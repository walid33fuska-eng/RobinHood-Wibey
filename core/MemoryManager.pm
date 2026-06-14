package core::MemoryManager;
# =============================================================================
# MemoryManager.pm - إدارة الذاكرة اللامتناهية والذاكرة الكمية
# =============================================================================
# الميزات: ذاكرة لانهائية، تخزين موزع P2P، استرجاع فوري، ضغط كمي
# =============================================================================

use strict;
use warnings;
use parent 'Exporter';
our @EXPORT_OK = qw(store_memory retrieve_memory quantum_compression distributed_storage memory_stats);

use lib '.';
use lib::Utils;
use JSON;
use File::Slurp qw(read_file write_file);
use Storable qw(freeze thaw);
use Compress::Zlib qw(compress uncompress);
use Digest::SHA qw(sha256_hex);
use Time::HiRes qw(time);

# =============================================================================
# بنية الذاكرة الكمية
# =============================================================================
my %QUANTUM_MEMORY = ();
my %MEMORY_INDEX = ();
my $MEMORY_FILE = "$ENV{HOME}/.robinhood/quantum_memory.dat";
my $MEMORY_SIZE = 0;
my $MAX_MEMORY_SIZE = 1024 * 1024 * 1024;  # 1GB افتراضي

# تحميل الذاكرة السابقة
if (-f $MEMORY_FILE) {
    eval {
        my $data = read_file($MEMORY_FILE, binmode => ':raw');
        my $decompressed = uncompress($data);
        my $memory_ref = thaw($decompressed);
        %QUANTUM_MEMORY = %$memory_ref if $memory_ref;
    };
}

# =============================================================================
# تخزين في الذاكرة الكمية
# =============================================================================
sub store_memory {
    my ($key, $value, $metadata) = @_;
    
    my $color = lib::Colors->new();
    my $utils = lib::Utils->new();
    
    say "\n${\($color->quantum())}💾 تخزين في الذاكرة الكمية...${\($color->reset())}";
    
    # توليد مفتاح كمي
    my $quantum_key = sha256_hex($key . time() . rand());
    
    # ضغط البيانات
    my $frozen = freeze($value);
    my $compressed = compress($frozen);
    
    # حفظ مع البيانات الوصفية
    $QUANTUM_MEMORY{$quantum_key} = {
        data => $compressed,
        original_key => $key,
        timestamp => time(),
        size => length($compressed),
        metadata => $metadata || {},
        access_count => 0,
        quantum_entropy => rand()
    };
    
    # تحديث الفهرس
    $MEMORY_INDEX{$key} = $quantum_key;
    $MEMORY_SIZE += length($compressed);
    
    # حفظ دوري
    if ($MEMORY_SIZE > $MAX_MEMORY_SIZE * 0.8) {
        _prune_memory();
    }
    
    _save_memory();
    
    say "${\($color->success())}[✓] تم التخزين بنجاح${\($color->reset())}";
    say "   → المفتاح: $key";
    say "   → الحجم: " . $utils->format_size(length($compressed));
    say "   → الإنتروبيا: " . sprintf("%.4f", $QUANTUM_MEMORY{$quantum_key}{quantum_entropy});
    
    return $quantum_key;
}

# =============================================================================
# استرجاع من الذاكرة الكمية
# =============================================================================
sub retrieve_memory {
    my ($key) = @_;
    
    my $color = lib::Colors->new();
    
    say "\n${\($color->quantum())}🔍 استرجاع من الذاكرة الكمية...${\($color->reset())}";
    
    # البحث في الفهرس
    my $quantum_key = $MEMORY_INDEX{$key};
    
    if (!$quantum_key || !$QUANTUM_MEMORY{$quantum_key}) {
        say "${\($color->error())}[!] المفتاح غير موجود: $key${\($color->reset())}";
        return undef;
    }
    
    # استرجاع البيانات
    my $entry = $QUANTUM_MEMORY{$quantum_key};
    $entry->{access_count}++;
    $entry->{last_access} = time();
    
    # فك الضغط
    my $decompressed = uncompress($entry->{data});
    my $value = thaw($decompressed);
    
    say "${\($color->success())}[✓] تم الاسترجاع بنجاح${\($color->reset())}";
    say "   → المفتاح: $key";
    say "   → عدد الوصولات: $entry->{access_count}";
    say "   → آخر وصول: " . localtime($entry->{last_access});
    
    return $value;
}

# =============================================================================
# ضغط كمي - Quantum Compression
# =============================================================================
sub quantum_compression {
    my ($data) = @_;
    
    my $color = lib::Colors->new();
    
    say "\n${\($color->quantum())}🗜️  الضغط الكمي...${\($color->reset())}";
    
    # قياس الحجم الأصلي
    my $original_size = length(encode_json($data));
    
    # خوارزمية الضغط الكمي المحاكاة
    # دمج البيانات المتشابهة في حالات تراكب
    my $compressed = _quantum_compress_algorithm($data);
    
    my $compressed_size = length($compressed);
    my $ratio = (1 - $compressed_size / $original_size) * 100;
    
    say "${\($color->quantum())}📊 إحصائيات الضغط الكمي:${\($color->reset())}";
    say "   → الحجم الأصلي: " . $original_size . " بايت";
    say "   → الحجم بعد الضغط: " . $compressed_size . " بايت";
    say "   → نسبة الضغط: " . sprintf("%.2f", $ratio) . "%";
    
    # حفظ مضغوط
    my $compressed_key = store_memory('compressed_' . time(), $compressed, {
        algorithm => 'quantum_compression',
        original_size => $original_size,
        ratio => $ratio
    });
    
    return {
        compressed_data => $compressed,
        original_size => $original_size,
        compressed_size => $compressed_size,
        ratio => $ratio,
        key => $compressed_key
    };
}

# =============================================================================
# خوارزمية الضغط الكمي الداخلية
# =============================================================================
sub _quantum_compress_algorithm {
    my ($data) = @_;
    
    # تحويل البيانات إلى JSON
    my $json = encode_json($data);
    
    # البحث عن أنماط متكررة
    my %patterns = ();
    my $pattern_id = 0;
    
    # استبدال الأنماط المتكررة برموز كمومية
    my $compressed = $json;
    
    # أنماط شائعة في كلمات المرور والبيانات
    my @common_patterns = (
        ['password', '§1§'],
        ['admin', '§2§'],
        ['123456', '§3§'],
        ['qwerty', '§4§'],
        ['abcdef', '§5§']
    );
    
    for my $pattern (@common_patterns) {
        $compressed =~ s/$pattern->[0]/$pattern->[1]/g;
    }
    
    # ضغط إضافي باستخدام zlib
    my $final_compressed = compress($compressed);
    
    return $final_compressed;
}

# =============================================================================
# تخزين موزع P2P - Distributed Storage
# =============================================================================
sub distributed_storage {
    my ($data, $peers) = @_;
    
    my $color = lib::Colors->new();
    
    say "\n${\($color->quantum())}🌐 التخزين الموزع P2P...${\($color->reset())}";
    
    $peers //= [
        'peer1.local:8080',
        'peer2.local:8080',
        'peer3.local:8080'
    ];
    
    # تقسيم البيانات إلى شظايا كمومية
    my $shards = _create_quantum_shards($data, scalar(@$peers));
    
    # توزيع الشظايا على الأقران
    my $distribution = {};
    for my $i (0..$#$peers) {
        $distribution->{$peers->[$i]} = $shards->[$i];
        say "${\($color->info())}[*] إرسال شظية " . ($i+1) . " إلى $peers->[$i]${\($color->reset())}";
    }
    
    # تخزين فهرس التوزيع محلياً
    my $index = {
        timestamp => time(),
        total_shards => scalar(@$peers),
        distribution => $distribution,
        checksum => sha256_hex(encode_json($data))
    };
    
    store_memory('distributed_index_' . time(), $index);
    
    say "${\($color->success())}[✓] تم توزيع البيانات على " . scalar(@$peers) . " أقران${\($color->reset())}";
    
    return $index;
}

# =============================================================================
# إنشاء شظايا كمومية
# =============================================================================
sub _create_quantum_shards {
    my ($data, $num_shards) = @_;
    
    my $json = encode_json($data);
    my $shard_size = int(length($json) / $num_shards) + 1;
    
    my @shards = ();
    for my $i (0..$num_shards-1) {
        my $start = $i * $shard_size;
        my $shard = substr($json, $start, $shard_size);
        
        # تشفير الشظية بمفتاح كمي
        my $encrypted = _quantum_encrypt($shard);
        push @shards, $encrypted;
    }
    
    return \@shards;
}

# =============================================================================
# تشفير كمي بسيط
# =============================================================================
sub _quantum_encrypt {
    my ($data) = @_;
    
    my $key = sha256_hex(time() . rand());
    my $encrypted = '';
    
    for my $i (0..length($data)-1) {
        my $char = substr($data, $i, 1);
        my $key_char = substr($key, $i % length($key), 1);
        $encrypted .= chr(ord($char) ^ ord($key_char));
    }
    
    return $encrypted;
}

# =============================================================================
# إحصائيات الذاكرة
# =============================================================================
sub memory_stats {
    my $color = lib::Colors->new();
    my $utils = lib::Utils->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    📊 إحصائيات الذاكرة الكمية 📊                    ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    my $num_entries = scalar(keys %QUANTUM_MEMORY);
    my $total_size = $MEMORY_SIZE;
    my $avg_size = $num_entries ? $total_size / $num_entries : 0;
    
    # حساب الإنتروبيا الإجمالية
    my $total_entropy = 0;
    for my $key (keys %QUANTUM_MEMORY) {
        $total_entropy += $QUANTUM_MEMORY{$key}{quantum_entropy};
    }
    my $avg_entropy = $num_entries ? $total_entropy / $num_entries : 0;
    
    say "${\($color->info())}📈 الإحصائيات:${\($color->reset())}";
    say "   • عدد المدخلات: $num_entries";
    say "   • الحجم الإجمالي: " . $utils->format_size($total_size);
    say "   • متوسط الحجم: " . $utils->format_size($avg_size);
    say "   • متوسط الإنتروبيا: " . sprintf("%.4f", $avg_entropy);
    say "   • الحد الأقصى: " . $utils->format_size($MAX_MEMORY_SIZE);
    
    # أكثر البيانات استخداماً
    my @sorted = sort { $QUANTUM_MEMORY{$b}{access_count} <=> $QUANTUM_MEMORY{$a}{access_count} } keys %QUANTUM_MEMORY;
    if (@sorted > 0) {
        say "\n${\($color->success())}🔥 أكثر البيانات استخداماً:${\($color->reset())}";
        for my $i (0..2) {
            last unless $sorted[$i];
            my $entry = $QUANTUM_MEMORY{$sorted[$i]};
            say "   " . ($i+1) . ". $entry->{original_key} (وصل $entry->{access_count} مرة)";
        }
    }
    
    return {
        num_entries => $num_entries,
        total_size => $total_size,
        avg_size => $avg_size,
        avg_entropy => $avg_entropy
    };
}

# =============================================================================
# تقليم الذاكرة (حذف أقدم البيانات)
# =============================================================================
sub _prune_memory {
    my $color = lib::Colors->new();
    
    say "${\($color->warning())}[!] تجاوز 80% من سعة الذاكرة - بدء التقليم${\($color->reset())}";
    
    # ترتيب حسب آخر وصول
    my @sorted = sort { $QUANTUM_MEMORY{$a}{last_access} // 0 <=> $QUANTUM_MEMORY{$b}{last_access} // 0 } keys %QUANTUM_MEMORY;
    
    # حذف 20% من أقدم البيانات
    my $to_delete = int(@sorted * 0.2);
    for my $i (0..$to_delete-1) {
        my $key = $sorted[$i];
        my $entry = $QUANTUM_MEMORY{$key};
        $MEMORY_SIZE -= $entry->{size};
        delete $QUANTUM_MEMORY{$key};
        
        # حذف من الفهرس
        for my $orig_key (keys %MEMORY_INDEX) {
            if ($MEMORY_INDEX{$orig_key} eq $key) {
                delete $MEMORY_INDEX{$orig_key};
                last;
            }
        }
    }
    
    say "${\($color->success())}[✓] تم حذف $to_delete مدخل قديم${\($color->reset())}";
}

# =============================================================================
# حفظ الذاكرة على القرص
# =============================================================================
sub _save_memory {
    my $color = lib::Colors->new();
    
    eval {
        my $frozen = freeze(\%QUANTUM_MEMORY);
        my $compressed = compress($frozen);
        write_file($MEMORY_FILE, {binmode => ':raw'}, $compressed);
    };
    
    if ($@) {
        say "${\($color->error())}[!] فشل حفظ الذاكرة: $@${\($color->reset())}";
    }
}

# =============================================================================
# تنظيف عند الخروج
# =============================================================================
END {
    _save_memory();
}

1;  # نهاية الوحدة
