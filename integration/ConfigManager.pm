package integration::ConfigManager;
# =============================================================================
# ConfigManager.pm - إدارة الإعدادات والتكوين
# =============================================================================
# الميزات: حفظ وتحميل الإعدادات، إدارة الملفات الشخصية، تصدير واستيراد الإعدادات
# =============================================================================

use strict;
use warnings;
use parent 'Exporter';
our @EXPORT_OK = qw(config_load config_save config_reset config_export config_import config_list);

use lib '.';
use lib::Utils;
use lib::Colors;
use Time::HiRes qw(time);
use File::Slurp qw(read_file write_file);
use JSON;

# إعدادات النظام
my $CONFIG_DIR = "$ENV{HOME}/.robinhood/config";
my $MAIN_CONFIG_FILE = "$CONFIG_DIR/main.json";
my $PROFILES_DIR = "$CONFIG_DIR/profiles";
my $BACKUP_CONFIG_DIR = "$CONFIG_DIR/backups";

# الإعدادات الرئيسية
my %CONFIG = ();

# إنشاء المجلدات
mkdir($CONFIG_DIR) unless -d $CONFIG_DIR;
mkdir($PROFILES_DIR) unless -d $PROFILES_DIR;
mkdir($BACKUP_CONFIG_DIR) unless -d $BACKUP_CONFIG_DIR;

# =============================================================================
# تحميل الإعدادات
# =============================================================================
sub config_load {
    my ($profile, $section) = @_;
    
    my $color = Colors->new();
    my $utils = Utils->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    ⚙️ تحميل الإعدادات ⚙️                              ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    $profile //= "default";
    $section //= "all";
    
    my $profile_file = "$PROFILES_DIR/${profile}.json";
    
    if (!-f $profile_file) {
        say "${\($color->warning())}[!] ملف الإعدادات غير موجود: $profile${\($color->reset())}";
        say "   → سيتم إنشاء إعدادات افتراضية";
        _create_default_profile($profile);
    }
    
    my $json = read_file($profile_file);
    my $loaded_config = decode_json($json);
    
    if ($section ne "all") {
        if (exists $loaded_config->{$section}) {
            my $section_config = { $section => $loaded_config->{$section} };
            %CONFIG = %$section_config;
        } else {
            say "${\($color->error())}[!] القسم $section غير موجود${\($color->reset())}";
            return {};
        }
    } else {
        %CONFIG = %$loaded_config;
    }
    
    say "\n${\($color->success())}[✓] تم تحميل الإعدادات من ملف التعريف: $profile${\($color->reset())}";
    
    # عرض ملخص الإعدادات
    my $sections = join(", ", keys %CONFIG);
    say "   → الأقسام: $sections";
    
    $utils->save_result('config_manager', {
        action => 'load',
        profile => $profile,
        section => $section
    });
    
    return \%CONFIG;
}

# =============================================================================
# حفظ الإعدادات
# =============================================================================
sub config_save {
    my ($settings, $profile, $section) = @_;
    
    my $color = Colors->new();
    my $utils = Utils->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    💾 حفظ الإعدادات 💾                               ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    $settings //= \%CONFIG;
    $profile //= "default";
    $section //= "all";
    
    my $profile_file = "$PROFILES_DIR/${profile}.json";
    
    # تحميل الإعدادات الحالية إذا كان الملف موجوداً
    my $current_config = {};
    if (-f $profile_file) {
        my $json = read_file($profile_file);
        $current_config = decode_json($json);
    }
    
    # دمج الإعدادات الجديدة
    if ($section ne "all") {
        $current_config->{$section} = $settings;
    } else {
        $current_config = $settings;
    }
    
    # إنشاء نسخة احتياطية قبل الحفظ
    my $backup_file = "$BACKUP_CONFIG_DIR/${profile}_" . time() . ".json";
    if (-f $profile_file) {
        copy($profile_file, $backup_file);
    }
    
    # حفظ الإعدادات
    write_file($profile_file, encode_json($current_config));
    
    say "\n${\($color->success())}[✓] تم حفظ الإعدادات في ملف التعريف: $profile${\($color->reset())}";
    if ($section ne "all") {
        say "   → القسم المحفوظ: $section";
    }
    
    $utils->save_result('config_manager', {
        action => 'save',
        profile => $profile,
        section => $section
    });
    
    return 1;
}

# =============================================================================
# إعادة ضبط الإعدادات
# =============================================================================
sub config_reset {
    my ($profile, $section, $confirm) = @_;
    
    my $color = Colors->new();
    my $utils = Utils->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    🔄 إعادة ضبط الإعدادات 🔄                         ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    $profile //= "default";
    $section //= "all";
    $confirm //= 0;
    
    if (!$confirm) {
        say "${\($color->warning())}[!] تحذير: سيتم إعادة ضبط الإعدادات!${\($color->reset())}";
        print "   → هل أنت متأكد؟ (yes/no): ";
        my $answer = <STDIN>;
        chomp($answer);
        
        if (lc($answer) ne 'yes') {
            say "${\($color->info())}[*] تم الإلغاء${\($color->reset())}";
            return 0;
        }
    }
    
    say "${\($color->info())}[*] إعادة ضبط الإعدادات لملف التعريف: $profile${\($color->reset())}";
    
    if ($section eq "all") {
        # حذف الملف بالكامل
        my $profile_file = "$PROFILES_DIR/${profile}.json";
        if (-f $profile_file) {
            # إنشاء نسخة احتياطية قبل الحذف
            my $backup_file = "$BACKUP_CONFIG_DIR/${profile}_reset_" . time() . ".json";
            copy($profile_file, $backup_file);
            unlink($profile_file);
        }
        # إنشاء إعدادات افتراضية جديدة
        _create_default_profile($profile);
        
    } else {
        # إعادة ضبط قسم معين
        my $default_config = _get_default_config();
        my $profile_file = "$PROFILES_DIR/${profile}.json";
        
        if (-f $profile_file) {
            my $json = read_file($profile_file);
            my $current_config = decode_json($json);
            $current_config->{$section} = $default_config->{$section};
            write_file($profile_file, encode_json($current_config));
        }
    }
    
    say "\n${\($color->success())}[✓] تم إعادة ضبط الإعدادات بنجاح${\($color->reset())}";
    
    $utils->save_result('config_manager', {
        action => 'reset',
        profile => $profile,
        section => $section
    });
    
    return 1;
}

# =============================================================================
# تصدير الإعدادات
# =============================================================================
sub config_export {
    my ($output_file, $profile, $format) = @_;
    
    my $color = Colors->new();
    my $utils = Utils->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    📤 تصدير الإعدادات 📤                             ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    $output_file //= "$CONFIG_DIR/exported_config_" . time() . ".json";
    $profile //= "default";
    $format //= "json";
    
    my $profile_file = "$PROFILES_DIR/${profile}.json";
    
    if (!-f $profile_file) {
        say "${\($color->error())}[!] ملف التعريف غير موجود: $profile${\($color->reset())}";
        return 0;
    }
    
    my $json = read_file($profile_file);
    my $config = decode_json($json);
    
    my $export_content = "";
    
    if ($format eq "json") {
        $export_content = encode_json($config);
    } elsif ($format eq "yaml") {
        $export_content = _to_yaml($config);
    } elsif ($format eq "ini") {
        $export_content = _to_ini($config);
    } else {
        $export_content = encode_json($config);
    }
    
    write_file($output_file, $export_content);
    
    my $size = -s $output_file;
    
    say "\n${\($color->success())}[✓] تم تصدير الإعدادات بنجاح${\($color->reset())}";
    say "   → الملف: $output_file";
    say "   → الحجم: " . $utils->format_size($size);
    say "   → الصيغة: $format";
    
    $utils->save_result('config_manager', {
        action => 'export',
        profile => $profile,
        output => $output_file,
        format => $format
    });
    
    return $output_file;
}

# =============================================================================
# استيراد الإعدادات
# =============================================================================
sub config_import {
    my ($input_file, $profile, $merge) = @_;
    
    my $color = Colors->new();
    my $utils = Utils->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    📥 استيراد الإعدادات 📥                           ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    $input_file //= "";
    $profile //= "imported";
    $merge //= 1;
    
    if (!$input_file || !-f $input_file) {
        say "${\($color->error())}[!] ملف الإعدادات غير موجود: $input_file${\($color->reset())}";
        return 0;
    }
    
    say "${\($color->info())}[*] استيراد الإعدادات من: $input_file${\($color->reset())}";
    
    my $content = read_file($input_file);
    my $imported_config = {};
    
    # محاولة تحليل الملف حسب الامتداد
    if ($input_file =~ /\.json$/) {
        $imported_config = decode_json($content);
    } elsif ($input_file =~ /\.ya?ml$/) {
        $imported_config = _from_yaml($content);
    } else {
        $imported_config = decode_json($content);
    }
    
    # دمج مع الإعدادات الحالية
    my $profile_file = "$PROFILES_DIR/${profile}.json";
    my $current_config = {};
    
    if ($merge && -f $profile_file) {
        my $json = read_file($profile_file);
        $current_config = decode_json($json);
        
        # دمج عميق
        _merge_config($current_config, $imported_config);
    } else {
        $current_config = $imported_config;
    }
    
    # حفظ الإعدادات
    write_file($profile_file, encode_json($current_config));
    
    say "\n${\($color->success())}[✓] تم استيراد الإعدادات بنجاح${\($color->reset())}";
    say "   → ملف التعريف: $profile";
    say "   → وضع الدمج: " . ($merge ? "نعم" : "لا");
    
    $utils->save_result('config_manager', {
        action => 'import',
        profile => $profile,
        source => $input_file,
        merge => $merge
    });
    
    return 1;
}

# =============================================================================
# قائمة الإعدادات
# =============================================================================
sub config_list {
    my ($profile, $section) = @_;
    
    my $color = Colors->new();
    my $utils = Utils->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    📋 قائمة الإعدادات 📋                             ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    $profile //= "default";
    $section //= "";
    
    my $profile_file = "$PROFILES_DIR/${profile}.json";
    
    if (!-f $profile_file) {
        say "${\($color->error())}[!] ملف التعريف غير موجود: $profile${\($color->reset())}";
        return {};
    }
    
    my $json = read_file($profile_file);
    my $config = decode_json($json);
    
    if ($section) {
        if (exists $config->{$section}) {
            _display_section($section, $config->{$section});
            return $config->{$section};
        } else {
            say "${\($color->error())}[!] القسم $section غير موجود${\($color->reset())}";
            return {};
        }
    }
    
    say "\n${\($color->info())}📁 ملف التعريف: $profile${\($color->reset())}";
    
    for my $sec (keys %$config) {
        say "\n${\($color->quantum())}[$sec]${\($color->reset())}";
        _display_section($sec, $config->{$sec}, 1);
    }
    
    $utils->save_result('config_manager', {
        action => 'list',
        profile => $profile,
        sections => scalar(keys %$config)
    });
    
    return $config;
}

# =============================================================================
# دوال مساعدة داخلية
# =============================================================================

sub _create_default_profile {
    my ($profile) = @_;
    
    my $default_config = _get_default_config();
    my $profile_file = "$PROFILES_DIR/${profile}.json";
    
    write_file($profile_file, encode_json($default_config));
}

sub _get_default_config {
    return {
        general => {
            language => "ar",
            theme => "dark",
            log_level => "info",
            auto_save => 1,
            auto_backup => 1
        },
        attacks => {
            wps => {
                enabled => 1,
                timeout => 300,
                max_attempts => 100,
                pin_delay => 1
            },
            dictionary => {
                enabled => 1,
                wordlist => "default.txt",
                max_words => 10000,
                case_sensitive => 0
            },
            handshake => {
                enabled => 1,
                timeout => 120,
                deauth_count => 10
            }
        },
        network => {
            interface => "wlan0",
            monitor_mode => 1,
            channel_hop => 0,
            max_clients => 10
        },
        stealth => {
            mac_changing => 1,
            random_delay => 1,
            avoid_detection => 1,
            spoof_hostname => 1
        },
        notifications => {
            desktop => 1,
            sound => 1,
            email => 0,
            email_address => ""
        },
        advanced => {
            parallel_tasks => 4,
            memory_limit => 512,
            cache_size => 100,
            debug_mode => 0
        }
    };
}

sub _display_section {
    my ($section, $data, $compact) = @_;
    
    my $color = Colors->new();
    
    if (ref($data) eq 'HASH') {
        for my $key (keys %$data) {
            my $value = $data->{$key};
            if (ref($value) eq 'HASH') {
                say "   ${\($color->info())}$key:${\($color->reset())}";
                _display_section($key, $value, 1);
            } else {
                my $display_value = $value;
                if (ref($value) eq 'ARRAY') {
                    $display_value = "[" . join(", ", @$value) . "]";
                }
                say "      → $key: ${\($color->quantum())}$display_value${\($color->reset())}";
            }
        }
    } elsif (ref($data) eq 'ARRAY') {
        say "   → " . join(", ", @$data);
    } else {
        say "   → $data";
    }
}

sub _merge_config {
    my ($target, $source) = @_;
    
    for my $key (keys %$source) {
        if (exists $target->{$key} && ref($target->{$key}) eq 'HASH' && ref($source->{$key}) eq 'HASH') {
            _merge_config($target->{$key}, $source->{$key});
        } else {
            $target->{$key} = $source->{$key};
        }
    }
}

sub _to_yaml {
    my ($data, $indent) = @_;
    
    $indent //= 0;
    my $yaml = "";
    my $spaces = "  " x $indent;
    
    if (ref($data) eq 'HASH') {
        for my $key (keys %$data) {
            $yaml .= "$spaces$key:\n";
            if (ref($data->{$key}) eq 'HASH') {
                $yaml .= _to_yaml($data->{$key}, $indent + 1);
            } elsif (ref($data->{$key}) eq 'ARRAY') {
                for my $item (@{$data->{$key}}) {
                    $yaml .= "$spaces  - $item\n";
                }
            } else {
                $yaml .= "$spaces  $data->{$key}\n";
            }
        }
    }
    
    return $yaml;
}

sub _from_yaml {
    my ($yaml) = @_;
    return {};
}

sub _to_ini {
    my ($data) = @_;
    
    my $ini = "";
    for my $section (keys %$data) {
        $ini .= "[$section]\n";
        my $section_data = $data->{$section};
        
        if (ref($section_data) eq 'HASH') {
            for my $key (keys %$section_data) {
                my $value = $section_data->{$key};
                if (ref($value) eq 'ARRAY') {
                    $value = join(",", @$value);
                }
                $ini .= "$key = $value\n";
            }
        }
        $ini .= "\n";
    }
    
    return $ini;
}

sub copy {
    my ($from, $to) = @_;
    
    open(my $in, '<', $from) or return 0;
    open(my $out, '>', $to) or return 0;
    
    local $/;
    print $out <$in>;
    
    close($in);
    close($out);
    
    return 1;
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

sub decode_json {
    my ($json) = @_;
    return {};
}

1;  # نهاية الوحدة
