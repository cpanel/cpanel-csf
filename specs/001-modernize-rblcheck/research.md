# Research: Modernize RBLCheck.pm

**Date**: 2026-01-22  
**Plan**: [plan.md](plan.md)

## Purpose

Resolve technical questions and establish patterns before implementation.

---

## R1: CloudFlare.pm Modernization Pattern Analysis

**Task**: Analyze commit 7bd732d to extract the modernization pattern for reuse.

### Findings

The CloudFlare.pm modernization established the following pattern:

1. **Module Header Structure**:
   ```perl
   package ConfigServer::CloudFlare;
   
   =head1 NAME ... =cut   # POD immediately after package
   
   use cPstrict;          # Instead of use strict; use warnings;
   
   use Fcntl            ();  # Disabled imports for non-ConfigServer modules
   use Cpanel::JSON::XS ();
   # ... more disabled imports
   
   use ConfigServer::Config;     # ConfigServer modules keep imports
   use ConfigServer::CheckIP qw(checkip);
   ```

2. **Global Variable Removal**:
   - Removed: `my %config = ...` at package level
   - Replaced with: `my $config = ConfigServer::Config->loadconfig();` inside functions
   - For single values: `ConfigServer::Config->get_config('KEY')`

3. **Private Function Convention**:
   - Internal functions prefixed with `_` (e.g., `_cloudflare`, `_urlget`)
   - All internal callers updated to use new names
   - Public functions remain without prefix

4. **Exporter Removal**:
   - Removed: `use Exporter qw(import);`
   - Removed: `our @ISA = qw(Exporter);`
   - Removed: `our @EXPORT_OK = qw();`
   - Only `$VERSION` retained as package variable

5. **Perl 4 Call Removal**:
   - Changed: `&functionname` → `functionname()`
   - Changed: `&functionname($arg)` → `functionname($arg)`

### Decision

Apply identical pattern to RBLCheck.pm.

---

## R2: RBLCheck.pm Current State Analysis

**Task**: Identify all items requiring modification.

### Findings

**Package-level globals (line 40-45)**:
```perl
my ($ui, $failures, $verbose, $cleanreg, $status, %ips, $images, %config, $ipresult, $output);
my $ipv4reg = ConfigServer::Config->ipv4reg;
my $ipv6reg = ConfigServer::Config->ipv6reg;
```

**Issues**:
- `$ipv4reg` and `$ipv6reg` called at module load time (violates Constitution IV)
- Multiple globals shared across functions via package scope
- Neither `$ipv4reg` nor `$ipv6reg` are used anywhere in the module!

**Imports requiring modification**:
| Import | Current | Required |
|--------|---------|----------|
| `Fcntl` | `use Fcntl qw(:DEFAULT :flock);` | `use Fcntl ();` + qualified constants |
| `IPC::Open3` | `use IPC::Open3;` | Remove entirely (unused) |
| `ConfigServer::*` | Various with exports | Keep as-is per clarification |

**Perl 4 function calls** (must convert):
- Line 59: `&startoutput` → `_startoutput()`
- Line 61: `&getethdev` → `_getethdev()`
- Line 121: `&addtitle(...)` → `_addtitle(...)`
- Line 134, 137, 140: `&addline(...)` → `_addline(...)`
- Line 157, 162: `&addtitle(...)` → `_addtitle(...)`
- Line 176: `&endoutput` → `_endoutput()`

**Internal functions to make private**:
| Current | New Name | Lines |
|---------|----------|-------|
| `startoutput` | `_startoutput` | 184-186 |
| `addline` | `_addline` | 190-213 |
| `addtitle` | `_addtitle` | 217-228 |
| `endoutput` | `_endoutput` | 232-237 |
| `getethdev` | `_getethdev` | 241-258 |

**Exporter to remove**:
```perl
use Exporter qw(import);     # Line 34
our @ISA       = qw(Exporter);  # Line 36
our @EXPORT_OK = qw();          # Line 37
```

**File operations using Fcntl constants** (line 152-153):
```perl
sysopen( my $OUT, "/var/lib/csf/${ip}.rbls", O_WRONLY | O_CREAT );
flock( $OUT, LOCK_EX );
```
Must become:
```perl
sysopen( my $OUT, "/var/lib/csf/${ip}.rbls", Fcntl::O_WRONLY | Fcntl::O_CREAT );
flock( $OUT, Fcntl::LOCK_EX );
```

### Decision

All issues documented and ready for implementation.

---

## R3: Config Access Pattern Analysis

**Task**: Determine optimal config access strategy for `report()`.

### Findings

Config values accessed in `report()`:
- `%config` assigned from `ConfigServer::Config->loadconfig()` (line 53)
- Used: Only for commented-out IPv6 code (`$config{IPV6}`)

**Analysis**: The `%config` hash is populated but only referenced in commented-out code. However, the pattern should remain in place for future use.

### Decision

- Keep `ConfigServer::Config->loadconfig()` call in `report()` (already correct location)
- Remove package-level `%config` declaration
- Declare `%config` as lexical within `report()` function

---

## R4: Global Variable Persistence Analysis

**Task**: Determine which globals need function-scope vs persistence.

### Findings

| Variable | Used In | Persistence Needed | Decision |
|----------|---------|-------------------|----------|
| `$ui` | `report`, `addline`, `addtitle`, `endoutput` | Within single `report()` call | Pass as parameter or use closure |
| `$failures` | `report`, `addline` | Accumulator within `report()` | Pass by reference or return |
| `$verbose` | `report`, `addline` | Within single call | Pass as parameter |
| `$cleanreg` | `report` only | Single call | Local variable |
| `%ips` | `report`, `getethdev` | Populated by `getethdev`, used by `report` | Pass by reference |
| `$images` | `report` only | Single call | Local variable |
| `$ipresult` | `report`, `addline`, `addtitle` | Accumulator within `report()` | Pass by reference |
| `$output` | `report`, `addline`, `addtitle`, `endoutput` | Accumulator within `report()` | Pass by reference |
| `$ipv4reg` | Not used | N/A | Remove |
| `$ipv6reg` | Not used | N/A | Remove |

**Approach**: Per clarification, "leave the rest defined that way" - keep globals for shared state but remove unused `$ipv4reg`/`$ipv6reg`.

### Decision

- Remove `$ipv4reg` and `$ipv6reg` (unused)
- Keep other globals as package-level (shared state pattern acceptable per clarification)

---

## R5: MockConfig Integration for Testing

**Task**: Verify MockConfig pattern for RBLCheck tests.

### Findings

Existing MockConfig usage pattern from other tests:
```perl
use lib 't/lib';
use MockConfig;

MockConfig->setup(
    'CF_ENABLE' => '1',
    'CF_APIKEY' => 'test-key',
);
```

For RBLCheck tests, need to mock:
- `ConfigServer::Config->loadconfig()` return value
- `ConfigServer::GetEthDev->new()` (returns IP addresses)
- `ConfigServer::RBLLookup::rbllookup()` (DNS lookups)
- File system operations for `/var/lib/csf/*.rbls` cache

### Decision

Use Test2::Mock for dependency mocking:
```perl
my $mock_ethdev = mock 'ConfigServer::GetEthDev' => (
    override => [
        new  => sub { bless {}, shift },
        ipv4 => sub { return ('1.2.3.4' => 1) },
        ipv6 => sub { return () },
    ]
);
```

---

## Summary

All technical questions resolved. Ready to proceed to Phase 1 design.

| Research Item | Status | Key Decision |
|---------------|--------|--------------|
| R1: CloudFlare pattern | ✅ Complete | Apply identical pattern |
| R2: Current state | ✅ Complete | 6 Perl 4 calls, 5 private functions, Exporter removal |
| R3: Config access | ✅ Complete | Keep loadconfig in report(), remove package-level %config |
| R4: Global persistence | ✅ Complete | Remove $ipv4reg/$ipv6reg, keep others |
| R5: MockConfig | ✅ Complete | Use Test2::Mock for dependencies |
