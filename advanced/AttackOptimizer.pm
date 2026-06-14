package advanced::AttackOptimizer;
# =============================================================================
# AttackOptimizer.pm - محسن الهجمات (تحسين الأداء وزيادة الفعالية)
# =============================================================================
# الميزات: تحسين معلمات الهجوم، ضبط السرعة، تقليل الاكتشاف، زيادة النجاح
# =============================================================================

use strict;
use warnings;
use parent 'Exporter';
our @EXPORT_OK = qw(optimize_attack_parameters optimize_speed optimize_stealth optimize_success_rate);

use lib '.';
use lib::Utils;
use lib::Colors;
use Time::HiRes qw(sleep time);
use File::Slurp qw(write_file);
use List::Util qw(min max);

# =============================================================================
# تحسين معلمات الهجوم
# =============================================================================
sub optimize_attack_parameters {
    my ($attack_type, $environment) = @_;
    
    my $color = Colors->new();
    my $utils = Utils->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    ⚙️ تحسين معلمات الهجوم ⚙️                          ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    $attack_type //= "wps";
    $environment //= {
        signal_strength => 65,
        interference_level => 30,
        target_responsiveness => "normal",
        network_density => "medium"
    };
    
    say "${\($color->info())}[*] نوع الهجوم: $attack_type${\($color->reset())}";
    say "${\($color->info())}[*] البيئة المحيطة:${\($color->reset())}";
    say "   → قوة الإشارة: $environment->{signal_strength}%";
    say "   → مستوى التداخل: $environment->{interference_level}%";
    say "   → كثافة الشبكة: $environment->{network_density}";
    
    my $optimized_params = _optimize_for_environment($attack_type, $environment);
    
    say "\n${\($color->success())}📊 المعلمات المحسنة:${\($color->reset())}";
    for my $param (@$optimized_params) {
        say "   → $param->{name}: $param->{old_value} → ${\($color->quantum())}$param->{new_value}${\($color->reset())} (تحسين: +$param->{improvement}%)";
    }
    
    $utils->save_result('attack_optimizer', {
        attack_type => $attack_type,
        params_count => scalar(@$optimized_params),
        improvements => [map { $_->{improvement} } @$optimized_params]
    });
    
    return $optimized_params;
}

# =============================================================================
# تحسين السرعة
# =============================================================================
sub optimize_speed {
    my ($current_speed, $target_metrics) = @_;
    
    my $color = Colors->new();
    my $utils = Utils->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    🚀 تحسين السرعة 🚀                                ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    $current_speed //= 100;  # حزمة/ثانية
    $target_metrics //= {
        max_speed => 500,
        stability => 90,
        latency => 50
    };
    
    say "${\($color->info())}[*] السرعة الحالية: $current_speed حزمة/ثانية${\($color->reset())}";
    say "${\($color->info())}[*] السرعة المستهدفة: $target_metrics->{max_speed} حزمة/ثانية${\($color->reset())}";
    
    my $speed_optimization = {
        original_speed => $current_speed,
        optimized_speed => 0,
        improvements => [],
        estimated_gain => 0
    };
    
    # حساب التحسينات الممكنة
    if ($current_speed < $target_metrics->{max_speed}) {
        my $potential_increase = $target_metrics->{max_speed} - $current_speed;
        my $safe_increase = min($potential_increase, 200);  # حد أقصى للزيادة الآمنة
        
        $speed_optimization->{optimized_speed} = $current_speed + $safe_increase;
        $speed_optimization->{estimated_gain} = ($safe_increase / $current_speed) * 100;
        
        push @{$speed_optimization->{improvements}}, {
            action => "زيادة معدل إرسال الحزم",
            gain => $safe_increase,
            new_speed => $speed_optimization->{optimized_speed}
        };
        
        # تحسينات إضافية
        push @{$speed_optimization->{improvements}}, {
            action => "تفعيل المعالجة المتوازية",
            gain => 30,
            new_speed => $speed_optimization->{optimized_speed} + 30
        };
        
        push @{$speed_optimization->{improvements}}, {
            action => "تقليل التأخير بين الحزم",
            gain => 20,
            new_speed => $speed_optimization->{optimized_speed} + 50
        };
    }
    
    $speed_optimization->{optimized_speed} = min($speed_optimization->{optimized_speed}, $target_metrics->{max_speed});
    
    # عرض النتائج
    say "\n${\($color->success())}⚡ نتائج تحسين السرعة:${\($color->reset())}";
    say "   → السرعة الأصلية: $current_speed حزمة/ثانية";
    say "   → السرعة المحسنة: $speed_optimization->{optimized_speed} حزمة/ثانية";
    say "   → التحسين: +" . sprintf("%.1f", $speed_optimization->{estimated_gain}) . "%";
    
    say "\n${\($color->info())}🔧 التحسينات المطبقة:${\($color->reset())}";
    for my $imp (@{$speed_optimization->{improvements}}) {
        say "   → $imp->{action}: +$imp->{gain} حزمة/ثانية";
    }
    
    $utils->save_result('speed_optimization', {
        original_speed => $current_speed,
        optimized_speed => $speed_optimization->{optimized_speed},
        gain_percentage => $speed_optimization->{estimated_gain}
    });
    
    return $speed_optimization;
}

# =============================================================================
# تحسين التخفي (تقليل الاكتشاف)
# =============================================================================
sub optimize_stealth {
    my ($stealth_level, $detection_risk) = @_;
    
    my $color = Colors->new();
    my $utils = Utils->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    🕵️ تحسين التخفي 🕵️                               ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    $stealth_level //= 50;
    $detection_risk //= 60;
    
    say "${\($color->info())}[*] مستوى التخفي الحالي: $stealth_level%${\($color->reset())}";
    say "${\($color->info())}[*] خطر الاكتشاف الحالي: $detection_risk%${\($color->reset())}";
    
    my $stealth_optimization = {
        original_stealth => $stealth_level,
        optimized_stealth => 0,
        risk_reduction => 0,
        techniques => []
    };
    
    # تقنيات تحسين التخفي
    my @stealth_techniques = (
        { name => "تغيير MAC عشوائي", stealth_gain => 15, risk_reduction => 20 },
        { name => "تبديل القنوات بشكل عشوائي", stealth_gain => 10, risk_reduction => 15 },
        { name => "إرسال حزم وهمية للتشتيت", stealth_gain => 20, risk_reduction => 25 },
        { name => "تأخير عشوائي بين الحزم", stealth_gain => 25, risk_reduction => 30 },
        { name => "تجزئة الهجوم على فترات", stealth_gain => 30, risk_reduction => 35 }
    );
    
    my $total_stealth_gain = 0;
    my $total_risk_reduction = 0;
    
    # اختيار التقنيات المناسبة
    for my $technique (@stealth_techniques) {
        if ($stealth_level + $total_stealth_gain < 95) {
            push @{$stealth_optimization->{techniques}}, $technique;
            $total_stealth_gain += $technique->{stealth_gain};
            $total_risk_reduction += $technique->{risk_reduction};
        }
    }
    
    $stealth_optimization->{optimized_stealth} = min(95, $stealth_level + $total_stealth_gain);
    $stealth_optimization->{risk_reduction} = min(90, $detection_risk - $total_risk_reduction / 2);
    $stealth_optimization->{risk_reduction} = max(5, $stealth_optimization->{risk_reduction});
    
    # عرض النتائج
    say "\n${\($color->success())}🕵️ نتائج تحسين التخفي:${\($color->reset())}";
    say "   → مستوى التخفي: $stealth_level% → $stealth_optimization->{optimized_stealth}%";
    say "   → خطر الاكتشاف: $detection_risk% → $stealth_optimization->{risk_reduction}%";
    
    say "\n${\($color->info())}🎭 التقنيات المطبقة:${\($color->reset())}";
    for my $tech (@{$stealth_optimization->{techniques}}) {
        say "   → $tech->{name}: +$tech->{stealth_gain}% تخفي, -$tech->{risk_reduction}% اكتشاف";
    }
    
    $utils->save_result('stealth_optimization', {
        original_stealth => $stealth_level,
        optimized_stealth => $stealth_optimization->{optimized_stealth},
        risk_reduction => $stealth_optimization->{risk_reduction}
    });
    
    return $stealth_optimization;
}

# =============================================================================
# تحسين نسبة النجاح
# =============================================================================
sub optimize_success_rate {
    my ($current_rate, $failure_reasons) = @_;
    
    my $color = Colors->new();
    my $utils = Utils->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    🎯 تحسين نسبة النجاح 🎯                           ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    $current_rate //= 30;
    $failure_reasons //= [
        "إشارة ضعيفة",
        "WPS محمي",
        "كلمة مرور قوية",
        "وقت غير مناسب"
    ];
    
    say "${\($color->info())}[*] نسبة النجاح الحالية: $current_rate%${\($color->reset())}";
    say "${\($color->info())}[*] أسباب الفشل المكتشفة:${\($color->reset())}";
    for my $reason (@$failure_reasons) {
        say "   → $reason";
    }
    
    my $success_optimization = {
        original_rate => $current_rate,
        optimized_rate => 0,
        improvements => [],
        expected_rate => 0
    };
    
    # تحسينات لكل سبب فشل
    my @improvements = ();
    
    if (grep { $_ eq "إشارة ضعيفة" } @$failure_reasons) {
        push @improvements, {
            action => "تحسين قوة الإشارة بالاقتراب من الراوتر",
            expected_gain => 25
        };
    }
    
    if (grep { $_ eq "WPS محمي" } @$failure_reasons) {
        push @improvements, {
            action => "استخدام هجوم Pixie Dust بدلاً من PIN العادي",
            expected_gain => 40
        };
    }
    
    if (grep { $_ eq "كلمة مرور قوية" } @$failure_reasons) {
        push @improvements, {
            action => "توسيع قاموس الهجوم بكلمات مرتبطة بالهدف",
            expected_gain => 20
        };
        push @improvements, {
            action => "استخدام هجوم Evil Twin بدلاً من القاموس",
            expected_gain => 35
        };
    }
    
    if (grep { $_ eq "وقت غير مناسب" } @$failure_reasons) {
        push @improvements, {
            action => "الهجوم خلال ساعات النشاط المنخفض (2-5 صباحاً)",
            expected_gain => 30
        };
    }
    
    # حساب التحسين الإجمالي
    my $total_gain = 0;
    my $applied_count = 0;
    
    for my $imp (@improvements) {
        if ($applied_count < 3) {  # حد أقصى 3 تحسينات
            push @{$success_optimization->{improvements}}, $imp;
            $total_gain += $imp->{expected_gain};
            $applied_count++;
        }
    }
    
    $success_optimization->{optimized_rate} = min(95, $current_rate + $total_gain);
    $success_optimization->{expected_rate} = $success_optimization->{optimized_rate};
    
    # عرض النتائج
    say "\n${\($color->success())}📈 نتائج تحسين نسبة النجاح:${\($color->reset())}";
    say "   → النسبة الحالية: $current_rate%";
    say "   → النسبة المتوقعة بعد التحسين: $success_optimization->{optimized_rate}%";
    say "   → التحسين المتوقع: +" . sprintf("%.1f", $success_optimization->{optimized_rate} - $current_rate) . "%";
    
    say "\n${\($color->info())}💡 التحسينات المقترحة:${\($color->reset())}";
    for my $imp (@{$success_optimization->{improvements}}) {
        say "   → $imp->{action}: متوقع +$imp->{expected_gain}%";
    }
    
    $utils->save_result('success_optimization', {
        original_rate => $current_rate,
        optimized_rate => $success_optimization->{optimized_rate},
        improvements_count => scalar(@{$success_optimization->{improvements}})
    });
    
    return $success_optimization;
}

# =============================================================================
# دوال مساعدة داخلية
# =============================================================================

sub _optimize_for_environment {
    my ($attack_type, $env) = @_;
    
    my @params = ();
    
    if ($attack_type eq 'wps') {
        push @params, {
            name => "وقت الانتظار بين المحاولات",
            old_value => "2 ثانية",
            new_value => "1 ثانية",
            improvement => 50
        };
        push @params, {
            name => "عدد المحاولات المتوازية",
            old_value => 1,
            new_value => 4,
            improvement => 75
        };
    }
    
    if ($attack_type eq 'dictionary') {
        push @params, {
            name => "حجم القاموس",
            old_value => "10,000 كلمة",
            new_value => "50,000 كلمة",
            improvement => 60
        };
    }
    
    if ($env->{interference_level} > 40) {
        push @params, {
            name => "معدل إعادة الإرسال",
            old_value => 1,
            new_value => 3,
            improvement => 40
        };
    }
    
    if ($env->{signal_strength} < 50) {
        push @params, {
            name => "مضخم الإشارة",
            old_value => "لا",
            new_value => "نعم",
            improvement => 80
        };
    }
    
    return \@params;
}

1;  # نهاية الوحدة
