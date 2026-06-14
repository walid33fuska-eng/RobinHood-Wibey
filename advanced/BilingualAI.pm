package advanced::BilingualAI;
# =============================================================================
# BilingualAI.pm - الذكاء الاصطناعي ثنائي اللغة (عربي/إنجليزي)
# =============================================================================
# الميزات: معالجة اللغة العربية والإنجليزية، ترجمة فورية، توليد كلمات مرور ثنائية اللغة
# =============================================================================

use strict;
use warnings;
use parent 'Exporter';
our @EXPORT_OK = qw(bilingual_process bilingual_translate bilingual_generate_passwords bilingual_analyze);

use lib '.';
use lib::Utils;
use lib::Colors;
use Time::HiRes qw(time);
use File::Slurp qw(write_file);
use List::Util qw(shuffle uniq);

# قواعد البيانات اللغوية
my %ARABIC_TO_ENGLISH = (
    'مدير' => 'admin',
    'كلمة' => 'password',
    'سر' => 'secret',
    'شبكة' => 'network',
    'واي فاي' => 'wifi',
    'انترنت' => 'internet',
    'اتصال' => 'connection',
    'موبايل' => 'mobile',
    'هاتف' => 'phone',
    'بيت' => 'home',
    'منزل' => 'house',
    'عمل' => 'work',
    'مكتب' => 'office',
    'مدينة' => 'city',
    'مستخدم' => 'user',
    'ضيف' => 'guest',
    'جذر' => 'root',
    'مرحباً' => 'hello',
    'اهلاً' => 'welcome',
    'عالم' => 'world',
    'تقنية' => 'tech',
    'حاسوب' => 'computer',
    'انظمة' => 'systems',
    'امن' => 'security',
    'اختراق' => 'hacking',
    'تشفير' => 'encryption'
);

my %ENGLISH_TO_ARABIC = (
    'admin' => 'مدير',
    'password' => 'كلمة',
    'secret' => 'سر',
    'network' => 'شبكة',
    'wifi' => 'واي فاي',
    'internet' => 'انترنت',
    'connection' => 'اتصال',
    'mobile' => 'موبايل',
    'phone' => 'هاتف',
    'home' => 'بيت',
    'work' => 'عمل',
    'user' => 'مستخدم',
    'guest' => 'ضيف',
    'root' => 'جذر',
    'hello' => 'مرحباً',
    'welcome' => 'اهلاً'
);

# =============================================================================
# معالجة النص ثنائي اللغة
# =============================================================================
sub bilingual_process {
    my ($text, $mode) = @_;
    
    my $color = Colors->new();
    my $utils = Utils->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    🌐 المعالجة ثنائية اللغة 🌐                        ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    $text //= "";
    $mode //= "detect";
    
    say "${\($color->info())}[*] النص المدخل: $text${\($color->reset())}";
    say "${\($color->info())}[*] الوضع: $mode${\($color->reset())}";
    
    # تحديد اللغة
    my $language = _detect_language($text);
    say "${\($color->info())}[*] اللغة المكتشفة: $language${\($color->reset())}";
    
    my $result = {
        original => $text,
        language => $language,
        processed => {},
        suggestions => []
    };
    
    # معالجة حسب اللغة
    if ($language eq 'arabic') {
        $result->{processed}{transliteration} = _arabic_to_latin($text);
        $result->{processed}{english_translation} = _translate_arabic_to_english($text);
        $result->{processed}{normalized} = _normalize_arabic($text);
        
        # توليد كلمات مرور مقترحة
        my $passwords = _generate_from_arabic($text);
        push @{$result->{suggestions}}, @$passwords;
        
    } elsif ($language eq 'english') {
        $result->{processed}{transliteration} = $text;
        $result->{processed}{arabic_translation} = _translate_english_to_arabic($text);
        $result->{processed}{normalized} = lc($text);
        
        # توليد كلمات مرور مقترحة
        my $passwords = _generate_from_english($text);
        push @{$result->{suggestions}}, @$passwords;
        
    } else {
        $result->{processed}{normalized} = $text;
    }
    
    # عرض النتائج
    say "\n${\($color->success())}📝 نتائج المعالجة:${\($color->reset())}";
    say "   → اللغة الأصلية: $result->{language}";
    say "   → النص المعالج: $result->{processed}{normalized}";
    
    if ($result->{processed}{english_translation}) {
        say "   → الترجمة للإنجليزية: $result->{processed}{english_translation}";
    }
    if ($result->{processed}{arabic_translation}) {
        say "   → الترجمة للعربية: $result->{processed}{arabic_translation}";
    }
    
    if (scalar(@{$result->{suggestions}}) > 0) {
        say "\n${\($color->quantum())}🔑 كلمات مرور مقترحة:${\($color->reset())}";
        for my $i (0..4) {
            last unless $result->{suggestions}[$i];
            say "   → $result->{suggestions}[$i]";
        }
    }
    
    $utils->save_result('bilingual_ai', {
        input => $text,
        language => $language,
        suggestions_count => scalar(@{$result->{suggestions}})
    });
    
    return $result;
}

# =============================================================================
# ترجمة فورية
# =============================================================================
sub bilingual_translate {
    my ($text, $direction) = @_;
    
    my $color = Colors->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    🔄 الترجمة الفورية 🔄                              ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    $text //= "";
    $direction //= "auto";
    
    say "${\($color->info())}[*] النص: $text${\($color->reset())}";
    
    my $translation = "";
    
    if ($direction eq "auto") {
        my $lang = _detect_language($text);
        if ($lang eq 'arabic') {
            $translation = _translate_arabic_to_english($text);
        } else {
            $translation = _translate_english_to_arabic($text);
        }
    } elsif ($direction eq "ar2en") {
        $translation = _translate_arabic_to_english($text);
    } elsif ($direction eq "en2ar") {
        $translation = _translate_english_to_arabic($text);
    }
    
    say "\n${\($color->success())}📖 الترجمة:${\($color->reset())}";
    say "   → $text";
    say "   → ↓";
    say "   → $translation";
    
    return $translation;
}

# =============================================================================
# توليد كلمات مرور ثنائية اللغة
# =============================================================================
sub bilingual_generate_passwords {
    my ($base_words, $count) = @_;
    
    my $color = Colors->new();
    my $utils = Utils->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    🔑 كلمات مرور ثنائية اللغة 🔑                      ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    $base_words //= [];
    $count //= 100;
    
    my @passwords = ();
    
    # كلمات عربية
    my @arabic_words = keys %ARABIC_TO_ENGLISH;
    
    # كلمات إنجليزية
    my @english_words = keys %ENGLISH_TO_ARABIC;
    
    # 1. كلمات عربية محولة إلى إنجليزية
    for my $word (@arabic_words) {
        push @passwords, $word;
        push @passwords, $ARABIC_TO_ENGLISH{$word};
        push @passwords, $word . $ARABIC_TO_ENGLISH{$word};
        push @passwords, $ARABIC_TO_ENGLISH{$word} . $word;
    }
    
    # 2. كلمات إنجليزية محولة إلى عربية
    for my $word (@english_words) {
        push @passwords, $word;
        push @passwords, $ENGLISH_TO_ARABIC{$word};
        push @passwords, $word . $ENGLISH_TO_ARABIC{$word};
        push @passwords, $ENGLISH_TO_ARABIC{$word} . $word;
    }
    
    # 3. إضافة أرقام ورموز
    my @symbols = ('123', '1234', '2024', '@', '#', '!');
    my @extended = ();
    for my $pwd (@passwords[0..min(49, scalar(@passwords)-1)]) {
        for my $sym (@symbols) {
            push @extended, $pwd . $sym;
            push @extended, $sym . $pwd;
        }
    }
    push @passwords, @extended;
    
    # إزالة التكرار
    my %seen;
    @passwords = grep { !$seen{$_}++ } @passwords;
    
    # أخذ العدد المطلوب
    if (scalar(@passwords) > $count) {
        @passwords = @passwords[0..$count-1];
    }
    
    # عرض العينة
    say "\n${\($color->success())}📝 عينة من كلمات المرور المولدة:${\($color->reset())}";
    for my $i (0..9) {
        last unless $passwords[$i];
        say "   → $passwords[$i]";
    }
    
    say "\n${\($color->success())}[✓] تم توليد " . scalar(@passwords) . " كلمة مرور ثنائية اللغة${\($color->reset())}";
    
    $utils->save_result('bilingual_passwords', {
        count => scalar(@passwords),
        sample => [@passwords[0..9]]
    });
    
    return \@passwords;
}

# =============================================================================
# تحليل النص ثنائي اللغة
# =============================================================================
sub bilingual_analyze {
    my ($text) = @_;
    
    my $color = Colors->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    📊 تحليل النص ثنائي اللغة 📊                       ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    $text //= "";
    
    my $analysis = {
        text => $text,
        length => length($text),
        words => [],
        arabic_words => 0,
        english_words => 0,
        mixed => 0,
        suggestions => []
    };
    
    # تقسيم النص إلى كلمات
    my @words = split(/[\s,.;:!?]+/, $text);
    $analysis->{words} = \@words;
    
    for my $word (@words) {
        my $lang = _detect_language($word);
        if ($lang eq 'arabic') {
            $analysis->{arabic_words}++;
        } elsif ($lang eq 'english') {
            $analysis->{english_words}++;
        } else {
            $analysis->{mixed}++;
        }
    }
    
    say "\n${\($color->info())}📈 نتائج التحليل:${\($color->reset())}";
    say "   → طول النص: $analysis->{length} حرف";
    say "   → عدد الكلمات: " . scalar(@words);
    say "   → كلمات عربية: $analysis->{arabic_words}";
    say "   → كلمات إنجليزية: $analysis->{english_words}";
    
    # اقتراحات لتوليد كلمات مرور
    my @important_words = grep { length($_) > 3 } @words;
    if (scalar(@important_words) > 0) {
        say "\n${\($color->quantum())}💡 كلمات مهمة يمكن استخدامها لكلمات المرور:${\($color->reset())}";
        for my $word (@important_words[0..4]) {
            say "   → $word";
        }
    }
    
    return $analysis;
}

# =============================================================================
# دوال مساعدة داخلية
# =============================================================================

sub _detect_language {
    my ($text) = @_;
    
    # الكشف عن الأحرف العربية
    if ($text =~ /[\x{0600}-\x{06FF}\x{0750}-\x{077F}\x{08A0}-\x{08FF}\x{FB50}-\x{FDFF}\x{FE70}-\x{FEFF}]/) {
        return 'arabic';
    }
    
    # الكشف عن الأحرف الإنجليزية
    if ($text =~ /^[a-zA-Z0-9\s\.,;:!?]+$/) {
        return 'english';
    }
    
    return 'mixed';
}

sub _arabic_to_latin {
    my ($text) = @_;
    
    my %arabic_to_latin = (
        'ا' => 'a', 'ب' => 'b', 'ت' => 't', 'ث' => 'th', 'ج' => 'j',
        'ح' => 'h', 'خ' => 'kh', 'د' => 'd', 'ذ' => 'dh', 'ر' => 'r',
        'ز' => 'z', 'س' => 's', 'ش' => 'sh', 'ص' => 's', 'ض' => 'd',
        'ط' => 't', 'ظ' => 'z', 'ع' => 'a', 'غ' => 'gh', 'ف' => 'f',
        'ق' => 'q', 'ك' => 'k', 'ل' => 'l', 'م' => 'm', 'ن' => 'n',
        'ه' => 'h', 'و' => 'w', 'ي' => 'y', 'ة' => 'h', 'ى' => 'a'
    );
    
    my $result = $text;
    for my $arabic (keys %arabic_to_latin) {
        $result =~ s/$arabic/$arabic_to_latin{$arabic}/g;
    }
    
    return $result;
}

sub _normalize_arabic {
    my ($text) = @_;
    
    # توحيد الأحرف العربية
    $text =~ s/أ|إ|آ/ا/g;
    $text =~ s/ة/ه/g;
    $text =~ s/ى/ي/g;
    
    return $text;
}

sub _translate_arabic_to_english {
    my ($text) = @_;
    
    my $translation = $text;
    for my $arabic (keys %ARABIC_TO_ENGLISH) {
        $translation =~ s/$arabic/$ARABIC_TO_ENGLISH{$arabic}/g;
    }
    
    return $translation;
}

sub _translate_english_to_arabic {
    my ($text) = @_;
    
    my $translation = lc($text);
    for my $english (keys %ENGLISH_TO_ARABIC) {
        $translation =~ s/\b$english\b/$ENGLISH_TO_ARABIC{$english}/g;
    }
    
    return $translation;
}

sub _generate_from_arabic {
    my ($text) = @_;
    
    my @passwords = ();
    
    # النص الأصلي
    push @passwords, $text;
    push @passwords, _normalize_arabic($text);
    push @passwords, _arabic_to_latin($text);
    
    # ترجمة إلى إنجليزية
    my $english = _translate_arabic_to_english($text);
    push @passwords, $english;
    
    # خلط عربي وإنجليزي
    push @passwords, $text . $english;
    push @passwords, $english . $text;
    
    return \@passwords;
}

sub _generate_from_english {
    my ($text) = @_;
    
    my @passwords = ();
    
    # النص الأصلي
    push @passwords, $text;
    push @passwords, lc($text);
    push @passwords, uc($text);
    push @passwords, ucfirst($text);
    
    # ترجمة إلى عربية
    my $arabic = _translate_english_to_arabic($text);
    push @passwords, $arabic;
    
    # خلط إنجليزي وعربي
    push @passwords, $text . $arabic;
    push @passwords, $arabic . $text;
    
    return \@passwords;
}

sub min {
    my ($a, $b) = @_;
    return $a < $b ? $a : $b;
}

1;  # نهاية الوحدة
