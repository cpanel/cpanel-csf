# Implementation Plan: Modernize ConfigServer::Service.pm

**Branch**: `007-modernize-service` | **Date**: 2026-01-28 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/007-modernize-service/spec.md`

## Summary

Modernize `ConfigServer::Service` module to follow cPanel Perl coding standards: use cPstrict, remove package-level config loading and /proc access, remove Exporter machinery and hardcoded lib path, use disabled imports with fully qualified names, rename internal helper `printcmd()` to `_printcmd`, add POD documentation, and create comprehensive unit tests with mocked external dependencies.

## Technical Context

**Language/Version**: Perl 5.36+ (cPanel-provided at `/usr/local/cpanel/3rdparty/bin/perl`)  
**Primary Dependencies**: ConfigServer::Config, ConfigServer::Slurp, IPC::Open3, Fcntl  
**Storage**: N/A (manages LFD service via systemd or init scripts)  
**Testing**: Test2::V0 framework with MockConfig for configuration mocking  
**Target Platform**: Linux server with systemd or SysV init  
**Project Type**: Single Perl module modernization  
**Performance Goals**: N/A (existing behavior preserved)  
**Constraints**: Service management is critical; systemd and init paths must both work  
**Scale/Scope**: Single 110-line module with 6 subroutines (type, startlfd, stoplfd, restartlfd, statuslfd, printcmd)

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Copyright & Attribution | ✅ PASS | Copyright header (lines 1-18) will be preserved exactly |
| II. Security-First Design | ✅ PASS | Uses IPC::Open3 for command execution |
| III. Perl Standards Compliance | ✅ WILL FIX | Currently violates: use strict (not cPstrict), Exporter, use lib, package-level loadconfig, package-level /proc access, imports without (), ampersand syntax |
| IV. Test-First & Isolation | ✅ WILL ADD | Creating t/ConfigServer-Service.t with MockConfig |
| V. Configuration Discipline | ✅ WILL FIX | Config loaded at module level - must move to function |
| VI. Simplicity & Maintainability | ✅ PASS | Module is simple (6 functions) |

**Gate Result**: PASS - No blocking violations. Modernization will bring module into compliance.

## Project Structure

### Documentation (this feature)

```text
specs/007-modernize-service/
├── spec.md              # Feature specification
├── plan.md              # This file
├── research.md          # Phase 0 output
├── quickstart.md        # Phase 1 output
├── checklists/
│   └── requirements.md  # Validation checklist
└── tasks.md             # Phase 2 output (created by /speckit.tasks)
```

### Source Code (repository root)

```text
lib/
└── ConfigServer/
    └── Service.pm       # Module to modernize

t/
├── lib/
│   └── MockConfig.pm    # Existing test mock utility
└── ConfigServer-Service.t # New test file to create
```

**Structure Decision**: Single module modernization - no new directories needed. Test file follows existing `t/ConfigServer-*.t` naming convention.

## Phase 0: Research

### Dependencies to Research

1. **IPC::Open3 mocking** - How to mock command execution for testing
2. **/proc/1/comm access** - How to refactor init type detection from package level
3. **Fcntl constants** - How to use fully qualified names for locking constants

### Research Tasks

| Topic | Finding |
|-------|---------|
| IPC::Open3 mocking | Use Test2::Mock to override `IPC::Open3::open3` or mock the `_printcmd` helper directly |
| Init type detection | Create `_get_init_type()` helper with lazy initialization using state variable |
| Fcntl constants | Use `Fcntl::LOCK_SH()` with `use Fcntl ()` |
| Config access | Use `ConfigServer::Config->get_config('SYSTEMCTL')` within functions |
| /proc file reading | Use `ConfigServer::Slurp::slurp()` for simple file reading |

### Open Questions Resolved

- Missing /proc/1/comm → Default to "init" (safe fallback)
- Missing SYSTEMCTL config → Will cause runtime error (existing behavior)
- Init script failures → Errors printed to stdout (existing behavior)

### Package-Level Variables Strategy

**Current State**:
```perl
my $config = ConfigServer::Config->loadconfig();
my %config = $config->config();

open( my $IN, "<", "/proc/1/comm" );
flock( $IN, LOCK_SH );
my $sysinit = <$IN>;
close($IN);
chomp $sysinit;
if ( $sysinit ne "systemd" ) { $sysinit = "init" }
```

**Refactoring Strategy**:
1. Remove `$config`/`%config` entirely - use get_config() in functions
2. Create `_get_init_type()` with state variable for lazy init
3. Use `ConfigServer::Slurp::slurp()` for /proc reading

## Phase 1: Design

### Data Model

No new entities to design. Function signatures and return values preserved:

| Function | Input | Output | Description |
|----------|-------|--------|-------------|
| type() | none | string | Returns "systemd" or "init" |
| startlfd() | none | void | Starts lfd service |
| stoplfd() | none | void | Stops lfd service |
| restartlfd() | none | void | Restarts lfd service |
| statuslfd() | none | 0 | Shows lfd status, returns 0 |
| _printcmd(@cmd) | @command | void | Executes command, prints output |

### API Contracts

**Public API** (unchanged signatures):

```perl
# type() - Returns init system type
sub type {
    return _get_init_type();
}

# startlfd() - Start the lfd service
sub startlfd {
    # ... implementation ...
    return;
}

# stoplfd() - Stop the lfd service
sub stoplfd {
    # ... implementation ...
    return;
}

# restartlfd() - Restart the lfd service
sub restartlfd {
    # ... implementation ...
    return;
}

# statuslfd() - Show lfd service status
sub statuslfd {
    # ... implementation ...
    return 0;
}
```

**Private API** (new and renamed):

```perl
# _get_init_type() - Lazily detect init system type
sub _get_init_type {
    state $init_type;
    return $init_type if defined $init_type;
    # ... read /proc/1/comm ...
    return $init_type;
}

# _printcmd(@command) - Execute command and print output (renamed from printcmd)
sub _printcmd {
    my @command = @_;
    # ... implementation ...
    return;
}
```

### Implementation Phases

#### Phase 1: P0 - Remove Legacy Comment Clutter

**Files to modify**: `lib/ConfigServer/Service.pm`

**Changes**:
1. Remove `## no critic` directive (line 20)
2. Remove `# start main` comment
3. Remove `# end main` comment
4. Remove `###...###` dividers between functions
5. Remove all `# start <function>` and `# end <function>` markers

#### Phase 2: P1 - Code Modernization

**Files to modify**: `lib/ConfigServer/Service.pm`

**Import Changes**:
1. Replace `use strict;` with `use cPstrict;`
2. Remove `use lib '/usr/local/csf/lib';`
3. Add `use Carp ();`
4. Change `use IPC::Open3;` to `use IPC::Open3 ()`
5. Change `use Fcntl qw(:DEFAULT :flock);` to `use Fcntl ()`
6. Add `use ConfigServer::Config ();`
7. Add `use ConfigServer::Slurp ();`
8. Remove `use Exporter qw(import);`
9. Remove `our @ISA = qw(Exporter);`
10. Remove `our @EXPORT_OK = qw();`

**Package-Level Removal**:
1. Remove `my $config = ConfigServer::Config->loadconfig();`
2. Remove `my %config = $config->config();`
3. Remove the /proc/1/comm file reading block
4. Add `_get_init_type()` helper function

**Function Updates**:
1. Replace `$config{SYSTEMCTL}` with `ConfigServer::Config->get_config('SYSTEMCTL')`
2. Replace `LOCK_SH` with `Fcntl::LOCK_SH()`
3. Replace `$sysinit` variable with `_get_init_type()` calls

#### Phase 3: P2 - Rename Internal Helpers

**Files to modify**: `lib/ConfigServer/Service.pm`

**Changes**:
1. Rename `sub printcmd` to `sub _printcmd`
2. Update all `&printcmd(...)` calls to `_printcmd(...)`

#### Phase 4: P3 - Add POD Documentation

**Files to modify**: `lib/ConfigServer/Service.pm`

**POD Sections**:
1. NAME - Module name and short description
2. SYNOPSIS - Usage examples
3. DESCRIPTION - What the module does
4. FUNCTIONS - Document type, startlfd, stoplfd, restartlfd, statuslfd
5. CONFIGURATION - SYSTEMCTL config value
6. SEE ALSO - Related modules

#### Phase 5: P4 - Add Unit Tests

**Files to create**: `t/ConfigServer-Service.t`

**Test Cases**:
1. Module loads successfully
2. Public API exists (type, startlfd, stoplfd, restartlfd, statuslfd)
3. _get_init_type() returns "systemd" when /proc/1/comm contains "systemd"
4. _get_init_type() returns "init" for any other value
5. _get_init_type() caches result (lazy initialization)
6. startlfd() calls correct commands for systemd
7. startlfd() calls correct commands for init
8. stoplfd() calls correct commands for systemd
9. stoplfd() calls correct commands for init
10. restartlfd() calls correct commands for systemd
11. restartlfd() calls correct commands for init
12. statuslfd() returns 0
13. _printcmd() executes command and captures output

## Risks and Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Breaking service management | High | Comprehensive testing before and after |
| Init type detection failure | Medium | Default to "init" as safe fallback |
| Config value missing | Low | Existing behavior preserved (runtime error) |

## Validation Plan

1. **Syntax check**: `perl -cw -Ilib lib/ConfigServer/Service.pm`
2. **POD check**: `podchecker lib/ConfigServer/Service.pm`
3. **Unit tests**: `PERL5LIB='' prove -wlvm t/ConfigServer-Service.t`
4. **All tests**: `make test`
5. **No legacy markers**: `grep -E '# (start|end) ' lib/ConfigServer/Service.pm`
6. **No Exporter**: `grep -E '@EXPORT|@ISA|use Exporter' lib/ConfigServer/Service.pm`
