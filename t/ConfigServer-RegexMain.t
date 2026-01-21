#!/usr/local/cpanel/3rdparty/bin/perl

#                                      Copyright 2025 WebPros International, LLC
#                                                           All rights reserved.
# copyright@cpanel.net                                         http://cpanel.net
# This code is subject to the cPanel license. Unauthorized copying is prohibited.

use strict;
use warnings;

use Test2::V0;
use Test2::Tools::Explain;
use Test2::Plugin::NoWarnings;

use lib 't/lib';
use MockConfig;

# Now load the module under test
use ConfigServer::RegexMain;

# Storage for logged messages
our @logged_messages;

# Mock ConfigServer::GetEthDev
my $ethdev_mock = mock 'ConfigServer::GetEthDev' => (
    override => [
        new  => sub { return bless {}, 'ConfigServer::GetEthDev'; },
        brd  => sub { return ( 'eth0' => '192.168.1.255' ); },
        ipv4 => sub { return ( 'eth0' => '192.168.1.10' ); },
    ],
);

# Mock ConfigServer::CheckIP
my $checkip_mock = mock 'ConfigServer::CheckIP' => (
    override => [
        checkip => sub {
            my $ip_ref = shift;
            my $ip     = ref $ip_ref ? $$ip_ref : $ip_ref;

            # Simple validation - real IPs only
            return 0 if !defined $ip || $ip eq '';
            return 0 if $ip =~ /[a-z]/i && $ip !~ /^[a-f0-9:]+$/i;    # Letters except hex for IPv6
            return 1 if $ip =~ /^(?:\d{1,3}\.){3}\d{1,3}$/;           # IPv4
            return 1 if $ip =~ /^[a-f0-9:]+$/i;                       # IPv6
            return 0;
        },
    ],
);

# Mock ConfigServer::Logger
my $logger_mock = mock 'ConfigServer::Logger' => (
    override => [
        logfile => sub {
            my $msg = shift;
            push @logged_messages, $msg;
            return;
        },
    ],
);

# Mock Cpanel::Config::LoadWwwAcctConf
my $wwwacct_mock = mock 'Cpanel::Config::LoadWwwAcctConf' => (
    override => [
        loadwwwacctconf => sub {
            return {
                HOMEDIR => '/home',
            };
        },
    ],
);

# Test private subroutines that populate our variables
subtest 'private _config subroutine populates %config' => sub {

    # Clear any existing config
    clear_config();
    %ConfigServer::RegexMain::config = ();

    # Set up mock config
    set_config(
        LF_SSHD                => 1,
        LF_APACHE_ERRPORT      => 0,
        PS_PORTS               => '22,80,443',
        LF_SCRIPT_ALERT        => 1,
        LF_POP3D               => 1,
        LF_IMAPD               => 1,
        LT_POP3D               => 1,
        LT_IMAPD               => 1,
        LF_SSH_EMAIL_ALERT     => 1,
        LF_SU_EMAIL_ALERT      => 1,
        LF_SUDO_EMAIL_ALERT    => 1,
        LF_CONSOLE_EMAIL_ALERT => 1,
        LF_CPANEL_ALERT        => 1,
        LF_WEBMIN_EMAIL_ALERT  => 1,
    );

    # Call the private _config function
    ConfigServer::RegexMain::_config();

    # Verify %config is populated
    ok( %ConfigServer::RegexMain::config, '%config hash is populated' );
    is( $ConfigServer::RegexMain::config{LF_SSHD},  1, 'LF_SSHD config value set' );
    is( $ConfigServer::RegexMain::config{LF_POP3D}, 1, 'LF_POP3D config value set' );

    # Verify LF_APACHE_ERRPORT is set to 2 when not 1
    ok( $ConfigServer::RegexMain::config{LF_APACHE_ERRPORT} > 0, 'LF_APACHE_ERRPORT was set' );

    # Verify logger was called
    ok( scalar @logged_messages > 0, 'Logger was called' );
    like(
        $logged_messages[-1],
        qr/LF_APACHE_ERRPORT/,
        'Logger message contains LF_APACHE_ERRPORT'
    );
};

subtest 'private _eth_info subroutine populates %brd and %ips' => sub {

    # Clear any existing data
    %ConfigServer::RegexMain::brd = ();
    %ConfigServer::RegexMain::ips = ();

    # Call the private _eth_info function
    ConfigServer::RegexMain::_eth_info();

    # Verify %brd and %ips are populated
    ok( %ConfigServer::RegexMain::brd, '%brd hash is populated' );
    ok( %ConfigServer::RegexMain::ips, '%ips hash is populated' );

    is( $ConfigServer::RegexMain::brd{eth0}, '192.168.1.255', 'broadcast address for eth0' );
    is( $ConfigServer::RegexMain::ips{eth0}, '192.168.1.10',  'IPv4 address for eth0' );
};

subtest '_config is idempotent - does not reload if already loaded' => sub {

    # Set initial config
    %ConfigServer::RegexMain::config = ( TEST_KEY => 'test_value' );
    my $initial_count = scalar @logged_messages;

    # Call _config again
    ConfigServer::RegexMain::_config();

    # Verify config was not reloaded
    is( $ConfigServer::RegexMain::config{TEST_KEY}, 'test_value', 'config unchanged' );

    # Logger should not have been called again
    is(
        scalar @logged_messages,
        $initial_count,
        'logger not called again when config already loaded'
    );
};

subtest '_eth_info is idempotent - does not reload if already loaded' => sub {

    # Set initial values
    %ConfigServer::RegexMain::brd = ( test_if => '1.2.3.4' );
    %ConfigServer::RegexMain::ips = ( test_if => '5.6.7.8' );

    # Call _eth_info again
    ConfigServer::RegexMain::_eth_info();

    # Verify data was not reloaded
    is( $ConfigServer::RegexMain::brd{test_if}, '1.2.3.4', 'brd unchanged' );
    is( $ConfigServer::RegexMain::ips{test_if}, '5.6.7.8', 'ips unchanged' );
};

# Now pre-populate the variables for testing public functions without file access
sub setup_test_environment {
    clear_config();
    @logged_messages = ();

    # Pre-populate %config
    %ConfigServer::RegexMain::config = (
        LF_SSHD                => 1,
        LF_APACHE_ERRPORT      => 2,
        PS_PORTS               => '22,80,443',
        LF_SCRIPT_ALERT        => 1,
        LF_POP3D               => 1,
        LF_IMAPD               => 1,
        LT_POP3D               => 1,
        LT_IMAPD               => 1,
        LF_SSH_EMAIL_ALERT     => 1,
        LF_SU_EMAIL_ALERT      => 1,
        LF_SUDO_EMAIL_ALERT    => 1,
        LF_CONSOLE_EMAIL_ALERT => 1,
        LF_CPANEL_ALERT        => 1,
        DEBUG                  => 0,
    );

    # Pre-populate %brd and %ips
    %ConfigServer::RegexMain::brd = ( eth0 => '192.168.1.255' );
    %ConfigServer::RegexMain::ips = ( eth0 => '192.168.1.10' );

    return;
}

# Test processline function
subtest 'processline - SSH failed login detection' => sub {
    setup_test_environment();

    my %globlogs = (
        SSHD_LOG => { '/var/log/secure' => 1 },
    );

    # Test failed password
    my $line = 'Jan 20 10:15:30 server sshd[1234]: Failed password for invalid user admin from 10.0.0.1 port 54321 ssh2';
    my ( $reason, $ip_acc, $app ) = ConfigServer::RegexMain::processline( $line, '/var/log/secure', \%globlogs );

    is( $reason, 'Failed SSH login from', 'detected failed SSH login' );
    is( $ip_acc, '10.0.0.1|admin',        'extracted IP and account' );
    is( $app,    'sshd',                  'identified sshd app' );
};

subtest 'processline - SSH authentication failure' => sub {
    setup_test_environment();

    my %globlogs = ( SSHD_LOG => { '/var/log/secure' => 1 } );

    my $line = 'Jan 20 10:15:30 server sshd[1234]: pam_unix(sshd:auth): authentication failure; logname= uid=0 euid=0 tty=ssh ruser= rhost=192.168.1.100  user=root';
    my ( $reason, $ip_acc, $app ) = ConfigServer::RegexMain::processline( $line, '/var/log/secure', \%globlogs );

    is( $reason, 'Failed SSH login from', 'detected authentication failure' );
    is( $ip_acc, '192.168.1.100|root',    'extracted IP and user' );
    is( $app,    'sshd',                  'identified sshd app' );
};

subtest 'processline - POP3 failed login' => sub {
    setup_test_environment();

    my %globlogs = ( POP3D_LOG => { '/var/log/maillog' => 1 } );

    my $line = 'Jan 20 10:15:30 server dovecot: pop3-login: Disconnected (auth failed, 1 attempts): user=<testuser>, method=PLAIN, rip=10.0.0.2, lip=192.168.1.1';
    my ( $reason, $ip_acc, $app ) = ConfigServer::RegexMain::processline( $line, '/var/log/maillog', \%globlogs );

    is( $reason, 'Failed POP3 login from', 'detected failed POP3 login' );
    is( $ip_acc, '10.0.0.2|testuser',      'extracted IP and account' );
    is( $app,    'pop3d',                  'identified pop3d app' );
};

subtest 'processline - IMAP failed login' => sub {
    setup_test_environment();

    my %globlogs = ( IMAPD_LOG => { '/var/log/maillog' => 1 } );

    my $line = 'Jan 20 10:15:30 server dovecot: imap-login: Disconnected (auth failed, 1 attempts): user=<baduser>, method=PLAIN, rip=172.16.0.1, lip=192.168.1.1';
    my ( $reason, $ip_acc, $app ) = ConfigServer::RegexMain::processline( $line, '/var/log/maillog', \%globlogs );

    is( $reason, 'Failed IMAP login from', 'detected failed IMAP login' );
    is( $ip_acc, '172.16.0.1|baduser',     'extracted IP and account' );
    is( $app,    'imapd',                  'identified imapd app' );
};

subtest 'processline - strips IPv6 prefix' => sub {
    setup_test_environment();

    my %globlogs = ( SSHD_LOG => { '/var/log/secure' => 1 } );

    my $line = 'Jan 20 10:15:30 server sshd[1234]: Failed password for root from ::ffff:10.0.0.1 port 54321';
    my ( $reason, $ip_acc, $app ) = ConfigServer::RegexMain::processline( $line, '/var/log/secure', \%globlogs );

    like( $ip_acc, qr/^10\.0\.0\.1/, 'IPv6 prefix stripped from IP' );
};

subtest 'processline - no match returns empty list' => sub {
    setup_test_environment();

    my %globlogs = ( SSHD_LOG => { '/var/log/secure' => 1 } );

    my $line   = 'Jan 20 10:15:30 server some_other_service: doing something';
    my @result = ConfigServer::RegexMain::processline( $line, '/var/log/secure', \%globlogs );

    # processline returns undef when no match, which becomes single undef element in list context
    ok( !defined $result[0] || $result[0] eq '', 'no match returns undef or empty' );
};

# Test processloginline function
subtest 'processloginline - courier POP3 successful login' => sub {
    setup_test_environment();

    my $line = 'Jan 20 10:15:30 server pop3d: LOGIN, user=testuser, ip=[10.0.0.2], port=12345';
    my ( $app, $acc, $ip ) = ConfigServer::RegexMain::processloginline($line);

    is( $app, 'pop3d',    'identified pop3d app' );
    is( $acc, 'testuser', 'extracted account' );
    is( $ip,  '10.0.0.2', 'extracted IP' );
};

subtest 'processloginline - dovecot POP3 login' => sub {
    setup_test_environment();

    my $line = 'Jan 20 10:15:30 server dovecot: pop3-login: Login: user=<testuser>, method=PLAIN, rip=10.0.0.5, lip=192.168.1.1';
    my ( $app, $acc, $ip ) = ConfigServer::RegexMain::processloginline($line);

    is( $app, 'pop3d',    'identified pop3d app' );
    is( $acc, 'testuser', 'extracted account' );
    is( $ip,  '10.0.0.5', 'extracted IP' );
};

subtest 'processloginline - dovecot IMAP login' => sub {
    setup_test_environment();

    my $line = 'Jan 20 10:15:30 server dovecot[5678]: imap-login: Login: user=<admin>, method=PLAIN, rip=172.16.0.10, lip=172.16.0.1';
    my ( $app, $acc, $ip ) = ConfigServer::RegexMain::processloginline($line);

    is( $app, 'imapd',       'identified imapd app' );
    is( $acc, 'admin',       'extracted account' );
    is( $ip,  '172.16.0.10', 'extracted IP' );
};

# Test processsshline function
subtest 'processsshline - successful SSH login' => sub {
    setup_test_environment();

    my $line = 'Jan 20 10:15:30 server sshd[1234]: Accepted password for root from 10.0.0.1 port 54321';
    my ( $acc, $ip, $method ) = ConfigServer::RegexMain::processsshline($line);

    is( $acc,    'root',     'extracted account' );
    is( $ip,     '10.0.0.1', 'extracted IP' );
    is( $method, 'password', 'extracted method' );
};

subtest 'processsshline - publickey authentication' => sub {
    setup_test_environment();

    my $line = 'Jan 20 10:15:30 server sshd[1234]: Accepted publickey for admin from 192.168.1.100 port 22';
    my ( $acc, $ip, $method ) = ConfigServer::RegexMain::processsshline($line);

    is( $acc,    'admin',         'extracted account' );
    is( $ip,     '192.168.1.100', 'extracted IP' );
    is( $method, 'publickey',     'extracted method' );
};

# Test processsuline function
subtest 'processsuline - successful su' => sub {
    setup_test_environment();

    my $line = 'Jan 20 10:15:30 server su[1234]: pam_unix(su:session): session opened for user root by admin';
    my ( $to, $from, $status ) = ConfigServer::RegexMain::processsuline($line);

    is( $to,     'root',             'to user' );
    is( $from,   'admin',            'from user' );
    is( $status, 'Successful login', 'successful status' );
};

subtest 'processsuline - failed su' => sub {
    setup_test_environment();

    my $line = 'Jan 20 10:15:30 server su[1234]: pam_unix(su:auth): authentication failure; logname=user uid=1000 euid=0 tty=pts/0 ruser=user rhost=  user=root';
    my ( $to, $from, $status ) = ConfigServer::RegexMain::processsuline($line);

    is( $to,     'root',         'to user' );
    is( $from,   'user',         'from user' );
    is( $status, 'Failed login', 'failed status' );
};

# Test processsudoline function
subtest 'processsudoline - successful sudo' => sub {
    setup_test_environment();

    my $line = 'Jan 20 10:15:30 server sudo: admin : TTY=pts/0 ; PWD=/home/admin ; USER=root ; COMMAND=/bin/ls';
    my ( $to, $from, $status ) = ConfigServer::RegexMain::processsudoline($line);

    is( $to,     'root',             'to user' );
    is( $from,   'admin',            'from user' );
    is( $status, 'Successful login', 'successful status' );
};

subtest 'processsudoline - failed sudo (not in sudoers)' => sub {
    setup_test_environment();

    my $line = 'Jan 20 10:15:30 server sudo: baduser : user NOT in sudoers ; TTY=pts/0 ; PWD=/home/baduser ; USER=root ; COMMAND=/bin/ls';
    my ( $to, $from, $status ) = ConfigServer::RegexMain::processsudoline($line);

    is( $to,     'root',         'to user' );
    is( $from,   'baduser',      'from user' );
    is( $status, 'Failed login', 'failed status' );
};

# Test processconsoleline function
subtest 'processconsoleline - root console login' => sub {
    setup_test_environment();

    my $line   = 'Jan 20 10:15:30 server login[1234]: ROOT LOGIN';
    my $status = ConfigServer::RegexMain::processconsoleline($line);

    is( $status, 1, 'detected root console login' );
};

# Test processcpanelline function
subtest 'processcpanelline - cPanel login' => sub {
    setup_test_environment();

    my $line = '10.0.0.1 - user [20/Jan/2026:10:15:30 +0000] "POST /login HTTP/1.1" 200 1234';
    my ( $ip, $acc ) = ConfigServer::RegexMain::processcpanelline($line);

    is( $ip,  '10.0.0.1', 'extracted IP' );
    is( $acc, 'user',     'extracted account' );
};

# Test scriptlinecheck function
subtest 'scriptlinecheck - detects script in home directory' => sub {
    setup_test_environment();

    # Format: date time [optional pid] cwd=PATH digits args:
    # Note: [1234] with space after it is the optional pid group
    my $line = 'Jan 20 [1234] cwd=/home/user/public_html 123 args: /usr/bin/php script.php';
    my $path = ConfigServer::RegexMain::scriptlinecheck($line);

    is( $path, '/home/user/public_html', 'detected script path in home' );
};

subtest 'scriptlinecheck - detects script with PWD format' => sub {
    setup_test_environment();

    # Format: date time [optional pid] something H=localhost ...PWD=PATH  REMOTE_ADDR=IP
    # Note the double space before REMOTE_ADDR in the regex
    my $line = 'Jan 20 exim H=localhost user=test PWD=/home/testuser/scripts  REMOTE_ADDR=127.0.0.1';
    my $path = ConfigServer::RegexMain::scriptlinecheck($line);

    is( $path, '/home/testuser/scripts', 'detected script path with PWD format' );
};

# Test relaycheck function
subtest 'relaycheck - authenticated relay' => sub {
    setup_test_environment();

    # Format: date time [pid] msgid <= sender H=host[IP] ... A=auth_type:user P=esmtpa
    # Date/time must be non-space: 2025-01-15 14:48:07, not "Jan 20"
    my $line = '2025-01-15 14:48:07 [1234] 1ABC-2DEF-GH <= sender@domain.com H=mail.example.com [10.0.0.1] A=plain:user@domain.com P=esmtpa S=1234';
    my ( $ip, $check ) = ConfigServer::RegexMain::relaycheck($line);

    is( $ip,    '10.0.0.1',  'extracted IP' );
    is( $check, 'AUTHRELAY', 'identified authenticated relay' );
};

subtest 'relaycheck - local relay' => sub {
    setup_test_environment();

    # Format: date time [pid] msgid <= sender U=username P=local
    # Date/time must be non-space: 2025-01-15 14:48:07, not "Jan 20"
    my $line = '2025-01-15 14:48:07 [1234] 1ABC-2DEF-GH <= sender@domain.com U=mailuser P=local S=1234';
    my ( $user, $check ) = ConfigServer::RegexMain::relaycheck($line);

    is( $user,  'mailuser',   'extracted username' );
    is( $check, 'LOCALRELAY', 'identified local relay' );
};

# Test pslinecheck function
subtest 'pslinecheck - TCP port scan' => sub {
    setup_test_environment();

    my $line = 'Jan 20 10:15:30 server kernel: Firewall: IN=eth0 OUT= MAC=... SRC=10.0.0.1 DST=192.168.1.10 PROTO=TCP DPT=8080';
    my ( $ip, $port ) = ConfigServer::RegexMain::pslinecheck($line);

    is( $ip,   '10.0.0.1', 'extracted source IP' );
    is( $port, '8080',     'extracted destination port' );
};

subtest 'pslinecheck - ICMP scan' => sub {
    setup_test_environment();

    my $line = 'Jan 20 10:15:30 server kernel: Firewall: IN=eth0 OUT= SRC=10.0.0.1 DST=192.168.1.10 PROTO=ICMP';
    my ( $ip, $port ) = ConfigServer::RegexMain::pslinecheck($line);

    is( $ip,   '10.0.0.1', 'extracted source IP' );
    is( $port, 'ICMP',     'identified ICMP protocol' );
};

# Test uidlinecheck function
subtest 'uidlinecheck - outbound connection by UID' => sub {
    setup_test_environment();

    my $line = 'Jan 20 10:15:30 server kernel: Firewall: OUT=eth0 IN= SRC=192.168.1.10 DST=10.0.0.1 PROTO=TCP DPT=80 UID=1000';
    my ( $port, $uid ) = ConfigServer::RegexMain::uidlinecheck($line);

    is( $port, '80',   'extracted destination port' );
    is( $uid,  '1000', 'extracted UID' );
};

# Test portknockingcheck function
subtest 'portknockingcheck - port knock detected' => sub {
    setup_test_environment();

    my $line = 'Jan 20 10:15:30 server kernel: Knock: *1234_IN* SRC=10.0.0.1 DST=192.168.1.10 DPT=1234';
    my ( $ip, $port ) = ConfigServer::RegexMain::portknockingcheck($line);

    is( $ip,   '10.0.0.1', 'extracted source IP' );
    is( $port, '1234',     'extracted knock port' );
};

# Test processdistftpline function
subtest 'processdistftpline - pure-ftpd login' => sub {
    setup_test_environment();

    my $line = 'Jan 20 10:15:30 server pure-ftpd[1234]: (?@10.0.0.1) [INFO] ftpuser is now logged in';
    my ( $ip, $acc ) = ConfigServer::RegexMain::processdistftpline($line);

    is( $ip,  '10.0.0.1', 'extracted IP' );
    is( $acc, 'ftpuser',  'extracted account' );
};

subtest 'processdistftpline - proftpd login' => sub {
    setup_test_environment();

    my $line = 'Jan 20 10:15:30 server proftpd[1234]: server.example.com (example.com[10.0.0.2]) - USER ftpuser2: Login successful.';
    my ( $ip, $acc ) = ConfigServer::RegexMain::processdistftpline($line);

    is( $ip,  '10.0.0.2', 'extracted IP' );
    is( $acc, 'ftpuser2', 'extracted account' );
};

# Test processdistsmtpline function
subtest 'processdistsmtpline - Exim SMTP auth' => sub {
    setup_test_environment();

    # Format: date time [pid] msgid <= sender H=host[IP] ... A=auth_type:account P=esmtpa
    # Date/time must be non-space: 2025-01-15 14:48:07, not "Jan 20"
    my $line = '2025-01-15 14:48:07 [1234] 1ABC-2DEF-GH <= sender@domain.com H=mail.example.com [10.0.0.1] A=plain:user@domain.com P=esmtpa S=1234';
    my ( $ip, $acc ) = ConfigServer::RegexMain::processdistsmtpline($line);

    is( $ip,  '10.0.0.1',        'extracted IP' );
    is( $acc, 'user@domain.com', 'extracted account' );
};

# Test loginline404 function
subtest 'loginline404 - Apache 404 error' => sub {
    setup_test_environment();

    my $line = '[Mon Jan 20 10:15:30 2026] [error] [client 10.0.0.1:54321] File does not exist: /var/www/html/missing.html';
    my $ip   = ConfigServer::RegexMain::loginline404($line);

    is( $ip, '10.0.0.1', 'extracted IP from 404 error' );
};

# Test loginline403 function
subtest 'loginline403 - Apache 403 error' => sub {
    setup_test_environment();

    my $line = '[Mon Jan 20 10:15:30 2026] [error] [client 10.0.0.2:54321] client denied by server configuration: /var/www/html/forbidden.html';
    my $ip   = ConfigServer::RegexMain::loginline403($line);

    is( $ip, '10.0.0.2', 'extracted IP from 403 error' );
};

# Test loginline401 function
subtest 'loginline401 - Apache 401 error' => sub {
    setup_test_environment();

    my $line = '[Mon Jan 20 10:15:30 2026] [error] [client 10.0.0.3:54321] AH01618: user admin not found: /admin';
    my $ip   = ConfigServer::RegexMain::loginline401($line);

    is( $ip, '10.0.0.3', 'extracted IP from 401 error' );
};

# Test statscheck function
subtest 'statscheck - firewall stats line' => sub {
    setup_test_environment();

    my $line     = 'Jan 20 10:15:30 server kernel: Firewall: *TCP_IN Blocked* IN=eth0 OUT=';
    my $is_stats = ConfigServer::RegexMain::statscheck($line);

    is( $is_stats, 1, 'identified firewall stats line' );
};

subtest 'statscheck - knock stats line' => sub {
    setup_test_environment();

    my $line     = 'Jan 20 10:15:30 server kernel: Knock: *1234_IN* SRC=10.0.0.1';
    my $is_stats = ConfigServer::RegexMain::statscheck($line);

    is( $is_stats, 1, 'identified knock stats line' );
};

# Test syslogcheckline function
subtest 'syslogcheckline - matching check code' => sub {
    setup_test_environment();

    my $line    = 'Jan 20 10:15:30 server lfd[1234]: SYSLOG check [ABC123]';
    my $matched = ConfigServer::RegexMain::syslogcheckline( $line, 'ABC123' );

    is( $matched, 1, 'matching check code detected' );
};

subtest 'syslogcheckline - non-matching check code' => sub {
    setup_test_environment();

    my $line    = 'Jan 20 10:15:30 server lfd[1234]: SYSLOG check [ABC123]';
    my $matched = ConfigServer::RegexMain::syslogcheckline( $line, 'XYZ789' );

    ok( !$matched, 'non-matching check code rejected' );
};

done_testing();
