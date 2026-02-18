#!/usr/local/cpanel/3rdparty/bin/perl

use lib 't/lib';
use FindBin::libs;

use cPstrict;

use Test2::V0;
use Test2::Tools::Explain;
use Test2::Plugin::NoWarnings;

use MockConfig;

# Helper to set default config for tests
sub _set_default_config {
    my %overrides = @_;
    clear_config();
    set_config(
        RESTRICT_UI    => 0,
        CF_ENABLE      => 0,
        ST_ENABLE      => 0,
        IPV6           => 0,
        URLGET         => 1,
        URLPROXY       => '',
        DOWNLOADSERVER => 'download.configserver.com',
        TESTING        => 1,
        THIS_UI        => 'csf',
        %overrides,
    );
    return;
}

# Set up initial mock config for module load
_set_default_config();

# Load the module under test
use ConfigServer::DisplayUI ();

# T050: Test module loads successfully
subtest 'Module loads correctly' => sub {
    ok( 1,                                         'ConfigServer::DisplayUI loaded without errors' );
    ok( defined $ConfigServer::DisplayUI::VERSION, 'VERSION is defined' );
    is( $ConfigServer::DisplayUI::VERSION, 1.01, 'VERSION is 1.01' );
};

# T051: Test public subroutine main exists
subtest 'Public API exists' => sub {
    can_ok( 'ConfigServer::DisplayUI', 'main' );
};

# T053: Test invalid IP address rejected
subtest 'Invalid IP address is rejected' => sub {
    _set_default_config();

    my $output = '';
    {
        local *STDOUT;
        open STDOUT, '>', \$output or die "Cannot redirect STDOUT: $!";

        my %form = (
            action => 'qallow',
            ip     => 'not-a-valid-ip',
        );

        ConfigServer::DisplayUI::main(
            \%form,
            '/csf/',          # $script
            '/csf/da/',       # $script_da
            '/csf/images',    # $images
            '1.01',           # $myv
            'csf',            # $this_ui
        );

        close STDOUT;
    }

    like( $output, qr/not a valid IP/i, 'Invalid IP address produces error message' );
};

# T054: Test invalid filename rejected
subtest 'Invalid filename is rejected' => sub {
    _set_default_config();

    my $output = '';
    {
        local *STDOUT;
        open STDOUT, '>', \$output or die "Cannot redirect STDOUT: $!";

        my %form = (
            action     => 'viewignore',
            ip         => '',
            ignorefile => '../../../etc/passwd',
        );

        ConfigServer::DisplayUI::main(
            \%form,
            '/csf/',          # $script
            '/csf/da/',       # $script_da
            '/csf/images',    # $images
            '1.01',           # $myv
            'csf',            # $this_ui
        );

        close STDOUT;
    }

    like( $output, qr/not a valid file/i, 'Invalid filename produces error message' );
};

# T055: Test RESTRICT_UI=2 disables UI
subtest 'RESTRICT_UI=2 disables UI' => sub {
    _set_default_config( RESTRICT_UI => 2 );

    my $output = '';
    my $status;
    {
        local *STDOUT;
        open STDOUT, '>', \$output or die "Cannot redirect STDOUT: $!";

        my %form = (
            action => 'status',
        );

        $status = ConfigServer::DisplayUI::main(
            \%form,
            '/csf/',          # $script
            '/csf/da/',       # $script_da
            '/csf/images',    # $images
            '1.01',           # $myv
            'csf',            # $this_ui
        );

        close STDOUT;
    }

    like( $output, qr/csf UI Disabled/i,    'RESTRICT_UI=2 shows disabled message' );
    like( $output, qr/RESTRICT_UI option/i, 'Message mentions RESTRICT_UI option' );
    is( $status, 0, 'RESTRICT_UI=2 returns exit code 0' );
};

done_testing();
