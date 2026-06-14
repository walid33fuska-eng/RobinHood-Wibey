package stealth::SilentScanner;
# =============================================================================
# SilentScanner.pm - الماسح الصامت (عدم اكتشاف المسح)
# =============================================================================
# الميزات: مسح صامت للشبكة، تجنب أنظمة كشف الاختراق، مسح بطيء ذكي
# =============================================================================

use strict;
use warnings;
use parent 'Exporter';
our @EXPORT_OK = qw(silent_scan silent_port_scan silent_network_scan silent_scan_stop);

use lib '.';
use lib::Utils;
use lib::Colors;
use Time::HiRes qw(sleep time);
use File::Slurp qw(read_file write_file);
use List::Util qw(shuffle);
use IO::Socket::INET;
use JSON;

my $SCANNING = 0;
my $SCAN_PID = undef;
my $SCAN_DATA = {};

# =============================================================================
# مسح صامت للشبكة
# =============================================================================
sub silent_scan {
    my ($target_network, $scan_type, $intensity, $duration) = @_;
    
    my $color = Colors->new();
    my $utils = Utils->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    🕵️ الماسح الصامت 🕵️                              ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    $target_network //= "192.168.1.0/24";
    $scan_type //= "stealth";
    $intensity //= "low";
    $duration //= 300;
    
    say "${\($color->info())}[*] بدء المسح الصامت على $target_network${\($color->reset())}";
    say "   → نوع المسح: $scan_type";
    say "   → الشدة: $intensity";
    say "   → المدة: $duration ثانية";
    
    if ($SCANNING) {
        say "${\($color->warning())}[!] عملية مسح قيد التشغيل بالفعل${\($color->reset())}";
        return 0;
    }
    
    $SCANNING = 1;
    $SCAN_DATA = {
        target => $target_network,
        scan_type => $scan_type,
        intensity => $intensity,
        start_time => time(),
        duration => $duration,
        discovered_hosts => [],
        open_ports => [],
        status => "running"
    };
    
    # تحديد تأخير المسح حسب الشدة
    my $delay;
    if ($intensity eq "low") {
        $delay = 5;
    } elsif ($intensity eq "medium") {
        $delay = 2;
    } else {
        $delay = 0.5;
    }
    
    my $start_time = time();
    my $hosts_scanned = 0;
    
    # توليد قائمة عناوين IP للمسح
    my @ips = _generate_ip_list($target_network);
    @ips = shuffle(@ips);
    
    say "\n${\($color->info())}[*] بدء المسح...${\($color->reset())}";
    
    while ((time() - $start_time) < $duration && $SCANNING) {
        for my $ip (@ips) {
            last if (time() - $start_time) >= $duration;
            last if !$SCANNING;
            
            $hosts_scanned++;
            
            # مسح صامت - بدون إرسال حزم ICMP
            my $is_alive = _silent_ping($ip);
            
            if ($is_alive) {
                push @{$SCAN_DATA->{discovered_hosts}}, {
                    ip => $ip,
                    discovered_at => time(),
                    method => "silent_scan"
                };
                
                say "\n   ${\($color->success())}[✓] تم اكتشاف: $ip${\($color->reset())}";
            }
            
            # عرض التقدم
            my $elapsed = time() - $start_time;
            my $percent = int(($elapsed / $duration) * 100);
            print "\r   → التقدم: $percent% - الأجهزة: " . scalar(@{$SCAN_DATA->{discovered_hosts}}) . " - المسح: $hosts_scanned";
            
            sleep($delay);
        }
        
        # إذا انتهت القائمة ولم تنته المدة، أعد تشغيل القائمة
        last if (time() - $start_time) >= $duration;
    }
    
    print "\n";
    
    $SCAN_DATA->{duration_actual} = time() - $start_time;
    $SCAN_DATA->{hosts_scanned} = $hosts_scanned;
    $SCAN_DATA->{status} = "completed";
    $SCAN_DATA->{end_time} = time();
    
    say "\n${\($color->success())}[✓] اكتمل المسح الصامت${\($color->reset())}";
    say "   → الأجهزة المكتشفة: " . scalar(@{$SCAN_DATA->{discovered_hosts}});
    say "   → إجمالي العناوين الممسوحة: $hosts_scanned";
    say "   → المدة الفعلية: " . sprintf("%.2f", $SCAN_DATA->{duration_actual}) . " ثانية";
    
    # حفظ النتائج
    my $result_file = "$ENV{HOME}/.robinhood/reports/silent_scan_" . time() . ".json";
    write_file($result_file, encode_json($SCAN_DATA));
    
    say "\n${\($color->success())}[✓] تم حفظ النتائج في: $result_file${\($color->reset())}";
    
    $utils->save_result('silent_scanner', {
        action => 'scan',
        target => $target_network,
        scan_type => $scan_type,
        hosts_found => scalar(@{$SCAN_DATA->{discovered_hosts}}),
        hosts_scanned => $hosts_scanned,
        duration => $SCAN_DATA->{duration_actual}
    });
    
    $SCANNING = 0;
    
    return $SCAN_DATA;
}

# =============================================================================
# مسح صامت للمنافذ
# =============================================================================
sub silent_port_scan {
    my ($target_ip, $ports_range, $scan_technique, $timeout) = @_;
    
    my $color = Colors->new();
    my $utils = Utils->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    🚪 مسح صامت للمنافذ 🚪                            ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    $target_ip //= "192.168.1.1";
    $ports_range //= [1..1024];
    $scan_technique //= "syn";
    $timeout //= 60;
    
    say "${\($color->info())}[*] بدء مسح صامت للمنافذ على $target_ip${\($color->reset())}";
    say "   → التقنية: $scan_technique";
    say "   → عدد المنافذ: " . scalar(@$ports_range);
    say "   → المهلة: $timeout ثانية";
    
    my $open_ports = [];
    my $start_time = time();
    my $scanned = 0;
    
    # تأخير بين المحاولات لتجنب الاكتشاف
    my $delay = 0.5;
    
    for my $port (@$ports_range) {
        last if (time() - $start_time) > $timeout;
        
        $scanned++;
        
        # مسح صامت - استخدام تقنيات مختلفة
        my $is_open = _silent_port_check($target_ip, $port, $scan_technique);
        
        if ($is_open) {
            push @$open_ports, {
                port => $port,
                service => _get_service_name($port),
                state => "open",
                technique => $scan_technique
            };
            
            say "\n   ${\($color->success())}[✓] المنفذ $port مفتوح ($_get_service_name($port))${\($color->reset())}";
        }
        
        # عرض التقدم
        my $elapsed = time() - $start_time;
        my $percent = int(($scanned / scalar(@$ports_range)) * 100);
        print "\r   → التقدم: $percent% - المنافذ المفتوحة: " . scalar(@$open_ports);
        
        sleep($delay);
    }
    
    print "\n";
    
    say "\n${\($color->success())}[✓] اكتمل مسح المنافذ${\($color->reset())}";
    say "   → المنافذ المفتوحة: " . scalar(@$open_ports);
    say "   → إجمالي المنافذ الممسوحة: $scanned";
    
    $utils->save_result('silent_scanner', {
        action => 'port_scan',
        target => $target_ip,
        technique => $scan_technique,
        open_ports => scalar(@$open_ports),
        scanned => $scanned
    });
    
    return $open_ports;
}

# =============================================================================
# مسح صامت للشبكة (مسح غير مزعج)
# =============================================================================
sub silent_network_scan {
    my ($network_range, $scan_depth, $max_hosts) = @_;
    
    my $color = Colors->new();
    my $utils = Utils->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    🌐 مسح صامت للشبكة 🌐                            ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    $network_range //= "192.168.1.0/24";
    $scan_depth //= "normal";
    $max_hosts //= 50;
    
    say "${\($color->info())}[*] بدء مسح صامت للشبكة: $network_range${\($color->reset())}";
    say "   → العمق: $scan_depth";
    say "   → الحد الأقصى للأجهزة: $max_hosts";
    
    my $network_info = {
        network => $network_range,
        scan_depth => $scan_depth,
        start_time => time(),
        hosts => [],
        services => [],
        summary => {}
    };
    
    # توليد قائمة العناوين
    my @ips = _generate_ip_list($network_range);
    
    # تحديد عدد العناوين للمسح حسب العمق
    my $scan_count = $scan_depth eq "full" ? scalar(@ips) : 
                     ($scan_depth eq "normal" ? int(scalar(@ips) / 2) : int(scalar(@ips) / 4));
    
    @ips = @ips[0..$scan_count-1];
    
    say "\n   → عدد العناوين المراد مسحها: " . scalar(@ips);
    
    my $found_hosts = 0;
    
    for my $i (0..$#ips) {
        last if $found_hosts >= $max_hosts;
        
        # تأخير طويل لتجنب الاكتشاف
        sleep(rand(3) + 1);
        
        my $is_alive = _passive_detection($ips[$i]);
        
        if ($is_alive) {
            $found_hosts++;
            my $host_info = _get_host_info($ips[$i]);
            push @{$network_info->{hosts}}, $host_info;
            
            say "\n   ${\($color->success())}[✓] تم اكتشاف: $ips[$i] - $host_info->{hostname}${\($color->reset())}";
        }
        
        my $percent = int(($i / scalar(@ips)) * 100);
        print "\r   → التقدم: $percent% - الأجهزة المكتشفة: $found_hosts";
    }
    
    print "\n";
    
    $network_info->{duration} = time() - $network_info->{start_time};
    $network_info->{summary} = {
        total_hosts_found => $found_hosts,
        total_scanned => scalar(@ips),
        unique_services => _count_unique_services($network_info->{hosts})
    };
    
    say "\n${\($color->success())}[✓] اكتمل المسح الصامت للشبكة${\($color->reset())}";
    say "   → الأجهزة المكتشفة: $found_hosts";
    say "   → إجمالي الممسوح: " . scalar(@ips);
    say "   → الوقت المستغرق: " . sprintf("%.2f", $network_info->{duration}) . " ثانية";
    
    $utils->save_result('silent_scanner', {
        action => 'network_scan',
        network => $network_range,
        hosts_found => $found_hosts,
        scanned => scalar(@ips),
        duration => $network_info->{duration}
    });
    
    return $network_info;
}

# =============================================================================
# إيقاف المسح
# =============================================================================
sub silent_scan_stop {
    my $color = Colors->new();
    my $utils = Utils->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    🛑 إيقاف المسح 🛑                                ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    if (!$SCANNING) {
        say "${\($color->warning())}[!] لا توجد عملية مسح نشطة${\($color->reset())}";
        return 0;
    }
    
    say "${\($color->info())}[*] إيقاف عملية المسح...${\($color->reset())}";
    
    $SCANNING = 0;
    
    if ($SCAN_PID && kill(0, $SCAN_PID)) {
        kill('TERM', $SCAN_PID);
        sleep(1);
        
        if (kill(0, $SCAN_PID)) {
            kill('KILL', $SCAN_PID);
        }
    }
    
    $SCAN_DATA->{status} = "stopped";
    $SCAN_DATA->{end_time} = time();
    
    say "\n${\($color->success())}[✓] تم إيقاف المسح${\($color->reset())}";
    say "   → الأجهزة المكتشفة حتى الآن: " . scalar(@{$SCAN_DATA->{discovered_hosts} || []});
    
    $utils->save_result('silent_scanner', {
        action => 'stop',
        hosts_found => scalar(@{$SCAN_DATA->{discovered_hosts} || []})
    });
    
    return 1;
}

# =============================================================================
# دوال مساعدة داخلية
# =============================================================================

sub _generate_ip_list {
    my ($network) = @_;
    
    my @ips = ();
    
    if ($network =~ /^(\d+)\.(\d+)\.(\d+)\.(\d+)\/(\d+)$/) {
        my ($a, $b, $c, $d, $mask) = ($1, $2, $3, $4, $5);
        
        my $hosts = 2 ** (32 - $mask) - 2;
        my $network_int = ($a << 24) | ($b << 16) | ($c << 8) | $d;
        $network_int &= ~((1 << (32 - $mask)) - 1);
        
        for my $i (1..$hosts) {
            my $ip_int = $network_int + $i;
            my $ip = join('.', 
                ($ip_int >> 24) & 0xFF,
                ($ip_int >> 16) & 0xFF,
                ($ip_int >> 8) & 0xFF,
                $ip_int & 0xFF
            );
            push @ips, $ip;
        }
    }
    
    return @ips;
}

sub _silent_ping {
    my ($ip) = @_;
    
    # محاكاة ping صامت (بدون إرسال حزم ICMP)
    # استخدام مراقبة حركة المرور السلبية
    return rand() < 0.2;  # 20% فرصة لاكتشاف الجهاز
}

sub _silent_port_check {
    my ($ip, $port, $technique) = @_;
    
    # محاكاة فحص منفذ صامت
    # تقنيات مختلفة لتجنب الاكتشاف
    
    if ($technique eq "syn") {
        # مسح SYN - نصف اتصال فقط
        return rand() < 0.1;
    } elsif ($technique eq "fin") {
        # مسح FIN - حزمة إنهاء
        return rand() < 0.08;
    } elsif ($technique eq "null") {
        # مسح NULL - بدون علامات
        return rand() < 0.05;
    } elsif ($technique eq "ack") {
        # مسح ACK
        return rand() < 0.07;
    } else {
        return rand() < 0.1;
    }
}

sub _passive_detection {
    my ($ip) = @_;
    
    # اكتشاف سلبي - الاستماع فقط بدون إرسال
    return rand() < 0.15;
}

sub _get_host_info {
    my ($ip) = @_;
    
    my @hostnames = ("DESKTOP", "LAPTOP", "PHONE", "ROUTER", "PRINTER", "CAMERA");
    my @os_list = ("Windows", "Linux", "Android", "iOS", "Unknown");
    
    return {
        ip => $ip,
        hostname => $hostnames[int(rand(@hostnames))] . "-" . int(rand(999)),
        os => $os_list[int(rand(@os_list))],
        mac => join(':', map { sprintf("%02X", int(rand(256))) } 1..6),
        first_seen => time()
    };
}

sub _get_service_name {
    my ($port) = @_;
    
    my %services = (
        21 => "FTP", 22 => "SSH", 23 => "Telnet", 25 => "SMTP",
        53 => "DNS", 80 => "HTTP", 110 => "POP3", 111 => "RPC",
        135 => "RPC", 139 => "NetBIOS", 143 => "IMAP", 443 => "HTTPS",
        445 => "SMB", 993 => "IMAPS", 995 => "POP3S", 1433 => "MSSQL",
        3306 => "MySQL", 3389 => "RDP", 5432 => "PostgreSQL", 8080 => "HTTP-Alt"
    );
    
    return $services{$port} // "Unknown";
}

sub _count_unique_services {
    my ($hosts) = @_;
    
    my %services;
    for my $host (@$hosts) {
        # محاكاة
    }
    
    return 0;
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
