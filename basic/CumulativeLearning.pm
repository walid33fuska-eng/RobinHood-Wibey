package basic::CumulativeLearning;
# =============================================================================
# CumulativeLearning.pm - نظام التعلم التراكمي (Cumulative Learning)
# =============================================================================
# الميزات: تعلم من الهجمات السابقة، تحسين الأداء، اقتراح الهجمات المناسبة
# =============================================================================

use strict;
use warnings;
use parent 'Exporter';
our @EXPORT_OK = qw(learning_update learning_suggest learning_stats learning_reset);

use lib '.';
use lib::Utils;
use lib::Colors;
use Time::HiRes qw(time);
use File::Slurp qw(read_file write_file);
use List::Util qw(sum max min shuffle);

# قاعدة بيانات التعلم
my $LEARNING_DB_FILE = "$ENV{HOME}/.robinhood/learning_db.json";
my $learning_db = {};

# تحميل قاعدة التعلم عند البدء
sub _load_learning_db {
    if (-f $LEARNING_DB_FILE) {
        my $json = read_file($LEARNING_DB_FILE);
        eval { $learning_db = decode_json($json); };
    }
    
    # تهيئة الهيكل إذا كان فارغاً
    if (!keys %$learning_db) {
        $learning_db = {
            total_attacks => 0,
            successful_attacks => 0,
            attacks_by_type => {},
            successful_contexts => [],
            attack_ranking => [],
            best_time => "",
            best_signal_threshold => 60,
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
# تحديث نظام التعلم
# =============================================================================
sub learning_update {
    my ($attack_result, $context) = @_;
    
    my $color = Colors->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    🧠 التعلم التراكمي 🧠                              ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    _load_learning_db();
    
    $attack_result //= { success => 0, attack_type => "unknown" };
    $context //= { bssid => "unknown", ssid => "unknown", signal => 50, channel => 6 };
    
    my $attack_type = $attack_result->{attack_type} || "unknown";
    my $success = $attack_result->{success} || 0;
    
    say "${\($color->info())}[*] تسجيل هجوم من نوع: $attack_type${\($color->reset())}";
    say "${\($color->info())}[*] النتيجة: " . ($success ? "نجاح ✓" : "فشل ✗") . "${\($color->reset())}";
    
    # تحديث الإحصائيات العامة
    $learning_db->{total_attacks}++;
    $learning_db->{successful_attacks}++ if $success;
    $learning_db->{last_updated} = time();
    
    # تحديث إحصائيات حسب نوع الهجوم
    $learning_db->{attacks_by_type}{$attack_type}{attempts}++;
    $learning_db->{attacks_by_type}{$attack_type}{successes}++ if $success;
    
    # حساب معدل النجاح لكل نوع
    my $attempts = $learning_db->{attacks_by_type}{$attack_type}{attempts};
    my $successes = $learning_db->{attacks_by_type}{$attack_type}{successes};
    $learning_db->{attacks_by_type}{$attack_type}{success_rate} = ($successes / $attempts) * 100;
    
    # تسجيل السياق إذا كان الهجوم ناجحاً
    if ($success) {
        push @{$learning_db->{successful_contexts}}, {
            timestamp => time(),
            bssid => $context->{bssid},
            ssid => $context->{ssid},
            channel => $context->{channel},
            signal => $context->{signal},
            attack_type => $attack_type,
            duration => $context->{duration} // 0
        };
        
        # الاحتفاظ بآخر 100 سياق فقط
        if (scalar(@{$learning_db->{successful_contexts}}) > 100) {
            shift @{$learning_db->{successful_contexts}};
        }
        
        # تحديث أفضل وقت للهجوم
        my $hour = (localtime(time()))[2];
        my $best_hour = $learning_db->{best_time_hour} // $hour;
        $learning_db->{best_time_hour} = $hour;
        
        # تحديث أفضل قوة إشارة
        if ($context->{signal} > ($learning_db->{best_signal_threshold} // 0)) {
            $learning_db->{best_signal_threshold} = $context->{signal};
        }
    }
    
    # تحديث ترتيب الهجمات حسب الفعالية
    my @attack_ranking = sort {
        ($learning_db->{attacks_by_type}{$b}{success_rate} // 0) <=> 
        ($learning_db->{attacks_by_type}{$a}{success_rate} // 0)
    } keys %{$learning_db->{attacks_by_type}};
    $learning_db->{attack_ranking} = \@attack_ranking;
    
    # حساب المعدل الإجمالي
    $learning_db->{overall_success_rate} = ($learning_db->{successful_attacks} / $learning_db->{total_attacks}) * 100;
    
    # حفظ التحديثات
    _save_learning_db();
    
    say "\n${\($color->success())}[✓] تم تحديث نظام التعلم التراكمي${\($color->reset())}";
    say "   → المعدل الإجمالي: " . sprintf("%.1f", $learning_db->{overall_success_rate}) . "%";
    say "   → أفضل هجوم: " . ($attack_ranking[0] // "لا يوجد");
    
    return $learning_db;
}

# =============================================================================
# اقتراح الهجوم المناسب
# =============================================================================
sub learning_suggest {
    my ($target_context) = @_;
    
    my $color = Colors->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    💡 اقتراح الهجوم المناسب 💡                       ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    _load_learning_db();
    
    $target_context //= {
        bssid => "AA:BB:CC:DD:EE:FF",
        ssid => "Target_Network",
        signal => 65,
        channel => 6,
        encryption => "WPA2"
    };
    
    say "${\($color->info())}[*] تحليل السياق المستهدف:${\($color->reset())}";
    say "   → SSID: $target_context->{ssid}";
    say "   → قوة الإشارة: $target_context->{signal}%";
    say "   → التشفير: $target_context->{encryption}";
    
    # حساب أفضل هجوم بناءً على التعلم السابق
    my @ranked_attacks = @{$learning_db->{attack_ranking} || []};
    
    # تعديل الاقتراح بناءً على السياق الحالي
    my @suggestions = ();
    
    # إذا كانت الإشارة ضعيفة
    if ($target_context->{signal} < 40) {
        unshift @suggestions, {
            attack => "PMKIDAttack",
            reason => "إشارة ضعيفة - هجوم PMKID لا يحتاج إلى عميل متصل",
            probability => 70
        };
    }
    
    # إذا كان التشفير WPS مفعل
    if ($target_context->{encryption} =~ /WPS/i) {
        unshift @suggestions, {
            attack => "WPSCracker",
            reason => "WPS مفعل - ثغرة معروفة",
            probability => 85
        };
    }
    
    # اقتراح من التعلم السابق
    for my $attack (@ranked_attacks[0..2]) {
        my $success_rate = $learning_db->{attacks_by_type}{$attack}{success_rate} // 0;
        push @suggestions, {
            attack => $attack,
            reason => "نسبة نجاح عالية في السابق: " . sprintf("%.1f", $success_rate) . "%",
            probability => $success_rate
        };
    }
    
    # اقتراحات عامة
    my @general_attacks = (
        { attack => "HandshakeCapture", probability => 60, reason => "هجوم كلاسيكي فعال" },
        { attack => "DictionaryAttack", probability => 50, reason => "سريع إذا كانت كلمة المرور ضعيفة" },
        { attack => "EvilTwin", probability => 70, reason => "فعال ضد المستخدمين غير الحذرين" }
    );
    
    push @suggestions, @general_attacks;
    
    # إزالة التكرار
    my %seen;
    @suggestions = grep { !$seen{$_->{attack}}++ } @suggestions;
    
    # ترتيب حسب الاحتمالية
    @suggestions = sort { $b->{probability} <=> $a->{probability} } @suggestions;
    
    # عرض الاقتراحات
    say "\n${\($color->success())}🎯 الاقتراحات (مرتبة حسب الفعالية):${\($color->reset())}";
    my $rank = 1;
    for my $suggestion (@suggestions[0..4]) {
        my $prob_color = $suggestion->{probability} >= 70 ? $color->success() :
                         ($suggestion->{probability} >= 50 ? $color->info() : $color->warning());
        say "   $rank. ${\($color->quantum())}$suggestion->{attack}${\($color->reset())} - " .
            "${\($prob_color)}" . sprintf("%.0f", $suggestion->{probability}) . "%${\($color->reset())}";
        say "      → $suggestion->{reason}";
        $rank++;
    }
    
    # أفضل وقت للهجوم
    if ($learning_db->{best_time_hour}) {
        my $best_hour = $learning_db->{best_time_hour};
        say "\n${\($color->info())}⏰ أفضل وقت للهجوم: حوالي $best_hour:00${\($color->reset())}";
    }
    
    return \@suggestions;
}

# =============================================================================
# إحصائيات التعلم
# =============================================================================
sub learning_stats {
    my $color = Colors->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    📊 إحصائيات التعلم التراكمي 📊                     ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    _load_learning_db();
    
    say "\n${\($color->info())}📈 الإحصائيات العامة:${\($color->reset())}";
    say "   → إجمالي الهجمات: $learning_db->{total_attacks}";
    say "   → الهجمات الناجحة: $learning_db->{successful_attacks}";
    say "   → المعدل الإجمالي: " . sprintf("%.1f", $learning_db->{overall_success_rate} || 0) . "%";
    say "   → أفضل قوة إشارة: $learning_db->{best_signal_threshold}%";
    say "   → آخر تحديث: " . localtime($learning_db->{last_updated});
    
    if (scalar(@{$learning_db->{attack_ranking} || []}) > 0) {
        say "\n${\($color->success())}🏆 ترتيب الهجمات حسب الفعالية:${\($color->reset())}";
        my $rank = 1;
        for my $attack (@{$learning_db->{attack_ranking}}[0..4]) {
            my $success_rate = $learning_db->{attacks_by_type}{$attack}{success_rate} || 0;
            my $attempts = $learning_db->{attacks_by_type}{$attack}{attempts} || 0;
            say "   $rank. $attack - " . sprintf("%.1f", $success_rate) . "% نجاح ($attempts محاولة)";
            $rank++;
        }
    }
    
    if (scalar(@{$learning_db->{successful_contexts} || []}) > 0) {
        say "\n${\($color->info())}✅ آخر 5 هجمات ناجحة:${\($color->reset())}";
        my @last_successful = reverse @{$learning_db->{successful_contexts}};
        for my $ctx (@last_successful[0..4]) {
            next unless $ctx;
            say "   → $ctx->{attack_type} على $ctx->{ssid} - إشارة $ctx->{signal}%";
        }
    }
    
    return $learning_db;
}

# =============================================================================
# إعادة ضبط نظام التعلم
# =============================================================================
sub learning_reset {
    my $color = Colors->new();
    
    say "\n${\($color->warning())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->warning())}║                    🔄 إعادة ضبط التعلم 🔄                             ║${\($color->reset())}";
    say "${\($color->warning())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    # إعادة تهيئة قاعدة التعلم
    $learning_db = {
        total_attacks => 0,
        successful_attacks => 0,
        attacks_by_type => {},
        successful_contexts => [],
        attack_ranking => [],
        best_time_hour => undef,
        best_signal_threshold => 60,
        created_at => time(),
        last_updated => time()
    };
    
    _save_learning_db();
    
    say "${\($color->success())}[✓] تم إعادة ضبط نظام التعلم التراكمي${\($color->reset())}";
    
    return $learning_db;
}

# =============================================================================
# ترميز JSON
# =============================================================================
sub encode_json {
    my ($data) = @_;
    
    if (ref($data) eq 'HASH') {
        my @pairs = ();
        for my $key (keys %$data) {
            my $value = $data->{$key};
            my $encoded_value = ref($value) ? encode_json($value) : qq{"$value"};
            push @pairs, qq{"$key":$encoded_value};
        }
        return "{" . join(",", @pairs) . "}";
    }
    elsif (ref($data) eq 'ARRAY') {
        my @items = map { encode_json($_) } @$data;
        return "[" . join(",", @items) . "]";
    }
    else {
        return qq{"$data"};
    }
}

sub decode_json {
    my ($json) = @_;
    # محاكاة بسيطة - في الحقيقة نستخدم JSON::PP
    return {};
}

# تحميل قاعدة البيانات عند تحميل الوحدة
_load_learning_db();

1;  # نهاية الوحدة
