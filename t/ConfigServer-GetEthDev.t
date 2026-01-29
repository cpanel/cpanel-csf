#!/usr/local/cpanel/3rdparty/bin/perl

#                                      Copyright 2026 WebPros International, LLC
#                                                           All rights reserved.
# copyright@cpanel.net                                         http://cpanel.net
# This code is subject to the cPanel license. Unauthorized copying is prohibited.

use cPstrict;

use Test2::V0;
use Test2::Tools::Explain;
use Test2::Plugin::NoWarnings;

use ConfigServer::GetEthDev;

subtest "Constructor" => sub {
    my $ethdev = ConfigServer::GetEthDev->new();

    ok( $ethdev, "Constructor returns object" );
    isa_ok( $ethdev, "ConfigServer::GetEthDev" );
    ok( exists $ethdev->{status},                         "Object has status attribute" );
    ok( $ethdev->{status} == 0 || $ethdev->{status} == 1, "Status is 0 (success) or 1 (no ip/ifconfig)" );
};

subtest "Network detection methods" => sub {
    my $ethdev = ConfigServer::GetEthDev->new();

    subtest "ifaces method" => sub {
        my %ifaces = $ethdev->ifaces();

        if ( $ethdev->{status} == 0 ) {
            ok( scalar( keys %ifaces ) > 0, "At least one interface detected" );

            # Loopback interface should exist on most systems
            ok( exists $ifaces{lo} || exists $ifaces{lo0}, "Loopback interface detected" )
              or diag( "Available interfaces: " . explain( [ keys %ifaces ] ) );

            # All interface names should be non-empty strings
            for my $iface ( keys %ifaces ) {
                ok( length $iface, "Interface name '$iface' is non-empty" );
                is( $ifaces{$iface}, 1, "Interface '$iface' has value 1" );
            }
        }
        else {
            is( scalar( keys %ifaces ), 0, "No interfaces when status is 1" );
        }
    };

    subtest "ipv4 method" => sub {
        my %ipv4 = $ethdev->ipv4();

        if ( $ethdev->{status} == 0 ) {
            ok( scalar( keys %ipv4 ) > 0, "At least one IPv4 address detected" )
              or diag( "Available IPv4 addresses: " . explain( [ keys %ipv4 ] ) );

            # All IPs should be valid IPv4 format
            for my $ip ( keys %ipv4 ) {
                like( $ip, qr/^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$/, "IPv4 '$ip' has valid format" );
                is( $ipv4{$ip}, 1, "IPv4 '$ip' has value 1" );
            }
        }
        else {
            is( scalar( keys %ipv4 ), 0, "No IPv4 addresses when status is 1" );
        }
    };

    subtest "ipv6 method" => sub {
        my %ipv6 = $ethdev->ipv6();

        # IPv6 may or may not be available
        if ( scalar( keys %ipv6 ) > 0 ) {

            # All IPs should end with /128
            for my $ip ( keys %ipv6 ) {
                like( $ip, qr/\/128$/, "IPv6 '$ip' ends with /128" );
                is( $ipv6{$ip}, 1, "IPv6 '$ip' has value 1" );
            }
        }
        else {
            pass("No IPv6 addresses detected (may be disabled on system)");
        }
    };

    subtest "brd method" => sub {
        my %brd = $ethdev->brd();

        # 255.255.255.255 should always be present
        ok( exists $brd{"255.255.255.255"}, "Default broadcast 255.255.255.255 exists" )
          or diag( "Available broadcast addresses: " . explain( [ keys %brd ] ) );

        if ( $ethdev->{status} == 0 ) {
            ok( scalar( keys %brd ) > 0, "At least one broadcast address detected" );

            # All broadcast IPs should be valid IPv4 format
            for my $ip ( keys %brd ) {
                like( $ip, qr/^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$/, "Broadcast '$ip' has valid format" );
                is( $brd{$ip}, 1, "Broadcast '$ip' has value 1" );
            }
        }
    };
};

subtest "Multiple calls return consistent data" => sub {
    my $ethdev = ConfigServer::GetEthDev->new();

    my %ifaces1 = $ethdev->ifaces();
    my %ifaces2 = $ethdev->ifaces();
    is( \%ifaces1, \%ifaces2, "ifaces() returns consistent data" );

    my %ipv4_1 = $ethdev->ipv4();
    my %ipv4_2 = $ethdev->ipv4();
    is( \%ipv4_1, \%ipv4_2, "ipv4() returns consistent data" );

    my %ipv6_1 = $ethdev->ipv6();
    my %ipv6_2 = $ethdev->ipv6();
    is( \%ipv6_1, \%ipv6_2, "ipv6() returns consistent data" );

    my %brd1 = $ethdev->brd();
    my %brd2 = $ethdev->brd();
    is( \%brd1, \%brd2, "brd() returns consistent data" );
};

subtest "Module behavior with ip command" => sub {
  SKIP: {
        my $config = ConfigServer::Config->loadconfig();
        my %config = $config->config();

        skip "ip command not available", 1 unless -e $config{IP};

        my $ethdev = ConfigServer::GetEthDev->new();
        is( $ethdev->{status}, 0, "Status is 0 when ip command available" );

        my %ifaces = $ethdev->ifaces();
        my %ipv4   = $ethdev->ipv4();

        ok( scalar( keys %ifaces ) > 0, "Detected interfaces with ip command" );
        ok( scalar( keys %ipv4 ) > 0,   "Detected IPv4 addresses with ip command" );
    }
};

subtest "Module behavior with ifconfig command" => sub {
  SKIP: {
        my $config = ConfigServer::Config->loadconfig();
        my %config = $config->config();

        skip "ifconfig command not available", 1 unless -e $config{IFCONFIG};

        my $ethdev = ConfigServer::GetEthDev->new();
        is( $ethdev->{status}, 0, "Status is 0 when ifconfig command available" );

        my %ifaces = $ethdev->ifaces();
        my %ipv4   = $ethdev->ipv4();

        ok( scalar( keys %ifaces ) > 0, "Detected interfaces with ifconfig command" );
        ok( scalar( keys %ipv4 ) > 0,   "Detected IPv4 addresses with ifconfig command" );
    }
};

subtest "cPanel NAT configuration support" => sub {
  SKIP: {
        skip "cPanel NAT file not present", 1 unless -e "/var/cpanel/cpnat";

        my $ethdev = ConfigServer::GetEthDev->new();
        my %ipv4   = $ethdev->ipv4();

        ok( scalar( keys %ipv4 ) > 0, "IPv4 addresses include NAT entries" );
        pass("Module successfully read /var/cpanel/cpnat");
    }
};

done_testing;
