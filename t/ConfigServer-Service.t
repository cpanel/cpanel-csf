#!/usr/local/cpanel/3rdparty/bin/perl

use lib 't/lib';
use FindBin::libs;

use cPstrict;

use Test2::V0;
use Test2::Tools::Explain;
use Test2::Plugin::NoWarnings;

use MockConfig;
use File::Temp ();

use ConfigServer::Service ();

subtest 'Public API exists' => sub {
    can_ok( 'ConfigServer::Service', qw(type startlfd stoplfd restartlfd statuslfd) );
};

subtest '_get_init_type returns systemd' => sub {
    my ( $fh, $filename ) = File::Temp::tempfile( UNLINK => 1 );
    print $fh "systemd\n";
    close $fh;
    local $ConfigServer::Service::INIT_TYPE_FILE = $filename;
    ConfigServer::Service::_reset_init_type();
    is( ConfigServer::Service::type(), 'systemd', 'type() returns systemd' );
};

subtest '_get_init_type returns init for other values' => sub {
    my ( $fh, $filename ) = File::Temp::tempfile( UNLINK => 1 );
    print $fh "init\n";
    close $fh;
    local $ConfigServer::Service::INIT_TYPE_FILE = $filename;
    ConfigServer::Service::_reset_init_type();
    is( ConfigServer::Service::type(), 'init', 'type() returns init' );
};

subtest '_get_init_type returns init when file missing' => sub {
    local $ConfigServer::Service::INIT_TYPE_FILE = '/nonexistent/file';
    ConfigServer::Service::_reset_init_type();
    is( ConfigServer::Service::type(), 'init', 'type() returns init when file missing' );
};

subtest 'init type caching behavior' => sub {
    my ( $fh, $filename ) = File::Temp::tempfile( UNLINK => 1 );
    print $fh "systemd\n";
    close $fh;
    local $ConfigServer::Service::INIT_TYPE_FILE = $filename;
    ConfigServer::Service::_reset_init_type();
    is( ConfigServer::Service::type(), 'systemd', 'initial type is systemd' );

    # Change file contents but don't reset cache
    open my $fh2, '>', $filename or die "Cannot reopen $filename: $!";
    print $fh2 "init\n";
    close $fh2;
    is( ConfigServer::Service::type(), 'systemd', 'type still cached as systemd after file change' );

    # Reset cache and verify new value is read
    ConfigServer::Service::_reset_init_type();
    is( ConfigServer::Service::type(), 'init', 'type returns init after cache reset' );
};

subtest 'startlfd calls correct commands for systemd' => sub {
    my @calls;
    my $mock = mock 'ConfigServer::Service' => (
        override => [
            _printcmd      => sub { push @calls, [@_]; return; },
            _get_init_type => sub { 'systemd' },
        ],
    );
    set_config( SYSTEMCTL => '/bin/true' );
    ConfigServer::Service::startlfd();
    is(
        \@calls,
        [
            [ '/bin/true', 'start',  'lfd.service' ],
            [ '/bin/true', 'status', 'lfd.service' ],
        ],
        'startlfd systemd calls _printcmd with correct args'
    );
    clear_config();
};

subtest 'startlfd calls correct commands for init' => sub {
    my @calls;
    my $mock = mock 'ConfigServer::Service' => (
        override => [
            _printcmd      => sub { push @calls, [@_]; return; },
            _get_init_type => sub { 'init' },
        ],
    );
    ConfigServer::Service::startlfd();
    is(
        \@calls,
        [ [ '/etc/init.d/lfd', 'start' ] ],
        'startlfd init calls _printcmd with correct args'
    );
};

# Repeat for stoplfd, restartlfd, statuslfd
foreach my $fn (qw(stoplfd restartlfd statuslfd)) {
    my $code = ConfigServer::Service->can($fn) or die "No such function: $fn";
    subtest "$fn calls correct commands for systemd" => sub {
        my @calls;
        my $mock = mock 'ConfigServer::Service' => (
            override => [
                _printcmd      => sub { push @calls, [@_]; return; },
                _get_init_type => sub { 'systemd' },
            ],
        );
        set_config( SYSTEMCTL => '/bin/true' );
        $code->();
        my $expected_calls = (
              $fn eq 'stoplfd'    ? [ [ '/bin/true', 'stop', 'lfd.service' ] ]
            : $fn eq 'restartlfd' ? [ [ '/bin/true', 'restart', 'lfd.service' ], [ '/bin/true', 'status', 'lfd.service' ] ]
            : $fn eq 'statuslfd'  ? [ [ '/bin/true', 'status', 'lfd.service' ] ]
            :                       die "Unexpected function: $fn"
        );
        is( \@calls, $expected_calls, "$fn systemd calls _printcmd with correct args" );
        clear_config();
    };
    subtest "$fn calls correct commands for init" => sub {
        my @calls;
        my $mock = mock 'ConfigServer::Service' => (
            override => [
                _printcmd      => sub { push @calls, [@_]; return; },
                _get_init_type => sub { 'init' },
            ],
        );
        $code->();
        my $expected_action = (
              $fn eq 'stoplfd'    ? 'stop'
            : $fn eq 'restartlfd' ? 'restart'
            : $fn eq 'statuslfd'  ? 'status'
            :                       die "Unexpected function: $fn"
        );
        is( \@calls, [ [ '/etc/init.d/lfd', $expected_action ] ], "$fn init calls _printcmd with correct args" );
    };
}

subtest 'statuslfd returns 0' => sub {
    my $mock = mock 'ConfigServer::Service' => (
        override => [ _printcmd => sub { return; }, _get_init_type => sub { 'systemd' } ],
    );
    is( ConfigServer::Service::statuslfd(), 0, 'statuslfd returns 0' );
};

done_testing();
