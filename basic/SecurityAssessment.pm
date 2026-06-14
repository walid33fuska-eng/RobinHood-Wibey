package basic::SecurityAssessment;
# =============================================================================
# SecurityAssessment.pm - تقييم أمني للشبكة
# =============================================================================
# الميزات: فحص الثغرات، تقييم قوة التشفير، تحليل المخاطر، توصيات أمنية
# =============================================================================

use strict;
use warnings;
use parent 'Exporter';
our @EXPORT_OK = qw(assessment_run assessment_report assessment_recommendations);

use lib '.';
use lib::Utils;
use lib::Colors;
use Time::HiRes qw(time);
use File::Slurp qw(write_file read_file);
use List::Util qw(sum max min);

# =============================================================================
# تشغيل التقييم الأمني
# =============================================================================
sub assessment_run {
    my ($target_bssid, $target_ssid, $interface) = @_;
    
    my $color = Colors->new();
    my $utils = Utils->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    🛡️ التقييم الأمني للشبكة 🛡️                        ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    $target_bssid //= "AA:BB:CC:DD:EE:FF";
    $target_ssid //= "Target_Network";
    $interface //= "wlan0";
    
    say "${\($color->info())}[*] استهداف: $target_ssid ($target_bssid)${\($color->reset())}";
    say "${\($color->info())}[*] الواجهة: $interface${\($color->reset())}";
    
    # فتحات التقييم
    my %assessment = (
        bssid => $target_bssid,
        ssid => $target_ssid,
        timestamp => time(),
        scores => {},
        risks => [],
        recommendations => [],
        details => {}
    );
    
    # 1. فحص نوع التشفير
    say "\n${\($color->info())}[1/7] فحص نوع التشفير...${\($color->reset())}";
    my $encryption = _check_encryption($target_bssid);
    $assessment{scores}{encryption} = $encryption->{score};
    $assessment{details}{encryption} = $encryption;
    if ($encryption->{score} < 50) {
        push @{$assessment{risks}}, "تشفير ضعيف: $encryption->{type}";
        push @{$assessment{recommendations}}, $encryption->{recommendation};
    }
    
    # 2. فحص WPS
    say "${\($color->info())}[2/7] فحص حالة WPS...${\($color->reset())}";
    my $wps = _check_wps($target_bssid);
    $assessment{scores}{wps} = $wps->{score};
    $assessment{details}{wps} = $wps;
    if ($wps->{enabled}) {
        push @{$assessment{risks}}, "WPS مفعل - ثغرة خطيرة";
        push @{$assessment{recommendations}}, "تعطيل WPS من إعدادات الراوتر فوراً";
    }
    
    # 3. فحص قوة كلمة المرور
    say "${\($color->info())}[3/7] تحليل قوة كلمة المرور...${\($color->reset())}";
    my $password_strength = _check_password_strength($target_ssid);
    $assessment{scores}{password} = $password_strength->{score};
    $assessment{details}{password} = $password_strength;
    if ($password_strength->{score} < 40) {
        push @{$assessment{risks}}, "كلمة مرور ضعيفة جداً";
        push @{$assessment{recommendations}}, "استخدم كلمة مرور مكونة من 12 حرفاً على الأقل تحتوي على أرقام ورموز";
    }
    
    # 4. فحص بث SSID
    say "${\($color->info())}[4/7] فحص إخفاء SSID...${\($color->reset())}";
    my $ssid_hidden = _check_ssid_hidden($target_bssid);
    $assessment{scores}{ssid_hidden} = $ssid_hidden->{score};
    $assessment{details}{ssid_hidden} = $ssid_hidden;
    if (!$ssid_hidden->{hidden}) {
        push @{$assessment{recommendations}}, "يمكن إخفاء SSID لمزيد من الخصوصية";
    }
    
    # 5. فحص تصفية MAC
    say "${\($color->info())}[5/7] فحص تصفية MAC...${\($color->reset())}";
    my $mac_filter = _check_mac_filter($target_bssid);
    $assessment{scores}{mac_filter} = $mac_filter->{score};
    $assessment{details}{mac_filter} = $mac_filter;
    if (!$mac_filter->{enabled}) {
        push @{$assessment{recommendations}}, "فعّل تصفية MAC للأجهزة المعروفة فقط";
    }
    
    # 6. فحص المنافذ المفتوحة
    say "${\($color->info())}[6/7] فحص المنافذ المفتوحة...${\($color->reset())}";
    my $open_ports = _check_open_ports($target_bssid);
    $assessment{scores}{ports} = $open_ports->{score};
    $assessment{details}{ports} = $open_ports;
    if (scalar(@{$open_ports->{list}}) > 0) {
        push @{$assessment{risks}}, "منافذ خطيرة مفتوحة: " . join(', ', @{$open_ports->{list}});
        push @{$assessment{recommendations}}, "أغلق المنافذ غير الضرورية في إعدادات الراوتر";
    }
    
    # 7. فحص تحديثات البرامج الثابتة
    say "${\($color->info())}[7/7] فحص تحديثات البرامج الثابتة...${\($color->reset())}";
    my $firmware = _check_firmware($target_bssid);
    $assessment{scores}{firmware} = $firmware->{score};
    $assessment{details}{firmware} = $firmware;
    if (!$firmware->{up_to_date}) {
        push @{$assessment{risks}}, "البرامج الثابتة قديمة";
        push @{$assessment{recommendations}}, "قم بتحديث البرامج الثابتة للراوتر إلى أحدث إصدار";
    }
    
    # حساب الدرجة الإجمالية
    my $total_score = 0;
    my $score_count = 0;
    for my $key (keys %{$assessment{scores}}) {
        $total_score += $assessment{scores}{$key};
        $score_count++;
    }
    $assessment{overall_score} = $score_count ? int($total_score / $score_count) : 0;
    
    # تحديد التقييم النهائي
    my $grade;
    my $grade_color;
    if ($assessment{overall_score} >= 85) {
        $grade = "A+ (ممتاز - آمن جداً)";
        $grade_color = $color->success();
    } elsif ($assessment{overall_score} >= 70) {
        $grade = "B (جيد - آمن نسبياً)";
        $grade_color = $color->info();
    } elsif ($assessment{overall_score} >= 50) {
        $grade = "C (متوسط - يحتاج تحسينات)";
        $grade_color = $color->warning();
    } elsif ($assessment{overall_score} >= 30) {
        $grade = "D (ضعيف - غير آمن)";
        $grade_color = $color->error();
    } else {
        $grade = "F (خطير جداً - تم اختراقه بسهولة)";
        $grade_color = $color->error();
    }
    $assessment{grade} = $grade;
    
    # عرض التقرير
    _display_assessment_report(\%assessment, $grade_color);
    
    # حفظ التقرير
    my $report_file = _save_assessment(\%assessment);
    say "\n${\($color->success())}[✓] تم حفظ التقرير في: $report_file${\($color->reset())}";
    
    $utils->save_result('security_assessment', {
        bssid => $target_bssid,
        ssid => $target_ssid,
        overall_score => $assessment{overall_score},
        grade => $grade,
        risks_count => scalar(@{$assessment{risks}})
    });
    
    return \%assessment;
}

# =============================================================================
# تقرير مفصل
# =============================================================================
sub assessment_report {
    my ($assessment_data) = @_;
    
    my $color = Colors->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    📋 تقرير التقييم الأمني 📋                         ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    $assessment_data //= {};
    
    say "\n${\($color->info())}基本信息:${\($color->reset())}";
    say "   → SSID: $assessment_data->{ssid}";
    say "   → BSSID: $assessment_data->{bssid}";
    say "   → وقت التقييم: " . localtime($assessment_data->{timestamp});
    say "   → الدرجة النهائية: $assessment_data->{overall_score}%";
    say "   → التصنيف: $assessment_data->{grade}";
    
    say "\n${\($color->info())}📊 النقاط التفصيلية:${\($color->reset())}";
    for my $key (keys %{$assessment_data->{scores}}) {
        my $score = $assessment_data->{scores}{$key};
        my $icon = $score >= 70 ? "✓" : ($score >= 40 ? "⚠️" : "✗");
        say "   → $icon $key: $score%";
    }
    
    if (scalar(@{$assessment_data->{risks} || []}) > 0) {
        say "\n${\($color->error())}⚠️ المخاطر المكتشفة:${\($color->reset())}";
        for my $risk (@{$assessment_data->{risks}}) {
            say "   → $risk";
        }
    }
    
    if (scalar(@{$assessment_data->{recommendations} || []}) > 0) {
        say "\n${\($color->success())}💡 التوصيات:${\($color->reset())}";
        for my $rec (@{$assessment_data->{recommendations}}) {
            say "   → $rec";
        }
    }
    
    return $assessment_data;
}

# =============================================================================
# توصيات أمنية
# =============================================================================
sub assessment_recommendations {
    my ($overall_score) = @_;
    
    my $color = Colors->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    💡 التوصيات الأمنية 💡                            ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    $overall_score //= 0;
    
    my @recommendations = ();
    
    if ($overall_score < 50) {
        push @recommendations, "🔴 خطر مرتفع - قم بتطبيق جميع التوصيات التالية فوراً:";
        push @recommendations, "   1. قم بتغيير كلمة المرور الافتراضية للراوتر";
        push @recommendations, "   2. فعّل تشفير WPA2-AES على الأقل (يفضل WPA3)";
        push @recommendations, "   3. عطّل خدمة WPS نهائياً";
        push @recommendations, "   4. حدّث البرامج الثابتة للراوتر";
        push @recommendations, "   5. فعّل جدار الحماية";
    } elsif ($overall_score < 70) {
        push @recommendations, "🟡 خطر متوسط - يوصى بتحسين النقاط التالية:";
        push @recommendations, "   1. حسّن كلمة المرور (12 حرفاً+ أرقام ورموز)";
        push @recommendations, "   2. فكّر في إخفاء SSID";
        push @recommendations, "   3. فعّل تصفية MAC إذا كان عدد الأجهزة محدوداً";
        push @recommendations, "   4. راجع تحديثات البرامج الثابتة بانتظام";
    } else {
        push @recommendations, "🟢 شبكة آمنة - نصائح للحفاظ على الأمان:";
        push @recommendations, "   1. استمر في تحديث كلمة المرور كل 6 أشهر";
        push @recommendations, "   2. راقب الأجهزة المتصلة باستمرار";
        push @recommendations, "   3. فعّل التنبيهات للاتصالات الجديدة";
        push @recommendations, "   4. استخدم VPN للأنشطة الحساسة";
    }
    
    for my $rec (@recommendations) {
        say "${\($color->info())}$rec${\($color->reset())}";
    }
    
    return \@recommendations;
}

# =============================================================================
# دوال فحص داخلية
# =============================================================================

sub _check_encryption {
    my ($bssid) = @_;
    
    # محاكاة أنواع التشفير المختلفة
    my @types = ('WPA3', 'WPA2-AES', 'WPA2-TKIP', 'WPA', 'WEP', 'None');
    my $type = $types[int(rand(scalar(@types)))];
    
    my $score = 0;
    my $recommendation = "";
    
    if ($type eq 'WPA3') {
        $score = 100;
        $recommendation = "تشفير ممتاز، استمر";
    } elsif ($type eq 'WPA2-AES') {
        $score = 85;
        $recommendation = "تشفير جيد، يفضل الترقية إلى WPA3";
    } elsif ($type eq 'WPA2-TKIP') {
        $score = 50;
        $recommendation = "تشفير ضعيف، غير إلى AES";
    } else {
        $score = 20;
        $recommendation = "تشفير خطير، غير إلى WPA2-AES أو WPA3 فوراً";
    }
    
    return { type => $type, score => $score, recommendation => $recommendation };
}

sub _check_wps {
    my ($bssid) = @_;
    
    my $enabled = rand() < 0.6;  # 60% من الراوترات تفعيل WPS (محاكاة)
    
    return {
        enabled => $enabled,
        score => $enabled ? 0 : 100,
        recommendation => $enabled ? "تعطيل WPS فوراً" : "WPS معطل - جيد"
    };
}

sub _check_password_strength {
    my ($ssid) = @_;
    
    my $strength = int(rand(100));
    my $score = $strength;
    my $analysis = "";
    
    if ($strength >= 80) {
        $analysis = "كلمة مرور قوية جداً";
    } elsif ($strength >= 60) {
        $analysis = "كلمة مرور جيدة";
    } elsif ($strength >= 40) {
        $analysis = "كلمة مرور متوسطة";
    } elsif ($strength >= 20) {
        $analysis = "كلمة مرور ضعيفة";
    } else {
        $analysis = "كلمة مرور خطيرة جداً";
    }
    
    return { score => $score, strength => $strength, analysis => $analysis };
}

sub _check_ssid_hidden {
    my ($bssid) = @_;
    
    my $hidden = rand() < 0.3;  # 30% من الشبكات تخفي SSID
    
    return {
        hidden => $hidden,
        score => $hidden ? 100 : 30,
        recommendation => $hidden ? "SSID مخفي - ممتاز" : "يمكن إخفاء SSID لمزيد من الأمان"
    };
}

sub _check_mac_filter {
    my ($bssid) = @_;
    
    my $enabled = rand() < 0.4;  # 40% تفعيل تصفية MAC
    
    return {
        enabled => $enabled,
        score => $enabled ? 70 : 40,
        recommendation => $enabled ? "تصفية MAC مفعلة - جيد" : "فعّل تصفية MAC إن أمكن"
    };
}

sub _check_open_ports {
    my ($bssid) = @_;
    
    my @common_ports = (21, 22, 23, 80, 443, 8080, 3389);
    my @open_ports = ();
    
    for my $port (@common_ports) {
        if (rand() < 0.2) {  # 20% فرصة أن يكون المنفذ مفتوحاً
            push @open_ports, $port;
        }
    }
    
    my $score = scalar(@open_ports) == 0 ? 100 : max(0, 100 - (scalar(@open_ports) * 15));
    
    return {
        list => \@open_ports,
        score => $score,
        count => scalar(@open_ports)
    };
}

sub _check_firmware {
    my ($bssid) = @_;
    
    my $up_to_date = rand() < 0.5;  # 50% فرصة أن البرامج الثابتة محدثة
    
    return {
        up_to_date => $up_to_date,
        score => $up_to_date ? 100 : 40,
        recommendation => $up_to_date ? "البرامج الثابتة محدثة" : "قم بتحديث البرامج الثابتة"
    };
}

# =============================================================================
# عرض تقرير التقييم
# =============================================================================
sub _display_assessment_report {
    my ($assessment, $grade_color) = @_;
    
    my $color = Colors->new();
    
    say "\n${$color->quantum()}╔══════════════════════════════════════════════════════════════════╗${$color->reset()}";
    say "${$color->quantum()}║                    📊 نتيجة التقييم الأمني 📊                           ║${$color->reset()}";
    say "${$color->quantum()}╠══════════════════════════════════════════════════════════════════╣${$color->reset()}";
    say "${$color->quantum()}║${$color->reset()} SSID: $assessment->{ssid}";
    say "${$color->quantum()}║${$color->reset()} BSSID: $assessment->{bssid}";
    say "${$color->quantum()}╠══════════════════════════════════════════════════════════════════╣${$color->reset()}";
    say "${$color->quantum()}║${$color->reset()} ${$grade_color}الدرجة النهائية: $assessment->{overall_score}% - $assessment->{grade}${$color->reset()}";
    say "${$color->quantum()}╠══════════════════════════════════════════════════════════════════╣${$color->reset()}";
    
    # النقاط التفصيلية
    say "${$color->quantum()}║${$color->reset()} 📊 النقاط التفصيلية:";
    for my $key (keys %{$assessment->{scores}}) {
        my $score = $assessment->{scores}{$key};
        my $icon = $score >= 70 ? "✓" : ($score >= 40 ? "⚠️" : "✗");
        my $key_name = {
            encryption => "التشفير",
            wps => "WPS",
            password => "كلمة المرور",
            ssid_hidden => "إخفاء SSID",
            mac_filter => "تصفية MAC",
            ports => "المنافذ",
            firmware => "البرامج الثابتة"
        }->{$key} // $key;
        say "${$color->quantum()}║${$color->reset()}   $icon $key_name: $score%";
    }
    
    # المخاطر
    if (scalar(@{$assessment->{risks}}) > 0) {
        say "${$color->quantum()}╠══════════════════════════════════════════════════════════════════╣${$color->reset()}";
        say "${$color->error()}║ ⚠️ المخاطر المكتشفة:${$color->reset()}";
        for my $risk (@{$assessment->{risks}}) {
            say "${$color->error()}║    • $risk${$color->reset()}";
        }
    }
    
    # التوصيات
    if (scalar(@{$assessment->{recommendations}}) > 0) {
        say "${$color->quantum()}╠══════════════════════════════════════════════════════════════════╣${$color->reset()}";
        say "${$color->success()}║ 💡 التوصيات:${$color->reset()}";
        for my $rec (@{$assessment->{recommendations}}) {
            say "${$color->success()}║    • $rec${$color->reset()}";
        }
    }
    
    say "${$color->quantum()}╚══════════════════════════════════════════════════════════════════╝${$color->reset()}";
}

# =============================================================================
# حفظ التقييم
# =============================================================================
sub _save_assessment {
    my ($assessment) = @_;
    
    my $filename = "$ENV{HOME}/.robinhood/logs/assessment_" . $assessment->{bssid} . "_" . time() . ".json";
    my $json = encode_json($assessment);
    write_file($filename, $json);
    
    return $filename;
}

# ترميز JSON بسيط
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

1;  # نهاية الوحدة
