package integration::TaskQueue;
# =============================================================================
# TaskQueue.pm - قائمة انتظار المهام وإدارتها
# =============================================================================
# الميزات: إدارة قائمة المهام، تحديد الأولويات، تنفيذ متوازي، مراقبة التقدم
# =============================================================================

use strict;
use warnings;
use parent 'Exporter';
our @EXPORT_OK = qw(task_enqueue task_dequeue task_status task_process task_clear);

use lib '.';
use lib::Utils;
use lib::Colors;
use Time::HiRes qw(sleep time);
use File::Slurp qw(read_file write_file);
use JSON;

# قائمة المهام
my $TASK_QUEUE_FILE = "$ENV{HOME}/.robinhood/task_queue.json";
my @TASK_QUEUE = ();
my @COMPLETED_TASKS = ();
my @FAILED_TASKS = ();
my $PROCESSING = 0;
my $MAX_CONCURRENT = 3;

# تحميل المهام المحفوظة
sub _load_task_queue {
    if (-f $TASK_QUEUE_FILE) {
        my $json = read_file($TASK_QUEUE_FILE);
        eval { 
            my $data = decode_json($json);
            @TASK_QUEUE = @{$data->{pending}} if $data->{pending};
            @COMPLETED_TASKS = @{$data->{completed}} if $data->{completed};
            @FAILED_TASKS = @{$data->{failed}} if $data->{failed};
        };
    }
}

# حفظ المهام
sub _save_task_queue {
    my $data = {
        pending => \@TASK_QUEUE,
        completed => \@COMPLETED_TASKS,
        failed => \@FAILED_TASKS,
        updated_at => time()
    };
    write_file($TASK_QUEUE_FILE, encode_json($data));
}

# =============================================================================
# إضافة مهمة إلى قائمة الانتظار
# =============================================================================
sub task_enqueue {
    my ($task_name, $task_type, $priority, $parameters, $schedule_time) = @_;
    
    my $color = Colors->new();
    my $utils = Utils->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    📥 إضافة مهمة إلى قائمة الانتظار 📥                ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    _load_task_queue();
    
    $task_name //= "مهمة غير مسماة";
    $task_type //= "attack";
    $priority //= 5;
    $parameters //= {};
    $schedule_time //= time();
    
    my $task_id = int(rand(10000)) . "_" . time();
    
    my $task = {
        id => $task_id,
        name => $task_name,
        type => $task_type,
        priority => $priority,
        parameters => $parameters,
        status => "pending",
        created_at => time(),
        schedule_time => $schedule_time,
        retry_count => 0,
        max_retries => 3
    };
    
    push @TASK_QUEUE, $task;
    
    # ترتيب حسب الأولوية والوقت
    @TASK_QUEUE = sort { 
        $b->{priority} <=> $a->{priority} ||
        $a->{schedule_time} <=> $b->{schedule_time}
    } @TASK_QUEUE;
    
    _save_task_queue();
    
    say "\n${\($color->success())}[✓] تمت إضافة المهمة إلى قائمة الانتظار:${\($color->reset())}";
    say "   → المعرف: $task_id";
    say "   → الاسم: $task_name";
    say "   → الأولوية: $priority";
    say "   → النوع: $task_type";
    
    $utils->save_result('task_queue', {
        action => 'enqueue',
        task_id => $task_id,
        task_name => $task_name,
        priority => $priority
    });
    
    return $task_id;
}

# =============================================================================
# استخراج مهمة من قائمة الانتظار
# =============================================================================
sub task_dequeue {
    my ($task_id) = @_;
    
    my $color = Colors->new();
    my $utils = Utils->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    📤 استخراج مهمة من قائمة الانتظار 📤               ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    _load_task_queue();
    
    my $found_task = undef;
    my $index = -1;
    
    for my $i (0..$#TASK_QUEUE) {
        if ($TASK_QUEUE[$i]->{id} eq $task_id) {
            $found_task = $TASK_QUEUE[$i];
            $index = $i;
            last;
        }
    }
    
    if (!$found_task) {
        say "${\($color->error())}[!] المهمة غير موجودة: $task_id${\($color->reset())}";
        return undef;
    }
    
    splice(@TASK_QUEUE, $index, 1);
    $found_task->{status} = "dequeued";
    $found_task->{dequeued_at} = time();
    
    push @COMPLETED_TASKS, $found_task;
    _save_task_queue();
    
    say "\n${\($color->success())}[✓] تم استخراج المهمة:${\($color->reset())}";
    say "   → المعرف: $task_id";
    say "   → الاسم: $found_task->{name}";
    
    $utils->save_result('task_queue', {
        action => 'dequeue',
        task_id => $task_id
    });
    
    return $found_task;
}

# =============================================================================
# حالة قائمة الانتظار
# =============================================================================
sub task_status {
    my ($detailed) = @_;
    
    my $color = Colors->new();
    my $utils = Utils->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    📊 حالة قائمة الانتظار 📊                          ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    _load_task_queue();
    
    $detailed //= 0;
    
    my $pending_count = scalar(@TASK_QUEUE);
    my $completed_count = scalar(@COMPLETED_TASKS);
    my $failed_count = scalar(@FAILED_TASKS);
    
    say "\n${\($color->info())}📈 إحصائيات قائمة الانتظار:${\($color->reset())}";
    say "   → مهام معلقة: $pending_count";
    say "   → مهام مكتملة: $completed_count";
    say "   → مهام فاشلة: $failed_count";
    say "   → قيد المعالجة: " . ($PROCESSING ? "نعم" : "لا");
    
    if ($pending_count > 0 && $detailed) {
        say "\n${\($color->quantum())}⏳ المهام المعلقة:${\($color->reset())}";
        for my $task (@TASK_QUEUE[0..4]) {
            my $time_left = $task->{schedule_time} - time();
            my $time_str = $time_left > 0 ? "بعد $time_left ثانية" : "جاهزة الآن";
            say "   → $task->{name} (أولوية: $task->{priority}) - $time_str";
        }
    }
    
    if ($completed_count > 0 && $detailed) {
        say "\n${\($color->success())}✅ آخر المهام المكتملة:${\($color->reset())}";
        for my $task (@COMPLETED_TASKS[-5..-1]) {
            say "   → $task->{name} - " . localtime($task->{dequeued_at});
        }
    }
    
    $utils->save_result('task_queue', {
        action => 'status',
        pending => $pending_count,
        completed => $completed_count,
        failed => $failed_count
    });
    
    return {
        pending => $pending_count,
        completed => $completed_count,
        failed => $failed_count,
        tasks => \@TASK_QUEUE
    };
}

# =============================================================================
# معالجة قائمة الانتظار
# =============================================================================
sub task_process {
    my ($max_tasks, $parallel) = @_;
    
    my $color = Colors->new();
    my $utils = Utils->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    ⚙️ معالجة قائمة الانتظار ⚙️                        ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    _load_task_queue();
    
    $max_tasks //= scalar(@TASK_QUEUE);
    $parallel //= 1;
    
    if ($PROCESSING) {
        say "${\($color->warning())}[!] توجد معالجة نشطة بالفعل${\($color->reset())}";
        return 0;
    }
    
    $PROCESSING = 1;
    
    my $processed = 0;
    my $successful = 0;
    my $failed = 0;
    
    # الحصول على المهام الجاهزة للتنفيذ
    my @ready = grep { $_->{status} eq 'pending' && $_->{schedule_time} <= time() } @TASK_QUEUE;
    @ready = sort { $b->{priority} <=> $a->{priority} } @ready;
    
    if (scalar(@ready) == 0) {
        say "\n${\($color->info())}[*] لا توجد مهام جاهزة للتنفيذ${\($color->reset())}";
        $PROCESSING = 0;
        return 0;
    }
    
    my $to_process = $max_tasks < scalar(@ready) ? $max_tasks : scalar(@ready);
    
    say "${\($color->info())}[*] معالجة $to_process مهمة${\($color->reset())}";
    
    if ($parallel) {
        # محاكاة المعالجة المتوازية
        my $pm = Parallel::ForkManager->new($MAX_CONCURRENT);
        
        for my $i (0..$to_process-1) {
            my $task = $ready[$i];
            $pm->start and next;
            
            my $result = _execute_task($task);
            
            if ($result->{success}) {
                $successful++;
                say "\n${\($color->success())}[✓] اكتملت المهمة: $task->{name}${\($color->reset())}";
            } else {
                $failed++;
                say "\n${\($color->error())}[✗] فشلت المهمة: $task->{name} - $result->{error}${\($color->reset())}";
            }
            
            $pm->finish;
        }
        
        $pm->wait_all_children();
    } else {
        # معالجة تسلسلية
        for my $i (0..$to_process-1) {
            my $task = $ready[$i];
            
            print "\n${\($color->info())}[*] تنفيذ المهمة: $task->{name}...${\($color->reset())}";
            
            my $result = _execute_task($task);
            
            if ($result->{success}) {
                $successful++;
                say " ${\($color->success())}✓${\($color->reset())}";
            } else {
                $failed++;
                say " ${\($color->error())}✗${\($color->reset())} - $result->{error}";
            }
            
            $processed++;
        }
    }
    
    # إزالة المهام المعالجة من قائمة الانتظار
    my @remaining = ();
    my $processed_ids = {};
    for my $i (0..$to_process-1) {
        $processed_ids->{$ready[$i]->{id}} = 1;
    }
    
    for my $task (@TASK_QUEUE) {
        if (!$processed_ids->{$task->{id}}) {
            push @remaining, $task;
        }
    }
    @TASK_QUEUE = @remaining;
    
    _save_task_queue();
    
    say "\n${\($color->success())}📊 خلاصة المعالجة:${\($color->reset())}";
    say "   → مهام معالجة: $processed";
    say "   → مهام ناجحة: $successful";
    say "   → مهام فاشلة: $failed";
    
    $PROCESSING = 0;
    
    $utils->save_result('task_queue', {
        action => 'process',
        processed => $processed,
        successful => $successful,
        failed => $failed
    });
    
    return {
        processed => $processed,
        successful => $successful,
        failed => $failed
    };
}

# =============================================================================
# مسح قائمة الانتظار
# =============================================================================
sub task_clear {
    my ($clear_completed, $clear_failed) = @_;
    
    my $color = Colors->new();
    my $utils = Utils->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    🧹 مسح قائمة الانتظار 🧹                           ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    _load_task_queue();
    
    $clear_completed //= 1;
    $clear_failed //= 1;
    
    my $cleared_count = 0;
    
    if ($clear_completed) {
        $cleared_count += scalar(@COMPLETED_TASKS);
        @COMPLETED_TASKS = ();
        say "${\($color->info())}[✓] تم مسح المهام المكتملة${\($color->reset())}";
    }
    
    if ($clear_failed) {
        $cleared_count += scalar(@FAILED_TASKS);
        @FAILED_TASKS = ();
        say "${\($color->info())}[✓] تم مسح المهام الفاشلة${\($color->reset())}";
    }
    
    _save_task_queue();
    
    say "\n${\($color->success())}[✓] تم مسح $cleared_count مهمة${\($color->reset())}";
    
    $utils->save_result('task_queue', {
        action => 'clear',
        cleared => $cleared_count
    });
    
    return $cleared_count;
}

# =============================================================================
# دوال مساعدة داخلية
# =============================================================================

sub _execute_task {
    my ($task) = @_;
    
    # محاكاة تنفيذ المهمة
    my $success = rand() < 0.8;  # 80% نجاح
    
    if ($success) {
        $task->{status} = "completed";
        $task->{completed_at} = time();
        return { success => 1 };
    } else {
        $task->{retry_count}++;
        
        if ($task->{retry_count} >= $task->{max_retries}) {
            $task->{status} = "failed";
            push @FAILED_TASKS, $task;
            return { success => 0, error => "فشل بعد $task->{retry_count} محاولات" };
        } else {
            # إعادة جدولة
            $task->{schedule_time} = time() + 60 * $task->{retry_count};
            return { success => 0, error => "سيتم إعادة المحاولة (محاولة $task->{retry_count})" };
        }
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
    return {};
}

# تحميل المهام عند التحميل
_load_task_queue();

1;  # نهاية الوحدة
