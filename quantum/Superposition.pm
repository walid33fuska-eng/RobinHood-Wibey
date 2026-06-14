package quantum::Superposition;
# =============================================================================
# Superposition.pm - التراكب الكمي (Quantum Superposition)
# =============================================================================
# الميزات: إنشاء حالات تراكب، توليد احتمالات متعددة، محاكاة الكيوبتات
# =============================================================================

use strict;
use warnings;
use parent 'Exporter';
our @EXPORT_OK = qw(superposition_create superposition_collapse superposition_interfere superposition_entangle);

use lib '.';
use lib::Utils;
use lib::Colors;
use Time::HiRes qw(time);
use File::Slurp qw(write_file);
use List::Util qw(shuffle sum);

# =============================================================================
# إنشاء حالة تراكب كمي
# =============================================================================
sub superposition_create {
    my ($states, $amplitudes, $num_qubits) = @_;
    
    my $color = Colors->new();
    my $utils = Utils->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    🔮 إنشاء التراكب الكمي 🔮                          ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    $num_qubits //= 4;
    $states //= [ map { sprintf("%0${num_qubits}b", $_) } (0..(2**$num_qubits)-1) ];
    $amplitudes //= [ map { 1 / sqrt(2**$num_qubits) } (0..(2**$num_qubits)-1) ];
    
    say "${\($color->info())}[*] إنشاء تراكب كمي بـ $num_qubits كيوبت${\($color->reset())}";
    say "${\($color->info())}[*] عدد الحالات الأساسية: " . scalar(@$states) . "${\($color->reset())}";
    
    my $superposition = {
        type => "quantum_superposition",
        num_qubits => $num_qubits,
        states => $states,
        amplitudes => $amplitudes,
        probabilities => [ map { abs($_) ** 2 } @$amplitudes ],
        created_at => time(),
        collapsed => 0,
        measured_value => undef
    };
    
    # التحقق من تطبيع الحالة
    my $norm = sqrt(sum(map { abs($_) ** 2 } @$amplitudes));
    $superposition->{is_normalized} = abs($norm - 1) < 0.001;
    
    say "\n${\($color->quantum())}📊 حالة التراكب الكمي:${\($color->reset())}";
    say "   → |ψ⟩ = " . _format_superposition($superposition);
    
    say "\n${\($color->info())}📈 الاحتمالات لكل حالة:${\($color->reset())}";
    for my $i (0..$#{$superposition->{states}}) {
        my $prob = $superposition->{probabilities}[$i] * 100;
        my $bar = _probability_bar($prob);
        say "   → |$superposition->{states}[$i]⟩: $prob% $bar";
    }
    
    say "\n${\($color->success())}[✓] تم إنشاء التراكب الكمي بنجاح${\($color->reset())}";
    
    $utils->save_result('superposition_create', {
        num_qubits => $num_qubits,
        states_count => scalar(@$states),
        is_normalized => $superposition->{is_normalized}
    });
    
    return $superposition;
}

# =============================================================================
# انهيار التراكب الكمي
# =============================================================================
sub superposition_collapse {
    my ($superposition, $measure) = @_;
    
    my $color = Colors->new();
    my $utils = Utils->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    💥 انهيار التراكب الكمي 💥                        ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    $superposition //= superposition_create();
    $measure //= 1;
    
    if ($superposition->{collapsed}) {
        say "${\($color->warning())}[!] التراكب قد انهار بالفعل${\($color->reset())}";
        return $superposition;
    }
    
    say "${\($color->info())}[*] قياس التراكب الكمي...${\($color->reset())}";
    
    # اختيار حالة عشوائية حسب الاحتمالات
    my $random = rand();
    my $cumulative = 0;
    my $chosen_index = 0;
    
    for my $i (0..$#{$superposition->{probabilities}}) {
        $cumulative += $superposition->{probabilities}[$i];
        if ($random <= $cumulative) {
            $chosen_index = $i;
            last;
        }
    }
    
    my $measured_state = $superposition->{states}[$chosen_index];
    my $probability = $superposition->{probabilities}[$chosen_index] * 100;
    
    $superposition->{collapsed} = 1;
    $superposition->{measured_value} = $measured_state;
    $superposition->{collapse_time} = time();
    $superposition->{measurement_probability} = $probability;
    
    say "\n${\($color->quantum())}🔬 نتيجة القياس:${\($color->reset())}";
    say "   → الحالة المقاسة: |$measured_state⟩";
    say "   → احتمالية القياس: $probability%";
    
    # إزالة التراكب بعد القياس
    say "\n${\($color->success())}[✓] انهار التراكب إلى حالة محددة${\($color->reset())}";
    
    $utils->save_result('superposition_collapse', {
        measured_state => $measured_state,
        probability => $probability
    });
    
    return $superposition;
}

# =============================================================================
# تداخل التراكبات الكمية
# =============================================================================
sub superposition_interfere {
    my ($superposition1, $superposition2, $interference_type) = @_;
    
    my $color = Colors->new();
    my $utils = Utils->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    🌊 تداخل التراكبات الكمية 🌊                       ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    $superposition1 //= superposition_create(undef, undef, 2);
    $superposition2 //= superposition_create(undef, undef, 2);
    $interference_type //= "constructive";
    
    say "${\($color->info())}[*] تطبيق تداخل $interference_type بين تراكبين${\($color->reset())}";
    
    my $interfered_state = {
        type => "quantum_interference",
        interference_type => $interference_type,
        source1 => $superposition1,
        source2 => $superposition2,
        created_at => time()
    };
    
    # حساب الحالة المتداخلة
    my $new_amplitudes = [];
    my $num_states = scalar(@{$superposition1->{states}});
    
    for my $i (0..$num_states-1) {
        my $amp1 = $superposition1->{amplitudes}[$i];
        my $amp2 = $superposition2->{amplitudes}[$i];
        
        my $new_amp;
        if ($interference_type eq "constructive") {
            $new_amp = $amp1 + $amp2;
        } elsif ($interference_type eq "destructive") {
            $new_amp = $amp1 - $amp2;
        } else {
            $new_amp = ($amp1 + $amp2) / 2;
        }
        
        push @$new_amplitudes, $new_amp;
    }
    
    # إعادة التطبيع
    my $norm = sqrt(sum(map { abs($_) ** 2 } @$new_amplitudes));
    $_ /= $norm for @$new_amplitudes;
    
    $interfered_state->{amplitudes} = $new_amplitudes;
    $interfered_state->{states} = $superposition1->{states};
    $interfered_state->{probabilities} = [ map { abs($_) ** 2 } @$new_amplitudes ];
    
    say "\n${\($color->quantum())}📊 نتيجة التداخل:${\($color->reset())}";
    for my $i (0..$#{$interfered_state->{states}}) {
        my $prob1 = $superposition1->{probabilities}[$i] * 100;
        my $prob2 = $superposition2->{probabilities}[$i] * 100;
        my $new_prob = $interfered_state->{probabilities}[$i] * 100;
        
        say "   → |$interfered_state->{states}[$i]⟩: $prob1% + $prob2% = $new_prob%";
    }
    
    $utils->save_result('superposition_interfere', {
        interference_type => $interference_type,
        result_states => scalar(@{$interfered_state->{states}})
    });
    
    return $interfered_state;
}

# =============================================================================
# تشابك التراكبات الكمية
# =============================================================================
sub superposition_entangle {
    my ($superposition1, $superposition2) = @_;
    
    my $color = Colors->new();
    my $utils = Utils->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    🔗 تشابك التراكبات الكمية 🔗                       ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    $superposition1 //= superposition_create(undef, undef, 1);
    $superposition2 //= superposition_create(undef, undef, 1);
    
    say "${\($color->info())}[*] إنشاء تشابك كمي بين تراكبين${\($color->reset())}";
    
    my $entangled_state = {
        type => "bell_state",
        qubits => [$superposition1, $superposition2],
        bell_type => "Φ⁺",
        created_at => time(),
        is_entangled => 1
    };
    
    # حالات بيل المتشابكة
    my @bell_states = (
        { name => "Φ⁺", formula => "(|00⟩ + |11⟩)/√2" },
        { name => "Φ⁻", formula => "(|00⟩ - |11⟩)/√2" },
        { name => "Ψ⁺", formula => "(|01⟩ + |10⟩)/√2" },
        { name => "Ψ⁻", formula => "(|01⟩ - |10⟩)/√2" }
    );
    
    $entangled_state->{bell_formula} = $bell_states[0]->{formula};
    
    say "\n${\($color->quantum())}🔗 حالة التشابك:${\($color->reset())}";
    say "   → نوع Bell: $entangled_state->{bell_type}";
    say "   → الصيغة: $entangled_state->{bell_formula}";
    say "   → عدد الكيوبتات المتشابكة: 2";
    
    # محاكاة قياس كيوبت واحد يؤثر على الآخر
    say "\n${\($color->info())}[*] محاكاة القياس:${\($color->reset())}";
    my $measure_q1 = rand() < 0.5 ? "0" : "1";
    my $measure_q2 = $measure_q1;  # في حالة Φ⁺، القياسات متطابقة
    
    say "   → قياس الكيوبت الأول: |$measure_q1⟩";
    say "   → قياس الكيوبت الثاني: |$measure_q2⟩ (تأثير التشابك)";
    
    $utils->save_result('superposition_entangle', {
        bell_type => $entangled_state->{bell_type},
        measurement_correlation => "perfect"
    });
    
    return $entangled_state;
}

# =============================================================================
# دوال مساعدة داخلية
# =============================================================================

sub _format_superposition {
    my ($superposition) = @_;
    
    my @terms = ();
    for my $i (0..$#{$superposition->{states}}) {
        my $amp = $superposition->{amplitudes}[$i];
        my $state = $superposition->{states}[$i];
        
        if (abs($amp) > 0.001) {
            my $term = sprintf("%.3f", $amp);
            $term =~ s/\.?0+$//;
            $term = "" if $term eq "1";
            push @terms, "${term}|${state}⟩";
        }
    }
    
    return join(" + ", @terms);
}

sub _probability_bar {
    my ($percent) = @_;
    
    my $filled = int($percent / 10);
    my $empty = 10 - $filled;
    
    return "[" . ("█" x $filled) . ("░" x $empty) . "]";
}

1;  # نهاية الوحدة
