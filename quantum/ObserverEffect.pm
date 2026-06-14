package quantum::ObserverEffect;
# =============================================================================
# ObserverEffect.pm - تأثير المراقب في ميكانيكا الكم
# =============================================================================
# الميزات: محاكاة تأثير المراقب، تغيير السلوك عند القياس، تطبيقات في الاختراق
# =============================================================================

use strict;
use warnings;
use parent 'Exporter';
our @EXPORT_OK = qw(observer_apply observer_measure observer_avoid observer_attack);

use lib '.';
use lib::Utils;
use lib::Colors;
use Time::HiRes qw(time);
use File::Slurp qw(write_file);
use List::Util qw(shuffle);

# =============================================================================
# تطبيق تأثير المراقب
# =============================================================================
sub observer_apply {
    my ($quantum_system, $observation_strength) = @_;
    
    my $color = Colors->new();
    my $utils = Utils->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    👁️ تطبيق تأثير المراقب 👁️                          ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    $quantum_system //= {
        type => "superposition",
        states => ["0", "1"],
        probabilities => [0.5, 0.5],
        coherence => 1.0
    };
    $observation_strength //= 0.5;
    
    say "${\($color->info())}[*] تطبيق تأثير المراقب بقوة $observation_strength${\($color->reset())}";
    
    my $original_coherence = $quantum_system->{coherence};
    
    # تأثير المراقب يقلل الترابط الكمي
    my $new_coherence = $original_coherence * (1 - $observation_strength);
    $new_coherence = 0 if $new_coherence < 0;
    
    # تأثير المراقب يغير الاحتمالات (تأثير القياس الجزئي)
    my $new_probabilities = [];
    for my $i (0..$#{$quantum_system->{probabilities}}) {
        my $prob = $quantum_system->{probabilities}[$i];
        # المراقب يزيد احتمالية الحالة الأكثر ترجيحاً
        if ($prob > 0.5) {
            $prob += $observation_strength * (1 - $prob);
        } else {
            $prob -= $observation_strength * $prob;
        }
        push @$new_probabilities, $prob;
    }
    
    # تطبيع الاحتمالات
    my $sum = 0;
    $sum += $_ for @$new_probabilities;
    $_ /= $sum for @$new_probabilities;
    
    my $result = {
        original_system => $quantum_system,
        observation_strength => $observation_strength,
        original_coherence => $original_coherence,
        new_coherence => $new_coherence,
        original_probabilities => $quantum_system->{probabilities},
        new_probabilities => $new_probabilities,
        entropy_change => _calculate_entropy_change($quantum_system->{probabilities}, $new_probabilities),
        collapsed_partially => $observation_strength > 0.7
    };
    
    say "\n${\($color->quantum())}📊 تأثير المراقب:${\($color->reset())}";
    say "   → الترابط الكمي: $original_coherence → " . sprintf("%.3f", $new_coherence);
    say "   → تغير الإنتروبيا: " . sprintf("%.3f", $result->{entropy_change});
    
    say "\n${\($color->info())}🎯 تغير الاحتمالات:${\($color->reset())}";
    for my $i (0..$#{$quantum_system->{states}}) {
        my $state = $quantum_system->{states}[$i];
        my $old_prob = $quantum_system->{probabilities}[$i] * 100;
        my $new_prob = $new_probabilities->[$i] * 100;
        my $diff = $new_prob - $old_prob;
        my $diff_color = $diff > 0 ? $color->success() : $color->error();
        say "   → |$state⟩: $old_prob% → $new_prob% (${\($diff_color)}$diff%${\($color->reset())})";
    }
    
    if ($result->{collapsed_partially}) {
        say "\n${\($color->warning())}⚠️ مراقبة قوية: النظام في حالة انهيار جزئي${\($color->reset())}";
    }
    
    $utils->save_result('observer_effect', {
        observation_strength => $observation_strength,
        coherence_change => $original_coherence - $new_coherence,
        entropy_change => $result->{entropy_change}
    });
    
    return $result;
}

# =============================================================================
# قياس مع تأثير المراقب
# =============================================================================
sub observer_measure {
    my ($system, $measurement_type, $observer_awareness) = @_;
    
    my $color = Colors->new();
    my $utils = Utils->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    📐 قياس مع تأثير المراقب 📐                        ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    $system //= {
        type => "quantum_state",
        value => rand(),
        is_superposition => 1
    };
    $measurement_type //= "strong";
    $observer_awareness //= 0.8;
    
    say "${\($color->info())}[*] قياس $measurement_type للنظام${\($color->reset())}";
    say "   → وعي المراقب: " . sprintf("%.1f", $observer_awareness * 100) . "%";
    
    my $measurement_result;
    my $disturbance;
    
    if ($measurement_type eq "strong") {
        # قياس قوي ينهار النظام تماماً
        $measurement_result = $system->{value};
        $disturbance = 1.0;
        $system->{is_superposition} = 0;
        
    } elsif ($measurement_type eq "weak") {
        # قياس ضعيف يغير النظام قليلاً
        $measurement_result = $system->{value} + (rand() * 0.1 - 0.05);
        $disturbance = 0.3;
        $system->{is_superposition} = 1;
        
    } else {
        # قياس متوسط
        $measurement_result = $system->{value} + (rand() * 0.3 - 0.15);
        $disturbance = 0.6;
        $system->{is_superposition} = rand() < 0.5;
    }
    
    # تأثير وعي المراقب على النتيجة
    if ($observer_awareness > 0.7) {
        $measurement_result = $system->{value};  # مراقب واعٍ يحصل على قيمة أدق
        $disturbance *= 0.5;
    }
    
    say "\n${\($color->quantum())}🔬 نتائج القياس:${\($color->reset())}";
    say "   → القيمة المقاسة: " . sprintf("%.4f", $measurement_result);
    say "   → القيمة الحقيقية: " . sprintf("%.4f", $system->{value});
    say "   → الإزعاج الكمي: " . sprintf("%.1f", $disturbance * 100) . "%";
    
    # مبدأ عدم اليقين لهايزنبرغ
    my $uncertainty = $disturbance * (1 - $observer_awareness);
    say "\n${\($color->info())}⚠️ مبدأ عدم اليقين: Δx·Δp ≥ " . sprintf("%.4f", $uncertainty);
    
    $utils->save_result('observer_measure', {
        measurement_type => $measurement_type,
        disturbance => $disturbance,
        uncertainty => $uncertainty
    });
    
    return {
        measured_value => $measurement_result,
        disturbance => $disturbance,
        system_after => $system,
        uncertainty => $uncertainty
    };
}

# =============================================================================
# تجنب تأثير المراقب
# =============================================================================
sub observer_avoid {
    my ($attack_context, $stealth_techniques) = @_;
    
    my $color = Colors->new();
    my $utils = Utils->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    🕵️ تجنب تأثير المراقب 🕵️                          ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    $attack_context //= {
        target_visibility => 0.7,
        monitoring_level => 0.5,
        previous_alerts => 0
    };
    
    $stealth_techniques //= [
        "quantum_stealth", "measurement_delay", "noise_injection", "decoherence"
    ];
    
    say "${\($color->info())}[*] تطبيق تقنيات تجنب المراقب:${\($color->reset())}";
    for my $tech (@$stealth_techniques) {
        say "   → $tech";
    }
    
    my $effectiveness = 0;
    my $technique_results = [];
    
    for my $tech (@$stealth_techniques) {
        my $tech_effectiveness;
        
        if ($tech eq "quantum_stealth") {
            $tech_effectiveness = 0.85;
        } elsif ($tech eq "measurement_delay") {
            $tech_effectiveness = 0.60;
        } elsif ($tech eq "noise_injection") {
            $tech_effectiveness = 0.70;
        } elsif ($tech eq "decoherence") {
            $tech_effectiveness = 0.50;
        } else {
            $tech_effectiveness = 0.40;
        }
        
        push @$technique_results, {
            technique => $tech,
            effectiveness => $tech_effectiveness
        };
        
        $effectiveness = 1 - (1 - $effectiveness) * (1 - $tech_effectiveness);
    }
    
    # تطبيق تأثير السياق
    my $final_visibility = $attack_context->{target_visibility} * (1 - $effectiveness);
    my $detection_probability = $final_visibility * $attack_context->{monitoring_level};
    
    say "\n${\($color->success())}📊 فعالية التخفي:${\($color->reset())}";
    say "   → فعالية التقنيات: " . sprintf("%.1f", $effectiveness * 100) . "%";
    say "   → الرؤية النهائية: " . sprintf("%.1f", $final_visibility * 100) . "%";
    say "   → احتمالية الاكتشاف: " . sprintf("%.1f", $detection_probability * 100) . "%";
    
    my $risk_level;
    if ($detection_probability > 0.7) {
        $risk_level = "مرتفع جداً";
    } elsif ($detection_probability > 0.4) {
        $risk_level = "متوسط";
    } else {
        $risk_level = "منخفض";
    }
    
    say "   → مستوى المخاطرة: $risk_level";
    
    $utils->save_result('observer_avoid', {
        effectiveness => $effectiveness,
        detection_probability => $detection_probability,
        risk_level => $risk_level
    });
    
    return {
        effectiveness => $effectiveness,
        final_visibility => $final_visibility,
        detection_probability => $detection_probability,
        techniques => $technique_results
    };
}

# =============================================================================
# هجوم تأثير المراقب
# =============================================================================
sub observer_attack {
    my ($target, $attack_intensity) = @_;
    
    my $color = Colors->new();
    my $utils = Utils->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    ⚡ هجوم تأثير المراقب ⚡                           ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    $target //= {
        type => "wifi_network",
        encryption => "WPA2",
        sensitivity => 0.6
    };
    $attack_intensity //= 0.7;
    
    say "${\($color->info())}[*] تنفيذ هجوم تأثير المراقب على $target->{type}${\($color->reset())}";
    say "   → شدة الهجوم: " . sprintf("%.1f", $attack_intensity * 100) . "%";
    say "   → حساسية الهدف: " . sprintf("%.1f", $target->{sensitivity} * 100) . "%";
    
    # الهجوم يعتمد على مراقبة النظام وانهياره
    my $attack_success = 0;
    my $detection_risk = 0;
    
    if ($attack_intensity > 0.8) {
        # هجوم قوي - احتمالية نجاح عالية لكن اكتشاف مرتفع
        $attack_success = 0.9;
        $detection_risk = 0.8;
    } elsif ($attack_intensity > 0.5) {
        $attack_success = 0.7;
        $detection_risk = 0.5;
    } else {
        $attack_success = 0.4;
        $detection_risk = 0.3;
    }
    
    # تعديل حسب حساسية الهدف
    $attack_success *= (1 - $target->{sensitivity});
    $detection_risk *= (1 + $target->{sensitivity});
    
    $attack_success = 1 if $attack_success > 1;
    $detection_risk = 1 if $detection_risk > 1;
    
    # استخراج المعلومات بعد الانهيار
    my $extracted_info = "";
    if ($attack_success > 0.5) {
        $extracted_info = _extract_quantum_info($target);
    }
    
    say "\n${\($color->quantum())}🔮 نتائج الهجوم:${\($color->reset())}";
    say "   → نجاح الهجوم: " . sprintf("%.1f", $attack_success * 100) . "%";
    say "   → خطر الاكتشاف: " . sprintf("%.1f", $detection_risk * 100) . "%";
    
    if ($extracted_info) {
        say "   → معلومات مستخرجة: $extracted_info";
    }
    
    # تقييم المخاطرة
    my $net_gain = $attack_success - $detection_risk;
    my $recommendation;
    
    if ($net_gain > 0.3) {
        $recommendation = "يوصى بتنفيذ الهجوم";
    } elsif ($net_gain > 0) {
        $recommendation = "هجوم ممكن مع مخاطرة متوسطة";
    } else {
        $recommendation = "لا يوصى بالهجوم - المخاطرة أعلى من الفائدة";
    }
    
    say "\n${\($color->info())}💡 التوصية: $recommendation${\($color->reset())}";
    
    $utils->save_result('observer_attack', {
        attack_intensity => $attack_intensity,
        success_rate => $attack_success,
        detection_risk => $detection_risk,
        net_gain => $net_gain
    });
    
    return {
        success => $attack_success,
        detection_risk => $detection_risk,
        extracted_info => $extracted_info,
        recommendation => $recommendation
    };
}

# =============================================================================
# دوال مساعدة داخلية
# =============================================================================

sub _calculate_entropy_change {
    my ($old_probs, $new_probs) = @_;
    
    my $old_entropy = 0;
    for my $p (@$old_probs) {
        $old_entropy -= $p * log($p) if $p > 0;
    }
    
    my $new_entropy = 0;
    for my $p (@$new_probs) {
        $new_entropy -= $p * log($p) if $p > 0;
    }
    
    return $new_entropy - $old_entropy;
}

sub _extract_quantum_info {
    my ($target) = @_;
    
    my @info = ("مفتاح التشفير", "كلمة المرور", "بيانات المصادقة", "إعدادات الشبكة");
    return $info[int(rand(@info))];
}

1;  # نهاية الوحدة
