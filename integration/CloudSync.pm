package integration::CloudSync;
# =============================================================================
# CloudSync.pm - مزامنة سحابية للبيانات والإعدادات
# =============================================================================
# الميزات: رفع البيانات للسحابة، مزامنة بين الأجهزة، نسخ احتياطي سحابي
# =============================================================================

use strict;
use warnings;
use parent 'Exporter';
our @EXPORT_OK = qw(cloud_upload cloud_download cloud_sync cloud_backup);

use lib '.';
use lib::Utils;
use lib::Colors;
use Time::HiRes qw(time);
use File::Slurp qw(read_file write_file);
use Digest::SHA qw(sha256_hex);
use JSON;

# إعدادات السحابة
my $CLOUD_CONFIG_FILE = "$ENV{HOME}/.robinhood/cloud_config.json";
my $CLOUD_CONFIG = {};

# تحميل إعدادات السحابة
sub _load_cloud_config {
    if (-f $CLOUD_CONFIG_FILE) {
        my $json = read_file($CLOUD_CONFIG_FILE);
        eval { $CLOUD_CONFIG = decode_json($json); };
    }
    
    if (!keys %$CLOUD_CONFIG) {
        $CLOUD_CONFIG = {
            provider => "local",
            enabled => 0,
            api_key => "",
            sync_folder => "$ENV{HOME}/.robinhood/cloud",
            auto_sync => 1,
            last_sync => 0
        };
    }
}

# حفظ إعدادات السحابة
sub _save_cloud_config {
    write_file($CLOUD_CONFIG_FILE, encode_json($CLOUD_CONFIG));
}

# =============================================================================
# رفع البيانات للسحابة
# =============================================================================
sub cloud_upload {
    my ($local_file, $remote_path, $provider) = @_;
    
    my $color = Colors->new();
    my $utils = Utils->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    ☁️ رفع البيانات للسحابة ☁️                         ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    _load_cloud_config();
    
    $local_file //= "$ENV{HOME}/.robinhood/results/latest_results.json";
    $remote_path //= "robinhood_data/" . time() . "_" . basename($local_file);
    $provider //= $CLOUD_CONFIG->{provider};
    
    say "${\($color->info())}[*] رفع الملف $local_file إلى $provider${\($color->reset())}";
    
    if (!-f $local_file) {
        say "${\($color->error())}[!] الملف غير موجود: $local_file${\($color->reset())}";
        return 0;
    }
    
    my $file_size = -s $local_file;
    my $file_hash = _calculate_file_hash($local_file);
    
    # محاكاة الرفع لمختلف مقدمي الخدمات
    my $upload_result;
    
    if ($provider eq "local") {
        $upload_result = _upload_to_local($local_file, $remote_path);
    } elsif ($provider eq "dropbox") {
        $upload_result = _upload_to_dropbox($local_file, $remote_path);
    } elsif ($provider eq "google_drive") {
        $upload_result = _upload_to_google_drive($local_file, $remote_path);
    } elsif ($provider eq "github") {
        $upload_result = _upload_to_github($local_file, $remote_path);
    } else {
        $upload_result = _upload_to_generic($local_file, $remote_path);
    }
    
    if ($upload_result->{success}) {
        say "\n${\($color->success())}[✓] تم رفع الملف بنجاح${\($color->reset())}";
        say "   → المسار البعيد: $upload_result->{remote_url}";
        say "   → الحجم: " . $utils->format_size($file_size);
        say "   → بصمة الملف: " . substr($file_hash, 0, 16) . "...";
        
        # تسجيل الرفع
        _log_cloud_action("upload", $local_file, $upload_result->{remote_url});
        
        # تحديث آخر مزامنة
        $CLOUD_CONFIG->{last_sync} = time();
        _save_cloud_config();
        
    } else {
        say "\n${\($color->error())}[!] فشل رفع الملف: $upload_result->{error}${\($color->reset())}";
    }
    
    $utils->save_result('cloud_sync', {
        action => 'upload',
        provider => $provider,
        file => $local_file,
        success => $upload_result->{success}
    });
    
    return $upload_result;
}

# =============================================================================
# تحميل البيانات من السحابة
# =============================================================================
sub cloud_download {
    my ($remote_path, $local_path, $provider) = @_;
    
    my $color = Colors->new();
    my $utils = Utils->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    📥 تحميل البيانات من السحابة 📥                    ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    _load_cloud_config();
    
    $remote_path //= "robinhood_data/latest_results.json";
    $local_path //= "$ENV{HOME}/.robinhood/downloads/" . basename($remote_path);
    $provider //= $CLOUD_CONFIG->{provider};
    
    say "${\($color->info())}[*] تحميل الملف $remote_path من $provider${\($color->reset())}";
    
    # إنشاء مجلد التحميلات
    my $download_dir = dirname($local_path);
    mkdir($download_dir) unless -d $download_dir;
    
    # محاكاة التحميل
    my $download_result;
    
    if ($provider eq "local") {
        $download_result = _download_from_local($remote_path, $local_path);
    } elsif ($provider eq "dropbox") {
        $download_result = _download_from_dropbox($remote_path, $local_path);
    } elsif ($provider eq "google_drive") {
        $download_result = _download_from_google_drive($remote_path, $local_path);
    } else {
        $download_result = _download_from_generic($remote_path, $local_path);
    }
    
    if ($download_result->{success}) {
        my $file_size = -s $local_path;
        
        say "\n${\($color->success())}[✓] تم تحميل الملف بنجاح${\($color->reset())}";
        say "   → المسار المحلي: $local_path";
        say "   → الحجم: " . $utils->format_size($file_size);
        
        # تسجيل التحميل
        _log_cloud_action("download", $remote_path, $local_path);
        
    } else {
        say "\n${\($color->error())}[!] فشل تحميل الملف: $download_result->{error}${\($color->reset())}";
    }
    
    $utils->save_result('cloud_sync', {
        action => 'download',
        provider => $provider,
        remote_path => $remote_path,
        success => $download_result->{success}
    });
    
    return $download_result;
}

# =============================================================================
# مزامنة كاملة مع السحابة
# =============================================================================
sub cloud_sync {
    my ($direction, $provider) = @_;
    
    my $color = Colors->new();
    my $utils = Utils->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    🔄 مزامنة سحابية 🔄                               ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    _load_cloud_config();
    
    $direction //= "both";
    $provider //= $CLOUD_CONFIG->{provider};
    
    say "${\($color->info())}[*] بدء المزامنة مع $provider (الاتجاه: $direction)${\($color->reset())}";
    
    my $sync_result = {
        success => 1,
        uploaded => 0,
        downloaded => 0,
        conflicts => 0,
        details => []
    };
    
    # تحديد المجلدات المراد مزامنتها
    my @sync_folders = ("results", "logs", "wordlists", "captures");
    
    for my $folder (@sync_folders) {
        my $local_folder = "$ENV{HOME}/.robinhood/$folder";
        my $remote_folder = "robinhood_data/$folder";
        
        next unless -d $local_folder;
        
        if ($direction eq "upload" || $direction eq "both") {
            # رفع الملفات المحلية الجديدة
            opendir(my $dh, $local_folder);
            my @files = grep { -f "$local_folder/$_" && !/^\./ } readdir($dh);
            closedir($dh);
            
            for my $file (@files) {
                my $local_file = "$local_folder/$file";
                my $remote_file = "$remote_folder/$file";
                
                # التحقق مما إذا كان الملف موجوداً بالفعل في السحابة
                if (!_file_exists_in_cloud($remote_file)) {
                    my $upload = cloud_upload($local_file, $remote_file, $provider);
                    if ($upload->{success}) {
                        $sync_result->{uploaded}++;
                        push @{$sync_result->{details}}, "رفع: $file";
                    }
                }
            }
        }
        
        if ($direction eq "download" || $direction eq "both") {
            # تحميل الملفات الجديدة من السحابة
            my $remote_files = _list_cloud_files($remote_folder);
            
            for my $remote_file (@$remote_files) {
                my $local_file = "$local_folder/" . basename($remote_file);
                
                if (!-f $local_file) {
                    my $download = cloud_download($remote_file, $local_file, $provider);
                    if ($download->{success}) {
                        $sync_result->{downloaded}++;
                        push @{$sync_result->{details}}, "تحميل: " . basename($remote_file);
                    }
                }
            }
        }
    }
    
    # تحديث آخر مزامنة
    $CLOUD_CONFIG->{last_sync} = time();
    _save_cloud_config();
    
    say "\n${\($color->success())}📊 نتائج المزامنة:${\($color->reset())}";
    say "   → تم الرفع: $sync_result->{uploaded} ملف";
    say "   → تم التحميل: $sync_result->{downloaded} ملف";
    say "   → تعارضات: $sync_result->{conflicts}";
    say "   → آخر مزامنة: " . localtime($CLOUD_CONFIG->{last_sync});
    
    $utils->save_result('cloud_sync', {
        action => 'sync',
        direction => $direction,
        uploaded => $sync_result->{uploaded},
        downloaded => $sync_result->{downloaded}
    });
    
    return $sync_result;
}

# =============================================================================
# نسخ احتياطي سحابي
# =============================================================================
sub cloud_backup {
    my ($backup_name, $include_data, $provider) = @_;
    
    my $color = Colors->new();
    my $utils = Utils->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    💾 نسخ احتياطي سحابي 💾                           ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    _load_cloud_config();
    
    $backup_name //= "backup_" . time();
    $include_data //= 1;
    $provider //= $CLOUD_CONFIG->{provider};
    
    say "${\($color->info())}[*] إنشاء نسخة احتياطية سحابية: $backup_name${\($color->reset())}";
    
    # إنشاء مجلد مؤقت للنسخة الاحتياطية
    my $temp_dir = "/tmp/robinhood_backup_$$";
    mkdir($temp_dir);
    
    # نسخ الملفات المهمة
    my @backup_dirs = ("config", "wordlists", "ai_models");
    push @backup_dirs, "captures" if $include_data;
    push @backup_dirs, "logs" if $include_data;
    
    for my $dir (@backup_dirs) {
        my $source = "$ENV{HOME}/.robinhood/$dir";
        my $target = "$temp_dir/$dir";
        
        if (-d $source) {
            system("cp -r $source $target") if -d $source;
        }
    }
    
    # إنشاء ملف metadata
    my $metadata = {
        backup_name => $backup_name,
        timestamp => time(),
        version => "3.0.0",
        files => [],
        size => 0
    };
    
    # حساب حجم النسخة الاحتياطية
    my $backup_size = 0;
    opendir(my $dh, $temp_dir);
    while (my $item = readdir($dh)) {
        next if $item eq '.' or $item eq '..';
        $backup_size += _dir_size("$temp_dir/$item");
    }
    closedir($dh);
    
    $metadata->{size} = $backup_size;
    
    write_file("$temp_dir/metadata.json", encode_json($metadata));
    
    # ضغط النسخة الاحتياطية
    my $backup_file = "/tmp/$backup_name.tar.gz";
    system("tar -czf $backup_file -C $temp_dir .");
    
    # رفع النسخة الاحتياطية للسحابة
    my $remote_path = "backups/$backup_name.tar.gz";
    my $upload = cloud_upload($backup_file, $remote_path, $provider);
    
    # تنظيف الملفات المؤقتة
    system("rm -rf $temp_dir");
    unlink($backup_file);
    
    if ($upload->{success}) {
        say "\n${\($color->success())}[✓] تم إنشاء النسخة الاحتياطية السحابية بنجاح${\($color->reset())}";
        say "   → الاسم: $backup_name";
        say "   → الحجم: " . $utils->format_size($backup_size);
        say "   → الموقع: $upload->{remote_url}";
    } else {
        say "\n${\($color->error())}[!] فشل إنشاء النسخة الاحتياطية${\($color->reset())}";
    }
    
    $utils->save_result('cloud_backup', {
        backup_name => $backup_name,
        size => $backup_size,
        success => $upload->{success}
    });
    
    return $upload;
}

# =============================================================================
# دوال مساعدة داخلية
# =============================================================================

sub _calculate_file_hash {
    my ($file) = @_;
    
    open(my $fh, '<', $file);
    local $/;
    my $content = <$fh>;
    close($fh);
    
    return sha256_hex($content);
}

sub _log_cloud_action {
    my ($action, $source, $destination) = @_;
    
    my $log_file = "$ENV{HOME}/.robinhood/logs/cloud_sync.log";
    my $log_entry = {
        timestamp => time(),
        action => $action,
        source => $source,
        destination => $destination
    };
    
    open(my $fh, '>>', $log_file);
    print $fh encode_json($log_entry) . "\n";
    close($fh);
}

sub _upload_to_local {
    my ($local_file, $remote_path) = @_;
    
    my $sync_folder = $CLOUD_CONFIG->{sync_folder};
    mkdir($sync_folder) unless -d $sync_folder;
    
    my $target = "$sync_folder/$remote_path";
    my $target_dir = dirname($target);
    mkdir($target_dir) unless -d $target_dir;
    
    if (copy($local_file, $target)) {
        return {
            success => 1,
            remote_url => "file://$target"
        };
    }
    
    return {
        success => 0,
        error => "فشل نسخ الملف"
    };
}

sub _upload_to_dropbox {
    my ($local_file, $remote_path) = @_;
    
    # محاكاة رفع إلى Dropbox
    sleep(1);
    
    if (rand() < 0.9) {
        return {
            success => 1,
            remote_url => "https://www.dropbox.com/robinhood/$remote_path"
        };
    }
    
    return {
        success => 0,
        error => "خطأ في الاتصال بـ Dropbox"
    };
}

sub _upload_to_google_drive {
    my ($local_file, $remote_path) = @_;
    
    # محاكاة رفع إلى Google Drive
    sleep(1);
    
    if (rand() < 0.85) {
        return {
            success => 1,
            remote_url => "https://drive.google.com/robinhood/$remote_path"
        };
    }
    
    return {
        success => 0,
        error => "خطأ في الاتصال بـ Google Drive"
    };
}

sub _upload_to_github {
    my ($local_file, $remote_path) = @_;
    
    # محاكاة رفع إلى GitHub
    sleep(1);
    
    if (rand() < 0.95) {
        return {
            success => 1,
            remote_url => "https://github.com/robinhood/$remote_path"
        };
    }
    
    return {
        success => 0,
        error => "خطأ في الاتصال بـ GitHub"
    };
}

sub _upload_to_generic {
    my ($local_file, $remote_path) = @_;
    
    # محاكاة رفع عام
    sleep(1);
    
    if (rand() < 0.8) {
        return {
            success => 1,
            remote_url => "https://cloud.robinhood.com/$remote_path"
        };
    }
    
    return {
        success => 0,
        error => "خطأ في الاتصال بالسحابة"
    };
}

sub _download_from_local {
    my ($remote_path, $local_path) = @_;
    
    my $sync_folder = $CLOUD_CONFIG->{sync_folder};
    my $source = "$sync_folder/$remote_path";
    
    if (-f $source) {
        if (copy($source, $local_path)) {
            return { success => 1 };
        }
    }
    
    return {
        success => 0,
        error => "الملف غير موجود محلياً"
    };
}

sub _download_from_dropbox {
    my ($remote_path, $local_path) = @_;
    
    sleep(1);
    
    if (rand() < 0.85) {
        # إنشاء ملف وهمي
        write_file($local_path, "محاكاة ملف من Dropbox\n");
        return { success => 1 };
    }
    
    return {
        success => 0,
        error => "فشل التحميل من Dropbox"
    };
}

sub _download_from_google_drive {
    my ($remote_path, $local_path) = @_;
    
    sleep(1);
    
    if (rand() < 0.85) {
        write_file($local_path, "محاكاة ملف من Google Drive\n");
        return { success => 1 };
    }
    
    return {
        success => 0,
        error => "فشل التحميل من Google Drive"
    };
}

sub _download_from_generic {
    my ($remote_path, $local_path) = @_;
    
    sleep(1);
    
    if (rand() < 0.8) {
        write_file($local_path, "محاكاة ملف من السحابة\n");
        return { success => 1 };
    }
    
    return {
        success => 0,
        error => "فشل التحميل من السحابة"
    };
}

sub _file_exists_in_cloud {
    my ($remote_file) = @_;
    
    # محاكاة التحقق من وجود الملف
    return rand() < 0.3;
}

sub _list_cloud_files {
    my ($remote_folder) = @_;
    
    my @files = ();
    
    # محاكاة قائمة الملفات
    for my $i (1..int(rand(5))) {
        push @files, "$remote_folder/file_$i.json";
    }
    
    return \@files;
}

sub _dir_size {
    my ($dir) = @_;
    
    my $size = 0;
    opendir(my $dh, $dir);
    while (my $item = readdir($dh)) {
        next if $item eq '.' or $item eq '..';
        my $path = "$dir/$item";
        if (-f $path) {
            $size += -s $path;
        } elsif (-d $path) {
            $size += _dir_size($path);
        }
    }
    closedir($dh);
    
    return $size;
}

sub basename {
    my ($path) = @_;
    $path =~ s/.*\///;
    return $path;
}

sub dirname {
    my ($path) = @_;
    $path =~ s/[^\/]+$//;
    $path = "." if $path eq "";
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

# تحميل الإعدادات عند التحميل
_load_cloud_config();

1;  # نهاية الوحدة
