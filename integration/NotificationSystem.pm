package integration::NotificationSystem;
# =============================================================================
# NotificationSystem.pm - نظام الإشعارات والتنبيهات
# =============================================================================
# الميزات: إشعارات فورية، تنبيهات عبر البريد الإلكتروني، إشعارات سطح المكتب
# =============================================================================

use strict;
use warnings;
use parent 'Exporter';
our @EXPORT_OK = qw(notify_send notify_email notify_desktop notify_config);

use lib '.';
use lib::Utils;
use lib::Colors;
use Time::HiRes qw(time);
use File::Slurp qw(read_file write_file);
use JSON;

# إعدادات الإشعارات
my $NOTIFY_CONFIG_FILE = "$ENV{HOME}/.robinhood/notify_config.json";
my $NOTIFY_CONFIG = {};

# تحميل إعدادات الإشعارات
sub _load_notify_config {
    if (-f $NOTIFY_CONFIG_FILE) {
        my $json = read_file($NOTIFY_CONFIG_FILE);
        eval { $NOTIFY_CONFIG = decode_json($json); };
    }
    
    if (!keys %$NOTIFY_CONFIG) {
        $NOTIFY_CONFIG = {
            enabled => 1,
            desktop => 1,
            email => 0,
            email_address => "",
            sound => 1,
            min_level => "info",
            max_stored => 100
        };
    }
}

# حفظ إعدادات الإشعارات
sub _save_notify_config {
    write_file($NOTIFY_CONFIG_FILE, encode_json($NOTIFY_CONFIG));
}

# سجل الإشعارات
my @NOTIFICATION_HISTORY = ();

# =============================================================================
# إرسال إشعار عام
# =============================================================================
sub notify_send {
    my ($title, $message, $level, $options) = @_;
    
    my $color = Colors->new();
    my $utils = Utils->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    🔔 إرسال إشعار 🔔                                  ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    _load_notify_config();
    
    $title //= "RobinHood Wibey";
    $message //= "تم تنفيذ عملية بنجاح";
    $level //= "info";
    $options //= {};
    
    # التحقق من مستوى الإشعار
    my $level_order = { 'critical' => 4, 'high' => 3, 'warning' => 2, 'info' => 1 };
    my $min_order = $level_order->{$NOTIFY_CONFIG->{min_level}} || 1;
    my $current_order = $level_order->{$level} || 1;
    
    if ($current_order < $min_order) {
        say "${\($color->info())}[*] تم تجاهل الإشعار (المستوى $level أقل من الحد الأدنى)${\($color->reset())}";
        return 0;
    }
    
    # تحديد لون الإشعار حسب المستوى
    my $level_color;
    my $level_icon;
    if ($level eq 'critical') {
        $level_color = $color->error();
        $level_icon = "🔴";
    } elsif ($level eq 'high') {
        $level_color = $color->error();
        $level_icon = "🟠";
    } elsif ($level eq 'warning') {
        $level_color = $color->warning();
        $level_icon = "⚠️";
    } else {
        $level_color = $color->info();
        $level_icon = "ℹ️";
    }
    
    # عرض الإشعار في الطرفية
    say "\n${\($level_color())}${\($level_icon())} [$level] $title${\($color->reset())}";
    say "   → $message";
    
    # إشعار سطح المكتب
    if ($NOTIFY_CONFIG->{desktop}) {
        _send_desktop_notification($title, $message, $level);
    }
    
    # إشعار بريد إلكتروني
    if ($NOTIFY_CONFIG->{email} && ($level eq 'critical' || $level eq 'high')) {
        _send_email_notification($title, $message, $level);
    }
    
    # تشغيل صوت
    if ($NOTIFY_CONFIG->{sound} && $level ne 'info') {
        _play_notification_sound($level);
    }
    
    # تسجيل الإشعار
    my $notification = {
        id => scalar(@NOTIFICATION_HISTORY) + 1,
        timestamp => time(),
        time => scalar(localtime()),
        title => $title,
        message => $message,
        level => $level
    };
    
    push @NOTIFICATION_HISTORY, $notification;
    
    # الاحتفاظ بآخر 100 إشعار فقط
    if (scalar(@NOTIFICATION_HISTORY) > $NOTIFY_CONFIG->{max_stored}) {
        shift @NOTIFICATION_HISTORY;
    }
    
    # حفظ السجل
    _save_notification_history();
    
    $utils->save_result('notification_system', {
        action => 'send',
        title => $title,
        level => $level,
        timestamp => time()
    });
    
    return 1;
}

# =============================================================================
# إرسال إشعار بريد إلكتروني
# =============================================================================
sub notify_email {
    my ($to, $subject, $body, $attachments) = @_;
    
    my $color = Colors->new();
    my $utils = Utils->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    📧 إشعار بريد إلكتروني 📧                          ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    _load_notify_config();
    
    $to //= $NOTIFY_CONFIG->{email_address} || "admin@localhost";
    $subject //= "تنبيه من RobinHood Wibey";
    $body //= "هذا تنبيه تلقائي من نظام RobinHood Wibey";
    $attachments //= [];
    
    say "${\($color->info())}[*] إرسال بريد إلكتروني إلى: $to${\($color->reset())}";
    say "   → الموضوع: $subject";
    
    # محاكاة إرسال البريد الإلكتروني
    my $email_result = _send_email($to, $subject, $body, $attachments);
    
    if ($email_result->{success}) {
        say "\n${\($color->success())}[✓] تم إرسال البريد الإلكتروني بنجاح${\($color->reset())}";
    } else {
        say "\n${\($color->error())}[!] فشل إرسال البريد الإلكتروني: $email_result->{error}${\($color->reset())}";
    }
    
    $utils->save_result('notification_email', {
        to => $to,
        subject => $subject,
        success => $email_result->{success}
    });
    
    return $email_result;
}

# =============================================================================
# إشعار سطح المكتب
# =============================================================================
sub notify_desktop {
    my ($title, $message, $urgency, $timeout) = @_;
    
    my $color = Colors->new();
    my $utils = Utils->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    🖥️ إشعار سطح المكتب 🖥️                            ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    $title //= "RobinHood Wibey";
    $message //= "حدث جديد في النظام";
    $urgency //= "normal";
    $timeout //= 5;
    
    say "${\($color->info())}[*] إرسال إشعار سطح المكتب: $title${\($color->reset())}";
    
    my $result = _send_desktop_notification($title, $message, $urgency, $timeout);
    
    if ($result) {
        say "\n${\($color->success())}[✓] تم إرسال إشعار سطح المكتب${\($color->reset())}";
    } else {
        say "\n${\($color->warning())}[!] غير مدعوم في هذا النظام${\($color->reset())}";
    }
    
    $utils->save_result('notification_desktop', {
        title => $title,
        urgency => $urgency,
        success => $result
    });
    
    return $result;
}

# =============================================================================
# تكوين نظام الإشعارات
# =============================================================================
sub notify_config {
    my ($settings) = @_;
    
    my $color = Colors->new();
    my $utils = Utils->new();
    
    say "\n${\($color->quantum())}╔══════════════════════════════════════════════════════════════════╗${\($color->reset())}";
    say "${\($color->quantum())}║                    ⚙️ تكوين الإشعارات ⚙️                              ║${\($color->reset())}";
    say "${\($color->quantum())}╚══════════════════════════════════════════════════════════════════╝${\($color->reset())}";
    
    _load_notify_config();
    
    if ($settings) {
        # تحديث الإعدادات
        for my $key (keys %$settings) {
            if (exists $NOTIFY_CONFIG->{$key}) {
                $NOTIFY_CONFIG->{$key} = $settings->{$key};
                say "${\($color->info())}[✓] تم تحديث $key → $settings->{$key}${\($color->reset())}";
            }
        }
        _save_notify_config();
    }
    
    # عرض الإعدادات الحالية
    say "\n${\($color->quantum())}📋 إعدادات الإشعارات الحالية:${\($color->reset())}";
    say "   → تمكين الإشعارات: " . ($NOTIFY_CONFIG->{enabled} ? "نعم" : "لا");
    say "   → إشعارات سطح المكتب: " . ($NOTIFY_CONFIG->{desktop} ? "مفعل" : "معطل");
    say "   → إشعارات البريد الإلكتروني: " . ($NOTIFY_CONFIG->{email} ? "مفعل" : "معطل");
    say "   → البريد الإلكتروني: $NOTIFY_CONFIG->{email_address}" if $NOTIFY_CONFIG->{email};
    say "   → الصوت: " . ($NOTIFY_CONFIG->{sound} ? "مفعل" : "معطل");
    say "   → الحد الأدنى للمستوى: $NOTIFY_CONFIG->{min_level}";
    say "   → عدد الإشعارات المخزنة: " . scalar(@NOTIFICATION_HISTORY);
    
    $utils->save_result('notification_config', {
        config => $NOTIFY_CONFIG
    });
    
    return $NOTIFY_CONFIG;
}

# =============================================================================
# دوال مساعدة داخلية
# =============================================================================

sub _send_desktop_notification {
    my ($title, $message, $urgency, $timeout) = @_;
    
    # محاولة استخدام notify-send (Linux)
    if (system("which notify-send > /dev/null 2>&1") == 0) {
        my $urgency_flag = "";
        if ($urgency eq 'critical') {
            $urgency_flag = "-u critical";
        } elsif ($urgency eq 'low') {
            $urgency_flag = "-u low";
        }
        
        system("notify-send $urgency_flag -t " . ($timeout * 1000) . " '$title' '$message'");
        return 1;
    }
    
    # محاكاة للإصدارات الأخرى
    return 0;
}

sub _send_email_notification {
    my ($title, $message, $level) = @_;
    
    my $subject = "[$level] $title";
    my $body = "الوقت: " . localtime() . "\n\n$message\n\n-- \nRobinHood Wibey Notification System";
    
    return _send_email($NOTIFY_CONFIG->{email_address}, $subject, $body, []);
}

sub _send_email {
    my ($to, $subject, $body, $attachments) = @_;
    
    # محاكاة إرسال البريد الإلكتروني
    # في البيئة الحقيقية، يمكن استخدام Net::SMTP أو Mail::Sendmail
    
    eval {
        # محاكاة الاتصال بخادم SMTP
        my $log_entry = "[EMAIL] To: $to | Subject: $subject | Body: " . substr($body, 0, 100);
        _log_notification($log_entry);
    };
    
    if ($@) {
        return { success => 0, error => $@ };
    }
    
    # نجاح عشوائي للمحاكاة
    return { success => 1 };
}

sub _play_notification_sound {
    my ($level) = @_;
    
    # محاكاة تشغيل الصوت
    if ($level eq 'critical') {
        # صوت تحذيري
        print "\a" x 3;
    } elsif ($level eq 'high') {
        print "\a" x 2;
    } else {
        print "\a";
    }
}

sub _log_notification {
    my ($message) = @_;
    
    my $log_file = "$ENV{HOME}/.robinhood/logs/notifications.log";
    open(my $fh, '>>', $log_file);
    print $fh "[" . localtime() . "] $message\n";
    close($fh);
}

sub _save_notification_history {
    my $history_file = "$ENV{HOME}/.robinhood/logs/notification_history.json";
    write_file($history_file, encode_json(\@NOTIFICATION_HISTORY));
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

sub decode_json {
    my ($json) = @_;
    return {};
}

# تحميل الإعدادات والتاريخ عند التحميل
_load_notify_config();

my $history_file = "$ENV{HOME}/.robinhood/logs/notification_history.json";
if (-f $history_file) {
    my $json = read_file($history_file);
    eval { @NOTIFICATION_HISTORY = @{decode_json($json)}; };
}

1;  # نهاية الوحدة
