package advanced::DecisionEngine;
# =============================================================================
# DecisionEngine.pm - محرك اتخاذ القرارات الذكي
# =============================================================================
# الميزات: تحليل الخيارات، تقييم المخاطر، اتخاذ القرار الأمثل، التعلم من النتائج
# =============================================================================

use strict;
use warnings;
use parent 'Exporter';
our @EXPORT_OK = qw(decide_best_action evaluate_options risk_assessment learn_decision);

use lib '.';
use lib::Utils;
use lib::Colors;
use Time::HiRes qw(time);
use File::Slurp qw(write_file);
use List::Util qw(max min);

# =============================================================================
# اتخاذ أفضل قرار
# =============================================================================
sub decide_best_action {
    my ($options, $context) = @_;
    
    my $color = Colors->new();
    my $utils = Utils->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    🧠 محرك اتخاذ القرارات 🧠                         ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    $options //= [
        { name => "هجوم WPS", success_rate => 70, risk => 30, time => 30, resources => 2 },
        { name => "هجوم القاموس", success_rate => 50, risk => 20, time => 60, resources => 3 },
        { name => "هجوم Evil Twin", success_rate => 85, risk => 60, time => 120, resources => 5 },
        { name => "PMKID Attack", success_rate => 65, risk => 15, time => 10, resources => 1 },
        { name => "التقاط المصافحة", success_rate => 80, risk => 25, time => 15, resources => 2 }
    ];
    
    $context //= {
        urgency => "high",
        available_time => 60,
        stealth_required => 1,
        available_resources => 4
    };
    
    say "${\($color->info())}[*] تحليل السياق الحالي:${\($color->reset())}";
    say "   → الإلحاح: $context->{urgency}";
    say "   → الوقت المتاح: $context->{available_time} دقيقة";
    say "   → مطلوب تخفي: " . ($context->{stealth_required} ? "نعم" : "لا");
    say "   → الموارد المتاحة: $context->{available_resources}";
    
    # تقييم جميع الخيارات
    my $evaluated_options = _evaluate_options($options, $context);
    
    # اختيار أفضل خيار
    my $best_choice = _select_best_option($evaluated_options);
    
    # عرض النتائج
    say "\n${\($color->success())}📊 تقييم الخيارات:${\($color->reset())}";
    for my $opt (@$evaluated_options) {
        my $color_score = $opt->{total_score} >= 80 ? $color->success() :
                          ($opt->{total_score} >= 60 ? $color->info() : $color->warning());
        say "   → $opt->{name}: درجة ${\($color_score)}$opt->{total_score}%${\($color->reset())} (نجاح: $opt->{success_rate}%, خطر: $opt->{risk}%, وقت: $opt->{time} دقيقة)";
    }
    
    say "\n${\($color->quantum())}🎯 القرار الموصى به: ${\($color->success())}$best_choice->{name}${\($color->reset())}";
    say "   → نسبة النجاح المتوقعة: $best_choice->{success_rate}%";
    say "   → مستوى المخاطرة: $best_choice->{risk}%";
    say "   → الوقت المقدر: $best_choice->{time} دقيقة";
    say "   → سبب الاختيار: $best_choice->{reason}";
    
    $utils->save_result('decision_engine', {
        best_action => $best_choice->{name},
        total_options => scalar(@$options),
        best_score => $best_choice->{total_score}
    });
    
    return $best_choice;
}

# =============================================================================
# تقييم الخيارات المتاحة
# =============================================================================
sub evaluate_options {
    my ($options, $weights) = @_;
    
    my $color = Colors->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    📊 تقييم الخيارات 📊                              ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    $options //= [
        { name => "الخيار أ", success_rate => 80, cost => 30, time => 20 },
        { name => "الخيار ب", success_rate => 60, cost => 20, time => 15 },
        { name => "الخيار ج", success_rate => 90, cost => 50, time => 40 }
    ];
    
    $weights //= {
        success_rate => 0.5,
        cost => 0.3,
        time => 0.2
    };
    
    my @evaluated = ();
    
    for my $opt (@$options) {
        my $score = ($opt->{success_rate} * $weights->{success_rate}) +
                    ((100 - $opt->{cost}) * $weights->{cost}) +
                    ((100 - $opt->{time}) * $weights->{time});
        
        push @evaluated, {
            name => $opt->{name},
            success_rate => $opt->{success_rate},
            cost => $opt->{cost},
            time => $opt->{time},
            total_score => int($score)
        };
    }
    
    # ترتيب حسب الدرجة
    my @sorted = sort { $b->{total_score} <=> $a->{total_score} } @evaluated;
    
    say "\n${\($color->success())}🏆 ترتيب الخيارات:${\($color->reset())}";
    for my $i (0..$#sorted) {
        my $opt = $sorted[$i];
        my $score_color = $opt->{total_score} >= 80 ? $color->success() :
                          ($opt->{total_score} >= 60 ? $color->info() : $color->warning());
        say "   " . ($i+1) . ". $opt->{name} - درجة: ${\($score_color)}$opt->{total_score}%${\($color->reset())}";
    }
    
    return \@sorted;
}

# =============================================================================
# تقييم المخاطر
# =============================================================================
sub risk_assessment {
    my ($action, $environment_factors) = @_;
    
    my $color = Colors->new();
    my $utils = Utils->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    ⚠️ تقييم المخاطر ⚠️                               ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    $action //= {
        name => "هجوم WPS",
        detection_probability => 40,
        failure_consequence => 60,
        collateral_damage => 30
    };
    
    $environment_factors //= {
        network_security => "medium",
        admin_activity => "low",
        monitoring_level => "medium",
        time_of_day => "night"
    };
    
    say "${\($color->info())}[*] تحليل مخاطر $action->{name}:${\($color->reset())}";
    say "   → احتمالية الاكتشاف: $action->{detection_probability}%";
    say "   → عواقب الفشل: $action->{failure_consequence}%";
    say "   → الأضرار الجانبية: $action->{collateral_damage}%";
    
    # تعديل المخاطر حسب البيئة
    my $risk_adjustment = 0;
    if ($environment_factors->{network_security} eq 'high') {
        $risk_adjustment += 20;
        say "   → ↑ الشبكة عالية الأمان (+20% خطر)";
    }
    if ($environment_factors->{admin_activity} eq 'high') {
        $risk_adjustment += 25;
        say "   → ↑ نشاط إداري مرتفع (+25% خطر)";
    }
    if ($environment_factors->{monitoring_level} eq 'high') {
        $risk_adjustment += 30;
        say "   → ↑ مراقبة مكثفة (+30% خطر)";
    }
    if ($environment_factors->{time_of_day} eq 'night') {
        $risk_adjustment -= 15;
        say "   → ↓ وقت الليل (-15% خطر)";
    }
    
    my $total_risk = $action->{detection_probability} * 0.4 +
                     $action->{failure_consequence} * 0.35 +
                     $action->{collateral_damage} * 0.25;
    $total_risk += $risk_adjustment;
    $total_risk = min(100, max(0, $total_risk));
    
    my $risk_level;
    my $risk_color;
    if ($total_risk >= 70) {
        $risk_level = "مرتفع جداً";
        $risk_color = $color->error();
    } elsif ($total_risk >= 50) {
        $risk_level = "مرتفع";
        $risk_color = $color->warning();
    } elsif ($total_risk >= 30) {
        $risk_level = "متوسط";
        $risk_color = $color->info();
    } else {
        $risk_level = "منخفض";
        $risk_color = $color->success();
    }
    
    say "\n${\($color->success())}📊 نتيجة تقييم المخاطر:${\($color->reset())}";
    say "   → درجة المخاطرة الإجمالية: ${\($risk_color)}$total_risk% ($risk_level)${\($color->reset())}";
    
    # توصيات
    my @recommendations = ();
    if ($total_risk > 60) {
        push @recommendations, "يوصى بتأجيل الهجوم إلى وقت أقل خطورة";
        push @recommendations, "استخدام تقنيات تخفي إضافية";
    } elsif ($total_risk > 40) {
        push @recommendations, "توخ الحذر والمراقبة المستمرة";
    } else {
        push @recommendations, "الظروف مناسبة للهجوم";
    }
    
    say "\n${\($color->info())}💡 التوصيات:${\($color->reset())}";
    for my $rec (@recommendations) {
        say "   → $rec";
    }
    
    $utils->save_result('risk_assessment', {
        action => $action->{name},
        total_risk => $total_risk,
        risk_level => $risk_level,
        recommendations => \@recommendations
    });
    
    return {
        risk_score => $total_risk,
        risk_level => $risk_level,
        recommendations => \@recommendations
    };
}

# =============================================================================
# التعلم من القرارات
# =============================================================================
sub learn_decision {
    my ($decision, $outcome) = @_;
    
    my $color = Colors->new();
    my $utils = Utils->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    📚 التعلم من القرارات 📚                          ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    $decision //= {
        action => "هجوم WPS",
        expected_success => 70,
        expected_time => 30
    };
    
    $outcome //= {
        success => 1,
        actual_time => 25,
        difficulties => []
    };
    
    say "${\($color->info())}[*] تسجيل نتيجة القرار:${\($color->reset())}";
    say "   → القرار: $decision->{action}";
    say "   → النتيجة: " . ($outcome->{success} ? "نجاح ✓" : "فشل ✗");
    say "   → الوقت المتوقع: $decision->{expected_time} دقيقة";
    say "   → الوقت الفعلي: $outcome->{actual_time} دقيقة";
    
    # حساب الدقة
    my $accuracy = 0;
    if ($outcome->{success}) {
        $accuracy = 100 - abs($decision->{expected_time} - $outcome->{actual_time}) / $decision->{expected_time} * 100;
        $accuracy = max(0, min(100, $accuracy));
    } else {
        $accuracy = 0;
    }
    
    # حفظ في قاعدة التعلم
    my $learning_data = {
        timestamp => time(),
        decision => $decision,
        outcome => $outcome,
        accuracy => $accuracy
    };
    
    my $learning_file = "$ENV{HOME}/.robinhood/logs/decision_learning.json";
    my $history = [];
    if (-f $learning_file) {
        local $/;
        open(my $fh, '<', $learning_file);
        my $json = <$fh>;
        close($fh);
        eval { $history = decode_json($json); };
    }
    push @$history, $learning_data;
    
    # الاحتفاظ بآخر 100 قرار فقط
    if (scalar(@$history) > 100) {
        shift @$history;
    }
    
    write_file($learning_file, encode_json($history));
    
    # حساب متوسط الدقة
    my $total_accuracy = 0;
    for my $record (@$history) {
        $total_accuracy += $record->{accuracy};
    }
    my $avg_accuracy = $total_accuracy / scalar(@$history);
    
    say "\n${\($color->success())}📈 إحصائيات التعلم:${\($color->reset())}";
    say "   → دقة هذا القرار: " . sprintf("%.1f", $accuracy) . "%";
    say "   → متوسط الدقة الكلي: " . sprintf("%.1f", $avg_accuracy) . "%";
    say "   → عدد القرارات المسجلة: " . scalar(@$history);
    
    $utils->save_result('decision_learning', {
        decision_accuracy => $accuracy,
        average_accuracy => $avg_accuracy,
        total_decisions => scalar(@$history)
    });
    
    return {
        accuracy => $accuracy,
        history_count => scalar(@$history),
        average_accuracy => $avg_accuracy
    };
}

# =============================================================================
# دوال مساعدة داخلية
# =============================================================================

sub _evaluate_options {
    my ($options, $context) = @_;
    
    my @evaluated = ();
    
    for my $opt (@$options) {
        my $score = 0;
        
        # عامل نجاح الهجوم
        $score += $opt->{success_rate} * 0.4;
        
        # عامل المخاطرة (كلما قلت المخاطرة كان أفضل)
        $score += (100 - $opt->{risk}) * 0.3;
        
        # عامل الوقت (كلما قل الوقت كان أفضل)
        if ($context->{available_time} >= $opt->{time}) {
            $score += 100 * 0.2;
        } else {
            $score += (100 - ($opt->{time} - $context->{available_time}) / $opt->{time} * 100) * 0.2;
        }
        
        # عامل الموارد
        if ($context->{available_resources} >= $opt->{resources}) {
            $score += 100 * 0.1;
        } else {
            $score += (100 - ($opt->{resources} - $context->{available_resources}) / $opt->{resources} * 100) * 0.1;
        }
        
        push @evaluated, {
            name => $opt->{name},
            success_rate => $opt->{success_rate},
            risk => $opt->{risk},
            time => $opt->{time},
            resources => $opt->{resources},
            total_score => int($score)
        };
    }
    
    return \@evaluated;
}

sub _select_best_option {
    my ($options) = @_;
    
    my @sorted = sort { $b->{total_score} <=> $a->{total_score} } @$options;
    my $best = $sorted[0];
    
    # تحديد سبب الاختيار
    my $reason = "";
    if ($best->{success_rate} >= 80) {
        $reason = "أعلى نسبة نجاح متوقعة ($best->{success_rate}%)";
    } elsif ($best->{risk} <= 20) {
        $reason = "أقل مستوى مخاطرة ($best->{risk}%)";
    } elsif ($best->{time} <= 30) {
        $reason = "أسرع وقت تنفيذ ($best->{time} دقيقة)";
    } else {
        $reason = "أفضل توازن بين العوامل المختلفة";
    }
    
    $best->{reason} = $reason;
    
    return $best;
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
    return [];
}

1;  # نهاية الوحدة
