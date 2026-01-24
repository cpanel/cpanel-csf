#!/usr/local/cpanel/3rdparty/bin/perl

use cPstrict;

use Test2::V0;
use Test2::Tools::Explain;
use Test2::Plugin::NoWarnings;

use Cwd        ();
use File::Temp ();

use lib 't/lib';
use MockConfig;

# Set up mock config values that cseUI.pm uses
set_config(
    UI_CXS => 0,
    UI_CSE => 1,
);

# Load the module under test
use ConfigServer::cseUI ();

subtest 'Module loads correctly' => sub {
    ok( 1,                                     'ConfigServer::cseUI loaded without errors' );
    ok( defined $ConfigServer::cseUI::VERSION, 'VERSION is defined' );
    is( $ConfigServer::cseUI::VERSION, 2.03, 'VERSION is 2.03' );
};

subtest 'Public API exists' => sub {
    can_ok( 'ConfigServer::cseUI', 'main' );
};

subtest 'Private functions are not exported' => sub {
    my @private_funcs = qw(
      _loadconfig _browse _setp _seto _ren _moveit _copyit _mycopy
      _cnewd _cnewf _del _view _console _cd _edit _save _uploadfile _countfiles
    );

    for my $func (@private_funcs) {
        ok(
            !main->can($func),
            "Private function $func is not exported to main"
        );
    }
};

subtest 'Module uses modern Perl standards' => sub {

    # Verify the module file uses cPstrict
    my $module_file = 'lib/ConfigServer/cseUI.pm';
    open my $fh, '<', $module_file or die "Cannot open $module_file: $!";
    my $content = do { local $/; <$fh> };
    close $fh;

    like( $content, qr/use cPstrict;/, 'Module uses cPstrict' );
    unlike( $content, qr/use Exporter/,               'Module does not use Exporter' );
    unlike( $content, qr/\@ISA\s*=\s*qw\(Exporter\)/, 'Module does not have @ISA = qw(Exporter)' );
    unlike( $content, qr/\@EXPORT_OK/,                'Module does not have @EXPORT_OK' );

    # Verify no Perl 4-style calls (excluding HTML entities and subroutine refs)
    my @lines = split /\n/, $content;
    for my $line (@lines) {

        # Skip lines with HTML entities, URLs, or subroutine references
        next if $line =~ /&(?:amp|nbsp|copy|lt|gt|#\d+)/;
        next if $line =~ /href=|print.*&[a-z]=/;
        next if $line =~ /\\&_\w+/;                         # Subroutine reference like \&_mycopy
        next if $line =~ /s\/.*&/;                          # Regex substitution

        # Check for Perl 4-style subroutine calls
        unlike(
            $line,
            qr/&(?!amp|nbsp|copy|lt|gt|#)[a-z_]+[;(]/i,
            "No Perl 4-style call on line: $line"
        ) if $line =~ /&[a-z_]+[;(]/i;
    }
};

subtest 'Module has POD documentation' => sub {
    my $module_file = 'lib/ConfigServer/cseUI.pm';
    open my $fh, '<', $module_file or die "Cannot open $module_file: $!";
    my $content = do { local $/; <$fh> };
    close $fh;

    like( $content, qr/=head1 NAME/,        'POD has NAME section' );
    like( $content, qr/=head1 SYNOPSIS/,    'POD has SYNOPSIS section' );
    like( $content, qr/=head1 DESCRIPTION/, 'POD has DESCRIPTION section' );
    like( $content, qr/=head2 main/,        'POD has main() documentation' );
    like( $content, qr/=head1 AUTHOR/,      'POD has AUTHOR section' );
};

subtest 'Module removes unused global variables' => sub {
    my $module_file = 'lib/ConfigServer/cseUI.pm';
    open my $fh, '<', $module_file or die "Cannot open $module_file: $!";
    my $content = do { local $/; <$fh> };
    close $fh;

    # Check that unused variables are removed
    unlike( $content, qr/\$chart/,    '$chart variable removed' );
    unlike( $content, qr/\$ipscidr6/, '$ipscidr6 variable removed' );
    unlike( $content, qr/\$ipv6reg/,  '$ipv6reg variable removed' );
    unlike( $content, qr/\$ipv4reg/,  '$ipv4reg variable removed' );
    unlike( $content, qr/\%ips\b/,    '%ips variable removed' );
    unlike( $content, qr/\$mobile/,   '$mobile variable removed' );
};

subtest 'Module uses fully qualified function names' => sub {
    my $module_file = 'lib/ConfigServer/cseUI.pm';
    open my $fh, '<', $module_file or die "Cannot open $module_file: $!";
    my $content = do { local $/; <$fh> };
    close $fh;

    # Check for fully qualified Fcntl constants
    like( $content, qr/Fcntl::LOCK_SH/, 'Uses Fcntl::LOCK_SH' );
    like( $content, qr/Fcntl::LOCK_EX/, 'Uses Fcntl::LOCK_EX' );

    # Check for fully qualified function calls
    like( $content, qr/File::Find::find/,  'Uses File::Find::find' );
    like( $content, qr/File::Copy::copy/,  'Uses File::Copy::copy' );
    like( $content, qr/IPC::Open3::open3/, 'Uses IPC::Open3::open3' );

    # Check that imports are disabled (allow flexible whitespace)
    like( $content, qr/use Fcntl\s+\(\);/,      'Fcntl import disabled' );
    like( $content, qr/use File::Find\s+\(\);/, 'File::Find import disabled' );
    like( $content, qr/use File::Copy\s+\(\);/, 'File::Copy import disabled' );
    like( $content, qr/use IPC::Open3\s+\(\);/, 'IPC::Open3 import disabled' );
};

# Helper to capture STDOUT from main()
# T079: Tests the output capture helper function
sub capture_main {
    my (%form) = @_;

    my $output = '';
    {
        local *STDOUT;
        open STDOUT, '>', \$output or die "Cannot redirect STDOUT: $!";

        ConfigServer::cseUI::main(
            \%form,
            undef,            # $fileinc
            '/cse/',          # $script
            '/cse/da/',       # $script_da
            '/cse/images',    # $images
            '2.03',           # $version
        );

        close STDOUT;
    }
    return $output;
}

# T079: Verify output capture helper works correctly
subtest 'Output capture helper function works' => sub {
    my $tempdir = File::Temp->newdir();

    my %form = (
        do => 'b',
        p  => $tempdir->dirname,
    );

    my $output = capture_main(%form);

    ok( defined $output,     'capture_main returns defined value' );
    ok( length($output) > 0, 'capture_main returns non-empty output' );
    like( $output, qr/Content-type: text\/html/, 'Output contains HTTP header' );
};

# T075: Test do=browse action with mocked directory
subtest 'do=browse action with directory listing' => sub {
    my $tempdir = File::Temp->newdir();

    # Create test files and directories
    my $testfile = "$tempdir/testfile.txt";
    my $testdir  = "$tempdir/subdir";

    open my $fh, '>', $testfile or die "Cannot create test file: $!";
    print $fh "test content\n";
    close $fh;

    mkdir $testdir or die "Cannot create test directory: $!";

    my %form = (
        do => 'b',
        p  => $tempdir->dirname,
    );

    my $output = capture_main(%form);

    # Verify browse action displays directory contents
    like( $output, qr/testfile\.txt/,        'Browse shows test file' );
    like( $output, qr/subdir/,               'Browse shows subdirectory' );
    like( $output, qr/<table/,               'Browse output contains table' );
    like( $output, qr/WARNING!/,             'Browse shows danger warning' );
    like( $output, qr/Create New Directory/, 'Browse shows create directory option' );
    like( $output, qr/Create Empty File/,    'Browse shows create file option' );
};

# T076: Test do=edit action with mocked file
subtest 'do=edit action with file content' => sub {
    my $tempdir = File::Temp->newdir();

    # Create a test file to edit
    my $testfile = "$tempdir/editable.txt";
    my $content  = "Line 1\nLine 2\nLine 3\n";

    open my $fh, '>', $testfile or die "Cannot create test file: $!";
    print $fh $content;
    close $fh;

    my %form = (
        do => 'edit',
        p  => $tempdir->dirname,
        f  => 'editable.txt',
    );

    my $output = capture_main(%form);

    # Verify edit action displays file content in textarea
    like( $output, qr/<textarea/,      'Edit action shows textarea' );
    like( $output, qr/Line 1/,         'Edit action shows file content' );
    like( $output, qr/value='Save'/,   'Edit action has Save button' );
    like( $output, qr/value='Cancel'/, 'Edit action has Cancel button' );
};

# T077: Test do=view action with mocked file
subtest 'do=view action downloads file' => sub {
    my $tempdir = File::Temp->newdir();

    # Create a test file to view
    my $testfile = "$tempdir/viewable.txt";
    my $content  = "This is viewable content";

    open my $fh, '>', $testfile or die "Cannot create test file: $!";
    print $fh $content;
    close $fh;

    my %form = (
        do => 'view',
        p  => $tempdir->dirname,
        f  => 'viewable.txt',
    );

    my $output = capture_main(%form);

    # Verify view action sets proper headers and outputs content
    like( $output, qr/content-type: text\/plain/,       'View sets text/plain content type' );
    like( $output, qr/content-disposition: attachment/, 'View sets attachment disposition' );
    like( $output, qr/filename=viewable\.txt/,          'View sets correct filename' );
    like( $output, qr/This is viewable content/,        'View outputs file content' );
};

# T077 additional: Test view action with non-existent file
subtest 'do=view action handles missing file' => sub {
    my $tempdir = File::Temp->newdir();

    my %form = (
        do => 'view',
        p  => $tempdir->dirname,
        f  => 'nonexistent.txt',
    );

    my $output = capture_main(%form);

    like( $output, qr/not found/i, 'View action reports file not found' );
};

# T078: Test unknown action falls through to error
subtest 'Unknown action produces error message' => sub {
    my $tempdir = File::Temp->newdir();

    my %form = (
        do => 'unknown_action_xyz',
        p  => $tempdir->dirname,
    );

    my $output = capture_main(%form);

    like( $output, qr/Invalid action/, 'Unknown action shows Invalid action message' );
};

# T074: Test that main() uses File::Temp for I/O operations (mocked directories work)
subtest 'File I/O operations work with temp directories' => sub {
    my $tempdir = File::Temp->newdir();

    # Create nested structure to verify file operations
    my $subdir   = "$tempdir/nested";
    my $testfile = "$subdir/deepfile.txt";

    mkdir $subdir or die "Cannot create subdir: $!";
    open my $fh, '>', $testfile or die "Cannot create file: $!";
    print $fh "deep content";
    close $fh;

    # Browse the nested directory
    my %form = (
        do => 'b',
        p  => $subdir,
    );

    my $output = capture_main(%form);

    like( $output, qr/deepfile\.txt/, 'Nested file visible in browse' );
    like( $output, qr/nested/,        'Path shows nested directory' );
};

subtest 'main() uses MockConfig for UI settings' => sub {
    my $tempdir = File::Temp->newdir();

    # Test with UI_CSE enabled (set in initial config)
    my %form = (
        do => 'b',
        p  => $tempdir->dirname,
    );

    my $output = capture_main(%form);

    # When UI_CSE is enabled, the app switcher should show cse as selected
    like( $output, qr/<option selected>cse<\/option>/, 'UI_CSE enabled shows cse as selected option' );
};

subtest 'main() respects UI_CXS config setting' => sub {
    my $tempdir = File::Temp->newdir();

    # Enable UI_CXS
    set_config(
        UI_CXS => 1,
        UI_CSE => 1,
    );

    my %form = (
        do => 'b',
        p  => $tempdir->dirname,
    );

    my $output = capture_main(%form);

    # When UI_CXS is enabled, cxs option should appear in dropdown
    like( $output, qr/<option>cxs<\/option>/, 'UI_CXS enabled shows cxs option' );

    # Reset to default config
    set_config(
        UI_CXS => 0,
        UI_CSE => 1,
    );
};

subtest 'main() hides app switcher when no UI options enabled' => sub {
    my $tempdir = File::Temp->newdir();

    # Disable both UI options
    set_config(
        UI_CXS => 0,
        UI_CSE => 0,
    );

    my %form = (
        do => 'b',
        p  => $tempdir->dirname,
    );

    my $output = capture_main(%form);

    # When neither UI option is enabled, no app switcher dropdown should appear
    unlike( $output, qr/<select name='csfapp'>/, 'No app switcher when UI options disabled' );

    # Reset to default config
    set_config(
        UI_CXS => 0,
        UI_CSE => 1,
    );
};

done_testing();
