package advanced::PatternRecognizer;
# =============================================================================
# PatternRecognizer.pm - التعرف على الأنماط في الشبكات والهجمات
# =============================================================================
# الميزات: اكتشاف أنماط حركة المرور، التعرف على أنماط كلمات المرور، تحليل الأنماط الزمنية
# =============================================================================

use strict;
use warnings;
use parent 'Exporter';
our @EXPORT_OK = qw(recognize_traffic_pattern recognize_password_pattern recognize_temporal_pattern recognize_attack_pattern);

use lib '.';
use lib::Utils;
use lib::Colors;
use Time::HiRes qw(time);
use File::Slurp qw(write_file);
use List::Util qw(sum max min uniq);

# =============================================================================
# التعرف على أنماط حركة المرور
# =============================================================================
sub recognize_traffic_pattern {
    my ($traffic_data, $pattern_type) = @_;
    
    my $color = Colors->new();
    my $utils = Utils->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    🔍 التعرف على أنماط المرور 🔍                      ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    $traffic_data //= [];
    $pattern_type //= "all";
    
    say "${\($color->info())}[*] تحليل أنماط حركة المرور...${\($color->reset())}";
    
    my $patterns = {
        periodic => [],
        burst => [],
        gradual => [],
        random => []
    };
    
    # تحليل البيانات
    if (scalar(@$traffic_data) > 0) {
        $patterns = _analyze_traffic_patterns($traffic_data);
    } else {
        # بيانات افتراضية للعرض
        $patterns = _generate_sample_patterns();
    }
    
    # عرض النتائج
    say "\n${\($color->success())}📊 الأنماط المكتشفة:${\($color->reset())}";
    
    if (scalar(@{$patterns->{periodic}}) > 0) {
        say "\n   🔄 الأنماط الدورية:";
        for my $pattern (@{$patterns->{periodic}}) {
            say "      → $pattern->{description} (دورة: $pattern->{interval} ثانية)";
        }
    }
    
    if (scalar(@{$patterns->{burst}}) > 0) {
        say "\n   💥 الأنماط الانفجارية:";
        for my $pattern (@{$patterns->{burst}}) {
            say "      → $pattern->{description} (شدة: $pattern->{intensity})";
        }
    }
    
    if (scalar(@{$patterns->{gradual}}) > 0) {
        say "\n   📈 الأنماط التدريجية:";
        for my $pattern (@{$patterns->{gradual}}) {
            say "      → $pattern->{description} (معدل: $pattern->{rate}/ثانية)";
        }
    }
    
    $utils->save_result('pattern_recognizer', {
        pattern_type => $pattern_type,
        periodic_count => scalar(@{$patterns->{periodic}}),
        burst_count => scalar(@{$patterns->{burst}})
    });
    
    return $patterns;
}

# =============================================================================
# التعرف على أنماط كلمات المرور
# =============================================================================
sub recognize_password_pattern {
    my ($passwords_list) = @_;
    
    my $color = Colors->new();
    my $utils = Utils->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    🔑 أنماط كلمات المرور 🔑                           ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    $passwords_list //= [];
    
    my $patterns = {
        structural => [],
        character_based => [],
        semantic => [],
        common_patterns => []
    };
    
    if (scalar(@$passwords_list) > 0) {
        $patterns = _analyze_password_patterns($passwords_list);
    } else {
        $patterns = _generate_sample_password_patterns();
    }
    
    say "\n${\($color->success())}🔐 أنماط كلمات المرور المكتشفة:${\($color->reset())}";
    
    if (scalar(@{$patterns->{structural}}) > 0) {
        say "\n   📐 الأنماط الهيكلية:";
        for my $pattern (@{$patterns->{structural}}) {
            say "      → $pattern->{description} (نسبة: $pattern->{percentage}%)";
        }
    }
    
    if (scalar(@{$patterns->{character_based}}) > 0) {
        say "\n   🔤 الأنماط القائمة على الأحرف:";
        for my $pattern (@{$patterns->{character_based}}) {
            say "      → $pattern->{description}";
        }
    }
    
    if (scalar(@{$patterns->{semantic}}) > 0) {
        say "\n   🧠 الأنماط الدلالية:";
        for my $pattern (@{$patterns->{semantic}}) {
            say "      → $pattern->{description}";
        }
    }
    
    $utils->save_result('password_patterns', {
        total_patterns => scalar(@{$patterns->{structural}}) + scalar(@{$patterns->{character_based}})
    });
    
    return $patterns;
}

# =============================================================================
# التعرف على الأنماط الزمنية
# =============================================================================
sub recognize_temporal_pattern {
    my ($timeline_data, $resolution) = @_;
    
    my $color = Colors->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    ⏰ الأنماط الزمنية ⏰                               ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    $timeline_data //= [];
    $resolution //= "hour";
    
    my $patterns = {
        daily => {},
        weekly => {},
        monthly => {},
        seasonal => []
    };
    
    # تحليل الأنماط الزمنية
    $patterns = _analyze_temporal_patterns($timeline_data, $resolution);
    
    say "\n${\($color->success())}📅 الأنماط الزمنية المكتشفة:${\($color->reset())}";
    
    say "\n   🕐 النمط اليومي:";
    my @sorted_hours = sort { $patterns->{daily}{$b} <=> $patterns->{daily}{$a} } keys %{$patterns->{daily}};
    if (scalar(@sorted_hours) > 0) {
        say "      → ساعات الذروة: " . join(", ", map { "$_:00" } @sorted_hours[0..2]);
        say "      → ساعات الخمول: " . join(", ", map { "$_:00" } @sorted_hours[-3..-1]);
    }
    
    say "\n   📆 النمط الأسبوعي:";
    my @sorted_days = sort { $patterns->{weekly}{$b} <=> $patterns->{weekly}{$a} } keys %{$patterns->{weekly}};
    if (scalar(@sorted_days) > 0) {
        say "      → أكثر الأيام نشاطاً: $sorted_days[0]";
        say "      → أقل الأيام نشاطاً: $sorted_days[-1]";
    }
    
    return $patterns;
}

# =============================================================================
# التعرف على أنماط الهجمات
# =============================================================================
sub recognize_attack_pattern {
    my ($attack_logs) = @_;
    
    my $color = Colors->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    ⚔️ أنماط الهجمات ⚔️                                ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    $attack_logs //= [];
    
    my $patterns = {
        sequence => [],
        frequency => {},
        success_factors => [],
        defense_responses => []
    };
    
    if (scalar(@$attack_logs) > 0) {
        $patterns = _analyze_attack_patterns($attack_logs);
    } else {
        $patterns = _generate_sample_attack_patterns();
    }
    
    say "\n${\($color->success())}🎯 أنماط الهجمات المكتشفة:${\($color->reset())}";
    
    if (scalar(@{$patterns->{sequence}}) > 0) {
        say "\n   📋 التسلسلات الشائعة:";
        for my $seq (@{$patterns->{sequence}}) {
            say "      → " . join(" → ", @{$seq->{steps}}) . " (تكرار: $seq->{frequency})";
        }
    }
    
    if (scalar(@{$patterns->{success_factors}}) > 0) {
        say "\n   ✅ عوامل النجاح:";
        for my $factor (@{$patterns->{success_factors}}) {
            say "      → $factor->{factor} (تأثير: +$factor->{impact}%)";
        }
    }
    
    return $patterns;
}

# =============================================================================
# دوال مساعدة داخلية
# =============================================================================

sub _analyze_traffic_patterns {
    my ($data) = @_;
    
    my $patterns = {
        periodic => [],
        burst => [],
        gradual => [],
        random => []
    };
    
    # محاكاة تحليل الأنماط
    if (scalar(@$data) > 10) {
        push @{$patterns->{periodic}}, {
            description => "حركة دورية كل 30 ثانية",
            interval => 30,
            confidence => 85
        };
        
        push @{$patterns->{burst}}, {
            description => "انفجارات حركة كل 5 دقائق",
            intensity => "high",
            confidence => 75
        };
    }
    
    return $patterns;
}

sub _generate_sample_patterns {
    return {
        periodic => [
            { description => "حركة دورية منتظمة", interval => 30, confidence => 85 },
            { description => "نمط يومي متكرر", interval => 86400, confidence => 90 }
        ],
        burst => [
            { description => "انفجارات حركة عند بداية كل ساعة", intensity => "high", confidence => 80 }
        ],
        gradual => [
            { description => "زيادة تدريجية في المساء", rate => 10, confidence => 75 }
        ],
        random => []
    };
}

sub _analyze_password_patterns {
    my ($passwords) = @_;
    
    my $patterns = {
        structural => [],
        character_based => [],
        semantic => [],
        common_patterns => []
    };
    
    # تحليل الهيكل
    my $avg_len = 0;
    for my $pwd (@$passwords) {
        $avg_len += length($pwd);
    }
    $avg_len /= scalar(@$passwords);
    
    push @{$patterns->{structural}}, {
        description => "متوسط طول كلمات المرور: " . sprintf("%.1f", $avg_len),
        percentage => 100
    };
    
    # تحليل الأحرف
    my $has_numbers = grep { /\d/ } @$passwords;
    my $has_symbols = grep { /[\@\#\$\%\!\?]/ } @$passwords;
    
    push @{$patterns->{character_based}}, {
        description => "كلمات تحتوي على أرقام: " . sprintf("%.1f", ($has_numbers/scalar(@$passwords))*100) . "%"
    };
    
    push @{$patterns->{character_based}}, {
        description => "كلمات تحتوي على رموز: " . sprintf("%.1f", ($has_symbols/scalar(@$passwords))*100) . "%"
    };
    
    return $patterns;
}

sub _generate_sample_password_patterns {
    return {
        structural => [
            { description => "8-12 حرف هو الأكثر شيوعاً", percentage => 65 },
            { description => "كلمات تبدأ بحرف كبير", percentage => 45 }
        ],
        character_based => [
            { description => "80% تحتوي على أرقام في النهاية" },
            { description => "30% تحتوي على رموز خاصة" }
        ],
        semantic => [
            { description => "كلمات مرتبطة بالعلامة التجارية" },
            { description => "استخدام تواريخ ميلاد" }
        ],
        common_patterns => [
            { description => "admin, password, 123456 هي الأكثر شيوعاً" }
        ]
    };
}

sub _analyze_temporal_patterns {
    my ($data, $resolution) = @_;
    
    my $patterns = {
        daily => {},
        weekly => {},
        monthly => {},
        seasonal => []
    };
    
    # محاكاة الأنماط اليومية
    for my $hour (0..23) {
        if ($hour >= 9 && $hour <= 17) {
            $patterns->{daily}{$hour} = 80 + int(rand(20));
        } elsif ($hour >= 18 && $hour <= 23) {
            $patterns->{daily}{$hour} = 50 + int(rand(30));
        } else {
            $patterns->{daily}{$hour} = 10 + int(rand(20));
        }
    }
    
    # محاكاة الأنماط الأسبوعية
    my @days = qw(Sunday Monday Tuesday Wednesday Thursday Friday Saturday);
    for my $day (@days) {
        if ($day eq 'Saturday' || $day eq 'Sunday') {
            $patterns->{weekly}{$day} = 30 + int(rand(30));
        } else {
            $patterns->{weekly}{$day} = 70 + int(rand(20));
        }
    }
    
    return $patterns;
}

sub _analyze_attack_patterns {
    my ($logs) = @_;
    
    my $patterns = {
        sequence => [],
        frequency => {},
        success_factors => [],
        defense_responses => []
    };
    
    push @{$patterns->{sequence}}, {
        steps => ['scan', 'deauth', 'handshake', 'dictionary'],
        frequency => 25
    };
    
    push @{$patterns->{success_factors}}, {
        factor => "قوة الإشارة > 60%",
        impact => 40
    };
    
    return $patterns;
}

sub _generate_sample_attack_patterns {
    return {
        sequence => [
            { steps => ['scan', 'wps_pin', 'crack'], frequency => 45 },
            { steps => ['deauth', 'handshake', 'dictionary'], frequency => 35 },
            { steps => ['pmkid', 'hashcat'], frequency => 20 }
        ],
        frequency => {
            'wps' => 40,
            'dictionary' => 35,
            'deauth' => 25
        },
        success_factors => [
            { factor => "إشارة قوية (>70%)", impact => 50 },
            { factor => "شبكة بها أجهزة متعددة", impact => 30 },
            { factor => "تشفير WEP", impact => 80 }
        ],
        defense_responses => [
            { response => "إبطاء الهجوم بعد محاولات فاشلة", effectiveness => 60 }
        ]
    };
}

1;  # نهاية الوحدة
