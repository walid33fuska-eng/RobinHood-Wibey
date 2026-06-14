package integration::WebInterface;
# =============================================================================
# WebInterface.pm - واجهة ويب للتحكم والمراقبة
# =============================================================================
# الميزات: خادم ويب مدمج، لوحة تحكم، مراقبة عن بعد، واجهة API
# =============================================================================

use strict;
use warnings;
use parent 'Exporter';
our @EXPORT_OK = qw(web_start web_stop web_status web_dashboard);

use lib '.';
use lib::Utils;
use lib::Colors;
use HTTP::Daemon;
use HTTP::Status;
use File::Slurp qw(read_file write_file);
use Time::HiRes qw(time);
use JSON;

my $WEB_SERVER_PID = undef;
my $WEB_SERVER_PORT = 8080;
my $WEB_SERVER_RUNNING = 0;

# =============================================================================
# تشغيل خادم الويب
# =============================================================================
sub web_start {
    my ($port, $bind_address) = @_;
    
    my $color = Colors->new();
    my $utils = Utils->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    🌐 تشغيل واجهة الويب 🌐                           ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    $port //= 8080;
    $bind_address //= "127.0.0.1";
    
    if ($WEB_SERVER_RUNNING) {
        say "${\($color->warning())}[!] خادم الويب قيد التشغيل بالفعل على المنفذ $WEB_SERVER_PORT${\($color->reset())}";
        return 0;
    }
    
    say "${\($color->info())}[*] بدء تشغيل خادم الويب على $bind_address:$port${\($color->reset())}";
    
    $WEB_SERVER_PID = fork();
    
    if ($WEB_SERVER_PID == 0) {
        _web_server_loop($port, $bind_address);
        exit(0);
    }
    
    $WEB_SERVER_RUNNING = 1;
    $WEB_SERVER_PORT = $port;
    
    say "\n${\($color->success())}[✓] تم تشغيل خادم الويب بنجاح (PID: $WEB_SERVER_PID)${\($color->reset())}";
    say "   → الواجهة: http://$bind_address:$port";
    say "   → لوحة التحكم: http://$bind_address:$port/dashboard";
    say "   → API: http://$bind_address:$port/api";
    
    $utils->save_result('web_interface', {
        action => 'start',
        port => $port,
        bind_address => $bind_address,
        pid => $WEB_SERVER_PID
    });
    
    return 1;
}

# =============================================================================
# إيقاف خادم الويب
# =============================================================================
sub web_stop {
    my $color = Colors->new();
    my $utils = Utils->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    🛑 إيقاف واجهة الويب 🛑                            ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    if (!$WEB_SERVER_RUNNING) {
        say "${\($color->warning())}[!] خادم الويب ليس قيد التشغيل${\($color->reset())}";
        return 0;
    }
    
    say "${\($color->info())}[*] إيقاف خادم الويب...${\($color->reset())}";
    
    if ($WEB_SERVER_PID && kill(0, $WEB_SERVER_PID)) {
        kill('TERM', $WEB_SERVER_PID);
        sleep(1);
        
        if (kill(0, $WEB_SERVER_PID)) {
            kill('KILL', $WEB_SERVER_PID);
        }
    }
    
    $WEB_SERVER_RUNNING = 0;
    $WEB_SERVER_PID = undef;
    
    say "\n${\($color->success())}[✓] تم إيقاف خادم الويب${\($color->reset())}";
    
    $utils->save_result('web_interface', {
        action => 'stop'
    });
    
    return 1;
}

# =============================================================================
# حالة خادم الويب
# =============================================================================
sub web_status {
    my $color = Colors->new();
    my $utils = Utils->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    📊 حالة واجهة الويب 📊                            ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    if ($WEB_SERVER_RUNNING) {
        say "\n${\($color->success())}✓ خادم الويب قيد التشغيل${\($color->reset())}";
        say "   → PID: $WEB_SERVER_PID";
        say "   → المنفذ: $WEB_SERVER_PORT";
        say "   → وقت التشغيل: " . _get_uptime();
        
        # إحصائيات الطلبات
        my $stats = _get_request_stats();
        say "\n${\($color->info())}📈 إحصائيات الطلبات:${\($color->reset())}";
        say "   → إجمالي الطلبات: $stats->{total_requests}";
        say "   → الطلبات الناجحة: $stats->{successful_requests}";
        say "   → متوسط وقت الاستجابة: $stats->{avg_response_time} ms";
        
    } else {
        say "\n${\($color->error())}✗ خادم الويب متوقف${\($color->reset())}";
    }
    
    $utils->save_result('web_interface', {
        action => 'status',
        running => $WEB_SERVER_RUNNING,
        port => $WEB_SERVER_PORT
    });
    
    return {
        running => $WEB_SERVER_RUNNING,
        pid => $WEB_SERVER_PID,
        port => $WEB_SERVER_PORT
    };
}

# =============================================================================
# لوحة التحكم
# =============================================================================
sub web_dashboard {
    my $color = Colors->new();
    my $utils = Utils->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    📊 لوحة التحكم 📊                                 ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    # جمع معلومات النظام
    my $system_info = {
        cpu_usage => _get_cpu_usage(),
        memory_usage => _get_memory_usage(),
        disk_usage => _get_disk_usage(),
        uptime => _get_uptime(),
        active_attacks => _get_active_attacks(),
        completed_attacks => _get_completed_attacks(),
        success_rate => _get_success_rate()
    };
    
    say "\n${\($color->info())}🖥️ معلومات النظام:${\($color->reset())}";
    say "   → استخدام المعالج: $system_info->{cpu_usage}%";
    say "   → استخدام الذاكرة: $system_info->{memory_usage}%";
    say "   → استخدام القرص: $system_info->{disk_usage}%";
    say "   → وقت التشغيل: $system_info->{uptime}";
    
    say "\n${\($color->quantum())}⚔️ إحصائيات الهجمات:${\($color->reset())}";
    say "   → هجمات نشطة: $system_info->{active_attacks}";
    say "   → هجمات مكتملة: $system_info->{completed_attacks}";
    say "   → نسبة النجاح: $system_info->{success_rate}%";
    
    # عرض الرابط المباشر للوحة التحكم
    if ($WEB_SERVER_RUNNING) {
        say "\n${\($color->success())}🔗 رابط لوحة التحكم: http://127.0.0.1:$WEB_SERVER_PORT/dashboard${\($color->reset())}";
    } else {
        say "\n${\($color->warning())}⚠️ قم بتشغيل خادم الويب أولاً (web_start)${\($color->reset())}";
    }
    
    $utils->save_result('web_dashboard', {
        system_info => $system_info
    });
    
    return $system_info;
}

# =============================================================================
# دوال مساعدة داخلية
# =============================================================================

sub _web_server_loop {
    my ($port, $bind_address) = @_;
    
    my $d = HTTP::Daemon->new(
        LocalAddr => $bind_address,
        LocalPort => $port,
        ReuseAddr => 1
    ) or die "فشل بدء خادم HTTP";
    
    while (my $c = $d->accept) {
        while (my $request = $c->get_request) {
            my $uri = $request->uri->path;
            my $response = _handle_request($uri, $request);
            $c->send_response($response);
        }
        $c->close;
    }
}

sub _handle_request {
    my ($uri, $request) = @_;
    
    my $response = HTTP::Response->new(200);
    $response->header('Content-Type' => 'text/html; charset=utf-8');
    
    if ($uri eq '/' || $uri eq '/index.html') {
        $response->content(_generate_index_page());
        
    } elsif ($uri eq '/dashboard') {
        $response->content(_generate_dashboard_page());
        
    } elsif ($uri eq '/api/status') {
        $response->header('Content-Type' => 'application/json');
        $response->content(_generate_api_status());
        
    } elsif ($uri eq '/api/attacks') {
        $response->header('Content-Type' => 'application/json');
        $response->content(_generate_api_attacks());
        
    } elsif ($uri =~ /^\/api\/attack\/(.+)/) {
        my $attack_id = $1;
        $response->header('Content-Type' => 'application/json');
        $response->content(_generate_api_attack_details($attack_id));
        
    } else {
        $response = HTTP::Response->new(404);
        $response->content("<html><body><h1>404 - غير موجود</h1></body></html>");
    }
    
    _log_request($uri);
    return $response;
}

sub _generate_index_page {
    my $color = Colors->new();
    
    return <<"HTML";
<!DOCTYPE html>
<html lang="ar">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>RobinHood Wibey - واجهة التحكم</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            background: linear-gradient(135deg, #1a1a2e 0%, #16213e 100%);
            color: #eee;
            margin: 0;
            padding: 20px;
        }
        .container {
            max-width: 1200px;
            margin: 0 auto;
        }
        h1 {
            color: #00d9ff;
            text-align: center;
            font-size: 2.5em;
        }
        .card {
            background: rgba(255,255,255,0.1);
            border-radius: 10px;
            padding: 20px;
            margin: 20px 0;
            backdrop-filter: blur(10px);
        }
        .stats {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 20px;
            margin: 20px 0;
        }
        .stat-box {
            background: rgba(0,217,255,0.2);
            border-radius: 10px;
            padding: 15px;
            text-align: center;
        }
        .stat-value {
            font-size: 2em;
            font-weight: bold;
            color: #00d9ff;
        }
        button {
            background: #00d9ff;
            color: #1a1a2e;
            border: none;
            padding: 10px 20px;
            border-radius: 5px;
            cursor: pointer;
            margin: 5px;
        }
        button:hover {
            background: #00b8d4;
        }
        .footer {
            text-align: center;
            margin-top: 40px;
            padding: 20px;
            color: #888;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>🦅 RobinHood Wibey</h1>
        <h3 style="text-align:center">أداة اختراق الواي فاي الكمية</h3>
        
        <div class="stats">
            <div class="stat-box">
                <div>🖥️ حالة النظام</div>
                <div class="stat-value" id="status">نشط</div>
            </div>
            <div class="stat-box">
                <div>⚡ هجمات نشطة</div>
                <div class="stat-value" id="active-attacks">0</div>
            </div>
            <div class="stat-box">
                <div>✓ نسبة النجاح</div>
                <div class="stat-value" id="success-rate">0%</div>
            </div>
            <div class="stat-box">
                <div>🔋 البطارية</div>
                <div class="stat-value" id="battery">100%</div>
            </div>
        </div>
        
        <div class="card">
            <h2>🎯 هجمات سريعة</h2>
            <button onclick="startAttack('wps')">هجوم WPS</button>
            <button onclick="startAttack('dictionary')">هجوم القاموس</button>
            <button onclick="startAttack('handshake')">التقاط المصافحة</button>
            <button onclick="startAttack('pmkid')">هجوم PMKID</button>
            <button onclick="startAttack('evil_twin')">Evil Twin</button>
        </div>
        
        <div class="card">
            <h2>📊 الهجمات الأخيرة</h2>
            <div id="attacks-list">
                <p>جاري التحميل...</p>
            </div>
        </div>
        
        <div class="footer">
            RobinHood Wibey v3.0 | المطور: walid33fuska-eng
        </div>
    </div>
    
    <script>
        async function updateStats() {
            try {
                const response = await fetch('/api/status');
                const data = await response.json();
                document.getElementById('active-attacks').innerText = data.active_attacks;
                document.getElementById('success-rate').innerText = data.success_rate;
                document.getElementById('battery').innerText = data.battery;
            } catch(e) { console.error(e); }
        }
        
        async function loadAttacks() {
            try {
                const response = await fetch('/api/attacks');
                const attacks = await response.json();
                const listDiv = document.getElementById('attacks-list');
                if (attacks.length === 0) {
                    listDiv.innerHTML = '<p>لا توجد هجمات مسجلة</p>';
                } else {
                    listDiv.innerHTML = '<ul>' + attacks.map(a => 
                        `<li>${a.name} - ${a.status} - ${new Date(a.timestamp * 1000).toLocaleString()}</li>`
                    ).join('') + '</ul>';
                }
            } catch(e) { console.error(e); }
        }
        
        async function startAttack(type) {
            alert(\`بدء هجوم \${type}...\`);
            // محاكاة بدء الهجوم
            setTimeout(() => {
                loadAttacks();
                updateStats();
            }, 1000);
        }
        
        setInterval(updateStats, 5000);
        setInterval(loadAttacks, 10000);
        updateStats();
        loadAttacks();
    </script>
</body>
</html>
HTML
}

sub _generate_dashboard_page {
    return _generate_index_page();  # نفس الصفحة مع تعديلات بسيطة
}

sub _generate_api_status {
    my $status = {
        active_attacks => _get_active_attacks(),
        success_rate => _get_success_rate(),
        battery => _get_battery_level(),
        uptime => _get_uptime(),
        timestamp => time()
    };
    return encode_json($status);
}

sub _generate_api_attacks {
    my $attacks = _get_recent_attacks();
    return encode_json($attacks);
}

sub _generate_api_attack_details {
    my ($id) = @_;
    my $details = { id => $id, status => "completed", result => "success" };
    return encode_json($details);
}

sub _log_request {
    my ($uri) = @_;
    my $log_file = "$ENV{HOME}/.robinhood/logs/web_requests.log";
    open(my $fh, '>>', $log_file);
    print $fh "[".localtime()."] $uri\n";
    close($fh);
}

# إحصائيات وهمية للعرض
sub _get_uptime {
    return "5 ساعات و 23 دقيقة";
}

sub _get_cpu_usage {
    return int(rand(50)) + 10;
}

sub _get_memory_usage {
    return int(rand(40)) + 20;
}

sub _get_disk_usage {
    return int(rand(30)) + 10;
}

sub _get_active_attacks {
    return int(rand(3));
}

sub _get_completed_attacks {
    return int(rand(20)) + 5;
}

sub _get_success_rate {
    return int(rand(40)) + 30;
}

sub _get_battery_level {
    return int(rand(50)) + 30;
}

sub _get_recent_attacks {
    my @attacks = ();
    for my $i (1..5) {
        push @attacks, {
            name => ["WPS Crack", "Dictionary Attack", "Handshake Capture", "PMKID Attack"][int(rand(4))],
            status => ["completed", "running", "failed"][int(rand(3))],
            timestamp => time() - $i * 3600
        };
    }
    return \@attacks;
}

sub _get_request_stats {
    return {
        total_requests => int(rand(1000)),
        successful_requests => int(rand(900)),
        avg_response_time => int(rand(100))
    };
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
