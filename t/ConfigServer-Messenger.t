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

use ConfigServer::Messenger;

# Mock dependencies
my $logger_mock = mock 'ConfigServer::Logger' => (
    override => [
        logfile => sub { return; },
    ],
);

my $checkip_mock = mock 'ConfigServer::CheckIP' => (
    override => [
        checkip => sub {
            my $ip_ref = shift;
            my $ip     = ref $ip_ref ? $$ip_ref : $ip_ref;
            return 1 if $ip =~ /^\d+\.\d+\.\d+\.\d+$/;
            return 0;
        },
    ],
);

my $urlget_mock = mock 'ConfigServer::URLGet' => (
    override => [
        urlget => sub { return ''; },
    ],
);

my $getethdev_mock = mock 'ConfigServer::GetEthDev' => (
    override => [
        new  => sub { return bless {}, 'ConfigServer::GetEthDev'; },
        ipv4 => sub { return (); },
        ipv6 => sub { return (); },
    ],
);

# Test module basics
subtest 'Module basics' => sub {
    ok( ConfigServer::Messenger->can('init'),        'init method exists' );
    ok( ConfigServer::Messenger->can('start'),       'start method exists' );
    ok( ConfigServer::Messenger->can('messengerv2'), 'messengerv2 method exists' );
    ok( ConfigServer::Messenger->can('error'),       'error method exists' );
    ok( defined $ConfigServer::Messenger::VERSION,   'VERSION is defined' );
    is( $ConfigServer::Messenger::VERSION, 3.00, 'VERSION is 3.00' );
};

# Test init method
subtest 'init method' => sub {
    set_config(
        MESSENGER6    => 0,
        RECAPTCHA_NAT => '',
    );

    my $messenger = ConfigServer::Messenger->init(1);
    ok( defined $messenger, 'init returns a defined value' );
    isa_ok( $messenger, ['ConfigServer::Messenger'], 'init returns correct object type' );

    clear_config();
};

# Test init with different versions
subtest 'init with different versions' => sub {
    set_config(
        MESSENGER6    => 0,
        RECAPTCHA_NAT => '',
    );

    my $messenger1 = ConfigServer::Messenger->init(1);
    isa_ok( $messenger1, ['ConfigServer::Messenger'], 'init(1) returns messenger object' );

    my $messenger2 = ConfigServer::Messenger->init(2);
    isa_ok( $messenger2, ['ConfigServer::Messenger'], 'init(2) returns messenger object' );

    my $messenger3 = ConfigServer::Messenger->init(3);
    isa_ok( $messenger3, ['ConfigServer::Messenger'], 'init(3) returns messenger object' );

    clear_config();
};

# Test VERSION export
subtest 'VERSION variable' => sub {
    is( $ConfigServer::Messenger::VERSION, 3.00, 'VERSION is correct' );
};

# Test init with RECAPTCHA_NAT configuration
subtest 'init handles RECAPTCHA_NAT IPs' => sub {
    %ConfigServer::Messenger::config = ();
    set_config(
        MESSENGER6    => 0,
        RECAPTCHA_NAT => '192.168.1.1, 10.0.0.1',
        IPV6          => 0,
    );

    my $messenger = ConfigServer::Messenger->init(1);
    isa_ok( $messenger, ['ConfigServer::Messenger'], 'init(1) with RECAPTCHA_NAT works' );

    %ConfigServer::Messenger::config = ();
    clear_config();
};

# Test init version 3 creates SSL directory
subtest 'init version 3 behavior' => sub {
    %ConfigServer::Messenger::config = ();
    set_config(
        MESSENGER6    => 0,
        RECAPTCHA_NAT => '',
    );

    my $messenger3 = ConfigServer::Messenger->init(3);
    isa_ok( $messenger3, ['ConfigServer::Messenger'], 'init(3) returns object' );
    ok( -d '/var/lib/csf/ssl', 'SSL directory exists after init(3)' ) if -w '/var/lib/csf';

    %ConfigServer::Messenger::config = ();
    clear_config();
};

# Test init with MESSENGER6 enabled
subtest 'init with IPv6 support' => sub {
    %ConfigServer::Messenger::config = ();
    set_config(
        MESSENGER6    => 1,
        RECAPTCHA_NAT => '',
        IPV6          => 1,
    );

    my $messenger = ConfigServer::Messenger->init(1);
    isa_ok( $messenger, ['ConfigServer::Messenger'], 'init(1) with MESSENGER6 works' );

    %ConfigServer::Messenger::config = ();
    clear_config();
};

# Test config caching behavior
subtest 'config caching behavior' => sub {
    %ConfigServer::Messenger::config = ();
    set_config(
        DEBUG              => 1,
        MESSENGER_HTTPS_IN => '443',
        IPV6               => 0,
    );

    # Populate the config cache by directly accessing it
    %ConfigServer::Messenger::config = ConfigServer::Config->get_config;

    is( $ConfigServer::Messenger::config{DEBUG},              1,     'Config cached DEBUG value' );
    is( $ConfigServer::Messenger::config{MESSENGER_HTTPS_IN}, '443', 'Config cached MESSENGER_HTTPS_IN value' );

    %ConfigServer::Messenger::config = ();
    clear_config();
};

# Test with different DEBUG levels
subtest 'DEBUG level configuration' => sub {
    %ConfigServer::Messenger::config = ();

    for my $debug_level ( 0, 1, 2, 3 ) {
        set_config(
            DEBUG => $debug_level,
        );

        %ConfigServer::Messenger::config = ConfigServer::Config->get_config;
        is( $ConfigServer::Messenger::config{DEBUG}, $debug_level, "DEBUG level $debug_level cached correctly" );
        %ConfigServer::Messenger::config = ();
        clear_config();
    }
};

# Test MESSENGER_HTTPS_SKIPMAIL configuration
subtest 'MESSENGER_HTTPS_SKIPMAIL configuration' => sub {
    %ConfigServer::Messenger::config = ();
    set_config(
        MESSENGER_HTTPS_SKIPMAIL => 1,
        IPV6                     => 0,
    );

    %ConfigServer::Messenger::config = ConfigServer::Config->get_config;
    is( $ConfigServer::Messenger::config{MESSENGER_HTTPS_SKIPMAIL}, 1, 'MESSENGER_HTTPS_SKIPMAIL enabled' );

    %ConfigServer::Messenger::config = ();
    clear_config();
};

# Test RECAPTCHA_SITEKEY configuration paths
subtest 'RECAPTCHA_SITEKEY affects behavior' => sub {
    %ConfigServer::Messenger::config = ();

    # Test with RECAPTCHA_SITEKEY set
    set_config(
        RECAPTCHA_SITEKEY => 'test-site-key-123',
        RECAPTCHA_SECRET  => 'test-secret-456',
    );

    %ConfigServer::Messenger::config = ConfigServer::Config->get_config;
    is( $ConfigServer::Messenger::config{RECAPTCHA_SITEKEY}, 'test-site-key-123', 'RECAPTCHA_SITEKEY stored' );
    is( $ConfigServer::Messenger::config{RECAPTCHA_SECRET},  'test-secret-456',   'RECAPTCHA_SECRET stored' );

    %ConfigServer::Messenger::config = ();
    clear_config();

    # Test without RECAPTCHA_SITEKEY
    set_config(
        RECAPTCHA_SITEKEY => '',
    );

    %ConfigServer::Messenger::config = ConfigServer::Config->get_config;
    is( $ConfigServer::Messenger::config{RECAPTCHA_SITEKEY}, '', 'RECAPTCHA_SITEKEY empty when not configured' );

    %ConfigServer::Messenger::config = ();
    clear_config();
};

# Test webserver type configuration
subtest 'webserver type configuration' => sub {
    %ConfigServer::Messenger::config = ();

    for my $webserver ( 'apache', 'litespeed' ) {
        set_config(
            MESSENGERV3WEBSERVER => $webserver,
        );

        %ConfigServer::Messenger::config = ConfigServer::Config->get_config;
        is( $ConfigServer::Messenger::config{MESSENGERV3WEBSERVER}, $webserver, "Webserver type $webserver configured" );

        %ConfigServer::Messenger::config = ();
        clear_config();
    }
};

done_testing;
