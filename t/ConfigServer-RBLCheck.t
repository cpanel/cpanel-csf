#!/usr/local/cpanel/3rdparty/bin/perl

use lib 't/lib';
use FindBin::libs;

use cPstrict;

use Test2::V0;
use Test2::Tools::Explain;
use Test2::Plugin::NoWarnings;

use MockConfig;

# Mock dependencies to isolate the module under test
my $mock_ethdev = mock 'ConfigServer::GetEthDev' => (
    override => [
        new  => sub { bless {}, shift },
        ipv4 => sub { return () },         # No IPv4 addresses by default
        ipv6 => sub { return () },         # No IPv6 addresses
    ]
);

my $mock_rbllookup = mock 'ConfigServer::RBLLookup' => (
    override => [
        rbllookup => sub {
            my ( $ip, $rbl ) = @_;
            return ( "", "OK" );    # Not listed by default
        },
    ]
);

# Now load the module under test
use ConfigServer::RBLCheck;

subtest 'Module loads correctly' => sub {
    ok( 1,                                        'ConfigServer::RBLCheck loaded without errors' );
    ok( defined $ConfigServer::RBLCheck::VERSION, 'VERSION is defined' );
};

subtest 'Public API exists' => sub {
    can_ok( 'ConfigServer::RBLCheck', 'report' );
};

subtest 'Private functions are not exported' => sub {
    my @private_funcs = qw(_startoutput _addline _addtitle _endoutput _getethdev);

    for my $func (@private_funcs) {
        ok(
            !main->can($func),
            "Private function $func is not exported to main"
        );
    }
};

subtest 'report() returns expected structure with no IPs' => sub {
    my ( $failures, $output ) = ConfigServer::RBLCheck::report( 0, '', 0 );

    is( $failures, 0, 'No failures with no IPs configured' );
    like( $output, qr/<br>/, 'Output contains HTML' );
};

subtest 'report() with UI mode prints to STDOUT and returns output' => sub {

    # Capture STDOUT to verify UI mode prints
    my $stdout = '';
    {
        local *STDOUT;
        open STDOUT, '>', \$stdout or die "Cannot redirect STDOUT: $!";

        my ( $failures, $output ) = ConfigServer::RBLCheck::report( 0, '', 1 );

        is( $failures, 0, 'Failures count returned' );
        like( $output, qr/<br>/, 'Output still contains HTML in UI mode' );
    }

    like( $stdout, qr/<br>/, 'Output printed to STDOUT in UI mode' );
};

subtest 'report() with mocked public IP returns zero failures' => sub {

    # Override mock to return a public IP
    $mock_ethdev = mock 'ConfigServer::GetEthDev' => (
        override => [
            new  => sub { bless {}, shift },
            ipv4 => sub { return ( '8.8.8.8' => 1 ) },
            ipv6 => sub { return () },
        ]
    );

    # Mock RBLLookup to return "not listed"
    $mock_rbllookup = mock 'ConfigServer::RBLLookup' => (
        override => [
            rbllookup => sub {
                my ( $ip, $rbl ) = @_;
                return ( "", "OK" );
            },
        ]
    );

    my ( $failures, $output ) = ConfigServer::RBLCheck::report( 0, '', 0 );

    is( $failures, 0, 'Zero failures when IP is not listed' );
    like( $output, qr/8\.8\.8\.8|PUBLIC/, 'Output mentions the IP' );
};

subtest 'report() with verbosity levels' => sub {
    my ( $fail_v0, $out_v0 ) = ConfigServer::RBLCheck::report( 0, '', 0 );
    my ( $fail_v1, $out_v1 ) = ConfigServer::RBLCheck::report( 1, '', 0 );
    my ( $fail_v2, $out_v2 ) = ConfigServer::RBLCheck::report( 2, '', 0 );

    is( $fail_v0, 0, 'Verbosity 0: failures count' );
    is( $fail_v1, 0, 'Verbosity 1: failures count' );
    is( $fail_v2, 0, 'Verbosity 2: failures count' );

    ok( length($out_v0) > 0, 'Verbosity 0 produces output' );
    ok( length($out_v1) > 0, 'Verbosity 1 produces output' );
    ok( length($out_v2) > 0, 'Verbosity 2 produces output' );
};

done_testing();
