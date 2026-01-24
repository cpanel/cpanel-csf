# Implementation Plan: Modernize Ports.pm

**Branch**: `004-modernize-ports` | **Date**: 2026-01-24 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/004-modernize-ports/spec.md`

## Summary

Modernize `ConfigServer::Ports` module to follow cPanel Perl coding standards: add strict/warnings, remove Exporter machinery, use disabled imports with fully qualified names, replace bareword handles with lexical handles, mark internal functions as private, add POD documentation, and create comprehensive unit tests. Use `Cpanel::Slurp` for file reading where appropriate.

## Technical Context

**Language/Version**: Perl 5.36+ (cPanel-provided at `/usr/local/cpanel/3rdparty/bin/perl`)  
**Primary Dependencies**: ConfigServer::Config, Cpanel::Slurp (slurpee for optional files), Fcntl  
**Storage**: N/A (reads from /proc filesystem)  
**Testing**: Test2::V0 framework with MockConfig for configuration mocking  
**Target Platform**: Linux server with /proc filesystem  
**Project Type**: Single Perl module modernization  
**Performance Goals**: N/A (existing behavior preserved)  
**Constraints**: Must work on systems with IPv6 disabled (tcp6/udp6 may not exist)  
**Scale/Scope**: Single 236-line module with 3 subroutines

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Copyright & Attribution | ✅ PASS | Copyright header (lines 1-18) will be preserved exactly |
| II. Security-First Design | ✅ PASS | Will add proper error handling, use three-arg open (already in use) |
| III. Perl Standards Compliance | ✅ WILL FIX | Currently violates: no warnings, Perl 4 calls, bareword handles, Exporter |
| IV. Test-First & Isolation | ✅ WILL ADD | Creating t/ConfigServer-Ports.t with MockConfig |
| V. Configuration Discipline | ✅ PASS | Config loaded within openports(), not at module level |
| VI. Simplicity & Maintainability | ✅ PASS | Module is already simple (3 functions, <30 lines each) |

**Gate Result**: PASS - No blocking violations. Modernization will bring module into compliance.

## Project Structure

### Documentation (this feature)

```text
specs/004-modernize-ports/
├── spec.md              # Feature specification
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
└── checklists/
    └── requirements.md  # Validation checklist
```

### Source Code (repository root)

```text
lib/
└── ConfigServer/
    └── Ports.pm         # Module to modernize

t/
├── lib/
│   └── MockConfig.pm    # Existing test mock utility
└── ConfigServer-Ports.t # New test file to create
```

**Structure Decision**: Single module modernization - no new directories needed. Test file follows existing `t/ConfigServer-*.t` naming convention.

## Phase 0: Research

### Dependencies to Research

1. **Cpanel::Slurp** - Verify availability and usage patterns for slurp vs slurpee
2. **Existing test patterns** - Review MockConfig usage in other tests
3. **Logging approach** - Identify how other ConfigServer modules log warnings

### Research Tasks

| Topic | Finding |
|-------|---------|
| Cpanel::Slurp availability | Available at `/usr/local/cpanel/Cpanel/Slurp.pm` - use `slurpee` for optional files (returns undef on error), `slurp` for required files (dies on error) |
| MockConfig patterns | Already reviewed - use `set_config()` to set values, mock ConfigServer::Config automatically |
| Logging approach | ConfigServer modules typically use `warn` for non-fatal issues; CSF logs via `ConfigServer::Logger` but for /proc access warnings, simple `warn` is appropriate |
| Bareword handle replacement | Use `opendir(my $dh, ...)` pattern consistently |

### Open Questions Resolved

All clarification questions have been answered in the spec:
- Permission errors → Log warning, continue
- Missing config keys → Die with error
- Malformed hex input → Return empty string
- File reading → Use Cpanel::Slurp
- Process race conditions → Silent skip

## Phase 1: Design

### Data Model

No new entities to design. Existing data structures preserved:

| Entity | Type | Description |
|--------|------|-------------|
| %tcpstates | Package constant | Maps hex TCP state codes to names |
| %printable | Package constant | Escape map for non-printable chars |
| %listen (return) | Nested hash | `{protocol}{port}{pid}{attr}` |
| %ports (return) | Nested hash | `{protocol}{port} = 1` |

### API Contracts

**Public API** (unchanged signatures):

```perl
# listening() - Returns hash of listening ports with process info
sub listening {
    # No parameters
    # Returns: %listen hash
    #   Structure: {protocol}{port}{pid}{user|exe|cmd|conn}
    return %listen;
}

# openports() - Returns hash of configured open ports
sub openports {
    # No parameters  
    # Returns: %ports hash
    #   Structure: {protocol}{port} = 1
    return %ports;
}
```

**Private API** (internal only):

```perl
# _hex2ip($hex_string) - Convert hex IP to dotted/colon notation
sub _hex2ip {
    my ($hex) = @_;
    # Returns: IP string (IPv4 dotted or IPv6 colon) or empty string on error
    return $ip_string;
}
```

### Implementation Phases

#### Phase 1: P0 - Remove Legacy Comment Clutter

**Files to modify**: `lib/ConfigServer/Ports.pm`

**Changes**:
1. Remove `## no critic` line (line 19)
2. Remove `# start main` comment (line 20)
3. Remove `# end main` comment (line 48)
4. Remove `###...###` divider (line 49)
5. Remove `# start listening` comment (line 50)
6. Remove `# end listening` comment (line 148)
7. Remove `###...###` divider (line 149)
8. Remove `# start openports` comment (line 150)
9. Remove `# end openports` comment (line 219)
10. Remove `###...###` divider (line 220)
11. Remove `## start hex2ip` comment (line 221)
12. Remove `## end hex2ip` comment (line 232)
13. Remove trailing `###...###` divider (line 233)

#### Phase 2: P1 - Code Modernization

**Files to modify**: `lib/ConfigServer/Ports.pm`

**Changes**:
1. Add `use warnings;` after `use strict;`
2. Remove `use lib '/usr/local/csf/lib';`
3. Change `use Fcntl qw(:DEFAULT :flock);` to `use Fcntl ();`
4. Remove `use Exporter qw(import);`
5. Remove `our @ISA = qw(Exporter);`
6. Remove `our @EXPORT_OK = qw();`
7. Replace `LOCK_SH` with `Fcntl::LOCK_SH` (multiple locations)
8. Replace `&hex2ip(...)` with `_hex2ip(...)` (2 locations)
9. Replace `loadconfig()` with `get_config()` calls for TCP_IN, TCP6_IN, UDP_IN, UDP6_IN
9. Replace `opendir(PROCDIR, "/proc")` with `opendir(my $procdir, "/proc")`
10. Replace `readdir(PROCDIR)` with `readdir($procdir)`
11. Replace `closedir(PROCDIR)` with `closedir($procdir)`
12. Replace `opendir(DIR, ...)` with `opendir(my $fddir, ...)`
13. Replace `readdir(DIR)` with `readdir($fddir)`
14. Replace `closedir(DIR)` with `closedir($fddir)`
15. Replace /proc/net file reading with `Cpanel::Slurp::slurpee()` (returns undef on error, no die)
16. Add `warn` for /proc opendir failures, continue processing
17. Remove `##no critic` from %printable line

#### Phase 3: P2 - Make Internal Subroutines Private

**Files to modify**: `lib/ConfigServer/Ports.pm`

**Changes**:
1. Rename `sub hex2ip` to `sub _hex2ip`
2. Update function signature to handle empty/malformed input → return ''
3. Add explicit `return '';` for edge cases

#### Phase 4: P3 - Add POD Documentation

**Files to modify**: `lib/ConfigServer/Ports.pm`

**Sections to add**:
1. Module-level POD after line 18 (NAME, SYNOPSIS, DESCRIPTION)
2. `=head2 listening` documentation before the subroutine
3. `=head2 openports` documentation before the subroutine
4. End-of-file sections (VERSION, AUTHOR, COPYRIGHT AND LICENSE)

#### Phase 5: P4 - Add Unit Test Coverage

**Files to create**: `t/ConfigServer-Ports.t`

**Test groups**:
1. Module loads correctly
2. `_hex2ip()` with IPv4 input
3. `_hex2ip()` with IPv6 input
4. `_hex2ip()` with malformed input (returns empty string)
5. `openports()` with mocked config
6. `openports()` with missing config keys (dies)
7. `listening()` with skip conditions for /proc access

### Quickstart

See [quickstart.md](quickstart.md) for step-by-step implementation guide.

## Complexity Tracking

No constitution violations requiring justification. All changes bring module into compliance.

## Risk Assessment

| Risk | Impact | Mitigation |
|------|--------|------------|
| /proc filesystem mocking is complex | Medium | Use skip conditions for live /proc tests; focus on _hex2ip testing |
| Behavior change: missing config now dies | Low | This is an improvement - fail-fast on bad config |
| Cpanel::Slurp may not be available in test env | Low | Can defer to manual open if needed; focus on core modernization |

## Validation Checklist

- [ ] `perl -cw -Ilib lib/ConfigServer/Ports.pm` exits 0
- [ ] `podchecker lib/ConfigServer/Ports.pm` reports no errors
- [ ] `prove -wlvm t/ConfigServer-Ports.t` all tests pass
- [ ] No `# start`/`# end` comments remain
- [ ] No `###...###` dividers remain (except copyright header)
- [ ] No `&function` calls remain
- [ ] No bareword handles remain (PROCDIR, DIR)
- [ ] Copyright header (lines 1-18) unchanged
