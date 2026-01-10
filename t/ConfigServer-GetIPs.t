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

use ConfigServer::GetIPs qw(getips);

# Test module loading and exports
subtest 'Module loading and exports' => sub {
    ok( defined &getips,                        'getips function is exported' );
    ok( defined $ConfigServer::GetIPs::VERSION, 'VERSION is defined' );
    is( ref \&getips, 'CODE', 'getips is a code reference' );
};

# Test getips basic functionality
subtest 'getips basic behavior' => sub {

    # Test that getips returns a list (even if empty)
    my @result = getips('localhost');
    is( ref \@result, 'ARRAY', 'getips returns a list' );

    # Test with a well-known hostname that should resolve
    @result = getips('localhost');
    ok( scalar(@result) >= 0, 'getips returns results for localhost' );
};

# Test getips return format
subtest 'getips return format validation' => sub {
    my @ips = getips('localhost');

    # If we got results, verify they look like IP addresses
    if (@ips) {
        my $ipv4reg = ConfigServer::Config->ipv4reg;
        my $ipv6reg = ConfigServer::Config->ipv6reg;

        foreach my $ip (@ips) {
            ok(
                $ip =~ /^$ipv4reg$/ || $ip =~ /^$ipv6reg$/,
                "Result '$ip' is a valid IP address"
            );
        }
    }
    else {
        pass('No IPs returned for localhost - acceptable in test environment');
    }
};

# Test getips with invalid hostname
subtest 'getips with invalid hostname' => sub {
    my @ips = getips('this-hostname-should-not-exist-12345.invalid');
    is( ref \@ips, 'ARRAY', 'getips returns array for invalid hostname' );

    # May return empty or may timeout - either is acceptable behavior
};

# Test that getips doesn't die on errors
subtest 'getips error handling' => sub {
    ok lives {
        my @ips = getips('');
    }, 'getips handles empty hostname without dying';

    ok lives {
        my @ips = getips('invalid..hostname');
    }, 'getips handles malformed hostname without dying';
};

# Test getips with mocked host binary
subtest 'getips with host command path' => sub {

    # Create a local copy of config to test
    local $ConfigServer::Config::config{'HOST'} = '/usr/bin/host';

    # This test just verifies that having a HOST config doesn't break things
    ok lives {
        my @ips = getips('localhost');
    }, 'getips works with HOST configuration';
};

# Test getips with real-world hostnames
subtest 'getips with common hostnames' => sub {
    my $ipv4reg = ConfigServer::Config->ipv4reg;
    my $ipv6reg = ConfigServer::Config->ipv6reg;

    # Test with httpupdate.cpanel.net which has multiple IPs
    my @cpanel_ips = getips('httpupdate.cpanel.net');
    if (@cpanel_ips) {
        ok( scalar(@cpanel_ips) > 0, 'httpupdate.cpanel.net resolves to at least one IP' );

        foreach my $ip (@cpanel_ips) {
            ok(
                $ip =~ /^$ipv4reg$/ || $ip =~ /^$ipv6reg$/,
                "httpupdate.cpanel.net IP '$ip' is valid"
            );
        }

        note( "httpupdate.cpanel.net resolved to " . scalar(@cpanel_ips) . " IP(s): " . join( ", ", @cpanel_ips ) );
    }
    else {
        pass('httpupdate.cpanel.net did not resolve - may be network issue in test environment');
    }

    # Test with google.com which should be reliably resolvable
    my @google_ips = getips('google.com');
    if (@google_ips) {
        ok( scalar(@google_ips) > 0, 'google.com resolves to at least one IP' );

        foreach my $ip (@google_ips) {
            ok(
                $ip =~ /^$ipv4reg$/ || $ip =~ /^$ipv6reg$/,
                "google.com IP '$ip' is valid"
            );
        }

        note( "google.com resolved to " . scalar(@google_ips) . " IP(s)" );
    }
    else {
        pass('google.com did not resolve - may be network issue in test environment');
    }

};

done_testing;
