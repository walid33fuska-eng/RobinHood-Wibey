package integration::PluginSystem;
# =============================================================================
# PluginSystem.pm - نظام الإضافات والملحقات
# =============================================================================
# الميزات: تحميل الإضافات ديناميكياً، إدارة الإضافات، واجهة برمجة للإضافات
# =============================================================================

use strict;
use warnings;
use parent 'Exporter';
our @EXPORT_OK = qw(plugin_load plugin_unload plugin_list plugin_call plugin_install);

use lib '.';
use lib::Utils;
use lib::Colors;
use Time::HiRes qw(time);
use File::Slurp qw(read_file write_file);
use File::Find;
use JSON;

# إعدادات الإضافات
my $PLUGINS_DIR = "$ENV{HOME}/.robinhood/plugins";
my $PLUGINS_CONFIG_FILE = "$PLUGINS_DIR/plugins_config.json";
my $PLUGINS_CONFIG = {};
my %LOADED_PLUGINS = ();

# إنشاء مجلد الإضافات
mkdir($PLUGINS_DIR) unless -d $PLUGINS_DIR;

# تحميل إعدادات الإضافات
sub _load_plugins_config {
    if (-f $PLUGINS_CONFIG_FILE) {
        my $json = read_file($PLUGINS_CONFIG_FILE);
        eval { $PLUGINS_CONFIG = decode_json($json); };
    }
    
    if (!keys %$PLUGINS_CONFIG) {
        $PLUGINS_CONFIG = {
            enabled => 1,
            auto_load => 1,
            plugins => {},
            blacklist => [],
            max_plugins => 50
        };
    }
}

# حفظ إعدادات الإضافات
sub _save_plugins_config {
    write_file($PLUGINS_CONFIG_FILE, encode_json($PLUGINS_CONFIG));
}

# =============================================================================
# تحميل إضافة
# =============================================================================
sub plugin_load {
    my ($plugin_name, $plugin_path) = @_;
    
    my $color = Colors->new();
    my $utils = Utils->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    🔌 تحميل إضافة 🔌                                  ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    _load_plugins_config();
    
    $plugin_name //= "";
    $plugin_path //= "$PLUGINS_DIR/$plugin_name";
    
    if (!$plugin_name) {
        say "${\($color->error())}[!] لم يتم تحديد اسم الإضافة${\($color->reset())}";
        return 0;
    }
    
    if ($LOADED_PLUGINS{$plugin_name}) {
        say "${\($color->warning())}[!] الإضافة $plugin_name محملة بالفعل${\($color->reset())}";
        return 1;
    }
    
    say "${\($color->info())}[*] تحميل الإضافة: $plugin_name${\($color->reset())}";
    
    # البحث عن ملف الإضافة
    my $plugin_file = "$plugin_path/$plugin_name.pm";
    if (!-f $plugin_file) {
        $plugin_file = "$PLUGINS_DIR/$plugin_name.pm";
    }
    
    if (!-f $plugin_file) {
        say "${\($color->error())}[!] ملف الإضافة غير موجود: $plugin_name${\($color->reset())}";
        return 0;
    }
    
    # محاكاة تحميل الإضافة
    my $plugin_info = _load_plugin_file($plugin_file);
    
    if (!$plugin_info) {
        say "${\($color->error())}[!] فشل تحميل الإضافة${\($color->reset())}";
        return 0;
    }
    
    $LOADED_PLUGINS{$plugin_name} = $plugin_info;
    
    # تحديث الإعدادات
    $PLUGINS_CONFIG->{plugins}{$plugin_name} = {
        name => $plugin_name,
        version => $plugin_info->{version},
        author => $plugin_info->{author},
        enabled => 1,
        loaded_at => time(),
        path => $plugin_file
    };
    _save_plugins_config();
    
    say "\n${\($color->success())}[✓] تم تحميل الإضافة بنجاح${\($color->reset())}";
    say "   → الاسم: $plugin_name";
    say "   → الإصدار: $plugin_info->{version}";
    say "   → المؤلف: $plugin_info->{author}";
    say "   → الوصف: $plugin_info->{description}";
    
    $utils->save_result('plugin_system', {
        action => 'load',
        plugin => $plugin_name,
        version => $plugin_info->{version}
    });
    
    return 1;
}

# =============================================================================
# إلغاء تحميل إضافة
# =============================================================================
sub plugin_unload {
    my ($plugin_name) = @_;
    
    my $color = Colors->new();
    my $utils = Utils->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    🔌 إلغاء تحميل إضافة 🔌                            ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    _load_plugins_config();
    
    $plugin_name //= "";
    
    if (!$plugin_name) {
        say "${\($color->error())}[!] لم يتم تحديد اسم الإضافة${\($color->reset())}";
        return 0;
    }
    
    if (!$LOADED_PLUGINS{$plugin_name}) {
        say "${\($color->warning())}[!] الإضافة $plugin_name غير محملة${\($color->reset())}";
        return 0;
    }
    
    say "${\($color->info())}[*] إلغاء تحميل الإضافة: $plugin_name${\($color->reset())}";
    
    # استدعاء دالة الإلغاء إذا وجدت
    if ($LOADED_PLUGINS{$plugin_name}->{unload}) {
        eval { $LOADED_PLUGINS{$plugin_name}->{unload}->(); };
    }
    
    delete $LOADED_PLUGINS{$plugin_name};
    
    # تحديث الإعدادات
    $PLUGINS_CONFIG->{plugins}{$plugin_name}{enabled} = 0;
    _save_plugins_config();
    
    say "\n${\($color->success())}[✓] تم إلغاء تحميل الإضافة بنجاح${\($color->reset())}";
    
    $utils->save_result('plugin_system', {
        action => 'unload',
        plugin => $plugin_name
    });
    
    return 1;
}

# =============================================================================
# قائمة الإضافات
# =============================================================================
sub plugin_list {
    my ($show_details) = @_;
    
    my $color = Colors->new();
    my $utils = Utils->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    📋 قائمة الإضافات 📋                              ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    _load_plugins_config();
    
    $show_details //= 0;
    
    my @plugins = keys %LOADED_PLUGINS;
    my @available = _get_available_plugins();
    
    say "\n${\($color->success())}🔌 الإضافات المحملة:${\($color->reset())}";
    if (scalar(@plugins) == 0) {
        say "   → لا توجد إضافات محملة";
    } else {
        for my $plugin (@plugins) {
            my $info = $LOADED_PLUGINS{$plugin};
            say "   → ${\($color->quantum())}$plugin${\($color->reset())} v$info->{version}";
            if ($show_details) {
                say "      → المؤلف: $info->{author}";
                say "      → الوصف: $info->{description}";
                say "      → الدوال: " . join(", ", @{$info->{functions}});
            }
        }
    }
    
    if (scalar(@available) > 0) {
        say "\n${\($color->info())}📦 الإضافات المتاحة للتحميل:${\($color->reset())}";
        for my $plugin (@available) {
            say "   → $plugin";
        }
    }
    
    $utils->save_result('plugin_system', {
        action => 'list',
        loaded => scalar(@plugins),
        available => scalar(@available)
    });
    
    return {
        loaded => \@plugins,
        available => \@available
    };
}

# =============================================================================
# استدعاء دالة من إضافة
# =============================================================================
sub plugin_call {
    my ($plugin_name, $function, @args) = @_;
    
    my $color = Colors->new();
    my $utils = Utils->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    📞 استدعاء دالة من إضافة 📞                       ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    $plugin_name //= "";
    $function //= "";
    
    if (!$plugin_name || !$function) {
        say "${\($color->error())}[!] لم يتم تحديد الإضافة أو الدالة${\($color->reset())}";
        return undef;
    }
    
    if (!$LOADED_PLUGINS{$plugin_name}) {
        say "${\($color->error())}[!] الإضافة $plugin_name غير محملة${\($color->reset())}";
        return undef;
    }
    
    my $plugin = $LOADED_PLUGINS{$plugin_name};
    
    if (!$plugin->{functions_hash}{$function}) {
        say "${\($color->error())}[!] الدالة $function غير موجودة في الإضافة $plugin_name${\($color->reset())}";
        return undef;
    }
    
    say "${\($color->info())}[*] استدعاء $plugin_name::$function${\($color->reset())}";
    
    my $result = eval { $plugin->{functions_hash}{$function}->(@args); };
    
    if ($@) {
        say "${\($color->error())}[!] خطأ في تنفيذ الدالة: $@${\($color->reset())}";
        return undef;
    }
    
    say "\n${\($color->success())}[✓] تم تنفيذ الدالة بنجاح${\($color->reset())}";
    
    $utils->save_result('plugin_system', {
        action => 'call',
        plugin => $plugin_name,
        function => $function
    });
    
    return $result;
}

# =============================================================================
# تثبيت إضافة جديدة
# =============================================================================
sub plugin_install {
    my ($plugin_source, $plugin_name) = @_;
    
    my $color = Colors->new();
    my $utils = Utils->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    📦 تثبيت إضافة جديدة 📦                           ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    _load_plugins_config();
    
    $plugin_source //= "";
    $plugin_name //= "";
    
    if (!$plugin_source) {
        say "${\($color->error())}[!] لم يتم تحديد مصدر الإضافة${\($color->reset())}";
        return 0;
    }
    
    say "${\($color->info())}[*] تثبيت إضافة من: $plugin_source${\($color->reset())}";
    
    # محاكاة التثبيت من مصادر مختلفة
    my $install_result = _install_plugin($plugin_source, $plugin_name);
    
    if (!$install_result->{success}) {
        say "\n${\($color->error())}[!] فشل تثبيت الإضافة: $install_result->{error}${\($color->reset())}";
        return 0;
    }
    
    say "\n${\($color->success())}[✓] تم تثبيت الإضافة بنجاح${\($color->reset())}";
    say "   → الاسم: $install_result->{name}";
    say "   → الإصدار: $install_result->{version}";
    say "   → الموقع: $install_result->{path}";
    
    $utils->save_result('plugin_system', {
        action => 'install',
        plugin => $install_result->{name},
        source => $plugin_source
    });
    
    return $install_result;
}

# =============================================================================
# دوال مساعدة داخلية
# =============================================================================

sub _load_plugin_file {
    my ($file) = @_;
    
    # محاكاة قراءة معلومات الإضافة من الملف
    # في الواقع الحقيقي، ستستخدم eval أو require
    
    my $content = read_file($file);
    
    # استخراج معلومات الإضافة (محاكاة)
    my $info = {
        name => "Sample Plugin",
        version => "1.0.0",
        author => "Unknown",
        description => "وصف الإضافة",
        functions => ["init", "run", "cleanup"],
        functions_hash => {},
        unload => sub { say "   → تنظيف الإضافة..." }
    };
    
    # إنشاء دوال وهمية
    $info->{functions_hash}{init} = sub { say "   → تهيئة الإضافة..."; return 1; };
    $info->{functions_hash}{run} = sub { say "   → تشغيل الإضافة..."; return "result"; };
    $info->{functions_hash}{cleanup} = sub { say "   → تنظيف الإضافة..."; return 1; };
    
    return $info;
}

sub _get_available_plugins {
    my @plugins = ();
    
    # البحث عن ملفات الإضافات في المجلد
    find({
        wanted => sub {
            return unless -f $_ && /\.pm$/;
            my $file = $_;
            $file =~ s/.*\///;
            $file =~ s/\.pm$//;
            push @plugins, $file unless $LOADED_PLUGINS{$file};
        },
        no_chdir => 1
    }, $PLUGINS_DIR);
    
    return \@plugins;
}

sub _install_plugin {
    my ($source, $name) = @_;
    
    if ($source =~ /^https?:\/\//) {
        # تنزيل من الإنترنت
        my $filename = $name || "plugin_" . time() . ".pm";
        my $target = "$PLUGINS_DIR/$filename";
        
        # محاكاة التنزيل
        write_file($target, "# Plugin content\n");
        
        return {
            success => 1,
            name => $filename,
            version => "1.0.0",
            path => $target
        };
    } elsif (-f $source) {
        # نسخ من ملف محلي
        my $filename = $name || basename($source);
        my $target = "$PLUGINS_DIR/$filename";
        
        copy($source, $target);
        
        return {
            success => 1,
            name => $filename,
            version => "1.0.0",
            path => $target
        };
    } else {
        return {
            success => 0,
            error => "مصدر غير معروف"
        };
    }
}

sub basename {
    my ($path) = @_;
    $path =~ s/.*\///;
    return $path;
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

# تحميل الإعدادات عند التحميل
_load_plugins_config();

1;  # نهاية الوحدة
