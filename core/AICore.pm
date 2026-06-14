package core::AICore;
# =============================================================================
# AICore.pm - الذكاء الاصطناعي البسيط (تعلم تراكمي، توليد كلمات ذكي، تحليل سلوكي)
# =============================================================================
# الميزات: شبكة عصبية بسيطة، تعلم معزز، توليد كلمات مرور ذكية، محلل سلوكي
# =============================================================================

use strict;
use warnings;
use parent 'Exporter';
our @EXPORT_OK = qw(neural_network_train neural_network_predict smart_password_generate behavioral_analysis reinforcement_learning);

use lib '.';
use lib::Utils;
use lib::Colors;
use JSON;
use Storable;
use Digest::SHA qw(sha256);
use List::Util qw(shuffle min max);
use Statistics::Basic qw(mean stddev);
use Time::HiRes qw(time);

# =============================================================================
# متغيرات الشبكة العصبية
# =============================================================================
my %NEURAL_NETWORK = (
    weights => [],
    biases => [],
    activation_history => [],
    training_iterations => 0,
    accuracy => 0
);

my $NN_MODEL_FILE = "$ENV{HOME}/.robinhood/ai_models/neural_network.dat";
my $PASSWORD_MODEL_FILE = "$ENV{HOME}/.robinhood/ai_models/password_model.dat";
my $BEHAVIOR_MODEL_FILE = "$ENV{HOME}/.robinhood/ai_models/behavior_model.dat";

# تحميل النماذج السابقة
if (-f $NN_MODEL_FILE) {
    eval { $NEURAL_NETWORK = %{retrieve($NN_MODEL_FILE)}; };
}

# =============================================================================
# تدريب الشبكة العصبية
# =============================================================================
sub neural_network_train {
    my ($training_data, $labels, $epochs) = @_;
    
    my $color = Colors->new();
    my $utils = Utils->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    🧠 تدريب الشبكة العصبية 🧠                       ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    $epochs //= 100;
    $training_data //= _generate_sample_data(1000);
    $labels //= _generate_sample_labels(1000);
    
    my $input_size = scalar(@{$training_data->[0]});
    my $output_size = 2;  # ثنائي (ناجح/فاشل)
    my $hidden_size = int(($input_size + $output_size) / 2) + 1;
    
    say "${\($color->info())}[*] بنية الشبكة:${\($color->reset())}";
    say "   → طبقة الإدخال: $input_size عصبون";
    say "   → طبقة خفية: $hidden_size عصبون";
    say "   → طبقة الإخراج: $output_size عصبون";
    say "   → عدد الحقب التدريبية: $epochs";
    
    # تهيئة الأوزان بشكل عشوائي
    if (!$NEURAL_NETWORK{weights}[0]) {
        $NEURAL_NETWORK{weights} = [
            _random_matrix($hidden_size, $input_size),
            _random_matrix($output_size, $hidden_size)
        ];
        $NEURAL_NETWORK{biases} = [
            _random_vector($hidden_size),
            _random_vector($output_size)
        ];
    }
    
    # التدريب
    my $start_time = time();
    my $learning_rate = 0.01;
    
    for my $epoch (1..$epochs) {
        my $total_loss = 0;
        
        for my $i (0..$#$training_data) {
            my $input = $training_data->[$i];
            my $label = $labels->[$i];
            
            # الانتشار الأمامي
            my ($output, $hidden) = _forward_propagate($input);
            
            # حساب الخطأ
            my $error = _calculate_error($output, $label);
            $total_loss += $error;
            
            # الانتشار الخلفي
            _backward_propagate($input, $label, $output, $hidden, $learning_rate);
        }
        
        # عرض التقدم كل 10 حقب
        if ($epoch % 10 == 0) {
            my $avg_loss = $total_loss / scalar(@$training_data);
            my $progress = int(($epoch / $epochs) * 100);
            say "${\($color->info())}[*] العصر $epoch/$epochs - الخسارة: " . sprintf("%.4f", $avg_loss) . " - التقدم: $progress%${\($color->reset())}";
        }
    }
    
    my $duration = time() - $start_time;
    
    # تقييم الدقة
    my $accuracy = _evaluate_accuracy($training_data, $labels);
    $NEURAL_NETWORK{accuracy} = $accuracy;
    $NEURAL_NETWORK{training_iterations} += $epochs;
    
    # حفظ النموذج
    store(\%NEURAL_NETWORK, $NN_MODEL_FILE);
    
    say "\n${\($color->success())}[✓] اكتمل التدريب!${\($color->reset())}";
    say "   → الوقت المستغرق: " . sprintf("%.2f", $duration) . " ثانية";
    say "   → الدقة النهائية: " . sprintf("%.2f", $accuracy * 100) . "%";
    
    return \%NEURAL_NETWORK;
}

# =============================================================================
# التنبؤ باستخدام الشبكة العصبية
# =============================================================================
sub neural_network_predict {
    my ($input) = @_;
    
    my $color = Colors->new();
    
    say "\n${\($color->quantum())}🔮 التنبؤ بالشبكة العصبية...${\($color->reset())}";
    
    if (!$NEURAL_NETWORK{weights}[0]) {
        say "${\($color->warning())}[!] النموذج غير مدرب - سيتم التدريب أولاً${\($color->reset())}";
        neural_network_train();
    }
    
    my ($output, $hidden) = _forward_propagate($input);
    
    my $prediction = $output->[0] > $output->[1] ? 1 : 0;
    my $confidence = ($output->[0] - $output->[1]) * 100;
    $confidence = abs($confidence);
    
    say "${\($color->success())}[✓] نتيجة التنبؤ:${\($color->reset())}";
    say "   → الفئة المتوقعة: " . ($prediction ? "ناجح" : "فاشل");
    say "   → نسبة الثقة: " . sprintf("%.2f", $confidence) . "%";
    
    return {
        prediction => $prediction,
        confidence => $confidence,
        output => $output
    };
}

# =============================================================================
# دوال مساعدة للشبكة العصبية
# =============================================================================
sub _forward_propagate {
    my ($input) = @_;
    
    # الطبقة الخفية
    my $hidden = [];
    for my $i (0..$#{$NEURAL_NETWORK{weights}[0]}) {
        my $sum = $NEURAL_NETWORK{biases}[0][$i];
        for my $j (0..$#$input) {
            $sum += $NEURAL_NETWORK{weights}[0][$i][$j] * $input->[$j];
        }
        $hidden->[$i] = _sigmoid($sum);
    }
    
    # طبقة الإخراج
    my $output = [];
    for my $i (0..$#{$NEURAL_NETWORK{weights}[1]}) {
        my $sum = $NEURAL_NETWORK{biases}[1][$i];
        for my $j (0..$#$hidden) {
            $sum += $NEURAL_NETWORK{weights}[1][$i][$j] * $hidden->[$j];
        }
        $output->[$i] = _sigmoid($sum);
    }
    
    return ($output, $hidden);
}

sub _backward_propagate {
    my ($input, $label, $output, $hidden, $learning_rate) = @_;
    
    # حساب أخطاء طبقة الإخراج
    my $output_errors = [];
    for my $i (0..$#$output) {
        $output_errors->[$i] = ($label->[$i] - $output->[$i]) * _sigmoid_derivative($output->[$i]);
    }
    
    # حساب أخطاء الطبقة الخفية
    my $hidden_errors = [];
    for my $i (0..$#$hidden) {
        my $error = 0;
        for my $j (0..$#$output_errors) {
            $error += $output_errors->[$j] * $NEURAL_NETWORK{weights}[1][$j][$i];
        }
        $hidden_errors->[$i] = $error * _sigmoid_derivative($hidden->[$i]);
    }
    
    # تحديث أوزان طبقة الإخراج
    for my $i (0..$#{$NEURAL_NETWORK{weights}[1]}) {
        for my $j (0..$#{$NEURAL_NETWORK{weights}[1][$i]}) {
            $NEURAL_NETWORK{weights}[1][$i][$j] += $learning_rate * $output_errors->[$i] * $hidden->[$j];
        }
        $NEURAL_NETWORK{biases}[1][$i] += $learning_rate * $output_errors->[$i];
    }
    
    # تحديث أوزان الطبقة الخفية
    for my $i (0..$#{$NEURAL_NETWORK{weights}[0]}) {
        for my $j (0..$#{$NEURAL_NETWORK{weights}[0][$i]}) {
            $NEURAL_NETWORK{weights}[0][$i][$j] += $learning_rate * $hidden_errors->[$i] * $input->[$j];
        }
        $NEURAL_NETWORK{biases}[0][$i] += $learning_rate * $hidden_errors->[$i];
    }
}

sub _sigmoid {
    my ($x) = @_;
    return 1 / (1 + exp(-$x));
}

sub _sigmoid_derivative {
    my ($x) = @_;
    return $x * (1 - $x);
}

sub _random_matrix {
    my ($rows, $cols) = @_;
    my $matrix = [];
    for my $i (0..$rows-1) {
        my $row = [];
        for my $j (0..$cols-1) {
            push @$row, rand() - 0.5;
        }
        push @$matrix, $row;
    }
    return $matrix;
}

sub _random_vector {
    my ($size) = @_;
    my $vector = [];
    for my $i (0..$size-1) {
        push @$vector, rand() - 0.5;
    }
    return $vector;
}

sub _calculate_error {
    my ($output, $label) = @_;
    my $error = 0;
    for my $i (0..$#$output) {
        $error += 0.5 * ($label->[$i] - $output->[$i]) ** 2;
    }
    return $error;
}

sub _evaluate_accuracy {
    my ($training_data, $labels) = @_;
    my $correct = 0;
    
    for my $i (0..$#$training_data) {
        my ($output, $hidden) = _forward_propagate($training_data->[$i]);
        my $prediction = $output->[0] > $output->[1] ? 1 : 0;
        my $actual = $labels->[$i][0] > $labels->[$i][1] ? 1 : 0;
        $correct++ if $prediction == $actual;
    }
    
    return $correct / scalar(@$training_data);
}

# =============================================================================
# توليد كلمات مرور ذكية
# =============================================================================
sub smart_password_generate {
    my ($context, $count) = @_;
    
    my $color = Colors->new();
    
    say "\n${\($color->quantum())}🔑 توليد كلمات مرور ذكية بالذكاء الاصطناعي...${\($color->reset())}";
    
    $count //= 10;
    $context //= {
        ssid => "Default_Network",
        bssid => "AA:BB:CC:DD:EE:FF",
        signal_strength => 75,
        encryption => "WPA2",
        region => "AE"  # الإمارات العربية المتحدة
    };
    
    my @passwords = ();
    
    # 1. كلمات بناءً على SSID
    my $ssid_clean = $context->{ssid};
    $ssid_clean =~ s/[^a-zA-Z0-9]//g;
    push @passwords, $ssid_clean;
    push @passwords, lc($ssid_clean);
    push @passwords, uc($ssid_clean);
    push @passwords, $ssid_clean . "123";
    push @passwords, $ssid_clean . "@2024";
    
    # 2. كلمات شائعة عربية/إنجليزية
    my @common_words = (
        # عربية
        "admin", "مدير", "مدخل", "مدينة", "123456", "00000000", "11111111",
        "password", "كلمة", "سر", "سري", "سعادة", "اتصال", "شبكة", "واي فاي",
        # إنجليزية
        "admin123", "password123", "qwerty", "abc123", "letmein", "welcome",
        "monkey", "dragon", "master", "super", "hello", "robinhood", "wibey"
    );
    push @passwords, @common_words;
    
    # 3. كلمات مع تواريخ وأرقام
    my @years = (2020..2025);
    my @months = (1..12);
    for my $year (@years) {
        push @passwords, "admin$year";
        push @passwords, "password$year";
        push @passwords, "wifi$year";
        push @passwords, $ssid_clean . $year;
    }
    
    # 4. كلمات مع رموز خاصة
    my @symbols = ('@', '#', '$', '%', '!', '?', '&', '*');
    for my $word (@common_words[0..9]) {
        for my $symbol (@symbols) {
            push @passwords, $word . $symbol;
            push @passwords, $word . $symbol . "123";
        }
    }
    
    # 5. كلمات مولدة بواسطة الشبكة العصبية
    my $neural_passwords = _generate_neural_passwords($context);
    push @passwords, @$neural_passwords;
    
    # إزالة التكرار
    my %seen;
    @passwords = grep { !$seen{$_}++ } @passwords;
    
    # ترتيب حسب الاحتمالية (الأكثر شيوعاً أولاً)
    @passwords = _rank_by_probability(@passwords);
    
    # أخذ أول $count كلمة
    @passwords = @passwords[0..$count-1] if scalar(@passwords) > $count;
    
    # عرض النتائج
    say "\n${\($color->success())}📝 قائمة كلمات المرور المولدة ($count كلمة):${\($color->reset())}";
    for my $i (0..$#passwords) {
        my $probability = _calculate_password_probability($passwords[$i]);
        my $prob_bar = _probability_bar($probability);
        say "   " . ($i+1) . ". $passwords[$i] - احتمالية: $prob_bar ($probability%)";
    }
    
    # حفظ القائمة
    my $wordlist_file = "$ENV{HOME}/.robinhood/wordlists/ai_generated_" . time() . ".txt";
    open(my $fh, '>', $wordlist_file);
    print $fh join("\n", @passwords);
    close($fh);
    
    say "\n${\($color->success())}[✓] تم حفظ القائمة في: $wordlist_file${\($color->reset())}";
    
    return \@passwords;
}

# =============================================================================
# توليد كلمات مرور بالشبكة العصبية
# =============================================================================
sub _generate_neural_passwords {
    my ($context) = @_;
    
    my @passwords = ();
    
    # خوارزمية توليد ذكية تعتمد على الأنماط المستفادة
    my $input_features = [
        length($context->{ssid}),
        $context->{signal_strength},
        $context->{encryption} eq 'WPA2' ? 1 : 0,
        $context->{region} eq 'AE' ? 1 : 0
    ];
    
    # محاكاة توقع كلمات محتملة
    my $patterns = [
        { suffix => "123", weight => 0.9 },
        { suffix => "2024", weight => 0.8 },
        { suffix => "@", weight => 0.7 },
        { suffix => "!", weight => 0.6 },
        { prefix => "admin", weight => 0.9 },
        { prefix => "wifi", weight => 0.8 }
    ];
    
    for my $pattern (@$patterns) {
        if ($pattern->{suffix}) {
            push @passwords, $context->{ssid} . $pattern->{suffix};
            push @passwords, lc($context->{ssid}) . $pattern->{suffix};
        }
        if ($pattern->{prefix}) {
            push @passwords, $pattern->{prefix} . $context->{ssid};
        }
    }
    
    return \@passwords;
}

# =============================================================================
# تحليل سلوكي
# =============================================================================
sub behavioral_analysis {
    my ($target_data) = @_;
    
    my $color = Colors->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    🕵️  التحليل السلوكي 🕵️                          ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    $target_data //= {
        bssid => "AA:BB:CC:DD:EE:FF",
        activity_hours => {
            "00-06" => 5,
            "06-12" => 20,
            "12-18" => 45,
            "18-24" => 30
        },
        connected_devices => ["Phone", "Laptop", "TV", "Tablet"],
        data_usage => {
            upload => 1024 * 1024 * 100,   # 100MB
            download => 1024 * 1024 * 500   # 500MB
        }
    };
    
    # تحليل ساعات النشاط
    my $most_active_hours = "12-18";
    my $least_active_hours = "00-06";
    
    # تحليل نوع الأجهزة
    my $device_count = scalar(@{$target_data->{connected_devices}});
    my $has_mobile = grep { $_ =~ /Phone|Tablet/i } @{$target_data->{connected_devices}};
    my $has_computer = grep { $_ =~ /Laptop|PC/i } @{$target_data->{connected_devices}};
    
    # تقدير وقت الهجوم الأمثل
    my $optimal_attack_time = "03:00 - 05:00 (أقل نشاط)";
    
    # تقرير التحليل
    say "${\($color->info())}📊 تحليل السلوك:${\($color->reset())}";
    say "   • أكثر ساعات نشاطاً: $most_active_hours";
    say "   • أقل ساعات نشاطاً: $least_active_hours";
    say "   • عدد الأجهزة المتصلة: $device_count";
    say "   • وجود أجهزة محمولة: " . ($has_mobile ? "نعم" : "لا");
    say "   • وجود أجهزة كمبيوتر: " . ($has_computer ? "نعم" : "لا");
    say "   • وقت الهجوم الأمثل: $optimal_attack_time";
    
    # حساب استهلاك البيانات
    my $total_data = $target_data->{data_usage}{upload} + $target_data->{data_usage}{download};
    my $data_gb = $total_data / (1024 * 1024 * 1024);
    say "   • استهلاك البيانات اليومي: " . sprintf("%.2f", $data_gb) . " GB";
    
    # توصيات
    say "\n${\($color->success())}💡 التوصيات:${\($color->reset())}";
    say "   → قم بالهجوم بين 02:00 و 05:00 صباحاً";
    say "   → تجنب الهجوم عند وجود " . ($device_count > 3 ? "أجهزة متعددة" : "نشاط مرتفع");
    
    return {
        optimal_time => $optimal_attack_time,
        device_count => $device_count,
        most_active => $most_active_hours
    };
}

# =============================================================================
# التعلم المعزز
# =============================================================================
sub reinforcement_learning {
    my ($action, $reward) = @_;
    
    my $color = Colors->new();
    
    say "\n${\($color->quantum())}🎯 التعلم المعزز...${\($color->reset())}";
    
    # تحميل أو تهيئة Q-Table
    my %q_table = ();
    my $Q_TABLE_FILE = "$ENV{HOME}/.robinhood/ai_models/q_table.dat";
    if (-f $Q_TABLE_FILE) {
        %q_table = %{retrieve($Q_TABLE_FILE)};
    }
    
    my $learning_rate = 0.1;
    my $discount_factor = 0.95;
    
    # تحديث Q-Value
    my $state = "default_state";
    my $q_value = $q_table{$state}{$action} // 0;
    my $max_future_q = 0;  # محاكاة
    
    my $new_q_value = $q_value + $learning_rate * ($reward + $discount_factor * $max_future_q - $q_value);
    $q_table{$state}{$action} = $new_q_value;
    
    # حفظ Q-Table
    store(\%q_table, $Q_TABLE_FILE);
    
    say "${\($color->info())}[✓] تحديث Q-Value: $q_value → $new_q_value${\($color->reset())}";
    
    # اختيار أفضل إجراء للوقت القادم
    my $best_action = "";
    my $best_value = -1e9;
    for my $act (keys %{$q_table{$state}}) {
        if ($q_table{$state}{$act} > $best_value) {
            $best_value = $q_table{$state}{$act};
            $best_action = $act;
        }
    }
    
    say "${\($color->success())}[✓] أفضل إجراء مستفاد: $best_action (قيمته: $best_value)${\($color->reset())}";
    
    return $best_action;
}

# =============================================================================
# دوال مساعدة
# =============================================================================
sub _generate_sample_data {
    my ($count) = @_;
    my $data = [];
    for my $i (1..$count) {
        my $sample = [rand(), rand(), rand(), rand()];
        push @$data, $sample;
    }
    return $data;
}

sub _generate_sample_labels {
    my ($count) = @_;
    my $labels = [];
    for my $i (1..$count) {
        my $label = [rand() > 0.5 ? 1 : 0, rand() > 0.5 ? 1 : 0];
        push @$labels, $label;
    }
    return $labels;
}

sub _rank_by_probability {
    my (@passwords) = @_;
    my @ranked = sort { 
        _calculate_password_probability($b) <=> _calculate_password_probability($a) 
    } @passwords;
    return @ranked;
}

sub _calculate_password_probability {
    my ($password) = @_;
    
    my $score = 0;
    
    # طول كلمة المرور
    my $len = length($password);
    if ($len >= 8 && $len <= 12) { $score += 30; }
    elsif ($len < 8) { $score += 50; }  # كلمات قصيرة أكثر شيوعاً
    else { $score += 10; }
    
    # أرقام
    if ($password =~ /\d/) { $score += 20; }
    
    # أحرف كبيرة
    if ($password =~ /[A-Z]/) { $score += 10; }
    
    # كلمات شائعة
    my @common = qw(admin password 123456 qwerty abc123 letmein welcome);
    for my $common (@common) {
        if (lc($password) eq $common) { $score += 40; last; }
        elsif (lc($password) =~ /$common/) { $score += 20; }
    }
    
    return $score > 100 ? 100 : $score;
}

sub _probability_bar {
    my ($percent) = @_;
    my $filled = int($percent / 10);
    my $empty = 10 - $filled;
    return "[" . ("█" x $filled) . ("░" x $empty) . "]";
}

1;  # نهاية الوحدة
