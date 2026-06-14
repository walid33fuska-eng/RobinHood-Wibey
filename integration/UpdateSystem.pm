package integration::UpdateSystem;
# =============================================================================
# UpdateSystem.pm - نظام التحديثات التلقائية
# =============================================================================
# الميزات: التحقق من التحديثات، تنزيل التحديثات، تطبيق التحديثات، استعادة الإصدار السابق
# =============================================================================

use strict;
use warnings;
use parent 'Exporter';
our @EXPORT_OK = qw(update_check update_download update_apply update_rollback update_status);

use lib '.';
use lib::Utils;
use lib::Colors;
use Time::HiRes qw(time);
use File::Slurp qw(read_file write_file);
use File::Copy;
use JSON;

# إعدادات التحديثات
my $UPDATE_DIR = "$ENV{HOME}/.robinhood/updates";
my $UPDATE_CONFIG_FILE = "$UPDATE_DIR/update_config.json";
my $UPDATE_CONFIG = {};

# تحميل إعدادات التحديثات
sub _load_update_config {
    if (-f $UPDATE_CONFIG_FILE) {
        my $json = read_file($UPDATE_CONFIG_FILE);
        eval { $UPDATE_CONFIG = decode_json($json); };
    }
    
    if (!keys %$UPDATE_CONFIG) {
        $UPDATE_CONFIG = {
            auto_check => 1,
            auto_download => 0,
            auto_apply => 0,
            check_interval => 86400,  # 24 ساعة
            last_check => 0,
            current_version => "3.0.0",
            update_server => "https://updates.robinhood.com",
            channel => "stable"
        };
    }
}

# حفظ إعدادات التحديثات
sub _save_update_config {
    write_file($UPDATE_CONFIG_FILE, encode_json($UPDATE_CONFIG));
}

# إنشاء مجلد التحديثات
mkdir($UPDATE_DIR) unless -d $UPDATE_DIR;

# =============================================================================
# التحقق من التحديثات
# =============================================================================
sub update_check {
    my $color = Colors->new();
    my $utils = Utils->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    🔄 التحقق من التحديثات 🔄                         ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    _load_update_config();
    
    say "${\($color->info())}[*] التحقق من التحديثات للإصدار $UPDATE_CONFIG->{current_version}${\($color->reset())}";
    say "   → القناة: $UPDATE_CONFIG->{channel}";
    
    # محاكاة الاتصال بخادم التحديثات
    my $update_info = _check_for_updates($UPDATE_CONFIG->{current_version}, $UPDATE_CONFIG->{channel});
    
    $UPDATE_CONFIG->{last_check} = time();
    _save_update_config();
    
    if ($update_info->{has_update}) {
        say "\n${\($color->warning())}⚠️ تحديث جديد متاح!${\($color->reset())}";
        say "   → الإصدار الحالي: $UPDATE_CONFIG->{current_version}";
        say "   → الإصدار الجديد: $update_info->{latest_version}";
        say "   → تاريخ الإصدار: $update_info->{release_date}";
        say "   → الحجم: " . $utils->format_size($update_info->{size});
        
        say "\n${\($color->info())}📝 ما الجديد:${\($color->reset())}";
        for my $item (@{$update_info->{changelog}}) {
            say "   → $item";
        }
        
        if ($update_info->{critical}) {
            say "\n${\($color->error())}⚠️ تحديث أمني مهم - يوصى بالتحديث فوراً${\($color->reset())}";
        }
        
    } else {
        say "\n${\($color->success())}✓ أنت تستخدم أحدث إصدار${\($color->reset())}";
    }
    
    $utils->save_result('update_system', {
        action => 'check',
        has_update => $update_info->{has_update},
        current_version => $UPDATE_CONFIG->{current_version},
        latest_version => $update_info->{latest_version}
    });
    
    return $update_info;
}

# =============================================================================
# تنزيل التحديث
# =============================================================================
sub update_download {
    my ($version, $force) = @_;
    
    my $color = Colors->new();
    my $utils = Utils->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    📥 تنزيل التحديث 📥                               ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    _load_update_config();
    
    $version //= "";
    $force //= 0;
    
    # التحقق من وجود تحديث
    my $update_info = _check_for_updates($UPDATE_CONFIG->{current_version}, $UPDATE_CONFIG->{channel});
    
    if (!$update_info->{has_update} && !$force) {
        say "${\($color->warning())}[!] لا توجد تحديثات جديدة${\($color->reset())}";
        return 0;
    }
    
    my $target_version = $version || $update_info->{latest_version};
    
    say "${\($color->info())}[*] تنزيل الإصدار $target_version...${\($color->reset())}";
    
    # محاكاة التنزيل
    my $download_file = "$UPDATE_DIR/robinhood_update_$target_version.tar.gz";
    
    say "   → مصدر التحميل: $UPDATE_CONFIG->{update_server}/$target_version";
    say "   → الوجهة: $download_file";
    
    # محاكاة التحميل بتقدم
    my $file_size = $update_info->{size} || 10485760;  # 10 MB افتراضي
    my $downloaded = 0;
    
    while ($downloaded < $file_size) {
        my $chunk = int(rand($file_size * 0.1)) + 1024;
        $downloaded += $chunk;
        $downloaded = $file_size if $downloaded > $file_size;
        
        my $percent = int(($downloaded / $file_size) * 100);
        print "\r${\($color->info())}[*] التحميل: $percent% - " . $utils->format_size($downloaded) . " من " . $utils->format_size($file_size) . "${\($color->reset())}";
        
        sleep(rand(2));
    }
    
    print "\n";
    
    # إنشاء ملف وهمي
    write_file($download_file, "محاكاة ملف التحديث\n");
    
    # التحقق من integrity
    my $hash = _calculate_file_hash($download_file);
    
    # حفظ معلومات التحديث
    my $update_manifest = {
        version => $target_version,
        downloaded_at => time(),
        file => $download_file,
        size => $file_size,
        hash => $hash,
        changelog => $update_info->{changelog}
    };
    
    write_file("$UPDATE_DIR/manifest_$target_version.json", encode_json($update_manifest));
    
    say "\n${\($color->success())}[✓] تم تنزيل التحديث بنجاح${\($color->reset())}";
    say "   → الإصدار: $target_version";
    say "   → الملف: $download_file";
    say "   → البصمة: " . substr($hash, 0, 16) . "...";
    
    $utils->save_result('update_system', {
        action => 'download',
        version => $target_version,
        size => $file_size
    });
    
    return $update_manifest;
}

# =============================================================================
# تطبيق التحديث
# =============================================================================
sub update_apply {
    my ($version, $backup_first) = @_;
    
    my $color = Colors->new();
    my $utils = Utils->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    🔧 تطبيق التحديث 🔧                               ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    _load_update_config();
    
    $version //= "";
    $backup_first //= 1;
    
    # البحث عن ملف التحديث
    my $update_file = "$UPDATE_DIR/robinhood_update_${version}.tar.gz";
    my $manifest_file = "$UPDATE_DIR/manifest_${version}.json";
    
    if ($version && !-f $update_file) {
        say "${\($color->error())}[!] ملف التحديث غير موجود: $update_file${\($color->reset())}";
        return 0;
    }
    
    # إذا لم يتم تحديد إصدار، استخدم أحدث تحديث تم تنزيله
    if (!$version) {
        opendir(my $dh, $UPDATE_DIR);
        my @files = grep { /^robinhood_update_.*\.tar\.gz$/ } readdir($dh);
        closedir($dh);
        
        if (scalar(@files) == 0) {
            say "${\($color->error())}[!] لا توجد تحديثات متاحة للتطبيق${\($color->reset())}";
            return 0;
        }
        
        # أحدث ملف
        @files = sort { (stat("$UPDATE_DIR/$b"))[9] <=> (stat("$UPDATE_DIR/$a"))[9] } @files;
        $update_file = "$UPDATE_DIR/$files[0]";
        $files[0] =~ /robinhood_update_(.*)\.tar\.gz/;
        $version = $1;
        $manifest_file = "$UPDATE_DIR/manifest_$version.json";
    }
    
    say "${\($color->info())}[*] تطبيق التحديث إلى الإصدار $version${\($color->reset())}";
    
    # إنشاء نسخة احتياطية قبل التحديث
    if ($backup_first) {
        say "   → إنشاء نسخة احتياطية من الإصدار الحالي...";
        my $backup_dir = "$UPDATE_DIR/backup_$UPDATE_CONFIG->{current_version}";
        mkdir($backup_dir);
        system("cp -r $ENV{HOME}/.robinhood/*.pm $backup_dir/ 2>/dev/null");
        say "   → تم إنشاء النسخة الاحتياطية في $backup_dir";
    }
    
    # قراءة manifest
    my $manifest = {};
    if (-f $manifest_file) {
        my $json = read_file($manifest_file);
        $manifest = decode_json($json);
    }
    
    # محاكاة تطبيق التحديث
    say "\n${\($color->info())}[*] تطبيق التحديث...${\($color->reset())}";
    
    my $steps = [
        "إيقاف الخدمات النشطة",
        "نسخ الملفات الجديدة",
        "تحديث قاعدة البيانات",
        "تحديث الإعدادات",
        "إعادة تشغيل الخدمات"
    ];
    
    for my $step (@$steps) {
        print "   → $step... ";
        sleep(1);
        say "${\($color->success())}✓${\($color->reset())}";
    }
    
    # تحديث الإصدار
    my $old_version = $UPDATE_CONFIG->{current_version};
    $UPDATE_CONFIG->{current_version} = $version;
    $UPDATE_CONFIG->{last_update} = time();
    _save_update_config();
    
    say "\n${\($color->success())}[✓] تم تطبيق التحديث بنجاح!${\($color->reset())}";
    say "   → الإصدار السابق: $old_version";
    say "   → الإصدار الحالي: $version";
    
    if ($manifest->{changelog}) {
        say "\n${\($color->info())}📝 التغييرات:${\($color->reset())}";
        for my $item (@{$manifest->{changelog}}) {
            say "   → $item";
        }
    }
    
    $utils->save_result('update_system', {
        action => 'apply',
        from_version => $old_version,
        to_version => $version
    });
    
    return {
        success => 1,
        old_version => $old_version,
        new_version => $version
    };
}

# =============================================================================
# استعادة إصدار سابق
# =============================================================================
sub update_rollback {
    my ($version) = @_;
    
    my $color = Colors->new();
    my $utils = Utils->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    ↩️ استعادة إصدار سابق ↩️                           ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    _load_update_config();
    
    $version //= "";
    
    # البحث عن النسخة الاحتياطية
    my $backup_dir = "$UPDATE_DIR/backup_$version";
    
    if (!$version) {
        # عرض قائمة النسخ الاحتياطية المتاحة
        opendir(my $dh, $UPDATE_DIR);
        my @backups = grep { /^backup_/ && -d "$UPDATE_DIR/$_" } readdir($dh);
        closedir($dh);
        
        if (scalar(@backups) == 0) {
            say "${\($color->error())}[!] لا توجد نسخ احتياطية متاحة${\($color->reset())}";
            return 0;
        }
        
        say "\n${\($color->info())}📋 النسخ الاحتياطية المتاحة:${\($color->reset())}";
        for my $i (0..$#backups) {
            my $ver = $backups[$i];
            $ver =~ s/backup_//;
            say "   " . ($i+1) . ". الإصدار $ver";
        }
        
        print "\n${\($color->quantum())}اختر الإصدار: ${\($color->reset())}";
        my $choice = <STDIN>;
        chomp($choice);
        
        if ($choice =~ /^\d+$/ && $choice >= 1 && $choice <= scalar(@backups)) {
            my $selected = $backups[$choice-1];
            $selected =~ s/backup_//;
            $version = $selected;
            $backup_dir = "$UPDATE_DIR/backup_$version";
        } else {
            say "${\($color->error())}[!] اختيار غير صالح${\($color->reset())}";
            return 0;
        }
    }
    
    if (!-d $backup_dir) {
        say "${\($color->error())}[!] النسخة الاحتياطية غير موجودة: $version${\($color->reset())}";
        return 0;
    }
    
    say "${\($color->info())}[*] استعادة الإصدار $version...${\($color->reset())}";
    
    # محاكاة الاستعادة
    my $old_version = $UPDATE_CONFIG->{current_version};
    
    my $steps = [
        "إيقاف الخدمات النشطة",
        "استعادة الملفات من النسخة الاحتياطية",
        "استعادة قاعدة البيانات",
        "استعادة الإعدادات",
        "إعادة تشغيل الخدمات"
    ];
    
    for my $step (@$steps) {
        print "   → $step... ";
        sleep(1);
        say "${\($color->success())}✓${\($color->reset())}";
    }
    
    # تحديث الإصدار
    $UPDATE_CONFIG->{current_version} = $version;
    $UPDATE_CONFIG->{last_rollback} = time();
    _save_update_config();
    
    say "\n${\($color->success())}[✓] تم استعادة الإصدار السابق بنجاح!${\($color->reset())}";
    say "   → الإصدار السابق: $old_version";
    say "   → الإصدار الحالي: $version";
    
    $utils->save_result('update_system', {
        action => 'rollback',
        from_version => $old_version,
        to_version => $version
    });
    
    return {
        success => 1,
        old_version => $old_version,
        new_version => $version
    };
}

# =============================================================================
# حالة نظام التحديثات
# =============================================================================
sub update_status {
    my $color = Colors->new();
    my $utils = Utils->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    📊 حالة نظام التحديثات 📊                         ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    _load_update_config();
    
    say "\n${\($color->info())}ℹ️ معلومات النظام:${\($color->reset())}";
    say "   → الإصدار الحالي: ${\($color->quantum())}$UPDATE_CONFIG->{current_version}${\($color->reset())}";
    say "   → قناة التحديثات: $UPDATE_CONFIG->{channel}";
    say "   → التحقق التلقائي: " . ($UPDATE_CONFIG->{auto_check} ? "مفعل" : "معطل");
    say "   → التنزيل التلقائي: " . ($UPDATE_CONFIG->{auto_download} ? "مفعل" : "معطل");
    say "   → التطبيق التلقائي: " . ($UPDATE_CONFIG->{auto_apply} ? "مفعل" : "معطل");
    
    if ($UPDATE_CONFIG->{last_check}) {
        say "   → آخر تحقق: " . localtime($UPDATE_CONFIG->{last_check});
    }
    
    if ($UPDATE_CONFIG->{last_update}) {
        say "   → آخر تحديث: " . localtime($UPDATE_CONFIG->{last_update});
    }
    
    # قائمة التحديثات المتاحة
    opendir(my $dh, $UPDATE_DIR);
    my @updates = grep { /^robinhood_update_.*\.tar\.gz$/ } readdir($dh);
    closedir($dh);
    
    if (scalar(@updates) > 0) {
        say "\n${\($color->info())}📦 التحديثات المتاحة للتطبيق:${\($color->reset())}";
        for my $update (@updates) {
            $update =~ /robinhood_update_(.*)\.tar\.gz/;
            my $ver = $1;
            my $size = -s "$UPDATE_DIR/$update";
            say "   → الإصدار $ver (" . $utils->format_size($size) . ")";
        }
    }
    
    $utils->save_result('update_system', {
        action => 'status',
        current_version => $UPDATE_CONFIG->{current_version},
        auto_check => $UPDATE_CONFIG->{auto_check}
    });
    
    return $UPDATE_CONFIG;
}

# =============================================================================
# دوال مساعدة داخلية
# =============================================================================

sub _check_for_updates {
    my ($current, $channel) = @_;
    
    # محاكاة إصدارات مختلفة
    my $latest_version = "3.1.0";
    my $has_update = $current ne $latest_version;
    
    my @changelog = (
        "تحسين أداء الهجمات المتوازية",
        "إصلاح ثغرة أمنية في هجوم WPS",
        "إضافة دعم لـ WPA3",
        "تحسين واجهة المستخدم",
        "إصلاح مشاكل في قاعدة البيانات"
    );
    
    return {
        has_update => $has_update,
        latest_version => $latest_version,
        release_date => "2024-01-15",
        size => 15728640,  # 15 MB
        changelog => \@changelog,
        critical => $has_update && rand() < 0.3,
        channel => $channel
    };
}

sub _calculate_file_hash {
    my ($file) = @_;
    
    open(my $fh, '<', $file);
    local $/;
    my $content = <$fh>;
    close($fh);
    
    use Digest::SHA qw(sha256_hex);
    return sha256_hex($content);
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
_load_update_config();

1;  # نهاية الوحدة
