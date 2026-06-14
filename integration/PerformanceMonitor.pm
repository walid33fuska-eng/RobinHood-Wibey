package integration::PerformanceMonitor;
# =============================================================================
# PerformanceMonitor.pm - مراقبة أداء النظام
# =============================================================================
# الميزات: مراقبة CPU، الذاكرة، القرص، الشبكة، تحليل الأداء، تنبيهات
# =============================================================================

use strict;
use warnings;
use parent 'Exporter';
our @EXPORT_OK = qw(perf_monitor_start perf_monitor_stop perf_stats perf_alert perf_report);

use lib '.';
use lib::Utils;
use lib::Colors;
use Time::HiRes qw(sleep time);
use File::Slurp qw(read_file write_file);
use JSON;

# متغيرات المراقبة
my $MONITORING = 0;
my $MONITOR_PID = undef;
my @PERF_SAMPLES = ();
my $MONITOR_CONFIG_FILE = "$ENV{HOME}/.robinhood/perf_config.json";
my $MONITOR_CONFIG = {};

# تحميل إعدادات المراقبة
sub _load_monitor_config {
    if (-f $MONITOR_CONFIG_FILE) {
        my $json = read_file($MONITOR_CONFIG_FILE);
        eval { $MONITOR_CONFIG = decode_json($json); };
    }
    
    if (!keys %$MONITOR_CONFIG) {
        $MONITOR_CONFIG = {
            interval => 5,
            enabled => 1,
            alert_cpu => 80,
            alert_memory => 80,
            alert_disk => 90,
            max_samples => 1000,
            log_file => "$ENV{HOME}/.robinhood/logs/perf_log.json"
        };
    }
}

# حفظ إعدادات المراقبة
sub _save_monitor_config {
    write_file($MONITOR_CONFIG_FILE, encode_json($MONITOR_CONFIG));
}

# =============================================================================
# بدء مراقبة الأداء
# =============================================================================
sub perf_monitor_start {
    my ($interval, $daemon) = @_;
    
    my $color = Colors->new();
    my $utils = Utils->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    📊 بدء مراقبة الأداء 📊                            ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    _load_monitor_config();
    
    $interval //= $MONITOR_CONFIG->{interval};
    $daemon //= 0;
    
    if ($MONITORING) {
        say "${\($color->warning())}[!] المراقبة قيد التشغيل بالفعل${\($color->reset())}";
        return 0;
    }
    
    say "${\($color->info())}[*] بدء مراقبة الأداء (الفاصل: $interval ثانية)${\($color->reset())}";
    
    if ($daemon) {
        $MONITOR_PID = fork();
        if ($MONITOR_PID == 0) {
            _monitoring_loop($interval);
            exit(0);
        }
        say "${\($color->success())}[✓] تم تشغيل المراقبة كخادم خلفي (PID: $MONITOR_PID)${\($color->reset())}";
    } else {
        _monitoring_loop($interval);
    }
    
    $utils->save_result('performance_monitor', {
        action => 'start',
        interval => $interval,
        daemon => $daemon,
        pid => $MONITOR_PID
    });
    
    return 1;
}

# =============================================================================
# إيقاف مراقبة الأداء
# =============================================================================
sub perf_monitor_stop {
    my $color = Colors->new();
    my $utils = Utils->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    🛑 إيقاف مراقبة الأداء 🛑                          ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    if (!$MONITORING) {
        say "${\($color->warning())}[!] المراقبة غير قيد التشغيل${\($color->reset())}";
        return 0;
    }
    
    say "${\($color->info())}[*] إيقاف مراقبة الأداء...${\($color->reset())}";
    
    if ($MONITOR_PID && kill(0, $MONITOR_PID)) {
        kill('TERM', $MONITOR_PID);
        sleep(1);
        
        if (kill(0, $MONITOR_PID)) {
            kill('KILL', $MONITOR_PID);
        }
    }
    
    $MONITORING = 0;
    $MONITOR_PID = undef;
    
    say "\n${\($color->success())}[✓] تم إيقاف مراقبة الأداء${\($color->reset())}";
    
    $utils->save_result('performance_monitor', {
        action => 'stop'
    });
    
    return 1;
}

# =============================================================================
# إحصائيات الأداء
# =============================================================================
sub perf_stats {
    my ($time_range) = @_;
    
    my $color = Colors->new();
    my $utils = Utils->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    📈 إحصائيات الأداء 📈                             ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    $time_range //= 3600;  # آخر ساعة
    
    my $current_stats = _get_current_stats();
    my $historical_stats = _get_historical_stats($time_range);
    
    say "\n${\($color->info())}🖥️ الإحصائيات الحالية:${\($color->reset())}";
    say "   → CPU: $current_stats->{cpu}%";
    say "   → الذاكرة: $current_stats->{memory}%";
    say "   → القرص: $current_stats->{disk}%";
    say "   → الشبكة (تحميل): " . $utils->format_size($current_stats->{network_rx}) . "/s";
    say "   → الشبكة (رفع): " . $utils->format_size($current_stats->{network_tx}) . "/s";
    say "   → الحرارة: $current_stats->{temperature}°C";
    
    if ($historical_stats->{samples} > 0) {
        say "\n${\($color->quantum())}📊 الإحصائيات التاريخية (آخر " . ($time_range/3600) . " ساعة):${\($color->reset())}";
        say "   → متوسط CPU: " . sprintf("%.1f", $historical_stats->{avg_cpu}) . "%";
        say "   → ذروة CPU: $historical_stats->{max_cpu}%";
        say "   → متوسط الذاكرة: " . sprintf("%.1f", $historical_stats->{avg_memory}) . "%";
        say "   → ذروة الذاكرة: $historical_stats->{max_memory}%";
    }
    
    # تقييم الأداء
    my $performance_score = _calculate_performance_score($current_stats);
    my $score_color;
    if ($performance_score >= 80) {
        $score_color = $color->success();
    } elsif ($performance_score >= 60) {
        $score_color = $color->info();
    } elsif ($performance_score >= 40) {
        $score_color = $color->warning();
    } else {
        $score_color = $color->error();
    }
    
    say "\n${\($color->info())}🎯 درجة الأداء: ${\($score_color)}$performance_score/100${\($color->reset())}";
    
    $utils->save_result('performance_monitor', {
        action => 'stats',
        cpu => $current_stats->{cpu},
        memory => $current_stats->{memory},
        performance_score => $performance_score
    });
    
    return {
        current => $current_stats,
        historical => $historical_stats,
        score => $performance_score
    };
}

# =============================================================================
# تنبيهات الأداء
# =============================================================================
sub perf_alert {
    my ($cpu_threshold, $memory_threshold, $disk_threshold) = @_;
    
    my $color = Colors->new();
    my $utils = Utils->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    🔔 تنبيهات الأداء 🔔                              ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    _load_monitor_config();
    
    $cpu_threshold //= $MONITOR_CONFIG->{alert_cpu};
    $memory_threshold //= $MONITOR_CONFIG->{alert_memory};
    $disk_threshold //= $MONITOR_CONFIG->{alert_disk};
    
    my $current = _get_current_stats();
    my $alerts = [];
    
    if ($current->{cpu} > $cpu_threshold) {
        push @$alerts, {
            type => "CPU",
            value => $current->{cpu},
            threshold => $cpu_threshold,
            severity => "warning"
        };
        say "\n${\($color->warning())}⚠️ تنبيه: استخدام CPU مرتفع ($current->{cpu}% > $cpu_threshold%)${\($color->reset())}";
    }
    
    if ($current->{memory} > $memory_threshold) {
        push @$alerts, {
            type => "Memory",
            value => $current->{memory},
            threshold => $memory_threshold,
            severity => "warning"
        };
        say "\n${\($color->warning())}⚠️ تنبيه: استخدام الذاكرة مرتفع ($current->{memory}% > $memory_threshold%)${\($color->reset())}";
    }
    
    if ($current->{disk} > $disk_threshold) {
        push @$alerts, {
            type => "Disk",
            value => $current->{disk},
            threshold => $disk_threshold,
            severity => "critical"
        };
        say "\n${\($color->error())}🔴 تنبيه: استخدام القرص مرتفع ($current->{disk}% > $disk_threshold%)${\($color->reset())}";
    }
    
    if (scalar(@$alerts) == 0) {
        say "\n${\($color->success())}✓ جميع المقاييس ضمن الحدود الطبيعية${\($color->reset())}";
    }
    
    $utils->save_result('performance_monitor', {
        action => 'alert',
        alerts => scalar(@$alerts)
    });
    
    return $alerts;
}

# =============================================================================
# تقرير الأداء
# =============================================================================
sub perf_report {
    my ($output_file, $report_format) = @_;
    
    my $color = Colors->new();
    my $utils = Utils->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    📋 تقرير الأداء 📋                                ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    $output_file //= "$ENV{HOME}/.robinhood/reports/perf_report_" . time() . ".html";
    $report_format //= "html";
    
    # جمع البيانات
    my $current = _get_current_stats();
    my $historical = _get_historical_stats(86400);  # آخر 24 ساعة
    
    # إنشاء التقرير
    my $report = "";
    
    if ($report_format eq "html") {
        $report = _generate_html_report($current, $historical);
    } elsif ($report_format eq "json") {
        $report = encode_json({
            current => $current,
            historical => $historical,
            timestamp => time()
        });
    } else {
        $report = _generate_text_report($current, $historical);
    }
    
    write_file($output_file, $report);
    
    my $size = -s $output_file;
    
    say "\n${\($color->success())}[✓] تم إنشاء تقرير الأداء:${\($color->reset())}";
    say "   → الملف: $output_file";
    say "   → الحجم: " . $utils->format_size($size);
    
    $utils->save_result('performance_monitor', {
        action => 'report',
        output => $output_file,
        format => $report_format
    });
    
    return $output_file;
}

# =============================================================================
# دوال مساعدة داخلية
# =============================================================================

sub _monitoring_loop {
    my ($interval) = @_;
    
    $MONITORING = 1;
    
    while ($MONITORING) {
        my $sample = {
            timestamp => time(),
            time => scalar(localtime()),
            cpu => _get_cpu_usage(),
            memory => _get_memory_usage(),
            disk => _get_disk_usage(),
            network_rx => _get_network_rx(),
            network_tx => _get_network_tx(),
            temperature => _get_temperature(),
            processes => _get_process_count()
        };
        
        push @PERF_SAMPLES, $sample;
        
        # الاحتفاظ بآخر 1000 عينة فقط
        if (scalar(@PERF_SAMPLES) > $MONITOR_CONFIG->{max_samples}) {
            shift @PERF_SAMPLES;
        }
        
        # حفظ العينات في ملف السجل
        if ($MONITOR_CONFIG->{log_file}) {
            my $log_entry = encode_json($sample);
            open(my $fh, '>>', $MONITOR_CONFIG->{log_file});
            print $fh "$log_entry\n";
            close($fh);
        }
        
        sleep($interval);
    }
}

sub _get_current_stats {
    return {
        cpu => _get_cpu_usage(),
        memory => _get_memory_usage(),
        disk => _get_disk_usage(),
        network_rx => _get_network_rx(),
        network_tx => _get_network_tx(),
        temperature => _get_temperature(),
        processes => _get_process_count(),
        uptime => _get_uptime()
    };
}

sub _get_historical_stats {
    my ($time_range) = @_;
    
    my $cutoff = time() - $time_range;
    my @samples = grep { $_->{timestamp} >= $cutoff } @PERF_SAMPLES;
    
    if (scalar(@samples) == 0) {
        return {
            samples => 0,
            avg_cpu => 0,
            max_cpu => 0,
            avg_memory => 0,
            max_memory => 0
        };
    }
    
    my $total_cpu = 0;
    my $max_cpu = 0;
    my $total_memory = 0;
    my $max_memory = 0;
    
    for my $sample (@samples) {
        $total_cpu += $sample->{cpu};
        $max_cpu = $sample->{cpu} if $sample->{cpu} > $max_cpu;
        $total_memory += $sample->{memory};
        $max_memory = $sample->{memory} if $sample->{memory} > $max_memory;
    }
    
    return {
        samples => scalar(@samples),
        avg_cpu => $total_cpu / scalar(@samples),
        max_cpu => $max_cpu,
        avg_memory => $total_memory / scalar(@samples),
        max_memory => $max_memory
    };
}

sub _get_cpu_usage {
    # محاكاة استخدام CPU (10-90%)
    return int(rand(80)) + 10;
}

sub _get_memory_usage {
    # محاكاة استخدام الذاكرة (20-80%)
    return int(rand(60)) + 20;
}

sub _get_disk_usage {
    # محاكاة استخدام القرص (30-70%)
    return int(rand(40)) + 30;
}

sub _get_network_rx {
    # محاكاة استقبال الشبكة (KB/s)
    return int(rand(1024)) * 1024;
}

sub _get_network_tx {
    # محاكاة إرسال الشبكة (KB/s)
    return int(rand(512)) * 1024;
}

sub _get_temperature {
    # محاكاة درجة الحرارة (40-80 درجة)
    return int(rand(40)) + 40;
}

sub _get_process_count {
    # محاكاة عدد العمليات
    return int(rand(100)) + 20;
}

sub _get_uptime {
    return int(time() - $^T);
}

sub _calculate_performance_score {
    my ($stats) = @_;
    
    my $score = 100;
    
    $score -= ($stats->{cpu} - 50) / 2 if $stats->{cpu} > 50;
    $score -= ($stats->{memory} - 50) / 2 if $stats->{memory} > 50;
    $score -= ($stats->{temperature} - 70) if $stats->{temperature} > 70;
    
    $score = 0 if $score < 0;
    $score = 100 if $score > 100;
    
    return int($score);
}

sub _generate_text_report {
    my ($current, $historical) = @_;
    
    my $report = "=" x 60 . "\n";
    $report .= "تقرير أداء النظام\n";
    $report .= "=" x 60 . "\n\n";
    
    $report .= "الوقت: " . localtime() . "\n\n";
    
    $report .= "الإحصائيات الحالية:\n";
    $report .= "  CPU: $current->{cpu}%\n";
    $report .= "  الذاكرة: $current->{memory}%\n";
    $report .= "  القرص: $current->{disk}%\n";
    $report .= "  الحرارة: $current->{temperature}°C\n\n";
    
    $report .= "الإحصائيات التاريخية:\n";
    $report .= "  متوسط CPU: " . sprintf("%.1f", $historical->{avg_cpu}) . "%\n";
    $report .= "  ذروة CPU: $historical->{max_cpu}%\n";
    $report .= "  متوسط الذاكرة: " . sprintf("%.1f", $historical->{avg_memory}) . "%\n";
    $report .= "  ذروة الذاكرة: $historical->{max_memory}%\n";
    
    $report .= "\n" . "=" x 60 . "\n";
    
    return $report;
}

sub _generate_html_report {
    my ($current, $historical) = @_;
    
    my $html = '<!DOCTYPE html>';
    $html .= '<html><head><meta charset="UTF-8">';
    $html .= '<title>تقرير أداء النظام</title>';
    $html .= '<style>
        body { font-family: Arial, sans-serif; margin: 20px; direction: rtl; }
        h1 { color: #333; }
        .stats { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 20px; margin: 20px 0; }
        .stat-box { background: #f0f0f0; padding: 15px; border-radius: 10px; text-align: center; }
        .stat-value { font-size: 2em; font-weight: bold; color: #4CAF50; }
        table { border-collapse: collapse; width: 100%; margin: 20px 0; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: right; }
        th { background-color: #4CAF50; color: white; }
    </style>';
    $html .= '</head><body>';
    
    $html .= "<h1>تقرير أداء النظام</h1>";
    $html .= "<p>الوقت: " . localtime() . "</p>";
    
    $html .= "<div class='stats'>";
    $html .= "<div class='stat-box'><div>CPU</div><div class='stat-value'>$current->{cpu}%</div></div>";
    $html .= "<div class='stat-box'><div>الذاكرة</div><div class='stat-value'>$current->{memory}%</div></div>";
    $html .= "<div class='stat-box'><div>القرص</div><div class='stat-value'>$current->{disk}%</div></div>";
    $html .= "<div class='stat-box'><div>الحرارة</div><div class='stat-value'>$current->{temperature}°C</div></div>";
    $html .= "</div>";
    
    $html .= "<h2>الإحصائيات التاريخية</h2>";
    $html .= "<table>";
    $html .= "<tr><th>المقياس</th><th>المتوسط</th><th>الذروة</th></tr>";
    $html .= "<tr><td>CPU</td><td>" . sprintf("%.1f", $historical->{avg_cpu}) . "%</td><td>$historical->{max_cpu}%</td></tr>";
    $html .= "<tr><td>الذاكرة</td><td>" . sprintf("%.1f", $historical->{avg_memory}) . "%</td><td>$historical->{max_memory}%</td></tr>";
    $html .= "</table>";
    
    $html .= '</body></html>';
    
    return $html;
}

# تحميل الإعدادات عند التحميل
_load_monitor_config();

1;  # نهاية الوحدة
