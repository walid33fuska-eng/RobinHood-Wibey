package basic::ChannelScanner;
# =============================================================================
# ChannelScanner.pm - ماسح القنوات اللاسلكية
# =============================================================================
# الميزات: مسح جميع القنوات، تحليل ازدحام القنوات، اقتراح أفضل قناة للهجوم
# =============================================================================

use strict;
use warnings;
use parent 'Exporter';
our @EXPORT_OK = qw(channel_scan_all channel_scan_best channel_scan_analysis channel_scan_hop);

use lib '.';
use lib::Utils;
use lib::Colors;
use Time::HiRes qw(sleep time);
use File::Slurp qw(write_file);
use List::Util qw(sum max min);

# قنوات الواي فاي المدعومة (2.4GHz و 5GHz)
my @CHANNELS_24GHZ = (1..11);
my @CHANNELS_5GHZ = (36, 40, 44, 48, 52, 56, 60, 64, 100, 104, 108, 112, 116, 120, 124, 128, 132, 136, 140, 149, 153, 157, 161, 165);
my @ALL_CHANNELS = (@CHANNELS_24GHZ, @CHANNELS_5GHZ);

# =============================================================================
# مسح جميع القنوات
# =============================================================================
sub channel_scan_all {
    my ($interface, $band) = @_;
    
    my $color = Colors->new();
    my $utils = Utils->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    📡 ماسح القنوات 📡                                 ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    $interface //= "wlan0";
    $band //= "both";
    
    my @channels_to_scan = ();
    if ($band eq "2.4") {
        @channels_to_scan = @CHANNELS_24GHZ;
        say "${\($color->info())}[*] النطاق: 2.4 GHz${\($color->reset())}";
    } elsif ($band eq "5") {
        @channels_to_scan = @CHANNELS_5GHZ;
        say "${\($color->info())}[*] النطاق: 5 GHz${\($color->reset())}";
    } else {
        @channels_to_scan = @ALL_CHANNELS;
        say "${\($color->info())}[*] النطاق: كامل (2.4GHz + 5GHz)${\($color->reset())}";
    }
    
    say "${\($color->info())}[*] الواجهة: $interface${\($color->reset())}";
    say "${\($color->info())}[*] عدد القنوات للمسح: " . scalar(@channels_to_scan) . "${\($color->reset())}";
    
    my $scan_results = [];
    my $current_channel = 0;
    
    say "\n${\($color->info())}[*] بدء المسح...${\($color->reset())}";
    
    for my $channel (@channels_to_scan) {
        $current_channel++;
        my $percent = int(($current_channel / scalar(@channels_to_scan)) * 100);
        
        # محاكاة ضبط القناة والمسح
        _set_channel($interface, $channel);
        sleep(0.5);
        
        # محاكاة اكتشاف الشبكات على هذه القناة
        my $networks = _scan_channel($channel);
        my $interference = _measure_interference($channel);
        
        push @$scan_results, {
            channel => $channel,
            networks => $networks,
            interference => $interference,
            quality => _calculate_channel_quality($networks, $interference)
        };
        
        print "\r${\($color->info())}[*] التقدم: $percent% - القناة $channel - الشبكات: $networks - التداخل: $interference%${\($color->reset())}";
    }
    
    print "\n";
    say "\n${\($color->success())}[✓] اكتمل مسح القنوات${\($color->reset())}";
    
    # عرض النتائج
    _display_scan_results($scan_results);
    
    # حفظ النتائج
    my $scan_file = "$ENV{HOME}/.robinhood/logs/channel_scan_" . time() . ".json";
    write_file($scan_file, encode_json($scan_results));
    
    say "\n${\($color->success())}[✓] تم حفظ النتائج في: $scan_file${\($color->reset())}";
    
    $utils->save_result('channel_scan', {
        band => $band,
        channels_scanned => scalar(@channels_to_scan),
        results => $scan_results
    });
    
    return $scan_results;
}

# =============================================================================
# البحث عن أفضل قناة
# =============================================================================
sub channel_scan_best {
    my ($interface) = @_;
    
    my $color = Colors->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    🎯 أفضل قناة للهجوم 🎯                            ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    $interface //= "wlan0";
    
    # مسح جميع القنوات أولاً
    my $scan_results = channel_scan_all($interface, "both");
    
    # ترتيب حسب جودة القناة
    my @sorted = sort { $b->{quality} <=> $a->{quality} } @$scan_results;
    
    my $best_channel = $sorted[0];
    
    say "\n${\($color->success())}🏆 أفضل قناة للهجوم:${\($color->reset())}";
    say "   → القناة: $best_channel->{channel}";
    say "   → الجودة: " . sprintf("%.1f", $best_channel->{quality}) . "%";
    say "   → عدد الشبكات: $best_channel->{networks}";
    say "   → مستوى التداخل: $best_channel->{interference}%";
    
    # نصائح
    say "\n${\($color->info())}💡 نصيحة:${\($color->reset())}";
    if ($best_channel->{interference} < 30) {
        say "   → القناة $best_channel->{channel} مثالية للهجوم، تداخل منخفض";
    } else {
        say "   → القناة $best_channel->{channel} مقبولة، لكن هناك تداخل ملحوظ";
    }
    
    # قنوات بديلة
    if (scalar(@sorted) > 1) {
        say "\n${\($color->info())}🔄 قنوات بديلة:${\($color->reset())}";
        for my $i (1..3) {
            last unless $sorted[$i];
            say "   → القناة $sorted[$i]->{channel} - جودة " . sprintf("%.1f", $sorted[$i]->{quality}) . "%";
        }
    }
    
    return $best_channel;
}

# =============================================================================
# تحليل القنوات
# =============================================================================
sub channel_scan_analysis {
    my ($scan_results) = @_;
    
    my $color = Colors->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    📊 تحليل القنوات 📊                               ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    $scan_results //= [];
    
    if (scalar(@$scan_results) == 0) {
        say "${\($color->warning())}[!] لا توجد بيانات مسح${\($color->reset())}";
        return {};
    }
    
    # إحصائيات عامة
    my @qualities = map { $_->{quality} } @$scan_results;
    my @interferences = map { $_->{interference} } @$scan_results;
    my @networks = map { $_->{networks} } @$scan_results;
    
    my $avg_quality = sum(@qualities) / scalar(@qualities);
    my $avg_interference = sum(@interferences) / scalar(@interferences);
    my $total_networks = sum(@networks);
    
    say "\n${\($color->info())}📈 إحصائيات عامة:${\($color->reset())}";
    say "   → متوسط جودة القنوات: " . sprintf("%.1f", $avg_quality) . "%";
    say "   → متوسط التداخل: " . sprintf("%.1f", $avg_interference) . "%";
    say "   → إجمالي الشبكات المكتشفة: $total_networks";
    
    # توزيع القنوات
    my %band_distribution = (
        "2.4GHz" => 0,
        "5GHz" => 0
    );
    
    for my $result (@$scan_results) {
        if ($result->{channel} <= 11) {
            $band_distribution{"2.4GHz"}++;
        } else {
            $band_distribution{"5GHz"}++;
        }
    }
    
    say "\n${\($color->info())}📡 توزيع القنوات حسب النطاق:${\($color->reset())}";
    say "   → 2.4GHz: $band_distribution{'2.4GHz'} قناة";
    say "   → 5GHz: $band_distribution{'5GHz'} قناة";
    
    # القنوات الأقل ازدحاماً
    my @least_congested = sort { $a->{networks} <=> $b->{networks} } @$scan_results;
    
    say "\n${\($color->success())}🟢 أقل 3 قنوات ازدحاماً:${\($color->reset())}";
    for my $i (0..2) {
        last unless $least_congested[$i];
        say "   → القناة $least_congested[$i]->{channel} - $least_congested[$i]->{networks} شبكة";
    }
    
    return {
        avg_quality => $avg_quality,
        avg_interference => $avg_interference,
        total_networks => $total_networks,
        distribution => \%band_distribution
    };
}

# =============================================================================
# القفز بين القنوات (Channel Hopping)
# =============================================================================
sub channel_scan_hop {
    my ($interface, $duration, $hop_interval) = @_;
    
    my $color = Colors->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    🔄 القفز بين القنوات 🔄                           ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    $interface //= "wlan0";
    $duration //= 60;
    $hop_interval //= 2;
    
    say "${\($color->info())}[*] الواجهة: $interface${\($color->reset())}";
    say "${\($color->info())}[*] مدة القفز: $duration ثانية${\($color->reset())}";
    say "${\($color->info())}[*] الفاصل بين القفزات: $hop_interval ثانية${\($color->reset())}";
    
    # الحصول على أفضل القنوات للقفز
    my $scan_results = channel_scan_all($interface, "both");
    my @best_channels = sort { $b->{quality} <=> $a->{quality} } @$scan_results;
    @best_channels = @best_channels[0..4];  # أفضل 5 قنوات
    
    say "\n${\($color->info())}[*] بدء القفز بين القنوات...${\($color->reset())}";
    say "${\($color->warning())}[!] سيتم التنقل بين أفضل 5 قنوات${\($color->reset())}";
    
    my $start_time = time();
    my $hop_count = 0;
    
    while ((time() - $start_time) < $duration) {
        for my $channel_info (@best_channels) {
            last if (time() - $start_time) >= $duration;
            
            my $channel = $channel_info->{channel};
            _set_channel($interface, $channel);
            $hop_count++;
            
            my $elapsed = time() - $start_time;
            print "\r${\($color->info())}[$elapsed ث] القفز إلى القناة $channel - العدد: $hop_count${\($color->reset())}";
            
            sleep($hop_interval);
        }
    }
    
    print "\n";
    say "\n${\($color->success())}[✓] اكتمل القفز بين القنوات${\($color->reset())}";
    say "   → عدد القفزات: $hop_count";
    say "   → القنوات المستخدمة: " . join(", ", map { $_->{channel} } @best_channels);
    
    return {
        hop_count => $hop_count,
        channels => [map { $_->{channel} } @best_channels],
        duration => $duration
    };
}

# =============================================================================
# دوال مساعدة داخلية
# =============================================================================

sub _set_channel {
    my ($interface, $channel) = @_;
    # محاكاة ضبط القناة
    return 1;
}

sub _scan_channel {
    my ($channel) = @_;
    
    # محاكاة عدد الشبكات على القناة
    # القنوات الأكثر ازدحاماً (1,6,11) تحصل على شبكات أكثر
    if ($channel == 1 || $channel == 6 || $channel == 11) {
        return int(rand(15)) + 5;  # 5-20 شبكة
    } elsif ($channel <= 11) {
        return int(rand(8)) + 1;   # 1-9 شبكات
    } else {
        return int(rand(5));        # 0-5 شبكات (5GHz أقل ازدحاماً)
    }
}

sub _measure_interference {
    my ($channel) = @_;
    
    # محاكاة مستوى التداخل
    # قنوات 2.4GHz أكثر تداخلاً
    if ($channel <= 11) {
        return int(rand(60)) + 20;  # 20-80%
    } else {
        return int(rand(40)) + 10;  # 10-50%
    }
}

sub _calculate_channel_quality {
    my ($networks, $interference) = @_;
    
    # الجودة = 100 - (تداخل + (شبكات * 2))
    my $quality = 100 - ($interference + ($networks * 2));
    $quality = 0 if $quality < 0;
    $quality = 100 if $quality > 100;
    
    return $quality;
}

sub _display_scan_results {
    my ($results) = @_;
    
    my $color = Colors->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    📋 نتائج مسح القنوات 📋                           ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    # عرض جدول النتائج
    say "\n${\($color->info())}القناة | الشبكات | التداخل | الجودة | التوصية${\($color->reset())}";
    say "-------|---------|----------|--------|----------";
    
    for my $result (@$results) {
        my $quality = $result->{quality};
        my $recommendation;
        my $rec_color;
        
        if ($quality >= 80) {
            $recommendation = "ممتاز ✓";
            $rec_color = $color->success();
        } elsif ($quality >= 60) {
            $recommendation = "جيد ✓";
            $rec_color = $color->info();
        } elsif ($quality >= 40) {
            $recommendation = "مقبول ⚠️";
            $rec_color = $color->warning();
        } else {
            $recommendation = "سيء ✗";
            $rec_color = $color->error();
        }
        
        printf "  %3d  |    %2d    |    %3d%%   |   %3d%%   | ${\($rec_color)}%s${\($color->reset())}\n",
               $result->{channel}, $result->{networks}, $result->{interference}, 
               int($quality), $recommendation;
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

1;  # نهاية الوحدة
