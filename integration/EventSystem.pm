package integration::EventSystem;
# =============================================================================
# EventSystem.pm - نظام الأحداث والاستماع
# =============================================================================
# الميزات: تسجيل الأحداث، معالجة الأحداث، نظام النشر والاشتراك، تسجيل الأحداث
# =============================================================================

use strict;
use warnings;
use parent 'Exporter';
our @EXPORT_OK = qw(event_emit event_on event_once event_off event_list);

use lib '.';
use lib::Utils;
use lib::Colors;
use Time::HiRes qw(time);
use File::Slurp qw(read_file write_file);
use JSON;

# بنية الأحداث
my %EVENT_LISTENERS = ();
my @EVENT_HISTORY = ();
my $EVENT_LOG_FILE = "$ENV{HOME}/.robinhood/logs/events.log";
my $MAX_HISTORY = 1000;

# =============================================================================
# إصدار حدث
# =============================================================================
sub event_emit {
    my ($event_name, $event_data, $async) = @_;
    
    my $color = Colors->new();
    my $utils = Utils->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    📡 إصدار حدث 📡                                   ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    $event_name //= "unknown";
    $event_data //= {};
    $async //= 0;
    
    say "${\($color->info())}[*] إصدار حدث: $event_name${\($color->reset())}";
    
    # إنشاء كائن الحدث
    my $event = {
        name => $event_name,
        data => $event_data,
        timestamp => time(),
        time => scalar(localtime()),
        id => int(rand(1000000))
    };
    
    # تسجيل الحدث في السجل
    _log_event($event);
    
    # تخزين في التاريخ
    push @EVENT_HISTORY, $event;
    if (scalar(@EVENT_HISTORY) > $MAX_HISTORY) {
        shift @EVENT_HISTORY;
    }
    
    # استدعاء المستمعين
    my $listeners = $EVENT_LISTENERS{$event_name} || [];
    my $wildcard_listeners = $EVENT_LISTENERS{'*'} || [];
    
    my @all_listeners = (@$listeners, @$wildcard_listeners);
    
    if (scalar(@all_listeners) == 0) {
        say "   → لا يوجد مستمعين لهذا الحدث";
        return 0;
    }
    
    say "   → عدد المستمعين: " . scalar(@all_listeners);
    
    if ($async) {
        # تنفيذ غير متزامن
        for my $listener (@all_listeners) {
            my $pid = fork();
            if ($pid == 0) {
                eval { $listener->($event); };
                exit(0);
            }
        }
    } else {
        # تنفيذ متزامن
        for my $listener (@all_listeners) {
            eval { $listener->($event); };
            if ($@) {
                say "${\($color->error())}   → خطأ في المستمع: $@${\($color->reset())}";
            }
        }
    }
    
    $utils->save_result('event_system', {
        action => 'emit',
        event => $event_name,
        listeners => scalar(@all_listeners)
    });
    
    return $event->{id};
}

# =============================================================================
# تسجيل مستمع لحدث
# =============================================================================
sub event_on {
    my ($event_name, $callback, $priority) = @_;
    
    my $color = Colors->new();
    my $utils = Utils->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    👂 تسجيل مستمع 👂                                 ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    $event_name //= "*";
    $callback //= sub { my ($e) = @_; say "   → حدث: $e->{name}"; };
    $priority //= 0;
    
    my $listener_id = int(rand(1000000)) . "_" . time();
    
    my $listener = {
        id => $listener_id,
        callback => $callback,
        priority => $priority,
        created_at => time(),
        event => $event_name
    };
    
    push @{$EVENT_LISTENERS{$event_name}}, $listener;
    
    # ترتيب حسب الأولوية
    @{$EVENT_LISTENERS{$event_name}} = sort { $b->{priority} <=> $a->{priority} } @{$EVENT_LISTENERS{$event_name}};
    
    say "\n${\($color->success())}[✓] تم تسجيل مستمع للحدث: $event_name${\($color->reset())}";
    say "   → المعرف: $listener_id";
    say "   → الأولوية: $priority";
    
    $utils->save_result('event_system', {
        action => 'on',
        event => $event_name,
        listener_id => $listener_id
    });
    
    return $listener_id;
}

# =============================================================================
# تسجيل مستمع لمرة واحدة
# =============================================================================
sub event_once {
    my ($event_name, $callback, $priority) = @_;
    
    my $color = Colors->new();
    my $utils = Utils->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    🔂 مستمع لمرة واحدة 🔂                             ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    $event_name //= "*";
    $callback //= sub { my ($e) = @_; say "   → حدث لمرة واحدة: $e->{name}"; };
    $priority //= 0;
    
    # غلاف يزيل المستمع بعد التنفيذ
    my $wrapper = sub {
        my ($event) = @_;
        $callback->($event);
        event_off($event_name, $wrapper);
    };
    
    my $listener_id = event_on($event_name, $wrapper, $priority);
    
    say "\n${\($color->success())}[✓] تم تسجيل مستمع لمرة واحدة للحدث: $event_name${\($color->reset())}";
    
    $utils->save_result('event_system', {
        action => 'once',
        event => $event_name,
        listener_id => $listener_id
    });
    
    return $listener_id;
}

# =============================================================================
# إزالة مستمع
# =============================================================================
sub event_off {
    my ($event_name, $listener_id_or_callback) = @_;
    
    my $color = Colors->new();
    my $utils = Utils->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    ❌ إزالة مستمع ❌                                 ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    $event_name //= "";
    
    if (!$event_name) {
        say "${\($color->error())}[!] لم يتم تحديد اسم الحدث${\($color->reset())}";
        return 0;
    }
    
    my $listeners = $EVENT_LISTENERS{$event_name};
    
    if (!$listeners) {
        say "${\($color->warning())}[!] لا يوجد مستمعين للحدث $event_name${\($color->reset())}";
        return 0;
    }
    
    my $removed = 0;
    
    if (ref($listener_id_or_callback) eq 'CODE') {
        # إزالة حسب الدالة
        my @remaining = ();
        for my $listener (@$listeners) {
            if ($listener->{callback} != $listener_id_or_callback) {
                push @remaining, $listener;
            } else {
                $removed++;
            }
        }
        $EVENT_LISTENERS{$event_name} = \@remaining;
        
    } else {
        # إزالة حسب المعرف
        my @remaining = ();
        for my $listener (@$listeners) {
            if ($listener->{id} ne $listener_id_or_callback) {
                push @remaining, $listener;
            } else {
                $removed++;
            }
        }
        $EVENT_LISTENERS{$event_name} = \@remaining;
    }
    
    # حذف المفتاح إذا أصبح فارغاً
    if (scalar(@{$EVENT_LISTENERS{$event_name}}) == 0) {
        delete $EVENT_LISTENERS{$event_name};
    }
    
    say "\n${\($color->success())}[✓] تم إزالة $removed مستمع للحدث $event_name${\($color->reset())}";
    
    $utils->save_result('event_system', {
        action => 'off',
        event => $event_name,
        removed => $removed
    });
    
    return $removed;
}

# =============================================================================
# قائمة الأحداث والمستمعين
# =============================================================================
sub event_list {
    my ($event_name) = @_;
    
    my $color = Colors->new();
    my $utils = Utils->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    📋 قائمة الأحداث والمستمعين 📋                     ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    $event_name //= "";
    
    if ($event_name) {
        # عرض مستمعي حدث معين
        my $listeners = $EVENT_LISTENERS{$event_name};
        
        if (!$listeners || scalar(@$listeners) == 0) {
            say "\n${\($color->warning())}[!] لا يوجد مستمعين للحدث $event_name${\($color->reset())}";
            return [];
        }
        
        say "\n${\($color->info())}👂 مستمعي الحدث $event_name:${\($color->reset())}";
        for my $i (0..$#$listeners) {
            my $listener = $listeners->[$i];
            say "   " . ($i+1) . ". المعرف: $listener->{id} (أولوية: $listener->{priority})";
        }
        
        return $listeners;
        
    } else {
        # عرض جميع الأحداث
        my @events = keys %EVENT_LISTENERS;
        
        if (scalar(@events) == 0) {
            say "\n${\($color->warning())}[!] لا توجد أحداث مسجلة${\($color->reset())}";
            return {};
        }
        
        say "\n${\($color->info())}📊 الأحداث المسجلة:${\($color->reset())}";
        for my $event (@events) {
            my $count = scalar(@{$EVENT_LISTENERS{$event}});
            say "   → $event: $count مستمع";
        }
        
        # عرض آخر الأحداث
        if (scalar(@EVENT_HISTORY) > 0) {
            say "\n${\($color->quantum())}🕐 آخر الأحداث:${\($color->reset())}";
            for my $event (@EVENT_HISTORY[-5..-1]) {
                say "   → $event->{time}: $event->{name}";
            }
        }
        
        return \%EVENT_LISTENERS;
    }
}

# =============================================================================
# دوال مساعدة داخلية
# =============================================================================

sub _log_event {
    my ($event) = @_;
    
    my $log_entry = encode_json($event);
    
    open(my $fh, '>>', $EVENT_LOG_FILE);
    print $fh "$log_entry\n";
    close($fh);
    
    # تدوير السجل إذا أصبح كبيراً جداً
    if (-s $EVENT_LOG_FILE > 10 * 1024 * 1024) {  # 10 MB
        my $backup = $EVENT_LOG_FILE . ".old";
        rename($EVENT_LOG_FILE, $backup);
    }
}

# ترميز JSON بسيط
sub encode_json {
    my ($data) = @_;
    
    if (ref($data) eq 'ARRAY') {
        my @items = map { encode_json($_) } @$data;
        return "[" . join(",", @items) . "]";
    }
    elsif (ref($data) eq 'HASH') {
        my @pairs = ();
        for my $key (keys %$data) {
            my $value = $data->{$key};
            my $encoded_value = ref($value) ? encode_json($value) : qq{"$value"};
            push @pairs, qq{"$key":$encoded_value};
        }
        return "{" . join(",", @pairs) . "}";
    }
    else {
        return qq{"$data"};
    }
}

1;  # نهاية الوحدة
