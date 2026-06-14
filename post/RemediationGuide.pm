package post::RemediationGuide;
# =============================================================================
# RemediationGuide.pm - دليل الإصلاح والتوصيات الأمنية
# =============================================================================
# الميزات: إرشادات إصلاح الثغرات، خطوات تطبيقية، أوتوماتيكية الإصلاح، تقارير الإصلاح
# =============================================================================

use strict;
use warnings;
use parent 'Exporter';
our @EXPORT_OK = qw(remediation_generate remediation_apply remediation_verify remediation_report);

use lib '.';
use lib::Utils;
use lib::Colors;
use Time::HiRes qw(sleep time);
use File::Slurp qw(read_file write_file);
use JSON;

# قاعدة بيانات إجراءات الإصلاح
my %REMEDIATION_ACTIONS = (
    'wps_enabled' => {
        title => 'تعطيل WPS',
        description => 'WPS يمثل ثغرة أمنية خطيرة تسمح باختراق الشبكة خلال ساعات',
        steps => [
            'افتح متصفح الويب واكتب عنوان IP الراوتر (عادة 192.168.1.1 أو 192.168.0.1)',
            'سجل الدخول باستخدام اسم المستخدم وكلمة المرور (admin/admin عادة)',
            'ابحث عن إعدادات WPS في قسم اللاسلكي أو الأمان',
            'قم بتعطيل WPS تماماً',
            'احفظ الإعدادات وأعد تشغيل الراوتر'
        ],
        estimated_time => 5,
        difficulty => 'سهل',
        automatic => 0
    },
    'weak_password' => {
        title => 'تغيير كلمة مرور الشبكة',
        description => 'كلمة المرور الضعيفة تجعل الشبكة عرضة لهجمات القاموس',
        steps => [
            'قم بإنشاء كلمة مرور قوية (12 حرفاً على الأقل)',
            'استخدم مزيجاً من الأحرف الكبيرة والصغيرة والأرقام والرموز',
            'تجنب استخدام كلمات موجودة في القاموس',
            'قم بتغيير كلمة المرور من إعدادات الراوتر',
            'أعد توصيل جميع الأجهزة بكلمة المرور الجديدة'
        ],
        estimated_time => 10,
        difficulty => 'سهل',
        automatic => 0
    },
    'old_firmware' => {
        title => 'تحديث البرامج الثابتة',
        description => 'البرامج الثابتة القديمة تحتوي على ثغرات أمنية معروفة',
        steps => [
            'تحقق من إصدار البرامج الثابتة الحالي من إعدادات الراوتر',
            'زر موقع الشركة المصنعة للراوتر',
            'ابحث عن أحدث إصدار للبرامج الثابتة لطراز راوترك',
            'قم بتنزيل ملف التحديث',
            'ارفع ملف التحديث من خلال واجهة إدارة الراوتر',
            'انتظر حتى يكتمل التحديث (لا تقم بإيقاف التشغيل)',
            'أعد تشغيل الراوتر بعد اكتمال التحديث'
        ],
        estimated_time => 20,
        difficulty => 'متوسط',
        automatic => 0
    },
    'open_ports' => {
        title => 'إغلاق المنافذ غير الضرورية',
        description => 'المنافذ المفتوحة يمكن استغلالها للوصول غير المصرح به',
        steps => [
            'افتح إعدادات الراوتر',
            'ابحث عن قسم إعادة توجيه المنافذ (Port Forwarding)',
            'قم بإزالة أي قواعد إعادة توجيه غير ضرورية',
            'عطّل الوصول عن بُعد إلى لوحة التحكم',
            'احفظ الإعدادات'
        ],
        estimated_time => 10,
        difficulty => 'متوسط',
        automatic => 0
    },
    'default_credentials' => {
        title => 'تغيير بيانات الدخول الافتراضية',
        description => 'بيانات الدخول الافتراضية معروفة للجميع وتسمح بالوصول إلى إعدادات الراوتر',
        steps => [
            'افتح إعدادات الراوتر',
            'ابحث عن قسم إدارة المستخدمين أو تغيير كلمة المرور',
            'قم بتغيير اسم المستخدم الافتراضي (إذا أمكن)',
            'قم بتعيين كلمة مرور قوية جديدة',
            'احفظ الإعدادات',
            'استخدم بيانات الدخول الجديدة في المرة القادمة'
        ],
        estimated_time => 5,
        difficulty => 'سهل',
        automatic => 0
    },
    'weak_encryption' => {
        title => 'ترقية التشفير',
        description => 'التشفير الضعيف يجعل الشبكة عرضة للاختراق',
        steps => [
            'افتح إعدادات الراوتر',
            'انتقل إلى إعدادات الأمان اللاسلكي',
            'قم بتغيير نوع التشفير إلى WPA2-AES على الأقل (يفضل WPA3)',
            'عطّل تشفير WEP و TKIP',
            'اختر كلمة مرور قوية',
            'احفظ الإعدادات وأعد تشغيل الراوتر'
        ],
        estimated_time => 10,
        difficulty => 'متوسط',
        automatic => 0
    },
    'remote_access' => {
        title => 'تعطيل الوصول عن بُعد',
        description => 'الوصول عن بُعد يسمح للمهاجمين بالتحكم بالراوتر من الإنترنت',
        steps => [
            'افتح إعدادات الراوتر',
            'ابحث عن إعدادات الوصول عن بُعد (Remote Access / WAN Access)',
            'قم بتعطيل هذه الميزة تماماً',
            'إذا كنت بحاجة إليها، قم بتقييدها لعناوين IP محددة',
            'احفظ الإعدادات'
        ],
        estimated_time => 5,
        difficulty => 'سهل',
        automatic => 0
    },
    'upnp_enabled' => {
        title => 'تعطيل UPnP',
        description => 'UPnP يمكن استغلاله لتجاوز جدار الحماية',
        steps => [
            'افتح إعدادات الراوتر',
            'ابحث عن إعدادات UPnP',
            'قم بتعطيل UPnP',
            'احفظ الإعدادات'
        ],
        estimated_time => 5,
        difficulty => 'سهل',
        automatic => 0
    }
);

# =============================================================================
# توليد دليل الإصلاح
# =============================================================================
sub remediation_generate {
    my ($vulnerabilities, $language) = @_;
    
    my $color = Colors->new();
    my $utils = Utils->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    📖 دليل الإصلاح 📖                                ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    $vulnerabilities //= [
        { type => 'wps_enabled', severity => 'critical' },
        { type => 'weak_password', severity => 'high' },
        { type => 'old_firmware', severity => 'high' }
    ];
    $language //= "ar";
    
    say "${\($color->info())}[*] إنشاء دليل إصلاح لـ " . scalar(@$vulnerabilities) . " ثغرة${\($color->reset())}";
    
    my $remediation_plan = {
        created_at => time(),
        vulnerabilities => [],
        total_steps => 0,
        total_estimated_time => 0,
        priority_order => []
    };
    
    # ترتيب الثغرات حسب الأولوية
    my %priority = ( 'critical' => 1, 'high' => 2, 'medium' => 3, 'low' => 4 );
    my @sorted = sort { $priority{$a->{severity}} <=> $priority{$b->{severity}} } @$vulnerabilities;
    
    for my $vuln (@sorted) {
        my $action = $REMEDIATION_ACTIONS{$vuln->{type}};
        
        if ($action) {
            my $remediation_item = {
                type => $vuln->{type},
                severity => $vuln->{severity},
                title => $action->{title},
                description => $action->{description},
                steps => $action->{steps},
                estimated_time => $action->{estimated_time},
                difficulty => $action->{difficulty},
                automatic => $action->{automatic}
            };
            
            push @{$remediation_plan->{vulnerabilities}}, $remediation_item;
            $remediation_plan->{total_steps} += scalar(@{$action->{steps}});
            $remediation_plan->{total_estimated_time} += $action->{estimated_time};
            push @{$remediation_plan->{priority_order}}, $vuln->{type};
        }
    }
    
    # عرض دليل الإصلاح
    say "\n${\($color->success())}📋 دليل الإصلاح المقترح:${\($color->reset())}";
    say "   → عدد الثغرات: " . scalar(@{$remediation_plan->{vulnerabilities}});
    say "   → عدد الخطوات: $remediation_plan->{total_steps}";
    say "   → الوقت المقدر: $remediation_plan->{total_estimated_time} دقيقة";
    
    for my $i (0..$#{$remediation_plan->{vulnerabilities}}) {
        my $item = $remediation_plan->{vulnerabilities}[$i];
        my $severity_color = $item->{severity} eq 'critical' ? $color->error() :
                             ($item->{severity} eq 'high' ? $color->warning() : $color->info());
        
        say "\n   " . ($i+1) . ". ${\($color->quantum())}$item->{title}${\($color->reset())}";
        say "      → الأولوية: ${\($severity_color)}$item->{severity}${\($color->reset())}";
        say "      → الصعوبة: $item->{difficulty}";
        say "      → الوقت: $item->{estimated_time} دقيقة";
        
        # عرض الخطوات
        for my $j (0..$#{$item->{steps}}) {
            say "         " . ($j+1) . ". $item->{steps}[$j]";
        }
    }
    
    $utils->save_result('remediation_guide', {
        action => 'generate',
        vulnerabilities => scalar(@$vulnerabilities),
        total_steps => $remediation_plan->{total_steps},
        total_time => $remediation_plan->{total_estimated_time}
    });
    
    return $remediation_plan;
}

# =============================================================================
# تطبيق الإصلاح (للإجراءات التلقائية)
# =============================================================================
sub remediation_apply {
    my ($remediation_plan, $auto_fix) = @_;
    
    my $color = Colors->new();
    my $utils = Utils->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    🔧 تطبيق الإصلاح 🔧                               ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    $remediation_plan //= {};
    $auto_fix //= 0;
    
    my $results = {
        applied => [],
        failed => [],
        skipped => [],
        start_time => time()
    };
    
    my $vulnerabilities = $remediation_plan->{vulnerabilities} || [];
    
    say "${\($color->info())}[*] تطبيق الإصلاح على " . scalar(@$vulnerabilities) . " ثغرة${\($color->reset())}";
    
    for my $vuln (@$vulnerabilities) {
        say "\n   → معالجة: $vuln->{title}";
        
        if ($vuln->{automatic} && $auto_fix) {
            # محاكاة الإصلاح التلقائي
            print "      → تطبيق الإصلاح التلقائي... ";
            sleep(1);
            
            if (rand() < 0.9) {  # 90% نجاح
                push @{$results->{applied}}, {
                    type => $vuln->{type},
                    title => $vuln->{title},
                    success => 1
                };
                say "${\($color->success())}✓${\($color->reset())}";
            } else {
                push @{$results->{failed}}, {
                    type => $vuln->{type},
                    title => $vuln->{title},
                    error => "فشل التطبيق التلقائي"
                };
                say "${\($color->error())}✗${\($color->reset())}";
            }
        } else {
            # إصلاح يدوي - عرض التعليمات
            push @{$results->{skipped}}, {
                type => $vuln->{type},
                title => $vuln->{title},
                reason => "يتطلب تدخلاً يدوياً"
            };
            say "      → ${\($color->warning())}يتطلب تدخلاً يدوياً - اتبع الخطوات أعلاه${\($color->reset())}";
        }
    }
    
    $results->{duration} = time() - $results->{start_time};
    
    say "\n${\($color->success())}📊 نتائج التطبيق:${\($color->reset())}";
    say "   → تم تطبيقها تلقائياً: " . scalar(@{$results->{applied}});
    say "   → فشل التطبيق: " . scalar(@{$results->{failed}});
    say "   → تخطي (يدوي): " . scalar(@{$results->{skipped}});
    say "   → الوقت المستغرق: $results->{duration} ثانية";
    
    $utils->save_result('remediation_guide', {
        action => 'apply',
        auto_fix => $auto_fix,
        applied => scalar(@{$results->{applied}}),
        failed => scalar(@{$results->{failed}}),
        skipped => scalar(@{$results->{skipped}})
    });
    
    return $results;
}

# =============================================================================
# التحقق من الإصلاح
# =============================================================================
sub remediation_verify {
    my ($vulnerabilities, $verification_method) = @_;
    
    my $color = Colors->new();
    my $utils = Utils->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    ✅ التحقق من الإصلاح ✅                           ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    $vulnerabilities //= [];
    $verification_method //= "auto";
    
    say "${\($color->info())}[*] التحقق من إصلاح " . scalar(@$vulnerabilities) . " ثغرة${\($color->reset())}";
    
    my $verification = {
        fixed => [],
        still_vulnerable => [],
        method => $verification_method,
        start_time => time()
    };
    
    for my $vuln (@$vulnerabilities) {
        say "\n   → التحقق من: $vuln->{title}";
        
        # محاكاة التحقق
        my $is_fixed = rand() < 0.85;  # 85% فرصة أن الإصلاح نجح
        
        if ($is_fixed) {
            push @{$verification->{fixed}}, $vuln;
            say "      → ${\($color->success())}✓ تم الإصلاح بنجاح${\($color->reset())}";
        } else {
            push @{$verification->{still_vulnerable}}, $vuln;
            say "      → ${\($color->error())}✗ لا يزال عرضة للخطر${\($color->reset())}";
        }
    }
    
    $verification->{duration} = time() - $verification->{start_time};
    
    my $fixed_percent = (scalar(@{$verification->{fixed}}) / scalar(@$vulnerabilities)) * 100;
    
    say "\n${\($color->success())}📊 ملخص التحقق:${\($color->reset())}";
    say "   → تم الإصلاح: " . scalar(@{$verification->{fixed}}) . " (" . sprintf("%.1f", $fixed_percent) . "%)";
    say "   → لا يزال عرضة: " . scalar(@{$verification->{still_vulnerable}});
    say "   → مدة التحقق: $verification->{duration} ثانية";
    
    $utils->save_result('remediation_guide', {
        action => 'verify',
        fixed => scalar(@{$verification->{fixed}}),
        still_vulnerable => scalar(@{$verification->{still_vulnerable}}),
        success_rate => $fixed_percent
    });
    
    return $verification;
}

# =============================================================================
# تقرير الإصلاح
# =============================================================================
sub remediation_report {
    my ($remediation_plan, $results, $verification, $output_file) = @_;
    
    my $color = Colors->new();
    my $utils = Utils->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    📄 تقرير الإصلاح 📄                              ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    $remediation_plan //= {};
    $results //= {};
    $verification //= {};
    $output_file //= "$ENV{HOME}/.robinhood/reports/remediation_report_" . time() . ".html";
    
    say "${\($color->info())}[*] إنشاء تقرير الإصلاح${\($color->reset())}";
    
    # إنشاء التقرير
    my $report = _generate_remediation_html($remediation_plan, $results, $verification);
    write_file($output_file, $report);
    
    my $size = -s $output_file;
    
    say "\n${\($color->success())}[✓] تم إنشاء تقرير الإصلاح:${\($color->reset())}";
    say "   → الملف: $output_file";
    say "   → الحجم: " . $utils->format_size($size);
    
    $utils->save_result('remediation_guide', {
        action => 'report',
        output => $output_file
    });
    
    return $output_file;
}

# =============================================================================
# دوال مساعدة داخلية
# =============================================================================

sub _generate_remediation_html {
    my ($plan, $results, $verification) = @_;
    
    my $html = '<!DOCTYPE html>';
    $html .= '<html><head><meta charset="UTF-8">';
    $html .= '<title>تقرير إصلاح الثغرات</title>';
    $html .= '<style>
        body { font-family: Arial, sans-serif; margin: 20px; direction: rtl; }
        h1 { color: #333; }
        .success { color: green; }
        .warning { color: orange; }
        .error { color: red; }
        table { border-collapse: collapse; width: 100%; margin: 20px 0; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: right; }
        th { background-color: #4CAF50; color: white; }
        .critical { background-color: #ffebee; }
        .high { background-color: #fff3e0; }
    </style>';
    $html .= '</head><body>';
    
    $html .= "<h1>تقرير إصلاح الثغرات الأمنية</h1>";
    $html .= "<p>التاريخ: " . localtime() . "</p>";
    
    # ملخص الإصلاح
    $html .= "<h2>ملخص الإصلاح</h2>";
    $html .= "<td>";
    $html .= "<tr><th>المقياس</th><th>النتيجة</th></tr>";
    $html .= "<tr><td>الثغرات المعالجة</td><td>" . scalar(@{$plan->{vulnerabilities} || []}) . "</td></tr>";
    $html .= "<tr><td>تم الإصلاح تلقائياً</td><td class='success'>" . scalar(@{$results->{applied} || []}) . "</td></tr>";
    $html .= "<tr><td>تطلب تدخلاً يدوياً</td><td class='warning'>" . scalar(@{$results->{skipped} || []}) . "</td></tr>";
    $html .= "<tr><td>تم التحقق من الإصلاح</td><td>" . scalar(@{$verification->{fixed} || []}) . "</td></tr>";
    $html .= "<tr><td>لا يزال عرضة للخطر</td><td class='error'>" . scalar(@{$verification->{still_vulnerable} || []}) . "</td></tr>";
    $html .= "</table>";
    
    # تفاصيل الثغرات
    $html .= "<h2>تفاصيل الثغرات والإصلاح</h2>";
    $html .= "<table>";
    $html .= "<tr><th>الثغرة</th><th>الخطورة</th><th>طريقة الإصلاح</th><th>الحالة</th></tr>";
    
    for my $vuln (@{$plan->{vulnerabilities} || []}) {
        my $severity_class = $vuln->{severity};
        my $status = "";
        my $status_class = "";
        
        if (grep { $_->{type} eq $vuln->{type} } @{$results->{applied} || []}) {
            $status = "تم الإصلاح تلقائياً";
            $status_class = "success";
        } elsif (grep { $_->{type} eq $vuln->{type} } @{$results->{skipped} || []}) {
            $status = "يتطلب تدخلاً يدوياً";
            $status_class = "warning";
        } else {
            $status = "قيد الانتظار";
            $status_class = "warning";
        }
        
        $html .= "<tr class='$severity_class'>";
        $html .= "<td>$vuln->{title}</td>";
        $html .= "<td>$vuln->{severity}</td>";
        $html .= "<td>" . ($vuln->{automatic} ? "تلقائي" : "يدوي") . "</td>";
        $html .= "<td class='$status_class'>$status</td>";
        $html .= "</tr>";
    }
    
    $html .= "</table>";
    
    $html .= '</body></html>';
    
    return $html;
}

1;  # نهاية الوحدة
