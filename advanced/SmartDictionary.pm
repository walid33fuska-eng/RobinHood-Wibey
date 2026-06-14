package advanced::SmartDictionary;
# =============================================================================
# SmartDictionary.pm - قاموس ذكي لتوليد كلمات المرور
# =============================================================================
# الميزات: توليد كلمات مرور ذكية بناءً على السياق، دعم عربي/إنجليزي، تحليل أنماط
# =============================================================================

use strict;
use warnings;
use parent 'Exporter';
our @EXPORT_OK = qw(smart_dict_generate smart_dict_customize smart_dict_merge smart_dict_optimize);

use lib '.';
use lib::Utils;
use lib::Colors;
use Time::HiRes qw(time);
use File::Slurp qw(read_file write_file);
use List::Util qw(shuffle uniq);

# قوائم الكلمات الأساسية
my @COMMON_PASSWORDS = (
    "password", "123456", "12345678", "qwerty", "abc123", "monkey", "letmein",
    "dragon", "baseball", "master", "super", "hello", "welcome", "admin",
    "user", "guest", "root", "toor", "12345", "123456789", "123123", "111111",
    "222222", "333333", "444444", "555555", "666666", "777777", "888888", "999999"
);

my @ARABIC_COMMON = (
    "admin", "مدير", "مرحباً", "شبكة", "واي فاي", "انترنت", "اتصال", "موبايل",
    "هاتف", "بيت", "منزل", "عمل", "مكتب", "سري", "كلمة", "سر", "123456", "00000000"
);

my @YEARS = (2010..2025);
my @SYMBOLS = ('@', '#', '$', '%', '!', '?', '&', '*', '.', ',', '_', '-');

# =============================================================================
# توليد قاموس ذكي
# =============================================================================
sub smart_dict_generate {
    my ($context, $count, $min_len, $max_len) = @_;
    
    my $color = Colors->new();
    my $utils = Utils->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    🧠 توليد قاموس ذكي 🧠                              ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    $context //= {
        ssid => "Default_Network",
        bssid => "AA:BB:CC:DD:EE:FF",
        company => "Unknown",
        region => "AE",
        keywords => []
    };
    $count //= 10000;
    $min_len //= 8;
    $max_len //= 20;
    
    say "${\($color->info())}[*] السياق المستخدم للتوليد:${\($color->reset())}";
    say "   → SSID: $context->{ssid}";
    say "   → BSSID: $context->{bssid}";
    say "   → المنطقة: $context->{region}";
    say "   → عدد الكلمات المستهدف: $count";
    say "   → طول الكلمات: $min_len - $max_len حرف";
    
    my @wordlist = ();
    
    # 1. كلمات أساسية
    say "\n${\($color->info())}[1/6] إضافة كلمات أساسية...${\($color->reset())}";
    push @wordlist, @COMMON_PASSWORDS;
    push @wordlist, @ARABIC_COMMON;
    
    # 2. كلمات مرتبطة بـ SSID
    say "${\($color->info())}[2/6] توليد كلمات مرتبطة بـ SSID...${\($color->reset())}";
    my $ssid_words = _generate_ssid_words($context->{ssid});
    push @wordlist, @$ssid_words;
    
    # 3. كلمات مرتبطة بـ BSSID
    say "${\($color->info())}[3/6] توليد كلمات مرتبطة بـ BSSID...${\($color->reset())}";
    my $bssid_words = _generate_bssid_words($context->{bssid});
    push @wordlist, @$bssid_words;
    
    # 4. كلمات مع تواريخ
    say "${\($color->info())}[4/6] إضافة كلمات مع تواريخ...${\($color->reset())}";
    my $date_words = _generate_date_words();
    push @wordlist, @$date_words;
    
    # 5. كلمات مع رموز
    say "${\($color->info())}[5/6] إضافة كلمات مع رموز...${\($color->reset())}";
    my $symbol_words = _generate_symbol_words(\@wordlist);
    push @wordlist, @$symbol_words;
    
    # 6. كلمات حسب المنطقة
    say "${\($color->info())}[6/6] إضافة كلمات حسب المنطقة...${\($color->reset())}";
    my $region_words = _generate_region_words($context->{region});
    push @wordlist, @$region_words;
    
    # إضافة كلمات مخصصة من المستخدم
    if ($context->{keywords} && scalar(@{$context->{keywords}}) > 0) {
        say "${\($color->info())}[*] إضافة كلمات مخصصة...${\($color->reset())}";
        push @wordlist, @{$context->{keywords}};
    }
    
    # معالجة القائمة
    say "\n${\($color->info())}[*] معالجة القائمة...${\($color->reset())}";
    
    # إزالة التكرار
    my %seen;
    @wordlist = grep { !$seen{$_}++ } @wordlist;
    
    # فلترة حسب الطول
    @wordlist = grep { length($_) >= $min_len && length($_) <= $max_len } @wordlist;
    
    # ترتيب حسب الاحتمالية
    @wordlist = _sort_by_probability(@wordlist);
    
    # أخذ العدد المطلوب
    if (scalar(@wordlist) > $count) {
        @wordlist = @wordlist[0..$count-1];
    }
    
    # حفظ القاموس
    my $dict_file = "$ENV{HOME}/.robinhood/wordlists/smart_dict_" . time() . ".txt";
    write_file($dict_file, join("\n", @wordlist));
    
    # عرض الإحصائيات
    say "\n${\($color->success())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->success())}║                    ✅ تم توليد القاموس الذكي! ✅                      ║${\($color->reset())}";
    say "${\($color->success())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    say "   → عدد الكلمات: " . scalar(@wordlist);
    say "   → حجم الملف: " . $utils->format_size(-s $dict_file);
    say "   → المسار: $dict_file";
    
    $utils->save_result('smart_dictionary', {
        context => $context,
        words_count => scalar(@wordlist),
        file => $dict_file
    });
    
    return \@wordlist;
}

# =============================================================================
# تخصيص القاموس
# =============================================================================
sub smart_dict_customize {
    my ($base_dict, $custom_rules) = @_;
    
    my $color = Colors->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    ⚙️ تخصيص القاموس ⚙️                                ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    $base_dict //= [];
    $custom_rules //= {
        add_suffix => [],
        add_prefix => [],
        replace => {},
        to_upper => 0,
        to_lower => 0,
        capitalize => 0,
        leet_speak => 0
    };
    
    my @customized = @$base_dict;
    
    # تطبيق القواعد
    if ($custom_rules->{to_upper}) {
        say "${\($color->info())}[*] تحويل إلى uppercase...${\($color->reset())}";
        push @customized, map { uc($_) } @$base_dict;
    }
    
    if ($custom_rules->{to_lower}) {
        say "${\($color->info())}[*] تحويل إلى lowercase...${\($color->reset())}";
        push @customized, map { lc($_) } @$base_dict;
    }
    
    if ($custom_rules->{capitalize}) {
        say "${\($color->info())}[*] تحويل أول حرف到大写...${\($color->reset())}";
        push @customized, map { ucfirst(lc($_)) } @$base_dict;
    }
    
    if ($custom_rules->{leet_speak}) {
        say "${\($color->info())}[*] تطبيق Leet Speak...${\($color->reset())}";
        push @customized, map { _leet_convert($_) } @$base_dict;
    }
    
    if ($custom_rules->{add_prefix} && scalar(@{$custom_rules->{add_prefix}}) > 0) {
        say "${\($color->info())}[*] إضافة بادئات...${\($color->reset())}";
        for my $prefix (@{$custom_rules->{add_prefix}}) {
            push @customized, map { $prefix . $_ } @$base_dict;
        }
    }
    
    if ($custom_rules->{add_suffix} && scalar(@{$custom_rules->{add_suffix}}) > 0) {
        say "${\($color->info())}[*] إضافة لواحق...${\($color->reset())}";
        for my $suffix (@{$custom_rules->{add_suffix}}) {
            push @customized, map { $_ . $suffix } @$base_dict;
        }
    }
    
    if ($custom_rules->{replace} && keys %{$custom_rules->{replace}}) {
        say "${\($color->info())}[*] استبدال أحرف...${\($color->reset())}";
        for my $word (@$base_dict) {
            my $new_word = $word;
            for my $old (keys %{$custom_rules->{replace}}) {
                my $new = $custom_rules->{replace}{$old};
                $new_word =~ s/$old/$new/g;
            }
            push @customized, $new_word if $new_word ne $word;
        }
    }
    
    # إزالة التكرار
    my %seen;
    @customized = grep { !$seen{$_}++ } @customized;
    
    say "\n${\($color->success())}[✓] تم تخصيص القاموس: " . scalar(@customized) . " كلمة";
    
    return \@customized;
}

# =============================================================================
# دمج قواميس متعددة
# =============================================================================
sub smart_dict_merge {
    my ($dictionaries, $remove_duplicates) = @_;
    
    my $color = Colors->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    🔗 دمج القواميس 🔗                                 ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    $dictionaries //= [];
    $remove_duplicates //= 1;
    
    my @merged = ();
    
    for my $dict (@$dictionaries) {
        if (ref($dict) eq 'ARRAY') {
            push @merged, @$dict;
        } elsif (-f $dict) {
            my @words = read_file($dict);
            chomp(@words);
            push @merged, @words;
        }
    }
    
    if ($remove_duplicates) {
        my %seen;
        @merged = grep { !$seen{$_}++ } @merged;
    }
    
    say "\n${\($color->success())}[✓] تم دمج القواميس: " . scalar(@merged) . " كلمة";
    
    return \@merged;
}

# =============================================================================
# تحسين القاموس
# =============================================================================
sub smart_dict_optimize {
    my ($dictionary, $target_count) = @_;
    
    my $color = Colors->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    ⚡ تحسين القاموس ⚡                                ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    $dictionary //= [];
    $target_count //= scalar(@$dictionary);
    
    my $original_count = scalar(@$dictionary);
    
    # ترتيب حسب الاحتمالية
    my @optimized = _sort_by_probability(@$dictionary);
    
    # أخذ العدد المطلوب
    if (scalar(@optimized) > $target_count) {
        @optimized = @optimized[0..$target_count-1];
    }
    
    say "\n${\($color->success())}[✓] تم تحسين القاموس: $original_count → " . scalar(@optimized) . " كلمة";
    say "   → نسبة التحسين: " . sprintf("%.1f", (1 - scalar(@optimized)/$original_count)*100) . "%";
    
    return \@optimized;
}

# =============================================================================
# دوال مساعدة داخلية
# =============================================================================

sub _generate_ssid_words {
    my ($ssid) = @_;
    
    my @words = ();
    my $clean = $ssid;
    $clean =~ s/[^a-zA-Z0-9]//g;
    
    if ($clean && length($clean) >= 3) {
        push @words, $clean;
        push @words, lc($clean);
        push @words, uc($clean);
        push @words, ucfirst(lc($clean));
        
        # إضافة أرقام
        for my $year (@YEARS[0..4]) {
            push @words, $clean . $year;
            push @words, $year . $clean;
            push @words, $clean . substr($year, -2);
        }
        
        # إضافة رموز
        for my $symbol (@SYMBOLS[0..4]) {
            push @words, $clean . $symbol;
            push @words, $symbol . $clean;
        }
    }
    
    return \@words;
}

sub _generate_bssid_words {
    my ($bssid) = @_;
    
    my @words = ();
    my $clean = $bssid;
    $clean =~ s/://g;
    
    if ($clean) {
        push @words, $clean;
        push @words, substr($clean, -6);
        push @words, substr($clean, 0, 6);
        
        # تحويل إلى أرقام
        my $dec = hex($clean);
        push @words, substr($dec, -8);
    }
    
    return \@words;
}

sub _generate_date_words {
    my @words = ();
    
    for my $year (@YEARS) {
        push @words, $year;
        push @words, "20" . substr($year, -2);
        push @words, substr($year, -2);
        
        for my $month (1..12) {
            my $month_str = sprintf("%02d", $month);
            push @words, $year . $month_str;
            push @words, $month_str . $year;
            push @words, $month_str . substr($year, -2);
        }
    }
    
    return \@words;
}

sub _generate_symbol_words {
    my ($base_words) = @_;
    
    my @words = ();
    
    for my $word (@$base_words[0..min(100, scalar(@$base_words)-1)]) {
        for my $symbol (@SYMBOLS) {
            push @words, $word . $symbol;
            push @words, $symbol . $word;
            push @words, $word . $symbol . "123";
            push @words, $word . $symbol . $symbol;
        }
    }
    
    return \@words;
}

sub _generate_region_words {
    my ($region) = @_;
    
    my %region_words = (
        'AE' => ['dubai', 'abudhabi', 'sharjah', 'uae', 'emirates', 'dxb', 'auh'],
        'SA' => ['riyadh', 'jeddah', 'mecca', 'medina', 'ksa', 'saudi'],
        'EG' => ['cairo', 'alex', 'egypt', 'giza', 'cairo123'],
        'KW' => ['kuwait', 'kwt', 'q8'],
        'QA' => ['doha', 'qatar', 'doh']
    );
    
    my @words = @{$region_words{$region} || []};
    
    # إضافة أرقام
    my @extended = ();
    for my $word (@words) {
        push @extended, $word;
        for my $year (@YEARS[0..3]) {
            push @extended, $word . $year;
            push @extended, $year . $word;
        }
    }
    
    return \@extended;
}

sub _sort_by_probability {
    my @words = @_;
    
    # حساب درجة الاحتمالية لكل كلمة
    my @scored = map {
        my $score = 0;
        
        # كلمات أقصر أكثر شيوعاً
        $score += (20 - length($_)) if length($_) < 20;
        
        # كلمات فيها أرقام فقط
        if ($_ =~ /^\d+$/) {
            $score += 30;
        }
        
        # كلمات شائعة جداً
        my @very_common = qw(password 123456 admin root toor guest user);
        if (grep { lc($_) eq lc($_) } @very_common) {
            $score += 50;
        }
        
        # كلمات تحتوي على تكرارات
        if ($_ =~ /(.)\1{3,}/) {
            $score += 20;
        }
        
        { word => $_, score => $score }
    } @words;
    
    # ترتيب حسب الدرجة تنازلياً
    my @sorted = sort { $b->{score} <=> $a->{score} } @scored;
    
    return map { $_->{word} } @sorted;
}

sub _leet_convert {
    my ($word) = @_;
    
    my %leet_map = (
        'a' => '4', 'e' => '3', 'i' => '1', 'o' => '0', 's' => '5',
        't' => '7', 'b' => '8', 'g' => '9', 'z' => '2'
    );
    
    my $leet = $word;
    for my $char (keys %leet_map) {
        $leet =~ s/$char/$leet_map{$char}/g;
        $leet =~ s/uc($char)/uc($leet_map{$char})/ge;
    }
    
    return $leet;
}

sub min {
    my ($a, $b) = @_;
    return $a < $b ? $a : $b;
}

1;  # نهاية الوحدة
