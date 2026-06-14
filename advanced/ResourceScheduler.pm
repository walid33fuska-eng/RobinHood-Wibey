package advanced::ResourceScheduler;
# =============================================================================
# ResourceScheduler.pm - جدولة الموارد وإدارة المهام
# =============================================================================
# الميزات: توزيع الموارد، جدولة الهجمات، إدارة الأولويات، تحسين الاستخدام
# =============================================================================

use strict;
use warnings;
use parent 'Exporter';
our @EXPORT_OK = qw(schedule_resources schedule_attacks optimize_resource_usage schedule_priority);

use lib '.';
use lib::Utils;
use lib::Colors;
use Time::HiRes qw(sleep time);
use File::Slurp qw(write_file);
use List::Util qw(sum max min);

# =============================================================================
# جدولة الموارد
# =============================================================================
sub schedule_resources {
    my ($available_resources, $task_requirements) = @_;
    
    my $color = Colors->new();
    my $utils = Utils->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    📊 جدولة الموارد 📊                               ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    $available_resources //= {
        cpu_cores => 4,
        memory_mb => 4096,
        bandwidth_mbps => 100,
        concurrent_tasks => 3
    };
    
    $task_requirements //= [
        { name => "WPS Cracker", cpu => 1, memory => 256, bandwidth => 5, priority => 10 },
        { name => "Dictionary Attack", cpu => 2, memory => 512, bandwidth => 10, priority => 8 },
        { name => "Handshake Capture", cpu => 1, memory => 128, bandwidth => 2, priority => 9 },
        { name => "Evil Twin", cpu => 2, memory => 1024, bandwidth => 50, priority => 7 },
        { name => "PMKID Attack", cpu => 1, memory => 256, bandwidth => 3, priority => 8 }
    ];
    
    say "${\($color->info())}[*] الموارد المتاحة:${\($color->reset())}";
    say "   → CPU: $available_resources->{cpu_cores} نواة";
    say "   → الذاكرة: $available_resources->{memory_mb} MB";
    say "   → النطاق الترددي: $available_resources->{bandwidth_mbps} Mbps";
    say "   → المهام المتزامنة: $available_resources->{concurrent_tasks}";
    
    # خوارزمية الجدولة
    my $schedule = _schedule_tasks($available_resources, $task_requirements);
    
    say "\n${\($color->success())}📋 جدولة المهام:${\($color->reset())}";
    for my $task (@{$schedule->{running}}) {
        say "   → $task->{name} (CPU: $task->{cpu}, ذاكرة: $task->{memory}MB, وقت مقدر: $task->{estimated_time} دقيقة)";
    }
    
    if (scalar(@{$schedule->{pending}}) > 0) {
        say "\n${\($color->warning())}⏳ المهام في قائمة الانتظار:${\($color->reset())}";
        for my $task (@{$schedule->{pending}}) {
            say "   → $task->{name} (أولوية: $task->{priority})";
        }
    }
    
    say "\n${\($color->info())}📊 استخدام الموارد:${\($color->reset())}";
    say "   → CPU: $schedule->{resource_usage}{cpu}%";
    say "   → الذاكرة: $schedule->{resource_usage}{memory}%";
    say "   → النطاق الترددي: $schedule->{resource_usage}{bandwidth}%";
    
    $utils->save_result('resource_scheduler', {
        running_tasks => scalar(@{$schedule->{running}}),
        pending_tasks => scalar(@{$schedule->{pending}}),
        resource_usage => $schedule->{resource_usage}
    });
    
    return $schedule;
}

# =============================================================================
# جدولة الهجمات
# =============================================================================
sub schedule_attacks {
    my ($attack_list, $time_constraints) = @_;
    
    my $color = Colors->new();
    my $utils = Utils->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    ⏰ جدولة الهجمات ⏰                                ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    $attack_list //= [
        { name => "مسح الشبكة", duration => 5, best_time => "any", dependencies => [] },
        { name => "هجوم WPS", duration => 30, best_time => "night", dependencies => ["مسح الشبكة"] },
        { name => "التقاط المصافحة", duration => 10, best_time => "evening", dependencies => ["مسح الشبكة"] },
        { name => "هجوم القاموس", duration => 60, best_time => "night", dependencies => ["التقاط المصافحة"] },
        { name => "هجوم Evil Twin", duration => 120, best_time => "day", dependencies => [] }
    ];
    
    $time_constraints //= {
        start_time => "22:00",
        end_time => "06:00",
        max_concurrent => 2
    };
    
    say "${\($color->info())}[*] القيود الزمنية:${\($color->reset())}";
    say "   → بداية: $time_constraints->{start_time}";
    say "   → نهاية: $time_constraints->{end_time}";
    say "   → مهام متزامنة كحد أقصى: $time_constraints->{max_concurrent}";
    
    my $attack_schedule = _schedule_attacks($attack_list, $time_constraints);
    
    say "\n${\($color->success())}🗓️ جدول الهجمات المقترح:${\($color->reset())}";
    for my $attack (@{$attack_schedule->{schedule}}) {
        say "   → $attack->{time} : $attack->{name} ($attack->{duration} دقيقة)";
    }
    
    say "\n${\($color->info())}📈 إحصائيات الجدول:${\($color->reset())}";
    say "   → إجمالي الهجمات: $attack_schedule->{total_attacks}";
    say "   → المدة الإجمالية: $attack_schedule->{total_duration} دقيقة";
    say "   → وقت الانتهاء المتوقع: $attack_schedule->{completion_time}";
    
    $utils->save_result('attack_scheduler', {
        scheduled_attacks => scalar(@{$attack_schedule->{schedule}}),
        total_duration => $attack_schedule->{total_duration},
        conflicts => scalar(@{$attack_schedule->{conflicts}})
    });
    
    return $attack_schedule;
}

# =============================================================================
# تحسين استخدام الموارد
# =============================================================================
sub optimize_resource_usage {
    my ($current_usage, $optimization_goals) = @_;
    
    my $color = Colors->new();
    my $utils = Utils->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    ⚡ تحسين استخدام الموارد ⚡                        ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    $current_usage //= {
        cpu => 75,
        memory => 80,
        bandwidth => 60,
        disk => 45
    };
    
    $optimization_goals //= {
        max_cpu => 90,
        max_memory => 85,
        min_bandwidth => 20
    };
    
    say "${\($color->info())}[*] الاستخدام الحالي:${\($color->reset())}";
    say "   → CPU: $current_usage->{cpu}%";
    say "   → الذاكرة: $current_usage->{memory}%";
    say "   → النطاق الترددي: $current_usage->{bandwidth}%";
    
    my $optimization = _optimize_usage($current_usage, $optimization_goals);
    
    say "\n${\($color->success())}📊 نتائج التحسين:${\($color->reset())}";
    for my $resource (keys %{$optimization->{improvements}}) {
        my $imp = $optimization->{improvements}{$resource};
        my $color_imp = $imp > 0 ? $color->success() : $color->warning();
        say "   → $resource: ${\($color->quantum())}$current_usage->{$resource}%${\($color->reset())} → $optimization->{optimized}{$resource}% (${\($color_imp)}$imp%${\($color->reset())})";
    }
    
    say "\n${\($color->info())}🔧 الإجراءات المتخذة:${\($color->reset())}";
    for my $action (@{$optimization->{actions}}) {
        say "   → $action";
    }
    
    $utils->save_result('resource_optimization', {
        original_usage => $current_usage,
        optimized_usage => $optimization->{optimized}
    });
    
    return $optimization;
}

# =============================================================================
# تحديد الأولويات
# =============================================================================
sub schedule_priority {
    my ($tasks, $priority_rules) = @_;
    
    my $color = Colors->new();
    my $utils = Utils->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    🎯 تحديد الأولويات 🎯                             ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    $tasks //= [
        { name => "هجوم WPS", importance => 5, urgency => 4, estimated_time => 30 },
        { name => "هجوم القاموس", importance => 4, urgency => 3, estimated_time => 60 },
        { name => "التقاط المصافحة", importance => 5, urgency => 5, estimated_time => 10 },
        { name => "مسح الشبكة", importance => 3, urgency => 2, estimated_time => 5 },
        { name => "هجوم Evil Twin", importance => 4, urgency => 4, estimated_time => 120 }
    ];
    
    $priority_rules //= {
        weight_importance => 0.5,
        weight_urgency => 0.3,
        weight_time => 0.2
    };
    
    my $priority_list = _calculate_priorities($tasks, $priority_rules);
    
    say "\n${\($color->success())}🏆 ترتيب الأولويات:${\($color->reset())}";
    for my $i (0..$#{$priority_list->{sorted_tasks}}) {
        my $task = $priority_list->{sorted_tasks}[$i];
        my $priority_color = $task->{priority_score} >= 80 ? $color->error() :
                             ($task->{priority_score} >= 60 ? $color->warning() : $color->info());
        say "   " . ($i+1) . ". $task->{name} - درجة الأولوية: ${\($priority_color)}$task->{priority_score}%${\($color->reset())}";
    }
    
    $utils->save_result('priority_scheduler', {
        tasks_count => scalar(@{$priority_list->{sorted_tasks}}),
        top_priority => $priority_list->{sorted_tasks}[0]{name}
    });
    
    return $priority_list;
}

# =============================================================================
# دوال مساعدة داخلية
# =============================================================================

sub _schedule_tasks {
    my ($resources, $tasks) = @_;
    
    my @sorted_tasks = sort { $b->{priority} <=> $a->{priority} } @$tasks;
    
    my @running = ();
    my @pending = ();
    my $current_cpu = 0;
    my $current_memory = 0;
    my $current_bandwidth = 0;
    
    for my $task (@sorted_tasks) {
        if ($current_cpu + $task->{cpu} <= $resources->{cpu_cores} &&
            $current_memory + $task->{memory} <= $resources->{memory_mb} &&
            $current_bandwidth + $task->{bandwidth} <= $resources->{bandwidth_mbps} &&
            scalar(@running) < $resources->{concurrent_tasks}) {
            
            push @running, {
                name => $task->{name},
                cpu => $task->{cpu},
                memory => $task->{memory},
                bandwidth => $task->{bandwidth},
                estimated_time => int($task->{memory} / 100) + 5
            };
            
            $current_cpu += $task->{cpu};
            $current_memory += $task->{memory};
            $current_bandwidth += $task->{bandwidth};
        } else {
            push @pending, $task;
        }
    }
    
    my $resource_usage = {
        cpu => ($current_cpu / $resources->{cpu_cores}) * 100,
        memory => ($current_memory / $resources->{memory_mb}) * 100,
        bandwidth => ($current_bandwidth / $resources->{bandwidth_mbps}) * 100
    };
    
    return {
        running => \@running,
        pending => \@pending,
        resource_usage => $resource_usage
    };
}

sub _schedule_attacks {
    my ($attacks, $constraints) = @_;
    
    my @schedule = ();
    my $current_time = $constraints->{start_time};
    my $total_duration = 0;
    my @conflicts = ();
    
    # تحويل الوقت إلى ساعات رقمية
    my $start_hour = (split(':', $constraints->{start_time}))[0];
    my $end_hour = (split(':', $constraints->{end_time}))[0];
    
    for my $attack (@$attacks) {
        my $scheduled_time = $current_time;
        
        # التحقق من الوقت المناسب للهجوم
        if ($attack->{best_time} eq 'night' && ($start_hour >= 22 || $end_hour <= 6)) {
            # وقت مناسب
        } elsif ($attack->{best_time} eq 'day' && ($start_hour < 18)) {
            # وقت مناسب
        } elsif ($attack->{best_time} ne 'any') {
            push @conflicts, {
                attack => $attack->{name},
                reason => "وقت غير مناسب (الأفضل: $attack->{best_time})"
            };
        }
        
        push @schedule, {
            time => $current_time,
            name => $attack->{name},
            duration => $attack->{duration}
        };
        
        # تحديث الوقت الحالي
        my $hours = int($attack->{duration} / 60);
        my $minutes = $attack->{duration} % 60;
        my @time_parts = split(':', $current_time);
        my $new_hour = $time_parts[0] + $hours;
        my $new_minute = $time_parts[1] + $minutes;
        if ($new_minute >= 60) {
            $new_hour += int($new_minute / 60);
            $new_minute %= 60;
        }
        $current_time = sprintf("%02d:%02d", $new_hour, $new_minute);
        $total_duration += $attack->{duration};
    }
    
    return {
        schedule => \@schedule,
        total_attacks => scalar(@$attacks),
        total_duration => $total_duration,
        completion_time => $current_time,
        conflicts => \@conflicts
    };
}

sub _optimize_usage {
    my ($usage, $goals) = @_;
    
    my $optimized = { %$usage };
    my $improvements = {};
    my @actions = ();
    
    # تحسين CPU
    if ($usage->{cpu} > $goals->{max_cpu}) {
        my $reduction = $usage->{cpu} - $goals->{max_cpu};
        $optimized->{cpu} = $goals->{max_cpu};
        $improvements->{cpu} = -$reduction;
        push @actions, "تقليل استخدام CPU بنسبة $reduction% (وقف مهام غير ضرورية)";
    } else {
        $improvements->{cpu} = 0;
    }
    
    # تحسين الذاكرة
    if ($usage->{memory} > $goals->{max_memory}) {
        my $reduction = $usage->{memory} - $goals->{max_memory};
        $optimized->{memory} = $goals->{max_memory};
        $improvements->{memory} = -$reduction;
        push @actions, "تحرير ذاكرة بنسبة $reduction% (تنظيف cache)";
    } else {
        $improvements->{memory} = 0;
    }
    
    # تحسين النطاق الترددي
    if ($usage->{bandwidth} < $goals->{min_bandwidth}) {
        my $increase = $goals->{min_bandwidth} - $usage->{bandwidth};
        $optimized->{bandwidth} = $goals->{min_bandwidth};
        $improvements->{bandwidth} = $increase;
        push @actions, "زيادة استخدام النطاق الترددي بنسبة $increase%";
    } else {
        $improvements->{bandwidth} = 0;
    }
    
    return {
        optimized => $optimized,
        improvements => $improvements,
        actions => \@actions
    };
}

sub _calculate_priorities {
    my ($tasks, $rules) = @_;
    
    my @scored_tasks = ();
    
    for my $task (@$tasks) {
        my $score = ($task->{importance} * $rules->{weight_importance} * 20) +
                    ($task->{urgency} * $rules->{weight_urgency} * 20) +
                    ((100 - $task->{estimated_time}) * $rules->{weight_time});
        
        push @scored_tasks, {
            name => $task->{name},
            priority_score => int($score),
            importance => $task->{importance},
            urgency => $task->{urgency},
            estimated_time => $task->{estimated_time}
        };
    }
    
    my @sorted = sort { $b->{priority_score} <=> $a->{priority_score} } @scored_tasks;
    
    return {
        sorted_tasks => \@sorted,
        scores => \@scored_tasks
    };
}

1;  # نهاية الوحدة
