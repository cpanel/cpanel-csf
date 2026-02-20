#!/usr/local/cpanel/3rdparty/bin/perl

use lib 't/lib';
use FindBin::libs;

use cPstrict;

use Test2::V0;
use Test2::Tools::Explain;
use Test2::Plugin::NoWarnings;

use MockConfig;

# Load the module under test FIRST
use ConfigServer::ServerStats ();

subtest 'Module compilation and version' => sub {
    ok( defined $ConfigServer::ServerStats::VERSION, '$VERSION is defined' );
    like( $ConfigServer::ServerStats::VERSION, qr/^\d+\.\d+$/, '$VERSION has correct format' );
};

subtest 'Package variable $STATS_FILE exists and is configurable' => sub {
    ok( defined $ConfigServer::ServerStats::STATS_FILE, '$STATS_FILE is defined' );
    is( $ConfigServer::ServerStats::STATS_FILE, '/var/lib/csf/stats/system', '$STATS_FILE has default value' );

    # Test that it can be overridden for test isolation
    local $ConfigServer::ServerStats::STATS_FILE = '/tmp/test_stats';
    is( $ConfigServer::ServerStats::STATS_FILE, '/tmp/test_stats', '$STATS_FILE can be locally overridden' );
};

subtest 'Public API functions exist' => sub {
    can_ok( 'ConfigServer::ServerStats', 'graphs' );
    can_ok( 'ConfigServer::ServerStats', 'charts' );
    can_ok( 'ConfigServer::ServerStats', 'graphs_html' );
    can_ok( 'ConfigServer::ServerStats', 'charts_html' );
};

# Note: Private helpers (_minmaxavg, _reset_stats) are exercised via public API tests.
# We avoid testing their existence directly to prevent brittle tests tied to internals.

subtest '_reset_stats() clears internal state' => sub {

    # Start from a clean state
    ConfigServer::ServerStats::_reset_stats();

    # Populate some state in a rendered bucket (e.g. HOUR) using a distinctive value
    ConfigServer::ServerStats::_minmaxavg( 'HOUR', 'cpu', 987 );

    # Verify state is reflected in graphs_html output before reset.
    # Use the formatted Min: HTML fragment rather than the bare number to avoid
    # false matches against the Unix timestamp embedded in the img ?text= URL.
    my $html_before = ConfigServer::ServerStats::graphs_html('/images/');
    like( $html_before, qr/Min:<b>987\.00<\/b>/, 'Before _reset_stats(), graphs_html() includes populated metric' );

    # Now reset and verify the metric is no longer present
    ConfigServer::ServerStats::_reset_stats();
    my $html_after = ConfigServer::ServerStats::graphs_html('/images/');
    unlike( $html_after, qr/Min:<b>987\.00<\/b>/, 'After _reset_stats(), populated metric is cleared from graphs_html() output' );
};

subtest 'graphs_html() returns HTML structure' => sub {
    ConfigServer::ServerStats::_reset_stats();

    my $html = ConfigServer::ServerStats::graphs_html('/images/stats/');

    ok( defined $html, 'graphs_html() returns defined value' );
    like( $html, qr/<table/,               'Output contains table element' );
    like( $html, qr/lfd_systemhour\.gif/,  'Output references hour graph' );
    like( $html, qr/lfd_systemday\.gif/,   'Output references day graph' );
    like( $html, qr/lfd_systemweek\.gif/,  'Output references week graph' );
    like( $html, qr/lfd_systemmonth\.gif/, 'Output references month graph' );
    like( $html, qr{/images/stats/},       'Output includes provided image directory' );
};

subtest 'charts_html() returns HTML structure' => sub {
    my $html = ConfigServer::ServerStats::charts_html( 0, '/images/stats/' );

    ok( defined $html, 'charts_html() returns defined value' );
    like( $html, qr/<table/,         'Output contains table element' );
    like( $html, qr/lfd_hour\.gif/,  'Output references hour chart' );
    like( $html, qr/lfd_month\.gif/, 'Output references month chart' );
    like( $html, qr{/images/stats/}, 'Output includes provided image directory' );
};

subtest 'charts_html() with cc_lookups includes country charts' => sub {
    my $html = ConfigServer::ServerStats::charts_html( 1, '/images/' );

    ok( defined $html, 'charts_html() with cc_lookups returns defined value' );
    like( $html, qr/lfd_cc\.gif/, 'Output includes country code chart when cc_lookups enabled' );
};

subtest 'charts_html() without cc_lookups excludes country charts' => sub {
    my $html = ConfigServer::ServerStats::charts_html( 0, '/images/' );

    ok( defined $html, 'charts_html() without cc_lookups returns defined value' );
    unlike( $html, qr/lfd_cc\.gif/, 'Output excludes country code chart when cc_lookups disabled' );
};

subtest '_minmaxavg() tracks min/max/avg correctly' => sub {
    ConfigServer::ServerStats::_reset_stats();

    # Add values
    ConfigServer::ServerStats::_minmaxavg( 'HOUR', 'testmetric', 10 );
    ConfigServer::ServerStats::_minmaxavg( 'HOUR', 'testmetric', 20 );
    ConfigServer::ServerStats::_minmaxavg( 'HOUR', 'testmetric', 30 );

    # Check that graphs_html includes testmetric data
    my $html = ConfigServer::ServerStats::graphs_html('/img/');

    # The HTML should contain the testmetric with Min, Max, Avg values
    like( $html, qr/testmetric/,         'graphs_html output includes test metric' );
    like( $html, qr/Min:<b>10\.00<\/b>/, 'Min value is tracked correctly' );
    like( $html, qr/Max:<b>30\.00<\/b>/, 'Max value is tracked correctly' );
    like( $html, qr/Avg:<b>60\.00<\/b>/, 'Avg value is the accumulated sum in this test path' );

    # Note: In this test we call _minmaxavg() directly and then graphs_html(),
    # so the AVG stored in %minmaxavg is the accumulated sum (10+20+30 == 60),
    # and graphs_html() prints that value without dividing by CNT.

    # Clean up
    ConfigServer::ServerStats::_reset_stats();
};

done_testing;
