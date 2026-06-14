package post::SecurityTips;
# =============================================================================
# SecurityTips.pm - نصائح وتوصيات أمنية
# =============================================================================
# الميزات: نصائح أمنية مخصصة، توصيات حسب السياق، تحسين الأمان، تعليمات وقائية
# =============================================================================

use strict;
use warnings;
use parent 'Exporter';
our @EXPORT_OK = qw(tips_generate tips_customize tips_schedule tips_export);

use lib '.';
use lib::Utils;
use lib::Colors;
use Time::HiRes qw(time);
use File::Slurp qw(read_file write_file);
use JSON;

# قاعدة بيانات النصائح الأمنية
my @SECURITY_TIPS = (
    {
        id => 1,
        category => "passwords",
        title => "استخدم كلمات مرور قوية",
        content => "استخدم كلمات مرور بطول 12 حرفاً على الأقل تحتوي على أحرف كبيرة وصغيرة وأرقام ورموز خاصة.",
        priority => "high",
        tags => ["passwords", "authentication"]
    },
    {
        id => 2,
        category => "network",
        title => "تعطيل WPS",
        content => "WPS لديه ثغرات أمنية خطيرة، قم بتعطيله من إعدادات الراوتر فوراً.",
        priority => "critical",
        tags => ["wifi", "wps", "router"]
    },
    {
        id => 3,
        category => "encryption",
        title => "استخدم تشفير WPA3",
        content => "قم بالترقية إلى WPA3 إذا كان جهازك يدعمه، وإلا استخدم WPA2-AES وتجنب TKIP.",
        priority => "high",
        tags => ["wifi", "encryption"]
    },
    {
        id => 4,
        category => "firmware",
        title => "حدّث البرامج الثابتة",
        content => "قم بتحديث البرامج الثابتة للراوتر بانتظام للحصول على أحدث التصحيحات الأمنية.",
        priority => "medium",
        tags => ["router", "updates"]
    },
    {
        id => 5,
        category => "monitoring",
        title => "راقب الأجهزة المتصلة",
        content => "تحقق بانتظام من الأجهزة المتصلة بشبكتك وتعرف على أي جهاز غير معروف.",
        priority => "medium",
        tags => ["monitoring", "devices"]
    },
    {
        id => 6,
        category => "ssid",
        title => "لا تخفِ SSID",
        content => "إخفاء SSID لا يوفر أماناً حقيقياً وقد يسبب مشاكل في الاتصال لأجهزتك.",
        priority => "low",
        tags => ["ssid", "wifi"]
    },
    {
        id => 7,
        category => "admin",
        title => "غيّر بيانات الدخول الافتراضية",
        content => "غيّر اسم المستخدم وكلمة المرور الافتراضية للراوتر فوراً.",
        priority => "critical",
        tags => ["admin", "router"]
    },
    {
        id => 8,
        category => "remote",
        title => "عطّل الوصول عن بُعد",
        content => "قم بتعطيل الوصول عن بُعد إلى لوحة تحكم الراوتر إلا إذا كنت بحاجة ماسة إليه.",
        priority => "high",
        tags => ["remote", "security"]
    },
    {
        id => 9,
        category => "guest",
        title => "استخدم شبكة ضيوف",
        content => "قم بإنشاء شبكة ضيوف منفصلة للزوار والأجهزة غير الموثوقة.",
        priority => "medium",
        tags => ["guest", "network"]
    },
    {
        id => 10,
        category => "vpn",
        title => "استخدم VPN",
        content => "استخدم VPN لحماية خصوصيتك وتشفير اتصالك خاصة على الشبكات العامة.",
        priority => "medium",
        tags => ["vpn", "privacy"]
    }
);

# =============================================================================
# توليد نصائح أمنية
# =============================================================================
sub tips_generate {
    my ($category, $count, $priority) = @_;
    
    my $color = Colors->new();
    my $utils = Utils->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    💡 نصائح أمنية 💡                                 ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    $category //= "all";
    $count //= 5;
    $priority //= "all";
    
    say "${\($color->info())}[*] توليد نصائح أمنية (الفئة: $category, العدد: $count)${\($color->reset())}";
    
    # تصفية النصائح
    my @filtered = @SECURITY_TIPS;
    
    if ($category ne "all") {
        @filtered = grep { $_->{category} eq $category } @filtered;
    }
    
    if ($priority ne "all") {
        @filtered = grep { $_->{priority} eq $priority } @filtered;
    }
    
    # ترتيب حسب الأولوية
    my %priority_order = (
        'critical' => 1,
        'high' => 2,
        'medium' => 3,
        'low' => 4
    );
    
    @filtered = sort { $priority_order{$a->{priority}} <=> $priority_order{$b->{priority}} } @filtered;
    
    # أخذ العدد المطلوب
    if (scalar(@filtered) > $count) {
        @filtered = @filtered[0..$count-1];
    }
    
    # عرض النصائح
    say "\n${\($color->success())}📋 قائمة النصائح الأمنية:${\($color->reset())}";
    
    for my $i (0..$#filtered) {
        my $tip = $filtered[$i];
        my $priority_color;
        
        if ($tip->{priority} eq 'critical') {
            $priority_color = $color->error();
        } elsif ($tip->{priority} eq 'high') {
            $priority_color = $color->warning();
        } elsif ($tip->{priority} eq 'medium') {
            $priority_color = $color->info();
        } else {
            $priority_color = $color->success();
        }
        
        say "\n   " . ($i+1) . ". ${\($color->quantum())}$tip->{title}${\($color->reset())}";
        say "      → ${\($priority_color)}[${\($color->reset())}$tip->{priority}${\($priority_color)}]${\($color->reset())} $tip->{content}";
    }
    
    $utils->save_result('security_tips', {
        action => 'generate',
        category => $category,
        count => scalar(@filtered),
        priority => $priority
    });
    
    return \@filtered;
}

# =============================================================================
# تخصيص النصائح
# =============================================================================
sub tips_customize {
    my ($target_info, $vulnerabilities) = @_;
    
    my $color = Colors->new();
    my $utils = Utils->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    🎯 نصائح مخصصة 🎯                                ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    $target_info //= {
        ssid => "Home_Network",
        encryption => "WPA2",
        wps_enabled => 1,
        firmware_age => 365
    };
    
    $vulnerabilities //= [
        "wps_enabled", "old_firmware", "weak_password"
    ];
    
    say "${\($color->info())}[*] إنشاء نصائح مخصصة للهدف: $target_info->{ssid}${\($color->reset())}";
    
    my @custom_tips = ();
    
    # نصائح بناءً على الثغرات المكتشفة
    if (grep { $_ eq 'wps_enabled' } @$vulnerabilities) {
        push @custom_tips, {
            title => "⚠️ ثغرة WPS مكتشفة!",
            content => "WPS مفعل على الراوتر. قم بتعطيله فوراً من إعدادات الراوتر لأنه يسمح باختراق الشبكة بسهولة.",
            urgency => "فوري",
            action => "تعطيل WPS"
        };
    }
    
    if (grep { $_ eq 'old_firmware' } @$vulnerabilities) {
        push @custom_tips, {
            title => "⚠️ برامج ثابتة قديمة",
            content => "البرامج الثابتة للراوتر قديمة جداً. قم بتحديثها إلى أحدث إصدار للحصول على التصحيحات الأمنية.",
            urgency => "عاجل",
            action => "تحديث البرامج الثابتة"
        };
    }
    
    if (grep { $_ eq 'weak_password' } @$vulnerabilities) {
        push @custom_tips, {
            title => "⚠️ كلمة مرور ضعيفة",
            content => "كلمة مرور الشبكة ضعيفة وقابلة للاختراق. استخدم كلمة مرور قوية مكونة من 12 حرفاً على الأقل.",
            urgency => "عاجل",
            action => "تغيير كلمة المرور"
        };
    }
    
    if (grep { $_ eq 'default_credentials' } @$vulnerabilities) {
        push @custom_tips, {
            title => "⚠️ بيانات دخول افتراضية",
            content => "لا تزال تستخدم اسم المستخدم وكلمة المرور الافتراضية للراوتر. قم بتغييرها فوراً.",
            urgency => "فوري",
            action => "تغيير بيانات الدخول"
        };
    }
    
    # نصائح عامة إذا لم تكن هناك ثغرات محددة
    if (scalar(@custom_tips) == 0) {
        push @custom_tips, {
            title => "✅ شبكة آمنة نسبياً",
            content => "لم يتم اكتشاف ثغرات خطيرة. استمر في اتباع ممارسات الأمان الجيدة.",
            urgency => "روتيني",
            action => "مراجعة دورية"
        };
        
        push @custom_tips, {
            title => "📊 تحسين مستمر",
            content => "قم بمراجعة إعدادات الأمان كل 3 أشهر وتأكد من تحديث جميع الأجهزة.",
            urgency => "شهري",
            action => "مراجعة دورية"
        };
    }
    
    # عرض النصائح المخصصة
    say "\n${\($color->success())}🎯 النصائح المخصصة:${\($color->reset())}";
    
    for my $i (0..$#custom_tips) {
        my $tip = $custom_tips[$i];
        my $urgency_color = $tip->{urgency} eq 'فوري' ? $color->error() :
                            ($tip->{urgency} eq 'عاجل' ? $color->warning() : $color->info());
        
        say "\n   " . ($i+1) . ". ${\($color->quantum())}$tip->{title}${\($color->reset())}";
        say "      → الإلحاح: ${\($urgency_color)}$tip->{urgency}${\($color->reset())}";
        say "      → $tip->{content}";
        say "      → الإجراء: ${\($color->success())}$tip->{action}${\($color->reset())}";
    }
    
    $utils->save_result('security_tips', {
        action => 'customize',
        target => $target_info->{ssid},
        tips_count => scalar(@custom_tips)
    });
    
    return \@custom_tips;
}

# =============================================================================
# جدولة النصائح
# =============================================================================
sub tips_schedule {
    my ($frequency, $delivery_method, $recipient) = @_;
    
    my $color = Colors->new();
    my $utils = Utils->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    ⏰ جدولة النصائح ⏰                               ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    $frequency //= "weekly";
    $delivery_method //= "terminal";
    $recipient //= "";
    
    say "${\($color->info())}[*] إعداد جدولة النصائح (التكرار: $frequency)${\($color->reset())}";
    
    my $schedule = {
        frequency => $frequency,
        delivery_method => $delivery_method,
        recipient => $recipient,
        enabled => 1,
        created_at => time(),
        next_delivery => _calculate_next_delivery($frequency)
    };
    
    # حفظ الجدولة
    my $schedule_file = "$ENV{HOME}/.robinhood/config/tips_schedule.json";
    write_file($schedule_file, encode_json($schedule));
    
    say "\n${\($color->success())}[✓] تم إعداد جدولة النصائح:${\($color->reset())}";
    say "   → التكرار: $frequency";
    say "   → طريقة الإرسال: $delivery_method";
    say "   → موعد الإرسال التالي: " . localtime($schedule->{next_delivery});
    
    if ($recipient) {
        say "   → المستلم: $recipient";
    }
    
    $utils->save_result('security_tips', {
        action => 'schedule',
        frequency => $frequency,
        delivery_method => $delivery_method,
        next_delivery => $schedule->{next_delivery}
    });
    
    return $schedule;
}

# =============================================================================
# تصدير النصائح
# =============================================================================
sub tips_export {
    my ($output_file, $format, $category) = @_;
    
    my $color = Colors->new();
    my $utils = Utils->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    📤 تصدير النصائح 📤                               ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    $output_file //= "$ENV{HOME}/.robinhood/reports/security_tips_" . time() . ".txt";
    $format //= "text";
    $category //= "all";
    
    say "${\($color->info())}[*] تصدير النصائح بصيغة $format${\($color->reset())}";
    
    # الحصول على النصائح
    my $tips = tips_generate($category, 100, "all");
    
    # إنشاء محتوى التصدير
    my $export_content = "";
    
    if ($format eq "text") {
        $export_content = _export_as_text($tips);
    } elsif ($format eq "html") {
        $output_file =~ s/\.txt$/.html/;
        $export_content = _export_as_html($tips);
    } elsif ($format eq "pdf") {
        $output_file =~ s/\.txt$/.pdf/;
        $export_content = _export_as_pdf($tips);
    } else {
        $export_content = _export_as_json($tips);
        $output_file =~ s/\.txt$/.json/;
    }
    
    write_file($output_file, $export_content);
    
    my $size = -s $output_file;
    
    say "\n${\($color->success())}[✓] تم تصدير النصائح:${\($color->reset())}";
    say "   → الملف: $output_file";
    say "   → الحجم: " . $utils->format_size($size);
    say "   → عدد النصائح: " . scalar(@$tips);
    
    $utils->save_result('security_tips', {
        action => 'export',
        format => $format,
        output => $output_file,
        tips_count => scalar(@$tips)
    });
    
    return $output_file;
}

# =============================================================================
# دوال مساعدة داخلية
# =============================================================================

sub _calculate_next_delivery {
    my ($frequency) = @_;
    
    my $now = time();
    
    if ($frequency eq "daily") {
        return $now + 86400;
    } elsif ($frequency eq "weekly") {
        return $now + 604800;
    } elsif ($frequency eq "monthly") {
        return $now + 2592000;
    } else {
        return $now + 86400;
    }
}

sub _export_as_text {
    my ($tips) = @_;
    
    my $content = "=" x 60 . "\n";
    $content .= "نصائح أمنية - RobinHood Wibey\n";
    $content .= "=" x 60 . "\n\n";
    $content .= "التاريخ: " . localtime() . "\n\n";
    
    for my $i (0..$#$tips) {
        my $tip = $tips->[$i];
        $content .= ($i+1) . ". $tip->{title}\n";
        $content .= "   [$tip->{priority}] $tip->{content}\n\n";
    }
    
    $content .= "=" x 60 . "\n";
    
    return $content;
}

sub _export_as_html {
    my ($tips) = @_;
    
    my $html = '<!DOCTYPE html>';
    $html .= '<html><head><meta charset="UTF-8">';
    $html .= '<title>نصائح أمنية</title>';
    $html .= '<style>
        body { font-family: Arial, sans-serif; margin: 20px; direction: rtl; }
        h1 { color: #333; }
        .tip { border: 1px solid #ddd; margin: 10px 0; padding: 10px; border-radius: 5px; }
        .critical { border-right: 5px solid #f44336; }
        .high { border-right: 5px solid #ff9800; }
        .medium { border-right: 5px solid #4caf50; }
        .low { border-right: 5px solid #2196f3; }
        .title { font-size: 1.2em; font-weight: bold; }
    </style>';
    $html .= '</head><body>';
    
    $html .= "<h1>نصائح أمنية</h1>";
    $html .= "<p>التاريخ: " . localtime() . "</p>";
    
    for my $tip (@$tips) {
        $html .= "<div class='tip $tip->{priority}'>";
        $html .= "<div class='title'>$tip->{title}</div>";
        $html .= "<p>$tip->{content}</p>";
        $html .= "<small>الأولوية: $tip->{priority}</small>";
        $html .= "</div>";
    }
    
    $html .= '</body></html>';
    
    return $html;
}

sub _export_as_pdf {
    my ($tips) = @_;
    return _export_as_html($tips);
}

sub _export_as_json {
    my ($tips) = @_;
    return encode_json($tips);
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

1;  # نهاية الوحدة
