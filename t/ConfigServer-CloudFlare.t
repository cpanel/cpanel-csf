#!/usr/local/cpanel/3rdparty/bin/perl

use cPstrict;

use Test2::V0;
use Test2::Plugin::NoWarnings;

use lib 't/lib';
use MockConfig;

use ConfigServer::CloudFlare;

subtest 'module loads successfully' => sub {
    ok( 1, 'ConfigServer::CloudFlare loaded' );
};

subtest 'public subroutines exist' => sub {
    can_ok( 'ConfigServer::CloudFlare', [ 'action', 'getscope' ] );
};

subtest '_checktarget determines correct target types' => sub {
    my $check_country = ConfigServer::CloudFlare::_checktarget('US');
    is( $check_country, 'country', 'two-letter code identified as country' );

    my $check_range16 = ConfigServer::CloudFlare::_checktarget('10.0.0.0/16');
    is( $check_range16, 'ip_range', '/16 CIDR identified as ip_range' );

    my $check_range24 = ConfigServer::CloudFlare::_checktarget('192.168.1.0/24');
    is( $check_range24, 'ip_range', '/24 CIDR identified as ip_range' );

    my $check_ip = ConfigServer::CloudFlare::_checktarget('1.2.3.4');
    is( $check_ip, 'ip', 'regular IP identified as ip' );
};

subtest 'action returns early without URLGET config' => sub {
    set_config(
        URLGET => 0,
        DEBUG  => 0,
    );

    my $log_called = 0;
    my $logged_msg;
    my $logger_mock = mock 'ConfigServer::CloudFlare' => (
        override => [
            logfile => sub {
                $log_called++;
                $logged_msg = shift;
                return;
            },
        ],
    );

    my $result = ConfigServer::CloudFlare::action( 'deny', '1.2.3.4', 'block', '', 'example.com', 0 );
    is( $result, undef, 'action returns undef when URLGET is disabled' );
    ok( $log_called, 'logfile was called' );
    like( $logged_msg, qr/URLGET must be set to 1/, 'correct error message logged' );

    clear_config();
};

subtest 'getscope reads configuration file' => sub {
    my $slurp_mock = mock 'ConfigServer::Slurp' => (
        override => [
            slurp => sub {
                my $file = shift;
                if ( $file =~ /csf\.cloudflare/ ) {
                    return (
                        'DOMAIN:example.com:USER:testuser:ACCOUNT:test@example.com:APIKEY:testkey123',
                        'DISABLE:disableduser',
                        'ANY:anyuser',
                    );
                }
                return ();
            },
            cleanreg => sub {
                return qr/\s*#.*/;
            },
        ],
    );

    set_config(
        CF_CPANEL => 0,
    );

    my $scope = ConfigServer::CloudFlare::getscope();

    ok( ref($scope) eq 'HASH',   'getscope returns hashref' );
    ok( exists $scope->{domain}, 'scope has domain key' );
    ok( exists $scope->{user},   'scope has user key' );

    is( $scope->{domain}{'example.com'}{account}, 'test@example.com', 'domain account parsed correctly' );
    is( $scope->{domain}{'example.com'}{apikey},  'testkey123',       'domain apikey parsed correctly' );
    is( $scope->{domain}{'example.com'}{user},    'testuser',         'domain user parsed correctly' );

    is( $scope->{user}{testuser}{account}, 'test@example.com', 'user account set correctly' );
    is( $scope->{user}{testuser}{apikey},  'testkey123',       'user apikey set correctly' );

    clear_config();
};

done_testing;
