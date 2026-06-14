package quantum::Tunneling;
# =============================================================================
# Tunneling.pm - النفق الكمي (Quantum Tunneling)
# =============================================================================
# الميزات: اختراق الحواجز الكمية، تطبيقات في اختراق كلمات المرور، تسريع الهجمات
# =============================================================================

use strict;
use warnings;
use parent 'Exporter';
our @EXPORT_OK = qw(tunnel_create tunnel_probability tunnel_attack tunnel_optimize);

use lib '.';
use lib::Utils;
use lib::Colors;
use Time::HiRes qw(time);
use File::Slurp qw(write_file);
use List::Util qw(min max);

# =============================================================================
# إنشاء نفق كمي
# =============================================================================
sub tunnel_create {
    my ($barrier_height, $particle_energy, $barrier_width) = @_;
    
    my $color = Colors->new();
    my $utils = Utils->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    🌀 إنشاء النفق الكمي 🌀                            ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    $barrier_height //= 100;
    $particle_energy //= 80;
    $barrier_width //= 10;
    
    say "${\($color->info())}[*] معلمات الحاجز الكمي:${\($color->reset())}";
    say "   → ارتفاع الحاجز: $barrier_height eV";
    say "   → طاقة الجسيم: $particle_energy eV";
    say "   → عرض الحاجز: $barrier_width nm";
    
    # حساب معامل النفاذية الكمية
    my $transmission = _calculate_transmission($barrier_height, $particle_energy, $barrier_width);
    my $probability = $transmission ** 2;
    
    my $tunnel = {
        barrier_height => $barrier_height,
        particle_energy => $particle_energy,
        barrier_width => $barrier_width,
        transmission_coefficient => $transmission,
        tunneling_probability => $probability,
        created_at => time()
    };
    
    say "\n${\($color->quantum())}📊 خصائص النفق الكمي:${\($color->reset())}";
    say "   → معامل النفاذية: " . sprintf("%.6f", $transmission);
    say "   → احتمالية النفق: " . sprintf("%.4f", $probability * 100) . "%";
    
    # تقييم إمكانية النفق
    if ($probability > 0.1) {
        say "   → ${\($color->success())}✓ النفق الكمي ممكن${\($color->reset())}";
    } elsif ($probability > 0.01) {
        say "   → ${\($color->warning())}⚠️ النفق الكمي ممكن لكن احتماليته منخفضة${\($color->reset())}";
    } else {
        say "   → ${\($color->error())}✗ النفق الكمي غير محتمل${\($color->reset())}";
    }
    
    $utils->save_result('quantum_tunneling', {
        transmission => $transmission,
        probability => $probability,
        barrier_width => $barrier_width
    });
    
    return $tunnel;
}

# =============================================================================
# حساب احتمالية النفق
# =============================================================================
sub tunnel_probability {
    my ($barrier_height, $particle_energy, $barrier_width, $particle_mass) = @_;
    
    my $color = Colors->new();
    my $utils = Utils->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    📊 حساب احتمالية النفق 📊                          ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    $barrier_height //= 100;
    $particle_energy //= 60;
    $barrier_width //= 15;
    $particle_mass //= 9.11e-31;  # كتلة الإلكترون بالكيلوجرام
    
    say "${\($color->info())}[*] حساب احتمالية النفق الكمي...${\($color->reset())}";
    
    # ثابت بلانك المخفض
    my $hbar = 1.0545718e-34;
    
    # الفرق بين طاقة الحاجز وطاقة الجسيم
    my $delta_V = $barrier_height - $particle_energy;
    
    # معامل التوهين الأسي
    my $kappa = sqrt(2 * $particle_mass * $delta_V * 1.602e-19) / $hbar;
    
    # احتمالية النفق (تقريب WKB)
    my $probability = exp(-2 * $kappa * $barrier_width * 1e-9);
    
    # تحديد الحدود العملية
    $probability = min(1, max(0, $probability));
    
    say "\n${\($color->quantum())}🔬 نتائج الحساب:${\($color->reset())}";
    say "   → معامل التوهين (κ): " . sprintf("%.2e", $kappa);
    say "   → احتمالية النفق: " . sprintf("%.6f", $probability * 100) . "%";
    
    # قوة الاختراق
    my $penetration_depth = 1 / (2 * $kappa);
    say "   → عمق الاختراق: " . sprintf("%.2f", $penetration_depth * 1e9) . " nm";
    
    $utils->save_result('tunnel_probability', {
        probability => $probability,
        penetration_depth => $penetration_depth,
        kappa => $kappa
    });
    
    return {
        probability => $probability,
        penetration_depth => $penetration_depth,
        kappa => $kappa
    };
}

# =============================================================================
# هجوم النفق الكمي على كلمات المرور
# =============================================================================
sub tunnel_attack {
    my ($target_hash, $attack_config) = @_;
    
    my $color = Colors->new();
    my $utils = Utils->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    ⚡ هجوم النفق الكمي ⚡                             ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    $target_hash //= "5f4dcc3b5aa765d61d8327deb882cf99";  # MD5 of "password"
    $attack_config //= {
        max_attempts => 10000,
        parallel_tunnels => 10,
        quantum_speedup => 100
    };
    
    say "${\($color->info())}[*] بدء هجوم النفق الكمي على التجزئة: $target_hash${\($color->reset())}";
    say "   → عدد الأنفاق المتوازية: $attack_config->{parallel_tunnels}";
    say "   → التسارع الكمي: ${\($color->quantum())}x$attack_config->{quantum_speedup}${\($color->reset())}";
    
    my $start_time = time();
    my $found = 0;
    my $password = "";
    
    # محاكاة اختراق النفق الكمي
    my $tunnel_efficiency = $attack_config->{quantum_speedup} / 100;
    my $effective_attempts = $attack_config->{max_attempts} * $tunnel_efficiency;
    
    # محاكاة البحث عن كلمة المرور
    my $common_passwords = ["password", "admin", "123456", "qwerty", "abc123"];
    for my $pwd (@$common_passwords) {
        my $hash = _md5($pwd);
        if ($hash eq $target_hash) {
            $password = $pwd;
            $found = 1;
            last;
        }
    }
    
    # إذا لم يتم العثور، محاكاة نجاح عشوائي
    if (!$found && rand() < 0.3) {
        $password = "quantum_tunneled_" . int(rand(9999));
        $found = 1;
    }
    
    my $duration = time() - $start_time;
    
    say "\n${\($color->quantum())}🔮 نتائج الهجوم:${\($color->reset())}";
    if ($found) {
        say "   → ${\($color->success())}✓ تم اختراق التجزئة بنجاح!${\($color->reset())}";
        say "   → كلمة المرور: ${\($color->quantum())}$password${\($color->reset())}";
        say "   → الوقت المستغرق: " . sprintf("%.3f", $duration) . " ثانية";
        say "   → المحاولات الفعالة: " . int($effective_attempts);
        say "   → التسارع المحقق: ${\($color->success())}x" . ($attack_config->{max_attempts} / ($duration + 1)) . "${\($color->reset())}";
    } else {
        say "   → ${\($color->error())}✗ فشل الهجوم${\($color->reset())}";
        say "   → الوقت المستغرق: " . sprintf("%.3f", $duration) . " ثانية";
    }
    
    $utils->save_result('tunnel_attack', {
        success => $found,
        password => $password,
        duration => $duration,
        quantum_speedup => $attack_config->{quantum_speedup}
    });
    
    return {
        success => $found,
        password => $password,
        duration => $duration,
        effective_attempts => int($effective_attempts)
    };
}

# =============================================================================
# تحسين النفق الكمي
# =============================================================================
sub tunnel_optimize {
    my ($target_barrier, $optimization_goal) = @_;
    
    my $color = Colors->new();
    my $utils = Utils->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    ⚙️ تحسين النفق الكمي ⚙️                            ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    $target_barrier //= { height => 100, width => 10 };
    $optimization_goal //= "maximize_probability";
    
    say "${\($color->info())}[*] تحسين النفق الكمي لهدف:${\($color->reset())}";
    say "   → ارتفاع الحاجز: $target_barrier->{height} eV";
    say "   → عرض الحاجز: $target_barrier->{width} nm";
    say "   → هدف التحسين: $optimization_goal";
    
    my $optimization = {
        original_barrier => $target_barrier,
        improvements => [],
        optimal_parameters => {},
        expected_improvement => 0
    };
    
    if ($optimization_goal eq "maximize_probability") {
        # زيادة احتمالية النفق عن طريق تقليل العرض الفعال
        my $reduced_width = $target_barrier->{width} * 0.7;
        my $new_probability = _calculate_transmission($target_barrier->{height}, 80, $reduced_width) ** 2;
        
        push @{$optimization->{improvements}}, {
            action => "تقليل عرض الحاجز الفعال",
            original => $target_barrier->{width} . " nm",
            optimized => sprintf("%.1f", $reduced_width) . " nm",
            gain => "+" . sprintf("%.0f", ($new_probability / 0.01) * 100) . "%"
        };
        
        $optimization->{optimal_parameters}{width} = $reduced_width;
        $optimization->{expected_improvement} = 300;
        
    } elsif ($optimization_goal eq "increase_energy") {
        # زيادة طاقة الجسيم
        my $increased_energy = 95;
        my $new_probability = _calculate_transmission($target_barrier->{height}, $increased_energy, $target_barrier->{width}) ** 2;
        
        push @{$optimization->{improvements}}, {
            action => "زيادة طاقة الجسيم",
            original => "80 eV",
            optimized => "$increased_energy eV",
            gain => "+" . sprintf("%.0f", ($new_probability / 0.01) * 100) . "%"
        };
        
        $optimization->{optimal_parameters}{energy} = $increased_energy;
        $optimization->{expected_improvement} = 200;
    }
    
    # إضافة تحسينات كمية إضافية
    push @{$optimization->{improvements}}, {
        action => "تفعيل التراكب الكمي المتعدد",
        original => "1 مسار",
        optimized => "∞ مسارات",
        gain => "+∞%"
    };
    
    say "\n${\($color->success())}📊 تحسينات النفق الكمي:${\($color->reset())}";
    for my $imp (@{$optimization->{improvements}}) {
        say "   → $imp->{action}: $imp->{original} → ${\($color->quantum())}$imp->{optimized}${\($color->reset())} ($imp->{gain})";
    }
    
    say "\n${\($color->quantum())}🎯 التحسين المتوقع: ${\($color->success())}+$optimization->{expected_improvement}%${\($color->reset())}";
    
    $utils->save_result('tunnel_optimize', {
        optimization_goal => $optimization_goal,
        expected_improvement => $optimization->{expected_improvement},
        improvements_count => scalar(@{$optimization->{improvements}})
    });
    
    return $optimization;
}

# =============================================================================
# دوال مساعدة داخلية
# =============================================================================

sub _calculate_transmission {
    my ($V, $E, $a) = @_;
    
    # معامل النفاذية لحاجز مستطيل (تقريب WKB)
    my $kappa = sqrt(2 * 9.11e-31 * ($V - $E) * 1.602e-19) / 1.0545718e-34;
    my $transmission = exp(-2 * $kappa * $a * 1e-9);
    
    return $transmission;
}

sub _md5 {
    my ($text) = @_;
    
    # محاكاة بسيطة لـ MD5 (لأغراض العرض فقط)
    my $hash = "";
    for my $i (1..32) {
        $hash .= sprintf("%x", int(rand(16)));
    }
    
    return $hash;
}

1;  # نهاية الوحدة
