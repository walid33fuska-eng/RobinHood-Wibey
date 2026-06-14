package integration::LogAnalyzer;
# =============================================================================
# LogAnalyzer.pm - تحليل السجلات والملفات
# =============================================================================
# الميزات: تحليل السجلات، اكتشاف الأنماط، تقارير الأمان، تنبيهات ذكية
# =============================================================================

use strict;
use warnings;
use parent 'Exporter';
our @EXPORT_OK = qw(log_analyze log_search log_report log_clean);

use lib '.';
use lib::Utils;
use lib::Colors;
use Time::HiRes qw(time);
use File::Slurp qw(read_file write_file);
use File::Find;
use List::Util qw(max min sum);
use JSON;

# =============================================================================
# تحليل السجلات
# =============================================================================
sub log_analyze {
    my ($log_file, $analysis_type, $time_range) = @_;
    
    my $color = Colors->new();
    my $utils = Utils->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    📊 تحليل السجلات 📊                               ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    $log_file //= "$ENV{HOME}/.robinhood/logs/attacks.log";
    $analysis_type //= "full";
    $time_range //= 86400;  # 24 ساعة
    
    if (!-f $log_file) {
        say "${\($color->error())}[!] ملف السجل غير موجود: $log_file${\($color->reset())}";
        return undef;
    }
    
    say "${\($color->info())}[*] تحليل ملف السجل: $log_file${\($color->reset())}";
    
    # قراءة السجلات
    my $log_content = read_file($log_file);
    my @lines = split(/\n/, $log_content);
    
    my $analysis = {
        file => $log_file,
        size => -s $log_file,
        lines => scalar(@lines),
        analysis_type => $analysis_type,
        start_time => time(),
        stats => {},
        patterns => [],
        anomalies => [],
        summary => {}
    };
    
    # تحليل حسب النوع
    if ($analysis_type eq "full" || $analysis_type eq "stats") {
        $analysis->{stats} = _calculate_stats(\@lines);
    }
    
    if ($analysis_type eq "full" || $analysis_type eq "patterns") {
        $analysis->{patterns} = _find_patterns(\@lines);
    }
    
    if ($analysis_type eq "full" || $analysis_type eq "anomalies") {
        $analysis->{anomalies} = _find_anomalies(\@lines);
    }
    
    $analysis->{duration} = time() - $analysis->{start_time};
    
    # عرض النتائج
    say "\n${\($color->quantum())}📈 نتائج التحليل:${\($color->reset())}";
    say "   → حجم الملف: " . $utils->format_size($analysis->{size});
    say "   → عدد الأسطر: $analysis->{lines}";
    say "   → وقت التحليل: " . sprintf("%.2f", $analysis->{duration}) . " ثانية";
    
    if ($analysis->{stats} && keys %{$analysis->{stats}}) {
        say "\n${\($color->info())}📊 الإحصائيات:${\($color->reset())}";
        say "   → مستوى INFO: $analysis->{stats}{info}";
        say "   → مستوى WARNING: $analysis->{stats}{warning}";
        say "   → مستوى ERROR: $analysis->{stats}{error}";
        say "   → مستوى CRITICAL: $analysis->{stats}{critical}";
    }
    
    if (scalar(@{$analysis->{patterns}}) > 0) {
        say "\n${\($color->quantum())}🎯 الأنماط المكتشفة:${\($color->reset())}";
        for my $pattern (@{$analysis->{patterns}}[0..4]) {
            say "   → $pattern->{pattern}: $pattern->{count} مرة";
        }
    }
    
    if (scalar(@{$analysis->{anomalies}}) > 0) {
        say "\n${\($color->error())}⚠️ الحالات الشاذة:${\($color->reset())}";
        for my $anomaly (@{$analysis->{anomalies}}[0..4]) {
            say "   → $anomaly->{line}";
        }
    }
    
    # حفظ التحليل
    my $analysis_file = "$ENV{HOME}/.robinhood/logs/log_analysis_" . time() . ".json";
    write_file($analysis_file, encode_json($analysis));
    say "\n${\($color->success())}[✓] تم حفظ التحليل في: $analysis_file${\($color->reset())}";
    
    $utils->save_result('log_analyzer', {
        file => $log_file,
        lines => $analysis->{lines},
        duration => $analysis->{duration},
        anomalies => scalar(@{$analysis->{anomalies}})
    });
    
    return $analysis;
}

# =============================================================================
# البحث في السجلات
# =============================================================================
sub log_search {
    my ($log_file, $pattern, $case_sensitive, $context_lines) = @_;
    
    my $color = Colors->new();
    my $utils = Utils->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    🔍 البحث في السجلات 🔍                            ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    $log_file //= "$ENV{HOME}/.robinhood/logs/attacks.log";
    $pattern //= "error";
    $case_sensitive //= 0;
    $context_lines //= 2;
    
    if (!-f $log_file) {
        say "${\($color->error())}[!] ملف السجل غير موجود: $log_file${\($color->reset())}";
        return [];
    }
    
    my $search_pattern = $case_sensitive ? qr/$pattern/ : qr/$pattern/i;
    
    say "${\($color->info())}[*] البحث عن '$pattern' في $log_file${\($color->reset())}";
    
    my @lines = read_file($log_file);
    my @results = ();
    my $line_num = 0;
    
    for my $line (@lines) {
        $line_num++;
        if ($line =~ $search_pattern) {
            my $result = {
                line_num => $line_num,
                line => $line,
                context => []
            };
            
            # إضافة سياق
            for my $i (max(0, $line_num - $context_lines - 1) .. min($#lines, $line_num + $context_lines - 1)) {
                push @{$result->{context}}, {
                    num => $i + 1,
                    text => $lines[$i]
                };
            }
            
            push @results, $result;
        }
    }
    
    say "\n${\($color->success())}✓ تم العثور على " . scalar(@results) . " نتيجة:${\($color->reset())}";
    
    for my $result (@results[0..9]) {
        say "\n   → السطر $result->{line_num}: $result->{line}";
        if (scalar(@{$result->{context}}) > 0) {
            say "      السياق:";
            for my $ctx (@{$result->{context}}) {
                say "        $ctx->{num}: $ctx->{text}";
            }
        }
    }
    
    if (scalar(@results) > 10) {
        say "\n   ... و " . (scalar(@results) - 10) . " نتيجة أخرى";
    }
    
    $utils->save_result('log_search', {
        pattern => $pattern,
        results => scalar(@results),
        case_sensitive => $case_sensitive
    });
    
    return \@results;
}

# =============================================================================
# تقرير السجلات
# =============================================================================
sub log_report {
    my ($log_file, $report_format, $output_file) = @_;
    
    my $color = Colors->new();
    my $utils = Utils->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    📋 تقرير السجلات 📋                              ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    $log_file //= "$ENV{HOME}/.robinhood/logs/attacks.log";
    $report_format //= "text";
    $output_file //= "$ENV{HOME}/.robinhood/reports/log_report_" . time() . ".$report_format";
    
    if (!-f $log_file) {
        say "${\($color->error())}[!] ملف السجل غير موجود: $log_file${\($color->reset())}";
        return 0;
    }
    
    # إنشاء مجلد التقارير
    my $report_dir = dirname($output_file);
    mkdir($report_dir) unless -d $report_dir;
    
    say "${\($color->info())}[*] إنشاء تقرير السجلات بصيغة $report_format${\($color->reset())}";
    
    # تحليل السجلات أولاً
    my $analysis = log_analyze($log_file, "full");
    
    # إنشاء التقرير
    my $report_content = "";
    
    if ($report_format eq "text") {
        $report_content = _generate_text_report($analysis);
    } elsif ($report_format eq "html") {
        $report_content = _generate_html_report($analysis);
    } elsif ($report_format eq "json") {
        $report_content = encode_json($analysis);
    } else {
        $report_content = _generate_text_report($analysis);
    }
    
    write_file($output_file, $report_content);
    
    my $size = -s $output_file;
    
    say "\n${\($color->success())}[✓] تم إنشاء التقرير:${\($color->reset())}";
    say "   → الملف: $output_file";
    say "   → الحجم: " . $utils->format_size($size);
    
    $utils->save_result('log_report', {
        format => $report_format,
        output => $output_file,
        size => $size
    });
    
    return $output_file;
}

# =============================================================================
# تنظيف السجلات القديمة
# =============================================================================
sub log_clean {
    my ($log_dir, $max_age_days, $max_size_mb) = @_;
    
    my $color = Colors->new();
    my $utils = Utils->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    🧹 تنظيف السجلات 🧹                               ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    $log_dir //= "$ENV{HOME}/.robinhood/logs/";
    $max_age_days //= 30;
    $max_size_mb //= 100;
    
    if (!-d $log_dir) {
        say "${\($color->error())}[!] مجلد السجلات غير موجود: $log_dir${\($color->reset())}";
        return 0;
    }
    
    say "${\($color->info())}[*] تنظيف السجلات الأقدم من $max_age_days يوم${\($color->reset())}";
    
    my $cleaned = {
        deleted_files => [],
        total_size_freed => 0,
        compressed_files => []
    };
    
    my $cutoff_time = time() - ($max_age_days * 86400);
    my $max_size_bytes = $max_size_mb * 1024 * 1024;
    
    find({
        wanted => sub {
            return unless -f $_;
            my $mtime = (stat($_))[9];
            
            # حذف الملفات القديمة
            if ($mtime < $cutoff_time) {
                my $size = -s $_;
                $cleaned->{total_size_freed} += $size;
                push @{$cleaned->{deleted_files}}, $_;
                unlink($_);
            }
            # ضغط الملفات الكبيرة
            elsif (-s $_ > $max_size_bytes) {
                my $compressed = "$_.gz";
                system("gzip -c $_ > $compressed");
                if (-f $compressed) {
                    unlink($_);
                    push @{$cleaned->{compressed_files}}, $_;
                }
            }
        },
        follow => 1,
        no_chdir => 1
    }, $log_dir);
    
    say "\n${\($color->success())}📊 نتائج التنظيف:${\($color->reset())}";
    say "   → عدد الملفات المحذوفة: " . scalar(@{$cleaned->{deleted_files}});
    say "   → عدد الملفات المضغوطة: " . scalar(@{$cleaned->{compressed_files}});
    say "   → المساحة المحررة: " . $utils->format_size($cleaned->{total_size_freed});
    
    $utils->save_result('log_clean', {
        deleted_files => scalar(@{$cleaned->{deleted_files}}),
        compressed_files => scalar(@{$cleaned->{compressed_files}}),
        space_freed => $cleaned->{total_size_freed}
    });
    
    return $cleaned;
}

# =============================================================================
# دوال مساعدة داخلية
# =============================================================================

sub _calculate_stats {
    my ($lines) = @_;
    
    my $stats = {
        info => 0,
        warning => 0,
        error => 0,
        critical => 0,
        total_attacks => 0,
        successful_attacks => 0
    };
    
    for my $line (@$lines) {
        $stats->{info}++ if $line =~ /\[INFO\]/i;
        $stats->{warning}++ if $line =~ /\[WARNING\]/i;
        $stats->{error}++ if $line =~ /\[ERROR\]/i;
        $stats->{critical}++ if $line =~ /\[CRITICAL\]/i;
        $stats->{total_attacks}++ if $line =~ /attack|هجوم/i;
        $stats->{successful_attacks}++ if $line =~ /success|نجاح/i;
    }
    
    return $stats;
}

sub _find_patterns {
    my ($lines) = @_;
    
    my @patterns = ();
    my %pattern_counts = ();
    
    for my $line (@$lines) {
        if ($line =~ /WPS|wps/) {
            $pattern_counts{'WPS Attack'}++;
        } elsif ($line =~ /dictionary|قاموس/i) {
            $pattern_counts{'Dictionary Attack'}++;
        } elsif ($line =~ /handshake|مصافحة/i) {
            $pattern_counts{'Handshake Capture'}++;
        } elsif ($line =~ /PMKID|pmkid/i) {
            $pattern_counts{'PMKID Attack'}++;
        } elsif ($line =~ /deauth/i) {
            $pattern_counts{'Deauth Attack'}++;
        }
    }
    
    for my $pattern (keys %pattern_counts) {
        push @patterns, {
            pattern => $pattern,
            count => $pattern_counts{$pattern}
        };
    }
    
    return \@patterns;
}

sub _find_anomalies {
    my ($lines) = @_;
    
    my @anomalies = ();
    
    for my $i (0..$#$lines) {
        my $line = $lines->[$i];
        
        # كشف الأنماط الشاذة
        if ($line =~ /fail|فشل/i && $lines->[$i+1] && $lines->[$i+1] =~ /fail|فشل/i) {
            push @anomalies, {
                line_num => $i + 1,
                line => $line,
                reason => "فشل متتالي"
            };
        }
        
        if ($line =~ /critical|حرج/i) {
            push @anomalies, {
                line_num => $i + 1,
                line => $line,
                reason => "خطأ حرج"
            };
        }
        
        if ($line =~ /attempt|محاولة/i && ($line =~ /100|200|500/)) {
            push @anomalies, {
                line_num => $i + 1,
                line => $line,
                reason => "عدد كبير من المحاولات"
            };
        }
    }
    
    return \@anomalies;
}

sub _generate_text_report {
    my ($analysis) = @_;
    
    my $report = "=" x 60 . "\n";
    $report .= "تقرير تحليل السجلات\n";
    $report .= "=" x 60 . "\n\n";
    
    $report .= "الملف: $analysis->{file}\n";
    $report .= "الحجم: $analysis->{size} بايت\n";
    $report .= "عدد الأسطر: $analysis->{lines}\n";
    $report .= "وقت التحليل: " . localtime($analysis->{start_time}) . "\n\n";
    
    $report .= "-" x 60 . "\n";
    $report .= "الإحصائيات:\n";
    $report .= "-" x 60 . "\n";
    $report .= "INFO: $analysis->{stats}{info}\n";
    $report .= "WARNING: $analysis->{stats}{warning}\n";
    $report .= "ERROR: $analysis->{stats}{error}\n";
    $report .= "CRITICAL: $analysis->{stats}{critical}\n\n";
    
    if (scalar(@{$analysis->{patterns}}) > 0) {
        $report .= "-" x 60 . "\n";
        $report .= "الأنماط المكتشفة:\n";
        $report .= "-" x 60 . "\n";
        for my $pattern (@{$analysis->{patterns}}) {
            $report .= "$pattern->{pattern}: $pattern->{count} مرة\n";
        }
        $report .= "\n";
    }
    
    if (scalar(@{$analysis->{anomalies}}) > 0) {
        $report .= "-" x 60 . "\n";
        $report .= "الحالات الشاذة:\n";
        $report .= "-" x 60 . "\n";
        for my $anomaly (@{$analysis->{anomalies}}) {
            $report .= "السطر $anomaly->{line_num}: $anomaly->{reason}\n";
        }
        $report .= "\n";
    }
    
    $report .= "=" x 60 . "\n";
    
    return $report;
}

sub _generate_html_report {
    my ($analysis) = @_;
    
    my $report = '<!DOCTYPE html>';
    $report .= '<html><head><meta charset="UTF-8">';
    $report .= '<title>تقرير تحليل السجلات</title>';
    $report .= '<style>
        body { font-family: Arial, sans-serif; margin: 20px; direction: rtl; }
        h1 { color: #333; }
        table { border-collapse: collapse; width: 100%; margin: 20px 0; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: right; }
        th { background-color: #4CAF50; color: white; }
        .anomaly { background-color: #ffeb3b; }
        .critical { background-color: #f44336; color: white; }
    </style>';
    $report .= '</head><body>';
    
    $report .= "<h1>تقرير تحليل السجلات</h1>";
    $report .= "<p><strong>الملف:</strong> $analysis->{file}</p>";
    $report .= "<p><strong>الحجم:</strong> $analysis->{size} بايت</p>";
    $report .= "<p><strong>عدد الأسطر:</strong> $analysis->{lines}</p>";
    $report .= "<p><strong>وقت التحليل:</strong> " . localtime($analysis->{start_time}) . "</p>";
    
    $report .= "<h2>الإحصائيات</h2>";
    $report .= "<table>";
    $report .= "<tr><th>المستوى</th><th>العدد</th></tr>";
    $report .= "<tr><td>INFO</td><td>$analysis->{stats}{info}</td></tr>";
    $report .= "<tr><td>WARNING</td><td>$analysis->{stats}{warning}</td></tr>";
    $report .= "<tr><td>ERROR</td><td>$analysis->{stats}{error}</td></tr>";
    $report .= "<tr><td>CRITICAL</td><td>$analysis->{stats}{critical}</td></tr>";
    $report .= "<table>";
    
    if (scalar(@{$analysis->{patterns}}) > 0) {
        $report .= "<h2>الأنماط المكتشفة</h2><ul>";
        for my $pattern (@{$analysis->{patterns}}) {
            $report .= "<li>$pattern->{pattern}: $pattern->{count} مرة</li>";
        }
        $report .= "</ul>";
    }
    
    if (scalar(@{$analysis->{anomalies}}) > 0) {
        $report .= "<h2>الحالات الشاذة</h2><ul>";
        for my $anomaly (@{$analysis->{anomalies}}) {
            $report .= "<li class='anomaly'>السطر $anomaly->{line_num}: $anomaly->{reason}</li>";
        }
        $report .= "</ul>";
    }
    
    $report .= '</body></html>';
    
    return $report;
}

sub dirname {
    my ($path) = @_;
    $path =~ s/[^\/]+$//;
    $path = "." if $path eq "";
    return $path;
}

sub max {
    my ($a, $b) = @_;
    return $a > $b ? $a : $b;
}

sub min {
    my ($a, $b) = @_;
    return $a < $b ? $a : $b;
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

1;  # نهاية الوحدة
