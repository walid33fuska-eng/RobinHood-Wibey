package basic::TrafficAnalyzer;
# =============================================================================
# TrafficAnalyzer.pm - تحليل حركة المرور على الشبكة
# =============================================================================
# الميزات: تحليل الحزم، إحصائيات البروتوكولات، كشف الأنماط المشبوهة
# =============================================================================

use strict;
use warnings;
use parent 'Exporter';
our @EXPORT_OK = qw(traffic_analyze traffic_stats traffic_protocols traffic_anomalies);

use lib '.';
use lib::Utils;
use lib::Colors;
use Time::HiRes qw(sleep time);
use File::Slurp qw(write_file);
use List::Util qw(sum max min);

# =============================================================================
# تحليل حركة المرور
# =============================================================================
sub traffic_analyze {
    my ($interface, $duration, $filter) = @_;
    
    my $color = Colors->new();
    my $utils = Utils->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    📊 تحليل حركة المرور 📊                            ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    $interface //= "wlan0";
    $duration //= 60;
    $filter //= "all";
    
    say "${\($color->info())}[*] الواجهة: $interface${\($color->reset())}";
    say "${\($color->info())}[*] مدة التحليل: $duration ثانية${\($color->reset())}";
    say "${\($color->info())}[*] الفلتر: $filter${\($color->reset())}";
    
    # تهيئة إحصائيات التحليل
    my $analysis = {
        start_time => time(),
        packets => 0,
        bytes => 0,
        protocols => {},
        src_ips => {},
        dst_ips => {},
        traffic_by_second => [],
        anomalies => []
    };
    
    say "\n${\($color->info())}[*] بدء تحليل حركة المرور...${\($color->reset())}";
    
    my $start_time = time();
    my $last_second = 0;
    my $current_second_traffic = 0;
    
    while ((time() - $start_time) < $duration) {
        # محاكاة التقاط حزمة
        my $packet = _capture_packet($interface);
        
        if (_matches_filter($packet, $filter)) {
            $analysis->{packets}++;
            $analysis->{bytes} += $packet->{size};
            
            # تحديث إحصائيات البروتوكولات
            $analysis->{protocols}{$packet->{protocol}}++;
            
            # تحديث عناوين IP
            if ($packet->{src_ip}) {
                $analysis->{src_ips}{$packet->{src_ip}}++;
            }
            if ($packet->{dst_ip}) {
                $analysis->{dst_ips}{$packet->{dst_ip}}++;
            }
            
            # حركة المرور في الثانية
            my $current_second = int(time() - $start_time);
            if ($current_second != $last_second) {
                if ($last_second > 0) {
                    push @{$analysis->{traffic_by_second}}, $current_second_traffic;
                }
                $last_second = $current_second;
                $current_second_traffic = 0;
            }
            $current_second_traffic += $packet->{size};
            
            # كشف الأنماط المشبوهة
            my $anomaly = _detect_anomaly($packet, $analysis);
            if ($anomaly) {
                push @{$analysis->{anomalies}}, $anomaly;
            }
        }
        
        # عرض التقدم
        my $elapsed = time() - $start_time;
        my $percent = int(($elapsed / $duration) * 100);
        my $speed = $analysis->{bytes} / $elapsed;
        
        print "\r${\($color->info())}[*] التقدم: $percent% - الحزم: $analysis->{packets} - السرعة: " . 
              sprintf("%.1f", $speed/1024) . " KB/s${\($color->reset())}";
        
        # محاكاة سرعة الالتقاط
        sleep(0.01);
    }
    
    print "\n";
    
    # حساب الإحصائيات النهائية
    $analysis->{duration} = time() - $start_time;
    $analysis->{avg_packet_size} = $analysis->{packets} > 0 ? 
        $analysis->{bytes} / $analysis->{packets} : 0;
    $analysis->{avg_speed} = $analysis->{bytes} / $analysis->{duration};
    
    # عرض النتائج
    _display_analysis($analysis);
    
    # حفظ التحليل
    my $analysis_file = "$ENV{HOME}/.robinhood/logs/traffic_analysis_" . time() . ".json";
    write_file($analysis_file, encode_json($analysis));
    
    say "\n${\($color->success())}[✓] تم حفظ التحليل في: $analysis_file${\($color->reset())}";
    
    $utils->save_result('traffic_analyzer', {
        interface => $interface,
        duration => $duration,
        packets => $analysis->{packets},
        bytes => $analysis->{bytes},
        protocols => $analysis->{protocols}
    });
    
    return $analysis;
}

# =============================================================================
# إحصائيات حركة المرور
# =============================================================================
sub traffic_stats {
    my ($analysis_data) = @_;
    
    my $color = Colors->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    📈 إحصائيات حركة المرور 📈                        ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    $analysis_data //= {};
    
    my $packets = $analysis_data->{packets} || 0;
    my $bytes = $analysis_data->{bytes} || 0;
    my $duration = $analysis_data->{duration} || 1;
    
    # تحويل البايتات إلى وحدات مناسبة
    my $bytes_display = _format_bytes($bytes);
    my $avg_speed = $bytes / $duration;
    my $avg_speed_display = _format_bytes($avg_speed) . "/s";
    
    say "\n${\($color->info())}📊 الإحصائيات العامة:${\($color->reset())}";
    say "   → إجمالي الحزم: $packets";
    say "   → إجمالي البيانات: $bytes_display";
    say "   → متوسط حجم الحزمة: " . sprintf("%.1f", $analysis_data->{avg_packet_size}) . " بايت";
    say "   → متوسط السرعة: $avg_speed_display";
    say "   → مدة التحليل: " . sprintf("%.2f", $duration) . " ثانية";
    
    # إحصائيات البروتوكولات
    my $protocols = $analysis_data->{protocols} || {};
    if (keys %$protocols > 0) {
        say "\n${\($color->info())}📡 توزيع البروتوكولات:${\($color->reset())}";
        my $total = $packets;
        for my $proto (sort { $protocols->{$b} <=> $protocols->{$a} } keys %$protocols) {
            my $count = $protocols->{$proto};
            my $percent = ($count / $total) * 100;
            my $bar = _percent_bar($percent);
            say "   → $proto: $count حزمة ($percent%) $bar";
        }
    }
    
    # أعلى المصادر
    my $src_ips = $analysis_data->{src_ips} || {};
    if (keys %$src_ips > 0) {
        say "\n${\($color->info())}📤 أعلى المصادر إرسالاً:${\($color->reset())}";
        my @sorted = sort { $src_ips->{$b} <=> $src_ips->{$a} } keys %$src_ips;
        for my $i (0..2) {
            last unless $sorted[$i];
            say "   → $sorted[$i]: $src_ips->{$sorted[$i]} حزمة";
        }
    }
    
    # أعلى الوجهات
    my $dst_ips = $analysis_data->{dst_ips} || {};
    if (keys %$dst_ips > 0) {
        say "\n${\($color->info())}📥 أعلى الوجهات استقبالاً:${\($color->reset())}";
        my @sorted = sort { $dst_ips->{$b} <=> $dst_ips->{$a} } keys %$dst_ips;
        for my $i (0..2) {
            last unless $sorted[$i];
            say "   → $sorted[$i]: $dst_ips->{$sorted[$i]} حزمة";
        }
    }
    
    return $analysis_data;
}

# =============================================================================
# تحليل البروتوكولات
# =============================================================================
sub traffic_protocols {
    my ($analysis_data) = @_;
    
    my $color = Colors->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    🔌 تحليل البروتوكولات 🔌                           ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    $analysis_data //= {};
    
    my $protocols = $analysis_data->{protocols} || {};
    my $total = $analysis_data->{packets} || 1;
    
    say "\n${\($color->info())}📋 قائمة البروتوكولات المكتشفة:${\($color->reset())}";
    
    my $i = 1;
    for my $proto (sort { $protocols->{$b} <=> $protocols->{$a} } keys %$protocols) {
        my $count = $protocols->{$proto};
        my $percent = ($count / $total) * 100;
        
        # معلومات إضافية عن البروتوكول
        my $info = _protocol_info($proto);
        
        say "\n   $i. ${\($color->quantum())}$proto${\($color->reset())}";
        say "      → العدد: $count حزمة ($percent%)";
        say "      → المنفذ: $info->{port}";
        say "      → الوصف: $info->{description}";
        say "      → المخاطر: $info->{risk}";
        
        $i++;
    }
    
    return $protocols;
}

# =============================================================================
# كشف الشذوذ في حركة المرور
# =============================================================================
sub traffic_anomalies {
    my ($analysis_data) = @_;
    
    my $color = Colors->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    🚨 كشف الشذوذ 🚨                                  ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    $analysis_data //= {};
    
    my $anomalies = $analysis_data->{anomalies} || [];
    
    if (scalar(@$anomalies) == 0) {
        say "\n${\($color->success())}✓ لم يتم اكتشاف أي شذوذ في حركة المرور${\($color->reset())}";
        return [];
    }
    
    say "\n${\($color->error())}⚠️ تم اكتشاف " . scalar(@$anomalies) . " حالة شاذة:${\($color->reset())}";
    
    my $i = 1;
    for my $anomaly (@$anomalies) {
        say "\n   $i. ${\($color->warning())}$anomaly->{type}${\($color->reset())}";
        say "      → الوقت: $anomaly->{time}";
        say "      → التفاصيل: $anomaly->{details}";
        say "      → مستوى الخطورة: $anomaly->{severity}";
        $i++;
    }
    
    return $anomalies;
}

# =============================================================================
# دوال مساعدة داخلية
# =============================================================================

sub _capture_packet {
    my ($interface) = @_;
    
    # محاكاة التقاط حزمة عشوائية
    my @protocols = ('TCP', 'UDP', 'ICMP', 'ARP', 'DNS', 'HTTP', 'HTTPS', 'DHCP');
    my @src_ips = ('192.168.1.1', '192.168.1.10', '192.168.1.20', '192.168.1.100', '10.0.0.1', '8.8.8.8');
    my @dst_ips = ('192.168.1.1', '192.168.1.10', '192.168.1.20', '192.168.1.100', '1.1.1.1', '208.67.222.222');
    
    my $protocol = $protocols[int(rand(@protocols))];
    my $size = int(rand(1400)) + 64;  # 64-1500 بايت
    
    return {
        protocol => $protocol,
        size => $size,
        src_ip => $src_ips[int(rand(@src_ips))],
        dst_ip => $dst_ips[int(rand(@dst_ips))],
        timestamp => time()
    };
}

sub _matches_filter {
    my ($packet, $filter) = @_;
    
    return 1 if $filter eq 'all';
    return $packet->{protocol} eq $filter if $filter ne 'all';
    return 1;
}

sub _detect_anomaly {
    my ($packet, $analysis) = @_;
    
    # كشف حزم كبيرة بشكل غير طبيعي
    if ($packet->{size} > 1400 && $packet->{protocol} eq 'UDP') {
        return {
            type => 'حزمة UDP كبيرة',
            time => scalar(localtime()),
            details => "حجم الحزمة: $packet->{size} بايت",
            severity => 'متوسط'
        };
    }
    
    # كشف هجوم SYN flood (محاكاة)
    if ($packet->{protocol} eq 'TCP' && $analysis->{packets} > 100) {
        my $syn_count = 0;
        # محاكاة حساب SYN packets
        if (rand() < 0.1) {
            return {
                type => 'هجوم SYN محتمل',
                time => scalar(localtime()),
                details => 'عدد كبير من حزم SYN',
                severity => 'مرتفع'
            };
        }
    }
    
    return undef;
}

sub _protocol_info {
    my ($protocol) = @_;
    
    my %info = (
        'TCP' => { port => 'متعدد', description => 'بروتوكول التحكم في الإرسال', risk => 'متوسط' },
        'UDP' => { port => 'متعدد', description => 'بروتوكول حزم المستخدم', risk => 'منخفض' },
        'ICMP' => { port => 'N/A', description => 'بروتوكول رسائل التحكم', risk => 'منخفض' },
        'ARP' => { port => 'N/A', description => 'بروتوكول تحليل العناوين', risk => 'مرتفع (هجمات ARP spoofing)' },
        'DNS' => { port => '53', description => 'نظام أسماء النطاقات', risk => 'متوسط (هجمات DNS spoofing)' },
        'HTTP' => { port => '80', description => 'بروتوكول نقل النص الفائق', risk => 'مرتفع (غير مشفر)' },
        'HTTPS' => { port => '443', description => 'HTTP مشفر', risk => 'منخفض' },
        'DHCP' => { port => '67/68', description => 'بروتوكول تهيئة المضيف', risk => 'متوسط (هجمات DHCP spoofing)' }
    );
    
    return $info{$protocol} || { port => 'غير معروف', description => 'بروتوكول غير معروف', risk => 'غير معروف' };
}

sub _format_bytes {
    my ($bytes) = @_;
    
    if ($bytes >= 1024**3) {
        return sprintf("%.2f GB", $bytes / (1024**3));
    } elsif ($bytes >= 1024**2) {
        return sprintf("%.2f MB", $bytes / (1024**2));
    } elsif ($bytes >= 1024) {
        return sprintf("%.2f KB", $bytes / 1024);
    } else {
        return "$bytes B";
    }
}

sub _percent_bar {
    my ($percent) = @_;
    
    my $filled = int($percent / 5);
    my $empty = 20 - $filled;
    
    return "[" . ("█" x $filled) . ("░" x $empty) . "]";
}

sub _display_analysis {
    my ($analysis) = @_;
    
    my $color = Colors->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    📋 نتائج تحليل حركة المرور 📋                      ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    my $bytes_display = _format_bytes($analysis->{bytes});
    my $avg_speed = _format_bytes($analysis->{avg_speed}) . "/s";
    
    say "\n${\($color->info())}📊 الخلاصة:${\($color->reset())}";
    say "   → إجمالي الحزم: $analysis->{packets}";
    say "   → إجمالي البيانات: $bytes_display";
    say "   → متوسط السرعة: $avg_speed";
    say "   → مدة التحليل: " . sprintf("%.2f", $analysis->{duration}) . " ثانية";
    
    # عدد البروتوكولات المختلفة
    my $num_protocols = keys %{$analysis->{protocols}};
    say "   → عدد البروتوكولات المختلفة: $num_protocols";
    
    # عدد الحالات الشاذة
    my $num_anomalies = scalar(@{$analysis->{anomalies} || []});
    if ($num_anomalies > 0) {
        say "   → ${\($color->warning())}حالات شاذة مكتشفة: $num_anomalies${\($color->reset())}";
    } else {
        say "   → ${\($color->success())}لم يتم اكتشاف حالات شاذة${\($color->reset())}";
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

1;  # نهاية الوحدة
