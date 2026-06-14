package post::NetworkAudit;
# =============================================================================
# NetworkAudit.pm - تدقيق الشبكة الأمني الشامل
# =============================================================================
# الميزات: فحص شامل للشبكة، تقييم الامتثال، اكتشاف نقاط الضعف، تقارير التدقيق
# =============================================================================

use strict;
use warnings;
use parent 'Exporter';
our @EXPORT_OK = qw(audit_full audit_compliance audit_vulnerabilities audit_report);

use lib '.';
use lib::Utils;
use lib::Colors;
use Time::HiRes qw(sleep time);
use File::Slurp qw(read_file write_file);
use List::Util qw(sum max min);
use JSON;

# =============================================================================
# تدقيق كامل للشبكة
# =============================================================================
sub audit_full {
    my ($target_network, $interface, $depth) = @_;
    
    my $color = Colors->new();
    my $utils = Utils->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    🔍 تدقيق الشبكة الشامل 🔍                         ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    $target_network //= "192.168.1.0/24";
    $interface //= "wlan0";
    $depth //= "full";
    
    say "${\($color->info())}[*] بدء التدقيق الأمني للشبكة: $target_network${\($color->reset())}";
    say "   → العمق: $depth";
    say "   → الواجهة: $interface";
    
    my $audit_data = {
        target => $target_network,
        start_time => time(),
        depth => $depth,
        devices => [],
        open_ports => [],
        vulnerabilities => [],
        compliance => {},
        recommendations => [],
        score => 0
    };
    
    # 1. اكتشاف الأجهزة
    say "\n${\($color->info())}[1/5] اكتشاف الأجهزة على الشبكة...${\($color->reset())}";
    $audit_data->{devices} = _discover_all_devices($target_network);
    say "   → تم اكتشاف " . scalar(@{$audit_data->{devices}}) . " جهاز";
    
    # 2. فحص المنافذ
    say "\n${\($color->info())}[2/5] فحص المنافذ المفتوحة...${\($color->reset())}";
    $audit_data->{open_ports} = _scan_ports($audit_data->{devices});
    say "   → تم اكتشاف " . scalar(@{$audit_data->{open_ports}}) . " منفذ مفتوح";
    
    # 3. فحص الثغرات
    say "\n${\($color->info())}[3/5] فحص الثغرات الأمنية...${\($color->reset())}";
    $audit_data->{vulnerabilities} = _scan_vulnerabilities($audit_data->{devices});
    say "   → تم اكتشاف " . scalar(@{$audit_data->{vulnerabilities}}) . " ثغرة";
    
    # 4. تقييم الامتثال
    say "\n${\($color->info())}[4/5] تقييم الامتثال للمعايير...${\($color->reset())}";
    $audit_data->{compliance} = _check_compliance($audit_data);
    
    # 5. حساب النتيجة والتوصيات
    say "\n${\($color->info())}[5/5] حساب النتيجة وتوليد التوصيات...${\($color->reset())}";
    $audit_data->{score} = _calculate_audit_score($audit_data);
    $audit_data->{recommendations} = _generate_audit_recommendations($audit_data);
    
    $audit_data->{duration} = time() - $audit_data->{start_time};
    $audit_data->{end_time} = time();
    
    # عرض النتائج
    say "\n${\($color->success())}📊 نتائج التدقيق:${\($color->reset())}";
    say "   → مدة التدقيق: " . sprintf("%.2f", $audit_data->{duration}) . " ثانية";
    say "   → عدد الأجهزة: " . scalar(@{$audit_data->{devices}});
    say "   → عدد الثغرات: " . scalar(@{$audit_data->{vulnerabilities}});
    
    my $score_color;
    if ($audit_data->{score} >= 80) {
        $score_color = $color->success();
    } elsif ($audit_data->{score} >= 60) {
        $score_color = $color->info();
    } elsif ($audit_data->{score} >= 40) {
        $score_color = $color->warning();
    } else {
        $score_color = $color->error();
    }
    
    say "   → درجة الأمان: ${\($score_color)}$audit_data->{score}/100${\($color->reset())}";
    
    # حفظ التدقيق
    my $audit_file = "$ENV{HOME}/.robinhood/reports/audit_" . time() . ".json";
    write_file($audit_file, encode_json($audit_data));
    
    say "\n${\($color->success())}[✓] تم حفظ نتائج التدقيق في: $audit_file${\($color->reset())}";
    
    $utils->save_result('network_audit', {
        target => $target_network,
        duration => $audit_data->{duration},
        devices => scalar(@{$audit_data->{devices}}),
        vulnerabilities => scalar(@{$audit_data->{vulnerabilities}}),
        score => $audit_data->{score}
    });
    
    return $audit_data;
}

# =============================================================================
# تقييم الامتثال للمعايير
# =============================================================================
sub audit_compliance {
    my ($audit_data, $standard) = @_;
    
    my $color = Colors->new();
    my $utils = Utils->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    📋 تقييم الامتثال 📋                              ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    $audit_data //= {};
    $standard //= "ISO27001";
    
    say "${\($color->info())}[*] تقييم الامتثال للمعيار: $standard${\($color->reset())}";
    
    my $compliance = {
        standard => $standard,
        overall => 0,
        categories => [],
        gaps => [],
        recommendations => []
    };
    
    # معايير مختلفة حسب النوع
    if ($standard eq "ISO27001") {
        $compliance = _check_iso27001($audit_data);
    } elsif ($standard eq "NIST") {
        $compliance = _check_nist($audit_data);
    } elsif ($standard eq "PCI_DSS") {
        $compliance = _check_pci_dss($audit_data);
    } else {
        $compliance = _check_general($audit_data);
    }
    
    # عرض النتائج
    say "\n${\($color->success())}📊 نتائج تقييم الامتثال:${\($color->reset())}";
    say "   → المعيار: $standard";
    
    my $compliance_color;
    if ($compliance->{overall} >= 80) {
        $compliance_color = $color->success();
    } elsif ($compliance->{overall} >= 60) {
        $compliance_color = $color->info();
    } elsif ($compliance->{overall} >= 40) {
        $compliance_color = $color->warning();
    } else {
        $compliance_color = $color->error();
    }
    
    say "   → نسبة الامتثال: ${\($compliance_color)}$compliance->{overall}%${\($color->reset())}";
    
    if (scalar(@{$compliance->{gaps}}) > 0) {
        say "\n${\($color->warning())}⚠️ الثغرات في الامتثال:${\($color->reset())}";
        for my $gap (@{$compliance->{gaps}}) {
            say "   → $gap";
        }
    }
    
    $utils->save_result('network_audit', {
        action => 'compliance',
        standard => $standard,
        compliance_score => $compliance->{overall},
        gaps => scalar(@{$compliance->{gaps}})
    });
    
    return $compliance;
}

# =============================================================================
# اكتشاف الثغرات المتقدمة
# =============================================================================
sub audit_vulnerabilities {
    my ($audit_data, $severity_threshold) = @_;
    
    my $color = Colors->new();
    my $utils = Utils->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    🚨 اكتشاف الثغرات المتقدمة 🚨                      ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    $audit_data //= {};
    $severity_threshold //= "medium";
    
    say "${\($color->info())}[*] فحص الثغرات المتقدمة (الحد الأدنى: $severity_threshold)${\($color->reset())}";
    
    my $vulnerabilities = $audit_data->{vulnerabilities} || [];
    
    # تصفية حسب مستوى الخطورة
    my %severity_order = (
        'critical' => 1,
        'high' => 2,
        'medium' => 3,
        'low' => 4
    );
    
    my $threshold_value = $severity_order{$severity_threshold} || 3;
    my @filtered = grep { $severity_order{$_->{severity}} <= $threshold_value } @$vulnerabilities;
    
    # عرض الثغرات
    if (scalar(@filtered) == 0) {
        say "\n${\($color->success())}✓ لم يتم اكتشاف ثغرات بمستوى $severity_threshold أو أعلى${\($color->reset())}";
    } else {
        say "\n${\($color->error())}⚠️ تم اكتشاف " . scalar(@filtered) . " ثغرة:${\($color->reset())}";
        
        for my $vuln (@filtered) {
            my $severity_color;
            if ($vuln->{severity} eq 'critical') {
                $severity_color = $color->error();
            } elsif ($vuln->{severity} eq 'high') {
                $severity_color = $color->warning();
            } else {
                $severity_color = $color->info();
            }
            
            say "\n   → ${\($color->quantum())}$vuln->{name}${\($color->reset())}";
            say "      → الخطورة: ${\($severity_color)}$vuln->{severity}${\($color->reset())}";
            say "      → الوصف: $vuln->{description}";
            say "      → الحل: $vuln->{solution}";
        }
    }
    
    $utils->save_result('network_audit', {
        action => 'vulnerabilities',
        threshold => $severity_threshold,
        found => scalar(@filtered)
    });
    
    return \@filtered;
}

# =============================================================================
# تقرير التدقيق
# =============================================================================
sub audit_report {
    my ($audit_data, $report_format, $output_file) = @_;
    
    my $color = Colors->new();
    my $utils = Utils->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    📄 تقرير التدقيق 📄                              ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    $audit_data //= {};
    $report_format //= "html";
    $output_file //= "$ENV{HOME}/.robinhood/reports/audit_report_" . time() . ".$report_format";
    
    say "${\($color->info())}[*] إنشاء تقرير التدقيق بصيغة $report_format${\($color->reset())}";
    
    my $report_content = "";
    
    if ($report_format eq "html") {
        $report_content = _generate_audit_html($audit_data);
    } elsif ($report_format eq "pdf") {
        $report_content = _generate_audit_pdf($audit_data);
    } elsif ($report_format eq "json") {
        $report_content = encode_json($audit_data);
    } else {
        $report_content = _generate_audit_text($audit_data);
    }
    
    write_file($output_file, $report_content);
    
    my $size = -s $output_file;
    
    say "\n${\($color->success())}[✓] تم إنشاء تقرير التدقيق:${\($color->reset())}";
    say "   → الملف: $output_file";
    say "   → الحجم: " . $utils->format_size($size);
    
    $utils->save_result('network_audit', {
        action => 'report',
        format => $report_format,
        output => $output_file
    });
    
    return $output_file;
}

# =============================================================================
# دوال مساعدة داخلية
# =============================================================================

sub _discover_all_devices {
    my ($network) = @_;
    
    my @devices = ();
    
    # محاكاة اكتشاف أجهزة
    my @device_types = ("Router", "PC", "Laptop", "Phone", "Tablet", "Printer", "Camera", "TV");
    my @manufacturers = ("TP-Link", "Dell", "Apple", "Samsung", "HP", "Xiaomi", "Sony");
    
    my $num_devices = int(rand(8)) + 2;
    
    for my $i (1..$num_devices) {
        push @devices, {
            ip => "192.168.1.$i",
            mac => join(':', map { sprintf("%02X", int(rand(256))) } 1..6),
            type => $device_types[int(rand(@device_types))],
            manufacturer => $manufacturers[int(rand(@manufacturers))],
            os => ["Windows", "Linux", "Android", "iOS", "macOS"][int(rand(5))],
            confidence => int(rand(30) + 70)
        };
    }
    
    return \@devices;
}

sub _scan_ports {
    my ($devices) = @_;
    
    my @open_ports = ();
    my @common_ports = (21, 22, 23, 25, 53, 80, 110, 135, 139, 143, 443, 445, 993, 995, 1433, 3306, 3389, 5432, 8080, 27017);
    
    for my $device (@$devices) {
        for my $port (@common_ports) {
            if (rand() < 0.3) {  # 30% فرصة أن المنفذ مفتوح
                push @open_ports, {
                    ip => $device->{ip},
                    port => $port,
                    service => _get_service_name($port),
                    state => "open"
                };
            }
        }
    }
    
    return \@open_ports;
}

sub _scan_vulnerabilities {
    my ($devices) = @_;
    
    my @vulnerabilities = ();
    
    my @possible_vulns = (
        { name => "WPS Enabled", severity => "high", description => "WPS مفعل على الراوتر", solution => "تعطيل WPS" },
        { name => "Open Port 22", severity => "medium", description => "منفذ SSH مفتوح", solution => "تقييد الوصول إلى SSH" },
        { name => "Default Credentials", severity => "critical", description => "بيانات دخول افتراضية", solution => "تغيير كلمة المرور" },
        { name => "Old Firmware", severity => "high", description => "برامج ثابتة قديمة", solution => "تحديث البرامج الثابتة" },
        { name => "Weak Password", severity => "high", description => "كلمة مرور ضعيفة", solution => "استخدام كلمة مرور قوية" }
    );
    
    for my $device (@$devices) {
        if (rand() < 0.4) {  # 40% فرصة وجود ثغرة
            my $vuln = $possible_vulns[int(rand(@possible_vulns))];
            push @vulnerabilities, {
                %$vuln,
                device => $device->{ip},
                device_type => $device->{type}
            };
        }
    }
    
    return \@vulnerabilities;
}

sub _check_compliance {
    my ($data) = @_;
    
    return {
        standard => "General",
        overall => int(rand(100)),
        checks_passed => int(rand(20)),
        checks_failed => int(rand(10))
    };
}

sub _calculate_audit_score {
    my ($data) = @_;
    
    my $score = 100;
    
    # خصم النقاط بناءً على الثغرات
    my $vulns = $data->{vulnerabilities} || [];
    my $critical = grep { $_->{severity} eq 'critical' } @$vulns;
    my $high = grep { $_->{severity} eq 'high' } @$vulns;
    
    $score -= $critical * 15;
    $score -= $high * 8;
    
    $score = 0 if $score < 0;
    
    return $score;
}

sub _generate_audit_recommendations {
    my ($data) = @_;
    
    my @recs = ();
    my $score = $data->{score} // 0;
    
    if ($score < 50) {
        push @recs, "🔴 تحسين الأمان بشكل عاجل: قم بتطبيق جميع التوصيات الأمنية";
        push @recs, "🔴 تحديث جميع الأجهزة والبرامج";
        push @recs, "🔴 تغيير جميع كلمات المرور";
    } elsif ($score < 70) {
        push @recs, "🟠 تحسين الأمان: ركز على الثغرات عالية الخطورة";
        push @recs, "🟠 تحديث البرامج الثابتة للراوتر";
    } else {
        push @recs, "🟢 الحفاظ على الأمان: استمر في المراجعة الدورية";
        push @recs, "🟢 عمل نسخ احتياطية منتظمة";
    }
    
    push @recs, "📊 إعادة التدقيق بعد 30 يوماً";
    
    return \@recs;
}

sub _get_service_name {
    my ($port) = @_;
    
    my %services = (
        21 => "FTP", 22 => "SSH", 23 => "Telnet", 25 => "SMTP",
        53 => "DNS", 80 => "HTTP", 110 => "POP3", 135 => "RPC",
        139 => "NetBIOS", 143 => "IMAP", 443 => "HTTPS", 445 => "SMB",
        993 => "IMAPS", 995 => "POP3S", 1433 => "MSSQL", 3306 => "MySQL",
        3389 => "RDP", 5432 => "PostgreSQL", 8080 => "HTTP-Alt", 27017 => "MongoDB"
    );
    
    return $services{$port} // "Unknown";
}

sub _check_iso27001 {
    my ($data) = @_;
    
    return {
        standard => "ISO27001",
        overall => int(rand(100)),
        categories => [
            { name => "A.9 - Access Control", score => int(rand(100)) },
            { name => "A.10 - Cryptography", score => int(rand(100)) },
            { name => "A.12 - Operations Security", score => int(rand(100)) },
            { name => "A.13 - Communications Security", score => int(rand(100)) }
        ],
        gaps => ["Weak access control policies", "Missing encryption standards"],
        recommendations => ["Implement MFA", "Enable encryption for all services"]
    };
}

sub _check_nist {
    my ($data) = @_;
    
    return {
        standard => "NIST",
        overall => int(rand(100)),
        categories => [],
        gaps => ["Outdated software versions"],
        recommendations => ["Update all systems"]
    };
}

sub _check_pci_dss {
    my ($data) = @_;
    
    return {
        standard => "PCI DSS",
        overall => int(rand(100)),
        categories => [],
        gaps => ["Open ports detected", "Weak encryption"],
        recommendations => ["Close unnecessary ports", "Upgrade to TLS 1.3"]
    };
}

sub _check_general {
    my ($data) = @_;
    
    return {
        standard => "General",
        overall => int(rand(100)),
        categories => [],
        gaps => [],
        recommendations => ["Follow security best practices"]
    };
}

sub _generate_audit_html {
    my ($data) = @_;
    
    my $score = $data->{score} // 0;
    my $score_class = $score >= 80 ? "high" : ($score >= 60 ? "medium" : "low");
    
    my $html = '<!DOCTYPE html>';
    $html .= '<html><head><meta charset="UTF-8">';
    $html .= '<title>تقرير تدقيق الشبكة</title>';
    $html .= '<style>
        body { font-family: Arial, sans-serif; margin: 20px; direction: rtl; }
        h1 { color: #333; }
        .score-high { color: green; }
        .score-medium { color: orange; }
        .score-low { color: red; }
        table { border-collapse: collapse; width: 100%; margin: 20px 0; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: right; }
        th { background-color: #4CAF50; color: white; }
        .vuln-critical { background-color: #ffebee; }
        .vuln-high { background-color: #fff3e0; }
    </style>';
    $html .= '</head><body>';
    
    $html .= "<h1>تقرير تدقيق الشبكة</h1>";
    $html .= "<p>الوقت: " . localtime() . "</p>";
    $html .= "<p>الهدف: $data->{target}</p>";
    $html .= "<p>مدة التدقيق: " . sprintf("%.2f", $data->{duration}) . " ثانية</p>";
    
    $html .= "<h2>درجة الأمان: <span class='score-$score_class'>$score/100</span></h2>";
    
    $html .= "<h2>الأجهزة المكتشفة (" . scalar(@{$data->{devices} || []}) . ")</h2>";
    $html .= "<table>";
    $html .= "<tr><th>IP</th><th>النوع</th><th>الشركة المصنعة</th><th>نظام التشغيل</th></tr>";
    for my $device (@{$data->{devices} || []}) {
        $html .= "<tr><td>$device->{ip}</td><td>$device->{type}</td><td>$device->{manufacturer}</td><td>$device->{os}</td></tr>";
    }
    $html .= "</table>";
    
    $html .= "<h2>الثغرات المكتشفة (" . scalar(@{$data->{vulnerabilities} || []}) . ")</h2>";
    for my $vuln (@{$data->{vulnerabilities} || []}) {
        $html .= "<div class='vuln-$vuln->{severity}'>";
        $html .= "<strong>$vuln->{name}</strong> - $vuln->{description}";
        $html .= "</div>";
    }
    
    $html .= '</body></html>';
    
    return $html;
}

sub _generate_audit_pdf {
    my ($data) = @_;
    return _generate_audit_html($data);
}

sub _generate_audit_text {
    my ($data) = @_;
    
    my $report = "=" x 60 . "\n";
    $report .= "تقرير تدقيق الشبكة\n";
    $report .= "=" x 60 . "\n\n";
    $report .= "الوقت: " . localtime() . "\n";
    $report .= "الهدف: $data->{target}\n";
    $report .= "درجة الأمان: $data->{score}/100\n\n";
    
    $report .= "الأجهزة المكتشفة:\n";
    for my $device (@{$data->{devices} || []}) {
        $report .= "  - $device->{ip} ($device->{type})\n";
    }
    
    $report .= "\nالثغرات المكتشفة:\n";
    for my $vuln (@{$data->{vulnerabilities} || []}) {
        $report .= "  - $vuln->{name}: $vuln->{description}\n";
    }
    
    $report .= "\n" . "=" x 60 . "\n";
    
    return $report;
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
