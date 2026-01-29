# Data Model: Modernize ServerCheck.pm Module

**Feature**: [010-modernize-servercheck](spec.md) | **Phase**: 1 - Design | **Date**: 2026-01-29

## Overview

ConfigServer::ServerCheck provides a comprehensive security audit report for cPanel/DirectAdmin servers. This document describes the module's data structures and state management **post-modernization**. The focus is on lazy-loading changes; the extensive report generation logic remains unchanged.

## State Variables

### Package-Level Variables (Unchanged)

The module maintains several package-level variables for internal state:

```perl
my (
    %config,     # CSF configuration hash
    $cpconf,     # cPanel configuration reference
    %daconfig,   # DirectAdmin configuration hash
    $cleanreg,   # Cleaned regex pattern
    $mypid,      # Current process ID
    $childin,    # Child process input filehandle
    $childout,   # Child process output filehandle
    $verbose,    # Verbosity flag (from report() parameter)
    $cpurl,      # cPanel URL
    @processes,  # Process list
    $total,      # Total check count
    $failures,   # Failed check count
    $current,    # Current check number
    $DEBIAN,     # Debian OS flag
    $output,     # HTML output accumulator
    $sysinit,    # Init system type (systemd/init)
    %g_ifaces,   # Global network interfaces hash
    %g_ipv4,     # Global IPv4 addresses hash
    %g_ipv6      # Global IPv6 addresses hash
);
```

**Rationale**: These variables are used throughout the 1887-line report() function. Refactoring them to parameters would require extensive function decomposition which is out of scope.

### Lazy-Loaded State Variables (NEW)

**Location**: Inside report() function  
**Purpose**: Defer ConfigServer::Config method calls from compile time to runtime

```perl
sub report {
    my ($verbose_param) = @_;
    
    # Lazy-load regex patterns on first call (cached for subsequent calls)
    state $ipv4reg = ConfigServer::Config->ipv4reg;
    state $ipv6reg = ConfigServer::Config->ipv6reg;
    
    # ... rest of function uses $ipv4reg and $ipv6reg for validation
}
```

**Behavior**:
- **First call**: State variables are initialized, Config methods invoked
- **Subsequent calls**: State variables retain their values, no Config method calls
- **Thread safety**: Not applicable (CSF runs in single-threaded context)

**Migration from Package-Level**:

| Before (Compile Time) | After (Lazy Runtime) |
|----------------------|---------------------|
| `my $ipv4reg = ConfigServer::Config->ipv4reg;` (line 97) | `state $ipv4reg = ConfigServer::Config->ipv4reg;` (inside report) |
| `my $ipv6reg = ConfigServer::Config->ipv6reg;` (line 98) | `state $ipv6reg = ConfigServer::Config->ipv6reg;` (inside report) |

## Module Imports (POST-MODERNIZATION)

### Before Modernization

```perl
use Fcntl qw(:DEFAULT :flock);          # Imports constants into namespace
use File::Basename;                      # Imports basename(), dirname()
use IPC::Open3;                          # Imports open3()
use ConfigServer::Slurp  qw(slurp);     # Imports slurp()
use ConfigServer::Sanity qw(sanity);    # Imports sanity()
use ConfigServer::GetIPs  qw(getips);   # Imports getips()
use ConfigServer::CheckIP qw(checkip);  # Imports checkip()
```

### After Modernization

```perl
use Fcntl ();                           # No imports - use Fcntl::LOCK_SH()
use File::Basename ();                  # No imports - use File::Basename::basename()
use IPC::Open3 ();                      # No imports - use IPC::Open3::open3()
use ConfigServer::Slurp ();             # No imports - use ConfigServer::Slurp::slurp()
use ConfigServer::Sanity ();            # No imports - use ConfigServer::Sanity::sanity()
use ConfigServer::GetIPs ();            # No imports - use ConfigServer::GetIPs::getips()
use ConfigServer::CheckIP ();           # No imports - use ConfigServer::CheckIP::checkip()
```

**Already Correct** (no changes needed):
```perl
use cPstrict;                           # cPanel strict/warnings
use Carp ();                            # Already disabled
use ConfigServer::Config;               # No imports (class methods only)
use ConfigServer::Service;              # No imports (class methods only)
use ConfigServer::GetEthDev;            # No imports (class methods only)
use ConfigServer::Messenger ();         # Already disabled
use Cpanel::Config ();                  # Already disabled
```

## Function Call Updates

### Fcntl Constants

**Pattern**: `CONSTANT` → `Fcntl::CONSTANT()`

Expected updates (actual count to be determined):
```perl
# File locking
LOCK_SH  → Fcntl::LOCK_SH()
LOCK_EX  → Fcntl::LOCK_EX()
LOCK_UN  → Fcntl::LOCK_UN()
LOCK_NB  → Fcntl::LOCK_NB()

# File operations
O_RDONLY → Fcntl::O_RDONLY()
O_WRONLY → Fcntl::O_WRONLY()
O_RDWR   → Fcntl::O_RDWR()
O_CREAT  → Fcntl::O_CREAT()
O_APPEND → Fcntl::O_APPEND()
O_TRUNC  → Fcntl::O_TRUNC()
O_EXCL   → Fcntl::O_EXCL()
```

### File::Basename Functions

**Pattern**: `function($path)` → `File::Basename::function($path)`

Expected updates:
```perl
basename($file)  → File::Basename::basename($file)
dirname($path)   → File::Basename::dirname($path)
```

### IPC::Open3 Function

**Pattern**: `open3(...)` → `IPC::Open3::open3(...)`

Expected updates:
```perl
open3($in, $out, $err, @cmd) → IPC::Open3::open3($in, $out, $err, @cmd)
```

### ConfigServer Module Functions

**Pattern**: `function(...)` → `ConfigServer::Module::function(...)`

Expected updates (counts to be verified during implementation):
```perl
# ConfigServer::Slurp (~20-30 occurrences estimated)
slurp($file) → ConfigServer::Slurp::slurp($file)

# ConfigServer::Sanity (~5-10 occurrences estimated)
sanity($name, $value) → ConfigServer::Sanity::sanity($name, $value)

# ConfigServer::GetIPs (~10-15 occurrences estimated)
getips() → ConfigServer::GetIPs::getips()

# ConfigServer::CheckIP (~5-10 occurrences estimated)
checkip($ip) → ConfigServer::CheckIP::checkip($ip)
```

## Report Output Data Structure

**Type**: HTML string  
**Format**: Comprehensive security audit report with multiple sections

**Structure** (unchanged by modernization):
```html
<html>
<head>
  <title>Server Check</title>
  <style>...</style>
</head>
<body>
  <h1>Server Security Audit</h1>
  
  <!-- Check categories -->
  <section class="firewall">...</section>
  <section class="server">...</section>
  <section class="whm">...</section>
  <section class="mail">...</section>
  <section class="php">...</section>
  <section class="apache">...</section>
  <section class="ssh">...</section>
  <section class="services">...</section>
  
  <!-- Summary -->
  <div class="summary">
    Total checks: X
    Failures: Y
  </div>
</body>
</html>
```

**Verbosity Control**:
- `report(0)` or `report()`: Shows only failed checks (default)
- `report(1)`: Shows all checks including passed ones

## Configuration Access Pattern

**Pattern**: Module accesses multiple configuration sources

```perl
# CSF configuration (loaded within report())
my %config;  # Populated by ConfigServer::Config->loadconfig()

# cPanel configuration (if applicable)
my $cpconf = Cpanel::Config::loadcpconf();

# DirectAdmin configuration (if applicable)
my %daconfig;  # Populated from DirectAdmin config files
```

**Modernization Impact**: None - configuration loading already happens within report() function, not at package level. Only the regex patterns (ipv4reg, ipv6reg) are being moved from package-level to lazy-load.

## File Access Patterns

**Pattern**: Multiple file reads for security checks

Common file operations (unchanged by modernization):
```perl
# Example file access patterns
ConfigServer::Slurp::slurp("/etc/ssh/sshd_config")
ConfigServer::Slurp::slurp("/etc/csf/csf.conf")
ConfigServer::Slurp::slurp("/usr/local/apache/conf/httpd.conf")
```

All file access uses ConfigServer::Slurp which provides error handling.

## Validation Patterns

**IP Address Validation**:
```perl
# Using lazy-loaded regex patterns
if ($ip =~ /^$ipv4reg$/) {
    # Valid IPv4
}
if ($ip =~ /^$ipv6reg$/) {
    # Valid IPv6
}
```

**Configuration Validation**:
```perl
# Using ConfigServer::Sanity
my $valid = ConfigServer::Sanity::sanity($param_name, $param_value);
```

## Summary of Changes

| Component | Before | After | Impact |
|-----------|--------|-------|--------|
| Package-level vars | 2 assignments (ipv4reg, ipv6reg) | 0 assignments | Eliminates compile-time Config method calls |
| State vars in report() | 0 | 2 (ipv4reg, ipv6reg) | Lazy initialization on first call |
| qw() imports | 7 modules | 0 modules | All imports disabled |
| Qualified calls | ~0 (used imports) | ~50-100+ | All calls fully qualified |
| use lib | 1 hardcoded path | 0 | Uses standard @INC |
| report() logic | Complex audit | Unchanged | No refactoring |

**Validation Strategy**:
1. Module compiles: `perl -cw -Ilib lib/ConfigServer/ServerCheck.pm`
2. Test loading: Verify no Config method calls at load time
3. Test lazy init: Verify Config methods called on first report() invocation
4. Functional test: Manual comparison of HTML output before/after modernization
