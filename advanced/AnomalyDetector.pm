package advanced::AnomalyDetector;
# =============================================================================
# AnomalyDetector.pm - كشف الحالات الشاذة والسلوكيات غير الطبيعية
# =============================================================================
# الميزات: كشف الاختراقات، اكتشاف الأنشطة المشبوهة، تنبيه فوري
# =============================================================================

use strict;
use warnings;
use parent 'Exporter';
our @EXPORT_OK = qw(detect_anomaly detect_intrusion detect_suspicious_activity detect_alert);

use lib '.';
use lib::Utils;
use lib::Colors;
use Time::HiRes qw(time);
use File::Slurp qw(write_file);
use List::Util qw(sum max min);

# =============================================================================
# كشف الحالات الشاذة العامة
# =============================================================================
sub detect_anomaly {
    my ($network_data, $baseline) = @_;
    
    my $color = Colors->new();
    my $utils = Utils->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    🚨 كشف الحالات الشاذة 🚨                           ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    $network_data //= {
        traffic_rate => 50,
        packets_per_second => 100,
        new_connections => 5,
        error_rate => 2,
        response_time => 150
    };
    
    $baseline //= {
        traffic_rate => 30,
        packets_per_second => 80,
        new_connections => 3,
        error_rate => 1,
        response_time => 100
    };
    
    say "${\($color->info())}[*] تحليل البيانات الحالية مقارنة بالخط الأساسي...${\($color->reset())}";
    
    my $anomalies = [];
    my $anomaly_score = 0;
    
    # فحص كل مقياس
    my $traffic_deviation = _calculate_deviation($network_data->{traffic_rate}, $baseline->{traffic_rate});
    if ($traffic_deviation > 50) {
        push @$anomalies, {
            type => "ارتفاع غير طبيعي في حركة المرور",
            current => $network_data->{traffic_rate},
            baseline => $baseline->{traffic_rate},
            deviation => $traffic_deviation,
            severity => "عالية"
        };
        $anomaly_score += 30;
    }
    
    my $packets_deviation = _calculate_deviation($network_data->{packets_per_second}, $baseline->{packets_per_second});
    if ($packets_deviation > 40) {
        push @$anomalies, {
            type => "زيادة مفاجئة في عدد الحزم",
            current => $network_data->{packets_per_second},
            baseline => $baseline->{packets_per_second},
            deviation => $packets_deviation,
            severity => "متوسطة"
        };
        $anomaly_score += 20;
    }
    
    my $connections_deviation = _calculate_deviation($network_data->{new_connections}, $baseline->{new_connections});
    if ($connections_deviation > 100) {
        push @$anomalies, {
            type => "عدد كبير من الاتصالات الجديدة",
            current => $network_data->{new_connections},
            baseline => $baseline->{new_connections},
            deviation => $connections_deviation,
            severity => "عالية"
        };
        $anomaly_score += 25;
    }
    
    my $error_deviation = _calculate_deviation($network_data->{error_rate}, $baseline->{error_rate});
    if ($error_deviation > 200) {
        push @$anomalies, {
            type => "ارتفاع معدل الأخطاء",
            current => $network_data->{error_rate},
            baseline => $baseline->{error_rate},
            deviation => $error_deviation,
            severity => "عالية"
        };
        $anomaly_score += 25;
    }
    
    # عرض النتائج
    if (scalar(@$anomalies) == 0) {
        say "\n${\($color->success())}✅ لم يتم اكتشاف أي حالات شاذة${\($color->reset())}";
    } else {
        say "\n${\($color->error())}⚠️ تم اكتشاف " . scalar(@$anomalies) . " حالة شاذة:${\($color->reset())}";
        
        for my $anomaly (@$anomalies) {
            my $severity_color = $anomaly->{severity} eq 'عالية' ? $color->error() : $color->warning();
            say "\n   → ${\($color->quantum())}$anomaly->{type}${\($color->reset())}";
            say "      → القيمة الحالية: $anomaly->{current}";
            say "      → القيمة الطبيعية: $anomaly->{baseline}";
            say "      → الانحراف: " . sprintf("%.1f", $anomaly->{deviation}) . "%";
            say "      → الخطورة: ${\($severity_color)}$anomaly->{severity}${\($color->reset())}";
        }
        
        say "\n${\($color->error())}📊 درجة الشذوذ الإجمالية: $anomaly_score/100${\($color->reset())}";
    }
    
    $utils->save_result('anomaly_detector', {
        anomalies_count => scalar(@$anomalies),
        anomaly_score => $anomaly_score
    });
    
    return {
        anomalies => $anomalies,
        score => $anomaly_score,
        has_anomaly => scalar(@$anomalies) > 0
    };
}

# =============================================================================
# كشف الاختراق
# =============================================================================
sub detect_intrusion {
    my ($security_logs, $threshold) = @_;
    
    my $color = Colors->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    🔓 كشف الاختراق 🔓                                ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    $security_logs //= [];
    $threshold //= 50;
    
    my $intrusions = [];
    my $risk_level = "منخفض";
    
    # تحليل سجلات الأمان
    my $failed_attempts = scalar(grep { $_->{type} eq 'failed_login' } @$security_logs);
    my $deauth_packets = scalar(grep { $_->{type} eq 'deauth' } @$security_logs);
    my $unusual_ports = scalar(grep { $_->{type} eq 'port_scan' } @$security_logs);
    
    my $intrusion_score = 0;
    
    if ($failed_attempts > 10) {
        push @$intrusions, {
            type => "هجوم تخمين كلمات المرور",
            details => "$failed_attempts محاولة فاشلة",
            severity => "عالية"
        };
        $intrusion_score += 40;
    }
    
    if ($deauth_packets > 50) {
        push @$intrusions, {
            type => "هجوم Deauthentication",
            details => "$deauth_packets حزمة deauth",
            severity => "عالية"
        };
        $intrusion_score += 35;
    }
    
    if ($unusual_ports > 5) {
        push @$intrusions, {
            type => "مسح المنافذ",
            details => "$unusual_ports منفذ غير عادي",
            severity => "متوسطة"
        };
        $intrusion_score += 25;
    }
    
    if ($intrusion_score > 70) {
        $risk_level = "حرج";
    } elsif ($intrusion_score > 40) {
        $risk_level = "مرتفع";
    } elsif ($intrusion_score > 20) {
        $risk_level = "متوسط";
    }
    
    # عرض النتائج
    if (scalar(@$intrusions) == 0) {
        say "\n${\($color->success())}✅ لم يتم اكتشاف أي اختراق${\($color->reset())}";
    } else {
        say "\n${\($color->error())}🚨 تم اكتشاف " . scalar(@$intrusions) . " اختراق محتمل:${\($color->reset())}";
        
        for my $intrusion (@$intrusions) {
            say "\n   → ${\($color->error())}$intrusion->{type}${\($color->reset())}";
            say "      → التفاصيل: $intrusion->{details}";
            say "      → الخطورة: $intrusion->{severity}";
        }
        
        say "\n${\($color->error())}⚠️ مستوى المخاطر: $risk_level${\($color->reset())}";
    }
    
    return {
        intrusions => $intrusions,
        score => $intrusion_score,
        risk_level => $risk_level
    };
}

# =============================================================================
# كشف الأنشطة المشبوهة
# =============================================================================
sub detect_suspicious_activity {
    my ($user_behavior, $time_window) = @_;
    
    my $color = Colors->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    👤 الأنشطة المشبوهة 👤                             ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    $user_behavior //= {
        login_time => "03:00",
        access_pattern => "unusual",
        data_transfer => 1000,  # MB
        failed_logins => 5,
        locations => 3
    };
    
    $time_window //= 3600;
    
    my $suspicious_activities = [];
    my $suspicion_score = 0;
    
    # كشف النشاط في وقت غير معتاد
    my $hour = (split(':', $user_behavior->{login_time}))[0];
    if ($hour < 5 || $hour > 23) {
        push @$suspicious_activities, {
            activity => "دخول في وقت غير معتاد",
            detail => "الوقت: $user_behavior->{login_time}",
            confidence => 70
        };
        $suspicion_score += 30;
    }
    
    # كشف نمط وصول غير معتاد
    if ($user_behavior->{access_pattern} eq 'unusual') {
        push @$suspicious_activities, {
            activity => "نمط وصول غير معتاد",
            detail => "محاولة الوصول إلى مناطق حساسة",
            confidence => 85
        };
        $suspicion_score += 35;
    }
    
    # كشف نقل بيانات كبير
    if ($user_behavior->{data_transfer} > 500) {
        push @$suspicious_activities, {
            activity => "نقل بيانات كبير",
            detail => "$user_behavior->{data_transfer} MB خلال $time_window ثانية",
            confidence => 75
        };
        $suspicion_score += 25;
    }
    
    # كشف محاولات دخول فاشلة متعددة
    if ($user_behavior->{failed_logins} > 3) {
        push @$suspicious_activities, {
            activity => "محاولات دخول فاشلة متعددة",
            detail => "$user_behavior->{failed_logins} محاولة",
            confidence => 90
        };
        $suspicion_score += 40;
    }
    
    # عرض النتائج
    if (scalar(@$suspicious_activities) == 0) {
        say "\n${\($color->success())}✅ لم يتم اكتشاف أنشطة مشبوهة${\($color->reset())}";
    } else {
        say "\n${\($color->warning())}⚠️ تم اكتشاف " . scalar(@$suspicious_activities) . " نشاط مشبوه:${\($color->reset())}";
        
        for my $activity (@$suspicious_activities) {
            say "\n   → ${\($color->quantum())}$activity->{activity}${\($color->reset())}";
            say "      → التفاصيل: $activity->{detail}";
            say "      → مستوى الثقة: $activity->{confidence}%";
        }
        
        say "\n${\($color->warning())}📊 درجة الاشتباه: $suspicion_score/100${\($color->reset())}";
    }
    
    return {
        activities => $suspicious_activities,
        suspicion_score => $suspicion_score
    };
}

# =============================================================================
# إنشاء تنبيه
# =============================================================================
sub detect_alert {
    my ($anomaly_data, $alert_config) = @_;
    
    my $color = Colors->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    🔔 نظام التنبيه 🔔                                ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    $anomaly_data //= { score => 50 };
    $alert_config //= {
        threshold => 40,
        notify_terminal => 1,
        log_alerts => 1
    };
    
    my $alerts = [];
    
    if ($anomaly_data->{score} > $alert_config->{threshold}) {
        my $alert = {
            timestamp => time(),
            time => scalar(localtime()),
            type => "anomaly_detected",
            score => $anomaly_data->{score},
            message => sprintf("تم اكتشاف حالة شاذة بدرجة %d", $anomaly_data->{score})
        };
        
        push @$alerts, $alert;
        
        if ($alert_config->{notify_terminal}) {
            say "\n${\($color->error())}🔔 تنبيه: $alert->{message}${\($color->reset())}";
        }
        
        if ($alert_config->{log_alerts}) {
            my $alert_file = "$ENV{HOME}/.robinhood/logs/alerts.log";
            open(my $fh, '>>', $alert_file);
            print $fh "[$alert->{time}] $alert->{message}\n";
            close($fh);
        }
    } else {
        say "\n${\($color->success())}✅ لا توجد تنبيهات - كل شيء طبيعي${\($color->reset())}";
    }
    
    return $alerts;
}

# =============================================================================
# دوال مساعدة داخلية
# =============================================================================

sub _calculate_deviation {
    my ($current, $baseline) = @_;
    
    if ($baseline == 0) {
        return $current > 0 ? 100 : 0;
    }
    
    return (($current - $baseline) / $baseline) * 100;
}

1;  # نهاية الوحدة
