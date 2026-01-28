# Research: Modernize ServerStats.pm

**Feature**: 006-modernize-serverstats  
**Date**: 2026-01-28  
**Status**: Complete

## Research Tasks

### 1. GD::Graph Module Loading Strategy

**Question**: How should the string eval loading of GD::Graph modules be modernized?

**Decision**: Use compile-time `use` statements with disabled imports

**Rationale**: 
- cPanel environment always provides GD::Graph modules
- Compile-time loading is cleaner and fails fast if dependencies missing
- No need for `init()` function to check availability
- Disabled imports (`use Module ();`) per constitution III

**Implementation**:
```perl
# Before (dynamic loading):
sub init {
    eval('use GD::Graph::bars;');
    if ($@) { return undef }
    eval('use GD::Graph::pie;');
    if ($@) { return undef }
    eval('use GD::Graph::lines;');
    if ($@) { return undef }
}

# After (compile-time):
use GD::Graph::bars  ();
use GD::Graph::pie   ();
use GD::Graph::lines ();
# init() function removed entirely
```

**Alternatives Considered**:
- Keep `init()` with block eval → Rejected: cPanel always provides these modules
- Use Module::Load → Rejected: unnecessary complexity for guaranteed modules

### 2. Package-Level %minmaxavg State Management

**Question**: How to handle the package-level `%minmaxavg` global variable for testability?

**Decision**: Keep as internal package state with `_reset_stats()` private function

**Rationale**:
- Changing the signature of public functions would break backward compatibility
- `%minmaxavg` is accumulated during `graphs()` calls and consumed by `graphs_html()`
- A reset function allows tests to clear state between test cases
- The underscore prefix marks it as internal testing aid

**Implementation**:
```perl
# Package-level state (unchanged in structure)
my %minmaxavg;

# New private function for test isolation
sub _reset_stats {
    %minmaxavg = ();
    return;
}
```

**Alternatives Considered**:
- Pass hash reference through functions → Rejected: breaks API compatibility
- Object-oriented refactor → Rejected: too invasive for modernization scope
- Remove global entirely → Rejected: required for graphs_html() to work

### 3. Stats File Path Testability

**Question**: How to make `/var/lib/csf/stats/system` path testable?

**Decision**: Add `our $STATS_FILE` package variable that tests can localize

**Rationale**:
- Minimal code change - replace hardcoded path with variable
- Tests can use `local $ConfigServer::ServerStats::STATS_FILE = '/tmp/test_stats';`
- No API changes required

**Implementation**:
```perl
# Package-level configurable path
our $STATS_FILE = '/var/lib/csf/stats/system';

# Usage in graphs() and charts():
sysopen( my $STATS, $STATS_FILE, O_RDWR | O_CREAT );
```

### 4. Fcntl Import Strategy

**Question**: How should Fcntl imports be modernized?

**Decision**: Use disabled import with fully qualified constant access

**Findings**:
- Module uses `O_RDWR`, `O_CREAT` (for sysopen)
- Module uses `LOCK_SH`, `LOCK_EX` (for flock)
- These must be accessed with fully qualified names per constitution III

**Implementation**:
```perl
# Before:
use Fcntl qw(:DEFAULT :flock);
sysopen( my $STATS, "/var/lib/csf/stats/system", O_RDWR | O_CREAT );
flock( $STATS, LOCK_SH );

# After:
use Fcntl ();
sysopen( my $STATS, $STATS_FILE, Fcntl::O_RDWR() | Fcntl::O_CREAT() );
flock( $STATS, Fcntl::LOCK_SH() );
```

### 5. init() Function Removal Impact

**Question**: What callers use `init()` and how will removal affect them?

**Decision**: Safe to remove - callers should just call `graphs()` directly

**Findings**:
- Searched codebase for `ServerStats::init` and `ServerStats->init`
- Found in cpanel/csf.cgi which calls init() before graphs()
- After modernization, init() return value check becomes unnecessary
- Callers should be updated to remove init() check

**Caller Update Required**:
```perl
# Before:
if (ConfigServer::ServerStats::init()) {
    ConfigServer::ServerStats::graphs($type, $maxdays, $dir);
}

# After (init check removed):
ConfigServer::ServerStats::graphs($type, $maxdays, $dir);
```

### 6. GD::Graph Method Mocking for Tests

**Question**: How to test graphs() and charts() without actual GD::Graph rendering?

**Decision**: Mock GD::Graph classes using Test2::Mock

**Rationale**:
- Tests need to verify correct GD::Graph method calls
- Actual image generation not needed for unit tests
- Mock can track calls and return dummy objects

**Implementation Pattern**:
```perl
# Mock GD::Graph::lines to track calls
our @graph_calls;
our $mock_gd_object;

my $lines_mock = mock 'GD::Graph::lines' => (
    override => [
        new => sub {
            my ($class, $width, $height) = @_;
            push @main::graph_calls, { type => 'lines', width => $width, height => $height };
            return bless {}, $class;
        },
        set => sub { return 1; },
        set_legend => sub { return 1; },
        plot => sub { return 1; },
        gd => sub { 
            return bless { 
                gif => sub { return 'GIF_DATA'; }
            }, 'GD::Image';
        },
    ],
);
```

### 7. graphs_html() and charts_html() Testing

**Question**: How to test HTML generation functions?

**Decision**: Test directly since they don't require external dependencies

**Rationale**:
- These functions only read from `%minmaxavg` state and format HTML
- Can pre-populate `%minmaxavg` using direct hash assignment in tests
- Verify HTML structure with regex or string matching

**Implementation Pattern**:
```perl
subtest 'graphs_html generates valid HTML' => sub {
    # Pre-populate stats (via internal access for testing)
    %ConfigServer::ServerStats::minmaxavg = (
        HOUR => {
            '1Idle' => { MIN => 10, MAX => 90, AVG => 50 },
        },
    );
    
    my $html = ConfigServer::ServerStats::graphs_html('/images/');
    
    like($html, qr/<table class='table/, 'Contains table markup');
    like($html, qr/lfd_systemhour\.gif/, 'References hour graph');
};
```

**Note**: Direct access to `%minmaxavg` for test setup is acceptable since we're testing internal behavior. Production code should not access it directly.

### 8. Legacy Comment Pattern for Removal

**Question**: What is the exact pattern of legacy comments to remove?

**Decision**: Remove all structural comments between subroutines

**Findings from grep analysis**:
```
Line 1:  ###############################################################################  (KEEP - copyright header start)
Line 18: ###############################################################################  (KEEP - copyright header end)
Line 20: # start main                                                                    (REMOVE)
Line 34: # end main                                                                      (REMOVE)
Line 35: ###############################################################################  (REMOVE)
Line 36: # start init                                                                    (REMOVE)
...and so on for each subroutine
```

**Removal Pattern**:
- Delete all lines matching `^# start ` and `^# end `
- Delete all lines matching `^###############################################################################$` EXCEPT lines 1 and 18
- Delete the `## no critic` line at line 19

## Summary

All research tasks completed. Key decisions:
1. Compile-time GD::Graph loading, remove init()
2. Keep %minmaxavg internal with _reset_stats() for testing
3. $STATS_FILE package variable for path testability
4. Disabled Fcntl import with fully qualified constants
5. Update callers to remove init() checks
6. Mock GD::Graph for unit tests
7. Test HTML functions by pre-populating state
8. Remove legacy structural comments (except copyright header)
