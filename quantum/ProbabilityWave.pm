package quantum::ProbabilityWave;
# =============================================================================
# ProbabilityWave.pm - موجة الاحتمالات الكمية
# =============================================================================
# الميزات: محاكاة موجات الاحتمال، تداخل الموجات، قياس الاحتمالات، توزيع الكثافة
# =============================================================================

use strict;
use warnings;
use parent 'Exporter';
our @EXPORT_OK = qw(prob_wave_create prob_wave_interfere prob_wave_measure prob_wave_collapse);

use lib '.';
use lib::Utils;
use lib::Colors;
use Time::HiRes qw(time);
use File::Slurp qw(write_file);
use List::Util qw(sum);

# =============================================================================
# إنشاء موجة احتمالية
# =============================================================================
sub prob_wave_create {
    my ($wave_function, $domain) = @_;
    
    my $color = Colors->new();
    my $utils = Utils->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    🌊 إنشاء موجة احتمالية 🌊                          ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    $wave_function //= "gaussian";
    $domain //= { min => -10, max => 10, points => 100 };
    
    say "${\($color->info())}[*] إنشاء موجة احتمالية من نوع: $wave_function${\($color->reset())}";
    say "   → المجال: [$domain->{min}, $domain->{max}]";
    say "   → عدد النقاط: $domain->{points}";
    
    my $wave = {
        type => $wave_function,
        domain => $domain,
        points => [],
        probabilities => [],
        amplitude => [],
        created_at => time(),
        normalized => 0
    };
    
    # توليد نقاط الموجة
    my $dx = ($domain->{max} - $domain->{min}) / $domain->{points};
    my $total_prob = 0;
    
    for my $i (0..$domain->{points}) {
        my $x = $domain->{min} + $i * $dx;
        my $amplitude;
        
        if ($wave_function eq "gaussian") {
            $amplitude = exp(-($x**2) / 2) / (2 * 3.14159)**0.25;
        } elsif ($wave_function eq "sine") {
            $amplitude = sin($x) / sqrt(2);
        } elsif ($wave_function eq "cosine") {
            $amplitude = cos($x) / sqrt(2);
        } elsif ($wave_function eq "plane") {
            $amplitude = 1 / sqrt($domain->{max} - $domain->{min});
        } else {
            $amplitude = rand();
        }
        
        my $probability = $amplitude**2;
        $total_prob += $probability * $dx;
        
        push @{$wave->{points}}, { x => $x, amplitude => $amplitude, probability => $probability };
        push @{$wave->{amplitude}}, $amplitude;
        push @{$wave->{probabilities}}, $probability;
    }
    
    # تطبيع الموجة
    if (abs($total_prob - 1) > 0.01) {
        my $norm_factor = sqrt($total_prob);
        for my $point (@{$wave->{points}}) {
            $point->{amplitude} /= $norm_factor;
            $point->{probability} = $point->{amplitude}**2;
        }
        $wave->{normalized} = 1;
        say "\n${\($color->info())}[*] تم تطبيع الموجة (عامل: " . sprintf("%.3f", $norm_factor) . ")${\($color->reset())}";
    }
    
    # عرض الموجة
    _display_wave($wave);
    
    # حساب الإنتروبيا
    my $entropy = _calculate_wave_entropy($wave);
    $wave->{entropy} = $entropy;
    
    say "\n${\($color->success())}📊 خصائص الموجة:${\($color->reset())}";
    say "   → الإنتروبيا الكمية: " . sprintf("%.3f", $entropy);
    say "   → الطاقة المتوقعة: " . sprintf("%.3f", _calculate_expected_energy($wave));
    say "   → الانحراف المعياري: " . sprintf("%.3f", _calculate_stddev($wave));
    
    $utils->save_result('probability_wave', {
        wave_type => $wave_function,
        points => scalar(@{$wave->{points}}),
        entropy => $entropy,
        normalized => $wave->{normalized}
    });
    
    return $wave;
}

# =============================================================================
# تداخل موجات الاحتمال
# =============================================================================
sub prob_wave_interfere {
    my ($wave1, $wave2, $interference_type) = @_;
    
    my $color = Colors->new();
    my $utils = Utils->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    🌊 تداخل موجات الاحتمال 🌊                        ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    $wave1 //= prob_wave_create("gaussian");
    $wave2 //= prob_wave_create("sine");
    $interference_type //= "constructive";
    
    say "${\($color->info())}[*] تطبيق تداخل $interference_type بين موجتين${\($color->reset())}";
    
    my $interfered_wave = {
        type => "interference",
        interference_type => $interference_type,
        source1 => $wave1,
        source2 => $wave2,
        points => [],
        created_at => time()
    };
    
    my $dx = ($wave1->{domain}{max} - $wave1->{domain}{min}) / $wave1->{domain}{points};
    
    for my $i (0..$wave1->{domain}{points}) {
        my $amp1 = $wave1->{amplitude}[$i];
        my $amp2 = $wave2->{amplitude}[$i];
        my $x = $wave1->{points}[$i]{x};
        
        my $result_amplitude;
        if ($interference_type eq "constructive") {
            $result_amplitude = $amp1 + $amp2;
        } elsif ($interference_type eq "destructive") {
            $result_amplitude = $amp1 - $amp2;
        } else {
            $result_amplitude = ($amp1 + $amp2) / 2;
        }
        
        my $probability = $result_amplitude**2;
        
        push @{$interfered_wave->{points}}, {
            x => $x,
            amplitude => $result_amplitude,
            probability => $probability
        };
        push @{$interfered_wave->{amplitude}}, $result_amplitude;
        push @{$interfered_wave->{probabilities}}, $probability;
    }
    
    # إعادة التطبيع
    my $total_prob = sum(@{$interfered_wave->{probabilities}}) * $dx;
    my $norm_factor = sqrt($total_prob);
    
    for my $point (@{$interfered_wave->{points}}) {
        $point->{amplitude} /= $norm_factor;
        $point->{probability} = $point->{amplitude}**2;
    }
    
    say "\n${\($color->quantum())}🔮 نتيجة التداخل:${\($color->reset())}";
    say "   → نوع التداخل: $interference_type";
    say "   → نقاط التداخل: " . scalar(@{$interfered_wave->{points}});
    
    # عرض نمط التداخل
    _display_interference_pattern($interfered_wave);
    
    $utils->save_result('prob_wave_interfere', {
        interference_type => $interference_type,
        points => scalar(@{$interfered_wave->{points}}),
        norm_factor => $norm_factor
    });
    
    return $interfered_wave;
}

# =============================================================================
# قياس موجة الاحتمال
# =============================================================================
sub prob_wave_measure {
    my ($wave, $num_measurements) = @_;
    
    my $color = Colors->new();
    my $utils = Utils->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    📐 قياس موجة الاحتمال 📐                           ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    $wave //= prob_wave_create("gaussian");
    $num_measurements //= 1000;
    
    say "${\($color->info())}[*] إجراء $num_measurements قياس على الموجة${\($color->reset())}";
    
    my $measurements = [];
    my $histogram = {};
    
    for my $i (1..$num_measurements) {
        # اختيار نقطة عشوائية وفقاً لتوزيع الاحتمال
        my $random = rand();
        my $cumulative = 0;
        my $selected_point = undef;
        
        for my $point (@{$wave->{points}}) {
            $cumulative += $point->{probability};
            if ($random <= $cumulative) {
                $selected_point = $point;
                last;
            }
        }
        
        push @$measurements, $selected_point->{x};
        $histogram->{sprintf("%.1f", $selected_point->{x})}++;
    }
    
    # حساب متوسط القياسات
    my $avg = sum(@$measurements) / $num_measurements;
    my $variance = 0;
    for my $x (@$measurements) {
        $variance += ($x - $avg)**2;
    }
    $variance /= $num_measurements;
    
    say "\n${\($color->quantum())}📊 نتائج القياس:${\($color->reset())}";
    say "   → متوسط القياسات: " . sprintf("%.3f", $avg);
    say "   → التباين: " . sprintf("%.3f", $variance);
    say "   → الانحراف المعياري: " . sprintf("%.3f", sqrt($variance));
    
    # عرض التوزيع
    say "\n${\($color->info())}📈 توزيع القياسات:${\($color->reset())}";
    my @sorted = sort { $a <=> $b } keys %$histogram;
    for my $bin (@sorted[0..9]) {
        my $count = $histogram->{$bin};
        my $percent = ($count / $num_measurements) * 100;
        my $bar = _probability_bar($percent);
        say "   → $bin: $count مرة ($percent%) $bar";
    }
    
    $utils->save_result('prob_wave_measure', {
        measurements => $num_measurements,
        average => $avg,
        variance => $variance,
        stddev => sqrt($variance)
    });
    
    return {
        measurements => $measurements,
        average => $avg,
        variance => $variance,
        histogram => $histogram
    };
}

# =============================================================================
# انهيار موجة الاحتمال
# =============================================================================
sub prob_wave_collapse {
    my ($wave, $measurement_result) = @_;
    
    my $color = Colors->new();
    my $utils = Utils->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    💥 انهيار موجة الاحتمال 💥                         ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    $wave //= prob_wave_create("gaussian");
    $measurement_result //= undef;
    
    # إذا لم يتم تحديد نتيجة، اختر نقطة عشوائية
    if (!$measurement_result) {
        my $random = rand();
        my $cumulative = 0;
        for my $point (@{$wave->{points}}) {
            $cumulative += $point->{probability};
            if ($random <= $cumulative) {
                $measurement_result = $point->{x};
                last;
            }
        }
    }
    
    say "${\($color->info())}[*] انهيار الموجة عند القياس x = $measurement_result${\($color->reset())}";
    
    # إنشاء موجة جديدة بعد الانهيار (دالة ديراك delta)
    my $collapsed_wave = {
        type => "collapsed",
        measurement => $measurement_result,
        points => [],
        collapsed_at => time(),
        original_entropy => _calculate_wave_entropy($wave)
    };
    
    my $dx = ($wave->{domain}{max} - $wave->{domain}{min}) / $wave->{domain}{points};
    my $delta_amplitude = 1 / sqrt($dx);
    
    for my $point (@{$wave->{points}}) {
        my $amplitude = abs($point->{x} - $measurement_result) < $dx/2 ? $delta_amplitude : 0;
        my $probability = $amplitude**2;
        
        push @{$collapsed_wave->{points}}, {
            x => $point->{x},
            amplitude => $amplitude,
            probability => $probability
        };
    }
    
    my $new_entropy = _calculate_wave_entropy($collapsed_wave);
    $collapsed_wave->{entropy} = $new_entropy;
    
    say "\n${\($color->quantum())}📊 تغير الإنتروبيا:${\($color->reset())}";
    say "   → الإنتروبيا قبل الانهيار: " . sprintf("%.3f", $collapsed_wave->{original_entropy});
    say "   → الإنتروبيا بعد الانهيار: " . sprintf("%.3f", $new_entropy);
    say "   → التغير: " . sprintf("%.3f", $new_entropy - $collapsed_wave->{original_entropy});
    
    $utils->save_result('prob_wave_collapse', {
        measurement => $measurement_result,
        original_entropy => $collapsed_wave->{original_entropy},
        new_entropy => $new_entropy
    });
    
    return $collapsed_wave;
}

# =============================================================================
# دوال مساعدة داخلية
# =============================================================================

sub _display_wave {
    my ($wave) = @_;
    
    my $color = Colors->new();
    
    say "\n${\($color->quantum())}📈 تمثيل الموجة:${\($color->reset())}";
    
    # رسم بسيط للموجة
    my $height = 20;
    my $width = 60;
    my @points = @{$wave->{points}};
    
    # إيجاد القيم القصوى للرسم
    my $max_amp = 0;
    for my $point (@points) {
        $max_amp = $point->{amplitude} if $point->{amplitude} > $max_amp;
    }
    
    for my $row (reverse(0..$height)) {
        my $line = "";
        for my $col (0..$width-1) {
            my $idx = int($col * scalar(@points) / $width);
            my $amp = $points[$idx]{amplitude};
            my $normalized_amp = $amp / $max_amp;
            my $row_val = $row / $height;
            
            if (abs($normalized_amp - $row_val) < 0.05) {
                $line .= "█";
            } else {
                $line .= " ";
            }
        }
        say "   $line";
    }
}

sub _display_interference_pattern {
    my ($wave) = @_;
    
    my $color = Colors->new();
    
    say "\n${\($color->quantum())}🔮 نمط التداخل:${\($color->reset())}";
    
    my $width = 60;
    my @points = @{$wave->{points}};
    
    # إيجاد القيم القصوى
    my $max_prob = 0;
    for my $point (@points) {
        $max_prob = $point->{probability} if $point->{probability} > $max_prob;
    }
    
    my $line = "";
    for my $col (0..$width-1) {
        my $idx = int($col * scalar(@points) / $width);
        my $prob = $points[$idx]{probability};
        my $normalized = $prob / $max_prob;
        
        if ($normalized > 0.8) {
            $line .= "█";
        } elsif ($normalized > 0.6) {
            $line .= "▓";
        } elsif ($normalized > 0.4) {
            $line .= "▒";
        } elsif ($normalized > 0.2) {
            $line .= "░";
        } else {
            $line .= "·";
        }
    }
    say "   $line";
}

sub _calculate_wave_entropy {
    my ($wave) = @_;
    
    my $entropy = 0;
    for my $point (@{$wave->{points}}) {
        my $p = $point->{probability};
        if ($p > 0) {
            $entropy -= $p * log($p) / log(2);
        }
    }
    
    return $entropy;
}

sub _calculate_expected_energy {
    my ($wave) = @_;
    
    my $energy = 0;
    my $dx = ($wave->{domain}{max} - $wave->{domain}{min}) / $wave->{domain}{points};
    
    for my $point (@{$wave->{points}}) {
        my $x = $point->{x};
        my $psi = $point->{amplitude};
        # الطاقة ~ |dψ/dx|^2 + V(x)|ψ|^2 (تبسيط)
        $energy += abs($psi)**2 * $x**2;
    }
    
    return $energy * $dx;
}

sub _calculate_stddev {
    my ($wave) = @_;
    
    my $mean = 0;
    my $dx = ($wave->{domain}{max} - $wave->{domain}{min}) / $wave->{domain}{points};
    
    for my $point (@{$wave->{points}}) {
        $mean += $point->{x} * $point->{probability};
    }
    $mean *= $dx;
    
    my $variance = 0;
    for my $point (@{$wave->{points}}) {
        $variance += ($point->{x} - $mean)**2 * $point->{probability};
    }
    $variance *= $dx;
    
    return sqrt($variance);
}

sub _probability_bar {
    my ($percent) = @_;
    
    my $filled = int($percent / 5);
    my $empty = 20 - $filled;
    
    return "[" . ("█" x $filled) . ("░" x $empty) . "]";
}

1;  # نهاية الوحدة
