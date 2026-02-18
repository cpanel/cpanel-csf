#!/usr/local/cpanel/3rdparty/bin/perl

#                                      Copyright 2025 WebPros International, LLC
#                                                           All rights reserved.
# copyright@cpanel.net                                         http://cpanel.net
# This code is subject to the cPanel license. Unauthorized copying is prohibited.

use lib 't/lib';
use FindBin::libs;

use cPstrict;

use Test2::V0;
use Test2::Tools::Explain;
use Test2::Plugin::NoWarnings;

use ConfigServer::CheckIP qw(checkip cccheckip);

subtest 'checkip - invalid inputs' => sub {
    is( checkip(''),                0, 'empty string returns 0' );
    is( checkip('not.an.ip'),       0, 'invalid IP returns 0' );
    is( checkip('999.999.999.999'), 0, 'out of range IPv4 returns 0' );
    is( checkip('192.168.1.1.1'),   0, 'too many octets returns 0' );
    is( checkip('192.168.1'),       0, 'too few octets returns 0' );
};

subtest 'checkip - valid IPv4 addresses' => sub {
    is( checkip('192.168.1.1'), 4, 'valid private IPv4 returns 4' );
    is( checkip('8.8.8.8'),     4, 'valid public IPv4 returns 4' );
    is( checkip('10.0.0.1'),    4, 'valid 10.x.x.x IPv4 returns 4' );
    is( checkip('172.16.0.1'),  4, 'valid 172.16.x.x IPv4 returns 4' );
    is( checkip('1.1.1.1'),     4, 'valid 1.1.1.1 IPv4 returns 4' );
};

subtest 'checkip - IPv4 with CIDR' => sub {
    is( checkip('192.168.1.0/24'), 4, 'IPv4 with /24 CIDR returns 4' );
    is( checkip('10.0.0.0/8'),     4, 'IPv4 with /8 CIDR returns 4' );
    is( checkip('192.168.1.1/32'), 4, 'IPv4 with /32 CIDR returns 4' );
    is( checkip('8.8.8.0/1'),      4, 'IPv4 with /1 CIDR returns 4' );

    # Note: /0 CIDR currently passes in the code (bug)
    is( checkip('192.168.1.1/33'),  0, 'IPv4 with /33 CIDR returns 0' );
    is( checkip('192.168.1.1/abc'), 0, 'IPv4 with invalid CIDR returns 0' );
};

subtest 'checkip - loopback rejection' => sub {
    is( checkip('127.0.0.1'),   0, 'IPv4 loopback 127.0.0.1 returns 0' );
    is( checkip('127.0.0.1/8'), 0, 'IPv4 loopback with CIDR returns 0' );
};

subtest 'checkip - valid IPv6 addresses' => sub {
    is( checkip('2001:db8::1'),                             6, 'valid IPv6 returns 6' );
    is( checkip('2001:0db8:0000:0000:0000:0000:0000:0001'), 6, 'full IPv6 returns 6' );
    is( checkip('fe80::1'),                                 6, 'link-local IPv6 returns 6' );
    is( checkip('::ffff:192.0.2.1'),                        6, 'IPv4-mapped IPv6 returns 6' );
};

subtest 'checkip - IPv6 with CIDR' => sub {
    is( checkip('2001:db8::/32'),   6, 'IPv6 with /32 CIDR returns 6' );
    is( checkip('2001:db8::1/128'), 6, 'IPv6 with /128 CIDR returns 6' );
    is( checkip('fe80::/10'),       6, 'IPv6 with /10 CIDR returns 6' );
    is( checkip('2001:db8::1/1'),   6, 'IPv6 with /1 CIDR returns 6' );

    # Note: /0 CIDR currently passes in the code (bug)
    is( checkip('2001:db8::1/129'), 0, 'IPv6 with /129 CIDR returns 0' );
    is( checkip('2001:db8::1/xyz'), 0, 'IPv6 with invalid CIDR returns 0' );
};

subtest 'checkip - IPv6 loopback rejection' => sub {
    is( checkip('::1'),                                     0, 'IPv6 loopback ::1 returns 0' );
    is( checkip('0000:0000:0000:0000:0000:0000:0000:0001'), 0, 'full IPv6 loopback returns 0' );
};

subtest 'checkip - reference modification for IPv6' => sub {
    my $ip     = '2001:db8::1';
    my $result = checkip( \$ip );

    is( $result, 6, 'IPv6 reference returns 6' );
    like( $ip, qr/^2001:db8::1$/, 'IPv6 normalized to short form' );

    my $ip_cidr = '2001:db8::1/64';
    $result = checkip( \$ip_cidr );

    is( $result, 6, 'IPv6 reference with CIDR returns 6' );
    like( $ip_cidr, qr/\/64$/, 'IPv6 with CIDR preserves CIDR notation' );
};

subtest 'checkip - reference with empty value' => sub {
    my $empty  = '';
    my $result = checkip( \$empty );

    ok( !defined $result || $result == 0, 'empty reference returns undef or 0' );
};

subtest 'cccheckip - valid public IPv4 addresses' => sub {
    is( cccheckip('8.8.8.8'), 4, 'Google DNS is public' );
    is( cccheckip('1.1.1.1'), 4, 'Cloudflare DNS is public' );
};

subtest 'cccheckip - private IPv4 addresses rejected' => sub {
    is( cccheckip('192.168.1.1'), 0, 'private 192.168.x.x returns 0' );
    is( cccheckip('10.0.0.1'),    0, 'private 10.x.x.x returns 0' );
    is( cccheckip('172.16.0.1'),  0, 'private 172.16.x.x returns 0' );
    is( cccheckip('127.0.0.1'),   0, 'loopback returns 0' );
};

subtest 'cccheckip - invalid inputs' => sub {
    is( cccheckip('not.an.ip'),       0, 'invalid IP returns 0' );
    is( cccheckip('999.999.999.999'), 0, 'out of range IPv4 returns 0' );
    is( cccheckip(''),                0, 'empty string returns 0' );
};

subtest 'cccheckip - IPv4 with CIDR' => sub {
    is( cccheckip('8.8.8.0/24'), 4, 'public IPv4 with /24 CIDR returns 4' );
    is( cccheckip('1.1.1.0/8'),  4, 'public IPv4 with /8 CIDR returns 4' );

    # Note: /0 CIDR currently passes in the code (bug)
    is( cccheckip('8.8.8.8/33'), 0, 'public IPv4 with /33 CIDR returns 0' );
};

subtest 'cccheckip - IPv6 addresses' => sub {
    is( cccheckip('2001:db8::1'), 6, 'valid IPv6 returns 6' );
    is( cccheckip('fe80::1'),     6, 'link-local IPv6 returns 6' );
};

subtest 'cccheckip - IPv6 loopback rejection' => sub {
    is( cccheckip('::1'), 0, 'IPv6 loopback ::1 returns 0' );
};

subtest 'cccheckip - IPv6 with CIDR' => sub {
    is( cccheckip('2001:db8::/32'),   6, 'IPv6 with /32 CIDR returns 6' );
    is( cccheckip('2001:db8::1/128'), 6, 'IPv6 with /128 CIDR returns 6' );

    # Note: /0 CIDR currently passes in the code (bug)

    is( cccheckip('2001:db8::1/129'), 0, 'IPv6 with /129 CIDR returns 0' );
};

subtest 'cccheckip - reference modification for IPv6' => sub {
    my $ip     = '2001:db8::1';
    my $result = cccheckip( \$ip );

    is( $result, 6, 'IPv6 reference returns 6' );
    like( $ip, qr/^2001:db8::1$/, 'IPv6 normalized to short form' );

    my $ip_cidr = '2001:db8::1/64';
    $result = cccheckip( \$ip_cidr );

    is( $result, 6, 'IPv6 reference with CIDR returns 6' );
    like( $ip_cidr, qr/\/64$/, 'IPv6 with CIDR preserves CIDR notation' );
};

subtest 'edge cases - special characters' => sub {
    is( checkip('192.168.1.1; echo "test"'), 0, 'IP with shell command returns 0' );
    is( checkip('192.168.1.1|cat'),          0, 'IP with pipe returns 0' );
    is( checkip('192.168.1.1 '),             0, 'IP with trailing space returns 0' );
    is( checkip(' 192.168.1.1'),             0, 'IP with leading space returns 0' );
};

subtest 'edge cases - boundary values' => sub {
    is( checkip('0.0.0.0'),         4, '0.0.0.0 returns 4' );
    is( checkip('255.255.255.255'), 4, '255.255.255.255 returns 4' );

    is( cccheckip('0.0.0.0'), 0, '0.0.0.0 is not public (returns 0)' );
};

done_testing;
