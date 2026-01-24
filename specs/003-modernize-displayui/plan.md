# Implementation Plan: Modernize DisplayUI.pm

**Branch**: `cp51229-modernize-displayui` | **Date**: 2026-01-24 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/003-modernize-displayui/spec.md`

## Summary

Modernize ConfigServer::DisplayUI.pm following the pattern established by cseUI.pm modernization. This includes removing legacy comment clutter, moving package-level variables inside `main()`, converting to disabled imports with fully qualified names, renaming internal functions to private (`_` prefix), adding POD documentation, and creating unit tests.

## Technical Context

**Language/Version**: Perl 5.36+ (cPanel-provided at `/usr/local/cpanel/3rdparty/bin/perl`)  
**Primary Dependencies**: ConfigServer::Config, ConfigServer::CheckIP, ConfigServer::Slurp, Net::CIDR::Lite, Fcntl, File::Copy, IPC::Open3  
**Storage**: File-based configuration at `/etc/csf/csf.conf`  
**Testing**: Test2::V0 framework with MockConfig isolation  
**Target Platform**: Linux server (cPanel environments)  
**Project Type**: Single Perl module modernization  
**Performance Goals**: N/A (refactoring - no performance changes)  
**Constraints**: Must maintain backward compatibility with existing callers  
**Scale/Scope**: Single module (~2985 lines), 13 subroutines, 2 exit calls to replace

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Copyright & Attribution | ✅ PASS | Lines 1-18 header will be preserved exactly |
| II. Security-First Design | ✅ PASS | Existing validation preserved; no new security logic |
| III. Perl Standards Compliance | ✅ PASS | Adding strict/warnings, disabled imports, explicit returns |
| IV. Test-First & Isolation | ✅ PASS | Creating unit tests with MockConfig |
| V. Configuration Discipline | ✅ PASS | Config already in main(); moving $cleanreg inside |
| VI. Simplicity & Maintainability | ✅ PASS | Cleaning up legacy comments, clear private API |

**All gates pass. Proceeding with planning.**

## Project Structure

### Documentation (this feature)

```text
specs/003-modernize-displayui/
├── plan.md              # This file
├── research.md          # Phase 0 output (not needed - pattern established)
├── data-model.md        # N/A for refactoring
├── quickstart.md        # N/A for refactoring
├── contracts/           # N/A for refactoring
└── tasks.md             # Phase 2 output (/speckit.tasks command)
```

### Source Code (affected files)

```text
lib/ConfigServer/
└── DisplayUI.pm         # Module being modernized

t/
├── lib/
│   └── MockConfig.pm    # Existing test utility (reuse)
└── ConfigServer-DisplayUI.t  # New test file
```

**Structure Decision**: This is a single-module refactoring. No new architectural components. Follows existing CSF module structure.

## Complexity Tracking

> No constitution violations requiring justification.

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| N/A | N/A | N/A |

## Implementation Phases

### Phase 0: Research (SKIPPED)

Research not needed - following established pattern from 002-modernize-cseui. The cseUI.pm modernization provides a proven template for all changes.

### Phase 1: Design (SKIPPED)

No new data models or API contracts needed - this is a refactoring of existing code maintaining backward compatibility.

### Phase 2: Implementation Tasks

Tasks are ordered by priority (P0-P5) from the specification. Each task is atomic and independently testable.

#### Task 0: Remove Legacy Comment Clutter (P0)

**File**: `lib/ConfigServer/DisplayUI.pm`

**Changes**:
1. Remove all `# start <name>` comment markers between subroutines
2. Remove all `# end <name>` comment markers between subroutines  
3. Remove all `###...###` divider lines between subroutines (keep lines 1 and 18 copyright header dividers)
4. Remove `# subroutine_name` labels immediately before function definitions

**Verification**: `perl -cw -Ilib lib/ConfigServer/DisplayUI.pm` compiles successfully

---

#### Task 1: Remove Global Variables at Module Load Time (P1)

**File**: `lib/ConfigServer/DisplayUI.pm`

**Changes**:
1. Remove line 54: `my $slurpreg = ConfigServer::Slurp->slurpreg;` (unused)
2. Remove line 55: `my $cleanreg = ConfigServer::Slurp->cleanreg;`
3. Add at start of `main()` (after variable declarations): `my $cleanreg = ConfigServer::Slurp->cleanreg;`

**Verification**: 
- `perl -cw -Ilib lib/ConfigServer/DisplayUI.pm` compiles successfully
- Grep for `$slurpreg` returns only 0 results
- Grep for `$cleanreg` shows declaration inside `main()`

---

#### Task 2: Code Modernization (P2)

**File**: `lib/ConfigServer/DisplayUI.pm`

**Changes**:
1. Remove line 19: `## no critic (...)`
2. Add after package declaration: `use warnings;` (strict already present)
3. Remove line 22: `use lib '/usr/local/csf/lib';`
4. Change `use Fcntl qw(:DEFAULT :flock);` to `use Fcntl ();`
5. Change `use File::Basename;` to `use File::Basename ();`
6. Change `use File::Copy;` to `use File::Copy ();`
7. Change `use IPC::Open3;` to `use IPC::Open3 ();`
8. Change `use Net::CIDR::Lite;` to `use Net::CIDR::Lite ();`
9. Remove Exporter machinery:
   - Remove `use Exporter qw(import);`
   - Remove `our @ISA = qw(Exporter);`
   - Remove `our @EXPORT_OK = qw();`
10. Update all Fcntl constant references to fully qualified names:
    - `O_RDWR` → `Fcntl::O_RDWR`
    - `O_CREAT` → `Fcntl::O_CREAT`
    - `O_RDONLY` → `Fcntl::O_RDONLY`
    - `O_WRONLY` → `Fcntl::O_WRONLY`
    - `LOCK_SH` → `Fcntl::LOCK_SH`
    - `LOCK_EX` → `Fcntl::LOCK_EX`
    - Note: `flock` and `sysopen` are Perl builtins - do NOT qualify
11. Update all IPC::Open3 function calls:
    - `open3(...)` → `IPC::Open3::open3(...)`
12. Update all File::Copy function calls:
    - `copy(...)` → `File::Copy::copy(...)`
13. Update all File::Basename function calls (if any):
    - `basename(...)` → `File::Basename::basename(...)`
    - `dirname(...)` → `File::Basename::dirname(...)`
14. Update Net::CIDR::Lite constructor:
    - `Net::CIDR::Lite->new` already fully qualified ✓
15. Convert all Perl 4-style subroutine calls to modern syntax:
    - `&printcmd(...)` → `_printcmd(...)`
    - `&printreturn` → `_printreturn()`
    - `&resize(...)` → `_resize(...)`
    - `&editfile(...)` → `_editfile(...)`
    - `&savefile(...)` → `_savefile(...)`
    - `&chart` → `_chart()`
    - `&systemstats(...)` → `_systemstats(...)`
    - `&cloudflare` → `_cloudflare()`
    - `&confirmmodal` → `_confirmmodal()`
    - `&manualversion(...)` → `_manualversion(...)`
16. Remove dead `&modsec` branch (lines 141-143) - pre-existing bug calling undefined subroutine

**Verification**: `perl -cw -Ilib lib/ConfigServer/DisplayUI.pm` compiles with no warnings

---

#### Task 3: Replace Exit Calls with Return (P2.5)

**File**: `lib/ConfigServer/DisplayUI.pm`

**Changes**:
1. Line 104: Replace `exit;` with `return;`
2. Line 1083: Replace `exit;` with `return;`

**Verification**: 
- `perl -cw -Ilib lib/ConfigServer/DisplayUI.pm` compiles successfully
- Grep for `\bexit\b` returns 0 results

---

#### Task 4: Make Subroutines Private (P3)

**File**: `lib/ConfigServer/DisplayUI.pm`

**Changes**: Rename all internal subroutines with underscore prefix:
1. `sub printcmd` → `sub _printcmd`
2. `sub getethdev` → `sub _getethdev`
3. `sub chart` → `sub _chart`
4. `sub systemstats` → `sub _systemstats`
5. `sub editfile` → `sub _editfile`
6. `sub savefile` → `sub _savefile`
7. `sub cloudflare` → `sub _cloudflare`
8. `sub resize` → `sub _resize`
9. `sub printreturn` → `sub _printreturn`
10. `sub confirmmodal` → `sub _confirmmodal`
11. `sub csgetversion` → `sub _csgetversion`
12. `sub manualversion` → `sub _manualversion`

**Note**: All call sites were already updated in Task 2 as part of Perl 4 → modern syntax conversion.

**Verification**: 
- `perl -cw -Ilib lib/ConfigServer/DisplayUI.pm` compiles successfully
- `grep "^sub " lib/ConfigServer/DisplayUI.pm` shows only `sub main` without underscore prefix

---

#### Task 5: Add POD Documentation (P4)

**File**: `lib/ConfigServer/DisplayUI.pm`

**Changes**: Add POD documentation following cPanel standards:

1. Add module-level POD after `package` declaration, before `use` statements:
```pod
=head1 NAME

ConfigServer::DisplayUI - Web-based firewall management interface for CSF

=head1 SYNOPSIS

    use ConfigServer::DisplayUI ();

    my %form = ( action => 'status' );
    ConfigServer::DisplayUI::main(\%form, $script, $script_da, $images, $myv, $this_ui);

=head1 DESCRIPTION

ConfigServer::DisplayUI provides a web-based user interface for managing
ConfigServer Security & Firewall (CSF). It handles form input dispatch,
firewall rule management, configuration editing, log viewing, and
system statistics display.

This module is typically called from a CGI script with form parameters
that determine the action to perform.

=cut
```

2. Add POD for `main()` subroutine immediately before the function:
```pod
=head2 main

    ConfigServer::DisplayUI::main(\%form, $script, $script_da, $images, $myv, $this_ui)

Main entry point for the DisplayUI module. Processes form input and dispatches
to appropriate action handlers.

=head3 Parameters

=over 4

=item C<\%form> - Hash reference containing form data (action, ip, ports, etc.)

=item C<$script> - URL path to the CGI script

=item C<$script_da> - DirectAdmin script path (if applicable)

=item C<$images> - Path to image assets

=item C<$myv> - Current CSF version string

=item C<$this_ui> - UI context identifier

=back

=head3 Returns

Returns after generating HTML output. Caller is responsible for process termination.

=cut
```

3. Add end-of-file POD sections after final `1;`:
```pod
=head1 VERSION

1.01

=head1 AUTHOR

Jonathan Michaelson

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2006-2025 Jonathan Michaelson

This program is free software; you can redistribute it and/or modify it under
the terms of the GNU General Public License as published by the Free Software
Foundation; either version 3 of the License, or (at your option) any later
version.

=cut
```

**Verification**:
- `podchecker lib/ConfigServer/DisplayUI.pm` reports no warnings or errors
- `perldoc lib/ConfigServer/DisplayUI.pm` displays NAME, SYNOPSIS, DESCRIPTION sections

---

#### Task 6: Create Unit Tests (P5)

**File**: `t/ConfigServer-DisplayUI.t` (new file)

**Content**: Create test file following cPanel testing standards:

```perl
#!/usr/local/cpanel/3rdparty/bin/perl

use cPstrict;

use Test2::V0;
use Test2::Tools::Explain;
use Test2::Plugin::NoWarnings;

use lib 't/lib';
use MockConfig;

# Test: Module loads successfully
use ConfigServer::DisplayUI ();
pass('ConfigServer::DisplayUI loaded successfully');

# Test: Public subroutine exists
can_ok('ConfigServer::DisplayUI', 'main');

# Test: Private subroutines are defined (spot check)
ok(defined &ConfigServer::DisplayUI::_printcmd, '_printcmd exists');
ok(defined &ConfigServer::DisplayUI::_printreturn, '_printreturn exists');
ok(defined &ConfigServer::DisplayUI::_editfile, '_editfile exists');

# Test: Input validation - invalid IP
subtest 'Input validation - invalid IP' => sub {
    my $output = '';
    local *STDOUT;
    open STDOUT, '>', \$output or die "Cannot redirect STDOUT: $!";
    
    MockConfig->set_config(
        RESTRICT_UI => 0,
        CF_ENABLE   => 0,
        ST_ENABLE   => 0,
        URLGET      => 1,
    );
    
    my %form = (
        action => '',
        ip     => 'not-a-valid-ip',
    );
    
    ConfigServer::DisplayUI::main(
        \%form,           # form ref
        '/cgi/csf.cgi',   # script
        '',               # script_da
        '/images',        # images
        '14.0',           # myv
        0,                # this_ui
    );
    
    like($output, qr/is not a valid IP/, 'Invalid IP rejected');
};

# Test: Input validation - invalid filename
subtest 'Input validation - invalid filename' => sub {
    my $output = '';
    local *STDOUT;
    open STDOUT, '>', \$output or die "Cannot redirect STDOUT: $!";
    
    MockConfig->set_config(
        RESTRICT_UI => 0,
        CF_ENABLE   => 0,
        ST_ENABLE   => 0,
        URLGET      => 1,
    );
    
    my %form = (
        action     => '',
        ip         => '',
        ignorefile => '../../../etc/passwd',
    );
    
    ConfigServer::DisplayUI::main(
        \%form,
        '/cgi/csf.cgi',
        '',
        '/images',
        '14.0',
        0,
    );
    
    like($output, qr/is not a valid file/, 'Invalid filename rejected');
};

# Test: RESTRICT_UI = 2 disables UI
subtest 'RESTRICT_UI disables UI' => sub {
    my $output = '';
    local *STDOUT;
    open STDOUT, '>', \$output or die "Cannot redirect STDOUT: $!";
    
    MockConfig->set_config(
        RESTRICT_UI => 2,
        CF_ENABLE   => 0,
        ST_ENABLE   => 0,
        URLGET      => 1,
    );
    
    my %form = ( action => 'status' );
    
    my $result = ConfigServer::DisplayUI::main(
        \%form,
        '/cgi/csf.cgi',
        '',
        '/images',
        '14.0',
        0,
    );
    
    like($output, qr/csf UI Disabled/, 'UI disabled message shown');
};

done_testing();
```

**Verification**:
- `perl -cw -Ilib t/ConfigServer-DisplayUI.t` reports no syntax errors
- `PERL5LIB='' prove -wlvm t/ConfigServer-DisplayUI.t` all tests pass
- `make test` passes with no regressions

---

## Implementation Order

| Order | Task | Priority | Dependency |
|-------|------|----------|------------|
| 1 | Task 0: Remove Legacy Comments | P0 | None |
| 2 | Task 1: Remove Global Variables | P1 | Task 0 |
| 3 | Task 2: Code Modernization | P2 | Task 1 |
| 4 | Task 3: Replace Exit Calls | P2.5 | Task 2 |
| 5 | Task 4: Make Subroutines Private | P3 | Task 3 (call sites updated in Task 2) |
| 6 | Task 5: Add POD Documentation | P4 | Task 4 |
| 7 | Task 6: Create Unit Tests | P5 | Task 5 |

## Post-Implementation Verification

After all tasks complete:

1. `perl -cw -Ilib lib/ConfigServer/DisplayUI.pm` - no warnings
2. `podchecker lib/ConfigServer/DisplayUI.pm` - no errors
3. `PERL5LIB='' prove -wlvm t/ConfigServer-DisplayUI.t` - all pass
4. `make test` - no regressions
5. Manual verification in UI (if accessible)
