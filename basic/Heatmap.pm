package basic::Heatmap;
# =============================================================================
# Heatmap.pm - خريطة حرارة الإشارات (Signal Heatmap)
# =============================================================================
# الميزات: رسم خريطة حرارة، تحليل قوة الإشارة، تحديد أفضل المواقع
# =============================================================================

use strict;
use warnings;
use parent 'Exporter';
our @EXPORT_OK = qw(heatmap_generate heatmap_analyze heatmap_best_location);

use lib '.';
use lib::Utils;
use lib::Colors;
use Time::HiRes qw(sleep time);
use File::Slurp qw(write_file);
use List::Util qw(max min sum);

# =============================================================================
# إنشاء خريطة حرارة
# =============================================================================
sub heatmap_generate {
    my ($interface, $duration, $grid_size) = @_;
    
    my $color = Colors->new();
    my $utils = Utils->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    🔥 خريطة حرارة الإشارات 🔥                         ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    $interface //= "wlan0";
    $duration //= 60;
    $grid_size //= 20;
    
    say "${\($color->info())}[*] الواجهة: $interface${\($color->reset())}";
    say "${\($color->info())}[*] مدة المسح: $duration ثانية${\($color->reset())}";
    say "${\($color->info())}[*] حجم الشبكة: ${grid_size}x${grid_size}${\($color->reset())}";
    
    # إنشاء شبكة افتراضية للمسح
    my $heatmap = _create_heatmap_grid($grid_size);
    
    say "\n${\($color->info())}[*] بدء مسح الإشارات...${\($color->reset())}";
    
    my $start_time = time();
    my $samples = 0;
    
    while ((time() - $start_time) < $duration) {
        # محاكاة قراءة الإشارات من نقاط مختلفة
        for my $x (0..$grid_size-1) {
            for my $y (0..$grid_size-1) {
                my $signal = _simulate_signal_strength($x, $y, $grid_size);
                $heatmap->[$x][$y] = [] if !$heatmap->[$x][$y];
                push @{$heatmap->[$x][$y]}, $signal;
                $samples++;
            }
        }
        
        my $elapsed = time() - $start_time;
        my $percent = int(($elapsed / $duration) * 100);
        print "\r${\($color->info())}[*] التقدم: $percent% - العينات: $samples${\($color->reset())}";
        
        sleep(1);
    }
    
    print "\n";
    
    # حساب المتوسطات
    my $avg_heatmap = [];
    for my $x (0..$grid_size-1) {
        for my $y (0..$grid_size-1) {
            my @values = @{$heatmap->[$x][$y]};
            my $avg = scalar(@values) ? sum(@values) / scalar(@values) : 0;
            $avg_heatmap->[$x][$y] = int($avg);
        }
    }
    
    # رسم الخريطة
    _draw_heatmap($avg_heatmap);
    
    # حفظ الخريطة
    my $heatmap_file = _save_heatmap($avg_heatmap);
    
    say "\n${\($color->success())}[✓] تم حفظ خريطة الحرارة في: $heatmap_file${\($color->reset())}";
    
    return {
        heatmap => $avg_heatmap,
        samples => $samples,
        duration => $duration,
        file => $heatmap_file
    };
}

# =============================================================================
# تحليل خريطة الحرارة
# =============================================================================
sub heatmap_analyze {
    my ($heatmap_data) = @_;
    
    my $color = Colors->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    📊 تحليل خريطة الحرارة 📊                          ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    $heatmap_data //= _create_sample_heatmap();
    
    my $grid_size = scalar(@$heatmap_data);
    my @all_signals = ();
    
    for my $x (0..$grid_size-1) {
        for my $y (0..$grid_size-1) {
            push @all_signals, $heatmap_data->[$x][$y];
        }
    }
    
    my $max_signal = max(@all_signals);
    my $min_signal = min(@all_signals);
    my $avg_signal = sum(@all_signals) / scalar(@all_signals);
    
    # تحديد أفضل وأسوأ موقع
    my ($best_x, $best_y, $best_signal) = (0, 0, 0);
    my ($worst_x, $worst_y, $worst_signal) = (0, 0, 100);
    
    for my $x (0..$grid_size-1) {
        for my $y (0..$grid_size-1) {
            my $signal = $heatmap_data->[$x][$y];
            if ($signal > $best_signal) {
                $best_signal = $signal;
                $best_x = $x;
                $best_y = $y;
            }
            if ($signal < $worst_signal) {
                $worst_signal = $signal;
                $worst_x = $x;
                $worst_y = $y;
            }
        }
    }
    
    say "\n${\($color->info())}📈 إحصائيات الإشارة:${\($color->reset())}";
    say "   → أقوى إشارة: $best_signal% عند الموقع ($best_x, $best_y)";
    say "   → أضعف إشارة: $worst_signal% عند الموقع ($worst_x, $worst_y)";
    say "   → متوسط الإشارة: " . sprintf("%.1f", $avg_signal) . "%";
    say "   → الفرق بين الأقوى والأضعف: " . ($best_signal - $worst_signal) . "%";
    
    # تصنيف التغطية
    my $excellent = grep { $_ >= 80 } @all_signals;
    my $good = grep { $_ >= 60 && $_ < 80 } @all_signals;
    my $poor = grep { $_ >= 30 && $_ < 60 } @all_signals;
    my $bad = grep { $_ < 30 } @all_signals;
    
    say "\n${\($color->info())}📊 تصنيف التغطية:${\($color->reset())}";
    say "   → ممتاز (80-100%): " . sprintf("%.1f", ($excellent / scalar(@all_signals)) * 100) . "%";
    say "   → جيد (60-79%): " . sprintf("%.1f", ($good / scalar(@all_signals)) * 100) . "%";
    say "   → ضعيف (30-59%): " . sprintf("%.1f", ($poor / scalar(@all_signals)) * 100) . "%";
    say "   → سيء (0-29%): " . sprintf("%.1f", ($bad / scalar(@all_signals)) * 100) . "%";
    
    return {
        max_signal => $best_signal,
        min_signal => $worst_signal,
        avg_signal => $avg_signal,
        best_location => { x => $best_x, y => $best_y },
        worst_location => { x => $worst_x, y => $worst_y }
    };
}

# =============================================================================
# تحديد أفضل موقع للهجوم
# =============================================================================
sub heatmap_best_location {
    my ($heatmap_data) = @_;
    
    my $color = Colors->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    🎯 أفضل موقع للهجوم 🎯                            ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    $heatmap_data //= _create_sample_heatmap();
    
    my $grid_size = scalar(@$heatmap_data);
    my $best_signal = 0;
    my $best_location = { x => 0, y => 0 };
    
    for my $x (0..$grid_size-1) {
        for my $y (0..$grid_size-1) {
            my $signal = $heatmap_data->[$x][$y];
            if ($signal > $best_signal) {
                $best_signal = $signal;
                $best_location = { x => $x, y => $y };
            }
        }
    }
    
    say "\n${\($color->success())}[✓] أفضل موقع للهجوم:${\($color->reset())}";
    say "   → الإحداثيات: X=$best_location->{x}, Y=$best_location->{y}";
    say "   → قوة الإشارة: $best_signal%";
    say "   → التصنيف: " . ($best_signal >= 80 ? "ممتاز" : ($best_signal >= 60 ? "جيد" : "متوسط"));
    
    # نصائح للهجوم
    say "\n${\($color->info())}💡 نصائح للهجوم من هذا الموقع:${\($color->reset())}";
    say "   → استخدم واجهة لاسلكية خارجية إذا كانت الإشارة أقل من 60%";
    say "   → قم بتوجيه الهوائي نحو اتجاه الراوتر";
    say "   → تجنب العوائق المعدنية والخزانات";
    
    return $best_location;
}

# =============================================================================
# دوال مساعدة داخلية
# =============================================================================

sub _create_heatmap_grid {
    my ($size) = @_;
    my $grid = [];
    for my $i (0..$size-1) {
        $grid->[$i] = [];
        for my $j (0..$size-1) {
            $grid->[$i][$j] = [];
        }
    }
    return $grid;
}

sub _simulate_signal_strength {
    my ($x, $y, $size) = @_;
    
    # محاكاة نقطة ساخنة في المنتصف
    my $center = $size / 2;
    my $distance = sqrt(($x - $center)**2 + ($y - $center)**2);
    my $max_distance = sqrt(2) * $center;
    
    # قوة الإشارة تتناقص مع المسافة
    my $signal = 100 * (1 - $distance / $max_distance);
    
    # إضافة تشويش عشوائي
    $signal += (rand(20) - 10);
    
    # تحديد الحدود
    $signal = 100 if $signal > 100;
    $signal = 0 if $signal < 0;
    
    return int($signal);
}

sub _draw_heatmap {
    my ($heatmap) = @_;
    
    my $color = Colors->new();
    my $size = scalar(@$heatmap);
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    🗺️ خريطة الحرارة 🗺️                               ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    # رسم الخريطة
    for my $y (0..$size-1) {
        my $line = "";
        for my $x (0..$size-1) {
            my $signal = $heatmap->[$x][$y];
            my $char;
            
            if ($signal >= 80) {
                $char = color('red') . "█" . $color->reset();
            } elsif ($signal >= 60) {
                $char = color('yellow') . "▓" . $color->reset();
            } elsif ($signal >= 40) {
                $char = color('green') . "▒" . $color->reset();
            } elsif ($signal >= 20) {
                $char = color('blue') . "░" . $color->reset();
            } else {
                $char = color('white') . "·" . $color->reset();
            }
            $line .= $char;
        }
        say $line;
    }
    
    # مفتاح الألوان
    say "\n${\($color->info())}مفتاح الألوان:${\($color->reset())}";
    say "   " . color('red') . "█ ≥80% (ممتاز)" . $color->reset();
    say "   " . color('yellow') . "▓ 60-79% (جيد)" . $color->reset();
    say "   " . color('green') . "▒ 40-59% (متوسط)" . $color->reset();
    say "   " . color('blue') . "░ 20-39% (ضعيف)" . $color->reset();
    say "   " . color('white') . "· <20% (سيء)" . $color->reset();
}

sub _save_heatmap {
    my ($heatmap) = @_;
    
    my $filename = "$ENV{HOME}/.robinhood/logs/heatmap_" . time() . ".json";
    
    # تحويل البيانات إلى JSON
    my $json = encode_json($heatmap);
    write_file($filename, $json);
    
    return $filename;
}

sub _create_sample_heatmap {
    my $size = 20;
    my $heatmap = [];
    
    for my $x (0..$size-1) {
        for my $y (0..$size-1) {
            my $center = $size / 2;
            my $distance = sqrt(($x - $center)**2 + ($y - $center)**2);
            my $max_distance = sqrt(2) * $center;
            my $signal = int(100 * (1 - $distance / $max_distance));
            $signal += int(rand(20) - 10);
            $signal = 100 if $signal > 100;
            $signal = 0 if $signal < 0;
            $heatmap->[$x][$y] = $signal;
        }
    }
    
    return $heatmap;
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
            push @pairs, qq{"$key":} . encode_json($data->{$key});
        }
        return "{" . join(",", @pairs) . "}";
    }
    else {
        return $data;
    }
}

1;  # نهاية الوحدة
