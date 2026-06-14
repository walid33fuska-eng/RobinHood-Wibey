package integration::BackupManager;
# =============================================================================
# BackupManager.pm - إدارة النسخ الاحتياطية
# =============================================================================
# الميزات: إنشاء نسخ احتياطية، استعادة البيانات، جدولة النسخ، ضغط وتشفير
# =============================================================================

use strict;
use warnings;
use parent 'Exporter';
our @EXPORT_OK = qw(backup_create backup_restore backup_list backup_schedule);

use lib '.';
use lib::Utils;
use lib::Colors;
use Time::HiRes qw(time);
use File::Slurp qw(read_file write_file);
use File::Find;
use Archive::Tar;
use Compress::Zlib qw(gzip);
use Digest::SHA qw(sha256_hex);
use JSON;

# إعدادات النسخ الاحتياطي
my $BACKUP_DIR = "$ENV{HOME}/.robinhood/backups";
my $BACKUP_CONFIG_FILE = "$BACKUP_DIR/backup_config.json";
my $BACKUP_CONFIG = {};

# تحميل إعدادات النسخ الاحتياطي
sub _load_backup_config {
    if (-f $BACKUP_CONFIG_FILE) {
        my $json = read_file($BACKUP_CONFIG_FILE);
        eval { $BACKUP_CONFIG = decode_json($json); };
    }
    
    if (!keys %$BACKUP_CONFIG) {
        $BACKUP_CONFIG = {
            enabled => 1,
            auto_backup => 1,
            backup_interval => 86400,  # 24 ساعة
            max_backups => 10,
            compress => 1,
            encrypt => 0,
            encryption_key => "",
            include_dirs => ["results", "logs", "wordlists", "captures", "ai_models"],
            exclude_patterns => ["*.tmp", "*.log"]
        };
    }
}

# حفظ إعدادات النسخ الاحتياطي
sub _save_backup_config {
    write_file($BACKUP_CONFIG_FILE, encode_json($BACKUP_CONFIG));
}

# إنشاء مجلد النسخ الاحتياطي
mkdir($BACKUP_DIR) unless -d $BACKUP_DIR;

# =============================================================================
# إنشاء نسخة احتياطية
# =============================================================================
sub backup_create {
    my ($backup_name, $include_dirs, $description) = @_;
    
    my $color = Colors->new();
    my $utils = Utils->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    💾 إنشاء نسخة احتياطية 💾                          ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    _load_backup_config();
    
    $backup_name //= "backup_" . time();
    $include_dirs //= $BACKUP_CONFIG->{include_dirs};
    $description //= "نسخة احتياطية تلقائية";
    
    say "${\($color->info())}[*] إنشاء نسخة احتياطية: $backup_name${\($color->reset())}";
    
    # إنشاء مجلد مؤقت
    my $temp_dir = "/tmp/robinhood_backup_$$";
    mkdir($temp_dir);
    
    # نسخ الملفات والمجلدات
    my $backup_data = {
        name => $backup_name,
        created_at => time(),
        created_time => scalar(localtime()),
        description => $description,
        version => "3.0.0",
        files => [],
        total_size => 0
    };
    
    for my $dir (@$include_dirs) {
        my $source = "$ENV{HOME}/.robinhood/$dir";
        my $target = "$temp_dir/$dir";
        
        if (-d $source) {
            system("cp -r $source $target");
            
            # حساب حجم المجلد
            my $size = _dir_size($source);
            $backup_data->{total_size} += $size;
            
            push @{$backup_data->{files}}, {
                path => $dir,
                size => $size,
                files_count => _count_files($source)
            };
            
            say "${\($color->info())}   → تم نسخ $dir (" . $utils->format_size($size) . ")${\($color->reset())}";
        }
    }
    
    # حفظ بيانات النسخة الاحتياطية
    write_file("$temp_dir/backup_info.json", encode_json($backup_data));
    
    # ضغط النسخة الاحتياطية
    my $backup_file = "$BACKUP_DIR/${backup_name}.tar";
    my $tar = Archive::Tar->new();
    $tar->add_files("$temp_dir");
    $tar->write($backup_file);
    
    # ضغط إضافي
    if ($BACKUP_CONFIG->{compress}) {
        system("gzip -f $backup_file");
        $backup_file .= ".gz";
    }
    
    # تشفير (اختياري)
    if ($BACKUP_CONFIG->{encrypt} && $BACKUP_CONFIG->{encryption_key}) {
        _encrypt_file($backup_file, $BACKUP_CONFIG->{encryption_key});
        $backup_file .= ".enc";
    }
    
    # حساب بصمة الملف
    my $file_hash = _calculate_file_hash($backup_file);
    $backup_data->{file_hash} = $file_hash;
    $backup_data->{file_size} = -s $backup_file;
    
    # حفظ معلومات النسخة الاحتياطية
    my $info_file = "$BACKUP_DIR/${backup_name}.info.json";
    write_file($info_file, encode_json($backup_data));
    
    # تنظيف الملفات المؤقتة
    system("rm -rf $temp_dir");
    
    # تحديث قائمة النسخ الاحتياطية
    _update_backup_list($backup_name, $backup_data);
    
    # حذف النسخ القديمة
    _prune_old_backups();
    
    say "\n${\($color->success())}[✓] تم إنشاء النسخة الاحتياطية بنجاح${\($color->reset())}";
    say "   → الاسم: $backup_name";
    say "   → الحجم: " . $utils->format_size($backup_data->{file_size});
    say "   → الملف: $backup_file";
    say "   → البصمة: " . substr($file_hash, 0, 16) . "...";
    
    $utils->save_result('backup_manager', {
        action => 'create',
        backup_name => $backup_name,
        size => $backup_data->{file_size},
        files_count => scalar(@{$backup_data->{files}})
    });
    
    return {
        name => $backup_name,
        file => $backup_file,
        size => $backup_data->{file_size},
        hash => $file_hash
    };
}

# =============================================================================
# استعادة نسخة احتياطية
# =============================================================================
sub backup_restore {
    my ($backup_name, $restore_path, $overwrite) = @_;
    
    my $color = Colors->new();
    my $utils = Utils->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    🔄 استعادة نسخة احتياطية 🔄                       ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    _load_backup_config();
    
    $backup_name //= "";
    $restore_path //= "$ENV{HOME}/.robinhood/restore";
    $overwrite //= 0;
    
    # البحث عن ملف النسخة الاحتياطية
    my $backup_file = _find_backup_file($backup_name);
    
    if (!$backup_file) {
        say "${\($color->error())}[!] لم يتم العثور على النسخة الاحتياطية: $backup_name${\($color->reset())}";
        return 0;
    }
    
    say "${\($color->info())}[*] استعادة النسخة الاحتياطية: $backup_name${\($color->reset())}";
    
    # إنشاء مجلد الاستعادة
    mkdir($restore_path) unless -d $restore_path;
    
    # فك التشفير إذا لزم الأمر
    if ($backup_file =~ /\.enc$/) {
        _decrypt_file($backup_file, $BACKUP_CONFIG->{encryption_key});
        $backup_file =~ s/\.enc$//;
    }
    
    # فك الضغط
    if ($backup_file =~ /\.gz$/) {
        system("gunzip -f $backup_file");
        $backup_file =~ s/\.gz$//;
    }
    
    # فك الأرشيف
    my $temp_dir = "/tmp/robinhood_restore_$$";
    mkdir($temp_dir);
    
    my $tar = Archive::Tar->new();
    $tar->read($backup_file);
    $tar->extract($temp_dir);
    
    # قراءة معلومات النسخة الاحتياطية
    my $info_file = "$temp_dir/backup_info.json";
    if (-f $info_file) {
        my $json = read_file($info_file);
        my $backup_info = decode_json($json);
        
        say "\n${\($color->info())}📋 معلومات النسخة الاحتياطية:${\($color->reset())}";
        say "   → التاريخ: $backup_info->{created_time}";
        say "   → الوصف: $backup_info->{description}";
        say "   → عدد الملفات: " . scalar(@{$backup_info->{files}});
    }
    
    # نسخ الملفات إلى موقع الاستعادة
    my $restored_count = 0;
    for my $dir (@{$BACKUP_CONFIG->{include_dirs}}) {
        my $source = "$temp_dir/$dir";
        my $target = "$restore_path/$dir";
        
        if (-d $source) {
            if (-d $target && !$overwrite) {
                say "${\($color->warning())}   → تخطي $dir (الموجود مسبقاً)${\($color->reset())}";
            } else {
                system("cp -r $source $target");
                $restored_count++;
                say "${\($color->success())}   → تم استعادة $dir${\($color->reset())}";
            }
        }
    }
    
    # تنظيف الملفات المؤقتة
    system("rm -rf $temp_dir");
    unlink($backup_file) if -f $backup_file;
    
    say "\n${\($color->success())}[✓] تم استعادة النسخة الاحتياطية بنجاح${\($color->reset())}";
    say "   → تم استعادة $restored_count مجلد";
    say "   → المسار: $restore_path";
    
    $utils->save_result('backup_manager', {
        action => 'restore',
        backup_name => $backup_name,
        restored_folders => $restored_count
    });
    
    return 1;
}

# =============================================================================
# قائمة النسخ الاحتياطية
# =============================================================================
sub backup_list {
    my $color = Colors->new();
    my $utils = Utils->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    📋 قائمة النسخ الاحتياطية 📋                       ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    my $backups = _get_backup_list();
    
    if (scalar(@$backups) == 0) {
        say "\n${\($color->warning())}[!] لا توجد نسخ احتياطية${\($color->reset())}";
        return [];
    }
    
    say "\n${\($color->info())}📊 النسخ الاحتياطية المتاحة:${\($color->reset())}";
    
    my $i = 1;
    for my $backup (@$backups) {
        my $size_mb = $backup->{file_size} / (1024 * 1024);
        say "\n   $i. ${\($color->quantum())}$backup->{name}${\($color->reset())}";
        say "      → التاريخ: $backup->{created_time}";
        say "      → الحجم: " . sprintf("%.2f", $size_mb) . " MB";
        say "      → الوصف: $backup->{description}";
        $i++;
    }
    
    $utils->save_result('backup_manager', {
        action => 'list',
        backups_count => scalar(@$backups)
    });
    
    return $backups;
}

# =============================================================================
# جدولة النسخ الاحتياطية
# =============================================================================
sub backup_schedule {
    my ($interval, $max_backups, $auto_clean) = @_;
    
    my $color = Colors->new();
    my $utils = Utils->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    ⏰ جدولة النسخ الاحتياطية ⏰                       ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    _load_backup_config();
    
    $interval //= $BACKUP_CONFIG->{backup_interval};
    $max_backups //= $BACKUP_CONFIG->{max_backups};
    $auto_clean //= 1;
    
    $BACKUP_CONFIG->{backup_interval} = $interval;
    $BACKUP_CONFIG->{max_backups} = $max_backups;
    $BACKUP_CONFIG->{auto_backup} = 1;
    
    _save_backup_config();
    
    say "${\($color->success())}[✓] تم تحديث إعدادات الجدولة:${\($color->reset())}";
    say "   → الفاصل الزمني: " . ($interval / 3600) . " ساعات";
    say "   → الحد الأقصى للنسخ: $max_backups";
    say "   → التنظيف التلقائي: " . ($auto_clean ? "مفعل" : "معطل");
    
    $utils->save_result('backup_manager', {
        action => 'schedule',
        interval => $interval,
        max_backups => $max_backups
    });
    
    return $BACKUP_CONFIG;
}

# =============================================================================
# دوال مساعدة داخلية
# =============================================================================

sub _dir_size {
    my ($dir) = @_;
    
    my $size = 0;
    find({
        wanted => sub {
            return unless -f $_;
            $size += -s $_;
        },
        no_chdir => 1
    }, $dir);
    
    return $size;
}

sub _count_files {
    my ($dir) = @_;
    
    my $count = 0;
    find({
        wanted => sub {
            return unless -f $_;
            $count++;
        },
        no_chdir => 1
    }, $dir);
    
    return $count;
}

sub _calculate_file_hash {
    my ($file) = @_;
    
    open(my $fh, '<', $file);
    local $/;
    my $content = <$fh>;
    close($fh);
    
    return sha256_hex($content);
}

sub _encrypt_file {
    my ($file, $key) = @_;
    
    # محاكاة تشفير الملف
    my $encrypted_file = "$file.enc";
    system("openssl enc -aes-256-cbc -in $file -out $encrypted_file -pass pass:$key 2>/dev/null");
    unlink($file);
    
    return $encrypted_file;
}

sub _decrypt_file {
    my ($file, $key) = @_;
    
    my $decrypted_file = $file;
    $decrypted_file =~ s/\.enc$//;
    
    system("openssl enc -d -aes-256-cbc -in $file -out $decrypted_file -pass pass:$key 2>/dev/null");
    unlink($file);
    
    return $decrypted_file;
}

sub _find_backup_file {
    my ($name) = @_;
    
    opendir(my $dh, $BACKUP_DIR);
    my @files = grep { /^$name/ && !/\.info\.json$/ } readdir($dh);
    closedir($dh);
    
    return $files[0] ? "$BACKUP_DIR/$files[0]" : undef;
}

sub _update_backup_list {
    my ($name, $data) = @_;
    
    my $list_file = "$BACKUP_DIR/backup_list.json";
    my $backups = [];
    
    if (-f $list_file) {
        my $json = read_file($list_file);
        eval { $backups = decode_json($json); };
    }
    
    unshift @$backups, $data;
    
    write_file($list_file, encode_json($backups));
}

sub _get_backup_list {
    my $list_file = "$BACKUP_DIR/backup_list.json";
    
    if (-f $list_file) {
        my $json = read_file($list_file);
        return decode_json($json);
    }
    
    return [];
}

sub _prune_old_backups {
    my $backups = _get_backup_list();
    my $max = $BACKUP_CONFIG->{max_backups};
    
    if (scalar(@$backups) > $max) {
        my @to_delete = splice(@$backups, $max);
        
        for my $backup (@to_delete) {
            my $backup_file = "$BACKUP_DIR/$backup->{name}.tar.gz";
            unlink($backup_file) if -f $backup_file;
            
            my $info_file = "$BACKUP_DIR/$backup->{name}.info.json";
            unlink($info_file) if -f $info_file;
        }
        
        my $list_file = "$BACKUP_DIR/backup_list.json";
        write_file($list_file, encode_json($backups));
    }
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
_load_backup_config();

1;  # نهاية الوحدة
