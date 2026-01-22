#!/usr/local/cpanel/3rdparty/bin/perl

#                                      Copyright 2026 WebPros International, LLC
#                                                           All rights reserved.
# copyright@cpanel.net                                         http://cpanel.net
# This code is subject to the cPanel license. Unauthorized copying is prohibited.

use cPstrict;

use Test2::V0;
use Test2::Tools::Explain;
use Test2::Plugin::NoWarnings;

use lib 't/lib';
use MockConfig;

# Load module under test
use ConfigServer::DisplayResellerUI ();

# Mock dependencies
my $checkip_mock = mock 'ConfigServer::CheckIP' => (
    override => [
        checkip => sub {
            my $ip_ref = shift;
            return 1 if $$ip_ref =~ /^192\.168\.1\.\d+$/;
            return 1 if $$ip_ref eq '10.0.0.1';
            return 0;
        },
    ],
);

my $sendmail_mock = mock 'ConfigServer::Sendmail' => (
    override => [
        relay => sub {
            return 1;
        },
    ],
);

my $logger_mock = mock 'ConfigServer::Logger' => (
    override => [
        logfile => sub {
            return;
        },
    ],
);

subtest "Module loading" => sub {
    ok( defined $ConfigServer::DisplayResellerUI::VERSION, "Module has VERSION" );
    can_ok( 'ConfigServer::DisplayResellerUI', ['main'] );
};

subtest "main function exists and is callable" => sub {
    ok( defined &ConfigServer::DisplayResellerUI::main, "main subroutine exists" );
    is( ref( \&ConfigServer::DisplayResellerUI::main ), 'CODE', "main is a CODE reference" );
};

subtest "main function with invalid IP" => sub {
    my $output = capture_output(
        sub {
            my %form = (
                action  => 'qallow',
                ip      => 'invalid.ip.address',
                comment => 'Test comment',
            );

            ConfigServer::DisplayResellerUI::main(
                \%form,
                '/test/script',
                0,
                '/images',
                '1.01'
            );
        }
    );

    like( $output, qr/is not a valid IP address/, "Invalid IP produces error message" );
};

subtest "main function with no action displays menu" => sub {
    plan skip_all => 'Requires real /etc/csf/csf.resellers and /proc/sys/kernel/hostname files';
};

subtest "main function basic structure validation" => sub {

    # Test that function accepts correct number of parameters
    my $output = capture_output(
        sub {
            my %form = ();

            # Should not die with proper parameters
            ok(
                lives {
                    ConfigServer::DisplayResellerUI::main(
                        \%form,
                        '/test/script',
                        0,
                        '/images',
                        '1.01'
                    );
                },
                "main executes without dying with empty form"
            );
        }
    );

    ok( length($output) > 0, "main produces output" );
};

subtest "Reseller privileges validation" => sub {
    plan skip_all => 'Requires real /etc/csf/csf.resellers and /proc/sys/kernel/hostname files';
};

done_testing;

# Helper subroutine to capture STDOUT
sub capture_output {
    my $code = shift;

    my $output = '';
    open( my $handle, '>', \$output ) or die "Cannot open string for writing: $!";
    my $old_fh = select($handle);

    eval { $code->() };
    my $error = $@;

    select($old_fh);
    close($handle);

    die $error if $error;

    return $output;
}
