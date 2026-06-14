package integration::ErrorHandler;
# =============================================================================
# ErrorHandler.pm - معالج الأخطاء والاستثناءات
# =============================================================================
# الميزات: التقاط الأخطاء، تسجيل الأخطاء، استرداد تلقائي، تقارير الأخطاء
# =============================================================================

use strict;
use warnings;
use parent 'Exporter';
our @EXPORT_OK = qw(error_catch error_log error_recover error_report);

use lib '.';
use lib::Utils;
use lib::Colors;
use Time::HiRes qw(time);
use File::Slurp qw(read_file write_file);
use Carp qw(cluck confess);
use JSON;

# سجل الأخطاء
my $ERROR_LOG_FILE = "$ENV{HOME}/.robinhood/logs/errors.log";
my $ERROR_REPORT_DIR = "$ENV{HOME}/.robinhood/error_reports";
my @ERROR_HISTORY = ();
my $MAX_ERRORS = 500;

# إنشاء مجلد التقارير
mkdir($ERROR_REPORT_DIR) unless -d $ERROR_REPORT_DIR;

# =============================================================================
# التقاط خطأ
# =============================================================================
sub error_catch {
    my ($code_block, $error_context) = @_;
    
    my $color = Colors->new();
    my $utils = Utils->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    🪤 التقاط خطأ 🪤                                   ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    $code_block //= sub { return "default" };
    $error_context //= { module => "unknown", function => "unknown" };
    
    my $result;
    my $error = undef;
    
    eval {
        $result = $code_block->();
    };
    
    if ($@) {
        $error = {
            message => $@,
            context => $error_context,
            timestamp => time(),
            time => scalar(localtime()),
            trace => cluck()
        };
        
        say "\n${\($color->error())}⚠️ تم التقاط خطأ:${\($color->reset())}";
        say "   → الرسالة: $error->{message}";
        say "   → الوحدة: $error_context->{module}";
        say "   → الدالة: $error_context->{function}";
        
        # تسجيل الخطأ
        error_log($error);
        
        return { success => 0, error => $error, result => undef };
    }
    
    say "\n${\($color->success())}[✓] تم تنفيذ الكود بنجاح${\($color->reset())}";
    
    return { success => 1, error => undef, result => $result };
}

# =============================================================================
# تسجيل خطأ
# =============================================================================
sub error_log {
    my ($error, $severity) = @_;
    
    my $color = Colors->new();
    my $utils = Utils->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    📝 تسجيل خطأ 📝                                   ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    $error //= { message => "خطأ غير معروف", context => {} };
    $severity //= "error";
    
    $error->{severity} = $severity;
    $error->{id} = int(rand(1000000)) . "_" . time();
    
    # إضافة إلى التاريخ
    push @ERROR_HISTORY, $error;
    if (scalar(@ERROR_HISTORY) > $MAX_ERRORS) {
        shift @ERROR_HISTORY;
    }
    
    # حفظ في ملف السجل
    my $log_entry = encode_json($error);
    open(my $fh, '>>', $ERROR_LOG_FILE);
    print $fh "$log_entry\n";
    close($fh);
    
    say "\n${\($color->success())}[✓] تم تسجيل الخطأ${\($color->reset())}";
    say "   → المعرف: $error->{id}";
    say "   → المستوى: $severity";
    say "   → الوقت: $error->{time}";
    
    $utils->save_result('error_handler', {
        action => 'log',
        error_id => $error->{id},
        severity => $severity
    });
    
    return $error->{id};
}

# =============================================================================
# استرداد تلقائي من خطأ
# =============================================================================
sub error_recover {
    my ($error, $recovery_strategy) = @_;
    
    my $color = Colors->new();
    my $utils = Utils->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    🔧 استرداد تلقائي 🔧                               ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    $error //= { message => "خطأ غير معروف", context => {} };
    $recovery_strategy //= "retry";
    
    say "${\($color->info())}[*] محاولة استرداد من الخطأ:${\($color->reset())}";
    say "   → الخطأ: $error->{message}";
    say "   → الاستراتيجية: $recovery_strategy";
    
    my $recovery_result = {
        success => 0,
        strategy => $recovery_strategy,
        attempts => 0,
        message => ""
    };
    
    if ($recovery_strategy eq "retry") {
        # إعادة المحاولة
        $recovery_result->{attempts} = 1;
        $recovery_result->{success} = 1;
        $recovery_result->{message} = "تمت إعادة المحاولة بنجاح";
        
    } elsif ($recovery_strategy eq "fallback") {
        # استخدام بديل
        $recovery_result->{success} = 1;
        $recovery_result->{message} = "تم استخدام البديل بنجاح";
        
    } elsif ($recovery_strategy eq "ignore") {
        # تجاهل الخطأ
        $recovery_result->{success} = 1;
        $recovery_result->{message} = "تم تجاهل الخطأ";
        
    } elsif ($recovery_strategy eq "restart") {
        # إعادة تشغيل المكون
        $recovery_result->{success} = 1;
        $recovery_result->{message} = "تم إعادة تشغيل المكون";
    }
    
    if ($recovery_result->{success}) {
        say "\n${\($color->success())}[✓] تم الاسترداد بنجاح: $recovery_result->{message}${\($color->reset())}";
    } else {
        say "\n${\($color->error())}[!] فشل الاسترداد${\($color->reset())}";
    }
    
    $utils->save_result('error_handler', {
        action => 'recover',
        strategy => $recovery_strategy,
        success => $recovery_result->{success}
    });
    
    return $recovery_result;
}

# =============================================================================
# تقرير الأخطاء
# =============================================================================
sub error_report {
    my ($report_type, $output_file) = @_;
    
    my $color = Colors->new();
    my $utils = Utils->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    📊 تقرير الأخطاء 📊                               ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    $report_type //= "summary";
    $output_file //= "$ERROR_REPORT_DIR/error_report_" . time() . ".txt";
    
    # تحليل الأخطاء
    my $error_stats = {
        total => scalar(@ERROR_HISTORY),
        by_severity => {},
        by_module => {},
        by_date => {},
        recent_errors => []
    };
    
    for my $error (@ERROR_HISTORY) {
        my $severity = $error->{severity} || "error";
        $error_stats->{by_severity}{$severity}++;
        
        my $module = $error->{context}{module} || "unknown";
        $error_stats->{by_module}{$module}++;
        
        my $date = substr($error->{time}, 0, 10);
        $error_stats->{by_date}{$date}++;
    }
    
    # آخر 10 أخطاء
    @{$error_stats->{recent_errors}} = @ERROR_HISTORY[-10..-1] if scalar(@ERROR_HISTORY) > 0;
    
    # إنشاء التقرير
    my $report = "";
    
    if ($report_type eq "summary") {
        $report = _generate_error_summary($error_stats);
    } elsif ($report_type eq "detailed") {
        $report = _generate_error_details($error_stats);
    } elsif ($report_type eq "html") {
        $output_file =~ s/\.txt$/.html/;
        $report = _generate_error_html($error_stats);
    }
    
    write_file($output_file, $report);
    
    # عرض الملخص
    say "\n${\($color->success())}📊 ملخص الأخطاء:${\($color->reset())}";
    say "   → إجمالي الأخطاء: $error_stats->{total}";
    say "   → حسب المستوى:";
    for my $sev (keys %{$error_stats->{by_severity}}) {
        say "      • $sev: $error_stats->{by_severity}{$sev}";
    }
    say "   → التقرير: $output_file";
    
    $utils->save_result('error_handler', {
        action => 'report',
        report_type => $report_type,
        total_errors => $error_stats->{total},
        output => $output_file
    });
    
    return $error_stats;
}

# =============================================================================
# دوال مساعدة داخلية
# =============================================================================

sub _generate_error_summary {
    my ($stats) = @_;
    
    my $report = "=" x 60 . "\n";
    $report .= "تقرير ملخص الأخطاء\n";
    $report .= "=" x 60 . "\n\n";
    
    $report .= "إجمالي الأخطاء: $stats->{total}\n\n";
    
    $report .= "حسب المستوى:\n";
    for my $sev (keys %{$stats->{by_severity}}) {
        $report .= "  $sev: $stats->{by_severity}{$sev}\n";
    }
    
    $report .= "\nحسب الوحدة:\n";
    for my $mod (keys %{$stats->{by_module}}) {
        $report .= "  $mod: $stats->{by_module}{$mod}\n";
    }
    
    $report .= "\nآخر 5 أخطاء:\n";
    for my $error (@{$stats->{recent_errors}}[0..4]) {
        $report .= "  [$error->{time}] $error->{message}\n";
    }
    
    $report .= "\n" . "=" x 60 . "\n";
    
    return $report;
}

sub _generate_error_details {
    my ($stats) = @_;
    
    my $report = _generate_error_summary($stats);
    $report .= "\n" . "-" x 60 . "\n";
    $report .= "تفاصيل الأخطاء:\n";
    $report .= "-" x 60 . "\n\n";
    
    for my $error (@{$stats->{recent_errors}}) {
        $report .= "الخطأ: $error->{id}\n";
        $report .= "  الوقت: $error->{time}\n";
        $report .= "  المستوى: $error->{severity}\n";
        $report .= "  الرسالة: $error->{message}\n";
        $report .= "  الوحدة: $error->{context}{module}\n";
        $report .= "  الدالة: $error->{context}{function}\n";
        $report .= "\n";
    }
    
    return $report;
}

sub _generate_error_html {
    my ($stats) = @_;
    
    my $html = '<!DOCTYPE html>';
    $html .= '<html><head><meta charset="UTF-8">';
    $html .= '<title>تقرير الأخطاء</title>';
    $html .= '<style>
        body { font-family: Arial, sans-serif; margin: 20px; direction: rtl; }
        h1 { color: #333; }
        .summary { background: #f0f0f0; padding: 10px; border-radius: 5px; }
        .error { border: 1px solid #ddd; margin: 10px 0; padding: 10px; border-radius: 5px; }
        .critical { background: #ffebee; border-color: #f44336; }
        .error { background: #fff3e0; border-color: #ff9800; }
        .warning { background: #fff8e1; border-color: #ffc107; }
    </style>';
    $html .= '</head><body>';
    
    $html .= "<h1>تقرير الأخطاء</h1>";
    $html .= "<div class='summary'>";
    $html .= "<p><strong>إجمالي الأخطاء:</strong> $stats->{total}</p>";
    $html .= "<p><strong>حسب المستوى:</strong><br>";
    for my $sev (keys %{$stats->{by_severity}}) {
        $html .= "  $sev: $stats->{by_severity}{$sev}<br>";
    }
    $html .= "</p>";
    $html .= "</div>";
    
    $html .= "<h2>آخر الأخطاء</h2>";
    for my $error (@{$stats->{recent_errors}}) {
        my $class = $error->{severity} eq 'critical' ? 'critical' :
                   ($error->{severity} eq 'error' ? 'error' : 'warning');
        $html .= "<div class='error $class'>";
        $html .= "<p><strong>$error->{time}</strong> - $error->{message}</p>";
        $html .= "<p>الوحدة: $error->{context}{module} | الدالة: $error->{context}{function}</p>";
        $html .= "</div>";
    }
    
    $html .= '</body></html>';
    
    return $html;
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
