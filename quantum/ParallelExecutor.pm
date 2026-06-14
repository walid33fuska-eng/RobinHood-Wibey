package quantum::ParallelExecutor;
# =============================================================================
# ParallelExecutor.pm - التنفيذ المتوازي الكمي
# =============================================================================
# الميزات: تنفيذ متوازي للهجمات، معالجة متعددة النوى، توزيع ذكي للمهام
# =============================================================================

use strict;
use warnings;
use parent 'Exporter';
our @EXPORT_OK = qw(parallel_execute parallel_distribute parallel_merge parallel_optimize);

use lib '.';
use lib::Utils;
use lib::Colors;
use Parallel::ForkManager;
use Time::HiRes qw(sleep time);
use File::Slurp qw(write_file);
use List::Util qw(shuffle);

# =============================================================================
# التنفيذ المتوازي الكمي
# =============================================================================
sub parallel_execute {
    my ($tasks, $max_workers, $timeout) = @_;
    
    my $color = Colors->new();
    my $utils = Utils->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    ⚡ التنفيذ المتوازي الكمي ⚡                       ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    $tasks //= [
        { id => 1, name => "هجوم WPS على target1", duration => 30 },
        { id => 2, name => "هجوم WPS على target2", duration => 25 },
        { id => 3, name => "هجوم القاموس", duration => 60 },
        { id => 4, name => "PMKID Attack", duration => 10 },
        { id => 5, name => "التقاط المصافحة", duration => 15 },
        { id => 6, name => "مسح الشبكة", duration => 5 }
    ];
    $max_workers //= 4;
    $timeout //= 300;
    
    say "${\($color->info())}[*] عدد المهام: " . scalar(@$tasks) . "${\($color->reset())}";
    say "${\($color->info())}[*] الحد الأقصى للعاملين: $max_workers${\($color->reset())}";
    say "${\($color->info())}[*] المهلة الإجمالية: $timeout ثانية${\($color->reset())}";
    
    # توزيع المهام
    my $distributed = _distribute_tasks_quantum($tasks, $max_workers);
    
    say "\n${\($color->quantum())}🔀 توزيع المهام الكمي:${\($color->reset())}";
    for my $worker (keys %$distributed) {
        say "   → العامل $worker: " . scalar(@{$distributed->{$worker}}) . " مهمة";
    }
    
    # التنفيذ المتوازي
    my $pm = Parallel::ForkManager->new($max_workers);
    my $results = {};
    my $start_time = time();
    
    for my $worker (keys %$distributed) {
        $pm->start and next;
        
        my $worker_tasks = $distributed->{$worker};
        my $worker_results = [];
        
        for my $task (@$worker_tasks) {
            last if (time() - $start_time) > $timeout;
            
            print "\n${\($color->info())}[العامل $worker] تنفيذ: $task->{name}${\($color->reset())}";
            sleep($task->{duration} / 10);  # محاكاة التنفيذ
            
            push @$worker_results, {
                task_id => $task->{id},
                name => $task->{name},
                status => "completed",
                duration => $task->{duration},
                worker => $worker
            };
        }
        
        $results->{$worker} = $worker_results;
        $pm->finish;
    }
    
    $pm->wait_all_children();
    my $total_duration = time() - $start_time;
    
    # دمج النتائج
    my $all_results = _merge_results($results);
    
    say "\n\n${\($color->success())}📊 نتائج التنفيذ المتوازي:${\($color->reset())}";
    say "   → إجمالي المهام المنفذة: " . scalar(@$all_results);
    say "   → الوقت الإجمالي: " . sprintf("%.2f", $total_duration) . " ثانية";
    say "   → العاملين المستخدمين: $max_workers";
    
    # حساب كفاءة التوازي
    my $total_sequential_time = 0;
    for my $task (@$tasks) {
        $total_sequential_time += $task->{duration} / 10;
    }
    my $efficiency = ($total_sequential_time / $total_duration) * 100;
    say "   → كفاءة التوازي: " . sprintf("%.1f", $efficiency) . "%";
    
    $utils->save_result('parallel_executor', {
        total_tasks => scalar(@$tasks),
        workers => $max_workers,
        duration => $total_duration,
        efficiency => $efficiency
    });
    
    return {
        results => $all_results,
        duration => $total_duration,
        efficiency => $efficiency
    };
}

# =============================================================================
# التوزيع الكمي للمهام
# =============================================================================
sub parallel_distribute {
    my ($tasks, $weights, $strategy) = @_;
    
    my $color = Colors->new();
    my $utils = Utils->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    🔀 التوزيع الكمي للمهام 🔀                         ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    $tasks //= [1..20];
    $weights //= [];
    $strategy //= "balanced";
    
    say "${\($color->info())}[*] عدد المهام: " . scalar(@$tasks) . "${\($color->reset())}";
    say "${\($color->info())}[*] استراتيجية التوزيع: $strategy${\($color->reset())}";
    
    my $distribution = {};
    
    if ($strategy eq "balanced") {
        $distribution = _balanced_distribution($tasks);
    } elsif ($strategy eq "weighted") {
        $distribution = _weighted_distribution($tasks, $weights);
    } elsif ($strategy eq "quantum") {
        $distribution = _quantum_distribution($tasks);
    } else {
        $distribution = _round_robin_distribution($tasks);
    }
    
    say "\n${\($color->success())}📊 نتائج التوزيع:${\($color->reset())}";
    for my $worker (keys %$distribution) {
        my $count = scalar(@{$distribution->{$worker}});
        my $bar = _task_bar($count, scalar(@$tasks));
        say "   → العامل $worker: $count مهمة $bar";
    }
    
    $utils->save_result('parallel_distribute', {
        strategy => $strategy,
        workers => scalar(keys %$distribution),
        distribution_map => $distribution
    });
    
    return $distribution;
}

# =============================================================================
# دمج النتائج الكمي
# =============================================================================
sub parallel_merge {
    my ($results, $merge_strategy) = @_;
    
    my $color = Colors->new();
    my $utils = Utils->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    🔗 دمج النتائج الكمي 🔗                           ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    $results //= {
        worker1 => [1, 2, 3],
        worker2 => [4, 5, 6],
        worker3 => [7, 8, 9]
    };
    $merge_strategy //= "ordered";
    
    my $merged = [];
    
    if ($merge_strategy eq "ordered") {
        $merged = _ordered_merge($results);
    } elsif ($merge_strategy eq "interleaved") {
        $merged = _interleaved_merge($results);
    } elsif ($merge_strategy eq "quantum") {
        $merged = _quantum_merge($results);
    } else {
        $merged = _simple_merge($results);
    }
    
    say "\n${\($color->success())}📋 النتائج المدمجة:${\($color->reset())}";
    say "   → عدد العناصر قبل الدمج: " . (_total_elements($results));
    say "   → عدد العناصر بعد الدمج: " . scalar(@$merged);
    
    $utils->save_result('parallel_merge', {
        strategy => $merge_strategy,
        input_sources => scalar(keys %$results),
        output_count => scalar(@$merged)
    });
    
    return $merged;
}

# =============================================================================
# تحسين التوازي الكمي
# =============================================================================
sub parallel_optimize {
    my ($workload, $resources) = @_;
    
    my $color = Colors->new();
    my $utils = Utils->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    ⚙️ تحسين التوازي الكمي ⚙️                          ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    $workload //= {
        tasks => 100,
        avg_duration => 10,
        dependencies => 0.3
    };
    
    $resources //= {
        max_workers => 8,
        memory_per_worker => 512,
        network_bandwidth => 100
    };
    
    say "${\($color->info())}[*] تحليل عبء العمل:${\($color->reset())}";
    say "   → عدد المهام: $workload->{tasks}";
    say "   → متوسط المدة: $workload->{avg_duration} ثانية";
    say "   → نسبة التبعيات: $workload->{dependencies}%";
    
    # حساب العدد الأمثل للعاملين
    my $optimal_workers = _calculate_optimal_workers($workload, $resources);
    
    # حساب التسارع المتوقع
    my $expected_speedup = $optimal_workers * (1 - $workload->{dependencies} / 100);
    
    say "\n${\($color->success())}📊 نتائج التحسين:${\($color->reset())}";
    say "   → العدد الأمثل للعاملين: $optimal_workers";
    say "   → التسارع المتوقع: " . sprintf("%.2f", $expected_speedup) . "x";
    say "   → كفاءة الموارد المتوقعة: " . sprintf("%.1f", ($expected_speedup / $optimal_workers) * 100) . "%";
    
    # توصيات
    my @recommendations = ();
    if ($optimal_workers > $resources->{max_workers}) {
        push @recommendations, "زيادة عدد العاملين المتاحين لتحسين الأداء";
    }
    if ($workload->{dependencies} > 50) {
        push @recommendations, "تقليل التبعيات بين المهام لتحسين التوازي";
    }
    
    if (scalar(@recommendations) > 0) {
        say "\n${\($color->info())}💡 توصيات:${\($color->reset())}";
        for my $rec (@recommendations) {
            say "   → $rec";
        }
    }
    
    $utils->save_result('parallel_optimize', {
        optimal_workers => $optimal_workers,
        expected_speedup => $expected_speedup,
        recommendations => \@recommendations
    });
    
    return {
        optimal_workers => $optimal_workers,
        expected_speedup => $expected_speedup,
        recommendations => \@recommendations
    };
}

# =============================================================================
# دوال مساعدة داخلية
# =============================================================================

sub _distribute_tasks_quantum {
    my ($tasks, $workers) = @_;
    
    my $distribution = {};
    my @shuffled = shuffle(@$tasks);
    
    for my $i (0..$#shuffled) {
        my $worker = ($i % $workers) + 1;
        push @{$distribution->{$worker}}, $shuffled[$i];
    }
    
    return $distribution;
}

sub _balanced_distribution {
    my ($tasks) = @_;
    
    my $num_workers = 4;
    my $distribution = {};
    my $per_worker = int(scalar(@$tasks) / $num_workers);
    my $remainder = scalar(@$tasks) % $num_workers;
    
    my $index = 0;
    for my $w (1..$num_workers) {
        my $count = $per_worker + ($w <= $remainder ? 1 : 0);
        $distribution->{$w} = [@{$tasks}[$index..$index+$count-1]];
        $index += $count;
    }
    
    return $distribution;
}

sub _weighted_distribution {
    my ($tasks, $weights) = @_;
    return _balanced_distribution($tasks);
}

sub _quantum_distribution {
    my ($tasks) = @_;
    return _balanced_distribution($tasks);
}

sub _round_robin_distribution {
    my ($tasks) = @_;
    
    my $num_workers = 4;
    my $distribution = {};
    
    for my $i (0..$#{$tasks}) {
        my $worker = ($i % $num_workers) + 1;
        push @{$distribution->{$worker}}, $tasks->[$i];
    }
    
    return $distribution;
}

sub _merge_results {
    my ($results) = @_;
    
    my $merged = [];
    for my $worker (sort keys %$results) {
        push @$merged, @{$results->{$worker}};
    }
    
    return $merged;
}

sub _ordered_merge {
    my ($results) = @_;
    
    my @all = ();
    for my $worker (sort keys %$results) {
        push @all, @{$results->{$worker}};
    }
    
    return \@all;
}

sub _interleaved_merge {
    my ($results) = @_;
    
    my @merged = ();
    my @keys = sort keys %$results;
    my $max_len = 0;
    
    for my $key (@keys) {
        my $len = scalar(@{$results->{$key}});
        $max_len = $len if $len > $max_len;
    }
    
    for my $i (0..$max_len-1) {
        for my $key (@keys) {
            push @merged, $results->{$key}[$i] if $results->{$key}[$i];
        }
    }
    
    return \@merged;
}

sub _quantum_merge {
    my ($results) = @_;
    return _interleaved_merge($results);
}

sub _simple_merge {
    my ($results) = @_;
    return _ordered_merge($results);
}

sub _total_elements {
    my ($results) = @_;
    
    my $total = 0;
    for my $key (keys %$results) {
        $total += scalar(@{$results->{$key}});
    }
    return $total;
}

sub _calculate_optimal_workers {
    my ($workload, $resources) = @_;
    
    my $ideal = $workload->{tasks} / ($workload->{avg_duration} / 10);
    $ideal = $resources->{max_workers} if $ideal > $resources->{max_workers};
    $ideal = 1 if $ideal < 1;
    
    return int($ideal);
}

sub _task_bar {
    my ($count, $total) = @_;
    
    my $percent = ($count / $total) * 100;
    my $filled = int($percent / 5);
    my $empty = 20 - $filled;
    
    return "[" . ("█" x $filled) . ("░" x $empty) . "]";
}

1;  # نهاية الوحدة
