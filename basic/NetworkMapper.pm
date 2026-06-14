package basic::NetworkMapper;
# =============================================================================
# NetworkMapper.pm - رسم خريطة الشبكة وتحديد الطوبولوجيا
# =============================================================================
# الميزات: اكتشاف طوبولوجيا الشبكة، رسم العلاقات بين الأجهزة، تحديد نقاط الضعف
# =============================================================================

use strict;
use warnings;
use parent 'Exporter';
our @EXPORT_OK = qw(network_map network_topology network_path_analysis network_vulnerable_paths);

use lib '.';
use lib::Utils;
use lib::Colors;
use Time::HiRes qw(time);
use File::Slurp qw(write_file);
use List::Util qw(first);

# =============================================================================
# رسم خريطة الشبكة
# =============================================================================
sub network_map {
    my ($target_network, $interface, $depth) = @_;
    
    my $color = Colors->new();
    my $utils = Utils->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    🗺️ رسم خريطة الشبكة 🗺️                            ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    $target_network //= "192.168.1.0/24";
    $interface //= "wlan0";
    $depth //= 3;
    
    say "${\($color->info())}[*] الشبكة المستهدفة: $target_network${\($color->reset())}";
    say "${\($color->info())}[*] الواجهة: $interface${\($color->reset())}";
    say "${\($color->info())}[*] عمق الاكتشاف: $depth قفزات${\($color->reset())}";
    
    # بدء الاكتشاف
    say "\n${\($color->info())}[*] بدء رسم خريطة الشبكة...${\($color->reset())}";
    
    my $network_map = {
        root => $target_network,
        devices => [],
        connections => [],
        gateways => [],
        timestamp => time()
    };
    
    # اكتشاف الجهاز الرئيسي (الراوتر)
    my $gateway = _discover_gateway($target_network);
    push @{$network_map->{gateways}}, $gateway;
    push @{$network_map->{devices}}, $gateway;
    
    # اكتشاف الأجهزة المتصلة
    my $devices = _discover_devices($target_network);
    push @{$network_map->{devices}}, @$devices;
    
    # اكتشاف العلاقات بين الأجهزة
    my $connections = _discover_connections($network_map->{devices});
    $network_map->{connections} = $connections;
    
    # عرض الخريطة
    _display_network_map($network_map);
    
    # حفظ الخريطة
    my $map_file = "$ENV{HOME}/.robinhood/logs/network_map_" . time() . ".json";
    write_file($map_file, encode_json($network_map));
    
    say "\n${\($color->success())}[✓] تم حفظ خريطة الشبكة في: $map_file${\($color->reset())}";
    
    $utils->save_result('network_mapper', {
        network => $target_network,
        devices_count => scalar(@{$network_map->{devices}}),
        connections_count => scalar(@{$network_map->{connections}})
    });
    
    return $network_map;
}

# =============================================================================
# تحليل طوبولوجيا الشبكة
# =============================================================================
sub network_topology {
    my ($network_map) = @_;
    
    my $color = Colors->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    🔬 تحليل طوبولوجيا الشبكة 🔬                       ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    $network_map //= {};
    
    my $topology = {
        type => _determine_topology_type($network_map),
        diameter => _calculate_network_diameter($network_map),
        central_devices => _find_central_devices($network_map),
        segments => _identify_segments($network_map),
        bottlenecks => _find_bottlenecks($network_map)
    };
    
    say "\n${\($color->info())}📊 معلومات الطوبولوجيا:${\($color->reset())}";
    say "   → نوع الطوبولوجيا: $topology->{type}";
    say "   → قطر الشبكة: $topology->{diameter} قفزات";
    say "   → عدد الأجهزة: " . scalar(@{$network_map->{devices} || []});
    say "   → عدد الاتصالات: " . scalar(@{$network_map->{connections} || []});
    
    if (scalar(@{$topology->{central_devices}}) > 0) {
        say "\n${\($color->info())}🎯 الأجهزة المركزية:${\($color->reset())}";
        for my $device (@{$topology->{central_devices}}) {
            say "   → $device->{ip} ($device->{type}) - مركزية: $device->{centrality}%";
        }
    }
    
    if (scalar(@{$topology->{bottlenecks}}) > 0) {
        say "\n${\($color->warning())}⚠️ نقاط الاختناق المحتملة:${\($color->reset())}";
        for my $bottleneck (@{$topology->{bottlenecks}}) {
            say "   → $bottleneck->{device} - $bottleneck->{reason}";
        }
    }
    
    return $topology;
}

# =============================================================================
# تحليل مسارات الشبكة
# =============================================================================
sub network_path_analysis {
    my ($network_map, $source_ip, $destination_ip) = @_;
    
    my $color = Colors->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    🛣️ تحليل مسارات الشبكة 🛣️                          ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    $network_map //= {};
    $source_ip //= "192.168.1.1";
    $destination_ip //= "192.168.1.100";
    
    # البحث عن المسارات
    my $paths = _find_paths($network_map, $source_ip, $destination_ip);
    
    say "\n${\($color->info())}[*] المصدر: $source_ip${\($color->reset())}";
    say "${\($color->info())}[*] الوجهة: $destination_ip${\($color->reset())}";
    
    if (scalar(@$paths) == 0) {
        say "\n${\($color->error())}[!] لا يوجد مسار بين المصدر والوجهة${\($color->reset())}";
        return [];
    }
    
    say "\n${\($color->success())}✅ تم العثور على " . scalar(@$paths) . " مسار(ات):${\($color->reset())}";
    
    my $i = 1;
    for my $path (@$paths) {
        say "\n   المسار $i:";
        say "   → " . join(" → ", @{$path->{nodes}});
        say "   → عدد القفزات: $path->{hops}";
        say "   → الوقت المقدر: $path->{estimated_time} ms";
        $i++;
    }
    
    return $paths;
}

# =============================================================================
# اكتشاف المسارات الضعيفة
# =============================================================================
sub network_vulnerable_paths {
    my ($network_map) = @_;
    
    my $color = Colors->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    🚨 المسارات الضعيفة 🚨                             ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    $network_map //= {};
    
    my $vulnerable_paths = _find_vulnerable_paths($network_map);
    
    if (scalar(@$vulnerable_paths) == 0) {
        say "\n${\($color->success())}✓ لم يتم اكتشاف مسارات ضعيفة${\($color->reset())}";
        return [];
    }
    
    say "\n${\($color->warning())}⚠️ تم اكتشاف " . scalar(@$vulnerable_paths) . " مسار ضعيف:${\($color->reset())}";
    
    for my $path (@$vulnerable_paths) {
        say "\n   → المسار: " . join(" → ", @{$path->{nodes}});
        say "   → سبب الضعف: $path->{reason}";
        say "   → مستوى الخطورة: $path->{severity}";
        say "   → التوصية: $path->{recommendation}";
    }
    
    return $vulnerable_paths;
}

# =============================================================================
# دوال مساعدة داخلية
# =============================================================================

sub _discover_gateway {
    my ($network) = @_;
    
    # محاكاة اكتشاف البوابة الرئيسية
    return {
        ip => "192.168.1.1",
        mac => "AA:BB:CC:DD:EE:01",
        type => "Router/Gateway",
        manufacturer => "TP-Link",
        os => "Linux",
        is_gateway => 1,
        services => ["DHCP", "DNS", "HTTP"]
    };
}

sub _discover_devices {
    my ($network) = @_;
    
    my @devices = ();
    
    # أجهزة وهمية للمحاكاة
    my @device_templates = (
        { ip => "192.168.1.10", mac => "AA:BB:CC:DD:EE:10", type => "Laptop", manufacturer => "Dell", os => "Windows" },
        { ip => "192.168.1.11", mac => "AA:BB:CC:DD:EE:11", type => "Phone", manufacturer => "Apple", os => "iOS" },
        { ip => "192.168.1.12", mac => "AA:BB:CC:DD:EE:12", type => "Phone", manufacturer => "Samsung", os => "Android" },
        { ip => "192.168.1.13", mac => "AA:BB:CC:DD:EE:13", type => "Tablet", manufacturer => "Apple", os => "iOS" },
        { ip => "192.168.1.14", mac => "AA:BB:CC:DD:EE:14", type => "Desktop", manufacturer => "HP", os => "Linux" },
        { ip => "192.168.1.15", mac => "AA:BB:CC:DD:EE:15", type => "Smart TV", manufacturer => "Samsung", os => "Tizen" },
        { ip => "192.168.1.16", mac => "AA:BB:CC:DD:EE:16", type => "Printer", manufacturer => "HP", os => "Embedded" },
        { ip => "192.168.1.17", mac => "AA:BB:CC:DD:EE:17", type => "Camera", manufacturer => "Xiaomi", os => "Linux" }
    );
    
    # اختيار عشوائي من 3 إلى 6 أجهزة
    my $num_devices = int(rand(4)) + 3;
    for my $i (0..$num_devices-1) {
        my $device = $device_templates[$i % scalar(@device_templates)];
        push @devices, $device;
    }
    
    return \@devices;
}

sub _discover_connections {
    my ($devices) = @_;
    
    my @connections = ();
    
    # البوابة الرئيسية (أول جهاز)
    my $gateway = $devices->[0];
    
    # ربط جميع الأجهزة بالبوابة
    for my $i (1..$#$devices) {
        push @connections, {
            from => $gateway->{ip},
            to => $devices->[$i]->{ip},
            type => "wireless",
            signal => int(rand(60)) + 30
        };
    }
    
    # بعض الاتصالات المباشرة بين الأجهزة (P2P)
    if (scalar(@$devices) > 3) {
        push @connections, {
            from => $devices->[1]->{ip},
            to => $devices->[2]->{ip},
            type => "direct",
            protocol => "AirDrop"
        };
    }
    
    return \@connections;
}

sub _display_network_map {
    my ($network_map) = @_;
    
    my $color = Colors->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    🗺️ خريطة الشبكة 🗺️                                 ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    # رسم الخريطة بشكل نصي بسيط
    say "\n${\($color->info())}📡 البوابة الرئيسية:${\($color->reset())}";
    say "   ┌─────────────┐";
    say "   │  ${\($color->quantum())}$network_map->{gateways}[0]{ip}${\($color->reset())}  │";
    say "   │  (Router)   │";
    say "   └──────┬──────┘";
    say "          │";
    
    say "\n${\($color->info())}📱 الأجهزة المتصلة:${\($color->reset())}";
    
    my $devices = $network_map->{devices};
    for my $i (1..$#$devices) {
        my $device = $devices->[$i];
        my $icon = $device->{type} eq "Laptop" ? "💻" :
                  ($device->{type} eq "Phone" ? "📱" :
                  ($device->{type} eq "Tablet" ? "📟" :
                  ($device->{type} eq "Smart TV" ? "📺" : "🖥️")));
        
        say "   ├── $icon $device->{ip} ($device->{type})";
        say "   │   └── $device->{manufacturer} - $device->{os}";
    }
    
    # عرض الاتصالات المباشرة بين الأجهزة
    my $connections = $network_map->{connections};
    my $direct_connections = [grep { $_->{type} eq 'direct' } @$connections];
    
    if (scalar(@$direct_connections) > 0) {
        say "\n${\($color->info())}🔗 الاتصالات المباشرة بين الأجهزة:${\($color->reset())}";
        for my $conn (@$direct_connections) {
            say "   → $conn->{from} ↔ $conn->{to} ($conn->{protocol})";
        }
    }
}

sub _determine_topology_type {
    my ($network_map) = @_;
    
    my $connections = $network_map->{connections};
    my $devices_count = scalar(@{$network_map->{devices} || []});
    my $connections_count = scalar(@$connections);
    
    # تحديد نوع الطوبولوجيا
    if ($connections_count == $devices_count - 1) {
        return "شجرة (Star/Tree)";
    } elsif ($connections_count > $devices_count) {
        return "شبكية (Mesh)";
    } elsif ($connections_count == $devices_count) {
        return "حلقية (Ring)";
    } else {
        return "هجينة (Hybrid)";
    }
}

sub _calculate_network_diameter {
    my ($network_map) = @_;
    
    # محاكاة حساب قطر الشبكة
    return int(rand(3)) + 2;
}

sub _find_central_devices {
    my ($network_map) = @_;
    
    my @central = ();
    my $devices = $network_map->{devices};
    
    # البوابة هي الجهاز الأكثر مركزية
    if (scalar(@$devices) > 0) {
        push @central, {
            ip => $devices->[0]->{ip},
            type => $devices->[0]->{type},
            centrality => 100
        };
    }
    
    return \@central;
}

sub _identify_segments {
    my ($network_map) = @_;
    
    # محاكاة تقسيم الشبكة إلى قطاعات
    return ["192.168.1.0/24"];
}

sub _find_bottlenecks {
    my ($network_map) = @_;
    
    my @bottlenecks = ();
    my $devices = $network_map->{devices};
    
    # البوابة قد تكون عنق زجاجة
    if (scalar(@$devices) > 5) {
        push @bottlenecks, {
            device => $devices->[0]->{ip},
            reason => "عدد كبير من الأجهزة (${\scalar(@$devices)}) يتصل عبر بوابة واحدة"
        };
    }
    
    return \@bottlenecks;
}

sub _find_paths {
    my ($network_map, $source, $destination) = @_;
    
    my @paths = ();
    
    # مسار مباشر عبر البوابة
    my $gateway = $network_map->{gateways}[0]{ip};
    
    push @paths, {
        nodes => [$source, $gateway, $destination],
        hops => 2,
        estimated_time => int(rand(20)) + 5
    };
    
    # مسار مباشر إذا كان الجهازان متصلين مباشرة
    my $connections = $network_map->{connections};
    my $direct = first { ($_->{from} eq $source && $_->{to} eq $destination) ||
                         ($_->{from} eq $destination && $_->{to} eq $source) } @$connections;
    
    if ($direct) {
        push @paths, {
            nodes => [$source, $destination],
            hops => 1,
            estimated_time => int(rand(5)) + 1
        };
    }
    
    return \@paths;
}

sub _find_vulnerable_paths {
    my ($network_map) = @_;
    
    my @vulnerable = ();
    my $connections = $network_map->{connections};
    
    # فحص الاتصالات اللاسلكية الضعيفة
    for my $conn (@$connections) {
        if ($conn->{type} eq 'wireless' && ($conn->{signal} // 0) < 40) {
            push @vulnerable, {
                nodes => [$conn->{from}, $conn->{to}],
                reason => "إشارة لاسلكية ضعيفة ($conn->{signal}%)",
                severity => "متوسطة",
                recommendation => "حسّن قوة الإشارة أو استخدم كابل"
            };
        }
    }
    
    # إضافة مسار البوابة إذا كان عدد الأجهزة كبيراً
    if (scalar(@{$network_map->{devices}}) > 8) {
        my $gateway = $network_map->{gateways}[0]{ip};
        push @vulnerable, {
            nodes => [$gateway],
            reason => "ازدحام محتمل على البوابة الرئيسية",
            severity => "متوسطة",
            recommendation => "وزع الحمل أو قم بترقية الراوتر"
        };
    }
    
    return \@vulnerable;
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
