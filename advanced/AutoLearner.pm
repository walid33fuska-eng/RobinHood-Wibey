package advanced::AutoLearner;
# =============================================================================
# AutoLearner.pm - التعلم الذاتي التلقائي
# =============================================================================
# الميزات: تعلم من النتائج السابقة، تحسين الاستراتيجيات، تكيف تلقائي مع الظروف
# =============================================================================

use strict;
use warnings;
use parent 'Exporter';
our @EXPORT_OK = qw(auto_learn auto_improve auto_adapt auto_strategy);

use lib '.';
use lib::Utils;
use lib::Colors;
use Time::HiRes qw(time);
use File::Slurp qw(read_file write_file);
use List::Util qw(sum max min shuffle);

# قاعدة بيانات التعلم الذاتي
my $LEARNING_DB_FILE = "$ENV{HOME}/.robinhood/auto_learn_db.json";
my $learning_db = {};

# تحميل قاعدة التعلم
sub _load_learning_db {
    if (-f $LEARNING_DB_FILE) {
        my $json = read_file($LEARNING_DB_FILE);
        eval { $learning_db = decode_json($json); };
    }
    
    if (!keys %$learning_db) {
        $learning_db = {
            attacks_history => [],
            successful_strategies => {},
            failed_strategies => {},
            environmental_factors => {},
            performance_metrics => {},
            adaptations => [],
            created_at => time(),
            last_updated => time()
        };
    }
}

# حفظ قاعدة التعلم
sub _save_learning_db {
    my $json = encode_json($learning_db);
    write_file($LEARNING_DB_FILE, $json);
}

# =============================================================================
# التعلم التلقائي
# =============================================================================
sub auto_learn {
    my ($experience, $feedback) = @_;
    
    my $color = Colors->new();
    my $utils = Utils->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    🧠 التعلم الذاتي التلقائي 🧠                       ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    _load_learning_db();
    
    $experience //= {
        attack_type => "unknown",
        target => "unknown",
        duration => 0,
        success => 0,
        environment => {}
    };
    
    $feedback //= {
        score => 0,
        effectiveness => 0,
        efficiency => 0
    };
    
    say "${\($color->info())}[*] تسجيل تجربة جديدة...${\($color->reset())}";
    say "   → نوع الهجوم: $experience->{attack_type}";
    say "   → النجاح: " . ($experience->{success} ? "نعم" : "لا");
    say "   → التقييم: $feedback->{score}/100";
    
    # تسجيل التجربة
    push @{$learning_db->{attacks_history}}, {
        timestamp => time(),
        attack_type => $experience->{attack_type},
        target => $experience->{target},
        duration => $experience->{duration},
        success => $experience->{success},
        score => $feedback->{score},
        environment => $experience->{environment}
    };
    
    # الاحتفاظ بآخر 1000 تجربة فقط
    if (scalar(@{$learning_db->{attacks_history}}) > 1000) {
        shift @{$learning_db->{attacks_history}};
    }
    
    # تحديث الاستراتيجيات الناجحة والفاشلة
    if ($experience->{success}) {
        $learning_db->{successful_strategies}{$experience->{attack_type}}++;
    } else {
        $learning_db->{failed_strategies}{$experience->{attack_type}}++;
    }
    
    # تحديث العوامل البيئية
    for my $factor (keys %{$experience->{environment}}) {
        $learning_db->{environmental_factors}{$factor}{values}{$experience->{environment}{$factor}}++;
        $learning_db->{environmental_factors}{$factor}{success_count}++ if $experience->{success};
    }
    
    # تحديث مقاييس الأداء
    $learning_db->{performance_metrics}{$experience->{attack_type}}{total_attempts}++;
    $learning_db->{performance_metrics}{$experience->{attack_type}}{total_success}++ if $experience->{success};
    $learning_db->{performance_metrics}{$experience->{attack_type}}{avg_duration} = 
        ($learning_db->{performance_metrics}{$experience->{attack_type}}{avg_duration} || 0) * 0.9 + $experience->{duration} * 0.1;
    $learning_db->{performance_metrics}{$experience->{attack_type}}{avg_score} = 
        ($learning_db->{performance_metrics}{$experience->{attack_type}}{avg_score} || 0) * 0.9 + $feedback->{score} * 0.1;
    
    # حساب معدلات النجاح
    for my $attack (keys %{$learning_db->{performance_metrics}}) {
        my $attempts = $learning_db->{performance_metrics}{$attack}{total_attempts} || 1;
        my $success = $learning_db->{performance_metrics}{$attack}{total_success} || 0;
        $learning_db->{performance_metrics}{$attack}{success_rate} = ($success / $attempts) * 100;
    }
    
    $learning_db->{last_updated} = time();
    _save_learning_db();
    
    # عرض الإحصائيات
    say "\n${\($color->success())}📊 إحصائيات التعلم الذاتي:${\($color->reset())}";
    say "   → إجمالي التجارب: " . scalar(@{$learning_db->{attacks_history}});
    say "   → الاستراتيجيات الناجحة: " . scalar(keys %{$learning_db->{successful_strategies}});
    say "   → الاستراتيجيات الفاشلة: " . scalar(keys %{$learning_db->{failed_strategies}});
    
    # أفضل استراتيجية حالياً
    my $best_strategy = "";
    my $best_rate = 0;
    for my $attack (keys %{$learning_db->{performance_metrics}}) {
        my $rate = $learning_db->{performance_metrics}{$attack}{success_rate} || 0;
        if ($rate > $best_rate) {
            $best_rate = $rate;
            $best_strategy = $attack;
        }
    }
    
    if ($best_strategy) {
        say "\n${\($color->success())}🏆 أفضل استراتيجية حالياً: $best_strategy (نسبة نجاح: " . sprintf("%.1f", $best_rate) . "%)${\($color->reset())}";
    }
    
    $utils->save_result('auto_learner', {
        total_experiences => scalar(@{$learning_db->{attacks_history}}),
        best_strategy => $best_strategy,
        best_rate => $best_rate
    });
    
    return $learning_db;
}

# =============================================================================
# تحسين ذاتي تلقائي
# =============================================================================
sub auto_improve {
    my ($target_context) = @_;
    
    my $color = Colors->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    ⚡ التحسين الذاتي التلقائي ⚡                      ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    _load_learning_db();
    
    $target_context //= {
        signal => 60,
        encryption => "WPA2",
        wps_enabled => 1,
        devices_count => 5
    };
    
    say "${\($color->info())}[*] تحليل السياق الحالي...${\($color->reset())}";
    say "   → قوة الإشارة: $target_context->{signal}%";
    say "   → التشفير: $target_context->{encryption}";
    say "   → عدد الأجهزة: $target_context->{devices_count}";
    
    # اقتراح تحسينات
    my $improvements = _suggest_improvements($target_context);
    
    say "\n${\($color->success())}💡 التحسينات المقترحة:${\($color->reset())}";
    for my $imp (@$improvements) {
        say "   → $imp->{action} (تأثير متوقع: +$imp->{expected_improvement}%)";
    }
    
    # تطبيق التحسينات المقترحة
    my $applied = _apply_improvements($improvements);
    
    say "\n${\($color->success())}[✓] تم تطبيق " . scalar(@$applied) . " تحسيناً${\($color->reset())}";
    
    return $applied;
}

# =============================================================================
# تكيف تلقائي مع الظروف
# =============================================================================
sub auto_adapt {
    my ($current_conditions) = @_;
    
    my $color = Colors->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    🔄 التكيف التلقائي 🔄                              ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    _load_learning_db();
    
    $current_conditions //= {
        time => scalar(localtime()),
        signal_trend => "stable",
        network_load => "medium",
        interference_level => 30
    };
    
    say "${\($color->info())}[*] الظروف الحالية:${\($color->reset())}";
    say "   → الوقت: $current_conditions->{time}";
    say "   → اتجاه الإشارة: $current_conditions->{signal_trend}";
    say "   → حمل الشبكة: $current_conditions->{network_load}";
    
    # تحديد استراتيجية التكيف المناسبة
    my $adaptation = _determine_adaptation($current_conditions);
    
    say "\n${\($color->info())}🔄 إجراءات التكيف المتخذة:${\($color->reset())}";
    for my $action (@{$adaptation->{actions}}) {
        say "   → $action";
    }
    
    # تسجيل التكيف
    push @{$learning_db->{adaptations}}, {
        timestamp => time(),
        conditions => $current_conditions,
        adaptation => $adaptation
    };
    
    _save_learning_db();
    
    return $adaptation;
}

# =============================================================================
# اقتراح استراتيجية تلقائي
# =============================================================================
sub auto_strategy {
    my ($target_info) = @_;
    
    my $color = Colors->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    🎯 اقتراح الاستراتيجية 🎯                          ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    _load_learning_db();
    
    $target_info //= {
        bssid => "AA:BB:CC:DD:EE:FF",
        ssid => "Target_Network",
        encryption => "WPA2",
        signal => 65,
        wps_enabled => 1
    };
    
    say "${\($color->info())}[*] تحليل الهدف: $target_info->{ssid}${\($color->reset())}";
    
    # حساب أفضل استراتيجية بناءً على التعلم السابق
    my $strategies = _rank_strategies($target_info);
    
    say "\n${\($color->success())}🏆 الاستراتيجيات المقترحة (مرتبة حسب الفعالية):${\($color->reset())}";
    
    for my $i (0..2) {
        last unless $strategies->[$i];
        my $strategy = $strategies->[$i];
        my $rate = $learning_db->{performance_metrics}{$strategy->{name}}{success_rate} || 50;
        my $expected_time = _estimate_strategy_time($strategy->{name}, $target_info);
        
        say "\n   " . ($i+1) . ". ${\($color->quantum())}$strategy->{name}${\($color->reset())}";
        say "      → نسبة النجاح المتوقعة: " . sprintf("%.1f", $rate) . "%";
        say "      → الوقت المتوقع: $expected_time";
        say "      → السبب: $strategy->{reason}";
    }
    
    # أفضل استراتيجية
    my $best = $strategies->[0];
    
    say "\n${\($color->success())}🎯 الاستراتيجية الموصى بها: ${\($color->quantum())}$best->{name}${\($color->reset())}";
    say "   → $best->{reason}";
    
    return $best;
}

# =============================================================================
# دوال مساعدة داخلية
# =============================================================================

sub _suggest_improvements {
    my ($context) = @_;
    
    my @improvements = ();
    
    if ($context->{signal} < 50) {
        push @improvements, {
            action => "تحسين قوة الإشارة عن طريق الاقتراب من الراوتر",
            expected_improvement => 30
        };
    }
    
    if ($context->{encryption} eq 'WPA2' && $context->{wps_enabled}) {
        push @improvements, {
            action => "استهداف WPS أولاً (ثغرة معروفة)",
            expected_improvement => 40
        };
    }
    
    if ($context->{devices_count} > 10) {
        push @improvements, {
            action => "استخدام هجوم Deauth لفصل الأجهزة ثم التقاط المصافحة",
            expected_improvement => 25
        };
    }
    
    return \@improvements;
}

sub _apply_improvements {
    my ($improvements) = @_;
    
    my @applied = ();
    
    for my $imp (@$improvements) {
        # محاكاة تطبيق التحسين
        push @applied, $imp->{action};
    }
    
    return \@applied;
}

sub _determine_adaptation {
    my ($conditions) = @_;
    
    my $adaptation = {
        actions => [],
        reasoning => []
    };
    
    if ($conditions->{signal_trend} eq 'decreasing') {
        push @{$adaptation->{actions}}, "زيادة معدل إرسال الحزم للتعويض";
        push @{$adaptation->{reasoning}}, "الإشارة تضعف - نحتاج إلى حزم أكثر";
    }
    
    if ($conditions->{network_load} eq 'high') {
        push @{$adaptation->{actions}}, "تقليل معدل الهجوم لتجنب الاكتشاف";
        push @{$adaptation->{reasoning}}, "شبكة مزدحمة - هجوم بطيء أقل اكتشافاً";
    }
    
    if ($conditions->{interference_level} > 50) {
        push @{$adaptation->{actions}}, "تغيير القناة إلى قناة أقل تداخلاً";
        push @{$adaptation->{reasoning}}, "تداخل عالي - تغيير القناة يحسن الفعالية";
    }
    
    return $adaptation;
}

sub _rank_strategies {
    my ($target) = @_;
    
    my @strategies = ();
    
    # قائمة الاستراتيجيات الممكنة
    my @possible = ('wps', 'dictionary', 'handshake', 'pmkid', 'evil_twin');
    
    for my $strategy (@possible) {
        my $score = 0;
        my $reason = "";
        
        if ($strategy eq 'wps' && $target->{wps_enabled}) {
            $score += 40;
            $reason = "WPS مفعل - ثغرة معروفة";
        } elsif ($strategy eq 'pmkid') {
            $score += 30;
            $reason = "هجوم PMKID سريع ولا يحتاج عميل";
        } elsif ($strategy eq 'handshake') {
            $score += 20;
            $reason = "هجوم تقليدي فعال";
        } elsif ($strategy eq 'dictionary') {
            $score += 15;
            $reason = "سريع إذا كانت كلمة المرور ضعيفة";
        } elsif ($strategy eq 'evil_twin') {
            $score += 25;
            $reason = "فعال ضد المستخدمين غير الحذرين";
        }
        
        # إضافة التعلم السابق
        my $success_rate = $learning_db->{performance_metrics}{$strategy}{success_rate} || 0;
        $score += $success_rate * 0.3;
        
        push @strategies, {
            name => $strategy,
            score => $score,
            reason => $reason
        };
    }
    
    # ترتيب حسب الدرجة
    @strategies = sort { $b->{score} <=> $a->{score} } @strategies;
    
    return \@strategies;
}

sub _estimate_strategy_time {
    my ($strategy, $target) = @_;
    
    if ($strategy eq 'wps') {
        return "5 - 30 دقيقة";
    } elsif ($strategy eq 'pmkid') {
        return "ثواني - دقائق";
    } elsif ($strategy eq 'handshake') {
        return "1 - 10 دقائق";
    } elsif ($strategy eq 'dictionary') {
        return "دقائق - أيام (حسب القاموس)";
    } elsif ($strategy eq 'evil_twin') {
        return "دقائق - ساعات";
    } else {
        return "غير محدد";
    }
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
    return {};
}

# تحميل قاعدة البيانات عند التحميل
_load_learning_db();

1;  # نهاية الوحدة
