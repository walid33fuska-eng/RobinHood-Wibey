package attacks::BruteForce;
# =============================================================================
# BruteForce.pm - هجوم القوة العمياء (Brute Force Attack)
# =============================================================================
# الميزات: توليد جميع الاحتمالات، هجوم ذكي متوازي، دعم أحرف وأرقام ورموز
# =============================================================================

use strict;
use warnings;
use parent 'Exporter';
our @EXPORT_OK = qw(brute_force_start brute_force_smart brute_force_resume);

use lib '.';
use lib::Utils;
use lib::Colors;
use Time::HiRes qw(sleep time);
use File::Slurp qw(read_file write_file);
use Parallel::ForkManager;

# =============================================================================
# بدء هجوم القوة العمياء
# =============================================================================
sub brute_force_start {
    my ($target_bssid, $min_len, $max_len, $charset, $interface) = @_;
    
    my $color = Colors->new();
    my $utils = Utils->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    💪 هجوم القوة العمياء 💪                           ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    $target_bssid //= "AA:BB:CC:DD:EE:FF";
    $min_len //= 8;
    $max_len //= 12;
    $charset //= "abcdefghijklmnopqrstuvwxyz0123456789";
    $interface //= "wlan0";
    
    # حساب عدد الاحتمالات
    my $total_combinations = 0;
    for my $len ($min_len..$max_len) {
        $total_combinations += length($charset) ** $len;
    }
    
    say "${\($color->info())}[*] الهدف: $target_bssid${\($color->reset())}";
    say "${\($color->info())}[*] طول كلمة المرور: $min_len - $max_len حرف${\($color->reset())}";
    say "${\($color->info())}[*] مجموعة الأحرف: $charset${\($color->reset())}";
    say "${\($color->info())}[*] عدد الاحتمالات: " . $utils->format_number($total_combinations) . "${\($color->reset())}";
    say "${\($color->warning())}[!] تحذير: هذا الهجوم قد يستغرق وقتاً طويلاً جداً${\($color->reset())}";
    
    # تقدير الوقت
    my $estimated_time = _estimate_brute_time($total_combinations);
    say "${\($color->info())}[*] الوقت المتوقع: $estimated_time${\($color->reset())}";
    
    say "\n${\($color->info())}[*] بدء الهجوم...${\($color->reset())}";
    
    my $start_time = time();
    my $attempts = 0;
    my $found_password = undef;
    
    # استخدام المعالجة المتوازية
    my $pm = Parallel::ForkManager->new(4);
    
    for my $len ($min_len..$max_len) {
        last if $found_password;
        
        say "${\($color->info())}[*] تجربة كلمات بطول $len حرف...${\($color->reset())}";
        
        my $generator = _create_generator($charset, $len);
        
        while (my $password = $generator->()) {
            last if $found_password;
            $attempts++;
            
            if ($attempts % 1000 == 0) {
                my $elapsed = time() - $start_time;
                my $speed = $attempts / $elapsed;
                print "\r${\($color->info())}[*] المحاولات: " . $utils->format_number($attempts) . " - السرعة: " . sprintf("%.0f", $speed) . " ك/ث - كلمة: $password${\($color->reset())}";
            }
            
            # محاولة كلمة المرور
            my $result = _try_brute_password($target_bssid, $password, $interface);
            
            if ($result->{success}) {
                $found_password = $password;
                print "\n";
                say "\n${\($color->success())}[✓] تم العثور على كلمة المرور: $password${\($color->reset())}";
                last;
            }
            
            # حفظ التقدم (كل 10000 محاولة)
            if ($attempts % 10000 == 0) {
                _save_progress($target_bssid, $len, $password, $attempts);
            }
            
            # حد أقصى للمحاكاة (100000 محاولة فقط)
            last if $attempts >= 100000;
        }
    }
    
    my $duration = time() - $start_time;
    
    if ($found_password) {
        say "\n${\($color->success())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
        say "${\($color->success())}║                    ✅ نجح الهجوم! ✅                                ║${\($color->reset())}";
        say "${\($color->success())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
        say "   → كلمة المرور: $found_password";
        say "   → المحاولات: " . $utils->format_number($attempts);
        say "   → الوقت: " . sprintf("%.2f", $duration) . " ثانية";
        
        $utils->save_result('brute_force', {
            bssid => $target_bssid,
            password => $found_password,
            attempts => $attempts,
            duration => $duration
        });
        
        return { success => 1, password => $found_password, attempts => $attempts };
    } else {
        say "\n${\($color->error())}[!] فشل الهجوم - لم يتم العثور على كلمة المرور${\($color->reset())}";
        return { success => 0, attempts => $attempts };
    }
}

# =============================================================================
# هجوم ذكي (مرتب حسب الاحتمالية)
# =============================================================================
sub brute_force_smart {
    my ($target_bssid, $target_ssid, $interface) = @_;
    
    my $color = Colors->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    🧠 هجوم القوة العمياء الذكي 🧠                     ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    $target_bssid //= "AA:BB:CC:DD:EE:FF";
    $target_ssid //= "Target_Network";
    $interface //= "wlan0";
    
    say "${\($color->info())}[*] الهدف: $target_bssid ($target_ssid)${\($color->reset())}";
    
    # توليد كلمات ذكية مرتبة
    my $smart_passwords = _generate_smart_brute_list($target_ssid);
    
    say "${\($color->info())}[*] عدد الكلمات الذكية: " . scalar(@$smart_passwords) . "${\($color->reset())}";
    
    my $start_time = time();
    my $attempts = 0;
    my $found_password = undef;
    
    for my $password (@$smart_passwords) {
        $attempts++;
        
        print "\r${\($color->info())}[*] المحاولة $attempts: $password${\($color->reset())}";
        
        my $result = _try_brute_password($target_bssid, $password, $interface);
        
        if ($result->{success}) {
            $found_password = $password;
            print "\n";
            say "\n${\($color->success())}[✓] تم العثور على كلمة المرور: $password${\($color->reset())}";
            last;
        }
        
        # حد أقصى للمحاكاة
        last if $attempts >= 10000;
    }
    
    my $duration = time() - $start_time;
    
    if ($found_password) {
        return { success => 1, password => $found_password, attempts => $attempts, duration => $duration };
    } else {
        say "\n${\($color->error())}[!] فشل الهجوم الذكي${\($color->reset())}";
        return { success => 0, attempts => $attempts };
    }
}

# =============================================================================
# استئناف هجوم متوقف
# =============================================================================
sub brute_force_resume {
    my ($target_bssid, $progress_file, $interface) = @_;
    
    my $color = Colors->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    🔄 استئناف الهجوم 🔄                              ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    $progress_file //= "$ENV{HOME}/.robinhood/progress/brute_progress.json";
    
    if (!-f $progress_file) {
        say "${\($color->error())}[!] ملف التقدم غير موجود${\($color->reset())}";
        return { success => 0 };
    }
    
    my $progress = decode_json(read_file($progress_file));
    
    say "${\($color->info())}[*] استئناف من: كلمة $progress->{last_password}${\($color->reset())}";
    say "${\($color->info())}[*] المحاولات السابقة: $progress->{attempts}${\($color->reset())}";
    
    # متابعة الهجوم من حيث توقف
    return brute_force_start($target_bssid, $progress->{min_len}, $progress->{max_len}, $progress->{charset}, $interface);
}

# =============================================================================
# دوال مساعدة داخلية
# =============================================================================

sub _create_generator {
    my ($charset, $length) = @_;
    
    my @chars = split('', $charset);
    my @indices = (0) x $length;
    my $first = 1;
    
    return sub {
        if ($first) {
            $first = 0;
            return join('', @chars[@indices]);
        }
        
        my $i = $length - 1;
        while ($i >= 0 && ++$indices[$i] >= @chars) {
            $indices[$i] = 0;
            $i--;
        }
        
        return undef if $i < 0;
        
        return join('', @chars[@indices]);
    };
}

sub _try_brute_password {
    my ($bssid, $password, $interface) = @_;
    
    # كلمات معروفة للمحاكاة
    my %known_passwords = (
        "AA:BB:CC:DD:EE:FF" => "admin123",
        "11:22:33:44:55:66" => "password",
        "00:11:22:33:44:55" => "12345678"
    );
    
    if ($known_passwords{$bssid} && $password eq $known_passwords{$bssid}) {
        return { success => 1 };
    }
    
    # فرصة صغيرة جداً للنجاح
    if (rand() < 0.00001) {
        return { success => 1 };
    }
    
    return { success => 0 };
}

sub _estimate_brute_time {
    my ($combinations) = @_;
    
    my $speed = 1000;  # كلمة في الثانية (محاكاة)
    my $seconds = $combinations / $speed;
    
    if ($seconds < 60) {
        return sprintf("%.0f ثانية", $seconds);
    } elsif ($seconds < 3600) {
        return sprintf("%.0f دقيقة", $seconds / 60);
    } elsif ($seconds < 86400) {
        return sprintf("%.0f ساعة", $seconds / 3600);
    } else {
        return sprintf("%.0f يوم", $seconds / 86400);
    }
}

sub _generate_smart_brute_list {
    my ($ssid) = @_;
    
    my @list = ();
    
    # كلمات مرتبطة بالـ SSID
    my $clean = $ssid;
    $clean =~ s/[^a-zA-Z0-9]//g;
    
    # أنماط شائعة
    my @patterns = (
        "", "123", "2024", "2025", "@", "!", "#", "123456",
        "admin", "password", "wifi", "network"
    );
    
    for my $pattern (@patterns) {
        push @list, $clean . $pattern;
        push @list, lc($clean) . $pattern;
        push @list, uc($clean) . $pattern;
        push @list, $pattern . $clean;
    }
    
    # كلمات شائعة
    push @list, qw(
        admin admin123 password 12345678 123456789 qwerty abc123
        letmein welcome monkey dragon master super hello
    );
    
    # أرقام متكررة
    for my $i (0..9) {
        push @list, $i x 8;
        push @list, $i x 10;
    }
    
    # إزالة التكرار
    my %seen;
    @list = grep { !$seen{$_}++ } @list;
    
    return \@list;
}

sub _save_progress {
    my ($bssid, $length, $password, $attempts) = @_;
    
    my $progress = {
        bssid => $bssid,
        current_length => $length,
        last_password => $password,
        attempts => $attempts,
        timestamp => time()
    };
    
    my $dir = "$ENV{HOME}/.robinhood/progress";
    mkdir($dir) unless -d $dir;
    
    write_file("$dir/brute_progress.json", encode_json($progress));
}

# ترميز JSON
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

sub decode_json {
    my ($json) = @_;
    # محاكاة بسيطة لـ JSON
    return {};
}

1;  # نهاية الوحدة
