# Quickstart: Modernize ServerStats.pm

**Feature**: 006-modernize-serverstats  
**Date**: 2026-01-28

## Prerequisites

- Perl 5.36+ (cPanel-provided)
- GD::Graph modules (bars, pie, lines) installed
- Test2::V0 test framework

## Quick Verification

```bash
# Check module compiles after changes
perl -cw -Ilib lib/ConfigServer/ServerStats.pm

# Run unit tests
prove -wlvm t/ConfigServer-ServerStats.t

# Check POD documentation
podchecker lib/ConfigServer/ServerStats.pm
perldoc lib/ConfigServer/ServerStats.pm
```

## Module Public API

After modernization, the public API is:

```perl
use ConfigServer::ServerStats ();

# Generate system graphs (CPU, memory, load, network, disk, mail, mysql, apache)
ConfigServer::ServerStats::graphs($type, $system_maxdays, $imghddir);

# Generate block/allow charts
ConfigServer::ServerStats::charts($cc_lookups, $imgdir);

# Get HTML to display system graphs
my $html = ConfigServer::ServerStats::graphs_html($imgdir);

# Get HTML to display charts
my $html = ConfigServer::ServerStats::charts_html($cc_lookups, $imgdir);
```

**Removed**: `init()` - no longer needed, modules loaded at compile time

## Test Isolation

For testing, use the package variables:

```perl
# Override stats file path
local $ConfigServer::ServerStats::STATS_FILE = '/tmp/test_stats';

# Clear accumulated stats between tests
ConfigServer::ServerStats::_reset_stats();
```

## File Locations

| File | Purpose |
|------|---------|
| `lib/ConfigServer/ServerStats.pm` | Module being modernized |
| `t/ConfigServer-ServerStats.t` | Unit tests |
| `/var/lib/csf/stats/system` | Default stats data file |

## Key Changes Summary

1. **Imports**: Use `cPstrict`, disabled imports, fully qualified names
2. **GD::Graph**: Compile-time loading, remove init()
3. **State**: Add `_reset_stats()` for test isolation
4. **Path**: Add `$STATS_FILE` for testability
5. **Comments**: Remove legacy `# start`/`# end` markers
6. **Docs**: Add POD documentation for public functions
7. **Tests**: Add comprehensive unit tests
