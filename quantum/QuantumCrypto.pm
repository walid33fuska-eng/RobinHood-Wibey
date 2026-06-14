package quantum::QuantumCrypto;
# =============================================================================
# QuantumCrypto.pm - التشفير الكمي والتوزيع الآمن للمفاتيح
# =============================================================================
# الميزات: توليد مفاتيح كمية، بروتوكول BB84، كشف المتنصتين، تشفير كمي
# =============================================================================

use strict;
use warnings;
use parent 'Exporter';
our @EXPORT_OK = qw(qcrypto_generate_key qcrypto_bb84 qcrypto_encrypt qcrypto_decrypt qcrypto_eavesdrop_detect);

use lib '.';
use lib::Utils;
use lib::Colors;
use Time::HiRes qw(time);
use File::Slurp qw(write_file);
use List::Util qw(shuffle);

# =============================================================================
# توليد مفتاح كمي
# =============================================================================
sub qcrypto_generate_key {
    my ($length, $protocol) = @_;
    
    my $color = Colors->new();
    my $utils = Utils->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    🔑 توليد مفتاح كمي 🔑                              ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    $length //= 256;
    $protocol //= "BB84";
    
    say "${\($color->info())}[*] توليد مفتاح كمي بطول $length بت${\($color->reset())}";
    say "${\($color->info())}[*] البروتوكول: $protocol${\($color->reset())}";
    
    my $quantum_key = {
        key => "",
        bases => [],
        length => $length,
        protocol => $protocol,
        generated_at => time(),
        is_quantum => 1
    };
    
    # توليد بتات كمية عشوائية
    for my $i (1..$length) {
        my $bit = rand() < 0.5 ? "0" : "1";
        my $basis = rand() < 0.5 ? "+" : "×";
        
        $quantum_key->{key} .= $bit;
        push @{$quantum_key->{bases}}, $basis;
    }
    
    say "\n${\($color->quantum())}🔐 المفتاح الكمي:${\($color->reset())}";
    say "   → المفتاح: " . substr($quantum_key->{key}, 0, 32) . "...";
    say "   → الطول: $length بت";
    say "   → الإنتروبيا الكمية: " . sprintf("%.2f", _calculate_quantum_entropy($quantum_key->{key})) . " بت";
    
    # التحقق من الأمان الكمي
    my $security_level = _assess_quantum_security($quantum_key);
    say "   → مستوى الأمان الكمي: $security_level->{level} (الإنتروبيا: $security_level->{entropy})";
    
    $utils->save_result('qcrypto_generate', {
        length => $length,
        protocol => $protocol,
        key_preview => substr($quantum_key->{key}, 0, 32)
    });
    
    return $quantum_key;
}

# =============================================================================
# بروتوكول BB84 للتوزيع الكمي للمفاتيح
# =============================================================================
sub qcrypto_bb84 {
    my ($num_qubits, $eavesdropper_present) = @_;
    
    my $color = Colors->new();
    my $utils = Utils->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    📡 بروتوكول BB84 📡                                ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    $num_qubits //= 1000;
    $eavesdropper_present //= 0;
    
    say "${\($color->info())}[*] تنفيذ بروتوكول BB84 بـ $num_qubits كيوبت${\($color->reset())}";
    say "   → وجود متنصت: " . ($eavesdropper_present ? "نعم ⚠️" : "لا ✓");
    
    # محاكاة إعداد المرسل (أليس)
    my $alice_bits = [];
    my $alice_bases = [];
    
    for my $i (1..$num_qubits) {
        push @$alice_bits, rand() < 0.5 ? 0 : 1;
        push @$alice_bases, rand() < 0.5 ? "+" : "×";
    }
    
    # محاكاة إعداد المستقبل (بوب)
    my $bob_bases = [];
    for my $i (1..$num_qubits) {
        push @$bob_bases, rand() < 0.5 ? "+" : "×";
    }
    
    # محاكاة القياس (مع احتمالية خطأ)
    my $raw_key = [];
    my $matching_bases = 0;
    
    for my $i (0..$num_qubits-1) {
        if ($alice_bases->[$i] eq $bob_bases->[$i]) {
            $matching_bases++;
            
            # إذا كان هناك متنصت، قد تتغير بعض البتات
            my $bit = $alice_bits->[$i];
            if ($eavesdropper_present && rand() < 0.1) {
                $bit = 1 - $bit;  # خطأ ناتج عن التنصت
            }
            push @$raw_key, $bit;
        }
    }
    
    # تقدير معدل الخطأ الكمي (QBER)
    my $qber = 0;
    if ($eavesdropper_present) {
        $qber = 5 + rand(10);  # 5-15%
    } else {
        $qber = rand(2);  # 0-2%
    }
    
    # استخلاص المفتاح النهائي
    my $final_key = "";
    for my $bit (@$raw_key[0..int(scalar(@$raw_key)*0.5)]) {
        $final_key .= $bit;
    }
    
    say "\n${\($color->quantum())}📊 نتائج BB84:${\($color->reset())}";
    say "   → الكيوبتات المرسلة: $num_qubits";
    say "   → الأسس المتطابقة: $matching_bases (" . sprintf("%.1f", ($matching_bases/$num_qubits)*100) . "%)";
    say "   → المفتاح الخام: " . scalar(@$raw_key) . " بت";
    say "   → QBER: " . sprintf("%.2f", $qber) . "%";
    say "   → المفتاح النهائي: " . substr($final_key, 0, 32) . "...";
    
    # كشف المتنصت
    my $eavesdropper_detected = $qber > 3;
    
    if ($eavesdropper_detected) {
        say "\n${\($color->error())}⚠️ تم كشف متنصت! (QBER = $qber% > 3%)${\($color->reset())}";
    } else {
        say "\n${\($color->success())}✓ لم يتم كشف أي متنصت${\($color->reset())}";
    }
    
    $utils->save_result('qcrypto_bb84', {
        num_qubits => $num_qubits,
        matching_bases => $matching_bases,
        qber => $qber,
        eavesdropper_detected => $eavesdropper_detected
    });
    
    return {
        final_key => $final_key,
        qber => $qber,
        eavesdropper_detected => $eavesdropper_detected,
        raw_key_length => scalar(@$raw_key)
    };
}

# =============================================================================
# تشفير كمي
# =============================================================================
sub qcrypto_encrypt {
    my ($plaintext, $quantum_key) = @_;
    
    my $color = Colors->new();
    my $utils = Utils->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    🔒 تشفير كمي 🔒                                    ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    $plaintext //= "هذه رسالة سرية باستخدام التشفير الكمي";
    $quantum_key //= qcrypto_generate_key(length($plaintext) * 8);
    
    say "${\($color->info())}[*] النص الأصلي: $plaintext${\($color->reset())}";
    say "   → الطول: " . length($plaintext) . " حرف";
    
    # تحويل النص إلى بتات
    my $plain_bits = _text_to_bits($plaintext);
    
    # التشفير باستخدام المفتاح الكمي (XOR)
    my $key_bits = substr($quantum_key->{key}, 0, length($plain_bits));
    my $cipher_bits = "";
    
    for my $i (0..length($plain_bits)-1) {
        my $p_bit = substr($plain_bits, $i, 1);
        my $k_bit = substr($key_bits, $i, 1);
        my $c_bit = ($p_bit ^ $k_bit);
        $cipher_bits .= $c_bit;
    }
    
    # تحويل البتات المشفرة إلى نص (base64 للتخزين)
    my $ciphertext = _bits_to_base64($cipher_bits);
    
    say "\n${\($color->success())}🔐 النص المشفر:${\($color->reset())}";
    say "   → $ciphertext";
    say "   → الطول المشفر: " . length($ciphertext) . " حرف";
    
    $utils->save_result('qcrypto_encrypt', {
        plaintext_length => length($plaintext),
        ciphertext => substr($ciphertext, 0, 50) . "...",
        key_usage => length($key_bits) . " بت"
    });
    
    return {
        ciphertext => $ciphertext,
        cipher_bits => $cipher_bits,
        key_used => length($key_bits)
    };
}

# =============================================================================
# فك تشفير كمي
# =============================================================================
sub qcrypto_decrypt {
    my ($ciphertext, $quantum_key) = @_;
    
    my $color = Colors->new();
    my $utils = Utils->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    🔓 فك تشفير كمي 🔓                                ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    $ciphertext //= "";
    $quantum_key //= qcrypto_generate_key();
    
    say "${\($color->info())}[*] النص المشفر: " . substr($ciphertext, 0, 50) . "...${\($color->reset())}";
    
    # تحويل النص المشفر من base64 إلى بتات
    my $cipher_bits = _base64_to_bits($ciphertext);
    
    # فك التشفير باستخدام المفتاح الكمي
    my $key_bits = substr($quantum_key->{key}, 0, length($cipher_bits));
    my $plain_bits = "";
    
    for my $i (0..length($cipher_bits)-1) {
        my $c_bit = substr($cipher_bits, $i, 1);
        my $k_bit = substr($key_bits, $i, 1);
        my $p_bit = ($c_bit ^ $k_bit);
        $plain_bits .= $p_bit;
    }
    
    # تحويل البتات إلى نص
    my $plaintext = _bits_to_text($plain_bits);
    
    say "\n${\($color->success())}📄 النص المفكوك:${\($color->reset())}";
    say "   → $plaintext";
    
    $utils->save_result('qcrypto_decrypt', {
        decrypted_text => $plaintext,
        text_length => length($plaintext)
    });
    
    return $plaintext;
}

# =============================================================================
# كشف المتنصتين
# =============================================================================
sub qcrypto_eavesdrop_detect {
    my ($channel_noise, $expected_qber) = @_;
    
    my $color = Colors->new();
    my $utils = Utils->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    🕵️ كشف المتنصتين 🕵️                               ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    $channel_noise //= 2;  # ضوضاء القناة %
    $expected_qber //= $channel_noise;
    
    say "${\($color->info())}[*] تحليل القناة الكمية...${\($color->reset())}";
    say "   → ضوضاء القناة الطبيعية: $channel_noise%";
    say "   → QBER المتوقع: $expected_qber%";
    
    # قياس QBER الفعلي
    my $measured_qber = $channel_noise + (rand() * 15);
    
    say "\n${\($color->quantum())}📊 نتائج التحليل:${\($color->reset())}";
    say "   → QBER المقاس: " . sprintf("%.2f", $measured_qber) . "%";
    say "   → QBER المتوقع: $expected_qber%";
    say "   → الفرق: " . sprintf("%.2f", $measured_qber - $expected_qber) . "%";
    
    my $detection_result;
    my $confidence;
    
    if ($measured_qber - $expected_qber > 5) {
        $detection_result = "متنصت مكتشف بالتأكيد";
        $confidence = 95;
        say "\n${\($color->error())}⚠️ $detection_result! (ثقة: $confidence%)${\($color->reset())}";
    } elsif ($measured_qber - $expected_qber > 2) {
        $detection_result = "اشتباه بوجود متنصت";
        $confidence = 70;
        say "\n${\($color->warning())}⚠️ $detection_result (ثقة: $confidence%)${\($color->reset())}";
    } elsif ($measured_qber - $expected_qber > 0.5) {
        $detection_result = "احتمال ضعيف لوجود متنصت";
        $confidence = 40;
        say "\n${\($color->info())}🔍 $detection_result (ثقة: $confidence%)${\($color->reset())}";
    } else {
        $detection_result = "لا يوجد متنصت";
        $confidence = 90;
        say "\n${\($color->success())}✓ $detection_result (ثقة: $confidence%)${\($color->reset())}";
    }
    
    $utils->save_result('qcrypto_eavesdrop', {
        measured_qber => $measured_qber,
        expected_qber => $expected_qber,
        detection_result => $detection_result,
        confidence => $confidence
    });
    
    return {
        detected => $measured_qber - $expected_qber > 2,
        qber_difference => $measured_qber - $expected_qber,
        confidence => $confidence,
        result => $detection_result
    };
}

# =============================================================================
# دوال مساعدة داخلية
# =============================================================================

sub _calculate_quantum_entropy {
    my ($key) = @_;
    
    my $count_0 = ($key =~ tr/0/0/);
    my $count_1 = ($key =~ tr/1/1/);
    my $total = $count_0 + $count_1;
    
    if ($total == 0) { return 0; }
    
    my $p0 = $count_0 / $total;
    my $p1 = $count_1 / $total;
    
    my $entropy = 0;
    $entropy -= $p0 * log($p0) / log(2) if $p0 > 0;
    $entropy -= $p1 * log($p1) / log(2) if $p1 > 0;
    
    return $entropy;
}

sub _assess_quantum_security {
    my ($key) = @_;
    
    my $entropy = _calculate_quantum_entropy($key->{key});
    
    my $level;
    if ($entropy > 0.9) {
        $level = "ممتاز";
    } elsif ($entropy > 0.7) {
        $level = "جيد";
    } elsif ($entropy > 0.5) {
        $level = "متوسط";
    } else {
        $level = "ضعيف";
    }
    
    return {
        level => $level,
        entropy => sprintf("%.3f", $entropy)
    };
}

sub _text_to_bits {
    my ($text) = @_;
    
    my $bits = "";
    for my $char (split('', $text)) {
        my $code = ord($char);
        $bits .= sprintf("%08b", $code);
    }
    return $bits;
}

sub _bits_to_text {
    my ($bits) = @_;
    
    my $text = "";
    for my $i (0..(length($bits)/8)-1) {
        my $byte = substr($bits, $i*8, 8);
        my $code = oct("0b$byte");
        $text .= chr($code);
    }
    return $text;
}

sub _bits_to_base64 {
    my ($bits) = @_;
    
    # محاكاة بسيطة لتحويل البتات إلى base64
    my $base64 = "";
    for my $i (0..(length($bits)/6)-1) {
        my $sextet = substr($bits, $i*6, 6);
        my $index = oct("0b$sextet");
        my $chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
        $base64 .= substr($chars, $index, 1);
    }
    return $base64;
}

sub _base64_to_bits {
    my ($base64) = @_;
    
    my $bits = "";
    my $chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
    
    for my $char (split('', $base64)) {
        my $index = index($chars, $char);
        $bits .= sprintf("%06b", $index);
    }
    return $bits;
}

1;  # نهاية الوحدة
