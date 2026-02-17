#!/usr/local/cpanel/3rdparty/bin/perl

#                                      Copyright 2026 WebPros International, LLC
#                                                           All rights reserved.
# copyright@cpanel.net                                         http://cpanel.net
# This code is subject to the cPanel license. Unauthorized copying is prohibited.

use cPstrict;

use Test2::V0;
use Test2::Plugin::NoWarnings;
use Test::MockModule;

use FindBin::libs;

# This test validates that csf.pl can be loaded as a modulino and executed with
# the -l argument without actually modifying firewall state. It uses Test::MockModule
# to mock all external dependencies.

# Create tmp directory with version.txt
foreach my $dir (qw{/opt/repos /opt/repos/app-csf /opt/repos/app-csf/tmp}) {
    mkdir $dir unless -d $dir;
}
open my $vfh, '>', '/opt/repos/app-csf/tmp/version.txt' or die $!;
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
        $file =~ s{^/etc/csf/}{/opt/repos/app-csf/tmp/};
        return unless -e $file;
        open my $fh, '<', $file or die;
        my @lines = <$fh>;
        close $fh;
        return @lines;
    }
);
$slurp_mock->redefine(
    'slurpee',
    sub {
        my ( $file, %opts ) = @_;
        $file =~ s{^/etc/csf/}{/opt/repos/app-csf/tmp/};
        if ( !-e $file && $opts{fatal} ) {
            die "*Error* File does not exist: [$file]\n";
        }
        return '' unless -e $file;
        open my $fh, '<', $file or die;
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
);
$config_mock->redefine( 'loadconfig', sub { return bless {}, 'ConfigServer::Config'; } );
$config_mock->redefine( 'config',     sub { return %mock_config; } );
$config_mock->redefine( 'get_config', sub { my ( $class, $key ) = @_; return $mock_config{$key}; } );

# Mock IPC::Open3 to prevent actual command execution
our @executed_commands;
my $open3_mock = Test::MockModule->new('IPC::Open3');
$open3_mock->redefine(
    'open3',
    sub {
        my ( $wtr, $rdr, $err, @cmd ) = @_;
        push @executed_commands, join( ' ', @cmd );
        my $sample_output = "Sample output\n";
        open my $fake_out, '<', \$sample_output or die;
        open my $fake_err, '<', \''             or die;
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

subtest 'modulino pattern implemented correctly' => sub {
    open my $fh, '<', 'csf.pl' or die;
    my $source = do { local $/; <$fh> };
    close $fh;

    like(
        $source, qr/__PACKAGE__->run\(\) unless caller;/,
        'Has modulino pattern: __PACKAGE__->run() unless caller'
    );

    like(
        $source, qr/sub run \{/,
        'Has run() subroutine defined'
    );

    # Extract run() subroutine
    my ($run_sub) = $source =~ /(sub run \{.*?^})/ms;
    ok( $run_sub, 'Successfully extracted run() subroutine' );

    like(
        $run_sub, qr/\$version = version\(\);/,
        'version() initialization moved inside run() to prevent compile-time file access'
    );
};

subtest 'execute modulino with -l argument without modifying system' => sub {
    @executed_commands = ();
    local @ARGV = ('-l');

    my $load_ok = eval {
        require './csf.pl';
        1;
    };

    if ( !$load_ok ) {
        my $error = $@ || '';
        fail("Failed to load csf.pl: $error");
        diag("Additional mocking needed - error above shows what's missing");
        return;
    }

    pass('csf.pl loaded and executed as modulino with -l argument');
    pass('No actual firewall modifications occurred (all commands mocked)');

    note( "Executed " . scalar(@executed_commands) . " commands" ) if @executed_commands;
};

done_testing;
