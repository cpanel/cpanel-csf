#!/usr/local/cpanel/3rdparty/bin/perl

use cPstrict;

use Test2::V0;
use Test2::Tools::Explain;
use Test2::Plugin::NoWarnings;

use lib 't/lib';
use MockConfig;

# Load the module under test FIRST (which loads its dependencies)
use ConfigServer::RBLLookup ();

# Set required config values
set_config(
    HOST => '/usr/bin/host',
);

# Track IPC::Open3::open3 calls for verification
our @open3_calls;
our $mock_a_output   = '';
our $mock_txt_output = '';

# Control for ConfigServer::CheckIP mocking
our $mock_checkip_result = 1;

# Control for timeout simulation
our $mock_simulate_timeout = 0;

# Now create mocks for dependencies using Test2::Mock
my $checkip_mock = mock 'ConfigServer::CheckIP' => (
    override => [
        checkip => sub {
            my $ip_ref = shift;
            return $main::mock_checkip_result;
        },
    ],
);

# Mock IPC::Open3 to control DNS responses
my $ipc_mock = mock 'IPC::Open3' => (
    override => [
        open3 => sub {
            my ( $childin_in, $childout_in, $childerr_in, @cmd ) = @_;
            push @main::open3_calls, \@cmd;

            # Simulate timeout if requested (trigger the alarm handler)
            if ($main::mock_simulate_timeout) {
                die "Simulated timeout";
            }

            # Determine which output to use based on query type
            my $output = '';
            if ( grep { $_ eq 'A' } @cmd ) {
                $output = $main::mock_a_output;
            }
            elsif ( grep { $_ eq 'TXT' } @cmd ) {
                $output = $main::mock_txt_output;
            }

            # Create in-memory filehandles for mock
            # childin needs to be writable (even though we'll close it)
            my $childin_content = '';
            open my $mock_childin, '>', \$childin_content or die "Cannot open mock childin: $!";

            # childout provides our mock output
            open my $mock_childout, '<', \$output or die "Cannot open mock childout: $!";

            $_[0] = $mock_childin;     # Set childin
            $_[1] = $mock_childout;    # Set childout

            return 12345;              # Fake PID
        },
    ],
);

subtest 'Public API exists' => sub {
    can_ok( 'ConfigServer::RBLLookup', 'rbllookup' );
};

subtest 'Invalid IP returns empty strings without DNS query' => sub {
    reset_test_state();
    $mock_checkip_result = 0;    # checkip fails

    my ( $hit, $txt ) = ConfigServer::RBLLookup::rbllookup( 'not-an-ip', 'zen.spamhaus.org' );

    is( $hit,                '',    'rblhit is empty string for invalid IP' );
    is( $txt,                undef, 'rblhittxt is undef for invalid IP' );
    is( scalar @open3_calls, 0,     'No DNS queries made for invalid IP' );
};

subtest 'Valid IPv4 address triggers DNS lookup' => sub {
    reset_test_state();
    $mock_checkip_result = 1;
    $mock_a_output       = '';    # Not listed

    my ( $hit, $txt ) = ConfigServer::RBLLookup::rbllookup( '192.0.2.1', 'zen.spamhaus.org' );

    ok( scalar @open3_calls >= 1, 'DNS query made for valid IPv4' );

    # Verify the lookup used reversed IP format
    my $cmd_str = join ' ', @{ $open3_calls[0] || [] };
    like( $cmd_str, qr/1\.2\.0\.192\.zen\.spamhaus\.org/, 'IPv4 reversed correctly in query' );
};

subtest 'RBL hit returns IP and TXT record' => sub {
    reset_test_state();
    $mock_checkip_result = 1;

    # Mock A record response (IP is listed)
    $mock_a_output = "1.2.0.192.zen.spamhaus.org has address 127.0.0.2\n";

    # Mock TXT record response
    $mock_txt_output = "1.2.0.192.zen.spamhaus.org descriptive text \"Listed for spam activity\"\n";

    my ( $hit, $txt ) = ConfigServer::RBLLookup::rbllookup( '192.0.2.1', 'zen.spamhaus.org' );

    is( $hit, '127.0.0.2', 'rblhit contains RBL response IP' );
    like( $txt, qr/Listed for spam activity/, 'rblhittxt contains TXT record text' );
    is( scalar @open3_calls, 2, 'Both A and TXT queries made' );
};

subtest 'RBL not listed returns empty strings' => sub {
    reset_test_state();
    $mock_checkip_result = 1;

    # Mock empty A record response (not listed)
    $mock_a_output = "Host 1.2.0.192.zen.spamhaus.org not found: 3(NXDOMAIN)\n";

    my ( $hit, $txt ) = ConfigServer::RBLLookup::rbllookup( '192.0.2.1', 'zen.spamhaus.org' );

    is( $hit,                '',    'rblhit is empty string when not listed' );
    is( $txt,                undef, 'rblhittxt is undef when not listed' );
    is( scalar @open3_calls, 1,     'Only A query made (no TXT query when not listed)' );
};

subtest 'RBL hit without TXT record returns hit with empty txt' => sub {
    reset_test_state();
    $mock_checkip_result = 1;

    # Mock A record response (IP is listed)
    $mock_a_output = "1.2.0.192.zen.spamhaus.org has address 127.0.0.3\n";

    # Mock empty TXT response
    $mock_txt_output = "Host 1.2.0.192.zen.spamhaus.org not found: 3(NXDOMAIN)\n";

    my ( $hit, $txt ) = ConfigServer::RBLLookup::rbllookup( '192.0.2.1', 'zen.spamhaus.org' );

    is( $hit, '127.0.0.3', 'rblhit contains response IP' );
    is( $txt, undef,       'rblhittxt is undef when no TXT record' );
};

subtest 'HOST config value is used for command' => sub {
    reset_test_state();
    $mock_checkip_result = 1;
    $mock_a_output       = '';

    set_config( HOST => '/custom/path/host' );

    my ( $hit, $txt ) = ConfigServer::RBLLookup::rbllookup( '192.0.2.1', 'zen.spamhaus.org' );

    ok( scalar @open3_calls >= 1, 'DNS query made' );
    is( $open3_calls[0]->[0], '/custom/path/host', 'Uses HOST config for command' );

    # Reset to default
    set_config( HOST => '/usr/bin/host' );
};

subtest 'Different RBL domains are used correctly' => sub {
    reset_test_state();
    $mock_checkip_result = 1;
    $mock_a_output       = '';

    my ( $hit, $txt ) = ConfigServer::RBLLookup::rbllookup( '10.0.0.1', 'bl.spamcop.net' );

    ok( scalar @open3_calls >= 1, 'DNS query made' );
    my $cmd_str = join ' ', @{ $open3_calls[0] || [] };
    like( $cmd_str, qr/1\.0\.0\.10\.bl\.spamcop\.net/, 'Uses correct RBL domain in query' );
};

subtest 'Valid IPv6 address triggers DNS lookup with correct reversal' => sub {
    reset_test_state();
    $mock_checkip_result = 1;
    $mock_a_output       = '';

    # Test with IPv6 address - Net::IP will reverse it properly
    my ( $hit, $txt ) = ConfigServer::RBLLookup::rbllookup( '2001:db8::1', 'zen.spamhaus.org' );

    ok( scalar @open3_calls >= 1, 'DNS query made for valid IPv6' );

    # Verify the lookup used reversed IPv6 format (nibble format)
    my $cmd_str = join ' ', @{ $open3_calls[0] || [] };

    # IPv6 reversal creates nibble format: each hex digit reversed with dots
    like( $cmd_str, qr/\.zen\.spamhaus\.org/, 'IPv6 lookup includes RBL domain' );

    # The reversed format for 2001:db8::1 should contain the nibbles
    like( $cmd_str, qr/1\.0\.0\.0\.0\.0\.0\.0\.0\.0\.0\.0\.0\.0\.0\.0\.0\.0\.0\.0\.0\.0\.0\.0\.8\.b\.d\.0\.1\.0\.0\.2/, 'IPv6 reversed correctly in nibble format' );
};

subtest 'IPv6 RBL hit returns IP and TXT record' => sub {
    reset_test_state();
    $mock_checkip_result = 1;

    # Mock A record response for IPv6 (IP is listed)
    $mock_a_output = "1.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.8.b.d.0.1.0.0.2.zen.spamhaus.org has address 127.0.0.2\n";

    # Mock TXT record response
    $mock_txt_output = "1.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.8.b.d.0.1.0.0.2.zen.spamhaus.org descriptive text \"Listed for spam activity\"\n";

    my ( $hit, $txt ) = ConfigServer::RBLLookup::rbllookup( '2001:db8::1', 'zen.spamhaus.org' );

    is( $hit, '127.0.0.2', 'rblhit contains RBL response IP for IPv6' );
    like( $txt, qr/Listed for spam activity/, 'rblhittxt contains TXT record text for IPv6' );
    is( scalar @open3_calls, 2, 'Both A and TXT queries made for IPv6' );
};

subtest 'Timeout returns timeout string' => sub {
    reset_test_state();
    $mock_checkip_result   = 1;
    $mock_simulate_timeout = 1;

    my ( $hit, $txt ) = ConfigServer::RBLLookup::rbllookup( '192.0.2.1', 'zen.spamhaus.org' );

    is( $hit, 'timeout', 'rblhit is "timeout" when DNS query times out' );

    # When timeout occurs, TXT is not fetched
    is( $txt, undef, 'rblhittxt is undef on timeout' );
};

done_testing();

# Helper to reset test state
sub reset_test_state {
    @main::open3_calls           = ();
    $main::mock_a_output         = '';
    $main::mock_txt_output       = '';
    $main::mock_checkip_result   = 1;
    $main::mock_simulate_timeout = 0;
    return;
}
