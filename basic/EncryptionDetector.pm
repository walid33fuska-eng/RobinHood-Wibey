package basic::EncryptionDetector;
# =============================================================================
# EncryptionDetector.pm - كشف نوع التشفير لشبكات الواي فاي
# =============================================================================
# الميزات: تحديد نوع التشفير، كشف نقاط الضعف في التشفير، اقتراح تحسينات
# =============================================================================

use strict;
use warnings;
use parent 'Exporter';
our @EXPORT_OK = qw(encryption_detect encryption_analyze encryption_recommend);

use lib '.';
use lib::Utils;
use lib::Colors;
use Time::HiRes qw(time);
use File::Slurp qw(write_file);

# =============================================================================
# كشف نوع التشفير
# =============================================================================
sub encryption_detect {
    my ($target_bssid, $interface) = @_;
    
    my $color = Colors->new();
    my $utils = Utils->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    🔐 كشف نوع التشفير 🔐                              ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    $target_bssid //= "AA:BB:CC:DD:EE:FF";
    $interface //= "wlan0";
    
    say "${\($color->info())}[*] الهدف: $target_bssid${\($color->reset())}";
    say "${\($color->info())}[*] الواجهة: $interface${\($color->reset())}";
    
    # محاكاة كشف التشفير
    my $encryption_info = _detect_encryption_type($target_bssid);
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    📡 نتائج كشف التشفير 📡                           ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    # عرض النتائج
    my $encryption_color;
    if ($encryption_info->{security_level} eq 'ممتاز') {
        $encryption_color = $color->success();
    } elsif ($encryption_info->{security_level} eq 'جيد') {
        $encryption_color = $color->info();
    } elsif ($encryption_info->{security_level} eq 'ضعيف') {
        $encryption_color = $color->warning();
    } else {
        $encryption_color = $color->error();
    }
    
    say "\n${\($color->info())}🔒 معلومات التشفير:${\($color->reset())}";
    say "   → النوع: $encryption_info->{type}";
    say "   → الخوارزمية: $encryption_info->{algorithm}";
    say "   → قوة المفتاح: $encryption_info->{key_strength}";
    say "   → مستوى الأمان: ${\($encryption_color)}$encryption_info->{security_level}${\($color->reset())}";
    say "   → وقت الاختراق المتوقع: $encryption_info->{crack_time}";
    
    # نقاط الضعف
    if (scalar(@{$encryption_info->{weaknesses}}) > 0) {
        say "\n${\($color->warning())}⚠️ نقاط الضعف المكتشفة:${\($color->reset())}";
        for my $weakness (@{$encryption_info->{weaknesses}}) {
            say "   → $weakness";
        }
    }
    
    $utils->save_result('encryption_detector', {
        bssid => $target_bssid,
        encryption_type => $encryption_info->{type},
        security_level => $encryption_info->{security_level}
    });
    
    return $encryption_info;
}

# =============================================================================
# تحليل نقاط قوة وضعف التشفير
# =============================================================================
sub encryption_analyze {
    my ($encryption_info) = @_;
    
    my $color = Colors->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    📊 تحليل التشفير 📊                               ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    $encryption_info //= _detect_encryption_type();
    
    say "\n${\($color->info())}🔬 التحليل التفصيلي:${\($color->reset())}";
    
    # تحليل حسب نوع التشفير
    my $analysis = _analyze_encryption_strength($encryption_info);
    
    say "   → الثغرات المعروفة:";
    for my $vuln (@{$analysis->{known_vulnerabilities}}) {
        say "      • $vuln";
    }
    
    say "\n   → الهجمات الفعالة ضد هذا التشفير:";
    for my $attack (@{$analysis->{effective_attacks}}) {
        say "      • $attack";
    }
    
    say "\n   → صعوبة الاختراق: $analysis->{difficulty}";
    say "   → الوقت المقدر للاختراق: $analysis->{estimated_time}";
    
    return $analysis;
}

# =============================================================================
# اقتراح تحسينات للتشفير
# =============================================================================
sub encryption_recommend {
    my ($encryption_info) = @_;
    
    my $color = Colors->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    💡 توصيات تحسين التشفير 💡                        ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    $encryption_info //= _detect_encryption_type();
    
    my $recommendations = _generate_recommendations($encryption_info);
    
    say "\n${\($color->success())}📋 التوصيات:${\($color->reset())}";
    for my $rec (@$recommendations) {
        say "   → $rec";
    }
    
    return $recommendations;
}

# =============================================================================
# دوال مساعدة داخلية
# =============================================================================

sub _detect_encryption_type {
    my ($bssid) = @_;
    
    # محاكاة أنواع التشفير المختلفة
    my @encryption_types = (
        { 
            type => 'WPA3-Personal',
            algorithm => 'SAE (Simultaneous Authentication of Equals)',
            key_strength => '256-bit',
            security_level => 'ممتاز',
            crack_time => 'غير ممكن عملياً',
            weaknesses => []
        },
        {
            type => 'WPA2-Enterprise',
            algorithm => 'AES-CCMP',
            key_strength => '128-bit',
            security_level => 'جيد',
            crack_time => 'سنوات',
            weaknesses => ['RADIUS server vulnerabilities', 'Misconfiguration risks']
        },
        {
            type => 'WPA2-PSK',
            algorithm => 'AES-CCMP أو TKIP',
            key_strength => '128-bit',
            security_level => 'جيد',
            crack_time => 'أيام إلى سنوات (حسب قوة كلمة المرور)',
            weaknesses => ['عرضة لهجمات القاموس', 'PMKID attack', 'KRACK']
        },
        {
            type => 'WPA-PSK',
            algorithm => 'TKIP',
            key_strength => '128-bit',
            security_level => 'ضعيف',
            crack_time => 'ساعات إلى أيام',
            weaknesses => ['ثغرة ChopChop', 'Michael MIC attack', 'Beck-Tews attack']
        },
        {
            type => 'WEP',
            algorithm => 'RC4',
            key_strength => '64-bit أو 128-bit',
            security_level => 'خطير',
            crack_time => 'دقائق',
            weaknesses => ['IV collision attacks', 'ARP replay', 'ChopChop', 'FMS attack']
        },
        {
            type => 'مفتوحة (بدون تشفير)',
            algorithm => 'لا يوجد',
            key_strength => '0-bit',
            security_level => 'خطير جداً',
            crack_time => 'فوري',
            weaknesses => ['جميع البيانات مرسلة بدون تشفير', 'سهولة التنصت', 'هجمات MITM']
        }
    );
    
    # اختيار عشوائي للمحاكاة
    my $encryption = $encryption_types[int(rand(@encryption_types))];
    
    return $encryption;
}

sub _analyze_encryption_strength {
    my ($encryption) = @_;
    
    my %analysis = (
        'WPA3-Personal' => {
            known_vulnerabilities => ['Dragonblood (تم إصلاحه)', 'Side-channel attacks (نادرة)'],
            effective_attacks => ['Social engineering', 'هجمات القاموس الضعيفة'],
            difficulty => 'صعب جداً',
            estimated_time => 'غير ممكن عملياً'
        },
        'WPA2-Enterprise' => {
            known_vulnerabilities => ['KRACK (تم إصلاحه)', 'Heartbleed في بعض RADIUS'],
            effective_attacks => ['هجمات القاموس على كلمة مرور RADIUS', 'Evil Twin مع RADIUS'],
            difficulty => 'صعب',
            estimated_time => 'أشهر إلى سنوات'
        },
        'WPA2-PSK' => {
            known_vulnerabilities => ['KRACK', 'PMKID attack', 'هجمات القاموس'],
            effective_attacks => ['PMKID capture', 'Handshake capture', 'Dictionary attack', 'Brute force'],
            difficulty => 'متوسط إلى صعب',
            estimated_time => 'أيام إلى سنوات'
        },
        'WPA-PSK' => {
            known_vulnerabilities => ['ChopChop', 'Michael MIC', 'Beck-Tews', 'KRACK'],
            effective_attacks => ['Deauth + Handshake capture', 'Dictionary attack'],
            difficulty => 'سهل إلى متوسط',
            estimated_time => 'ساعات إلى أيام'
        },
        'WEP' => {
            known_vulnerabilities => ['IV collision', 'FMS attack', 'KoreK attack', 'ARP replay'],
            effective_attacks => ['ARP replay', 'ChopChop', 'Fragmentation'],
            difficulty => 'سهل جداً',
            estimated_time => 'دقائق'
        },
        'مفتوحة' => {
            known_vulnerabilities => ['بدون تشفير - جميع البيانات مكشوفة'],
            effective_attacks => ['تنصت مباشر', 'Hijacking', 'MITM'],
            difficulty => 'تافه',
            estimated_time => 'فوري'
        }
    );
    
    return $analysis{$encryption->{type}} || $analysis{'WPA2-PSK'};
}

sub _generate_recommendations {
    my ($encryption) = @_;
    
    my @recommendations = ();
    
    if ($encryption->{type} eq 'WPA3-Personal') {
        push @recommendations, '✓ التشفير الحالي ممتاز، استمر في استخدامه';
        push @recommendations, '✓ تأكد من استخدام أحدث إصدار من البرامج الثابتة';
        push @recommendations, '✓ استخدم كلمة مرور قوية (12 حرفاً+ أرقام ورموز)';
    }
    elsif ($encryption->{type} eq 'WPA2-Enterprise') {
        push @recommendations, '✓ قم بالترقية إلى WPA3 إذا كان الراوتر يدعمه';
        push @recommendations, '✓ تأكد من تحديث خادم RADIUS باستمرار';
        push @recommendations, '✓ استخدم شهادات قوية وتجنب الشهادات الذاتية';
    }
    elsif ($encryption->{type} eq 'WPA2-PSK') {
        push @recommendations, '✓ قم بالترقية إلى WPA3 إذا كان الراوتر يدعمه';
        push @recommendations, '✓ استخدم AES فقط وعطل TKIP';
        push @recommendations, '✓ استخدم كلمة مرور قوية جداً (أكثر من 12 حرفاً)';
        push @recommendations, '✓ فعّل WPS فقط إذا كان ضرورياً ثم عطله بعد الإعداد';
    }
    elsif ($encryption->{type} eq 'WPA-PSK') {
        push @recommendations, '⚠️ خطر مرتفع - قم بالترقية إلى WPA2 أو WPA3 فوراً';
        push @recommendations, '⚠️ قم بتغيير كلمة المرور إلى كلمة قوية جداً مؤقتاً';
        push @recommendations, '⚠️ ابحث عن تحديث للبرامج الثابتة يدعم WPA2';
    }
    elsif ($encryption->{type} eq 'WEP') {
        push @recommendations, '🔴 خطر شديد - قم بشراء راوتر حديث يدعم WPA2/WPA3';
        push @recommendations, '🔴 لا تستخدم هذا الراوتر لأي شيء حساس';
        push @recommendations, '🔴 قم بتغيير الراوتر فوراً';
    }
    else {
        push @recommendations, '🔴 شبكة مفتوحة - خطيرة جداً';
        push @recommendations, '🔴 لا تستخدم هذه الشبكة لنقل أي بيانات حساسة';
        push @recommendations, '🔴 استخدم VPN إذا اضطررت للاتصال بها';
        push @recommendations, '🔴 قم بتأمين الشبكة بتفعيل WPA2/WPA3';
    }
    
    # توصيات إضافية عامة
    push @recommendations, '✓ قم بتحديث البرامج الثابتة للراوتر بانتظام';
    push @recommendations, '✓ عطّل WPS إذا لم تكن بحاجة إليه';
    push @recommendations, '✓ قم بتغيير اسم المستخدم وكلمة المرور الافتراضية للراوتر';
    
    return \@recommendations;
}

1;  # نهاية الوحدة
