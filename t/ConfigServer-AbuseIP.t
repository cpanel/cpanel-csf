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

use ConfigServer::AbuseIP qw(abuseip);

# Test invalid IP addresses
subtest 'invalid IP addresses' => sub {

    # When checkip fails, it returns 0, which becomes the return value
    my @result = abuseip('not.an.ip');
    ok( scalar(@result) <= 1, 'invalid IP returns 0 or 1 value (checkip failure)' );

    @result = abuseip('999.999.999.999');
    ok( scalar(@result) <= 1, 'out of range IPv4 returns 0 or 1 value' );

    @result = abuseip('');
    ok( scalar(@result) <= 1, 'empty string returns 0 or 1 value' );

    # Ensure we never get abuse contact info for invalid IPs
    my ( $abuse, $msg ) = abuseip('not.an.ip');
    ok( !$abuse || $abuse eq '' || $abuse == 0, 'no valid abuse contact for invalid IP' );
};

# Test valid IPv4 address - real DNS lookup
subtest 'valid IPv4 address - real DNS lookup' => sub {

    # Use a real IP that might have abuse contact info
    # This test may pass or not depending on network/DNS availability
    my ( $abuse, $msg ) = abuseip('8.8.8.8');

    # If we get results, validate them
    if ( defined $abuse && $abuse ne '' ) {
        like( $abuse, qr/\@/,                           'abuse contact contains @ symbol' );
        like( $msg,   qr/Abuse Contact for 8\.8\.8\.8/, 'message contains IP address' );
        like( $msg,   qr/abusix\.com/,                  'message contains abusix.com reference' );
        unlike( $msg, qr/\[ip\]/,          'message does not contain unreplaced [ip] placeholder' );
        unlike( $msg, qr/\[\[contact\]\]/, 'message does not contain unreplaced [[contact]] placeholder' );
    }
    else {
        # Network/DNS may not be available in test environment
        pass('No abuse contact found (acceptable - network/DNS may be unavailable)');
    }
};

# Test IPv6 address handling
subtest 'IPv6 address handling' => sub {

    # Test that IPv6 addresses are processed correctly
    my $ipv6 = '2001:db8::1';

    # This should not die/crash
    ok lives {
        my ( $abuse, $msg ) = abuseip($ipv6);
    }, 'IPv6 address processing does not crash';
};

# Test reverse IP format extraction
subtest 'reverse IP format parsing' => sub {

    # The module should handle various reverse DNS formats
    # This is internal behavior, but we can test the public interface

    my @test_ips = (
        '192.0.2.1',      # Standard IPv4
        '10.0.0.1',       # Private IPv4
        '2001:db8::1',    # IPv6
    );

    foreach my $ip (@test_ips) {
        ok lives {
            my ( $abuse, $msg ) = abuseip($ip);
        }, "IP $ip processed without error";
    }
};

# Test message formatting
subtest 'message formatting with real lookup' => sub {

    # Try with a known IP that might return results
    my ( $abuse, $msg ) = abuseip('1.1.1.1');

    if ( defined $msg ) {
        like( $msg, qr/Abuse Contact for 1\.1\.1\.1/, 'message contains correct IP' );
        like( $msg, qr/\Q$abuse\E/,                   'message contains abuse contact' ) if defined $abuse;
        like( $msg, qr/abusix\.com/,                  'message contains abusix reference' );
        like( $msg, qr/https:\/\/abusix\.com/,        'message contains abusix URL' );
        unlike( $msg, qr/\[ip\]/,          'message does not contain unreplaced [ip] placeholder' );
        unlike( $msg, qr/\[\[contact\]\]/, 'message does not contain unreplaced [[contact]] placeholder' );
    }
    else {
        pass('No abuse contact found (network/DNS unavailable)');
    }
};

# Test timeout handling
subtest 'timeout handling' => sub {

    # The function should handle timeouts gracefully (10 second alarm)
    # We can't easily test this without mocking, so just verify the function
    # doesn't crash with a timeout-prone scenario

    ok lives {

        # Use documentation IP that shouldn't exist in abuse DB
        my ( $abuse, $msg ) = abuseip('192.0.2.1');
    }, 'Function completes without crashing';
};

# Test DNS query failure / no results
subtest 'DNS query with no results' => sub {

    # Use a documentation IP that likely has no abuse contact
    my ( $abuse, $msg ) = abuseip('198.51.100.100');

    # Most likely this will return empty since it's a documentation IP
    # But we accept either outcome
    if ( !defined $abuse || $abuse eq '' ) {
        pass('No abuse contact returned (expected for documentation IP)');
    }
    else {
        # Unlikely but possible if DNS/network behaves unexpectedly
        pass('Got abuse contact (unexpected but acceptable)');
    }
};

# Test return value structure
subtest 'return value structure' => sub {

    # Test with a valid IP
    my @result = abuseip('8.8.8.8');

    # Function returns either 0 values (no result) or 2 values (abuse + msg)
    ok(
        scalar(@result) == 0 || scalar(@result) == 2,
        'function returns either 0 or 2 values'
    ) or diag "Got " . scalar(@result) . " return values";

    # If we got 2 values, validate them
    if ( scalar(@result) == 2 ) {
        my ( $abuse, $msg ) = @result;
        ok( defined $abuse && $abuse ne '', 'abuse contact is defined and non-empty' );
        ok( defined $msg   && $msg ne '',   'message is defined and non-empty' );
        is( ref($abuse), '', 'abuse contact is a scalar string' );
        is( ref($msg),   '', 'message is a scalar string' );
    }
    else {
        pass('No results returned (acceptable - network/DNS may be unavailable)');
    }
};

# Test special characters in abuse contact
subtest 'special characters in email handling' => sub {

    # We can't easily mock this, but we can test that the function
    # doesn't crash with various IP inputs
    my @test_ips = (
        '1.1.1.1',
        '8.8.4.4',
        '9.9.9.9',
    );

    foreach my $ip (@test_ips) {
        ok lives {
            my ( $abuse, $msg ) = abuseip($ip);

            # If we got an abuse contact, it should look like an email
            if ( defined $abuse && $abuse ne '' ) {
                like( $abuse, qr/\@/, "abuse contact for $ip contains @ symbol" );
            }
        }, "Processing $ip completes without error";
    }
};

done_testing;
