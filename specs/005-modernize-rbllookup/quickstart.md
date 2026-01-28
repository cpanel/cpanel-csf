# Quickstart: Modernize RBLLookup.pm

**Feature**: 005-modernize-rbllookup  
**Date**: 2026-01-24

## Prerequisites

- Perl 5.36+ (cPanel-provided at `/usr/local/cpanel/3rdparty/bin/perl`)
- Access to the CSF repository
- Branch `005-modernize-rbllookup` checked out

## File Overview

| File | Purpose | Action |
|------|---------|--------|
| `lib/ConfigServer/RBLLookup.pm` | RBL lookup module | Modify |
| `t/ConfigServer-RBLLookup.t` | Unit tests | Create |

## Quick Validation Commands

### Verify Module Compiles
```bash
perl -cw -Ilib lib/ConfigServer/RBLLookup.pm
```

### Run Unit Tests
```bash
PERL5LIB='' prove -wlvm t/ConfigServer-RBLLookup.t
```

### Validate POD Documentation
```bash
podchecker lib/ConfigServer/RBLLookup.pm
perldoc lib/ConfigServer/RBLLookup.pm
```

### Run All Tests (Regression Check)
```bash
make test
```

## Implementation Checklist

### P0: Legacy Comment Cleanup
- [x] Verify no `# start`/`# end` markers exist (already clean)
- [x] Verify no `###...###` dividers between subroutines (already clean)

### P1: Code Modernization
- [ ] Remove `use Fcntl qw(:DEFAULT :flock);` (unused)
- [ ] Change `use IPC::Open3;` to `use IPC::Open3 ();`
- [ ] Change `use Net::IP;` to `use Net::IP ();`
- [ ] Change `use ConfigServer::CheckIP qw(checkip);` to `use ConfigServer::CheckIP ();`
- [ ] Remove Exporter machinery (use Exporter, @ISA, @EXPORT_OK)
- [ ] Remove package-level `loadconfig()` call
- [ ] Replace `checkip(\$ip)` with `ConfigServer::CheckIP::checkip(\$ip)`
- [ ] Replace `open3(...)` with `IPC::Open3::open3(...)`
- [ ] Replace `$config{HOST}` with `ConfigServer::Config->get_config('HOST')`

### P2: Private Subroutines
- [x] Verify no internal helpers exist (only `rbllookup` which is public)

### P3: POD Documentation
- [ ] Add NAME, SYNOPSIS, DESCRIPTION sections after copyright header
- [ ] Document `rbllookup()` function with parameters and return values
- [ ] Add SEE ALSO and LICENSE sections
- [ ] Run `podchecker` to validate

### P4: Unit Tests
- [ ] Create `t/ConfigServer-RBLLookup.t`
- [ ] Test invalid IP handling
- [ ] Test IPv4 address processing
- [ ] Test IPv6 address processing
- [ ] Test RBL hit with TXT record
- [ ] Test RBL not listed scenario
- [ ] Test timeout handling (if feasible)

## Success Criteria Verification

```bash
# SC-001: Module compiles
perl -cw -Ilib lib/ConfigServer/RBLLookup.pm && echo "PASS"

# SC-002: No package-level loadconfig
grep -n 'loadconfig' lib/ConfigServer/RBLLookup.pm | grep -v 'sub\|#' || echo "PASS"

# SC-003: No legacy comments (already verified)
grep -E '# (start|end) ' lib/ConfigServer/RBLLookup.pm || echo "PASS"

# SC-004: POD valid
podchecker lib/ConfigServer/RBLLookup.pm 2>&1 | grep -q 'OK' && echo "PASS"

# SC-005: Tests pass
PERL5LIB='' prove -wlvm t/ConfigServer-RBLLookup.t && echo "PASS"

# SC-006: No Exporter machinery
grep -E '@EXPORT|@ISA|use Exporter' lib/ConfigServer/RBLLookup.pm || echo "PASS"

# SC-007: Disabled imports (except cPstrict)
grep -E '^use (IPC|Net|Fcntl|ConfigServer::CheckIP)' lib/ConfigServer/RBLLookup.pm | grep -v '()' || echo "PASS"

# SC-008: No unused imports
grep 'use Fcntl' lib/ConfigServer/RBLLookup.pm || echo "PASS"
```
