package quantum::QuantumCollapse;
# =============================================================================
# QuantumCollapse.pm - انهيار دالة الموجة الكمية
# =============================================================================
# الميزات: انهيار الاحتمالات، قياس الحالات الكمية، تأثير المراقب
# =============================================================================

use strict;
use warnings;
use parent 'Exporter';
our @EXPORT_OK = qw(collapse_wavefunction measure_state observer_effect quantum_decision);

use lib '.';
use lib::Utils;
use lib::Colors;
use Time::HiRes qw(time);
use File::Slurp qw(write_file);
use List::Util qw(shuffle);

# =============================================================================
# انهيار دالة الموجة
# =============================================================================
sub collapse_wavefunction {
    my ($superposition, $measurement_basis) = @_;
    
    my $color = Colors->new();
    my $utils = Utils->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    💥 انهيار دالة الموجة الكمية 💥                    ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    $superposition //= {
        states => ['0', '1', '2', '3'],
        probabilities => [0.4, 0.3, 0.2, 0.1],
        entangled_with => undef
    };
    
    $measurement_basis //= "standard";
    
    say "${\($color->info())}[*] حالة التراكب قبل القياس:${\($color->reset())}";
    for my $i (0..$#{$superposition->{states}}) {
        my $prob = $superposition->{probabilities}[$i] * 100;
        my $bar = _probability_bar($prob);
        say "   → $superposition->{states}[$i]: $prob% $bar";
    }
    
    # اختيار نتيجة عشوائية حسب الاحتمالات
    my $collapsed_state = _select_state($superposition);
    
    # تأثير القياس
    my $measurement_outcome = {
        original_superposition => $superposition,
        collapsed_state => $collapsed_state,
        measurement_basis => $measurement_basis,
        collapse_time => time(),
        entropy_change => _calculate_entropy_change($superposition)
    };
    
    say "\n${\($color->quantum())}🔬 إجراء القياس...${\($color->reset())}";
    sleep(1);
    
    say "\n${\($color->success())}✓ تم انهيار دالة الموجة!${\($color->reset())}";
    say "   → الحالة الناتجة: ${\($color->quantum())}$collapsed_state${\($color->reset())}";
    say "   → تغير الإنتروبيا: " . sprintf("%.2f", $measurement_outcome->{entropy_change});
    
    $utils->save_result('quantum_collapse', {
        collapsed_state => $collapsed_state,
        measurement_basis => $measurement_basis
    });
    
    return $measurement_outcome;
}

# =============================================================================
# قياس الحالة الكمية
# =============================================================================
sub measure_state {
    my ($quantum_state, $precision) = @_;
    
    my $color = Colors->new();
    my $utils = Utils->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    📐 قياس الحالة الكمية 📐                           ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    $quantum_state //= {
        type => "qubit",
        amplitude => [0.707, 0.707],
        phase => [0, 0]
    };
    
    $precision //= 0.01;
    
    say "${\($color->info())}[*] قياس الحالة الكمية...${\($color->reset())}";
    say "   → نوع الحالة: $quantum_state->{type}";
    say "   → دقة القياس: $precision";
    
    # محاكاة القياس
    my $measurement = {
        value => _perform_measurement($quantum_state),
        probability => _calculate_measurement_probability($quantum_state),
        fidelity => 1 - $precision,
        timestamp => time()
    };
    
    say "\n${\($color->quantum())}📊 نتائج القياس:${\($color->reset())}";
    say "   → القيمة المقاسة: $measurement->{value}";
    say "   → احتمالية النتيجة: " . sprintf("%.1f", $measurement->{probability} * 100) . "%";
    say "   → دقة القياس: " . sprintf("%.1f", $measurement->{fidelity} * 100) . "%";
    
    $utils->save_result('measure_state', {
        measured_value => $measurement->{value},
        probability => $measurement->{probability},
        fidelity => $measurement->{fidelity}
    });
    
    return $measurement;
}

# =============================================================================
# تأثير المراقب
# =============================================================================
sub observer_effect {
    my ($system_state, $observation_strength) = @_;
    
    my $color = Colors->new();
    my $utils = Utils->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    👁️ تأثير المراقب 👁️                               ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    $system_state //= {
        superposition => ['A', 'B', 'C'],
        probabilities => [0.5, 0.3, 0.2]
    };
    
    $observation_strength //= 0.7;
    
    say "${\($color->info())}[*] تأثير المراقب على النظام الكمي...${\($color->reset())}";
    say "   → قوة المراقبة: " . sprintf("%.1f", $observation_strength * 100) . "%";
    
    # حساب الحالة قبل المراقبة
    my $before_entropy = _calculate_entropy($system_state->{probabilities});
    
    # تأثير المراقب يغير الاحتمالات
    my $modified_state = _apply_observer_effect($system_state, $observation_strength);
    
    # حساب الحالة بعد المراقبة
    my $after_entropy = _calculate_entropy($modified_state->{probabilities});
    
    say "\n${\($color->quantum())}📊 تغيرات النظام:${\($color->reset())}";
    say "   → الإنتروبيا قبل المراقبة: " . sprintf("%.3f", $before_entropy);
    say "   → الإنتروبيا بعد المراقبة: " . sprintf("%.3f", $after_entropy);
    say "   → تغير الإنتروبيا: " . sprintf("%.3f", $after_entropy - $before_entropy);
    
    say "\n${\($color->info())}🎯 الاحتمالات بعد تأثير المراقب:${\($color->reset())}";
    for my $i (0..$#{$modified_state->{states}}) {
        my $prob = $modified_state->{probabilities}[$i] * 100;
        my $before_prob = $system_state->{probabilities}[$i] * 100;
        my $diff = $prob - $before_prob;
        my $diff_color = $diff > 0 ? $color->success() : $color->error();
        say "   → $modified_state->{states}[$i]: $prob% (${\($diff_color)}$diff%${\($color->reset())})";
    }
    
    $utils->save_result('observer_effect', {
        before_entropy => $before_entropy,
        after_entropy => $after_entropy,
        entropy_change => $after_entropy - $before_entropy
    });
    
    return $modified_state;
}

# =============================================================================
# القرار الكمي
# =============================================================================
sub quantum_decision {
    my ($options, $strategy) = @_;
    
    my $color = Colors->new();
    my $utils = Utils->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    🎲 القرار الكمي 🎲                                ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    $options //= [
        { name => "هجوم WPS", value => 90 },
        { name => "هجوم القاموس", value => 70 },
        { name => "PMKID Attack", value => 85 },
        { name => "Evil Twin", value => 95 }
    ];
    
    $strategy //= "probability";
    
    say "${\($color->info())}[*] اتخاذ قرار كمي باستخدام استراتيجية: $strategy${\($color->reset())}";
    
    # تحويل الخيارات إلى حالة تراكب كمي
    my $superposition = _options_to_superposition($options);
    
    # قياس الحالة الكمية للحصول على القرار
    my $decision;
    
    if ($strategy eq "probability") {
        $decision = collapse_wavefunction($superposition);
        $decision = $decision->{collapsed_state};
    } elsif ($strategy eq "superposition") {
        $decision = _superposition_decision($superposition);
    } else {
        $decision = _max_value_decision($options);
    }
    
    say "\n${\($color->success())}🎯 القرار الكمي: ${\($color->quantum())}$decision${\($color->reset())}";
    
    $utils->save_result('quantum_decision', {
        strategy => $strategy,
        decision => $decision
    });
    
    return $decision;
}

# =============================================================================
# دوال مساعدة داخلية
# =============================================================================

sub _select_state {
    my ($superposition) = @_;
    
    my $random = rand();
    my $cumulative = 0;
    
    for my $i (0..$#{$superposition->{states}}) {
        $cumulative += $superposition->{probabilities}[$i];
        if ($random <= $cumulative) {
            return $superposition->{states}[$i];
        }
    }
    
    return $superposition->{states}[-1];
}

sub _calculate_entropy_change {
    my ($superposition) = @_;
    
    my $entropy = 0;
    for my $prob (@{$superposition->{probabilities}}) {
        if ($prob > 0) {
            $entropy -= $prob * log($prob);
        }
    }
    
    # بعد الانهيار، الإنتروبيا تصبح 0 (حالة محددة)
    return -$entropy;
}

sub _calculate_entropy {
    my ($probabilities) = @_;
    
    my $entropy = 0;
    for my $prob (@$probabilities) {
        if ($prob > 0) {
            $entropy -= $prob * log($prob);
        }
    }
    
    return $entropy;
}

sub _perform_measurement {
    my ($state) = @_;
    
    # محاكاة القياس
    my $random = rand();
    if ($random < 0.5) {
        return "0";
    } else {
        return "1";
    }
}

sub _calculate_measurement_probability {
    my ($state) = @_;
    
    # محاكاة حساب الاحتمالية
    return 0.5 + (rand() * 0.3);
}

sub _apply_observer_effect {
    my ($state, $strength) = @_;
    
    my $new_probabilities = [];
    
    for my $i (0..$#{$state->{probabilities}}) {
        # تأثير المراقب يزيد من احتمالية الحالة الأكثر ترجيحاً
        my $enhancement = 1 + ($strength * (1 - $i / scalar(@{$state->{probabilities}})));
        $new_probabilities->[$i] = $state->{probabilities}[$i] * $enhancement;
    }
    
    # تطبيع الاحتمالات
    my $sum = 0;
    $sum += $_ for @$new_probabilities;
    $_ /= $sum for @$new_probabilities;
    
    return {
        states => $state->{superposition},
        probabilities => $new_probabilities
    };
}

sub _options_to_superposition {
    my ($options) = @_;
    
    my $states = [];
    my $probabilities = [];
    
    # حساب الوزن الكلي
    my $total = 0;
    for my $opt (@$options) {
        $total += $opt->{value};
    }
    
    for my $opt (@$options) {
        push @$states, $opt->{name};
        push @$probabilities, $opt->{value} / $total;
    }
    
    return {
        states => $states,
        probabilities => $probabilities
    };
}

sub _superposition_decision {
    my ($superposition) = @_;
    
    # اختيار عشوائي مرجح
    my $random = rand();
    my $cumulative = 0;
    
    for my $i (0..$#{$superposition->{states}}) {
        $cumulative += $superposition->{probabilities}[$i];
        if ($random <= $cumulative) {
            return $superposition->{states}[$i];
        }
    }
    
    return $superposition->{states}[-1];
}

sub _max_value_decision {
    my ($options) = @_;
    
    my @sorted = sort { $b->{value} <=> $a->{value} } @$options;
    return $sorted[0]->{name};
}

sub _probability_bar {
    my ($percent) = @_;
    
    my $filled = int($percent / 10);
    my $empty = 10 - $filled;
    
    return "[" . ("█" x $filled) . ("░" x $empty) . "]";
}

1;  # نهاية الوحدة
