#!/usr/local/cpanel/3rdparty/bin/perl

#                                      Copyright 2026 WebPros International, LLC
#                                                           All rights reserved.
# copyright@cpanel.net                                         http://cpanel.net
# This code is subject to the cPanel license. Unauthorized copying is prohibited.

use lib 't/lib';
use FindBin::libs;

use cPstrict;

use Test2::V0;
use Test2::Plugin::NoWarnings;
use Test::MockModule;
use File::Temp ();

# This test validates that csf.pl handles uninitialized variables correctly
# when processing firewall rules with missing or incomplete fields.
# It leverages the modulino pattern to load csf.pl without executing it.

# Create temporary directory for test artifacts
my $tempdir   = File::Temp->newdir( CLEANUP => 1 );
my $temp_path = $tempdir->dirname;

# Create version.txt in temp directory
open my $vfh, '>', "$temp_path/version.txt" or die "Failed to create version.txt: $!";
print $vfh "1.0.0-test\n";
close $vfh;

# Mock ConfigServer::Slurp
my $slurp_mock = Test::MockModule->new('ConfigServer::Slurp');
$slurp_mock->redefine( 'slurpreg', sub { return qr/\s/; } );
$slurp_mock->redefine( 'cleanreg', sub { return qr/[\r\n]/; } );
$slurp_mock->redefine(
    'slurp',
    sub {
        my ( $file, %opts ) = @_;
        $file =~ s{^/etc/csf/}{$temp_path/};
        return unless -e $file;
        open my $fh, '<', $file or die "Failed to open $file: $!";
        my @lines = <$fh>;
        close $fh;
        return @lines;
    }
);
$slurp_mock->redefine(
    'slurpee',
    sub {
        my ( $file, %opts ) = @_;
        $file =~ s{^/etc/csf/}{$temp_path/};
        if ( !-e $file && $opts{fatal} ) {
            die "*Error* File does not exist: [$file]\n";
        }
        return '' unless -e $file;
        open my $fh, '<', $file or die "Failed to open $file: $!";
        my $content = do { local $/; <$fh> };
        close $fh;
        return $content;
    }
);

# Mock ConfigServer::Config
my $config_mock = Test::MockModule->new('ConfigServer::Config');
my %mock_config = (
    TESTING          => 1,
    IPV6             => 1,
    LF_IPSET         => 0,
    FASTSTART        => 0,
    PACKET_FILTER    => 1,
    DROP_NOLOG       => '',
    DROP_IP_LOGGING  => 0,
    DROP_OUT_LOGGING => 0,
    DROP_PF_LOGGING  => 0,
    DROP_UID_LOGGING => 0,
    IPTABLES         => '/sbin/iptables',
    IP6TABLES        => '/sbin/ip6tables',
    IPTABLESWAIT     => '',
    DROP             => 'DROP',
    DROP_OUT         => 'DROP',
    LF_BLOCKINONLY   => 0,
    MESSENGER        => 0,
    MESSENGER6       => 0,
);

$config_mock->redefine( 'loadconfig', sub { return bless {}, 'ConfigServer::Config'; } );
$config_mock->redefine( 'config',     sub { return %mock_config; } );
$config_mock->redefine( 'get_config', sub { my ( $class, $key ) = @_; return $mock_config{$key}; } );

# Mock IPC::Open3 to prevent actual command execution
my $open3_mock = Test::MockModule->new('IPC::Open3');
$open3_mock->redefine(
    'open3',
    sub {
        my $sample_output = "Sample output\n";
        open my $fake_out, '<', \$sample_output or die "Failed to create fake output: $!";
        open my $fake_err, '<', \''             or die "Failed to create fake error: $!";
        $_[1] = $fake_out if defined $_[1];
        $_[2] = $fake_err if defined $_[2];
        return 1234;
    }
);

# Mock waitpid
BEGIN {
    *CORE::GLOBAL::waitpid = sub {
        $? = 0;
        return $_[0];
    };
}

# Load csf.pl as a module (modulino pattern - won't execute run())
require './csf.pl';

subtest 'linefilter handles incomplete pipe-delimited rules without uninitialized warnings' => sub {

    # Mock ConfigServer::CheckIP
    my $checkip_mock = Test::MockModule->new('ConfigServer::CheckIP');
    $checkip_mock->redefine(
        'checkip',
        sub {
            my $ip_ref = shift;
            my $ip     = ref $ip_ref ? $$ip_ref : $ip_ref;
            return 4 if $ip =~ /^\d+\.\d+\.\d+\.\d+$/;
            return 6 if $ip =~ /^[0-9a-f:]+$/i;
            return 0;
        }
    );

    # Set package variables needed by linefilter
    no warnings 'once';
    $sbin::csf::ethdevin       = '! -i lo';
    $sbin::csf::ethdevout      = '! -o lo';
    $sbin::csf::eth6devin      = '! -i lo';
    $sbin::csf::eth6devout     = '! -o lo';
    $sbin::csf::accept         = 'ACCEPT';
    $sbin::csf::verbose        = '';
    %sbin::csf::config         = %mock_config;
    %sbin::csf::messengerports = ();

    # Track syscommand calls
    our @syscommand_calls;
    my $syscommand_mock = Test::MockModule->new( 'sbin::csf', no_auto => 1 );
    $syscommand_mock->redefine(
        'syscommand',
        sub {
            my ( $line, $cmd ) = @_;
            push @syscommand_calls, $cmd;
            return;
        }
    );

    # Test case 1: Rule with only protocol (single field) - tests @ll with 1 element
    @syscommand_calls = ();
    eval { sbin::csf::linefilter( 'tcp', 'deny', '', 0 ); };
    ok( !$@, 'linefilter handles single-field rule (tcp) without warnings' ) or diag("Error: $@");

    # Test case 2: Rule with protocol and direction (two fields) - tests @ll with 2 elements
    @syscommand_calls = ();
    eval { sbin::csf::linefilter( 'tcp|in', 'deny', '', 0 ); };
    ok( !$@, 'linefilter handles two-field rule (tcp|in) without warnings' ) or diag("Error: $@");

    # Test case 3: Rule with protocol, direction, and port (three fields) - tests @ll with 3 elements
    @syscommand_calls = ();
    eval { sbin::csf::linefilter( 'tcp|in|d=80', 'allow', '', 0 ); };
    ok( !$@, 'linefilter handles three-field rule (tcp|in|d=80) without warnings' ) or diag("Error: $@");

    # Test case 4: Rule with protocol, direction, port, and IP (four fields) - tests @ll with 4 elements
    @syscommand_calls = ();
    eval { sbin::csf::linefilter( 'tcp|in|d=80|s=192.168.1.1', 'allow', '', 0 ); };
    ok( !$@, 'linefilter handles four-field rule (tcp|in|d=80|s=192.168.1.1) without warnings' ) or diag("Error: $@");

    # Test case 5: Full rule with all fields including UID (five fields) - tests @ll with 5 elements
    @syscommand_calls = ();
    eval { sbin::csf::linefilter( 'tcp|in|d=80|s=192.168.1.1|u=1000', 'allow', '', 0 ); };
    ok( !$@, 'linefilter handles five-field rule with UID without warnings' ) or diag("Error: $@");

    # Test case 6: Rule with missing middle fields (sparse fields) - tests undefined @ll elements
    @syscommand_calls = ();
    eval { sbin::csf::linefilter( 'tcp||d=443', 'allow', '', 0 ); };
    ok( !$@, 'linefilter handles sparse fields (tcp||d=443) without warnings' ) or diag("Error: $@");

    # Test case 7: Colon-delimited format (legacy) - tests colon-to-pipe conversion
    @syscommand_calls = ();
    eval { sbin::csf::linefilter( 'tcp:in:d=22', 'allow', '', 0 ); };
    ok( !$@, 'linefilter handles colon-delimited format (tcp:in:d=22) without warnings' ) or diag("Error: $@");
};

done_testing;
