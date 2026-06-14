package basic::DeviceDiscovery;
# =============================================================================
# DeviceDiscovery.pm - اكتشاف الأجهزة المتصلة بالشبكة
# =============================================================================
# الميزات: اكتشاف جميع الأجهزة، تحديد نوع الجهاز، تحليل سلوك الأجهزة
# =============================================================================

use strict;
use warnings;
use parent 'Exporter';
our @EXPORT_OK = qw(discover_devices discover_device_info discover_os_fingerprint discover_device_tracking);

use lib '.';
use lib::Utils;
use lib::Colors;
use Time::HiRes qw(sleep time);
use File::Slurp qw(write_file);
use List::Util qw(first);

# قاعدة بيانات عناوين MAC المعروفة
my %KNOWN_MANUFACTURERS = (
    '00:11:22' => 'Cisco',
    '00:14:22' => 'Dell',
    '00:16:CB' => 'Apple',
    '00:1A:2B' => 'Samsung',
    '00:1E:C2' => 'Huawei',
    '00:23:DF' => 'Xiaomi',
    '00:25:9C' => 'Google',
    '00:50:F2' => 'Microsoft',
    '08:00:27' => 'Oracle/VirtualBox',
    '0C:8B:FD' => 'Intel',
    '10:68:3F' => 'TP-Link',
    '14:10:9F' => 'Sony',
    '18:34:51' => 'LG',
    '1C:69:7A' => 'OnePlus',
    '20:DF:B9' => 'HTC',
    '24:0A:C4' => 'Nokia',
    '28:6C:07' => 'Asus',
    '2C:54:91' => 'Acer',
    '30:5A:3A' => 'HP',
    '34:02:86' => 'Lenovo'
);

# =============================================================================
# اكتشاف جميع الأجهزة
# =============================================================================
sub discover_devices {
    my ($target_bssid, $interface, $timeout) = @_;
    
    my $color = Colors->new();
    my $utils = Utils->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    🔍 اكتشاف الأجهزة 🔍                               ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    $target_bssid //= "AA:BB:CC:DD:EE:FF";
    $interface //= "wlan0";
    $timeout //= 30;
    
    say "${\($color->info())}[*] الهدف: $target_bssid${\($color->reset())}";
    say "${\($color->info())}[*] الواجهة: $interface${\($color->reset())}";
    say "${\($color->info())}[*] المهلة: $timeout ثانية${\($color->reset())}";
    
    # بدء اكتشاف الأجهزة
    say "\n${\($color->info())}[*] بدء اكتشاف الأجهزة...${\($color->reset())}";
    
    my $devices = [];
    my $start_time = time();
    
    # محاكاة إرسال حزم ARP ومراقبة الردود
    while ((time() - $start_time) < $timeout) {
        my $new_devices = _probe_for_devices($target_bssid, $interface);
        
        for my $device (@$new_devices) {
            # تجنب التكرار
            my $exists = first { $_->{mac} eq $device->{mac} } @$devices;
            if (!$exists) {
                push @$devices, $device;
                say "${\($color->success())}[✓] تم اكتشاف جهاز جديد: $device->{mac} - $device->{manufacturer} - $device->{type}${\($color->reset())}";
            }
        }
        
        my $elapsed = time() - $start_time;
        print "\r${\($color->info())}[*] الوقت: $elapsed/$timeout ثانية - الأجهزة المكتشفة: " . scalar(@$devices) . "${\($color->reset())}";
        
        sleep(2);
    }
    
    print "\n";
    
    # عرض النتائج
    _display_devices($devices);
    
    # حفظ النتائج
    my $devices_file = "$ENV{HOME}/.robinhood/logs/devices_" . time() . ".json";
    write_file($devices_file, encode_json($devices));
    
    say "\n${\($color->success())}[✓] تم حفظ قائمة الأجهزة في: $devices_file${\($color->reset())}";
    
    $utils->save_result('device_discovery', {
        bssid => $target_bssid,
        devices_count => scalar(@$devices),
        devices => $devices
    });
    
    return $devices;
}

# =============================================================================
# معلومات مفصلة عن جهاز محدد
# =============================================================================
sub discover_device_info {
    my ($target_mac, $interface) = @_;
    
    my $color = Colors->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    ℹ️ معلومات الجهاز ℹ️                              ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    $target_mac //= "AA:BB:CC:DD:EE:FF";
    $interface //= "wlan0";
    
    say "${\($color->info())}[*] الجهاز المستهدف: $target_mac${\($color->reset())}";
    
    # جمع المعلومات
    my $manufacturer = _get_manufacturer($target_mac);
    my $device_type = _guess_device_type($target_mac);
    my $os = _guess_os($target_mac);
    my $signal = _get_device_signal($target_mac, $interface);
    my $first_seen = time() - int(rand(3600));
    my $last_seen = time();
    
    my $device_info = {
        mac => $target_mac,
        manufacturer => $manufacturer,
        type => $device_type,
        os => $os,
        signal => $signal,
        first_seen => $first_seen,
        last_seen => $last_seen,
        is_active => 1
    };
    
    say "\n${\($color->info())}📱 معلومات الجهاز:${\($color->reset())}";
    say "   → عنوان MAC: $device_info->{mac}";
    say "   → الشركة المصنعة: $device_info->{manufacturer}";
    say "   → نوع الجهاز: $device_info->{type}";
    say "   → نظام التشغيل: $device_info->{os}";
    say "   → قوة الإشارة: $device_info->{signal}%";
    say "   → أول ظهور: " . localtime($device_info->{first_seen});
    say "   → آخر ظهور: " . localtime($device_info->{last_seen});
    
    return $device_info;
}

# =============================================================================
# بصمة نظام التشغيل
# =============================================================================
sub discover_os_fingerprint {
    my ($target_mac, $interface) = @_;
    
    my $color = Colors->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    🖥️ بصمة نظام التشغيل 🖥️                           ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    $target_mac //= "AA:BB:CC:DD:EE:FF";
    $interface //= "wlan0";
    
    say "${\($color->info())}[*] تحليل بصمة نظام التشغيل للجهاز $target_mac${\($color->reset())}";
    
    # محاكاة تحليل الحزم لتحديد نظام التشغيل
    my $os_fingerprint = _analyze_os_fingerprint($target_mac);
    
    say "\n${\($color->info())}🔬 نتائج التحليل:${\($color->reset())}";
    say "   → نظام التشغيل: $os_fingerprint->{os}";
    say "   → الثقة: $os_fingerprint->{confidence}%";
    say "   → طريقة التحديد: $os_fingerprint->{method}";
    
    # نقاط الضعف المحتملة حسب نظام التشغيل
    say "\n${\($color->warning())}⚠️ نقاط الضعف المحتملة:${\($color->reset())}";
    for my $vuln (@{$os_fingerprint->{vulnerabilities}}) {
        say "   → $vuln";
    }
    
    return $os_fingerprint;
}

# =============================================================================
# تتبع حركة الأجهزة
# =============================================================================
sub discover_device_tracking {
    my ($target_mac, $interface, $duration) = @_;
    
    my $color = Colors->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    📍 تتبع حركة الجهاز 📍                            ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    $target_mac //= "AA:BB:CC:DD:EE:FF";
    $interface //= "wlan0";
    $duration //= 60;
    
    say "${\($color->info())}[*] تتبع الجهاز: $target_mac${\($color->reset())}";
    say "${\($color->info())}[*] مدة التتبع: $duration ثانية${\($color->reset())}";
    
    my $tracking_data = [];
    my $start_time = time();
    
    say "\n${\($color->info())}[*] بدء التتبع...${\($color->reset())}";
    
    while ((time() - $start_time) < $duration) {
        my $signal = _get_device_signal($target_mac, $interface);
        my $timestamp = time();
        
        push @$tracking_data, {
            timestamp => $timestamp,
            time => scalar(localtime($timestamp)),
            signal => $signal
        };
        
        # عرض قوة الإشارة الحالية
        my $signal_bar = _signal_bar($signal);
        my $elapsed = time() - $start_time;
        print "\r${\($color->info())}[$elapsed ث] الإشارة: $signal% $signal_bar${\($color->reset())}";
        
        sleep(1);
    }
    
    print "\n";
    
    # تحليل مسار الحركة
    my $analysis = _analyze_movement($tracking_data);
    
    say "\n${\($color->success())}📊 تحليل حركة الجهاز:${\($color->reset())}";
    say "   → أقوى إشارة: $analysis->{max_signal}%";
    say "   → أضعف إشارة: $analysis->{min_signal}%";
    say "   → متوسط الإشارة: " . sprintf("%.1f", $analysis->{avg_signal}) . "%";
    say "   → الاتجاه: $analysis->{direction}";
    say "   → السرعة المقدرة: $analysis->{speed}";
    
    # حفظ بيانات التتبع
    my $tracking_file = "$ENV{HOME}/.robinhood/logs/tracking_" . $target_mac . "_" . time() . ".json";
    write_file($tracking_file, encode_json($tracking_data));
    say "\n${\($color->success())}[✓] تم حفظ بيانات التتبع في: $tracking_file${\($color->reset())}";
    
    return {
        tracking_data => $tracking_data,
        analysis => $analysis
    };
}

# =============================================================================
# دوال مساعدة داخلية
# =============================================================================

sub _probe_for_devices {
    my ($bssid, $interface) = @_;
    
    my @devices = ();
    
    # عدد الأجهزة الوهمية للمحاكاة
    my $num_new_devices = int(rand(3));
    
    my @fake_macs = (
        "00:11:22:33:44:01", "00:11:22:33:44:02", "00:11:22:33:44:03",
        "00:14:22:33:44:04", "00:16:CB:33:44:05", "00:1A:2B:33:44:06",
        "00:1E:C2:33:44:07", "00:23:DF:33:44:08", "00:25:9C:33:44:09",
        "00:50:F2:33:44:10", "08:00:27:33:44:11", "0C:8B:FD:33:44:12"
    );
    
    my @types = ("Phone", "Laptop", "Tablet", "Desktop", "TV", "IoT", "Camera", "Printer");
    my @oss = ("Windows", "Linux", "macOS", "Android", "iOS", "ChromeOS", "Unknown");
    
    for my $i (1..$num_new_devices) {
        my $mac = $fake_macs[int(rand(@fake_macs))];
        my $manufacturer = _get_manufacturer($mac);
        my $type = $types[int(rand(@types))];
        my $os = $oss[int(rand(@oss))];
        my $signal = int(rand(70)) + 20;
        
        push @devices, {
            mac => $mac,
            manufacturer => $manufacturer,
            type => $type,
            os => $os,
            signal => $signal,
            first_seen => time(),
            last_seen => time()
        };
    }
    
    return \@devices;
}

sub _get_manufacturer {
    my ($mac) = @_;
    
    my $prefix = uc(substr($mac, 0, 8));
    
    if ($KNOWN_MANUFACTURERS{$prefix}) {
        return $KNOWN_MANUFACTURERS{$prefix};
    }
    
    return "Unknown";
}

sub _guess_device_type {
    my ($mac) = @_;
    
    my $manufacturer = _get_manufacturer($mac);
    
    my %type_map = (
        'Apple' => 'Phone/Laptop',
        'Samsung' => 'Phone/Tablet',
        'Huawei' => 'Phone',
        'Xiaomi' => 'Phone',
        'Dell' => 'Laptop',
        'HP' => 'Laptop/Printer',
        'Lenovo' => 'Laptop',
        'Cisco' => 'Network Device',
        'TP-Link' => 'Router/Switch'
    );
    
    return $type_map{$manufacturer} || "Unknown Device";
}

sub _guess_os {
    my ($mac) = @_;
    
    my $manufacturer = _get_manufacturer($mac);
    
    my %os_map = (
        'Apple' => 'iOS/macOS',
        'Microsoft' => 'Windows',
        'Google' => 'Android/ChromeOS',
        'Oracle' => 'Virtual Machine'
    );
    
    return $os_map{$manufacturer} || "Unknown";
}

sub _get_device_signal {
    my ($mac, $interface) = @_;
    
    # محاكاة قوة الإشارة
    return int(rand(70)) + 20;
}

sub _analyze_os_fingerprint {
    my ($mac) = @_;
    
    my $manufacturer = _get_manufacturer($mac);
    
    my %os_profiles = (
        'Apple' => {
            os => 'iOS/macOS',
            confidence => 85,
            method => 'MAC OUI + TCP fingerprint',
            vulnerabilities => ['Weak encryption in older versions', 'Bluetooth vulnerabilities']
        },
        'Microsoft' => {
            os => 'Windows',
            confidence => 90,
            method => 'MAC OUI + SMB fingerprint',
            vulnerabilities => ['SMB vulnerabilities (EternalBlue)', 'RDP weak configurations']
        },
        'Google' => {
            os => 'Android',
            confidence => 80,
            method => 'MAC OUI + DHCP fingerprint',
            vulnerabilities => ['Stagefright', 'BlueBorne']
        },
        'Dell' => {
            os => 'Windows/Linux',
            confidence => 60,
            method => 'MAC OUI only',
            vulnerabilities => ['Depends on installed OS']
        }
    );
    
    if ($os_profiles{$manufacturer}) {
        return $os_profiles{$manufacturer};
    }
    
    return {
        os => 'Unknown',
        confidence => 30,
        method => 'Unable to determine',
        vulnerabilities => ['Unknown - further scanning required']
    };
}

sub _analyze_movement {
    my ($tracking_data) = @_;
    
    my @signals = map { $_->{signal} } @$tracking_data;
    my $max_signal = max(@signals);
    my $min_signal = min(@signals);
    my $avg_signal = sum(@signals) / scalar(@signals);
    
    # تحديد الاتجاه بناءً على تغير الإشارة
    my $first_signal = $signals[0];
    my $last_signal = $signals[-1];
    my $direction = $last_signal > $first_signal ? "يقترب" : "يبتعد";
    
    # حساب السرعة المقدرة
    my $speed = "بطيء";
    if (abs($last_signal - $first_signal) > 30) {
        $speed = "سريع";
    } elsif (abs($last_signal - $first_signal) > 15) {
        $speed = "متوسط";
    }
    
    return {
        max_signal => $max_signal,
        min_signal => $min_signal,
        avg_signal => $avg_signal,
        direction => $direction,
        speed => $speed
    };
}

sub _signal_bar {
    my ($signal) = @_;
    
    my $filled = int($signal / 10);
    my $empty = 10 - $filled;
    
    return "[" . ("█" x $filled) . ("░" x $empty) . "]";
}

sub _display_devices {
    my ($devices) = @_;
    
    my $color = Colors->new();
    
    if (scalar(@$devices) == 0) {
        say "\n${\($color->warning())}[!] لم يتم اكتشاف أي أجهزة${\($color->reset())}";
        return;
    }
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    📱 قائمة الأجهزة المكتشفة 📱                       ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    say "\n${\($color->info())}الجهاز | عنوان MAC | الشركة المصنعة | النوع | قوة الإشارة${\($color->reset())}";
    say "-------|-----------|----------------|-------|--------------";
    
    my $i = 1;
    for my $device (@$devices) {
        my $signal_bar = _signal_bar($device->{signal});
        printf "   %2d  | %s | %s | %s | %s %d%%\n",
               $i++, $device->{mac}, $device->{manufacturer}, $device->{type},
               $signal_bar, $device->{signal};
    }
}

# دوال مساعدة إضافية
sub max {
    my @list = @_;
    my $max = $list[0];
    for (@list) { $max = $_ if $_ > $max; }
    return $max;
}

sub min {
    my @list = @_;
    my $min = $list[0];
    for (@list) { $min = $_ if $_ < $min; }
    return $min;
}

sub sum {
    my $sum = 0;
    $sum += $_ for @_;
    return $sum;
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
