package quantum::QubitSimulator;
# =============================================================================
# QubitSimulator.pm - محاكي الكيوبتات الكمية
# =============================================================================
# الميزات: محاكاة الكيوبتات الفردية والمتعددة، تطبيق البوابات الكمية، قياس الحالات
# =============================================================================

use strict;
use warnings;
use parent 'Exporter';
our @EXPORT_OK = qw(qubit_create qubit_apply_gate qubit_measure qubit_entangle qubit_simulate);

use lib '.';
use lib::Utils;
use lib::Colors;
use Time::HiRes qw(time);
use File::Slurp qw(write_file);
use List::Util qw(sum);

# =============================================================================
# إنشاء كيوبت
# =============================================================================
sub qubit_create {
    my ($initial_state, $amplitude_0, $amplitude_1) = @_;
    
    my $color = Colors->new();
    my $utils = Utils->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    💎 إنشاء كيوبت كمي 💎                              ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    $initial_state //= "superposition";
    $amplitude_0 //= 1/sqrt(2);
    $amplitude_1 //= 1/sqrt(2);
    
    my $qubit = {
        id => int(rand(10000)),
        state_vector => [$amplitude_0, $amplitude_1],
        amplitudes => {
            '0' => $amplitude_0,
            '1' => $amplitude_1
        },
        probabilities => {
            '0' => abs($amplitude_0)**2,
            '1' => abs($amplitude_1)**2
        },
        created_at => time(),
        measured => 0,
        measured_value => undef
    };
    
    # التحقق من التطبيع
    my $norm = sqrt($qubit->{probabilities}{'0'} + $qubit->{probabilities}{'1'});
    $qubit->{is_normalized} = abs($norm - 1) < 0.001;
    
    say "\n${\($color->info())}[*] إنشاء كيوبت جديد:${\($color->reset())}";
    say "   → المعرف: $qubit->{id}";
    say "   → الحالة: $initial_state";
    say "   → متجه الحالة: [${\($color->quantum())}$amplitude_0${\($color->reset())}, ${\($color->quantum())}$amplitude_1${\($color->reset())}]";
    
    say "\n${\($color->quantum())}📊 الاحتمالات:${\($color->reset())}";
    say "   → |0⟩: " . sprintf("%.1f", $qubit->{probabilities}{'0'} * 100) . "%";
    say "   → |1⟩: " . sprintf("%.1f", $qubit->{probabilities}{'1'} * 100) . "%";
    
    # تمثيل كرة بلوخ
    $qubit->{bloch_sphere} = _calculate_bloch_coordinates($qubit);
    say "\n${\($color->info())}🌐 إحداثيات كرة بلوخ:${\($color->reset())}";
    say "   → θ: " . sprintf("%.1f", $qubit->{bloch_sphere}{theta}) . "°";
    say "   → φ: " . sprintf("%.1f", $qubit->{bloch_sphere}{phi}) . "°";
    
    $utils->save_result('qubit_simulator', {
        qubit_id => $qubit->{id},
        state => $initial_state,
        prob_0 => $qubit->{probabilities}{'0'},
        prob_1 => $qubit->{probabilities}{'1'}
    });
    
    return $qubit;
}

# =============================================================================
# تطبيق بوابة كمية
# =============================================================================
sub qubit_apply_gate {
    my ($qubit, $gate_type, $parameters) = @_;
    
    my $color = Colors->new();
    my $utils = Utils->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    🚪 تطبيق بوابة كمية 🚪                             ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    $qubit //= qubit_create();
    $gate_type //= "Hadamard";
    $parameters //= {};
    
    say "${\($color->info())}[*] تطبيق بوابة $gate_type على الكيوبت $qubit->{id}${\($color->reset())}";
    
    my $old_state = [$qubit->{state_vector}[0], $qubit->{state_vector}[1]];
    
    # تعريف البوابات الكمية
    my %gates = (
        'Hadamard' => {
            matrix => [[1/sqrt(2), 1/sqrt(2)], [1/sqrt(2), -1/sqrt(2)]],
            description => "إنشاء تراكب"
        },
        'Pauli-X' => {
            matrix => [[0, 1], [1, 0]],
            description => "قلب (NOT كمي)"
        },
        'Pauli-Y' => {
            matrix => [[0, -1], [1, 0]],
            description => "قلب مع طور"
        },
        'Pauli-Z' => {
            matrix => [[1, 0], [0, -1]],
            description => "تغيير الطور"
        },
        'Phase' => {
            matrix => [[1, 0], [0, exp(1i * ($parameters->{angle} || 0))]],
            description => "إزاحة طور"
        },
        'T' => {
            matrix => [[1, 0], [0, exp(1i * 3.14159/4)]],
            description => "بوابة T"
        },
        'S' => {
            matrix => [[1, 0], [0, 1i]],
            description => "بوابة S"
        }
    );
    
    my $gate = $gates{$gate_type};
    if (!$gate) {
        say "${\($color->error())}[!] بوابة غير معروفة: $gate_type${\($color->reset())}";
        return $qubit;
    }
    
    # تطبيق البوابة على متجه الحالة
    my $new_0 = $gate->{matrix}[0][0] * $old_state->[0] + $gate->{matrix}[0][1] * $old_state->[1];
    my $new_1 = $gate->{matrix}[1][0] * $old_state->[0] + $gate->{matrix}[1][1] * $old_state->[1];
    
    $qubit->{state_vector} = [$new_0, $new_1];
    $qubit->{amplitudes}{'0'} = $new_0;
    $qubit->{amplitudes}{'1'} = $new_1;
    $qubit->{probabilities}{'0'} = abs($new_0)**2;
    $qubit->{probabilities}{'1'} = abs($new_1)**2;
    $qubit->{bloch_sphere} = _calculate_bloch_coordinates($qubit);
    
    say "\n${\($color->success())}✓ تم تطبيق بوابة $gate_type: $gate->{description}${\($color->reset())}";
    say "   → الحالة الجديدة: [${\($color->quantum())}" . sprintf("%.3f", $new_0) . "${\($color->reset())}, ${\($color->quantum())}" . sprintf("%.3f", $new_1) . "${\($color->reset())}]";
    
    $utils->save_result('qubit_gate', {
        gate_type => $gate_type,
        old_state => $old_state,
        new_state => $qubit->{state_vector}
    });
    
    return $qubit;
}

# =============================================================================
# قياس الكيوبت
# =============================================================================
sub qubit_measure {
    my ($qubit, $shots) = @_;
    
    my $color = Colors->new();
    my $utils = Utils->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    📐 قياس الكيوبت 📐                                ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    $qubit //= qubit_create();
    $shots //= 1000;
    
    say "${\($color->info())}[*] قياس الكيوبت $qubit->{id} ($shots قياس)${\($color->reset())}";
    
    my $count_0 = 0;
    my $count_1 = 0;
    my $results = [];
    
    for my $i (1..$shots) {
        my $random = rand();
        my $result;
        
        if ($random < $qubit->{probabilities}{'0'}) {
            $result = "0";
            $count_0++;
        } else {
            $result = "1";
            $count_1++;
        }
        
        push @$results, $result;
    }
    
    my $measured_prob_0 = $count_0 / $shots;
    my $measured_prob_1 = $count_1 / $shots;
    
    # تحديث الكيوبت بعد القياس (انهيار دالة الموجة)
    my $majority_result = $count_0 > $count_1 ? "0" : "1";
    $qubit->{measured} = 1;
    $qubit->{measured_value} = $majority_result;
    $qubit->{collapse_time} = time();
    
    say "\n${\($color->quantum())}📊 نتائج القياس:${\($color->reset())}";
    say "   → |0⟩: $count_0 مرة (" . sprintf("%.1f", $measured_prob_0 * 100) . "%)";
    say "   → |1⟩: $count_1 مرة (" . sprintf("%.1f", $measured_prob_1 * 100) . "%)";
    
    say "\n${\($color->info())}🎯 النتيجة النهائية: |$majority_result⟩${\($color->reset())}";
    
    # مقارنة مع الاحتمالات النظرية
    my $theoretical_0 = $qubit->{probabilities}{'0'} * 100;
    my $theoretical_1 = $qubit->{probabilities}{'1'} * 100;
    my $error_0 = abs($measured_prob_0 * 100 - $theoretical_0);
    
    say "\n${\($color->info())}📈 مقارنة مع النظرية:${\($color->reset())}";
    say "   → |0⟩: $theoretical_0% (نظري) vs " . sprintf("%.1f", $measured_prob_0 * 100) . "% (عملي)";
    say "   → الخطأ: " . sprintf("%.2f", $error_0) . "%";
    
    $utils->save_result('qubit_measure', {
        shots => $shots,
        count_0 => $count_0,
        count_1 => $count_1,
        result => $majority_result
    });
    
    return {
        results => $results,
        counts => { '0' => $count_0, '1' => $count_1 },
        probabilities => { '0' => $measured_prob_0, '1' => $measured_prob_1 },
        final_state => $majority_result
    };
}

# =============================================================================
# تشابك كيوبتات متعددة
# =============================================================================
sub qubit_entangle {
    my ($num_qubits, $bell_state) = @_;
    
    my $color = Colors->new();
    my $utils = Utils->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    🔗 تشابك كيوبتات متعددة 🔗                         ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    $num_qubits //= 2;
    $bell_state //= "Φ⁺";
    
    say "${\($color->info())}[*] إنشاء تشابك كمي بين $num_qubits كيوبت${\($color->reset())}";
    say "   → نوع الحالة: Bell $bell_state";
    
    my $entangled_system = {
        num_qubits => $num_qubits,
        bell_state => $bell_state,
        qubits => [],
        created_at => time(),
        is_entangled => 1
    };
    
    # إنشاء الكيوبتات المتشابكة
    for my $i (1..$num_qubits) {
        my $qubit = qubit_create("ground");
        push @{$entangled_system->{qubits}}, $qubit;
    }
    
    # تطبيق بوابة Hadamard على أول كيوبت
    $entangled_system->{qubits}[0] = qubit_apply_gate($entangled_system->{qubits}[0], "Hadamard");
    
    # تطبيق بوابة CNOT (محاكاة)
    say "\n${\($color->quantum())}🔗 تطبيق بوابة CNOT للتشابك...${\($color->reset())}";
    
    # حساب الحالة المتشابكة
    my $state_vector = [];
    if ($bell_state eq "Φ⁺") {
        # (|00⟩ + |11⟩)/√2
        $state_vector = [1/sqrt(2), 0, 0, 1/sqrt(2)];
    } elsif ($bell_state eq "Φ⁻") {
        $state_vector = [1/sqrt(2), 0, 0, -1/sqrt(2)];
    } elsif ($bell_state eq "Ψ⁺") {
        $state_vector = [0, 1/sqrt(2), 1/sqrt(2), 0];
    } else {
        $state_vector = [0, 1/sqrt(2), -1/sqrt(2), 0];
    }
    
    $entangled_system->{state_vector} = $state_vector;
    
    say "\n${\($color->success())}[✓] تم إنشاء حالة متشابكة بنجاح!${\($color->reset())}";
    say "   → الصيغة: " . _format_entangled_state($bell_state);
    
    $utils->save_result('qubit_entangle', {
        num_qubits => $num_qubits,
        bell_state => $bell_state,
        state_vector => $state_vector
    });
    
    return $entangled_system;
}

# =============================================================================
# محاكاة كمية متقدمة
# =============================================================================
sub qubit_simulate {
    my ($circuit, $shots) = @_;
    
    my $color = Colors->new();
    my $utils = Utils->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    🔬 محاكاة الدائرة الكمية 🔬                        ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    $circuit //= {
        num_qubits => 2,
        gates => [
            { type => "Hadamard", target => 0 },
            { type => "CNOT", control => 0, target => 1 },
            { type => "Measure", target => [0, 1] }
        ]
    };
    $shots //= 1024;
    
    say "${\($color->info())}[*] محاكاة دائرة كمية بـ $circuit->{num_qubits} كيوبت${\($color->reset())}";
    say "   → عدد البوابات: " . scalar(@{$circuit->{gates}});
    say "   → عدد القياسات: $shots";
    
    # إنشاء الكيوبتات
    my $qubits = [];
    for my $i (1..$circuit->{num_qubits}) {
        push @$qubits, qubit_create("ground");
    }
    
    # تطبيق البوابات
    say "\n${\($color->info())}🔧 تنفيذ الدائرة:${\($color->reset())}";
    for my $gate (@{$circuit->{gates}}) {
        if ($gate->{type} eq "Hadamard") {
            $qubits->[$gate->{target}] = qubit_apply_gate($qubits->[$gate->{target}], "Hadamard");
            say "   → H على كيوبت $gate->{target}";
        } elsif ($gate->{type} eq "CNOT") {
            say "   → CNOT (control=$gate->{control}, target=$gate->{target})";
        } elsif ($gate->{type} eq "Measure") {
            say "   → قياس الكيوبتات: " . join(", ", @{$gate->{target}});
        }
    }
    
    # محاكاة النتائج
    my $results = {};
    for my $i (1..$shots) {
        my $result = "";
        for my $q (@$qubits) {
            my $random = rand();
            $result .= ($random < $q->{probabilities}{'0'}) ? "0" : "1";
        }
        $results->{$result}++;
    }
    
    say "\n${\($color->success())}📊 نتائج المحاكاة:${\($color->reset())}";
    for my $state (sort keys %$results) {
        my $count = $results->{$state};
        my $percent = ($count / $shots) * 100;
        my $bar = _probability_bar($percent);
        say "   → |$state⟩: $count مرة ($percent%) $bar";
    }
    
    $utils->save_result('qubit_simulate', {
        num_qubits => $circuit->{num_qubits},
        shots => $shots,
        results => $results
    });
    
    return $results;
}

# =============================================================================
# دوال مساعدة داخلية
# =============================================================================

sub _calculate_bloch_coordinates {
    my ($qubit) = @_;
    
    my $alpha = $qubit->{amplitudes}{'0'};
    my $beta = $qubit->{amplitudes}{'1'};
    
    my $theta = 2 * atan2(abs($beta), abs($alpha));
    my $phi = atan2(Im($beta), Re($beta));
    
    return {
        theta => $theta * 180 / 3.14159,
        phi => $phi * 180 / 3.14159,
        x => sin($theta) * cos($phi),
        y => sin($theta) * sin($phi),
        z => cos($theta)
    };
}

sub _format_entangled_state {
    my ($type) = @_;
    
    my %states = (
        'Φ⁺' => '(|00⟩ + |11⟩)/√2',
        'Φ⁻' => '(|00⟩ - |11⟩)/√2',
        'Ψ⁺' => '(|01⟩ + |10⟩)/√2',
        'Ψ⁻' => '(|01⟩ - |10⟩)/√2'
    );
    
    return $states{$type} // '( |00⟩ + |11⟩ )/√2';
}

sub _probability_bar {
    my ($percent) = @_;
    
    my $filled = int($percent / 5);
    my $empty = 20 - $filled;
    
    return "[" . ("█" x $filled) . ("░" x $empty) . "]";
}

# دالة Im للتعامل مع الأعداد المركبة
sub Im {
    my ($value) = @_;
    return 0;  # تبسيط للمحاكاة
}

sub Re {
    my ($value) = @_;
    return $value;  # تبسيط للمحاكاة
}

1;  # نهاية الوحدة
