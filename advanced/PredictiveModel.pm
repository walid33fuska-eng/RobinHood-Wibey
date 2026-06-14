package advanced::PredictiveModel;
# =============================================================================
# PredictiveModel.pm - نموذج تنبؤي للهجمات والسلوك
# =============================================================================
# الميزات: توقع نجاح الهجمات، تحليل احتمالية الاختراق، تنبؤ بسلوك الشبكة
# =============================================================================

use strict;
use warnings;
use parent 'Exporter';
our @EXPORT_OK = qw(predict_attack_success predict_weak_passwords predict_network_behavior predict_risk_score);

use lib '.';
use lib::Utils;
use lib::Colors;
use Time::HiRes qw(time);
use File::Slurp qw(write_file);
use List::Util qw(sum max min);

# =============================================================================
# توقع نجاح الهجوم
# =============================================================================
sub predict_attack_success {
    my ($target_info, $attack_type) = @_;
    
    my $color = Colors->new();
    my $utils = Utils->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    🎯 توقع نجاح الهجوم 🎯                            ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    $target_info //= {
        bssid => "AA:BB:CC:DD:EE:FF",
        ssid => "Target_Network",
        encryption => "WPA2",
        signal => 65,
        wps_enabled => 1,
        clients => 5
    };
    $attack_type //= "wps";
    
    say "${\($color->info())}[*] الهدف: $target_info->{ssid} ($target_info->{bssid})${\($color->reset())}";
    say "${\($color->info())}[*] نوع الهجوم: $attack_type${\($color->reset())}";
    
    # حساب عوامل النجاح
    my $factors = _calculate_success_factors($target_info, $attack_type);
    
    # حساب احتمالية النجاح الإجمالية
    my $success_probability = _calculate_success_probability($factors);
    
    # توقع الوقت المستغرق
    my $estimated_time = _estimate_attack_time($attack_type, $target_info);
    
    # عرض النتائج
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    📊 نتائج التوقع 📊                                ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    my $prob_color;
    if ($success_probability >= 70) {
        $prob_color = $color->success();
    } elsif ($success_probability >= 40) {
        $prob_color = $color->warning();
    } else {
        $prob_color = $color->error();
    }
    
    say "\n${\($color->info())}📈 احتمالية النجاح: ${\($prob_color)}$success_probability%${\($color->reset())}";
    say "   → الوقت المتوقع: $estimated_time";
    
    say "\n${\($color->info())}📊 العوامل المؤثرة:${\($color->reset())}";
    for my $factor (@$factors) {
        my $factor_color = $factor->{impact} eq 'positive' ? $color->success() : $color->error();
        say "   → $factor->{name}: ${\($factor_color)}$factor->{value}${\($color->reset())} (تأثير: $factor->{impact})";
    }
    
    # توصيات لزيادة احتمالية النجاح
    if ($success_probability < 60) {
        say "\n${\($color->info())}💡 توصيات لزيادة احتمالية النجاح:${\($color->reset())}";
        my $recommendations = _generate_recommendations($target_info, $attack_type);
        for my $rec (@$recommendations) {
            say "   → $rec";
        }
    }
    
    $utils->save_result('predictive_model', {
        target => $target_info->{ssid},
        attack_type => $attack_type,
        success_probability => $success_probability,
        estimated_time => $estimated_time
    });
    
    return {
        probability => $success_probability,
        estimated_time => $estimated_time,
        factors => $factors
    };
}

# =============================================================================
# توقع كلمات المرور الضعيفة
# =============================================================================
sub predict_weak_passwords {
    my ($target_info, $count) = @_;
    
    my $color = Colors->new();
    my $utils = Utils->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    🔑 توقع كلمات المرور الضعيفة 🔑                    ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    $target_info //= {
        ssid => "Target_Network",
        bssid => "AA:BB:CC:DD:EE:FF",
        region => "AE",
        company => "Home"
    };
    $count //= 20;
    
    say "${\($color->info())}[*] الهدف: $target_info->{ssid}${\($color->reset())}";
    say "${\($color->info())}[*] عدد الكلمات المتوقعة: $count${\($color->reset())}";
    
    # توليد الكلمات المتوقعة
    my $predicted_passwords = _generate_predicted_passwords($target_info, $count);
    
    say "\n${\($color->success())}🔮 كلمات المرور الأكثر توقعاً (مرتبة حسب الاحتمالية):${\($color->reset())}";
    
    for my $i (0..$#{$predicted_passwords}) {
        my $password = $predicted_passwords->[$i];
        my $probability = _calculate_password_probability($password, $target_info);
        my $prob_bar = _probability_bar($probability);
        
        say "   " . ($i+1) . ". $password - احتمالية: $prob_bar ($probability%)";
    }
    
    $utils->save_result('predicted_passwords', {
        target => $target_info->{ssid},
        predictions => $predicted_passwords
    });
    
    return $predicted_passwords;
}

# =============================================================================
# توقع سلوك الشبكة
# =============================================================================
sub predict_network_behavior {
    my ($network_info, $timeframe) = @_;
    
    my $color = Colors->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    🌐 توقع سلوك الشبكة 🌐                            ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    $network_info //= {
        bssid => "AA:BB:CC:DD:EE:FF",
        devices_count => 8,
        avg_traffic => 50,  # MB/s
        peak_hours => [20, 21, 22]
    };
    $timeframe //= "next_24h";
    
    say "${\($color->info())}[*] تحليل سلوك الشبكة لـ $timeframe${\($color->reset())}";
    
    my $prediction = {
        expected_devices => _predict_device_count($network_info),
        expected_traffic => _predict_traffic_pattern($network_info),
        expected_peak_hours => _predict_peak_hours($network_info),
        expected_anomalies => _predict_anomalies($network_info),
        recommendations => _generate_network_recommendations($network_info)
    };
    
    say "\n${\($color->info())}🔮 توقعات سلوك الشبكة:${\($color->reset())}";
    say "   → عدد الأجهزة المتوقع: $prediction->{expected_devices}";
    say "   → حركة المرور المتوقعة: $prediction->{expected_traffic} MB/s";
    say "   → ساعات الذروة المتوقعة: " . join(", ", @{$prediction->{expected_peak_hours}}) . ":00";
    
    if (scalar(@{$prediction->{expected_anomalies}}) > 0) {
        say "\n${\($color->warning())}⚠️ الحالات الشاذة المتوقعة:${\($color->reset())}";
        for my $anomaly (@{$prediction->{expected_anomalies}}) {
            say "   → $anomaly";
        }
    }
    
    return $prediction;
}

# =============================================================================
# حساب درجة المخاطر
# =============================================================================
sub predict_risk_score {
    my ($target_info) = @_;
    
    my $color = Colors->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    ⚠️ حساب درجة المخاطر ⚠️                           ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    $target_info //= {
        encryption => "WPA2",
        wps_enabled => 1,
        signal => 65,
        devices_count => 8,
        firmware_age => 365  # أيام
    };
    
    my $risk_score = 0;
    my $risk_factors = [];
    
    # 1. نوع التشفير
    my $encryption_risk = _encryption_risk_score($target_info->{encryption});
    $risk_score += $encryption_risk;
    push @$risk_factors, { factor => "نوع التشفير", score => $encryption_risk, max => 25 };
    
    # 2. WPS
    my $wps_risk = $target_info->{wps_enabled} ? 25 : 0;
    $risk_score += $wps_risk;
    push @$risk_factors, { factor => "WPS مفعل", score => $wps_risk, max => 25 };
    
    # 3. قوة الإشارة (إشارة أقوى = خطر أعلى للهجوم)
    my $signal_risk = int($target_info->{signal} * 0.3);
    $signal_risk = 20 if $signal_risk > 20;
    $risk_score += $signal_risk;
    push @$risk_factors, { factor => "قوة الإشارة", score => $signal_risk, max => 20 };
    
    # 4. عدد الأجهزة (أجهزة أكثر = خطر أعلى)
    my $devices_risk = $target_info->{devices_count} > 10 ? 15 : 
                       ($target_info->{devices_count} > 5 ? 10 : 5);
    $risk_score += $devices_risk;
    push @$risk_factors, { factor => "عدد الأجهزة", score => $devices_risk, max => 15 };
    
    # 5. عمر البرامج الثابتة
    my $firmware_risk = $target_info->{firmware_age} > 180 ? 15 : 
                        ($target_info->{firmware_age} > 90 ? 10 : 5);
    $risk_score += $firmware_risk;
    push @$risk_factors, { factor => "قدم البرامج الثابتة", score => $firmware_risk, max => 15 };
    
    $risk_score = 100 if $risk_score > 100;
    
    # عرض النتائج
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    📊 تفاصيل درجة المخاطر 📊                         ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    for my $factor (@$risk_factors) {
        my $factor_color = $factor->{score} > $factor->{max}/2 ? $color->error() : $color->success();
        say "   → $factor->{factor}: ${\($factor_color)}$factor->{score}/$factor->{max}${\($color->reset())}";
    }
    
    my $risk_color;
    my $risk_level;
    if ($risk_score >= 70) {
        $risk_color = $color->error();
        $risk_level = "خطير جداً";
    } elsif ($risk_score >= 50) {
        $risk_color = $color->warning();
        $risk_level = "مرتفع";
    } elsif ($risk_score >= 30) {
        $risk_color = $color->info();
        $risk_level = "متوسط";
    } else {
        $risk_color = $color->success();
        $risk_level = "منخفض";
    }
    
    say "\n${\($color->info())}🎯 درجة المخاطر الإجمالية: ${\($risk_color)}$risk_score/100 ($risk_level)${\($color->reset())}";
    
    return {
        total_score => $risk_score,
        level => $risk_level,
        factors => $risk_factors
    };
}

# =============================================================================
# دوال مساعدة داخلية
# =============================================================================

sub _calculate_success_factors {
    my ($target, $attack_type) = @_;
    
    my @factors = ();
    
    if ($attack_type eq 'wps') {
        push @factors, {
            name => "تفعيل WPS",
            value => $target->{wps_enabled} ? "نعم" : "لا",
            impact => $target->{wps_enabled} ? "positive" : "negative"
        };
        push @factors, {
            name => "حماية PIN",
            value => "غير معروفة",
            impact => "positive"
        };
    } elsif ($attack_type eq 'dictionary') {
        my $password_strength = int(rand(100));
        push @factors, {
            name => "قوة كلمة المرور المتوقعة",
            value => "$password_strength%",
            impact => $password_strength < 50 ? "positive" : "negative"
        };
    } elsif ($attack_type eq 'deauth') {
        push @factors, {
            name => "عدد الأجهزة المتصلة",
            value => $target->{clients},
            impact => $target->{clients} > 0 ? "positive" : "negative"
        };
    }
    
    push @factors, {
        name => "قوة الإشارة",
        value => $target->{signal} . "%",
        impact => $target->{signal} > 50 ? "positive" : "negative"
    };
    
    return \@factors;
}

sub _calculate_success_probability {
    my ($factors) = @_;
    
    my $positive = grep { $_->{impact} eq 'positive' } @$factors;
    my $total = scalar(@$factors);
    
    my $probability = ($positive / $total) * 100;
    $probability += rand(20) - 10;  # عشوائية إضافية
    
    $probability = 5 if $probability < 5;
    $probability = 95 if $probability > 95;
    
    return int($probability);
}

sub _estimate_attack_time {
    my ($attack_type, $target) = @_;
    
    if ($attack_type eq 'wps') {
        return "5 - 30 دقيقة";
    } elsif ($attack_type eq 'dictionary') {
        return "دقائق إلى أيام (حسب قوة كلمة المرور)";
    } elsif ($attack_type eq 'deauth') {
        return "ثواني";
    } elsif ($attack_type eq 'handshake') {
        return "1 - 10 دقائق";
    } else {
        return "غير محدد";
    }
}

sub _generate_recommendations {
    my ($target, $attack_type) = @_;
    
    my @recs = ();
    
    if ($attack_type eq 'wps' && !$target->{wps_enabled}) {
        push @recs, "قم بتفعيل WPS مؤقتاً للهجوم";
    }
    
    if ($target->{signal} < 50) {
        push @recs, "اقترب أكثر من الراوتر لتحسين قوة الإشارة";
    }
    
    if ($attack_type eq 'dictionary') {
        push @recs, "استخدم قاموساً مخصصاً يحتوي على كلمات مرتبطة بـ SSID";
        push @recs, "جرب هجوماً ذكياً بدلاً من القاموس العادي";
    }
    
    return \@recs;
}

sub _generate_predicted_passwords {
    my ($target, $count) = @_;
    
    my @passwords = ();
    
    # كلمات مرتبطة بـ SSID
    my $ssid = $target->{ssid};
    $ssid =~ s/[^a-zA-Z0-9]//g;
    
    if ($ssid && length($ssid) > 0) {
        push @passwords, $ssid;
        push @passwords, lc($ssid);
        push @passwords, uc($ssid);
        push @passwords, $ssid . "123";
        push @passwords, $ssid . "2024";
        push @passwords, "123" . $ssid;
    }
    
    # كلمات شائعة جداً
    my @common = qw(
        password admin 12345678 qwerty abc123 letmein welcome
        master super hello internet network wifi wireless
    );
    push @passwords, @common;
    
    # كلمات مع أرقام
    for my $year (2020..2025) {
        push @passwords, "admin$year";
        push @passwords, "password$year";
        push @passwords, "wifi$year";
    }
    
    # إزالة التكرار
    my %seen;
    @passwords = grep { !$seen{$_}++ } @passwords;
    
    # أخذ العدد المطلوب
    if (scalar(@passwords) > $count) {
        @passwords = @passwords[0..$count-1];
    }
    
    return \@passwords;
}

sub _calculate_password_probability {
    my ($password, $target) = @_;
    
    my $probability = 0;
    
    # كلمات مرتبطة بـ SSID لها احتمالية أعلى
    my $ssid = $target->{ssid};
    $ssid =~ s/[^a-zA-Z0-9]//g;
    
    if (lc($password) eq lc($ssid)) {
        $probability = 90;
    } elsif ($password =~ /$ssid/i) {
        $probability = 70;
    } elsif (length($password) < 8) {
        $probability = 60;
    } elsif ($password =~ /^[0-9]+$/) {
        $probability = 50;
    } elsif ($password =~ /^(admin|password|123456)/i) {
        $probability = 80;
    } else {
        $probability = int(rand(30)) + 10;
    }
    
    return $probability;
}

sub _probability_bar {
    my ($percent) = @_;
    
    my $filled = int($percent / 10);
    my $empty = 10 - $filled;
    
    return "[" . ("█" x $filled) . ("░" x $empty) . "]";
}

sub _predict_device_count {
    my ($info) = @_;
    return $info->{devices_count} + int(rand(5)) - 2;
}

sub _predict_traffic_pattern {
    my ($info) = @_;
    return $info->{avg_traffic} + int(rand(30)) - 15;
}

sub _predict_peak_hours {
    my ($info) = @_;
    return $info->{peak_hours};
}

sub _predict_anomalies {
    my ($info) = @_;
    
    my @anomalies = ();
    
    if (rand() < 0.3) {
        push @anomalies, "زيادة مفاجئة في حركة المرور متوقعة";
    }
    if (rand() < 0.2) {
        push @anomalies, "جهاز جديد غير معروف قد يتصل";
    }
    
    return \@anomalies;
}

sub _generate_network_recommendations {
    my ($info) = @_;
    
    my @recs = ();
    
    if ($info->{devices_count} > 10) {
        push @recs, "توقع ازدحام - خطط لزيادة سعة الشبكة";
    }
    
    push @recs, "قم بمراقبة حركة المرور خلال ساعات الذروة المتوقعة";
    
    return \@recs;
}

sub _encryption_risk_score {
    my ($encryption) = @_;
    
    my %scores = (
        'WEP' => 25,
        'WPA' => 20,
        'WPA2-TKIP' => 18,
        'WPA2-AES' => 10,
        'WPA3' => 5,
        'None' => 25
    );
    
    return $scores{$encryption} // 15;
}

1;  # نهاية الوحدة
