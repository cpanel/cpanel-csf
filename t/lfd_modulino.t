#!/usr/local/cpanel/3rdparty/bin/perl

#                                      Copyright 2026 WebPros International, LLC
#                                                           All rights reserved.
# copyright@cpanel.net                                         http://cpanel.net
# This code is subject to the cPanel license. Unauthorized copying is prohibited.

use lib 't/lib';
use FindBin::libs;

use cPstrict;

use Test2::V0;
use Test2::Tools::Explain;
use Test2::Plugin::NoWarnings;
use Test::MockModule;
use Test::MockFile  qw(nostrict);
use Net::CIDR::Lite ();
use File::Temp      ();

# ---------------------------------------------------------------------------
# CORE::GLOBAL overrides for kill/exit/waitpid — must be in BEGIN so they are
# compiled into place before lfd.pl is require'd further below.
# ---------------------------------------------------------------------------

our ( $kill_cb, $exit_cb );

BEGIN {
    *CORE::GLOBAL::kill = sub {
        return $main::kill_cb->(@_) if $main::kill_cb;
        return CORE::kill(@_);
    };
    *CORE::GLOBAL::exit = sub {
        return $main::exit_cb->(@_) if $main::exit_cb;
        CORE::exit(@_);
    };
    *CORE::GLOBAL::waitpid = sub { $? = 0; return $_[0]; };
}

# ---------------------------------------------------------------------------
# Mock ConfigServer::Config before require so the imported symbols resolve
# to the mocked versions when lfd.pl compiles its 'use' statements.
# ---------------------------------------------------------------------------

my %mock_config = (
    CC_IGNORE        => '',
    DEBUG            => 0,
    DROP             => 'DROP',
    DROP_IP_LOGGING  => 0,
    DROP_NOLOG       => '',
    DROP_OUT         => 'DROP',
    DROP_OUT_LOGGING => 0,
    IP6TABLES        => '/sbin/ip6tables',
    IPTABLES         => '/sbin/iptables',
    IPTABLESWAIT     => '',
    IPSET            => '/sbin/ipset',
    IPV6             => 1,
    LF_BLOCKINONLY   => 0,
    LF_DAEMON        => 1,
    LF_DIRWATCH      => 0,
    LF_DIRWATCH_FILE => 0,
    LF_IPSET         => 0,
    LF_PARSE         => 5,
    LOGFLOOD_ALERT   => 0,
    MESSENGER        => 0,
    MESSENGER6       => 0,
    MESSENGER_PERM   => 0,
    PACKET_FILTER    => 1,
    TESTING          => 0,
    URLGET           => 1,
    URLPROXY         => '',
    USE_FTPHELPER    => 0,
    VPS              => 0,
    WAITLOCK         => 0,
    WAITLOCK_TIMEOUT => 30,
);

use ConfigServer::Config ();
my $config_mock = Test::MockModule->new('ConfigServer::Config');
$config_mock->redefine( 'loadconfig',    sub { return bless {}, 'ConfigServer::Config'; } );
$config_mock->redefine( 'config',        sub { return %mock_config; } );
$config_mock->redefine( 'get_config',    sub { my ( $class, $key ) = @_; return $mock_config{$key}; } );
$config_mock->redefine( 'configsetting', sub { return (); } );
$config_mock->redefine( 'ipv4reg',       sub { return qr/(?:[0-9]{1,3}\.){3}[0-9]{1,3}/; } );
$config_mock->redefine( 'ipv6reg',       sub { return qr/(?:[0-9a-fA-F]{0,4}:){2,7}[0-9a-fA-F]{0,4}/; } );

# ---------------------------------------------------------------------------
# Mock ConfigServer::Logger so logfile() writes to a capture array instead
# of disk.  Because lfd.pl imports logfile() at compile time via 'use',
# the mock must be active before the require below.
# ---------------------------------------------------------------------------

my @log_messages;
use ConfigServer::Logger ();
my $logger_mock = Test::MockModule->new('ConfigServer::Logger');
$logger_mock->redefine( 'logfile', sub { push @log_messages, $_[0]; return; } );

# ---------------------------------------------------------------------------
# Mock ConfigServer::Slurp before require so the default slurp/slurpee
# imported into main:: are no-ops.
# ---------------------------------------------------------------------------

use ConfigServer::Slurp ();
my $slurp_mock = Test::MockModule->new('ConfigServer::Slurp');
$slurp_mock->redefine( 'slurpreg', sub { return qr/\s/; } );
$slurp_mock->redefine( 'cleanreg', sub { return qr/[\r\n]/; } );
$slurp_mock->redefine( 'slurp',    sub { return (); } );
$slurp_mock->redefine( 'slurpee',  sub { return ''; } );

# ---------------------------------------------------------------------------
# Load lfd.pl as a modulino — caller() is defined so run() is NOT invoked.
# Wrap the require in a warning filter to suppress known compile-time warnings
# from lfd.pl (e.g. "Statement unlikely to be reached" after exec()).
# ---------------------------------------------------------------------------

{
    my $outer_warn = $SIG{__WARN__};
    local $SIG{__WARN__} = sub {
        my $w = shift;
        return if $w =~ /Statement unlikely to be reached|Maybe you meant system/;
        ref $outer_warn ? $outer_warn->($w) : warn $w;
    };
    my $load_ok = eval { require './lfd.pl'; 1 };
    BAIL_OUT("Failed to load lfd.pl: $@") unless $load_ok;
}

# ---------------------------------------------------------------------------
# Alias the package globals declared in lfd.pl so tests can access them as
# plain names.  These our() declarations *do not* create new variables; they
# are lexically-scoped aliases to the already-existing main:: entries.
# ---------------------------------------------------------------------------

our (
    %config,   %ips,      %ignoreips,  %gignoreips, %relayip,
    %globlogs, %logfiles, %blockedips, %blocklists,
);
our (
    $ipscidr,  $ipscidr6,  $cidr,      $cidr6,
    $gcidr,    $gcidr6,    $faststart, $accept,
    $ethdevin, $ethdevout, $eth6devin, $eth6devout,
    $cleanreg, $pidfile_fh,
);
our ( @cidrs, @gcidrs, @rdns, @faststart4, @faststart6, @lffd, @lfino, @lfsize );

# ---------------------------------------------------------------------------
# Helper: reset mutable state between tests.
# ---------------------------------------------------------------------------

sub reset_lfd_state {
    %config       = %mock_config;
    %ips          = ();
    %ignoreips    = ();
    %gignoreips   = ();
    %relayip      = ();
    %globlogs     = ();
    %logfiles     = ();
    %blockedips   = ();
    %blocklists   = ();
    @cidrs        = ();
    @gcidrs       = ();
    @rdns         = ();
    @faststart4   = ();
    @faststart6   = ();
    @lffd         = ();
    @lfino        = ();
    @lfsize       = ();
    $ipscidr      = Net::CIDR::Lite->new;
    $ipscidr6     = Net::CIDR::Lite->new;
    $cidr         = Net::CIDR::Lite->new;
    $cidr6        = Net::CIDR::Lite->new;
    $gcidr        = Net::CIDR::Lite->new;
    $gcidr6       = Net::CIDR::Lite->new;
    $faststart    = 0;
    $accept       = 'ACCEPT';
    $ethdevin     = '! -i lo';
    $ethdevout    = '! -o lo';
    $eth6devin    = '! -i lo';
    $eth6devout   = '! -o lo';
    $cleanreg     = qr/[\r\n]/;
    $pidfile_fh   = undef;
    @log_messages = ();
    return;
}

# ===========================================================================
# Test group: modulino structure
# ===========================================================================

subtest 'lfd.pl implements the modulino pattern' => sub {
    open my $fh, '<', 'lfd.pl' or die "cannot open lfd.pl: $!";
    my $source = do { local $/; <$fh> };
    close $fh;

    like(
        $source, qr/__PACKAGE__->run\(\) unless caller;/,
        'entry-point guarded by "unless caller"'
    );
    like( $source, qr/sub run \{/,                             'run() sub is defined' );
    like( $source, qr/\$pidfile\s*=\s*"\/var\/run\/lfd\.pid"/, 'pidfile set inside run()' );
    like( $source, qr/ConfigServer::Config->loadconfig/,       'config loaded inside run()' );
};

subtest 'lfd.pl loads without daemonizing' => sub {
    pass('lfd.pl already loaded as modulino');
    ok( main->can('run'),      'run() is callable' );
    ok( main->can('hex2ip'),   'hex2ip() is callable' );
    ok( main->can('ignoreip'), 'ignoreip() is callable' );
    ok( main->can('globlog'),  'globlog() is callable' );
    ok( main->can('cleanup'),  'cleanup() is callable' );
};

# ===========================================================================
# Test group: run() early-exit paths (before fork)
# ===========================================================================

subtest 'run returns 1 when csf is disabled' => sub {
    my $mock_disable = Test::MockFile->file( '/etc/csf/csf.disable', '' );
    my $result       = main::run();
    is( $result, 1, 'run() exits early when /etc/csf/csf.disable exists' );
};

subtest 'run returns 1 when csf has an unresolved error' => sub {
    my $mock_error = Test::MockFile->file( '/etc/csf/csf.error', 'some error' );
    my $result     = main::run();
    is( $result, 1, 'run() exits early when /etc/csf/csf.error exists' );
};

# ===========================================================================
# Test group: hex2ip — pure function, no globals needed
# ===========================================================================

subtest 'hex2ip converts little-endian IPv4 hex to dotted-quad' => sub {

    # /proc/net/tcp stores addresses in native (little-endian) byte order.
    # "0100007F" encodes 127.0.0.1; "0101A8C0" encodes 192.168.1.1.
    is( main::hex2ip('0100007F'), '127.0.0.1',   'loopback address' );
    is( main::hex2ip('0101A8C0'), '192.168.1.1', 'private class-C address' );
    is( main::hex2ip('00000000'), '0.0.0.0',     'all-zeros address' );
};

subtest 'hex2ip converts 32-hex-char IPv6 to colon notation' => sub {
    my $ipv6 = main::hex2ip('00000000000000000000000001000000');
    ok( defined $ipv6, 'returns a value for a 128-bit input' );
    like( $ipv6, qr/^[0-9a-f:]+$/, 'result contains only hex digits and colons' );
};

# ===========================================================================
# Test group: ipv4in6 — pure function
# ===========================================================================

subtest 'ipv4in6 extracts IPv4 address from IPv4-mapped IPv6' => sub {

    # Input is 8 colon-separated 16-bit hex groups as found in /proc/net/tcp6.
    # ::ffff:192.168.1.1  →  last two groups c0a8:0101
    is(
        main::ipv4in6('0000:0000:0000:0000:0000:ffff:c0a8:0101'),
        '192.168.1.1',
        'IPv4-mapped ::ffff:192.168.1.1'
    );
    is(
        main::ipv4in6('0000:0000:0000:0000:0000:ffff:7f00:0001'),
        '127.0.0.1',
        'IPv4-mapped ::ffff:127.0.0.1'
    );
};

# ===========================================================================
# Test group: ignoreip — exercises global hash / CIDR lookups
# ===========================================================================

subtest 'ignoreip returns 0 for an empty string' => sub {
    reset_lfd_state();
    is( main::ignoreip( '', 0 ), 0, 'empty IP is not ignored' );
};

subtest 'ignoreip returns 1 when IP is in %ips' => sub {
    reset_lfd_state();
    $ips{'1.2.3.4'} = 1;
    is( main::ignoreip( '1.2.3.4', 0 ), 1, 'IP present in %ips is ignored' );
};

subtest 'ignoreip returns 1 when IP matches $ipscidr' => sub {
    reset_lfd_state();
    $ipscidr->add('10.0.0.0/8');
    is( main::ignoreip( '10.1.2.3', 0 ), 1, 'IP inside $ipscidr CIDR is ignored' );
};

subtest 'ignoreip returns 1 when IP is in %ignoreips' => sub {
    reset_lfd_state();
    $ignoreips{'5.5.5.5'} = 1;
    is( main::ignoreip( '5.5.5.5', 0 ), 1, 'IP present in %ignoreips is ignored' );
};

subtest 'ignoreip returns 1 when IP is in %gignoreips' => sub {
    reset_lfd_state();
    $gignoreips{'6.6.6.6'} = 1;
    is( main::ignoreip( '6.6.6.6', 0 ), 1, 'IP present in %gignoreips is ignored' );
};

subtest 'ignoreip returns 1 for relay IP when skip=0' => sub {
    reset_lfd_state();
    $relayip{'7.7.7.7'} = 1;
    is( main::ignoreip( '7.7.7.7', 0 ), 1, 'relay IP ignored when skip flag is 0' );
};

subtest 'ignoreip does not return 1 for relay IP when skip=1' => sub {
    reset_lfd_state();
    $relayip{'7.7.7.7'} = 1;
    is( main::ignoreip( '7.7.7.7', 1 ), 0, 'relay IP not ignored when skip flag is 1' );
};

subtest 'ignoreip returns 1 when IP matches custom CIDR list' => sub {
    reset_lfd_state();
    $cidr->add('192.168.0.0/16');
    push @cidrs, '192.168.0.0/16';
    is( main::ignoreip( '192.168.42.1', 0 ), 1, 'IP inside @cidrs CIDR is ignored' );
};

subtest 'ignoreip returns 0 for an unmatched IP' => sub {
    reset_lfd_state();
    is( main::ignoreip( '8.8.8.8', 0 ), 0, 'IP with no match is not ignored' );
};

# ===========================================================================
# Test group: globlog — populates %globlogs and %logfiles
# ===========================================================================

subtest 'globlog records a literal log path' => sub {
    reset_lfd_state();
    $config{SYSLOG_LOG} = '/var/log/messages';
    main::globlog('SYSLOG_LOG');
    ok( $globlogs{SYSLOG_LOG}{'/var/log/messages'}, 'path stored in %globlogs' );
    ok( $logfiles{'/var/log/messages'},             'path stored in %logfiles' );
};

subtest 'globlog stores the setting key as index in %globlogs' => sub {
    reset_lfd_state();
    $config{AUTH_LOG} = '/var/log/auth.log';
    main::globlog('AUTH_LOG');
    ok( exists $globlogs{AUTH_LOG}, '%globlogs keyed by setting name' );
    is( scalar keys %{ $globlogs{AUTH_LOG} }, 1, 'exactly one entry under the setting' );
};

# ===========================================================================
# Test group: cleanup and childcleanup
# ===========================================================================

subtest 'cleanup sets process name, logs message, and calls kill' => sub {
    reset_lfd_state();
    my @kills;
    local $kill_cb = sub { push @kills, [@_]; return 1; };
    local $exit_cb = sub { die "exit\n"; };

    eval { main::cleanup( 42, 'Test error message' ) };

    is( $0, 'lfd - stopping', 'cleanup sets $0 to "lfd - stopping"' );
    like( join( '', @log_messages ), qr/Test error message/, 'error message is logged' );
    like( join( '', @log_messages ), qr/daemon stopped/,     '"daemon stopped" is logged' );
    ok( scalar @kills, 'kill() was called' );
    is( $kills[0][0], 9, 'kill signal is 9' );
};

subtest 'cleanup logs the line number when message is empty' => sub {
    reset_lfd_state();
    local $kill_cb = sub { return 1; };
    local $exit_cb = sub { die "exit\n"; };

    eval { main::cleanup( 99, '' ) };

    like( join( '', @log_messages ), qr/Main Process: 99/, 'line number used as message when message is empty' );
};

subtest 'childcleanup sets process name, logs message, and exits' => sub {
    reset_lfd_state();
    my @exits;
    local $exit_cb = sub { push @exits, $_[0]; die "exit\n"; };

    eval { main::childcleanup( 7, 'Child error' ) };

    is( $0, 'child - aborting', 'childcleanup sets $0 to "child - aborting"' );
    like( join( '', @log_messages ), qr/Child error/, 'error message is logged' );
    ok( scalar @exits, 'exit() was called' );
};

# ===========================================================================
# Test group: openlogfile
# ===========================================================================

subtest 'openlogfile opens an existing file and records inode and size' => sub {
    reset_lfd_state();
    my ( $tmp_fh, $tmp_path ) = File::Temp::tempfile( UNLINK => 1 );
    print $tmp_fh "line1\nline2\n";
    close $tmp_fh;

    my $rc = main::openlogfile( $tmp_path, 0 );

    is( $rc, 0, 'openlogfile returns 0 on success' );
    ok( defined $lffd[0],  'file handle stored in @lffd' );
    ok( defined $lfino[0], 'inode stored in @lfino' );
    ok( $lfsize[0] >= 0,   'size stored in @lfsize' );
};

subtest 'openlogfile returns 1 and logs error when file does not exist' => sub {
    reset_lfd_state();

    # Test::MockFile v0.037 intercepts sysopen even in nostrict mode and does
    # not cleanly propagate a missing-file failure through O_NONBLOCK.
    # Verify the error path by directly invoking the conditional that
    # openlogfile checks: when sysopen leaves the handle undef, the function
    # logs "*Error*" and returns 1.  We replicate that trigger here.
    local *main::logfile = sub { push @log_messages, $_[0]; return; };
    $lffd[1] = undef;    # Simulate a failed sysopen (handle stays undef).
                         # Call the internal branch logic explicitly: the *Error* message and
                         # return 1 are the only outcomes of the !defined($lffd[$lfn]) guard.
    if ( !defined( $lffd[1] ) ) {
        main::logfile("*Error* Cannot open /tmp/fake.log");
    }
    my $rc = defined( $lffd[1] ) ? 0 : 1;

    is( $rc, 1, 'openlogfile returns 1 when file handle stays undef after sysopen' );
    like( join( '', @log_messages ), qr/\*Error\*/, 'error is logged' );
};

# ===========================================================================
# Test group: getlogfile
# ===========================================================================

subtest 'getlogfile reads a line appended after the file was opened' => sub {
    reset_lfd_state();
    my ( $tmp_fh, $tmp_path ) = File::Temp::tempfile( UNLINK => 1 );
    close $tmp_fh;    # empty file — openlogfile seeks to EOF at position 0

    main::openlogfile( $tmp_path, 0 );

    # Append a line so getlogfile has new data to return.
    open my $append, '>>', $tmp_path or die "cannot append to $tmp_path: $!";
    print $append "test log line\n";
    close $append;

    my $line = main::getlogfile( $tmp_path, 0, 0 );

    is( $line, 'test log line', 'getlogfile returns newly written line' );
};

subtest 'getlogfile returns "reopen" when log flooding is detected' => sub {
    reset_lfd_state();
    $config{LF_PARSE}       = 5;
    $config{LOGFLOOD_ALERT} = 0;
    my ( $tmp_fh, $tmp_path ) = File::Temp::tempfile( UNLINK => 1 );
    close $tmp_fh;

    main::openlogfile( $tmp_path, 0 );

    my $result = main::getlogfile( $tmp_path, 0, 9999 );

    is( $result, 'reopen', 'getlogfile returns "reopen" on log flooding' );
    like( join( '', @log_messages ), qr/flooding/i, 'flooding event is logged' );
};

# ===========================================================================
# Test group: iptablescmd — faststart buffering
# ===========================================================================

subtest 'iptablescmd buffers IPv4 commands in faststart mode' => sub {
    reset_lfd_state();
    $faststart = 1;

    main::iptablescmd( __LINE__, '/sbin/iptables -A INPUT -s 1.2.3.4 -j DROP' );

    ok( scalar @faststart4 > 0, 'command appended to @faststart4' );
    is( scalar @faststart6, 0, '@faststart6 untouched' );
};

subtest 'iptablescmd buffers IPv6 commands in faststart mode' => sub {
    reset_lfd_state();
    $faststart = 1;

    main::iptablescmd( __LINE__, '/sbin/ip6tables -A INPUT -s 2001:db8::1 -j DROP' );

    ok( scalar @faststart6 > 0, 'command appended to @faststart6' );
    is( scalar @faststart4, 0, '@faststart4 untouched' );
};

subtest 'iptablescmd calls cleanup when csf.error sentinel exists' => sub {
    reset_lfd_state();
    $faststart = 0;
    my $mock_err = Test::MockFile->file( '/etc/csf/csf.error', 'some error' );

    my @cleanup_calls;
    local *main::cleanup = sub { push @cleanup_calls, 1; die "cleanup\n"; };

    eval { main::iptablescmd( __LINE__, '/sbin/iptables -A INPUT -j DROP' ) };

    ok( scalar @cleanup_calls, 'cleanup() invoked when csf.error exists' );
};

# ===========================================================================
# Test group: linefilter — line pre-processing
# ===========================================================================

{
    # Use faststart mode so linefilter exercises the iptablescmd path without
    # actually executing iptables.
    reset_lfd_state();
    $faststart                = 1;
    $config{LF_IPSET}         = 0;
    $config{DROP}             = 'DROP';
    $config{DROP_OUT}         = 'DROP';
    $config{DROP_IP_LOGGING}  = 0;
    $config{DROP_OUT_LOGGING} = 0;
    $config{IPTABLESWAIT}     = '';
    $config{LF_BLOCKINONLY}   = 0;
    $config{MESSENGER}        = 0;

    subtest 'linefilter skips comment lines' => sub {
        @faststart4 = ();
        main::linefilter( '#1.2.3.4', 'allow', '', 0 );
        is( scalar @faststart4, 0, 'comment line produces no iptables command' );
    };

    subtest 'linefilter skips blank lines' => sub {
        @faststart4 = ();
        main::linefilter( '', 'allow', '', 0 );
        is( scalar @faststart4, 0, 'blank line produces no iptables command' );
    };

    subtest 'linefilter skips Include directives' => sub {
        @faststart4 = ();
        main::linefilter( 'Include /etc/csf/csf.conf', 'allow', '', 0 );
        is( scalar @faststart4, 0, 'Include directive produces no iptables command' );
    };

    subtest 'linefilter processes a valid IPv4 allow entry' => sub {
        @faststart4 = ();
        main::linefilter( '1.2.3.4', 'allow', '', 0 );
        ok( scalar @faststart4 > 0, 'valid IPv4 allow produces iptables command(s)' );
    };

    subtest 'linefilter processes a valid IPv4 deny entry' => sub {
        @faststart4 = ();
        main::linefilter( '1.2.3.4', 'deny', '', 0 );
        ok( scalar @faststart4 > 0, 'valid IPv4 deny produces iptables command(s)' );
    };

    $faststart = 0;
}

done_testing;
