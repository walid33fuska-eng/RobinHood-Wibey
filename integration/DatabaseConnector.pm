package integration::DatabaseConnector;
# =============================================================================
# DatabaseConnector.pm - الاتصال بقواعد البيانات
# =============================================================================
# الميزات: دعم SQLite، MySQL، PostgreSQL، تخزين النتائج، استعلامات متقدمة
# =============================================================================

use strict;
use warnings;
use parent 'Exporter';
our @EXPORT_OK = qw(db_connect db_query db_insert db_backup db_export);

use lib '.';
use lib::Utils;
use lib::Colors;
use Time::HiRes qw(time);
use File::Slurp qw(read_file write_file);
use DBI;
use JSON;

# إعدادات قاعدة البيانات الافتراضية
my $DB_TYPE = "sqlite";
my $DB_NAME = "$ENV{HOME}/.robinhood/robinhood.db";
my $DB_HOST = "localhost";
my $DB_PORT = 3306;
my $DB_USER = "";
my $DB_PASS = "";
my $DBH = undef;

# =============================================================================
# الاتصال بقاعدة البيانات
# =============================================================================
sub db_connect {
    my ($type, $database, $host, $port, $user, $password) = @_;
    
    my $color = Colors->new();
    my $utils = Utils->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    🗄️ الاتصال بقاعدة البيانات 🗄️                      ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    $type //= "sqlite";
    $database //= $DB_NAME;
    $host //= $DB_HOST;
    $port //= $DB_PORT;
    $user //= $DB_USER;
    $password //= $DB_PASS;
    
    say "${\($color->info())}[*] الاتصال بقاعدة بيانات $type${\($color->reset())}";
    
    # إغلاق الاتصال السابق إن وجد
    if ($DBH) {
        $DBH->disconnect();
        $DBH = undef;
    }
    
    # بناء سلسلة الاتصال
    my $dsn;
    if ($type eq "sqlite") {
        $dsn = "dbi:SQLite:dbname=$database";
        say "   → الملف: $database";
    } elsif ($type eq "mysql") {
        $dsn = "dbi:mysql:database=$database;host=$host;port=$port";
        say "   → الخادم: $host:$port";
        say "   → المستخدم: $user";
    } elsif ($type eq "postgresql") {
        $dsn = "dbi:Pg:database=$database;host=$host;port=$port";
        say "   → الخادم: $host:$port";
        say "   → المستخدم: $user";
    } else {
        say "${\($color->error())}[!] نوع قاعدة بيانات غير معروف: $type${\($color->reset())}";
        return 0;
    }
    
    # محاولة الاتصال
    eval {
        if ($type eq "sqlite") {
            $DBH = DBI->connect($dsn, "", "", { RaiseError => 1, AutoCommit => 1 });
        } else {
            $DBH = DBI->connect($dsn, $user, $password, { RaiseError => 1, AutoCommit => 1 });
        }
    };
    
    if ($@) {
        say "\n${\($color->error())}[!] فشل الاتصال: $@${\($color->reset())}";
        return 0;
    }
    
    # إنشاء الجداول إذا لم تكن موجودة (لـ SQLite)
    if ($type eq "sqlite") {
        _create_tables();
    }
    
    $DB_TYPE = $type;
    
    say "\n${\($color->success())}[✓] تم الاتصال بقاعدة البيانات بنجاح${\($color->reset())}";
    
    $utils->save_result('database_connector', {
        action => 'connect',
        type => $type,
        database => $database
    });
    
    return 1;
}

# =============================================================================
# تنفيذ استعلام
# =============================================================================
sub db_query {
    my ($sql, $params) = @_;
    
    my $color = Colors->new();
    my $utils = Utils->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    🔍 تنفيذ استعلام 🔍                               ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    if (!$DBH) {
        say "${\($color->error())}[!] لا يوجد اتصال بقاعدة البيانات${\($color->reset())}";
        return undef;
    }
    
    $sql //= "SELECT * FROM attacks LIMIT 10";
    $params //= [];
    
    say "${\($color->info())}[*] تنفيذ الاستعلام:${\($color->reset())}";
    say "   → $sql";
    
    my $sth = $DBH->prepare($sql);
    
    if (!$sth) {
        say "${\($color->error())}[!] خطأ في تحضير الاستعلام: " . $DBH->errstr() . "${\($color->reset())}";
        return undef;
    }
    
    my $result = $sth->execute(@$params);
    
    if (!$result) {
        say "${\($color->error())}[!] خطأ في تنفيذ الاستعلام: " . $sth->errstr() . "${\($color->reset())}";
        return undef;
    }
    
    my $data = $sth->fetchall_arrayref({});
    my $rows = scalar(@$data);
    
    say "\n${\($color->success())}[✓] تم تنفيذ الاستعلام بنجاح ($rows صف)${\($color->reset())}";
    
    if ($rows > 0 && $rows <= 20) {
        say "\n${\($color->info())}📊 النتائج:${\($color->reset())}";
        for my $row (@$data) {
            my $preview = substr(encode_json($row), 0, 100);
            say "   → $preview";
        }
    } elsif ($rows > 20) {
        say "   → تم استرجاع $rows صف (يتم عرض أول 20 فقط)";
    }
    
    $utils->save_result('database_query', {
        sql => substr($sql, 0, 100),
        rows => $rows,
        success => 1
    });
    
    return $data;
}

# =============================================================================
# إدراج بيانات
# =============================================================================
sub db_insert {
    my ($table, $data) = @_;
    
    my $color = Colors->new();
    my $utils = Utils->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    📝 إدراج بيانات 📝                                ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    if (!$DBH) {
        say "${\($color->error())}[!] لا يوجد اتصال بقاعدة البيانات${\($color->reset())}";
        return 0;
    }
    
    $table //= "attacks";
    $data //= { name => "test_attack", status => "completed", timestamp => time() };
    
    my $columns = join(", ", keys %$data);
    my $placeholders = join(", ", map { "?" } keys %$data);
    my $values = [values %$data];
    
    my $sql = "INSERT INTO $table ($columns) VALUES ($placeholders)";
    
    say "${\($color->info())}[*] إدراج بيانات في جدول $table${\($color->reset())}";
    say "   → الحقول: $columns";
    
    my $sth = $DBH->prepare($sql);
    
    if (!$sth) {
        say "${\($color->error())}[!] خطأ في تحضير الإدراج: " . $DBH->errstr() . "${\($color->reset())}";
        return 0;
    }
    
    my $result = $sth->execute(@$values);
    
    if (!$result) {
        say "${\($color->error())}[!] خطأ في إدراج البيانات: " . $sth->errstr() . "${\($color->reset())}";
        return 0;
    }
    
    my $insert_id = $DBH->last_insert_id("", "", $table, "");
    
    say "\n${\($color->success())}[✓] تم إدراج البيانات بنجاح (ID: $insert_id)${\($color->reset())}";
    
    $utils->save_result('database_insert', {
        table => $table,
        id => $insert_id,
        columns => scalar(keys %$data)
    });
    
    return $insert_id;
}

# =============================================================================
# نسخ احتياطي لقاعدة البيانات
# =============================================================================
sub db_backup {
    my ($backup_path) = @_;
    
    my $color = Colors->new();
    my $utils = Utils->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    💾 نسخ احتياطي لقاعدة البيانات 💾                  ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    $backup_path //= "$ENV{HOME}/.robinhood/backups/";
    
    # إنشاء مجلد النسخ الاحتياطي
    mkdir($backup_path) unless -d $backup_path;
    
    my $timestamp = time();
    my $backup_file = "$backup_path/robinhood_backup_$timestamp.db";
    
    say "${\($color->info())}[*] إنشاء نسخة احتياطية لقاعدة البيانات...${\($color->reset())}";
    
    if ($DB_TYPE eq "sqlite") {
        # نسخ ملف SQLite
        if (-f $DB_NAME) {
            copy($DB_NAME, $backup_file);
            say "   → الملف المصدر: $DB_NAME";
            say "   → الملف الهدف: $backup_file";
        } else {
            say "${\($color->error())}[!] ملف قاعدة البيانات غير موجود${\($color->reset())}";
            return 0;
        }
    } else {
        # تصدير قاعدة بيانات MySQL/PostgreSQL
        my $export_data = _export_database();
        write_file($backup_file . ".json", encode_json($export_data));
        say "   → تم تصدير البيانات إلى: $backup_file.json";
    }
    
    # ضغط الملف
    my $compressed_file = $backup_file . ".gz";
    if (-f $backup_file) {
        system("gzip -c $backup_file > $compressed_file");
        unlink($backup_file);
        $backup_file = $compressed_file;
    }
    
    my $size = -s $backup_file;
    my $size_mb = $size / (1024 * 1024);
    
    say "\n${\($color->success())}[✓] تم إنشاء النسخة الاحتياطية بنجاح${\($color->reset())}";
    say "   → الملف: $backup_file";
    say "   → الحجم: " . sprintf("%.2f", $size_mb) . " MB";
    say "   → الوقت: " . localtime($timestamp);
    
    $utils->save_result('database_backup', {
        backup_file => $backup_file,
        size_mb => sprintf("%.2f", $size_mb),
        timestamp => $timestamp
    });
    
    return $backup_file;
}

# =============================================================================
# تصدير البيانات
# =============================================================================
sub db_export {
    my ($format, $output_file) = @_;
    
    my $color = Colors->new();
    my $utils = Utils->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    📤 تصدير البيانات 📤                              ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    if (!$DBH) {
        say "${\($color->error())}[!] لا يوجد اتصال بقاعدة البيانات${\($color->reset())}";
        return 0;
    }
    
    $format //= "json";
    $output_file //= "$ENV{HOME}/.robinhood/exports/export_" . time() . ".$format";
    
    # إنشاء مجلد التصدير
    my $export_dir = dirname($output_file);
    mkdir($export_dir) unless -d $export_dir;
    
    say "${\($color->info())}[*] تصدير البيانات بتنسيق $format إلى $output_file${\($color->reset())}";
    
    # جلب جميع البيانات
    my $all_data = {};
    my $tables = _get_table_list();
    
    for my $table (@$tables) {
        my $data = db_query("SELECT * FROM $table");
        $all_data->{$table} = $data;
    }
    
    # تصدير حسب التنسيق
    if ($format eq "json") {
        write_file($output_file, encode_json($all_data));
    } elsif ($format eq "csv") {
        _export_to_csv($all_data, $output_file);
    } elsif ($format eq "xml") {
        _export_to_xml($all_data, $output_file);
    } else {
        say "${\($color->error())}[!] تنسيق غير معروف: $format${\($color->reset())}";
        return 0;
    }
    
    my $size = -s $output_file;
    my $size_mb = $size / (1024 * 1024);
    
    say "\n${\($color->success())}[✓] تم تصدير البيانات بنجاح${\($color->reset())}";
    say "   → الملف: $output_file";
    say "   → الحجم: " . sprintf("%.2f", $size_mb) . " MB";
    say "   → عدد الجداول: " . scalar(@$tables);
    
    $utils->save_result('database_export', {
        format => $format,
        output_file => $output_file,
        tables => scalar(@$tables)
    });
    
    return $output_file;
}

# =============================================================================
# دوال مساعدة داخلية
# =============================================================================

sub _create_tables {
    my $color = Colors->new();
    
    # جدول الهجمات
    my $sql_attacks = "
        CREATE TABLE IF NOT EXISTS attacks (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            target TEXT,
            status TEXT,
            result TEXT,
            start_time INTEGER,
            end_time INTEGER,
            duration INTEGER,
            details TEXT
        )
    ";
    
    # جدول النتائج
    my $sql_results = "
        CREATE TABLE IF NOT EXISTS results (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            attack_id INTEGER,
            success INTEGER,
            password TEXT,
            data TEXT,
            timestamp INTEGER
        )
    ";
    
    # جدول السجلات
    my $sql_logs = "
        CREATE TABLE IF NOT EXISTS logs (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            level TEXT,
            message TEXT,
            timestamp INTEGER
        )
    ";
    
    # جدول الإعدادات
    my $sql_settings = "
        CREATE TABLE IF NOT EXISTS settings (
            key TEXT PRIMARY KEY,
            value TEXT,
            updated_at INTEGER
        )
    ";
    
    $DBH->do($sql_attacks);
    $DBH->do($sql_results);
    $DBH->do($sql_logs);
    $DBH->do($sql_settings);
    
    say "${\($color->info())}[✓] تم إنشاء الجداول بنجاح${\($color->reset())}";
}

sub _get_table_list {
    my $tables = [];
    
    if ($DB_TYPE eq "sqlite") {
        my $data = db_query("SELECT name FROM sqlite_master WHERE type='table'");
        for my $row (@$data) {
            push @$tables, $row->{name};
        }
    } else {
        # محاكاة لجداول MySQL/PostgreSQL
        $tables = ["attacks", "results", "logs", "settings"];
    }
    
    return $tables;
}

sub _export_database {
    my $all_data = {};
    my $tables = _get_table_list();
    
    for my $table (@$tables) {
        my $data = db_query("SELECT * FROM $table");
        $all_data->{$table} = $data;
    }
    
    return $all_data;
}

sub _export_to_csv {
    my ($data, $filename) = @_;
    
    open(my $fh, '>', $filename);
    
    for my $table (keys %$data) {
        print $fh "\n# Table: $table\n";
        my $rows = $data->{$table};
        
        if (scalar(@$rows) > 0) {
            my $headers = join(",", keys %{$rows->[0]});
            print $fh "$headers\n";
            
            for my $row (@$rows) {
                my @values = map { "\"$_" . "\"" } values %$row;
                print $fh join(",", @values) . "\n";
            }
        }
    }
    
    close($fh);
}

sub _export_to_xml {
    my ($data, $filename) = @_;
    
    open(my $fh, '>', $filename);
    print $fh "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n";
    print $fh "<database>\n";
    
    for my $table (keys %$data) {
        print $fh "  <table name=\"$table\">\n";
        
        my $rows = $data->{$table};
        for my $row (@$rows) {
            print $fh "    <row>\n";
            for my $key (keys %$row) {
                my $value = $row->{$key};
                $value =~ s/&/&amp;/g;
                $value =~ s/</&lt;/g;
                $value =~ s/>/&gt;/g;
                print $fh "      <$key>$value</$key>\n";
            }
            print $fh "    </row>\n";
        }
        
        print $fh "  </table>\n";
    }
    
    print $fh "</database>\n";
    close($fh);
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

1;  # نهاية الوحدة
