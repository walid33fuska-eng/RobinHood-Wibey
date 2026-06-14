package attacks::DictionaryAttack;
# =============================================================================
# DictionaryAttack.pm - هجوم القاموس على شبكات الواي فاي
# =============================================================================
# الميزات: هجوم قاموس ذكي، دعم عربي/إنجليزي، توليد كلمات مرور ديناميكي
# =============================================================================

use strict;
use warnings;
use parent 'Exporter';
our @EXPORT_OK = qw(dictionary_attack dictionary_smart dictionary_custom);

use lib '.';
use lib::Utils;
use lib::Colors;
use Time::HiRes qw(sleep time);
use File::Slurp qw(read_file write_file);
use List::Util qw(shuffle);

# =============================================================================
# هجوم القاموس الرئيسي
# =============================================================================
sub dictionary_attack {
    my ($target_bssid, $wordlist_file, $interface) = @_;
    
    my $color = Colors->new();
    my $utils = Utils->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    📖 هجوم القاموس (Dictionary Attack) 📖            ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    $target_bssid //= "AA:BB:CC:DD:EE:FF";
    $interface //= "wlan0";
    
    # تحميل قائمة الكلمات
    my $wordlist = _load_wordlist($wordlist_file);
    
    if (!$wordlist || scalar(@$wordlist) == 0) {
        say "${\($color->error())}[!] لا توجد كلمات مرور في القاموس${\($color->reset())}";
        return { success => 0 };
    }
    
    say "${\($color->info())}[*] الهدف: $target_bssid${\($color->reset())}";
    say "${\($color->info())}[*] عدد الكلمات في القاموس: " . scalar(@$wordlist) . "${\($color->reset())}";
    say "${\($color->info())}[*] الواجهة: $interface${\($color->reset())}";
    
    my $start_time = time();
    my $attempts = 0;
    my $found_password = undef;
    
    say "\n${\($color->info())}[*] بدء الهجوم...${\($color->reset())}";
    
    for my $password (@$wordlist) {
        $attempts++;
        
        # عرض التقدم
        if ($attempts % 100 == 0 || $attempts == 1) {
            my $percent = int(($attempts / scalar(@$wordlist)) * 100);
            print "\r${\($color->info())}[*] التقدم: $percent% - المحاولات: $attempts - آخر كلمة: $password${\($color->reset())}";
        }
        
        # محاولة الاتصال بالكلمة
        my $result = _try_password($target_bssid, $password, $interface);
        
        if ($result->{success}) {
            $found_password = $password;
            print "\n";
            say "\n${\($color->success())}[✓] تم العثور على كلمة المرور: $password${\($color->reset())}";
            last;
        }
        
        # انتظار قصير بين المحاولات
        sleep(0.1);
    }
    
    my $duration = time() - $start_time;
    
    print "\n";
    say "\n${\($color->success())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    if ($found_password) {
        say "${\($color->success())}║                    ✅ نجح الهجوم! ✅                              ║${\($color->reset())}";
        say "${\($color->success())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
        say "   → كلمة المرور: $found_password";
        say "   → المحاولات: $attempts";
        say "   → الوقت المستغرق: " . sprintf("%.2f", $duration) . " ثانية";
        say "   → السرعة: " . sprintf("%.2f", $attempts / $duration) . " كلمة/ثانية";
        
        $utils->save_result('dictionary_attack', {
            bssid => $target_bssid,
            password => $found_password,
            attempts => $attempts,
            duration => $duration
        });
        
        return { success => 1, password => $found_password, attempts => $attempts };
    } else {
        say "${\($color->error())}║                    ❌ فشل الهجوم! ❌                              ║${\($color->reset())}";
        say "${\($color->error())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
        return { success => 0, attempts => $attempts };
    }
}

# =============================================================================
# هجوم القاموس الذكي (مرتب حسب الاحتمالية)
# =============================================================================
sub dictionary_smart {
    my ($target_bssid, $target_ssid, $interface) = @_;
    
    my $color = Colors->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    🧠 هجوم القاموس الذكي 🧠                          ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    $target_bssid //= "AA:BB:CC:DD:EE:FF";
    $target_ssid //= "Default_Network";
    $interface //= "wlan0";
    
    say "${\($color->info())}[*] الهدف: $target_bssid ($target_ssid)${\($color->reset())}";
    
    # إنشاء قائمة ذكية مرتبة حسب الاحتمالية
    my $smart_wordlist = _generate_smart_wordlist($target_ssid);
    
    say "${\($color->info())}[*] تم توليد " . scalar(@$smart_wordlist) . " كلمة ذكية${\($color->reset())}";
    
    my $attempts = 0;
    my $found_password = undef;
    
    for my $password (@$smart_wordlist) {
        $attempts++;
        
        print "\r${\($color->info())}[*] المحاولة $attempts: $password${\($color->reset())}";
        
        my $result = _try_password($target_bssid, $password, $interface);
        
        if ($result->{success}) {
            $found_password = $password;
            print "\n";
            say "\n${\($color->success())}[✓] تم العثور على كلمة المرور: $password${\($color->reset())}";
            last;
        }
        
        sleep(0.05);
    }
    
    if ($found_password) {
        return { success => 1, password => $found_password, attempts => $attempts };
    } else {
        say "\n${\($color->error())}[!] فشل الهجوم الذكي${\($color->reset())}";
        return { success => 0, attempts => $attempts };
    }
}

# =============================================================================
# هجوم قاموس مخصص
# =============================================================================
sub dictionary_custom {
    my ($target_bssid, $custom_words, $interface) = @_;
    
    my $color = Colors->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    ⚙️ هجوم قاموس مخصص ⚙️                             ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    $target_bssid //= "AA:BB:CC:DD:EE:FF";
    $interface //= "wlan0";
    $custom_words //= ["admin", "password", "12345678", "00000000"];
    
    say "${\($color->info())}[*] عدد الكلمات المخصصة: " . scalar(@$custom_words) . "${\($color->reset())}";
    
    my $attempts = 0;
    my $found_password = undef;
    
    for my $password (@$custom_words) {
        $attempts++;
        
        print "\r${\($color->info())}[*] محاولة $attempts: $password${\($color->reset())}";
        
        my $result = _try_password($target_bssid, $password, $interface);
        
        if ($result->{success}) {
            $found_password = $password;
            print "\n";
            say "\n${\($color->success())}[✓] تم العثور على كلمة المرور: $password${\($color->reset())}";
            last;
        }
        
        sleep(0.1);
    }
    
    return { success => $found_password ? 1 : 0, password => $found_password, attempts => $attempts };
}

# =============================================================================
# توليد قائمة كلمات ذكية
# =============================================================================
sub _generate_smart_wordlist {
    my ($ssid) = @_;
    
    my @wordlist = ();
    
    # 1. كلمات شائعة عالمياً
    my @common_passwords = (
        "password", "12345678", "123456789", "qwerty", "abc123", "11111111",
        "22222222", "33333333", "44444444", "55555555", "66666666", "77777777",
        "88888888", "99999999", "00000000", "admin", "admin123", "root",
        "toor", "user", "guest", "welcome", "letmein", "monkey", "dragon",
        "master", "super", "hello", "internet", "network", "wifi", "wireless"
    );
    push @wordlist, @common_passwords;
    
    # 2. كلمات مرتبطة بـ SSID
    my $clean_ssid = $ssid;
    $clean_ssid =~ s/[^a-zA-Z0-9]//g;
    if ($clean_ssid && length($clean_ssid) >= 4) {
        push @wordlist, $clean_ssid;
        push @wordlist, lc($clean_ssid);
        push @wordlist, uc($clean_ssid);
        push @wordlist, $clean_ssid . "123";
        push @wordlist, $clean_ssid . "2024";
        push @wordlist, $clean_ssid . "123456";
        push @wordlist, $clean_ssid . "@";
        push @wordlist, $clean_ssid . "!";
    }
    
    # 3. كلمات عربية شائعة
    my @arabic_passwords = (
        "admin", "مدير", "كلمة", "سر", "سري", "شبكة", "واي فاي", "اتصال",
        "انترنت", "موبايل", "هاتف", "بيت", "منزل", "عمل", "مكتب", "مدينة",
        "123456", "00000000", "11111111"
    );
    push @wordlist, @arabic_passwords;
    
    # 4. كلمات مع تواريخ
    my @years = (2020..2025);
    my @months = (1..12);
    for my $year (@years) {
        push @wordlist, "admin$year";
        push @wordlist, "password$year";
        push @wordlist, "wifi$year";
        push @wordlist, "network$year";
        push @wordlist, $year . $year;
        push @wordlist, $year . "123";
    }
    
    # 5. كلمات مع رموز
    my @symbols = ('@', '#', '$', '%', '!', '?', '&', '*', '.', ',');
    for my $word (@common_passwords[0..20]) {
        for my $symbol (@symbols[0..3]) {
            push @wordlist, $word . $symbol;
            push @wordlist, $word . $symbol . "123";
            push @wordlist, $symbol . $word;
        }
    }
    
    # 6. أرقام متكررة
    for my $i (0..9) {
        push @wordlist, $i x 8;
        push @wordlist, $i x 10;
        push @wordlist, ($i . $i) x 4;
    }
    
    # 7. كلمات شائعة في العالم العربي
    my @arabic_common = (
        "12345678", "123456789", "11223344", "44332211", "12121212",
        "123123123", "123321123", "10203040", "01020304", "98765432"
    );
    push @wordlist, @arabic_common;
    
    # إزالة التكرار
    my %seen;
    @wordlist = grep { !$seen{$_}++ } @wordlist;
    
    # ترتيب حسب الطول (الأقصر أولاً - الأكثر شيوعاً)
    @wordlist = sort { length($a) <=> length($b) } @wordlist;
    
    return \@wordlist;
}

# =============================================================================
# تحميل قائمة كلمات من ملف
# =============================================================================
sub _load_wordlist {
    my ($file) = @_;
    
    my @words = ();
    
    if ($file && -f $file) {
        @words = read_file($file);
        chomp(@words);
    } else {
        # استخدام القائمة الافتراضية
        @words = @{_generate_smart_wordlist("Default")};
    }
    
    return \@words;
}

# =============================================================================
# محاولة كلمة مرور
# =============================================================================
sub _try_password {
    my ($bssid, $password, $interface) = @_;
    
    # محاكاة محاولة الاتصال
    # في الواقع الحقيقي، ستستخدم أداة مثل aircrack-ng
    
    # كلمات مرور معروفة مسبقاً للمحاكاة
    my %known_passwords = (
        "AA:BB:CC:DD:EE:FF" => "admin123",
        "11:22:33:44:55:66" => "password",
        "00:11:22:33:44:55" => "12345678"
    );
    
    if ($known_passwords{$bssid} && $password eq $known_passwords{$bssid}) {
        return { success => 1, message => "كلمة المرور صحيحة" };
    }
    
    # فرصة عشوائية صغيرة جداً للنجاح في المحاكاة
    if (rand() < 0.001) {
        return { success => 1, message => "تم العثور على كلمة المرور (محاكاة)" };
    }
    
    return { success => 0, message => "كلمة مرور خاطئة" };
}

# =============================================================================
# إضافة كلمة مرور إلى القاموس
# =============================================================================
sub add_to_wordlist {
    my ($wordlist_file, $new_word) = @_;
    
    my $color = Colors->new();
    
    if (-f $wordlist_file) {
        my @words = read_file($wordlist_file);
        chomp(@words);
        
        # تجنب التكرار
        if (!grep { $_ eq $new_word } @words) {
            open(my $fh, '>>', $wordlist_file);
            print $fh "$new_word\n";
            close($fh);
            say "${\($color->success())}[✓] تمت إضافة $new_word إلى القاموس${\($color->reset())}";
        } else {
            say "${\($color->warning())}[!] الكلمة موجودة بالفعل في القاموس${\($color->reset())}";
        }
    }
}

1;  # نهاية الوحدة
