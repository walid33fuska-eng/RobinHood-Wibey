package attacks::HandshakeCapture;
# =============================================================================
# HandshakeCapture.pm - التقاط مصافحة WPA/WPA2
# =============================================================================
# الميزات: التقاط المصافحة، تحليل المصافحة، استخراج البيانات، حفظ بصيغة CAP/PCAP
# =============================================================================

use strict;
use warnings;
use parent 'Exporter';
our @EXPORT_OK = qw(capture_handshake analyze_handshake extract_keys save_capture);

use lib '.';
use lib::Utils;
use lib::Colors;
use Time::HiRes qw(sleep time);
use File::Slurp qw(read_file write_file);
use Digest::SHA qw(sha256);
use IO::Socket::INET;

# =============================================================================
# التقاط المصافحة
# =============================================================================
sub capture_handshake {
    my ($target_bssid, $target_channel, $interface, $timeout) = @_;
    
    my $color = Colors->new();
    my $utils = Utils->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    🤝 التقاط مصافحة WPA 🤝                           ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    $target_bssid //= "AA:BB:CC:DD:EE:FF";
    $target_channel //= 6;
    $interface //= "wlan0";
    $timeout //= 120;
    
    say "${\($color->info())}[*] الهدف: $target_bssid${\($color->reset())}";
    say "${\($color->info())}[*] القناة: $target_channel${\($color->reset())}";
    say "${\($color->info())}[*] الواجهة: $interface${\($color->reset())}";
    say "${\($color->info())}[*] المهلة: $timeout ثانية${\($color->reset())}";
    
    # ضبط الواجهة على القناة المستهدفة
    _set_channel($interface, $target_channel);
    
    # بدء التقاط الحزم
    say "\n${\($color->info())}[*] بدء التقاط المصافحة...${\($color->reset())}";
    
    my $start_time = time();
    my $handshake_captured = 0;
    my $packets = 0;
    my $handshake_data = undef;
    
    # إرسال حزم deauth لتحفيز إعادة المصافحة
    _send_deauth_packets($target_bssid, $interface);
    
    while ((time() - $start_time) < $timeout && !$handshake_captured) {
        # محاكاة التقاط الحزم
        $packets++;
        
        # عرض التقدم
        if ($packets % 10 == 0) {
            my $elapsed = time() - $start_time;
            print "\r${\($color->info())}[*] الوقت: $elapsed/$timeout ثانية - الحزم: $packets${\($color->reset())}";
        }
        
        # محاكاة اكتشاف المصافحة
        if (_is_handshake_captured()) {
            $handshake_captured = 1;
            $handshake_data = _extract_handshake_data($target_bssid);
            print "\n";
            say "\n${\($color->success())}[✓] تم التقاط المصافحة بنجاح!${\($color->reset())}";
        }
        
        sleep(0.1);
    }
    
    my $duration = time() - $start_time;
    
    if ($handshake_captured) {
        # حفظ المصافحة
        my $capture_file = _save_handshake($handshake_data);
        
        say "\n${\($color->success())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
        say "${\($color->success())}║                    ✅ تم التقاط المصافحة! ✅                         ║${\($color->reset())}";
        say "${\($color->success())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
        say "   → BSSID: $target_bssid";
        say "   → ملف الالتقاط: $capture_file";
        say "   → الوقت المستغرق: " . sprintf("%.2f", $duration) . " ثانية";
        say "   → عدد الحزم: $packets";
        
        # حفظ النتيجة
        $utils->save_result('handshake_capture', {
            bssid => $target_bssid,
            capture_file => $capture_file,
            duration => $duration,
            packets => $packets
        });
        
        return { success => 1, capture_file => $capture_file, handshake_data => $handshake_data };
    } else {
        say "\n${\($color->error())}[!] فشل التقاط المصافحة - انتهت المهلة${\($color->reset())}";
        return { success => 0, packets => $packets };
    }
}

# =============================================================================
# تحليل المصافحة
# =============================================================================
sub analyze_handshake {
    my ($capture_file) = @_;
    
    my $color = Colors->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    🔍 تحليل المصافحة 🔍                              ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    $capture_file //= "$ENV{HOME}/.robinhood/captures/handshake_latest.cap";
    
    if (!-f $capture_file) {
        say "${\($color->error())}[!] ملف الالتقاط غير موجود: $capture_file${\($color->reset())}";
        return { success => 0 };
    }
    
    say "${\($color->info())}[*] تحليل الملف: $capture_file${\($color->reset())}";
    
    # استخراج معلومات المصافحة
    my $analysis = {
        file => $capture_file,
        size => -s $capture_file,
        timestamp => time(),
        bssid => _extract_bssid_from_capture($capture_file),
        essid => _extract_essid_from_capture($capture_file),
        encryption_type => "WPA2-PSK",
        handshake_complete => 1,
        message_pairs => 4,  # M1-M2-M3-M4
        anonce => _generate_anonce(),
        snonce => _generate_snonce(),
        mic => _generate_mic(),
        key_version => 2,  # WPA2
        key_mgmt => "PSK",
        cipher => "CCMP"
    };
    
    # عرض التحليل
    say "\n${\($color->info())}📊 معلومات المصافحة:${\($color->reset())}";
    say "   → BSSID: $analysis->{bssid}";
    say "   → ESSID: $analysis->{essid}";
    say "   → نوع التشفير: $analysis->{encryption_type}";
    say "   → حالة المصافحة: " . ($analysis->{handshake_complete} ? "كاملة ✓" : "غير كاملة ✗");
    say "   → عدد الرسائل: $analysis->{message_pairs} (M1-M2-M3-M4)";
    say "   → ANonce: $analysis->{anonce}";
    say "   → SNounce: $analysis->{snonce}";
    say "   → MIC: $analysis->{mic}";
    
    # تقييم قوة المصافحة
    say "\n${\($color->quantum())}🎯 تقييم المصافحة:${\($color->reset())}";
    if ($analysis->{handshake_complete}) {
        say "   → ${\($color->success())}مصافحة كاملة - جاهزة للهجوم${\($color->reset())}";
        say "   → يمكن استخدامها مع aircrack-ng أو hashcat";
        say "   → القوة: ${\($color->success())}عالية${\($color->reset())}";
    } else {
        say "   → ${\($color->warning())}مصافحة غير كاملة - حاول مرة أخرى${\($color->reset())}";
    }
    
    # حفظ التحليل
    my $analysis_file = "$ENV{HOME}/.robinhood/logs/handshake_analysis.json";
    write_file($analysis_file, encode_json($analysis));
    
    return $analysis;
}

# =============================================================================
# استخراج المفاتيح من المصافحة
# =============================================================================
sub extract_keys {
    my ($capture_file, $password) = @_;
    
    my $color = Colors->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    🔑 استخراج المفاتيح 🔑                            ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    $capture_file //= "$ENV{HOME}/.robinhood/captures/handshake_latest.cap";
    $password //= undef;
    
    if ($password) {
        say "${\($color->info())}[*] التحقق من كلمة المرور: $password${\($color->reset())}";
        
        # محاكاة التحقق من كلمة المرور
        my $is_correct = _verify_password_against_handshake($capture_file, $password);
        
        if ($is_correct) {
            say "${\($color->success())}[✓] كلمة المرور صحيحة!${\($color->reset())}";
            
            # توليد المفاتيح
            my $keys = _generate_keys_from_password($password);
            
            say "\n${\($color->success())}🔐 المفاتيح المستخرجة:${\($color->reset())}";
            say "   → PMK (Pairwise Master Key): $keys->{pmk}";
            say "   → PTK (Pairwise Transient Key): $keys->{ptk}";
            say "   → MIC Key: $keys->{mic_key}";
            say "   → EAPOL Key: $keys->{eapol_key}";
            
            return { success => 1, keys => $keys };
        } else {
            say "${\($color->error())}[!] كلمة المرور غير صحيحة${\($color->reset())}";
            return { success => 0 };
        }
    } else {
        say "${\($color->info())}[*] لا توجد كلمة مرور للتحقق${\($color->reset())}";
        return { success => 0 };
    }
}

# =============================================================================
# حفظ ملف الالتقاط
# =============================================================================
sub save_capture {
    my ($handshake_data, $format) = @_;
    
    my $color = Colors->new();
    
    $format //= "cap";
    
    my $filename = "$ENV{HOME}/.robinhood/captures/handshake_" . time() . ".$format";
    
    # محاكاة حفظ الملف
    write_file($filename, "محاكاة بيانات المصافحة\n");
    
    say "${\($color->success())}[✓] تم حفظ الالتقاط في: $filename${\($color->reset())}";
    
    return $filename;
}

# =============================================================================
# دوال مساعدة داخلية
# =============================================================================

sub _set_channel {
    my ($interface, $channel) = @_;
    # محاكاة ضبط القناة
    return 1;
}

sub _send_deauth_packets {
    my ($bssid, $interface) = @_;
    # محاكاة إرسال حزم deauth لتحفيز إعادة المصافحة
    return 1;
}

sub _is_handshake_captured {
    # فرصة 20% للتقاط المصافحة في كل محاولة (محاكاة)
    return rand() < 0.2;
}

sub _extract_handshake_data {
    my ($bssid) = @_;
    
    return {
        bssid => $bssid,
        essid => "Target_Network",
        timestamp => time(),
        anonce => _generate_anonce(),
        snonce => _generate_snonce(),
        message1 => "M1_" . substr(sha256($bssid . "M1"), 0, 32),
        message2 => "M2_" . substr(sha256($bssid . "M2"), 0, 32),
        message3 => "M3_" . substr(sha256($bssid . "M3"), 0, 32),
        message4 => "M4_" . substr(sha256($bssid . "M4"), 0, 32)
    };
}

sub _save_handshake {
    my ($data) = @_;
    
    my $filename = "$ENV{HOME}/.robinhood/captures/handshake_" . time() . ".cap";
    write_file($filename, encode_json($data));
    
    # إنشاء رابط لأحدث ملف
    symlink($filename, "$ENV{HOME}/.robinhood/captures/handshake_latest.cap");
    
    return $filename;
}

sub _extract_bssid_from_capture {
    my ($file) = @_;
    # محاكاة استخراج BSSID
    return "AA:BB:CC:DD:EE:FF";
}

sub _extract_essid_from_capture {
    my ($file) = @_;
    # محاكاة استخراج ESSID
    return "Target_Network";
}

sub _generate_anonce {
    return substr(sha256(time() . rand() . "ANONCE"), 0, 32);
}

sub _generate_snonce {
    return substr(sha256(time() . rand() . "SNONCE"), 0, 32);
}

sub _generate_mic {
    return substr(sha256(time() . rand() . "MIC"), 0, 40);
}

sub _verify_password_against_handshake {
    my ($file, $password) = @_;
    
    # كلمات مرور معروفة للمحاكاة
    my %valid_passwords = (
        "AA:BB:CC:DD:EE:FF" => "admin123",
        "11:22:33:44:55:66" => "password"
    );
    
    my $bssid = _extract_bssid_from_capture($file);
    
    if ($valid_passwords{$bssid} && $password eq $valid_passwords{$bssid}) {
        return 1;
    }
    
    return 0;
}

sub _generate_keys_from_password {
    my ($password) = @_;
    
    return {
        pmk => substr(sha256($password . "PMK"), 0, 64),
        ptk => substr(sha256($password . "PTK"), 0, 64),
        mic_key => substr(sha256($password . "MIC"), 0, 32),
        eapol_key => substr(sha256($password . "EAPOL"), 0, 32)
    };
}

# ترميز JSON بسيط
sub encode_json {
    my ($data) = @_;
    
    if (ref($data) eq 'HASH') {
        my @pairs = ();
        for my $key (keys %$data) {
            my $value = $data->{$key};
            $value =~ s/"/\\"/g if !ref($value);
            push @pairs, qq{"$key":} . encode_json($value);
        }
        return "{" . join(",", @pairs) . "}";
    }
    elsif (ref($data) eq 'ARRAY') {
        my @items = map { encode_json($_) } @$data;
        return "[" . join(",", @items) . "]";
    }
    else {
        return qq{"$data"};
    }
}

1;  # نهاية الوحدة
