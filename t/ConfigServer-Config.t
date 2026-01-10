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

use ConfigServer::Config;

# Test module loading and basic functionality
subtest 'Module basics' => sub {
    ok( ConfigServer::Config->can('loadconfig'), 'loadconfig method exists' );
    ok( ConfigServer::Config->can('ipv4reg'),    'ipv4reg method exists' );
    ok( ConfigServer::Config->can('ipv6reg'),    'ipv6reg method exists' );
};

# Test package exports
subtest 'Package variables' => sub {
    ok( defined $ConfigServer::Config::VERSION, 'VERSION is defined' );
    is( ref ConfigServer::Config->ipv4reg(), 'Regexp', 'ipv4reg is a regexp' );
    is( ref ConfigServer::Config->ipv6reg(), 'Regexp', 'ipv6reg is a regexp' );
};

# Test ipv4reg patterns
subtest 'IPv4 regex validation' => sub {
    my $ipv4_regex = ConfigServer::Config->ipv4reg();

    # Valid IPv4 addresses
    like( '192.168.1.1',     qr/^$ipv4_regex$/, 'Valid IPv4: 192.168.1.1' );
    like( '10.0.0.1',        qr/^$ipv4_regex$/, 'Valid IPv4: 10.0.0.1' );
    like( '255.255.255.255', qr/^$ipv4_regex$/, 'Valid IPv4: 255.255.255.255' );
    like( '0.0.0.0',         qr/^$ipv4_regex$/, 'Valid IPv4: 0.0.0.0' );
    like( '127.0.0.1',       qr/^$ipv4_regex$/, 'Valid IPv4: 127.0.0.1' );

    # Invalid IPv4 addresses
    unlike( '256.1.1.1',      qr/^$ipv4_regex$/, 'Invalid IPv4: 256.1.1.1' );
    unlike( '192.168.1',      qr/^$ipv4_regex$/, 'Invalid IPv4: 192.168.1' );
    unlike( '192.168.1.1.1',  qr/^$ipv4_regex$/, 'Invalid IPv4: 192.168.1.1.1' );
    unlike( 'not.an.ip.addr', qr/^$ipv4_regex$/, 'Invalid IPv4: not.an.ip.addr' );
};

# Test ipv6reg patterns
subtest 'IPv6 regex validation' => sub {
    my $ipv6_regex = ConfigServer::Config->ipv6reg();

    # Valid IPv6 addresses
    like( '2001:0db8:85a3:0000:0000:8a2e:0370:7334', qr/^$ipv6_regex$/, 'Valid IPv6: full format' );
    like( '2001:db8:85a3::8a2e:370:7334',            qr/^$ipv6_regex$/, 'Valid IPv6: compressed' );
    like( '::1',                                     qr/^$ipv6_regex$/, 'Valid IPv6: loopback' );
    like( '::',                                      qr/^$ipv6_regex$/, 'Valid IPv6: all zeros' );
    like( 'fe80::1',                                 qr/^$ipv6_regex$/, 'Valid IPv6: link-local' );
    like( '2001:db8::1',                             qr/^$ipv6_regex$/, 'Valid IPv6: documentation' );

    # IPv4-mapped IPv6
    like( '::ffff:192.0.2.1', qr/^$ipv6_regex$/, 'Valid IPv6: IPv4-mapped' );
};

# Test resetconfig
subtest 'resetconfig functionality' => sub {
    ConfigServer::Config::_resetconfig();

    my %config = ConfigServer::Config::config();
    is( scalar keys %config, 0, 'config is empty after resetconfig' );

    my %configsetting = ConfigServer::Config::configsetting();
    is( scalar keys %configsetting, 0, 'configsetting is empty after resetconfig' );
};

# Test systemcmd
subtest 'systemcmd basic execution' => sub {
    my @result = ConfigServer::Config::_systemcmd( 'echo', 'test' );
    is( \@result, ['test'], 'systemcmd executes echo command' );

    @result = ConfigServer::Config::_systemcmd('true');
    is( ref \@result, 'ARRAY', 'systemcmd returns array for true command' );

    # Test that systemcmd handles multiline output
    @result = ConfigServer::Config::_systemcmd( 'printf', "line1\\nline2\\nline3" );
    is( scalar @result, 3,       'systemcmd captures multiple lines' );
    is( $result[0],     'line1', 'first line captured correctly' );
    is( $result[1],     'line2', 'second line captured correctly' );
    is( $result[2],     'line3', 'third line captured correctly' );
};

# Test config methods return types
subtest 'config return types' => sub {
    my %config = ConfigServer::Config::config();
    is( ref \%config, 'HASH', 'config() returns hash' );

    my %configsetting = ConfigServer::Config::configsetting();
    is( ref \%configsetting, 'HASH', 'configsetting() returns hash' );

    my $ipv4 = ConfigServer::Config->ipv4reg();
    is( ref $ipv4, 'Regexp', 'ipv4reg() returns Regexp object' );

    my $ipv6 = ConfigServer::Config->ipv6reg();
    is( ref $ipv6, 'Regexp', 'ipv6reg() returns Regexp object' );
};

# Test edge cases for IPv4 regex
subtest 'IPv4 regex edge cases' => sub {
    my $ipv4_regex = ConfigServer::Config->ipv4reg();

    # Test boundary values
    like( '0.0.0.0',         qr/^$ipv4_regex$/, 'Minimum valid IPv4' );
    like( '255.255.255.255', qr/^$ipv4_regex$/, 'Maximum valid IPv4' );

    # Test each octet boundary
    like( '255.0.0.0', qr/^$ipv4_regex$/, 'First octet max' );
    like( '0.255.0.0', qr/^$ipv4_regex$/, 'Second octet max' );
    like( '0.0.255.0', qr/^$ipv4_regex$/, 'Third octet max' );
    like( '0.0.0.255', qr/^$ipv4_regex$/, 'Fourth octet max' );

    # Test invalid boundaries
    unlike( '256.0.0.0', qr/^$ipv4_regex$/, 'First octet over max' );
    unlike( '0.256.0.0', qr/^$ipv4_regex$/, 'Second octet over max' );
    unlike( '0.0.256.0', qr/^$ipv4_regex$/, 'Third octet over max' );
    unlike( '0.0.0.256', qr/^$ipv4_regex$/, 'Fourth octet over max' );

    # Common typos and mistakes
    unlike( '192.168.1',     qr/^$ipv4_regex$/, 'Too few octets' );
    unlike( '192.168.1.1.1', qr/^$ipv4_regex$/, 'Too many octets' );
    unlike( '192.168.-1.1',  qr/^$ipv4_regex$/, 'Negative octet' );
    unlike( '192.168.1.1a',  qr/^$ipv4_regex$/, 'Non-numeric character' );
    unlike( '192.168. 1.1',  qr/^$ipv4_regex$/, 'Space in address' );
    unlike( '192..168.1.1',  qr/^$ipv4_regex$/, 'Double dot' );
};

# Test edge cases for IPv6 regex
subtest 'IPv6 regex edge cases' => sub {
    my $ipv6_regex = ConfigServer::Config->ipv6reg();

    # Special addresses
    like( '::',  qr/^$ipv6_regex$/, 'All zeros compressed' );
    like( '::1', qr/^$ipv6_regex$/, 'Loopback' );
    like( '::0', qr/^$ipv6_regex$/, 'All zeros with one zero' );

    # Link-local addresses
    like( 'fe80::1',                   qr/^$ipv6_regex$/, 'Link-local short' );
    like( 'fe80::1234:5678:90ab:cdef', qr/^$ipv6_regex$/, 'Link-local long' );

    # Global unicast
    like( '2001:db8::1',                             qr/^$ipv6_regex$/, 'Documentation prefix' );
    like( '2001:0db8:0000:0000:0000:0000:0000:0001', qr/^$ipv6_regex$/, 'Full form' );

    # IPv4-mapped and IPv4-compatible
    like( '::ffff:192.0.2.1', qr/^$ipv6_regex$/, 'IPv4-mapped' );
    like( '::192.0.2.1',      qr/^$ipv6_regex$/, 'IPv4-compatible' );

    # Multicast
    like( 'ff02::1', qr/^$ipv6_regex$/, 'Multicast all nodes' );
    like( 'ff02::2', qr/^$ipv6_regex$/, 'Multicast all routers' );
};

# Test systemcmd error handling
subtest 'systemcmd handles errors gracefully' => sub {

    # Command that doesn't exist should return empty or handle gracefully
    ok lives {
        my @result = ConfigServer::Config::_systemcmd('this_command_does_not_exist_12345');
    }, 'systemcmd handles non-existent commands without dying';

    # Test with stderr output
    ok lives {
        my @result = ConfigServer::Config::_systemcmd( 'sh', '-c', 'echo error >&2' );
    }, 'systemcmd handles stderr without dying';
};

done_testing;
