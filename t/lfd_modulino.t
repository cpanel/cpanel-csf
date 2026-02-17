#!/usr/local/cpanel/3rdparty/bin/perl

#                                      Copyright 2026 WebPros International, LLC
#                                                           All rights reserved.
# copyright@cpanel.net                                         http://cpanel.net
# This code is subject to the cPanel license. Unauthorized copying is prohibited.

use cPstrict;

use FindBin::libs;
use Test2::V0;
use Test2::Plugin::NoWarnings;
use Test::MockModule;

# This test validates that lfd.pl can be loaded as a modulino and executed
# without actually running the daemon or modifying system state. It mocks all
# external dependencies to prevent system modification during testing.

# Set up mocks BEFORE loading modules that depend on them

# Mock ConfigServer::Config FIRST (many modules depend on it)
use ConfigServer::Config;
my $config_mock = Test::MockModule->new('ConfigServer::Config');
my %mock_config = (
    TESTING          => 0,                   # Must be 0 or lfd refuses to run
    LF_DAEMON        => 1,                   # Must be 1 or lfd refuses to run
    USE_FTPHELPER    => 0,
    IPTABLES         => '/sbin/iptables',
    IP6TABLES        => '/sbin/ip6tables',
    IPSET            => '/sbin/ipset',
    IPV6             => 1,
    LF_IPSET         => 0,
    PACKET_FILTER    => 1,
    DROP_NOLOG       => '',
    UI               => 0,                   # Disable UI to avoid loading extra modules
    LF_DIRWATCH      => 0,                   # Disable to avoid loading File::Find
    LF_DIRWATCH_FILE => 0,
    DEBUG            => 0,
    LF_PARSE         => 5,
    URLGET           => 1,
    URLPROXY         => '',
);

$config_mock->redefine( 'loadconfig',    sub { return bless {}, 'ConfigServer::Config'; } );
$config_mock->redefine( 'config',        sub { return %mock_config; } );
$config_mock->redefine( 'get_config',    sub { my ( $class, $key ) = @_; return $mock_config{$key}; } );
$config_mock->redefine( 'configsetting', sub { return (); } );
$config_mock->redefine( 'ipv4reg',       sub { return qr/(?:[0-9]{1,3}\.){3}[0-9]{1,3}/; } );
$config_mock->redefine( 'ipv6reg',       sub { return qr/(?:[0-9a-fA-F]{0,4}:){2,7}[0-9a-fA-F]{0,4}/; } );

# Mock ConfigServer::Slurp
use ConfigServer::Slurp;
my $slurp_mock = Test::MockModule->new('ConfigServer::Slurp');
$slurp_mock->redefine( 'slurpreg', sub { return qr/\s/; } );
$slurp_mock->redefine( 'cleanreg', sub { return qr/[\r\n]/; } );
$slurp_mock->redefine( 'slurp',    sub { return (); } );
$slurp_mock->redefine( 'slurpee',  sub { return ''; } );

# Mock IPC::Open3 to prevent actual command execution
# Load without importing to avoid redefinition warnings when lfd.pl imports it
use IPC::Open3 ();
our @executed_commands;
my $open3_mock = Test::MockModule->new('IPC::Open3');
$open3_mock->redefine(
    'open3',
    sub {
        my ( $wtr, $rdr, $err, @cmd ) = @_;
        push @executed_commands, join( ' ', @cmd );
        my $sample_output = "Sample output\n";
        open my $fake_out, '<', \$sample_output or die;
        open my $fake_err, '<', \''             or die;
        $_[1] = $fake_out if defined $_[1];
        $_[2] = $fake_err if defined $_[2];
        return 1234;
    }
);

# Mock waitpid
BEGIN {
    *CORE::GLOBAL::waitpid = sub {
        $? = 0;
        return $_[0];
    };
}

subtest 'modulino pattern implemented correctly' => sub {
    open my $fh, '<', 'lfd.pl' or die;
    my $source = do { local $/; <$fh> };
    close $fh;

    like(
        $source, qr/__PACKAGE__->run\(\) unless caller;/,
        'Has modulino pattern: __PACKAGE__->run() unless caller'
    );

    like(
        $source, qr/sub run \{/,
        'Has run() subroutine defined'
    );

    # Extract run() subroutine
    my ($run_sub) = $source =~ /(sub run \{.*?^}.*?# End of run)/ms;
    ok( $run_sub, 'Successfully extracted run() subroutine' );

    like(
        $run_sub, qr/\$pidfile = "\/var\/run\/lfd\.pid";/,
        'pidfile initialization moved inside run()'
    );

    like(
        $run_sub, qr/ConfigServer::Config->loadconfig/,
        'Config loading happens inside run() to prevent compile-time file access'
    );

    like(
        $run_sub, qr/require ConfigServer::AbuseIP;/,
        'AbuseIP loaded at runtime via require (not compile-time use)'
    );
};

subtest 'load modulino without explosion' => sub {
    @executed_commands = ();
    local @ARGV = ();

    # The test is just to load the module without explosion
    # We can't actually run it because it would daemonize/loop forever
    my $load_ok = eval {
        require './lfd.pl';
        1;
    };

    if ( !$load_ok ) {
        my $error = $@ || '';
        fail("Failed to load lfd.pl: $error");
        diag("Additional mocking needed - error above shows what's missing");
        return;
    }

    pass('lfd.pl loaded as modulino without explosion');
    pass('No compilation errors occurred with mocked dependencies');

    # Note: We don't call run() because lfd would enter its main loop
    # The goal is just to verify it can be loaded as a module
};

done_testing;
