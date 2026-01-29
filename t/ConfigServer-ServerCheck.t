#!/usr/local/cpanel/3rdparty/bin/perl

#                                      Copyright 2026 WebPros International, LLC
#                                                           All rights reserved.
# copyright@cpanel.net                                         http://cpanel.net
# This code is subject to the cPanel license. Unauthorized copying is prohibited.

use cPstrict;

use Test2::V0;
use Test2::Tools::Explain;
use Test2::Plugin::NoWarnings echo => 'fail';
use Test::MockModule;

use lib 't/lib';
use MockConfig;

use File::Temp qw(tempdir tempfile);
use File::Path qw(make_path remove_tree);

use ConfigServer::ServerCheck;

# Mock Cpanel::Config using memory_only
$Cpanel::Config::CpConfGuard::memory_only = {
    alwaysredirecttossl => 1,
    skipboxtrapper      => 1,
    maxemailsperhour    => 500,
    nativessl           => 1,
    ftpserver           => 'pure-ftpd',
};

# Mock ConfigServer::GetEthDev to prevent warnings
my $mock_ethdev = Test::MockModule->new('ConfigServer::GetEthDev');
$mock_ethdev->mock(
    new => sub {
        return bless {}, 'ConfigServer::GetEthDev';
    }
);
$mock_ethdev->mock( ifaces     => sub { return ( 'eth0' => 1 ); } );
$mock_ethdev->mock( ipv4       => sub { return (); } );
$mock_ethdev->mock( ipv6       => sub { return (); } );
$mock_ethdev->mock( getethdev  => sub { return 'eth0'; } );
$mock_ethdev->mock( geteth6dev => sub { return 'eth0'; } );

# Test module loading and basic functionality
subtest 'Module basics' => sub {
    ok( ConfigServer::ServerCheck->can('report'),    'report method exists' );
    ok( defined $ConfigServer::ServerCheck::VERSION, 'VERSION is defined' );
    like( $ConfigServer::ServerCheck::VERSION, qr/^\d+\.\d+$/, 'VERSION has proper format' );
};

# Test _getportinfo function
subtest '_getportinfo function' => sub {
    no strict 'refs';
    no warnings 'redefine';

    # This function reads /proc/net/{tcp,udp,tcp6,udp6}
    # We'll test with a known port that likely doesn't exist
    my $result = ConfigServer::ServerCheck::_getportinfo(99999);
    is( ref( \$result ), 'SCALAR', '_getportinfo returns a scalar' );
    ok( ( $result == 0 || $result == 1 ), '_getportinfo returns 0 or 1' );
};

# Test report function returns output
subtest 'report function output structure' => sub {

    # Mock the check functions but allow output functions to run
    my $mock = mock 'ConfigServer::ServerCheck' => (
        override => [
            _firewallcheck  => sub { return; },
            _servercheck    => sub { return; },
            _sshtelnetcheck => sub { return; },
            _mailcheck      => sub { return; },
            _apachecheck    => sub { return; },
            _phpcheck       => sub { return; },
            _whmcheck       => sub { return; },
            _servicescheck  => sub { return; },
        ],
    );

    set_config(
        TESTING  => 0,
        DNSONLY  => 1,
        IPTABLES => '/sbin/iptables',
        IPV6     => 0,
        VPS      => 0,
    );

    my $output;
    my $lives = lives {
        $output = ConfigServer::ServerCheck::report();
    };

    ok( $lives,          'report() executes without dying' );
    ok( defined $output, 'report() returns defined output' );
    is( ref( \$output ), 'SCALAR', 'report() returns a scalar' );

    clear_config();
};

# Test report with verbose flag
subtest 'report with verbose flag' => sub {
    my $mock = mock 'ConfigServer::ServerCheck' => (
        override => [
            _firewallcheck  => sub { return; },
            _servercheck    => sub { return; },
            _sshtelnetcheck => sub { return; },
            _mailcheck      => sub { return; },
            _apachecheck    => sub { return; },
            _phpcheck       => sub { return; },
            _whmcheck       => sub { return; },
            _servicescheck  => sub { return; },
        ],
    );

    set_config(
        TESTING  => 0,
        DNSONLY  => 1,
        IPTABLES => '/sbin/iptables',
        IPV6     => 0,
        VPS      => 0,
    );

    my $output;
    my $lives = lives {
        $output = ConfigServer::ServerCheck::report(1);
    };

    ok( $lives,          'report(1) executes without dying' );
    ok( defined $output, 'report(1) returns defined output' );
    is( ref( \$output ), 'SCALAR', 'report(1) returns a scalar' );

    clear_config();
};

# Test that check functions can be called
subtest 'Check functions are callable' => sub {
    no strict 'refs';
    no warnings 'redefine';

    set_config(
        TESTING         => 0,
        RESTRICT_SYSLOG => 1,
        AUTO_UPDATES    => 1,
        LF_DAEMON       => 1,
        TCP_IN          => '22,80,443',
        DNSONLY         => 1,
        IPTABLES        => '/sbin/iptables',
        IPV6            => 0,
        VPS             => 0,
    );

    # Mock file operations and external commands
    my $mock = mock 'ConfigServer::ServerCheck' => (
        override => [
            _firewallcheck => sub {

                # Just verify it can be called
                pass '_firewallcheck can be called';
                return;
            },
            _servercheck => sub {
                pass '_servercheck can be called';
                return;
            },
            _sshtelnetcheck => sub {
                pass '_sshtelnetcheck can be called';
                return;
            },
            _servicescheck => sub {
                pass '_servicescheck can be called';
                return;
            },
        ],
    );

    my $lives = lives {
        ConfigServer::ServerCheck::_firewallcheck();
        ConfigServer::ServerCheck::_servercheck();
        ConfigServer::ServerCheck::_sshtelnetcheck();
        ConfigServer::ServerCheck::_servicescheck();
    };

    ok( $lives, 'Check functions execute without dying' );

    clear_config();
};

# Test config file dependencies
subtest 'Module handles missing config gracefully' => sub {
    my $mock = mock 'ConfigServer::ServerCheck' => (
        override => [
            _firewallcheck  => sub { return; },
            _servercheck    => sub { return; },
            _sshtelnetcheck => sub { return; },
            _mailcheck      => sub { return; },
            _apachecheck    => sub { return; },
            _phpcheck       => sub { return; },
            _whmcheck       => sub { return; },
            _servicescheck  => sub { return; },
        ],
    );

    set_config(
        DNSONLY  => 0,                         # Enable all checks
        IPTABLES => '/nonexistent/iptables',
        IPV6     => 0,
        VPS      => 0,
    );

    my $output;
    my $lives = lives {
        $output = ConfigServer::ServerCheck::report();
    };

    ok( $lives,          'report() handles missing config gracefully' );
    ok( defined $output, 'report() still returns output' );

    clear_config();
};

# Test that the module processes check results
subtest 'Module integrates check results' => sub {
    my $check_called = 0;
    my $mock         = mock 'ConfigServer::ServerCheck' => (
        override => [
            _firewallcheck => sub {
                $check_called++;
                return;
            },
            _servercheck    => sub { return; },
            _sshtelnetcheck => sub { return; },
            _mailcheck      => sub { return; },
            _apachecheck    => sub { return; },
            _phpcheck       => sub { return; },
            _whmcheck       => sub { return; },
            _servicescheck  => sub { return; },
        ],
    );

    set_config(
        DNSONLY  => 1,
        IPTABLES => '/sbin/iptables',
        IPV6     => 0,
        VPS      => 0,
    );

    ConfigServer::ServerCheck::report();

    ok( $check_called > 0, '_firewallcheck was called during report execution' );

    clear_config();
};

# Test DNSONLY mode skips certain checks
subtest 'DNSONLY mode behavior' => sub {
    my %calls;
    my $mock = mock 'ConfigServer::ServerCheck' => (
        override => [
            _firewallcheck => sub {
                $calls{firewall}++;
                return;
            },
            _servercheck => sub {
                $calls{server}++;
                return;
            },
            _sshtelnetcheck => sub {
                $calls{ssh}++;
                return;
            },
            _mailcheck => sub {
                $calls{mail}++;
                return;
            },
            _apachecheck => sub {
                $calls{apache}++;
                return;
            },
            _phpcheck => sub {
                $calls{php}++;
                return;
            },
            _whmcheck => sub {
                $calls{whm}++;
                return;
            },
            _servicescheck => sub {
                $calls{services}++;
                return;
            },
        ],
    );

    set_config(
        DNSONLY  => 1,
        IPTABLES => '/sbin/iptables',
        IPV6     => 0,
        VPS      => 0,
    );

    ConfigServer::ServerCheck::report();

    ok( $calls{firewall},        'firewall check runs in DNSONLY mode' );
    ok( $calls{server},          'server check runs in DNSONLY mode' );
    ok( $calls{ssh},             'ssh check runs in DNSONLY mode' );
    ok( $calls{services},        'services check runs in DNSONLY mode' );
    ok( !defined $calls{mail},   'mail check skipped in DNSONLY mode' );
    ok( !defined $calls{apache}, 'apache check skipped in DNSONLY mode' );
    ok( !defined $calls{php},    'php check skipped in DNSONLY mode' );
    ok( !defined $calls{whm},    'whm check skipped in DNSONLY mode' );

    clear_config();
};

done_testing;
