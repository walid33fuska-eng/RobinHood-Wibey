package advanced::BehavioralAnalyzer;
# =============================================================================
# BehavioralAnalyzer.pm - محلل السلوك والأنماط
# =============================================================================
# الميزات: تحليل سلوك المستخدمين، اكتشاف الأنماط الشاذة، التنبؤ بالسلوك المستقبلي
# =============================================================================

use strict;
use warnings;
use parent 'Exporter';
our @EXPORT_OK = qw(behavior_analyze behavior_patterns behavior_predict behavior_report);

use lib '.';
use lib::Utils;
use lib::Colors;
use Time::HiRes qw(sleep time);
use File::Slurp qw(read_file write_file);
use List::Util qw(sum max min);

# =============================================================================
# تحليل السلوك
# =============================================================================
sub behavior_analyze {
    my ($target_device, $duration, $interface) = @_;
    
    my $color = Colors->new();
    my $utils = Utils->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    🕵️ تحليل السلوك 🕵️                                 ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    $target_device //= "AA:BB:CC:DD:EE:FF";
    $duration //= 3600;  # ساعة واحدة
    $interface //= "wlan0";
    
    say "${\($color->info())}[*] الجهاز المستهدف: $target_device${\($color->reset())}";
    say "${\($color->info())}[*] مدة التحليل: $duration ثانية${\($color->reset())}";
    say "${\($color->info())}[*] الواجهة: $interface${\($color->reset())}";
    
    # جمع البيانات السلوكية
    say "\n${\($color->info())}[*] جمع البيانات السلوكية...${\($color->reset())}";
    
    my $behavior_data = {
        device => $target_device,
        start_time => time(),
        duration => $duration,
        activity_log => [],
        connection_patterns => {},
        activity_hours => {},
        avg_session_duration => 0,
        peak_hours => [],
        anomalies => []
    };
    
    my $start_time = time();
    my $sessions = 0;
    my $total_session_time = 0;
    
    while ((time() - $start_time) < $duration) {
        # محاكاة جمع بيانات النشاط
        my $activity = _collect_activity($target_device);
        push @{$behavior_data->{activity_log}}, $activity;
        
        # تحديث أنماط الاتصال
        my $hour = (localtime($activity->{timestamp}))[2];
        $behavior_data->{activity_hours}{$hour}++;
        
        # تحديث جلسات الاتصال
        if ($activity->{connected}) {
            $sessions++;
            $total_session_time += $activity->{session_duration} // 0;
        }
        
        # كشف الشذوذ
        my $anomaly = _detect_behavior_anomaly($activity, $behavior_data);
        if ($anomaly) {
            push @{$behavior_data->{anomalies}}, $anomaly;
        }
        
        # تحديث التقدم
        my $elapsed = time() - $start_time;
        my $percent = int(($elapsed / $duration) * 100);
        print "\r${\($color->info())}[*] التقدم: $percent% - الأحداث: " . scalar(@{$behavior_data->{activity_log}}) . "${\($color->reset())}";
        
        sleep(5);
    }
    
    print "\n";
    
    # حساب الإحصائيات
    $behavior_data->{avg_session_duration} = $sessions > 0 ? $total_session_time / $sessions : 0;
    
    # تحديد ساعات الذروة
    my @sorted_hours = sort { $behavior_data->{activity_hours}{$b} <=> $behavior_data->{activity_hours}{$a} } keys %{$behavior_data->{activity_hours}};
    $behavior_data->{peak_hours} = [@sorted_hours[0..2]];
    
    # عرض التحليل
    _display_behavior_analysis($behavior_data);
    
    # حفظ البيانات
    my $analysis_file = "$ENV{HOME}/.robinhood/logs/behavior_analysis_" . time() . ".json";
    write_file($analysis_file, encode_json($behavior_data));
    
    say "\n${\($color->success())}[✓] تم حفظ التحليل في: $analysis_file${\($color->reset())}";
    
    $utils->save_result('behavioral_analyzer', {
        device => $target_device,
        duration => $duration,
        events => scalar(@{$behavior_data->{activity_log}}),
        anomalies => scalar(@{$behavior_data->{anomalies}})
    });
    
    return $behavior_data;
}

# =============================================================================
# اكتشاف أنماط السلوك
# =============================================================================
sub behavior_patterns {
    my ($behavior_data) = @_;
    
    my $color = Colors->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    🎯 أنماط السلوك 🎯                                ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    $behavior_data //= {};
    
    my $patterns = {
        daily_pattern => _extract_daily_pattern($behavior_data),
        weekly_pattern => _extract_weekly_pattern($behavior_data),
        connection_pattern => _extract_connection_pattern($behavior_data),
        activity_pattern => _extract_activity_pattern($behavior_data)
    };
    
    say "\n${\($color->info())}📈 الأنماط المكتشفة:${\($color->reset())}";
    
    say "\n   🕐 النمط اليومي:";
    say "      → ساعات النشاط: $patterns->{daily_pattern}";
    
    say "\n   📡 نمط الاتصال:";
    say "      → $patterns->{connection_pattern}";
    
    say "\n   🎯 نمط النشاط:";
    say "      → $patterns->{activity_pattern}";
    
    return $patterns;
}

# =============================================================================
# التنبؤ بالسلوك المستقبلي
# =============================================================================
sub behavior_predict {
    my ($behavior_data, $future_time) = @_;
    
    my $color = Colors->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    🔮 التنبؤ بالسلوك 🔮                               ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    $behavior_data //= {};
    $future_time //= time() + 3600;  # بعد ساعة
    
    my $prediction = {
        timestamp => $future_time,
        predicted_state => _predict_state($behavior_data, $future_time),
        confidence => _calculate_prediction_confidence($behavior_data),
        factors => _identify_prediction_factors($behavior_data)
    };
    
    say "\n${\($color->info())}🔮 نتائج التنبؤ:${\($color->reset())}";
    say "   → الوقت المتوقع: " . localtime($future_time);
    say "   → الحالة المتوقعة: $prediction->{predicted_state}";
    say "   → مستوى الثقة: $prediction->{confidence}%";
    
    say "\n${\($color->info())}📊 العوامل المؤثرة:${\($color->reset())}";
    for my $factor (@{$prediction->{factors}}) {
        say "   → $factor";
    }
    
    return $prediction;
}

# =============================================================================
# تقرير السلوك
# =============================================================================
sub behavior_report {
    my ($behavior_data) = @_;
    
    my $color = Colors->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    📋 تقرير السلوك 📋                                ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    $behavior_data //= {};
    
    my $report = {
        device => $behavior_data->{device},
        analysis_period => $behavior_data->{duration},
        total_events => scalar(@{$behavior_data->{activity_log} || []}),
        anomalies_count => scalar(@{$behavior_data->{anomalies} || []}),
        peak_hours => $behavior_data->{peak_hours},
        avg_session => sprintf("%.1f", $behavior_data->{avg_session_duration} / 60) . " دقيقة",
        risk_level => _calculate_risk_level($behavior_data)
    };
    
    say "\n${\($color->info())}📊 ملخص التقرير:${\($color->reset())}";
    say "   → الجهاز: $report->{device}";
    say "   → مدة التحليل: $report->{analysis_period} ثانية";
    say "   → إجمالي الأحداث: $report->{total_events}";
    say "   → الحالات الشاذة: $report->{anomalies_count}";
    say "   → ساعات الذروة: " . join(", ", @{$report->{peak_hours}}) . ":00";
    say "   → متوسط مدة الجلسة: $report->{avg_session}";
    
    my $risk_color;
    if ($report->{risk_level} eq 'مرتفع') {
        $risk_color = $color->error();
    } elsif ($report->{risk_level} eq 'متوسط') {
        $risk_color = $color->warning();
    } else {
        $risk_color = $color->success();
    }
    
    say "   → مستوى الخطورة: ${\($risk_color)}$report->{risk_level}${\($color->reset())}";
    
    # التوصيات
    if ($report->{anomalies_count} > 0) {
        say "\n${\($color->warning())}⚠️ توصيات:${\($color->reset())}";
        say "   → تم اكتشاف سلوكيات شاذة، يوصى بمراقبة إضافية";
        say "   → تحقق من النشاط خلال ساعات غير معتادة";
    }
    
    return $report;
}

# =============================================================================
# دوال مساعدة داخلية
# =============================================================================

sub _collect_activity {
    my ($device) = @_;
    
    my $timestamp = time();
    my $hour = (localtime($timestamp))[2];
    
    # محاكاة النشاط: أكثر نشاطاً خلال النهار
    my $is_active = 0;
    if ($hour >= 9 && $hour <= 23) {
        $is_active = rand() < 0.7;  # 70% نشاط خلال النهار
    } else {
        $is_active = rand() < 0.2;  # 20% نشاط خلال الليل
    }
    
    return {
        timestamp => $timestamp,
        time => scalar(localtime($timestamp)),
        connected => $is_active,
        session_duration => $is_active ? int(rand(3600)) : 0,
        data_usage => $is_active ? int(rand(1024*1024*10)) : 0,
        signal => $is_active ? int(rand(60) + 20) : 0
    };
}

sub _detect_behavior_anomaly {
    my ($activity, $behavior_data) = @_;
    
    my $hour = (localtime($activity->{timestamp}))[2];
    my $normal_hours = $behavior_data->{activity_hours};
    
    # كشف نشاط في وقت غير معتاد
    if ($activity->{connected}) {
        my $avg_activity = $normal_hours->{$hour} // 0;
        if ($avg_activity < 2 && $avg_activity > 0) {
            return {
                timestamp => $activity->{timestamp},
                type => 'unusual_hour_activity',
                description => "نشاط غير معتاد في الساعة $hour:00",
                severity => 'متوسط'
            };
        }
    }
    
    return undef;
}

sub _extract_daily_pattern {
    my ($data) = @_;
    
    my $hours = $data->{activity_hours};
    my @active_hours = grep { $hours->{$_} > 0 } sort { $a <=> $b } keys %$hours;
    
    if (scalar(@active_hours) == 0) {
        return "لا يوجد نشاط";
    }
    
    return sprintf("%02d:00 - %02d:00", $active_hours[0], $active_hours[-1]);
}

sub _extract_weekly_pattern {
    my ($data) = @_;
    # محاكاة
    return "أيام الأسبوع: نشاط مرتفع، عطلات نهاية الأسبوع: نشاط منخفض";
}

sub _extract_connection_pattern {
    my ($data) = @_;
    # محاكاة
    return "جلسات قصيرة متكررة (15-30 دقيقة) خلال النهار";
}

sub _extract_activity_pattern {
    my ($data) = @_;
    # محاكاة
    return "تصفح مواقع التواصل، استخدام البريد الإلكتروني";
}

sub _predict_state {
    my ($data, $future_time) = @_;
    
    my $hour = (localtime($future_time))[2];
    my $hours = $data->{activity_hours};
    
    if ($hours->{$hour} && $hours->{$hour} > 5) {
        return "متصل (نشاط متوقع)";
    } elsif ($hours->{$hour} && $hours->{$hour} > 0) {
        return "متصل (نشاط محتمل)";
    } else {
        return "غير متصل";
    }
}

sub _calculate_prediction_confidence {
    my ($data) = @_;
    
    my $events = scalar(@{$data->{activity_log} || []});
    
    if ($events > 100) {
        return 85;
    } elsif ($events > 50) {
        return 70;
    } elsif ($events > 20) {
        return 50;
    } else {
        return 30;
    }
}

sub _identify_prediction_factors {
    my ($data) = @_;
    
    my @factors = ();
    
    push @factors, "نمط النشاط اليومي التاريخي";
    push @factors, "ساعات الذروة المعتادة";
    
    if ($data->{anomalies} && scalar(@{$data->{anomalies}}) > 0) {
        push @factors, "وجود حالات شاذة قد تؤثر على الدقة";
    }
    
    return \@factors;
}

sub _calculate_risk_level {
    my ($data) = @_;
    
    my $anomalies = scalar(@{$data->{anomalies} || []});
    my $events = scalar(@{$data->{activity_log} || []});
    
    if ($anomalies > 10) {
        return 'مرتفع';
    } elsif ($anomalies > 3) {
        return 'متوسط';
    } else {
        return 'منخفض';
    }
}

sub _display_behavior_analysis {
    my ($data) = @_;
    
    my $color = Colors->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    📊 نتائج تحليل السلوك 📊                           ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    say "\n${\($color->info())}📈 الإحصائيات الأساسية:${\($color->reset())}";
    say "   → عدد الأحداث: " . scalar(@{$data->{activity_log}});
    say "   → عدد الجلسات: " . (scalar(grep { $_->{connected} } @{$data->{activity_log}}));
    say "   → متوسط مدة الجلسة: " . sprintf("%.1f", $data->{avg_session_duration} / 60) . " دقيقة";
    
    say "\n${\($color->info())}🕐 توزيع النشاط حسب الساعة:${\($color->reset())}";
    for my $hour (sort { $a <=> $b } keys %{$data->{activity_hours}}) {
        my $count = $data->{activity_hours}{$hour};
        my $bar = _activity_bar($count);
        say "   → $hour:00 - $bar ($count حدث)";
    }
    
    if (scalar(@{$data->{anomalies}}) > 0) {
        say "\n${\($color->warning())}⚠️ الحالات الشاذة المكتشفة:${\($color->reset())}";
        for my $anomaly (@{$data->{anomalies}}) {
            say "   → $anomaly->{time}: $anomaly->{description}";
        }
    }
}

sub _activity_bar {
    my ($count) = @_;
    
    my $filled = $count > 10 ? 10 : $count;
    my $empty = 10 - $filled;
    
    return "[" . ("█" x $filled) . ("░" x $empty) . "]";
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
