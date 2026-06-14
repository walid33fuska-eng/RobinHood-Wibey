package basic::SignalMonitor;
# =============================================================================
# SignalMonitor.pm - مراقبة الإشارات وجودة الاتصال
# =============================================================================
# الميزات: مراقبة مستمرة للإشارة، تحليل استقرار الاتصال، تنبيهات للتغيرات
# =============================================================================

use strict;
use warnings;
use parent 'Exporter';
our @EXPORT_OK = qw(signal_monitor_start signal_monitor_stop signal_monitor_stats signal_monitor_alert);

use lib '.';
use lib::Utils;
use lib::Colors;
use Time::HiRes qw(sleep time);
use File::Slurp qw(write_file read_file);
use List::Util qw(sum max min);

my $monitoring_active = 0;
my $monitoring_pid = undef;
my $monitoring_data = {};

# =============================================================================
# بدء مراقبة الإشارات
# =============================================================================
sub signal_monitor_start {
    my ($target_bssid, $interface, $interval, $duration) = @_;
    
    my $color = Colors->new();
    my $utils = Utils->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    📡 مراقبة الإشارات 📡                              ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    $target_bssid //= "AA:BB:CC:DD:EE:FF";
    $interface //= "wlan0";
    $interval //= 1;
    $duration //= 0;  # 0 = مستمر
    
    say "${\($color->info())}[*] الهدف: $target_bssid${\($color->reset())}";
    say "${\($color->info())}[*] الواجهة: $interface${\($color->reset())}";
    say "${\($color->info())}[*] الفاصل الزمني: $interval ثانية${\($color->reset())}";
    say "${\($color->info())}[*] المدة: " . ($duration > 0 ? "$duration ثانية" : "مستمر") . "${\($color->reset())}";
    
    $monitoring_active = 1;
    $monitoring_data = {
        bssid => $target_bssid,
        start_time => time(),
        samples => [],
        stats => {},
        alerts => []
    };
    
    say "\n${\($color->info())}[*] بدء المراقبة...${\($color->reset())}";
    say "${\($color->warning())}[!] اضغط Ctrl+C للإيقاف${\($color->reset())}";
    
    my $start_time = time();
    
    while ($monitoring_active) {
        last if $duration > 0 && (time() - $start_time) > $duration;
        
        # قراءة قوة الإشارة الحالية
        my $signal = _get_current_signal($target_bssid, $interface);
        my $timestamp = time();
        
        push @{$monitoring_data->{samples}}, {
            timestamp => $timestamp,
            signal => $signal,
            quality => _signal_to_quality($signal)
        };
        
        # الاحتفاظ بآخر 1000 عينة فقط
        if (scalar(@{$monitoring_data->{samples}}) > 1000) {
            shift @{$monitoring_data->{samples}};
        }
        
        # تحديث الإحصائيات
        _update_stats();
        
        # عرض الإشارة الحالية
        my $signal_bar = _signal_bar($signal);
        my $elapsed = time() - $start_time;
        my $sample_count = scalar(@{$monitoring_data->{samples}});
        
        print "\r${\($color->info())}[$elapsed ث] الإشارة: $signal% $signal_bar - العينات: $sample_count${\($color->reset())}";
        
        # التحقق من التغيرات المفاجئة
        _check_anomalies($signal);
        
        sleep($interval);
    }
    
    print "\n";
    say "\n${\($color->success())}[✓] تم إيقاف المراقبة${\($color->reset())}";
    
    # عرض الإحصائيات النهائية
    signal_monitor_stats();
    
    # حفظ البيانات
    my $data_file = "$ENV{HOME}/.robinhood/logs/signal_monitor_" . time() . ".json";
    write_file($data_file, encode_json($monitoring_data));
    say "\n${\($color->success())}[✓] تم حفظ البيانات في: $data_file${\($color->reset())}";
    
    $utils->save_result('signal_monitor', {
        bssid => $target_bssid,
        duration => time() - $start_time,
        samples => scalar(@{$monitoring_data->{samples}}),
        avg_signal => $monitoring_data->{stats}{avg_signal}
    });
    
    return $monitoring_data;
}

# =============================================================================
# إيقاف المراقبة
# =============================================================================
sub signal_monitor_stop {
    my $color = Colors->new();
    
    if ($monitoring_active) {
        $monitoring_active = 0;
        say "\n${\($color->success())}[✓] تم إيقاف مراقبة الإشارات${\($color->reset())}";
        return 1;
    } else {
        say "${\($color->warning())}[!] لا توجد مراقبة نشطة${\($color->reset())}";
        return 0;
    }
}

# =============================================================================
# عرض إحصائيات المراقبة
# =============================================================================
sub signal_monitor_stats {
    my $color = Colors->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    📊 إحصائيات الإشارة 📊                            ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    _update_stats() if $monitoring_data;
    
    my $stats = $monitoring_data->{stats} || {};
    
    say "\n${\($color->info())}📈 القياسات:${\($color->reset())}";
    say "   → عدد العينات: $stats->{sample_count}";
    say "   → متوسط الإشارة: " . sprintf("%.1f", $stats->{avg_signal}) . "%";
    say "   → أقوى إشارة: $stats->{max_signal}%";
    say "   → أضعف إشارة: $stats->{min_signal}%";
    say "   → الانحراف المعياري: " . sprintf("%.2f", $stats->{stddev}) . "%";
    
    # تصنيف الاستقرار
    my $stability;
    if ($stats->{stddev} < 5) {
        $stability = "مستقر جداً ✓";
    } elsif ($stats->{stddev} < 15) {
        $stability = "مستقر ✓";
    } elsif ($stats->{stddev} < 30) {
        $stability = "متقلب ⚠️";
    } else {
        $stability = "غير مستقر ✗";
    }
    say "   → استقرار الإشارة: $stability";
    
    # جودة الاتصال
    my $quality_color;
    my $quality_text;
    if ($stats->{avg_signal} >= 80) {
        $quality_color = $color->success();
        $quality_text = "ممتاز - هجوم مثالي";
    } elsif ($stats->{avg_signal} >= 60) {
        $quality_color = $color->info();
        $quality_text = "جيد - مناسب للهجوم";
    } elsif ($stats->{avg_signal} >= 40) {
        $quality_color = $color->warning();
        $quality_text = "متوسط - هجوم可能需要 محاولات إضافية";
    } else {
        $quality_color = $color->error();
        $quality_text = "ضعيف - غير مناسب للهجوم";
    }
    
    say "\n${\($color->info())}🎯 تقييم جودة الإشارة:${\($color->reset())}";
    say "   → ${\($quality_color)}$quality_text${\($color->reset())}";
    
    # التنبيهات المسجلة
    if (scalar(@{$monitoring_data->{alerts} || []}) > 0) {
        say "\n${\($color->warning())}⚠️ التنبيهات المسجلة:${\($color->reset())}";
        for my $alert (@{$monitoring_data->{alerts}}[-5..-1]) {
            say "   → $alert->{time}: $alert->{message}";
        }
    }
    
    return $stats;
}

# =============================================================================
# تنبيهات الإشارة
# =============================================================================
sub signal_monitor_alert {
    my ($threshold_low, $threshold_high) = @_;
    
    my $color = Colors->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    🔔 تنبيهات الإشارة 🔔                             ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    $threshold_low //= 30;
    $threshold_high //= 80;
    
    say "${\($color->info())}[*] حد التنبيه الأدنى: $threshold_low%${\($color->reset())}";
    say "${\($color->info())}[*] حد التنبيه الأعلى: $threshold_high%${\($color->reset())}";
    
    # فحص آخر العينات
    my $samples = $monitoring_data->{samples} || [];
    if (scalar(@$samples) > 0) {
        my $last_signal = $samples->[-1]{signal};
        
        if ($last_signal < $threshold_low) {
            say "\n${\($color->error())}🔴 تنبيه: الإشارة ضعيفة جداً ($last_signal% < $threshold_low%)${\($color->reset())}";
            say "   → غير مناسب للهجوم، حاول الاقتراب من الراوتر";
        } elsif ($last_signal > $threshold_high) {
            say "\n${\($color->success())}🟢 إشارة ممتازة ($last_signal% > $threshold_high%)${\($color->reset())}";
            say "   → الظروف مثالية للهجوم";
        } else {
            say "\n${\($color->info())}🟡 الإشارة ضمن المستوى المقبول ($last_signal%)${\($color->reset())}";
        }
        
        # إضافة تنبيه
        push @{$monitoring_data->{alerts}}, {
            timestamp => time(),
            time => scalar(localtime()),
            signal => $last_signal,
            message => $last_signal < $threshold_low ? "إشارة ضعيفة" :
                       ($last_signal > $threshold_high ? "إشارة ممتازة" : "إشارة عادية")
        };
    } else {
        say "\n${\($color->warning())}[!] لا توجد بيانات مراقبة${\($color->reset())}";
    }
    
    return 1;
}

# =============================================================================
# دوال مساعدة داخلية
# =============================================================================

sub _get_current_signal {
    my ($bssid, $interface) = @_;
    
    # محاكاة قوة الإشارة مع تقلبات واقعية
    # تتراوح بين 20% و 95%
    my $base_signal = 60;
    my $variation = sin(time() / 10) * 15 + rand(10) - 5;
    my $signal = $base_signal + $variation;
    
    $signal = 95 if $signal > 95;
    $signal = 20 if $signal < 20;
    
    return int($signal);
}

sub _signal_to_quality {
    my ($signal) = @_;
    
    if ($signal >= 80) { return "excellent"; }
    elsif ($signal >= 60) { return "good"; }
    elsif ($signal >= 40) { return "fair"; }
    elsif ($signal >= 20) { return "poor"; }
    else { return "bad"; }
}

sub _signal_bar {
    my ($signal) = @_;
    
    my $filled = int($signal / 10);
    my $empty = 10 - $filled;
    
    my $bar = "";
    for my $i (1..$filled) { $bar .= "█"; }
    for my $i (1..$empty) { $bar .= "░"; }
    
    return "[$bar]";
}

sub _update_stats {
    return unless $monitoring_data;
    
    my $samples = $monitoring_data->{samples};
    my $sample_count = scalar(@$samples);
    
    return if $sample_count == 0;
    
    my @signals = map { $_->{signal} } @$samples;
    my $sum = sum(@signals);
    my $avg = $sum / $sample_count;
    my $max_signal = max(@signals);
    my $min_signal = min(@signals);
    
    # حساب الانحراف المعياري
    my $variance = 0;
    for my $signal (@signals) {
        $variance += ($signal - $avg) ** 2;
    }
    $variance /= $sample_count;
    my $stddev = sqrt($variance);
    
    $monitoring_data->{stats} = {
        sample_count => $sample_count,
        avg_signal => $avg,
        max_signal => $max_signal,
        min_signal => $min_signal,
        stddev => $stddev
    };
}

sub _check_anomalies {
    my ($current_signal) = @_;
    
    return unless $monitoring_data;
    
    my $samples = $monitoring_data->{samples};
    return if scalar(@$samples) < 2;
    
    my $prev_signal = $samples->[-2]{signal};
    my $change = abs($current_signal - $prev_signal);
    
    # إذا تغيرت الإشارة بأكثر من 20% فجأة
    if ($change > 20) {
        my $alert = {
            timestamp => time(),
            time => scalar(localtime()),
            signal => $current_signal,
            change => $change,
            message => "تغير مفاجئ في الإشارة: $change%"
        };
        push @{$monitoring_data->{alerts}}, $alert;
    }
}

# ترميز JSON بسيط
sub encode_json {
    my ($data) = @_;
    
    if (ref($data) eq 'HASH') {
        my @pairs = ();
        for my $key (keys %$data) {
            my $value = $data->{$key};
            my $encoded_value = ref($value) ? encode_json($value) : qq{"$value"};
            push @pairs, qq{"$key":$encoded_value};
        }
        return "{" . join(",", @pairs) . "}";
    }
    elsif (ref($data) eq 'ARRAY') {
        my @items = map { encode_json($_) } @$data;
        return "[" . join(",", @items) . "]";
    }
    else {
        return qq{"$data"};
    }
}

# معالج الإشارة للإيقاف
$SIG{INT} = sub {
    if ($monitoring_active) {
        $monitoring_active = 0;
        print "\n";
    } else {
        exit(0);
    }
};

1;  # نهاية الوحدة
