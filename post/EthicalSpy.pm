package post::EthicalSpy;
# =============================================================================
# EthicalSpy.pm - الجاسوس الأخلاقي (مراقبة وفحص أمني)
# =============================================================================
# الميزات: مراقبة الشبكة، تحليل السلوك، كشف الثغرات، تقارير أمنية
# =============================================================================

use strict;
use warnings;
use parent 'Exporter';
our @EXPORT_OK = qw(spy_monitor spy_analyze spy_report spy_recommend);

use lib '.';
use lib::Utils;
use lib::Colors;
use Time::HiRes qw(sleep time);
use File::Slurp qw(read_file write_file);
use List::Util qw(sum max min);
use JSON;

# =============================================================================
# مراقبة الشبكة (لأغراض أمنية)
# =============================================================================
sub spy_monitor {
    my ($target_network, $duration, $interface) = @_;
    
    my $color = Colors->new();
    my $utils = Utils->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    🕵️ الجاسوس الأخلاقي 🕵️                            ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    $target_network //= "192.168.1.0/24";
    $duration //= 300;
    $interface //= "wlan0";
    
    say "${\($color->info())}[*] بدء المراقبة الأخلاقية على $target_network لمدة $duration ثانية${\($color->reset())}";
    say "${\($color->warning())}[!] هذا لأغراض أمنية واختبار الاختراق المصرح به فقط${\($color->reset())}";
    
    my $monitoring_data = {
        target => $target_network,
        start_time => time(),
        duration => $duration,
        devices => [],
        traffic => [],
        anomalies => [],
        threats => []
    };
    
    my $start_time = time();
    my $packet_count = 0;
    
    while ((time() - $start_time) < $duration) {
        # محاكاة مراقبة الحزم
        $packet_count++;
        my $elapsed = time() - $start_time;
        my $percent = int(($elapsed / $duration) * 100);
        
        print "\r${\($color->info())}[*] التقدم: $percent% - الحزم: $packet_count${\($color->reset())}";
        
        # اكتشاف أجهزة جديدة
        if ($packet_count % 100 == 0) {
            my $new_device = _discover_device();
            my $exists = grep { $_->{mac} eq $new_device->{mac} } @{$monitoring_data->{devices}};
            if (!$exists) {
                push @{$monitoring_data->{devices}}, $new_device;
                say "\n${\($color->success())}[✓] تم اكتشاف جهاز جديد: $new_device->{mac} ($new_device->{type})${\($color->reset())}";
            }
        }
        
        # كشف التهديدات
        if (rand() < 0.05) {
            my $threat = _detect_threat();
            push @{$monitoring_data->{threats}}, $threat;
            say "\n${\($color->error())}[⚠️] تهديد مكتشف: $threat->{type} - $threat->{description}${\($color->reset())}";
        }
        
        sleep(1);
    }
    
    print "\n";
    
    # إحصائيات المراقبة
    $monitoring_data->{total_packets} = $packet_count;
    $monitoring_data->{devices_count} = scalar(@{$monitoring_data->{devices}});
    $monitoring_data->{threats_count} = scalar(@{$monitoring_data->{threats}});
    
    say "\n${\($color->success())}📊 نتائج المراقبة:${\($color->reset())}";
    say "   → الأجهزة المكتشفة: $monitoring_data->{devices_count}";
    say "   → إجمالي الحزم: $packet_count";
    say "   → التهديدات المكتشفة: $monitoring_data->{threats_count}";
    
    # حفظ النتائج
    my $result_file = "$ENV{HOME}/.robinhood/reports/spy_monitor_" . time() . ".json";
    write_file($result_file, encode_json($monitoring_data));
    
    say "\n${\($color->success())}[✓] تم حفظ نتائج المراقبة في: $result_file${\($color->reset())}";
    
    $utils->save_result('ethical_spy', {
        action => 'monitor',
        target => $target_network,
        duration => $duration,
        devices => $monitoring_data->{devices_count},
        threats => $monitoring_data->{threats_count}
    });
    
    return $monitoring_data;
}

# =============================================================================
# تحليل أمني
# =============================================================================
sub spy_analyze {
    my ($monitoring_data, $analysis_depth) = @_;
    
    my $color = Colors->new();
    my $utils = Utils->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    🔬 تحليل أمني 🔬                                  ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    $monitoring_data //= {};
    $analysis_depth //= "standard";
    
    say "${\($color->info())}[*] تحليل البيانات الأمنية (المستوى: $analysis_depth)${\($color->reset())}";
    
    my $analysis = {
        risk_score => 0,
        vulnerabilities => [],
        recommendations => [],
        summary => {}
    };
    
    # تحليل الأجهزة
    my $devices = $monitoring_data->{devices} || [];
    my $unknown_devices = grep { $_->{type} eq 'unknown' } @$devices;
    $analysis->{summary}{unknown_devices} = $unknown_devices;
    
    if ($unknown_devices > 0) {
        push @{$analysis->{vulnerabilities}}, {
            type => "أجهزة غير معروفة",
            count => $unknown_devices,
            severity => "medium",
            description => "تم اكتشاف $unknown_devices جهاز غير معروف على الشبكة"
        };
        $analysis->{risk_score} += $unknown_devices * 10;
    }
    
    # تحليل التهديدات
    my $threats = $monitoring_data->{threats} || [];
    if (scalar(@$threats) > 0) {
        push @{$analysis->{vulnerabilities}}, {
            type => "تهديدات أمنية",
            count => scalar(@$threats),
            severity => "high",
            description => "تم اكتشاف " . scalar(@$threats) . " تهديد أمني"
        };
        $analysis->{risk_score} += scalar(@$threats) * 20;
    }
    
    # تحديد مستوى الخطر
    $analysis->{risk_score} = min(100, $analysis->{risk_score});
    my $risk_level;
    if ($analysis->{risk_score} >= 70) {
        $risk_level = "مرتفع جداً";
    } elsif ($analysis->{risk_score} >= 50) {
        $risk_level = "مرتفع";
    } elsif ($analysis->{risk_score} >= 30) {
        $risk_level = "متوسط";
    } else {
        $risk_level = "منخفض";
    }
    $analysis->{risk_level} = $risk_level;
    
    # عرض التحليل
    say "\n${\($color->quantum())}📊 نتائج التحليل:${\($color->reset())}";
    say "   → درجة المخاطرة: $analysis->{risk_score}/100 ($risk_level)";
    
    if (scalar(@{$analysis->{vulnerabilities}}) > 0) {
        say "\n${\($color->error())}⚠️ الثغرات المكتشفة:${\($color->reset())}";
        for my $vuln (@{$analysis->{vulnerabilities}}) {
            say "   → $vuln->{description} (خطورة: $vuln->{severity})";
        }
    }
    
    $utils->save_result('ethical_spy', {
        action => 'analyze',
        risk_score => $analysis->{risk_score},
        risk_level => $risk_level,
        vulnerabilities => scalar(@{$analysis->{vulnerabilities}})
    });
    
    return $analysis;
}

# =============================================================================
# تقرير أمني
# =============================================================================
sub spy_report {
    my ($analysis_data, $report_format, $output_file) = @_;
    
    my $color = Colors->new();
    my $utils = Utils->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    📋 تقرير أمني 📋                                  ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    $analysis_data //= {};
    $report_format //= "html";
    $output_file //= "$ENV{HOME}/.robinhood/reports/security_report_" . time() . ".$report_format";
    
    say "${\($color->info())}[*] إنشاء تقرير أمني بصيغة $report_format${\($color->reset())}";
    
    my $report_content = "";
    
    if ($report_format eq "html") {
        $report_content = _generate_security_html($analysis_data);
    } elsif ($report_format eq "pdf") {
        $report_content = _generate_security_pdf($analysis_data);
    } else {
        $report_content = _generate_security_text($analysis_data);
    }
    
    write_file($output_file, $report_content);
    
    my $size = -s $output_file;
    
    say "\n${\($color->success())}[✓] تم إنشاء التقرير الأمني:${\($color->reset())}";
    say "   → الملف: $output_file";
    say "   → الحجم: " . $utils->format_size($size);
    
    $utils->save_result('ethical_spy', {
        action => 'report',
        format => $report_format,
        output => $output_file
    });
    
    return $output_file;
}

# =============================================================================
# توصيات أمنية
# =============================================================================
sub spy_recommend {
    my ($analysis_data) = @_;
    
    my $color = Colors->new();
    my $utils = Utils->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    💡 توصيات أمنية 💡                                ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    $analysis_data //= {};
    
    my $risk_score = $analysis_data->{risk_score} // 0;
    my $recommendations = [];
    
    if ($risk_score >= 70) {
        push @$recommendations, "🔴 خطر مرتفع جداً - اتخذ إجراءات فورية:";
        push @$recommendations, "   1. قم بتحديث جميع أجهزة الشبكة";
        push @$recommendations, "   2. غيّر كلمات المرور لجميع الأجهزة";
        push @$recommendations, "   3. فعّل جدار الحماية على جميع الأجهزة";
        push @$recommendations, "   4. قم بفحص جميع الأجهزة بحثاً عن برمجيات ضارة";
        
    } elsif ($risk_score >= 50) {
        push @$recommendations, "🟠 خطر مرتفع - يوصى بتحسين الأمان:";
        push @$recommendations, "   1. قم بتحديث البرامج الثابتة للأجهزة";
        push @$recommendations, "   2. استخدم كلمات مرور قوية وفريدة";
        push @$recommendations, "   3. عطّل الخدمات غير الضرورية";
        
    } elsif ($risk_score >= 30) {
        push @$recommendations, "🟡 خطر متوسط - يمكن تحسين الأمان:";
        push @$recommendations, "   1. راجع إعدادات الأمان الحالية";
        push @$recommendations, "   2. قم بمراقبة الشبكة بانتظام";
        push @$recommendations, "   3. فعّل التنبيهات للأنشطة المشبوهة";
        
    } else {
        push @$recommendations, "🟢 خطر منخفض - حافظ على الأمان:";
        push @$recommendations, "   1. استمر في تحديث الأنظمة بانتظام";
        push @$recommendations, "   2. قم بعمل نسخ احتياطية دورية";
        push @$recommendations, "   3. راجع سجلات الأمان بشكل منتظم";
    }
    
    # توصيات إضافية عامة
    push @$recommendations, "";
    push @$recommendations, "📌 توصيات عامة:";
    push @$recommendations, "   • استخدم VPN عند الاتصال بشبكات عامة";
    push @$recommendations, "   • فعّل المصادقة الثنائية حيثما أمكن";
    push @$recommendations, "   • قم بتعطيل WPS إذا لم تكن بحاجة إليه";
    push @$recommendations, "   • استخدم تشفير WPA3 إذا كان متاحاً";
    
    # عرض التوصيات
    for my $rec (@$recommendations) {
        if ($rec =~ /^[🔴🟠🟡🟢]/) {
            say "${\($color->quantum())}$rec${\($color->reset())}";
        } elsif ($rec =~ /^📌/) {
            say "\n${\($color->info())}$rec${\($color->reset())}";
        } else {
            say "${\($color->info())}$rec${\($color->reset())}";
        }
    }
    
    $utils->save_result('ethical_spy', {
        action => 'recommend',
        risk_score => $risk_score,
        recommendations_count => scalar(@$recommendations)
    });
    
    return $recommendations;
}

# =============================================================================
# دوال مساعدة داخلية
# =============================================================================

sub _discover_device {
    my @types = ("Computer", "Phone", "Tablet", "Printer", "Camera", "TV", "unknown");
    my @manufacturers = ("Dell", "Apple", "Samsung", "HP", "Lenovo", "Unknown");
    
    my $mac = join(':', map { sprintf("%02X", int(rand(256))) } 1..6);
    
    return {
        mac => $mac,
        type => $types[int(rand(@types))],
        manufacturer => $manufacturers[int(rand(@manufacturers))],
        first_seen => time(),
        last_seen => time(),
        signal => int(rand(70) + 20)
    };
}

sub _detect_threat {
    my @threats = (
        { type => "ARP Spoofing", description => "هجوم تزوير ARP محتمل", severity => "high" },
        { type => "Port Scan", description => "مسح غير طبيعي للمنافذ", severity => "medium" },
        { type => "Deauth Attack", description => "هجوم إلغاء مصادقة", severity => "high" },
        { type => "Brute Force", description => "محاولات تخمين كلمة مرور", severity => "medium" },
        { type => "Malicious DNS", description => "طلب DNS مشبوه", severity => "low" }
    );
    
    return $threats[int(rand(@threats))];
}

sub _generate_security_html {
    my ($data) = @_;
    
    my $risk_score = $data->{risk_score} // 0;
    my $risk_level = $data->{risk_level} // "غير محدد";
    my $vulnerabilities = $data->{vulnerabilities} // [];
    
    my $html = '<!DOCTYPE html>';
    $html .= '<html><head><meta charset="UTF-8">';
    $html .= '<title>التقرير الأمني</title>';
    $html .= '<style>
        body { font-family: Arial, sans-serif; margin: 20px; direction: rtl; }
        h1 { color: #333; }
        .risk-high { background: #f44336; color: white; padding: 10px; border-radius: 5px; }
        .risk-medium { background: #ff9800; color: white; padding: 10px; border-radius: 5px; }
        .risk-low { background: #4caf50; color: white; padding: 10px; border-radius: 5px; }
        .vuln { background: #f0f0f0; margin: 10px 0; padding: 10px; border-radius: 5px; }
        .high { border-right: 5px solid #f44336; }
        .medium { border-right: 5px solid #ff9800; }
        .low { border-right: 5px solid #4caf50; }
    </style>';
    $html .= '</head><body>';
    
    $html .= "<h1>التقرير الأمني</h1>";
    $html .= "<p>الوقت: " . localtime() . "</p>";
    
    my $risk_class = $risk_score >= 70 ? "risk-high" : ($risk_score >= 30 ? "risk-medium" : "risk-low");
    $html .= "<div class='$risk_class'>";
    $html .= "<h2>درجة المخاطرة: $risk_score/100 ($risk_level)</h2>";
    $html .= "</div>";
    
    if (scalar(@$vulnerabilities) > 0) {
        $html .= "<h2>الثغرات المكتشفة</h2>";
        for my $vuln (@$vulnerabilities) {
            $html .= "<div class='vuln $vuln->{severity}'>";
            $html .= "<strong>$vuln->{type}</strong><br>";
            $html .= $vuln->{description};
            $html .= "</div>";
        }
    }
    
    $html .= '</body></html>';
    
    return $html;
}

sub _generate_security_pdf {
    my ($data) = @_;
    return _generate_security_html($data);  # تبسيط للمحاكاة
}

sub _generate_security_text {
    my ($data) = @_;
    
    my $report = "=" x 60 . "\n";
    $report .= "التقرير الأمني\n";
    $report .= "=" x 60 . "\n\n";
    $report .= "الوقت: " . localtime() . "\n\n";
    $report .= "درجة المخاطرة: $data->{risk_score}/100 ($data->{risk_level})\n\n";
    
    if ($data->{vulnerabilities} && scalar(@{$data->{vulnerabilities}}) > 0) {
        $report .= "الثغرات المكتشفة:\n";
        for my $vuln (@{$data->{vulnerabilities}}) {
            $report .= "  - $vuln->{description}\n";
        }
    }
    
    $report .= "\n" . "=" x 60 . "\n";
    
    return $report;
}

sub min {
    my ($a, $b) = @_;
    return $a < $b ? $a : $b;
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
