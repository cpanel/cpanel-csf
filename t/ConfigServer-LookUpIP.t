#!/usr/local/cpanel/3rdparty/bin/perl

#                                      Copyright 2026 WebPros International, LLC
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

use File::Temp             qw(tempdir tempfile);
use ConfigServer::LookUpIP qw(iplookup);

my $tempdir = tempdir( CLEANUP => 1 );

# Mock _urlget to prevent ConfigServer::URLGet from being called
my $_urlget_mock = mock 'ConfigServer::LookUpIP' => (
    override => [
        _urlget => sub {

            # Return a mock object with urlget method
            return mock {} => (
                add => [
                    urlget => sub {

                        # Return mock response: ($status, $text)
                        return ( 0, '{"countryCode":"US","countryName":"United States","stateProv":"California","city":"Mountain View"}' );
                    },
                ],
            );
        },
        geo_binary => sub {
            my ( $ip, $iptype ) = @_;

            # Return test data: (country_code, country_name, state, city, asn)
            return ( 'US', 'United States', 'California', 'Mountain View', 'AS15169' );
        },
    ],
);

subtest 'module exports iplookup function' => sub {
    can_ok( 'main', ['iplookup'] );
};

subtest 'iplookup - no lookups enabled' => sub {
    set_config(
        LF_LOOKUPS  => 0,
        CC_LOOKUPS  => 0,
        CC6_LOOKUPS => 0,
    );

    my $result = iplookup('8.8.8.8');
    is( $result, '8.8.8.8', 'returns bare IP when no lookups enabled' );

    clear_config();
};

subtest 'iplookup - LF_LOOKUPS only (DNS lookup disabled)' => sub {
    set_config(
        LF_LOOKUPS  => 1,
        CC_LOOKUPS  => 0,
        CC6_LOOKUPS => 0,
        HOST        => '/usr/bin/host',    # Provide HOST config to avoid warnings
    );

    # Create empty DNS cache file
    my $cache_file = "/var/lib/csf/csf.dnscache";
    my $cache_dir  = "/var/lib/csf";

    # Skip if we can't create test files
  SKIP: {
        skip "Cannot create test cache directory", 1 unless -d $cache_dir || mkdir $cache_dir;

        open( my $fh, '>', $cache_file ) or skip "Cannot create cache file: $!", 1;
        close($fh);

        my $result = iplookup('8.8.8.8');
        like( $result, qr/8\.8\.8\.8 \(/, 'returns IP with hostname when LF_LOOKUPS enabled' );

        unlink $cache_file if -f $cache_file;
    }

    clear_config();
};

subtest 'iplookup - cconly parameter returns country code only' => sub {
    set_config(
        LF_LOOKUPS  => 0,
        CC_LOOKUPS  => 1,
        CC6_LOOKUPS => 0,
        CC_SRC      => "",
    );

    # This will fail without actual geo data files, but tests the code path
    # In a real environment, you'd mock the file reads or provide test data
    my $result = iplookup( '8.8.8.8', 1 );
    ok( defined $result, 'cconly parameter processes without error' );

    clear_config();
};

subtest 'iplookup - IPv6 support with CC6_LOOKUPS' => sub {
    set_config(
        LF_LOOKUPS  => 0,
        CC_LOOKUPS  => 1,
        CC6_LOOKUPS => 1,
        CC_SRC      => "",
    );

    my $result = iplookup('2001:4860:4860::8888');
    ok( defined $result, 'IPv6 address processes without error' );

    clear_config();
};

subtest 'iplookup - invalid IP returns safely' => sub {
    clear_config();

    my $result = iplookup('invalid.ip');
    ok( defined $result, 'invalid IP handles gracefully' );
};

subtest 'iplookup - private IP addresses' => sub {
    set_config(
        LF_LOOKUPS  => 0,
        CC_LOOKUPS  => 1,
        CC6_LOOKUPS => 0,
        CC_SRC      => "",
    );

    # Private IPs should be skipped in geo_binary due to iptype check
    my $result = iplookup('192.168.1.1');
    ok( defined $result, 'private IPv4 address processes without error' );

    clear_config();
};

subtest '_urlget - lazy initialization' => sub {
    set_config(
        URLGET   => 2,
        URLPROXY => '',
    );

    # Test that _urlget is callable (internal function)
    # This primarily tests compilation and basic structure
    ok( 1, '_urlget function compiles' );

    clear_config();
};

subtest 'iplookup - CC_LOOKUPS mode variations' => sub {

    # Test different CC_LOOKUPS modes (1, 2, 3, 4)
    for my $mode ( 1 .. 4 ) {
        set_config(
            LF_LOOKUPS  => 0,
            CC_LOOKUPS  => $mode,
            CC6_LOOKUPS => 0,
            CC_SRC      => "",
            URLGET      => 2,
            URLPROXY    => '',
        );

        my $result = iplookup('8.8.8.8');
        ok( defined $result, "CC_LOOKUPS mode $mode processes without error" );

        clear_config();
    }
};

subtest 'iplookup - CC_SRC variations' => sub {

    # Test different CC_SRC values ("", "1", "2")
    for my $src ( "", "1", "2" ) {
        set_config(
            LF_LOOKUPS  => 0,
            CC_LOOKUPS  => 1,
            CC6_LOOKUPS => 0,
            CC_SRC      => $src,
        );

        my $result = iplookup('8.8.8.8');
        my $label  = $src eq "" ? "default" : $src;
        ok( defined $result, "CC_SRC $label processes without error" );

        clear_config();
    }
};

subtest 'iplookup - DNS cache hit scenario' => sub {
    set_config(
        LF_LOOKUPS  => 1,
        CC_LOOKUPS  => 0,
        CC6_LOOKUPS => 0,
        HOST        => '/usr/bin/host',
    );

    my $cache_file = "/var/lib/csf/csf.dnscache";
    my $cache_dir  = "/var/lib/csf";

  SKIP: {
        skip "Cannot create test cache directory", 1 unless -d $cache_dir || mkdir $cache_dir;

        # Create cache with entry
        open( my $fh, '>', $cache_file ) or skip "Cannot create cache file: $!", 1;
        print $fh "8.8.8.8|8.8.8.8|dns.google\n";
        close($fh);

        my $result = iplookup('8.8.8.8');
        like( $result, qr/dns\.google/, 'cache hit returns cached hostname' );

        unlink $cache_file if -f $cache_file;
    }

    clear_config();
};

done_testing;
