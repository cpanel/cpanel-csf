#!/usr/local/cpanel/3rdparty/bin/perl

use cPstrict;

use Test2::V0;
use Test2::Tools::Explain;
use Test2::Plugin::NoWarnings;

use lib 't/lib';
use MockConfig;

use ConfigServer::Ports;

subtest 'Module loads correctly' => sub {
    ok( defined $ConfigServer::Ports::VERSION, 'VERSION is defined' );
    is( $ConfigServer::Ports::VERSION, 1.02, 'VERSION is 1.02' );

    can_ok( 'ConfigServer::Ports', 'listening' );
    can_ok( 'ConfigServer::Ports', 'openports' );
};

subtest '_hex2ip converts IPv4 correctly' => sub {

    # IPv4 addresses in /proc/net/tcp are stored as little-endian hex
    # 127.0.0.1 = 0100007F (reversed: 7F 00 00 01)
    is( ConfigServer::Ports::_hex2ip('0100007F'), '127.0.0.1', '127.0.0.1 (loopback)' );

    # 0.0.0.0 = 00000000
    is( ConfigServer::Ports::_hex2ip('00000000'), '0.0.0.0', '0.0.0.0 (any)' );

    # 192.168.1.1 = 0101A8C0 (little-endian)
    is( ConfigServer::Ports::_hex2ip('0101A8C0'), '192.168.1.1', '192.168.1.1' );

    # 10.0.0.1 = 0100000A
    is( ConfigServer::Ports::_hex2ip('0100000A'), '10.0.0.1', '10.0.0.1' );
};

subtest '_hex2ip converts IPv6 correctly' => sub {

    # IPv6 addresses are 32 hex chars (16 bytes = 4 x 32-bit words)
    # ::1 in /proc format is typically stored as 32 hex chars
    # All zeros = ::
    my $ipv6_zeros = '00000000000000000000000000000000';
    my $result     = ConfigServer::Ports::_hex2ip($ipv6_zeros);
    like( $result, qr/^[0:]+$/, 'IPv6 all zeros produces colon notation' );

    # Test that 32-char hex produces IPv6-style output
    my $ipv6_hex = '0000000000000000FFFF00000100007F';
    $result = ConfigServer::Ports::_hex2ip($ipv6_hex);
    ok( defined $result && $result ne '', 'IPv6 mapped address produces result' );
    like( $result, qr/:/, 'IPv6 result contains colons' );
};

subtest '_hex2ip handles malformed input' => sub {

    # Empty/undefined input
    is( ConfigServer::Ports::_hex2ip(undef), '', 'undef returns empty string' );
    is( ConfigServer::Ports::_hex2ip(''),    '', 'empty string returns empty string' );

    # Invalid characters
    is( ConfigServer::Ports::_hex2ip('ZZZZZZZZ'), '', 'non-hex chars return empty string' );
    is( ConfigServer::Ports::_hex2ip('ghijklmn'), '', 'letters g-n return empty string' );

    # Odd-length hex (would fail pack)
    is( ConfigServer::Ports::_hex2ip('0100007'), '', 'odd-length hex returns empty string' );

    # Wrong length for IPv4 or IPv6
    is( ConfigServer::Ports::_hex2ip('0100'),                 '', '4-char hex (not 8 or 32) returns empty string' );
    is( ConfigServer::Ports::_hex2ip('01000000000000000000'), '', '20-char hex returns empty string' );
};

subtest 'openports returns correct structure' => sub {
    set_config(
        TCP_IN  => '22,80,443',
        TCP6_IN => '22,443',
        UDP_IN  => '53',
        UDP6_IN => '',
    );

    my %ports = ConfigServer::Ports::openports();

    is( ref \%ports, 'HASH', 'openports returns a hash' );

    # Check TCP ports
    ok( exists $ports{tcp},      'tcp key exists' );
    ok( exists $ports{tcp}{22},  'port 22 in tcp' );
    ok( exists $ports{tcp}{80},  'port 80 in tcp' );
    ok( exists $ports{tcp}{443}, 'port 443 in tcp' );

    # Check TCP6 ports
    ok( exists $ports{tcp6},      'tcp6 key exists' );
    ok( exists $ports{tcp6}{22},  'port 22 in tcp6' );
    ok( exists $ports{tcp6}{443}, 'port 443 in tcp6' );

    # Check UDP ports
    ok( exists $ports{udp},     'udp key exists' );
    ok( exists $ports{udp}{53}, 'port 53 in udp' );

    clear_config();
};

subtest 'openports handles port ranges' => sub {
    set_config(
        TCP_IN  => '100:105',
        TCP6_IN => '',
        UDP_IN  => '200:203,53',
        UDP6_IN => '',
    );

    my %ports = ConfigServer::Ports::openports();

    # Range 100:105 should include 100,101,102,103,104 (not 105 - exclusive end)
    ok( exists $ports{tcp}{100},  'port 100 from range' );
    ok( exists $ports{tcp}{101},  'port 101 from range' );
    ok( exists $ports{tcp}{102},  'port 102 from range' );
    ok( exists $ports{tcp}{103},  'port 103 from range' );
    ok( exists $ports{tcp}{104},  'port 104 from range' );
    ok( !exists $ports{tcp}{105}, 'port 105 not included (exclusive end)' );

    # UDP range + single port
    ok( exists $ports{udp}{200}, 'port 200 from UDP range' );
    ok( exists $ports{udp}{201}, 'port 201 from UDP range' );
    ok( exists $ports{udp}{202}, 'port 202 from UDP range' );
    ok( exists $ports{udp}{53},  'single port 53 in UDP' );

    clear_config();
};

subtest 'openports handles empty config values' => sub {
    set_config(
        TCP_IN  => '',
        TCP6_IN => '',
        UDP_IN  => '',
        UDP6_IN => '',
    );

    my %ports = ConfigServer::Ports::openports();

    # Should not die, just return empty structure
    is( ref \%ports, 'HASH', 'returns hash with empty config' );

    clear_config();
};

subtest 'listening skips gracefully on non-Linux' => sub {

    # On non-Linux or when /proc is not available, listening() should not die
    # On Linux with /proc access, it returns listening port information

    my %listen;
    eval { %listen = ConfigServer::Ports::listening(); };

    ok( !$@, 'listening() does not die' ) or diag("Error: $@");
    is( ref \%listen, 'HASH', 'listening() returns a hash' );

    # Note: We cannot test actual content without root access to /proc
};

done_testing();
