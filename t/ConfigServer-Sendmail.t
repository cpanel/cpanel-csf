#!/usr/local/cpanel/3rdparty/bin/perl

use lib 't/lib';
use FindBin::libs;

use cPstrict;

use Test2::V0;
use Test2::Tools::Explain;
use Test2::Plugin::NoWarnings;

use MockConfig;

# Now load the module under test
use ConfigServer::Sendmail ();

# Set required config values
set_config(
    LF_ALERT_TO   => 'admin@example.com',
    LF_ALERT_FROM => 'csf@example.com',
    LF_ALERT_SMTP => '',
    SENDMAIL      => '/usr/sbin/sendmail',
    DEBUG         => 0,
);

# Track SMTP calls for verification
our @smtp_calls;
our $mock_smtp_success = 1;
our $captured_mail_data;

# Mock Net::SMTP using Test2::Mock
my $smtp_mock = mock 'Net::SMTP' => (
    override => [
        new => sub {
            my ( $class, $host, %opts ) = @_;
            push @main::smtp_calls, { action => 'new', host => $host, opts => \%opts };
            return unless $main::mock_smtp_success;
            my $self = bless { host => $host }, $class;
            return $self;
        },
        mail => sub {
            my ( $self, $from ) = @_;
            push @main::smtp_calls, { action => 'mail', from => $from };
            return 1;
        },
        to => sub {
            my ( $self, $to ) = @_;
            push @main::smtp_calls, { action => 'to', to => $to };
            return 1;
        },
        data => sub {
            push @main::smtp_calls, { action => 'data' };
            return 1;
        },
        datasend => sub {
            my ( $self, $data ) = @_;
            push @main::smtp_calls, { action => 'datasend', data => $data };
            $main::captured_mail_data = $data;
            return 1;
        },
        dataend => sub {
            push @main::smtp_calls, { action => 'dataend' };
            return 1;
        },
        quit => sub {
            push @main::smtp_calls, { action => 'quit' };
            return 1;
        },
    ],
);

# =============================================================================
# Public API Existence Tests
# =============================================================================

subtest 'Public API exists' => sub {
    can_ok( 'ConfigServer::Sendmail', 'relay' );
};

# =============================================================================
# _wraptext Unit Tests
# =============================================================================

subtest '_wraptext with short text' => sub {
    my $short  = "This is a short line.";
    my $result = ConfigServer::Sendmail::_wraptext( $short, 80 );
    like( $result, qr/This is a short line\./, 'Short text preserved' );
};

subtest '_wraptext with long text' => sub {
    my $long   = "A" x 100;
    my $result = ConfigServer::Sendmail::_wraptext( $long, 50 );

    # Long text without spaces cannot be wrapped at word boundaries
    # but the function should still return valid output
    ok( defined $result,        'Result is defined for long text without spaces' );
    ok( length($result) >= 100, 'Original content preserved when no wrap points' );
};

subtest '_wraptext with spaces for wrapping' => sub {
    my $text   = "word " x 30;                                     # 150 chars with spaces
    my $result = ConfigServer::Sendmail::_wraptext( $text, 50 );
    ok( defined $result, 'Result is defined' );

    # Should have wrapped at space boundaries
    my @lines = split /\n/, $result;
    foreach my $line (@lines) {
        ok( length($line) <= 51, "Line length <= column limit (got " . length($line) . ")" )
          if length($line) > 0;
    }
};

subtest '_wraptext with empty string' => sub {
    my $result = ConfigServer::Sendmail::_wraptext( '', 80 );
    is( $result, '', 'Empty string returns empty string' );
};

subtest '_wraptext preserves multiple lines' => sub {
    my $text   = "Line 1\nLine 2\nLine 3";
    my $result = ConfigServer::Sendmail::_wraptext( $text, 80 );
    like( $result, qr/Line 1/, 'Line 1 preserved' );
    like( $result, qr/Line 2/, 'Line 2 preserved' );
    like( $result, qr/Line 3/, 'Line 3 preserved' );
};

subtest '_wraptext handles newlines in long lines' => sub {
    my $text   = "Short line\n" . ( "word " x 30 ) . "\nAnother short";
    my $result = ConfigServer::Sendmail::_wraptext( $text, 50 );
    ok( defined $result, 'Result is defined' );
    like( $result, qr/Short line/,    'First line preserved' );
    like( $result, qr/Another short/, 'Last line preserved' );
};

# =============================================================================
# _get_hostname Tests
# =============================================================================

subtest '_get_hostname returns a string' => sub {
    my $hostname = ConfigServer::Sendmail::_get_hostname();
    ok( defined $hostname,     'Hostname is defined' );
    ok( length($hostname) > 0, 'Hostname is not empty' );
};

subtest '_get_hostname caches result' => sub {
    my $first  = ConfigServer::Sendmail::_get_hostname();
    my $second = ConfigServer::Sendmail::_get_hostname();
    is( $first, $second, 'Hostname is cached (same value returned)' );
};

# =============================================================================
# _get_timezone Tests
# =============================================================================

subtest '_get_timezone returns timezone string' => sub {
    my $tz = ConfigServer::Sendmail::_get_timezone();
    ok( defined $tz, 'Timezone is defined' );

    # Timezone should be in +HHMM or -HHMM format
    like( $tz, qr/^[+-]\d{4}$/, 'Timezone matches expected format' );
};

subtest '_get_timezone caches result' => sub {
    my $first  = ConfigServer::Sendmail::_get_timezone();
    my $second = ConfigServer::Sendmail::_get_timezone();
    is( $first, $second, 'Timezone is cached (same value returned)' );
};

# =============================================================================
# relay() with SMTP Tests
# =============================================================================

subtest 'relay uses SMTP when LF_ALERT_SMTP is set' => sub {
    reset_test_state();
    set_config(
        LF_ALERT_TO   => 'admin@example.com',
        LF_ALERT_FROM => 'csf@example.com',
        LF_ALERT_SMTP => 'smtp.example.com',
        SENDMAIL      => '/usr/sbin/sendmail',
        DEBUG         => 0,
    );

    ConfigServer::Sendmail::relay(
        '', '',
        'Subject: Test',
        'To: override@example.com',
        'From: sender@example.com',
        '',
        'Body text'
    );

    # Verify SMTP was used
    my @new_calls = grep { $_->{action} eq 'new' } @smtp_calls;
    is( scalar @new_calls,     1,                  'SMTP new() called once' );
    is( $new_calls[0]->{host}, 'smtp.example.com', 'SMTP host is correct' );

    # Verify mail transaction
    my @mail_calls = grep { $_->{action} eq 'mail' } @smtp_calls;
    is( scalar @mail_calls, 1, 'SMTP mail() called' );

    my @to_calls = grep { $_->{action} eq 'to' } @smtp_calls;
    is( scalar @to_calls, 1, 'SMTP to() called' );

    my @quit_calls = grep { $_->{action} eq 'quit' } @smtp_calls;
    is( scalar @quit_calls, 1, 'SMTP quit() called' );
};

subtest 'relay SMTP uses config addresses when params empty' => sub {
    reset_test_state();
    set_config(
        LF_ALERT_TO   => 'config-to@example.com',
        LF_ALERT_FROM => 'config-from@example.com',
        LF_ALERT_SMTP => 'smtp.example.com',
        SENDMAIL      => '/usr/sbin/sendmail',
        DEBUG         => 0,
    );

    ConfigServer::Sendmail::relay(
        '', '',
        'Subject: Test',
        '',
        'Body'
    );

    my @mail_calls = grep { $_->{action} eq 'mail' } @smtp_calls;
    my @to_calls   = grep { $_->{action} eq 'to' } @smtp_calls;

    # From should include hostname if no @ present
    like( $mail_calls[0]->{from}, qr/config-from/, 'SMTP from uses config value' );
    like( $to_calls[0]->{to},     qr/config-to/,   'SMTP to uses config value' );
};

subtest 'relay SMTP appends hostname when no @ in address' => sub {
    reset_test_state();
    set_config(
        LF_ALERT_TO   => 'root',
        LF_ALERT_FROM => 'csf',
        LF_ALERT_SMTP => 'smtp.example.com',
        SENDMAIL      => '/usr/sbin/sendmail',
        DEBUG         => 0,
    );

    ConfigServer::Sendmail::relay(
        '', '',
        'Subject: Test',
        '',
        'Body'
    );

    my @mail_calls = grep { $_->{action} eq 'mail' } @smtp_calls;
    my @to_calls   = grep { $_->{action} eq 'to' } @smtp_calls;

    like( $mail_calls[0]->{from}, qr/@/, 'SMTP from has @ appended with hostname' );
    like( $to_calls[0]->{to},     qr/@/, 'SMTP to has @ appended with hostname' );
};

# =============================================================================
# Email Processing Tests
# =============================================================================

subtest 'relay replaces [time] placeholder' => sub {
    reset_test_state();
    set_config(
        LF_ALERT_TO   => 'admin@example.com',
        LF_ALERT_FROM => 'csf@example.com',
        LF_ALERT_SMTP => 'smtp.example.com',
        SENDMAIL      => '/usr/sbin/sendmail',
        DEBUG         => 0,
    );

    ConfigServer::Sendmail::relay(
        '', '',
        'Subject: Alert at [time]',
        '',
        'Event occurred at [time]'
    );

    ok( defined $captured_mail_data, 'Mail data was captured' );
    unlike( $captured_mail_data, qr/\[time\]/, '[time] placeholder replaced' );
};

subtest 'relay replaces [hostname] placeholder' => sub {
    reset_test_state();
    set_config(
        LF_ALERT_TO   => 'admin@example.com',
        LF_ALERT_FROM => 'csf@example.com',
        LF_ALERT_SMTP => 'smtp.example.com',
        SENDMAIL      => '/usr/sbin/sendmail',
        DEBUG         => 0,
    );

    ConfigServer::Sendmail::relay(
        '', '',
        'Subject: Alert from [hostname]',
        '',
        'Server: [hostname]'
    );

    ok( defined $captured_mail_data, 'Mail data was captured' );
    unlike( $captured_mail_data, qr/\[hostname\]/, '[hostname] placeholder replaced' );
};

subtest 'relay sanitizes email addresses' => sub {
    reset_test_state();
    set_config(
        LF_ALERT_TO   => 'admin@example.com',
        LF_ALERT_FROM => 'csf@example.com',
        LF_ALERT_SMTP => 'smtp.example.com',
        SENDMAIL      => '/usr/sbin/sendmail',
        DEBUG         => 0,
    );

    # Pass addresses with extra characters
    ConfigServer::Sendmail::relay(
        '"Admin" <admin@example.com>',
        '"CSF" <csf@example.com>',
        'Subject: Test',
        '',
        'Body'
    );

    my @mail_calls = grep { $_->{action} eq 'mail' } @smtp_calls;
    my @to_calls   = grep { $_->{action} eq 'to' } @smtp_calls;

    # Addresses should be sanitized to just the email part
    is( $mail_calls[0]->{from}, 'csf@example.com',   'From address sanitized' );
    is( $to_calls[0]->{to},     'admin@example.com', 'To address sanitized' );
};

subtest 'relay overrides header To with LF_ALERT_TO' => sub {
    reset_test_state();
    set_config(
        LF_ALERT_TO   => 'override@example.com',
        LF_ALERT_FROM => 'csf@example.com',
        LF_ALERT_SMTP => 'smtp.example.com',
        SENDMAIL      => '/usr/sbin/sendmail',
        DEBUG         => 0,
    );

    ConfigServer::Sendmail::relay(
        '', '',
        'Subject: Test',
        'To: original@example.com',
        '',
        'Body'
    );

    ok( defined $captured_mail_data, 'Mail data was captured' );
    like( $captured_mail_data, qr/To: override\@example\.com/i, 'To header replaced with config value' );
};

subtest 'relay overrides header From with LF_ALERT_FROM' => sub {
    reset_test_state();
    set_config(
        LF_ALERT_TO   => 'admin@example.com',
        LF_ALERT_FROM => 'override@example.com',
        LF_ALERT_SMTP => 'smtp.example.com',
        SENDMAIL      => '/usr/sbin/sendmail',
        DEBUG         => 0,
    );

    ConfigServer::Sendmail::relay(
        '', '',
        'Subject: Test',
        'From: original@example.com',
        '',
        'Body'
    );

    ok( defined $captured_mail_data, 'Mail data was captured' );
    like( $captured_mail_data, qr/From: override\@example\.com/i, 'From header replaced with config value' );
};

subtest 'relay defaults to root when addresses empty' => sub {
    reset_test_state();
    set_config(
        LF_ALERT_TO   => '',
        LF_ALERT_FROM => '',
        LF_ALERT_SMTP => 'smtp.example.com',
        SENDMAIL      => '/usr/sbin/sendmail',
        DEBUG         => 0,
    );

    ConfigServer::Sendmail::relay(
        '', '',
        'Subject: Test',
        '',
        'Body'
    );

    my @mail_calls = grep { $_->{action} eq 'mail' } @smtp_calls;
    my @to_calls   = grep { $_->{action} eq 'to' } @smtp_calls;

    # Should default to root@hostname
    like( $mail_calls[0]->{from}, qr/^root@/, 'From defaults to root@hostname' );
    like( $to_calls[0]->{to},     qr/^root@/, 'To defaults to root@hostname' );
};

subtest 'relay wraps long lines' => sub {
    reset_test_state();
    set_config(
        LF_ALERT_TO   => 'admin@example.com',
        LF_ALERT_FROM => 'csf@example.com',
        LF_ALERT_SMTP => 'smtp.example.com',
        SENDMAIL      => '/usr/sbin/sendmail',
        DEBUG         => 0,
    );

    my $long_body = "word " x 250;    # Very long line
    ConfigServer::Sendmail::relay(
        '', '',
        'Subject: Test',
        '',
        $long_body
    );

    ok( defined $captured_mail_data, 'Mail data was captured' );

    # The function wraps at 990 chars
    my @lines   = split /\n/, $captured_mail_data;
    my $max_len = 0;
    for my $line (@lines) {
        $max_len = length($line) if length($line) > $max_len;
    }
    ok( $max_len <= 991, "Lines wrapped to RFC limit (max found: $max_len)" );
};

subtest 'relay handles carriage returns' => sub {
    reset_test_state();
    set_config(
        LF_ALERT_TO   => 'admin@example.com',
        LF_ALERT_FROM => 'csf@example.com',
        LF_ALERT_SMTP => 'smtp.example.com',
        SENDMAIL      => '/usr/sbin/sendmail',
        DEBUG         => 0,
    );

    # Each line has only one \r which gets removed
    ConfigServer::Sendmail::relay(
        '', '',
        "Subject: Test\r",
        "\r",
        "Body with carriage return\r"
    );

    ok( defined $captured_mail_data, 'Mail data was captured' );

    # The code removes one \r per line, so single \r per line should be stripped
    unlike( $captured_mail_data, qr/\r/, 'Carriage returns removed (one per line)' );
};

# =============================================================================
# SMTP Failure Handling
# =============================================================================

subtest 'relay handles SMTP connection failure' => sub {
    reset_test_state();
    $mock_smtp_success = 0;    # SMTP->new() returns undef

    set_config(
        LF_ALERT_TO   => 'admin@example.com',
        LF_ALERT_FROM => 'csf@example.com',
        LF_ALERT_SMTP => 'smtp.example.com',
        SENDMAIL      => '/usr/sbin/sendmail',
        DEBUG         => 0,
    );

    # Should not die when SMTP fails
    my $died = 0;
    eval {
        local $SIG{__WARN__} = sub { };    # Suppress carp warning
        ConfigServer::Sendmail::relay(
            '', '',
            'Subject: Test',
            '',
            'Body'
        );
    };
    $died = 1 if $@;

    ok( !$died, 'relay does not die when SMTP connection fails' );
};

# =============================================================================
# Completion
# =============================================================================

done_testing();

# Helper to reset test state
sub reset_test_state {
    @main::smtp_calls         = ();
    $main::mock_smtp_success  = 1;
    $main::captured_mail_data = undef;
    set_config(
        LF_ALERT_TO   => 'admin@example.com',
        LF_ALERT_FROM => 'csf@example.com',
        LF_ALERT_SMTP => '',
        SENDMAIL      => '/nonexistent/sendmail',    # Safety: prevent real email if sendmail path used
        DEBUG         => 0,
    );
    return;
}
