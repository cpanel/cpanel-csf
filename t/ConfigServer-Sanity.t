#!/usr/local/cpanel/3rdparty/bin/perl

use cPstrict;

use Test2::V0;
use Test2::Tools::Explain;
use Test2::Plugin::NoWarnings;

use lib 't/lib';
use MockConfig;

use File::Path qw(mkpath);

# Load the module under test
use ConfigServer::Sanity ();

# Create a temporary sanity.txt file for testing
my $test_sanity_data = <<'EOF';
AT_INTERVAL=10-3600=60
DROP=DROP|TARPIT|REJECT=DROP
CT_LIMIT=0|10-1000=0
DENY_IP_LIMIT=10-1000=200
EOF

my $temp_dir = "./tmp/test-sanity";
mkpath($temp_dir);
my $test_sanity_file = "$temp_dir/sanity.txt";
open( my $fh, '>', $test_sanity_file ) or die "Cannot create test sanity file: $!";
print $fh $test_sanity_data;
close($fh);

# Override the sanity file path to use our test file
$ConfigServer::Sanity::sanityfile = $test_sanity_file;

# =============================================================================
# Lazy Loading and Error Handling Tests
# =============================================================================

subtest 'Module loads without reading sanity.txt at compile time' => sub {

    # The module should already be loaded (via 'use ConfigServer::Sanity ()')
    # without attempting to read sanity.txt at compile time
    ok( 1, 'ConfigServer::Sanity loaded successfully without compile-time file read' );

    # Verify no data has been loaded yet (lazy loading)
    reset_sanity_state();
    is( $ConfigServer::Sanity::loaded,                    0, 'Sanity data not loaded after module import' );
    is( scalar keys %ConfigServer::Sanity::sanity,        0, 'Sanity hash is empty before first call' );
    is( scalar keys %ConfigServer::Sanity::sanitydefault, 0, 'Default hash is empty before first call' );

    # First call should trigger lazy load
    my ( $insane, $acceptable, $default ) = ConfigServer::Sanity::sanity( 'AT_INTERVAL', '60' );
    is( $ConfigServer::Sanity::loaded, 1, 'Sanity data loaded on first function call' );
    ok( scalar keys %ConfigServer::Sanity::sanity > 0, 'Sanity hash populated after first call' );
};

subtest 'Error handling when sanity file is missing' => sub {

    # Save original file path
    my $original_file = $ConfigServer::Sanity::sanityfile;

    # Reset state and point to non-existent file
    reset_sanity_state();
    $ConfigServer::Sanity::sanityfile = '/tmp/nonexistent-sanity-file-for-testing.txt';

    # Should die when trying to read missing file
    like(
        dies { ConfigServer::Sanity::sanity( 'AT_INTERVAL', '60' ) },
        qr/Cannot open \/tmp\/nonexistent-sanity-file-for-testing\.txt/,
        'Dies with appropriate error when sanity file is missing'
    );

    # Restore original file path
    $ConfigServer::Sanity::sanityfile = $original_file;
    reset_sanity_state();
};

# =============================================================================
# Range Validation Tests
# =============================================================================

subtest 'Range validation' => sub {

    my ( $insane, $acceptable, $default );

    # Test valid values within range
    ( $insane, $acceptable, $default ) = ConfigServer::Sanity::sanity( 'AT_INTERVAL', '60' );
    is( $insane,     0,         'Value 60 is valid (within range 10-3600)' );
    is( $acceptable, '10-3600', 'Acceptable values string' );
    is( $default,    '60',      'Default value is 60' );

    ( $insane, $acceptable, $default ) = ConfigServer::Sanity::sanity( 'AT_INTERVAL', '10' );
    is( $insane, 0, 'Minimum value 10 is valid' );

    ( $insane, $acceptable, $default ) = ConfigServer::Sanity::sanity( 'AT_INTERVAL', '3600' );
    is( $insane, 0, 'Maximum value 3600 is valid' );

    # Test invalid values outside range
    ( $insane, $acceptable, $default ) = ConfigServer::Sanity::sanity( 'AT_INTERVAL', '5' );
    is( $insane, 1, 'Value 5 is invalid (below minimum)' );

    ( $insane, $acceptable, $default ) = ConfigServer::Sanity::sanity( 'AT_INTERVAL', '10000' );
    is( $insane, 1, 'Value 10000 is invalid (above maximum)' );
};

# =============================================================================
# Discrete Value Validation Tests
# =============================================================================

subtest 'Discrete validation' => sub {
    my ( $insane, $acceptable, $default );

    # Test valid discrete values
    ( $insane, $acceptable, $default ) = ConfigServer::Sanity::sanity( 'DROP', 'DROP' );
    is( $insane,     0,                          'Value DROP is valid' );
    is( $acceptable, 'DROP or TARPIT or REJECT', 'Acceptable values formatted with or' );
    is( $default,    'DROP',                     'Default value is DROP' );

    ( $insane, $acceptable, $default ) = ConfigServer::Sanity::sanity( 'DROP', 'TARPIT' );
    is( $insane, 0, 'Value TARPIT is valid' );

    # Test invalid discrete values
    ( $insane, $acceptable, $default ) = ConfigServer::Sanity::sanity( 'DROP', 'INVALID' );
    is( $insane, 1, 'Value INVALID is invalid' );

    ( $insane, $acceptable, $default ) = ConfigServer::Sanity::sanity( 'DROP', '123' );
    is( $insane, 1, 'Numeric value 123 is invalid' );
};

# =============================================================================
# Undefined Sanity Items Tests
# =============================================================================

subtest 'Undefined sanity items' => sub {
    my ( $insane, $acceptable, $default );

    # Test undefined item returns sane (0)
    ( $insane, $acceptable, $default ) = ConfigServer::Sanity::sanity( 'UNKNOWN_ITEM', '999' );
    is( $insane,     0,     'Undefined item returns sane (0)' );
    is( $acceptable, undef, 'Acceptable is undefined' );
    is( $default,    undef, 'Default is undefined' );
};

# =============================================================================
# IPSET Configuration Tests
# =============================================================================

subtest 'IPSET enabled - DENY_IP_LIMIT validation skipped' => sub {

    # Set IPSET to 1 and reset state to force reload
    set_config( IPSET => 1 );
    reset_sanity_state();

    my ( $insane, $acceptable, $default );

    # With IPSET=1, DENY_IP_LIMIT validation should be skipped (returns 0/sane)
    # Test with value outside normal range (10-1000)
    ( $insane, $acceptable, $default ) = ConfigServer::Sanity::sanity( 'DENY_IP_LIMIT', '5' );
    is( $insane,     0,     'DENY_IP_LIMIT validation skipped when IPSET=1 (value 5 returns sane)' );
    is( $acceptable, undef, 'Acceptable is undefined when IPSET=1' );
    is( $default,    undef, 'Default is undefined when IPSET=1' );

    ( $insane, $acceptable, $default ) = ConfigServer::Sanity::sanity( 'DENY_IP_LIMIT', '10000' );
    is( $insane, 0, 'DENY_IP_LIMIT validation skipped when IPSET=1 (value 10000 returns sane)' );
};

subtest 'IPSET disabled - DENY_IP_LIMIT validation enforced' => sub {

    # Set IPSET to 0 and reset state to force reload
    set_config( IPSET => 0 );
    reset_sanity_state();

    my ( $insane, $acceptable, $default );

    # With IPSET=0, DENY_IP_LIMIT validation should be enforced (range 10-1000)
    # Test valid value
    ( $insane, $acceptable, $default ) = ConfigServer::Sanity::sanity( 'DENY_IP_LIMIT', '200' );
    is( $insane,     0,         'Value 200 is valid when IPSET=0' );
    is( $acceptable, '10-1000', 'Acceptable range shown when IPSET=0' );
    is( $default,    '200',     'Default value is 200' );

    # Test invalid value (below minimum)
    ( $insane, $acceptable, $default ) = ConfigServer::Sanity::sanity( 'DENY_IP_LIMIT', '5' );
    is( $insane, 1, 'Value 5 is invalid when IPSET=0 (below minimum)' );

    # Test invalid value (above maximum)
    ( $insane, $acceptable, $default ) = ConfigServer::Sanity::sanity( 'DENY_IP_LIMIT', '10000' );
    is( $insane, 1, 'Value 10000 is invalid when IPSET=0 (above maximum)' );
};

# Cleanup
END {
    unlink $test_sanity_file if defined $test_sanity_file && -f $test_sanity_file;
}

done_testing();

# =============================================================================
# Helper Subroutines
# =============================================================================

# Helper to reset state between tests
sub reset_sanity_state {
    %ConfigServer::Sanity::sanity        = ();
    %ConfigServer::Sanity::sanitydefault = ();
    $ConfigServer::Sanity::loaded        = 0;
    return;
}
