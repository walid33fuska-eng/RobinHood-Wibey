package post::PDFReporter;
# =============================================================================
# PDFReporter.pm - إنشاء تقارير PDF متقدمة
# =============================================================================
# الميزات: إنشاء تقارير PDF، جداول ورسوم بيانية، توقيع رقمي، تصدير احترافي
# =============================================================================

use strict;
use warnings;
use parent 'Exporter';
our @EXPORT_OK = qw(pdf_create pdf_add_section pdf_add_table pdf_add_chart pdf_sign);

use lib '.';
use lib::Utils;
use lib::Colors;
use Time::HiRes qw(time);
use File::Slurp qw(read_file write_file);
use JSON;

# =============================================================================
# إنشاء تقرير PDF
# =============================================================================
sub pdf_create {
    my ($title, $author, $sections, $output_file) = @_;
    
    my $color = Colors->new();
    my $utils = Utils->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    📄 إنشاء تقرير PDF 📄                             ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    $title //= "تقرير RobinHood Wibey";
    $author //= "walid33fuska-eng";
    $sections //= [];
    $output_file //= "$ENV{HOME}/.robinhood/reports/report_" . time() . ".pdf";
    
    say "${\($color->info())}[*] إنشاء تقرير PDF: $title${\($color->reset())}";
    
    # إنشاء مجلد التقارير
    my $report_dir = dirname($output_file);
    mkdir($report_dir) unless -d $report_dir;
    
    # إنشاء التقرير
    my $pdf_data = {
        title => $title,
        author => $author,
        created_at => time(),
        created_time => scalar(localtime()),
        sections => $sections,
        version => "1.0"
    };
    
    # محاكاة إنشاء PDF
    my $pdf_content = _generate_pdf_content($pdf_data);
    write_file($output_file, $pdf_content);
    
    my $size = -s $output_file;
    
    say "\n${\($color->success())}[✓] تم إنشاء التقرير بنجاح:${\($color->reset())}";
    say "   → العنوان: $title";
    say "   → المؤلف: $author";
    say "   → الملف: $output_file";
    say "   → الحجم: " . $utils->format_size($size);
    say "   → عدد الأقسام: " . scalar(@$sections);
    
    $utils->save_result('pdf_reporter', {
        action => 'create',
        title => $title,
        output => $output_file,
        size => $size,
        sections => scalar(@$sections)
    });
    
    return $output_file;
}

# =============================================================================
# إضافة قسم إلى التقرير
# =============================================================================
sub pdf_add_section {
    my ($pdf_file, $section_title, $section_content, $section_level) = @_;
    
    my $color = Colors->new();
    my $utils = Utils->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    📑 إضافة قسم إلى التقرير 📑                        ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    $pdf_file //= "";
    $section_title //= "قسم جديد";
    $section_content //= "محتوى القسم";
    $section_level //= 1;
    
    if (!-f $pdf_file) {
        say "${\($color->error())}[!] ملف PDF غير موجود: $pdf_file${\($color->reset())}";
        return 0;
    }
    
    say "${\($color->info())}[*] إضافة قسم: $section_title (المستوى $section_level)${\($color->reset())}";
    
    # محاكاة إضافة قسم إلى PDF
    my $section = {
        title => $section_title,
        content => $section_content,
        level => $section_level,
        added_at => time()
    };
    
    # تحديث ملف PDF (محاكاة)
    my $pdf_content = read_file($pdf_file);
    my $updated_content = $pdf_content . "\n<!-- SECTION: " . encode_json($section) . " -->\n";
    write_file($pdf_file, $updated_content);
    
    say "\n${\($color->success())}[✓] تم إضافة القسم بنجاح${\($color->reset())}";
    
    $utils->save_result('pdf_reporter', {
        action => 'add_section',
        pdf_file => $pdf_file,
        section_title => $section_title,
        section_level => $section_level
    });
    
    return 1;
}

# =============================================================================
# إضافة جدول إلى التقرير
# =============================================================================
sub pdf_add_table {
    my ($pdf_file, $table_title, $headers, $rows, $caption) = @_;
    
    my $color = Colors->new();
    my $utils = Utils->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    📊 إضافة جدول إلى التقرير 📊                       ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    $pdf_file //= "";
    $table_title //= "جدول البيانات";
    $headers //= ["العمود 1", "العمود 2", "العمود 3"];
    $rows //= [["بيان 1", "بيان 2", "بيان 3"], ["بيان 4", "بيان 5", "بيان 6"]];
    $caption //= "";
    
    if (!-f $pdf_file) {
        say "${\($color->error())}[!] ملف PDF غير موجود: $pdf_file${\($color->reset())}";
        return 0;
    }
    
    say "${\($color->info())}[*] إضافة جدول: $table_title (أبعاد: " . scalar(@$rows) . "x" . scalar(@$headers) . ")${\($color->reset())}";
    
    # إنشاء تمثيل للجدول
    my $table_html = _generate_table_html($table_title, $headers, $rows, $caption);
    
    # إضافة إلى PDF
    my $pdf_content = read_file($pdf_file);
    my $updated_content = $pdf_content . "\n<!-- TABLE: " . encode_json({ title => $table_title, html => $table_html }) . " -->\n";
    write_file($pdf_file, $updated_content);
    
    say "\n${\($color->success())}[✓] تم إضافة الجدول بنجاح${\($color->reset())}";
    
    $utils->save_result('pdf_reporter', {
        action => 'add_table',
        pdf_file => $pdf_file,
        table_title => $table_title,
        rows => scalar(@$rows),
        cols => scalar(@$headers)
    });
    
    return 1;
}

# =============================================================================
# إضافة رسم بياني
# =============================================================================
sub pdf_add_chart {
    my ($pdf_file, $chart_title, $chart_type, $data, $labels) = @_;
    
    my $color = Colors->new();
    my $utils = Utils->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    📈 إضافة رسم بياني 📈                              ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    $pdf_file //= "";
    $chart_title //= "رسم بياني";
    $chart_type //= "bar";
    $data //= [10, 20, 30, 40, 50];
    $labels //= ["أ", "ب", "ج", "د", "ه"];
    
    if (!-f $pdf_file) {
        say "${\($color->error())}[!] ملف PDF غير موجود: $pdf_file${\($color->reset())}";
        return 0;
    }
    
    say "${\($color->info())}[*] إضافة رسم بياني: $chart_title (نوع: $chart_type)${\($color->reset())}";
    
    # إنشاء تمثيل للرسم البياني
    my $chart_ascii = _generate_chart_ascii($chart_type, $data, $labels);
    
    # إضافة إلى PDF
    my $pdf_content = read_file($pdf_file);
    my $updated_content = $pdf_content . "\n<!-- CHART: " . encode_json({ 
        title => $chart_title, 
        type => $chart_type, 
        ascii => $chart_ascii 
    }) . " -->\n";
    write_file($pdf_file, $updated_content);
    
    say "\n${\($color->success())}[✓] تم إضافة الرسم البياني بنجاح${\($color->reset())}";
    
    $utils->save_result('pdf_reporter', {
        action => 'add_chart',
        pdf_file => $pdf_file,
        chart_title => $chart_title,
        chart_type => $chart_type,
        data_points => scalar(@$data)
    });
    
    return 1;
}

# =============================================================================
# توقيع رقمي على التقرير
# =============================================================================
sub pdf_sign {
    my ($pdf_file, $signer_name, $signer_title, $signature_data) = @_;
    
    my $color = Colors->new();
    my $utils = Utils->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    ✍️ توقيع رقمي على التقرير ✍️                       ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    $pdf_file //= "";
    $signer_name //= "walid33fuska-eng";
    $signer_title //= "المطور الرئيسي";
    $signature_data //= "";
    
    if (!-f $pdf_file) {
        say "${\($color->error())}[!] ملف PDF غير موجود: $pdf_file${\($color->reset())}";
        return 0;
    }
    
    say "${\($color->info())}[*] إضافة توقيع رقمي من: $signer_name ($signer_title)${\($color->reset())}";
    
    # توليد توقيع رقمي
    my $signature = {
        signer => $signer_name,
        title => $signer_title,
        timestamp => time(),
        time => scalar(localtime()),
        hash => _calculate_hash($pdf_file),
        signature_data => $signature_data
    };
    
    # إضافة التوقيع إلى PDF
    my $pdf_content = read_file($pdf_file);
    my $updated_content = $pdf_content . "\n<!-- SIGNATURE: " . encode_json($signature) . " -->\n";
    write_file($pdf_file, $updated_content);
    
    say "\n${\($color->success())}[✓] تم إضافة التوقيع الرقمي بنجاح${\($color->reset())}";
    say "   → الموقع: $signer_name";
    say "   → التاريخ: $signature->{time}";
    say "   → البصمة: " . substr($signature->{hash}, 0, 16) . "...";
    
    $utils->save_result('pdf_reporter', {
        action => 'sign',
        pdf_file => $pdf_file,
        signer => $signer_name,
        hash => substr($signature->{hash}, 0, 16)
    });
    
    return $signature;
}

# =============================================================================
# دوال مساعدة داخلية
# =============================================================================

sub _generate_pdf_content {
    my ($data) = @_;
    
    my $content = "%PDF-1.4\n";
    $content .= "1 0 obj\n";
    $content .= "<< /Type /Catalog /Pages 2 0 R >>\n";
    $content .= "endobj\n";
    $content .= "2 0 obj\n";
    $content .= "<< /Type /Pages /Kids [3 0 R] /Count 1 >>\n";
    $content .= "endobj\n";
    $content .= "3 0 obj\n";
    $content .= "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Contents 4 0 R >>\n";
    $content .= "endobj\n";
    $content .= "4 0 obj\n";
    $content .= "<< /Length 100 >>\n";
    $content .= "stream\n";
    $content .= "BT /F1 24 Tf 100 700 Td ($data->{title}) Tj ET\n";
    $content .= "BT /F1 12 Tf 100 670 Td (التاريخ: $data->{created_time}) Tj ET\n";
    $content .= "BT /F1 12 Tf 100 650 Td (المؤلف: $data->{author}) Tj ET\n";
    $content .= "endstream\n";
    $content .= "endobj\n";
    $content .= "xref\n";
    $content .= "0 5\n";
    $content .= "0000000000 65535 f\n";
    $content .= "0000000010 00000 n\n";
    $content .= "0000000050 00000 n\n";
    $content .= "0000000100 00000 n\n";
    $content .= "0000000200 00000 n\n";
    $content .= "trailer\n";
    $content .= "<< /Size 5 /Root 1 0 R >>\n";
    $content .= "startxref\n";
    $content .= "300\n";
    $content .= "%%EOF\n";
    
    return $content;
}

sub _generate_table_html {
    my ($title, $headers, $rows, $caption) = @_;
    
    my $html = "<h3>$title</h3>\n";
    $html .= "<table border='1' cellpadding='5' cellspacing='0'>\n";
    $html .= "<thead>\n <tr>";
    for my $header (@$headers) {
        $html .= "<th>$header</th>";
    }
    $html .= "</tr>\n</thead>\n<tbody>\n";
    
    for my $row (@$rows) {
        $html .= " <tr>";
        for my $cell (@$row) {
            $html .= "<td>$cell</td>";
        }
        $html .= "</tr>\n";
    }
    
    $html .= "</tbody>\n</table>\n";
    if ($caption) {
        $html .= "<p><em>$caption</em></p>\n";
    }
    
    return $html;
}

sub _generate_chart_ascii {
    my ($type, $data, $labels) = @_;
    
    my $max_val = max(@$data);
    my $height = 10;
    
    my $chart = "";
    
    if ($type eq "bar") {
        for my $i (0..$#$data) {
            my $bar_height = int(($data->[$i] / $max_val) * $height);
            $chart .= sprintf("%-10s | %s (%d)\n", $labels->[$i], "█" x $bar_height, $data->[$i]);
        }
    } elsif ($type eq "line") {
        # رسم خط بسيط
        for my $row (reverse(0..$height)) {
            my $line = "";
            for my $i (0..$#$data) {
                my $point_height = int(($data->[$i] / $max_val) * $height);
                if ($point_height == $row) {
                    $line .= "●";
                } else {
                    $line .= " ";
                }
            }
            $chart .= $line . "\n";
        }
        $chart .= join(" ", @$labels) . "\n";
    }
    
    return $chart;
}

sub _calculate_hash {
    my ($file) = @_;
    
    open(my $fh, '<', $file);
    local $/;
    my $content = <$fh>;
    close($fh);
    
    use Digest::SHA qw(sha256_hex);
    return sha256_hex($content);
}

sub dirname {
    my ($path) = @_;
    $path =~ s/[^\/]+$//;
    $path = "." if $path eq "";
    return $path;
}

sub max {
    my @list = @_;
    my $max = $list[0];
    for (@list) { $max = $_ if $_ > $max; }
    return $max;
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
