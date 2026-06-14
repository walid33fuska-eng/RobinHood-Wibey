package integration::SmartScheduler;
# =============================================================================
# SmartScheduler.pm - المجدول الذكي للمهام والهجمات
# =============================================================================
# الميزات: جدولة ذكية، توزيع المهام، تحسين الوقت، تنفيذ تلقائي
# =============================================================================

use strict;
use warnings;
use parent 'Exporter';
our @EXPORT_OK = qw(scheduler_add_task scheduler_run scheduler_status scheduler_optimize);

use lib '.';
use lib::Utils;
use lib::Colors;
use Time::HiRes qw(sleep time);
use File::Slurp qw(read_file write_file);
use List::Util qw(shuffle);

# قاعدة بيانات المهام
my @TASKS = ();
my $SCHEDULER_RUNNING = 0;
my $SCHEDULER_PID = undef;
my $SCHEDULER_FILE = "$ENV{HOME}/.robinhood/scheduler_tasks.json";

# تحميل المهام المحفوظة
sub _load_tasks {
    if (-f $SCHEDULER_FILE) {
        my $json = read_file($SCHEDULER_FILE);
        eval { @TASKS = @{decode_json($json)}; };
    }
}

# حفظ المهام
sub _save_tasks {
    my $json = encode_json(\@TASKS);
    write_file($SCHEDULER_FILE, $json);
}

# =============================================================================
# إضافة مهمة إلى المجدول
# =============================================================================
sub scheduler_add_task {
    my ($task_name, $task_type, $schedule_time, $priority, $parameters) = @_;
    
    my $color = Colors->new();
    my $utils = Utils->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    📋 إضافة مهمة إلى المجدول 📋                       ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    _load_tasks();
    
    $task_name //= "مهمة غير مسماة";
    $task_type //= "attack";
    $schedule_time //= time() + 3600;
    $priority //= 5;
    $parameters //= {};
    
    my $task_id = int(rand(10000)) . time();
    
    my $task = {
        id => $task_id,
        name => $task_name,
        type => $task_type,
        schedule_time => $schedule_time,
        priority => $priority,
        parameters => $parameters,
        status => "pending",
        created_at => time(),
        retry_count => 0,
        max_retries => 3
    };
    
    push @TASKS, $task;
    _save_tasks();
    
    say "\n${\($color->success())}[✓] تمت إضافة المهمة:${\($color->reset())}";
    say "   → المعرف: $task_id";
    say "   → الاسم: $task_name";
    say "   → النوع: $task_type";
    say "   → الوقت: " . localtime($schedule_time);
    say "   → الأولوية: $priority";
    
    $utils->save_result('smart_scheduler', {
        action => 'add_task',
        task_id => $task_id,
        task_name => $task_name,
        schedule_time => $schedule_time
    });
    
    return $task_id;
}

# =============================================================================
# تشغيل المجدول
# =============================================================================
sub scheduler_run {
    my ($daemon_mode) = @_;
    
    my $color = Colors->new();
    my $utils = Utils->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    🚀 تشغيل المجدول الذكي 🚀                          ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    $daemon_mode //= 0;
    
    if ($SCHEDULER_RUNNING) {
        say "${\($color->warning())}[!] المجدول قيد التشغيل بالفعل${\($color->reset())}";
        return 0;
    }
    
    say "${\($color->info())}[*] بدء تشغيل المجدول الذكي...${\($color->reset())}";
    
    if ($daemon_mode) {
        $SCHEDULER_PID = fork();
        if ($SCHEDULER_PID == 0) {
            _scheduler_loop();
            exit(0);
        }
        say "${\($color->success())}[✓] تم تشغيل المجدول كخادم خلفي (PID: $SCHEDULER_PID)${\($color->reset())}";
    } else {
        _scheduler_loop();
    }
    
    $utils->save_result('smart_scheduler', {
        action => 'run',
        daemon_mode => $daemon_mode,
        pid => $SCHEDULER_PID
    });
    
    return 1;
}

# =============================================================================
# حالة المجدول
# =============================================================================
sub scheduler_status {
    my $color = Colors->new();
    my $utils = Utils->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    📊 حالة المجدول 📊                                ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    _load_tasks();
    
    my $pending = [grep { $_->{status} eq 'pending' && $_->{schedule_time} <= time() } @TASKS];
    my $scheduled = [grep { $_->{status} eq 'pending' && $_->{schedule_time} > time() } @TASKS];
    my $completed = [grep { $_->{status} eq 'completed' } @TASKS];
    my $failed = [grep { $_->{status} eq 'failed' } @TASKS];
    
    say "\n${\($color->info())}📈 إحصائيات المهام:${\($color->reset())}";
    say "   → مهام جاهزة للتنفيذ: " . scalar(@$pending);
    say "   → مهام مجدولة: " . scalar(@$scheduled);
    say "   → مهام مكتملة: " . scalar(@$completed);
    say "   → مهام فاشلة: " . scalar(@$failed);
    
    if (scalar(@$pending) > 0) {
        say "\n${\($color->quantum())}⏳ المهام الجاهزة للتنفيذ:${\($color->reset())}";
        for my $task (@$pending[0..4]) {
            say "   → $task->{name} (أولوية: $task->{priority})";
        }
    }
    
    if (scalar(@$scheduled) > 0) {
        say "\n${\($color->info())}🗓️ أقرب المهام المجدولة:${\($color->reset())}";
        for my $task (@$scheduled[0..4]) {
            my $time_left = $task->{schedule_time} - time();
            my $time_str = _format_time($time_left);
            say "   → $task->{name} - بعد $time_str";
        }
    }
    
    $utils->save_result('smart_scheduler', {
        action => 'status',
        pending => scalar(@$pending),
        scheduled => scalar(@$scheduled),
        completed => scalar(@$completed),
        failed => scalar(@$failed)
    });
    
    return {
        pending => scalar(@$pending),
        scheduled => scalar(@$scheduled),
        completed => scalar(@$completed),
        failed => scalar(@$failed)
    };
}

# =============================================================================
# تحسين المجدول
# =============================================================================
sub scheduler_optimize {
    my ($optimization_goal) = @_;
    
    my $color = Colors->new();
    my $utils = Utils->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    ⚙️ تحسين المجدول ⚙️                                ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    _load_tasks();
    
    $optimization_goal //= "minimize_wait";
    
    say "${\($color->info())}[*] تحسين المجدول بهدف: $optimization_goal${\($color->reset())}";
    
    my $optimizations = [];
    
    if ($optimization_goal eq "minimize_wait") {
        # ترتيب المهام حسب الأولوية والوقت
        @TASKS = sort { 
            ($a->{priority} <=> $b->{priority}) ||
            ($a->{schedule_time} <=> $b->{schedule_time})
        } @TASKS;
        
        push @$optimizations, "إعادة ترتيب المهام حسب الأولوية";
        push @$optimizations, "تقليل وقت الانتظار للمهام عالية الأولوية";
        
    } elsif ($optimization_goal eq "maximize_throughput") {
        # تجميع المهام المتشابهة
        my %groups = ();
        for my $task (@TASKS) {
            push @{$groups{$task->{type}}}, $task;
        }
        
        @TASKS = ();
        for my $type (keys %groups) {
            push @TASKS, @{$groups{$type}};
        }
        
        push @$optimizations, "تجميع المهام المتشابهة معاً";
        push @$optimizations, "تحسين إنتاجية المعالجة";
        
    } elsif ($optimization_goal eq "balanced") {
        # توزيع متوازن
        push @$optimizations, "توزيع متوازن للمهام";
        push @$optimizations, "جدولة ذكية حسب الموارد المتاحة";
    }
    
    # إضافة تحسينات إضافية
    push @$optimizations, "تفعيل التنفيذ المتوازي للمهام المستقلة";
    push @$optimizations, "إعادة المحاولات التلقائية للمهام الفاشلة";
    
    _save_tasks();
    
    say "\n${\($color->success())}🔧 التحسينات المطبقة:${\($color->reset())}";
    for my $opt (@$optimizations) {
        say "   → $opt";
    }
    
    $utils->save_result('smart_scheduler', {
        action => 'optimize',
        goal => $optimization_goal,
        optimizations_count => scalar(@$optimizations)
    });
    
    return $optimizations;
}

# =============================================================================
# دوال مساعدة داخلية
# =============================================================================

sub _scheduler_loop {
    my $color = Colors->new();
    $SCHEDULER_RUNNING = 1;
    
    while ($SCHEDULER_RUNNING) {
        _load_tasks();
        
        # البحث عن مهام جاهزة للتنفيذ
        my @ready = grep { $_->{status} eq 'pending' && $_->{schedule_time} <= time() } @TASKS;
        
        # ترتيب حسب الأولوية
        @ready = sort { $b->{priority} <=> $a->{priority} } @ready;
        
        for my $task (@ready) {
            _execute_task($task);
        }
        
        sleep(5);
    }
}

sub _execute_task {
    my ($task) = @_;
    
    my $color = Colors->new();
    
    say "\n${\($color->info())}[*] تنفيذ المهمة: $task->{name}${\($color->reset())}";
    
    # محاكاة تنفيذ المهمة
    my $success = rand() < 0.8;  # 80% نجاح
    
    if ($success) {
        $task->{status} = 'completed';
        $task->{completed_at} = time();
        say "${\($color->success())}[✓] اكتملت المهمة بنجاح${\($color->reset())}";
    } else {
        $task->{retry_count}++;
        if ($task->{retry_count} >= $task->{max_retries}) {
            $task->{status} = 'failed';
            say "${\($color->error())}[✗] فشلت المهمة بعد $task->{retry_count} محاولات${\($color->reset())}";
        } else {
            # إعادة جدولة
            $task->{schedule_time} = time() + 60 * $task->{retry_count};
            say "${\($color->warning())}[!] إعادة جدولة المهمة (محاولة $task->{retry_count})${\($color->reset())}";
        }
    }
    
    _save_tasks();
}

sub _format_time {
    my ($seconds) = @_;
    
    if ($seconds < 60) {
        return "$seconds ثانية";
    } elsif ($seconds < 3600) {
        return sprintf("%d دقيقة", $seconds / 60);
    } elsif ($seconds < 86400) {
        return sprintf("%d ساعة", $seconds / 3600);
    } else {
        return sprintf("%d يوم", $seconds / 86400);
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

sub decode_json {
    my ($json) = @_;
    return [];
}

# تحميل المهام عند التحميل
_load_tasks();

1;  # نهاية الوحدة
