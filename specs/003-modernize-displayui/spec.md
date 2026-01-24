# Feature Specification: Modernize DisplayUI.pm

**Case Number**: CPANEL-51229  
**Feature Branch**: `cp51229-modernize-displayui`  
**Created**: 2026-01-24  
**Status**: Draft  
**Input**: User description: "Modernize DisplayUI.pm: Add strict/warnings, remove global variables at module load time, add POD documentation and unit tests following the same pattern used for cseUI.pm modernization"

## Clarifications

### Session 2026-01-24

- Q: How should `exit` calls at lines 104 and 1083 be handled during modernization? → A: Replace with `return` statements; caller handles process termination
- Q: How should `$slurpreg` and `$cleanreg` package-level variables be handled? → A: Remove `$slurpreg` (unused); move `$cleanreg` initialization inside `main()`
- Q: What test coverage target for the large `main()` dispatch function? → A: Focus on critical paths (module load, validation, 2-3 representative handlers) rather than percentage

## User Scenarios & Testing *(mandatory)*

### User Story 0 - Remove Legacy Comment Clutter (Priority: P0)

As a developer, I need to remove legacy formatting comments from DisplayUI.pm so that the code follows clean formatting standards and matches the cseUI.pm modernization pattern.

**Why this priority**: These legacy formatting comments clutter the code and serve no functional purpose. They should be removed before any other modernization work to establish a clean baseline.

**Context**: This is a one-time cleanup task, not a permanent rule against comments. Future developers may add useful comments as needed. The goal is to remove the specific legacy cruft that was common in older Perl code.

**What to remove**:
- All `# start` and `# end` comment markers (e.g., `# start main`, `# end main`, `# start printcmd`, etc.)
- All `###...###` divider lines between subroutines (but NOT the copyright header dividers at the top of the file)
- All `# subroutine_name` label comments immediately before function definitions
- Standalone `#` empty comment lines that serve no purpose

**What to keep**:
- The copyright/license header at the top of the file (lines 1-18)
- Useful inline comments explaining complex logic
- Any comments that provide genuine value to future developers

**Acceptance Scenarios**:

1. **Given** DisplayUI.pm, **When** examining the code between subroutines, **Then** no `# start` or `# end` comment markers exist
2. **Given** DisplayUI.pm, **When** examining the code between subroutines, **Then** no `###...###` divider lines exist (only the 2 copyright header dividers at top of file remain)
3. **Given** DisplayUI.pm, **When** running `perl -cw`, **Then** the module still compiles successfully after comment removal

---

### User Story 1 - Remove Global Variables at Module Load Time (Priority: P1)

As a developer maintaining the CSF codebase, I need the DisplayUI.pm module to not access configuration at module load time, so that the module can be properly unit tested without requiring production configuration files.

**Why this priority**: Global variables populated at module load time prevent unit testing and can cause circular dependency issues. This is the foundation for all other improvements.

**Independent Test**: Run `perl -cw -Ilib lib/ConfigServer/DisplayUI.pm` and verify it compiles without requiring `/etc/csf/csf.conf` to exist.

**Current State Analysis**:
- The module defines global variables at package level (line 48-53): `$chart`, `$ipscidr6`, `$ipv6reg`, `$ipv4reg`, `%config`, `%ips`, `$mobile`, `$urlget`, `%FORM`, `$script`, `$script_da`, `$images`, `$myv`
- Configuration is loaded inside `main()` function (lines 69-72), which is correct
- `$slurpreg` is defined at package level but never used - REMOVE
- `$cleanreg` is defined at package level but only used inside `main()` - move initialization inside `main()`

**Acceptance Scenarios**:

1. **Given** DisplayUI.pm is loaded, **When** no configuration files exist, **Then** the module compiles successfully without errors
2. **Given** the `main()` function is called, **When** configuration is needed, **Then** configuration is loaded within the function scope (not at module load time)
3. **Given** DisplayUI.pm, **When** examining package-level code, **Then** no configuration loading occurs outside of subroutines
4. **Given** DisplayUI.pm, **When** examining package-level variables, **Then** `$slurpreg` is removed and `$cleanreg` is initialized inside `main()`

---

### User Story 2 - Code Modernization (Priority: P2)

As a developer, I need DisplayUI.pm to follow modern cPanel Perl coding standards (strict, warnings, disabled imports, fully qualified names) so that the code is consistent with other modernized modules in the CSF codebase.

**Why this priority**: Standardized code patterns reduce cognitive load and make the codebase more maintainable. This modernization must happen before private function renaming.

**Independent Test**: Run `perl -cw -Ilib lib/ConfigServer/DisplayUI.pm` and verify it uses `use strict;`, `use warnings;`, has disabled imports for non-ConfigServer modules, and has removed unused imports.

**Acceptance Scenarios**:

1. **Given** DisplayUI.pm, **When** examining the module header, **Then** it uses `use strict;` and `use warnings;`
2. **Given** DisplayUI.pm, **When** examining imports, **Then** Fcntl uses `use Fcntl ();` with fully qualified constant names (e.g., `Fcntl::O_RDWR`, `Fcntl::LOCK_SH`)
3. **Given** DisplayUI.pm, **When** examining imports, **Then** File::Basename uses `use File::Basename ();` with fully qualified function names
4. **Given** DisplayUI.pm, **When** examining imports, **Then** File::Copy uses `use File::Copy ();` with fully qualified function names
5. **Given** DisplayUI.pm, **When** examining imports, **Then** IPC::Open3 uses `use IPC::Open3 ();` with fully qualified function names
6. **Given** DisplayUI.pm, **When** examining imports, **Then** Net::CIDR::Lite uses `use Net::CIDR::Lite ();` with fully qualified constructor calls
7. **Given** DisplayUI.pm, **When** examining code, **Then** Exporter machinery is removed (no @EXPORT_OK, @ISA, use Exporter)
8. **Given** DisplayUI.pm, **When** examining code, **Then** the `## no critic` line is removed or updated appropriately
9. **Given** DisplayUI.pm, **When** examining code, **Then** `use lib '/usr/local/csf/lib';` is removed (not needed with proper @INC)

---

### User Story 3 - Make Subroutines Private (Priority: P3)

As a developer, I need internal helper functions in DisplayUI.pm to be marked as private (with underscore prefix) so that the public API is clear and internal implementation details are not accidentally used by external code.

**Why this priority**: Clear API boundaries make the codebase easier to maintain and refactor. Private functions can be changed without breaking external consumers. This MUST happen before POD documentation so we only document the public API.

**Current Public Functions**:
- `main()` - Main entry point (KEEP PUBLIC)

**Current Internal Functions to Make Private**:
- `printcmd` → `_printcmd`
- `getethdev` → `_getethdev`
- `chart` → `_chart`
- `systemstats` → `_systemstats`
- `editfile` → `_editfile`
- `savefile` → `_savefile`
- `cloudflare` → `_cloudflare`
- `resize` → `_resize`
- `printreturn` → `_printreturn`
- `confirmmodal` → `_confirmmodal`
- `csgetversion` → `_csgetversion`
- `manualversion` → `_manualversion`

**Acceptance Scenarios**:

1. **Given** DisplayUI.pm module, **When** examining the subroutine names, **Then** only `main()` is public (no underscore prefix)
2. **Given** DisplayUI.pm module, **When** examining helper functions, **Then** all are prefixed with underscore (`_`)
3. **Given** DisplayUI.pm module, **When** running `perl -cw`, **Then** all internal function calls use the updated private names

---

### User Story 4 - Add POD Documentation (Priority: P4)

As a developer working with the CSF codebase, I need DisplayUI.pm to have proper POD documentation for PUBLIC functions only, so that I can understand the module's purpose and public API without reading the implementation code.

**Why this priority**: Documentation improves developer productivity and reduces time spent understanding code. Required by cPanel coding standards. This story depends on P3 (private functions) being complete first so we only document the public API.

**Independent Test**: Run `perldoc lib/ConfigServer/DisplayUI.pm` and verify NAME, SYNOPSIS, DESCRIPTION, and METHODS sections are present and properly formatted.

**Acceptance Scenarios**:

1. **Given** DisplayUI.pm, **When** running `podchecker`, **Then** no warnings or errors are reported
2. **Given** DisplayUI.pm, **When** viewing with `perldoc`, **Then** NAME, SYNOPSIS, DESCRIPTION sections are visible
3. **Given** the public `main()` function, **When** viewing documentation, **Then** parameters, return values, and usage examples are documented

---

### User Story 5 - Add Unit Test Coverage (Priority: P5)

As a developer, I need unit tests for DisplayUI.pm so that I can verify the module works correctly and catch regressions when making changes.

**Why this priority**: Tests enable confident refactoring and prevent regressions. This story depends on P1-P4 being complete first.

**Test Focus**: Tests should validate **actual module behavior** (functional testing), not meta-tests that check coding patterns. Since this is a modernization effort, validating coding patterns adds no value - the patterns are already enforced by the modernization process itself. Functional tests validate that the module works correctly.

**Independent Test**: Run `prove -wlvm t/ConfigServer-DisplayUI.t` and verify all tests pass.

**Acceptance Scenarios**:

1. **Given** the test file, **When** running with `prove`, **Then** all tests pass
2. **Given** the test file, **When** running with `perl -cw -Ilib`, **Then** no syntax errors or warnings
3. **Given** the tests, **When** checking coverage, **Then** module loading is tested without requiring production config
4. **Given** the tests, **When** checking coverage, **Then** input validation (invalid IP, invalid filename) paths are tested
5. **Given** the tests, **When** checking coverage, **Then** 2-3 representative action handlers are tested with mocked dependencies

---

### Edge Cases

- What happens when `/etc/csf/csf.conf` configuration file does not exist?
- What happens when `RESTRICT_UI` is set to 2 (should disable UI)?
- What happens when an invalid IP address is provided in `$FORM{ip}`?
- What happens when an invalid filename is provided in `$FORM{ignorefile}` or `$FORM{template}`?
- What happens when `$FORM{action}` contains an unrecognized action?
- What happens when external commands (`/usr/sbin/csf`) fail or time out?
- What happens when the CloudFlare module is required but not available (`$config{CF_ENABLE}`)?
- What happens when ServerStats initialization fails (`$chart = 0`)?
- What happens when URLGet fails and falls back to HTTP::Tiny?

## Requirements *(mandatory)*

### Functional Requirements

#### Code Modernization

- **FR-001**: Module MUST use `use strict;` and `use warnings;`
- **FR-002**: Module MUST remove `## no critic` line after modernization
- **FR-003**: Internal helper functions MUST be prefixed with underscore (`_`) to indicate private scope
- **FR-004**: Module MUST remove Exporter machinery (use Exporter, @ISA, @EXPORT_OK) since no exports are defined
- **FR-005**: For non-ConfigServer modules (Fcntl, File::Basename, File::Copy, IPC::Open3, Net::CIDR::Lite), MUST disable imports with empty parens `use Module ();` and use fully qualified names. Note: `flock`, `sysopen` are Perl builtins, not Fcntl functions
- **FR-006**: Module MUST preserve existing **working** error handling behavior; error handling improvements deferred to future iteration
- **FR-007**: All Perl 4-style subroutine calls (`&subname`) to **internal** functions MUST be converted to modern syntax (`_subname()`)
- **FR-008**: Module MUST remove legacy comment clutter: (a) `# start`/`# end` markers, (b) `###...###` divider lines between subroutines (NOT the copyright header), (c) `# subroutine_name` labels before functions
- **FR-009**: Module MUST remove `use lib '/usr/local/csf/lib';` line (not needed with proper module installation)

#### Exit Calls

- **FR-010**: All `exit` statements MUST be replaced with `return` statements. The caller (CGI script) is responsible for process termination. This enables:
  - Full unit testing without forking workarounds
  - Proper separation of concerns (module does not control process lifecycle)
  - Compatibility with long-running processes and mod_perl environments
  - **Implementation**: Replace `exit;` at lines 104 and 1083 with `return;`

#### Global Variables

- **FR-011**: Package-level `our` variables that are only used within `main()` scope SHOULD be converted to `my` variables within `main()`
- **FR-012**: The `%config` hash MUST be populated by calling `ConfigServer::Config->loadconfig()` within `main()`, not at package level (already correct, verify preserved)
- **FR-013**: Form variables (`%FORM`, `$script`, `$images`, etc.) MUST be passed as parameters or initialized within `main()` (already correct, verify preserved)
- **FR-014**: The `$slurpreg` package-level variable MUST be removed (unused). The `$cleanreg` assignment MUST be moved inside `main()` near the top, prior to all uses (used at lines 371, 440, 508, 588)

#### POD Documentation

- **FR-015**: Module MUST include NAME section with module name and brief description
- **FR-016**: Module MUST include SYNOPSIS section with usage example
- **FR-017**: Module MUST include DESCRIPTION section explaining module purpose
- **FR-018**: Public function `main()` MUST have POD documentation with parameters and return value
- **FR-019**: POD MUST pass `podchecker` without warnings or errors
- **FR-020**: POD MUST be placed after `package` declaration but before `use` statements (module-level) and immediately before subroutines (function-level)

#### Unit Tests

- **FR-021**: Test file MUST be named `t/ConfigServer-DisplayUI.t`
- **FR-022**: Test file MUST use shebang `#!/usr/local/cpanel/3rdparty/bin/perl`
- **FR-023**: Test file MUST use standardized header: `use cPstrict;` (NOT separate strict/warnings), `Test2::V0`, `Test2::Tools::Explain`, `Test2::Plugin::NoWarnings`, `use lib 't/lib'`, `MockConfig`
- **FR-024**: Test file MUST use `MockConfig` to mock configuration values
- **FR-025**: Tests MUST verify module loads successfully
- **FR-026**: Tests MUST verify public subroutines exist
- **FR-027**: Tests MUST mock external dependencies (file I/O, system commands, HTTP requests)
- **FR-028**: Tests MUST pass `perl -cw -Ilib` syntax check
- **FR-029**: Tests MUST pass when run with `prove -wlvm`

### Key Entities

- **DisplayUI.pm**: ConfigServer Display UI module providing a web-based firewall management interface for CSF
- **main()**: Main public entry point that processes form input and dispatches to appropriate action handlers
- **Action handlers**: Internal functions (`_printcmd`, `_editfile`, `_savefile`, `_chart`, `_systemstats`, etc.) that perform firewall and UI operations
- **%config**: Configuration hash loaded from `/etc/csf/csf.conf`
- **%FORM**: Form data hash containing user input (action, IP, ports, comments, etc.)
- **$urlget**: URL fetching object for version checks and downloads
- **$chart**: Flag indicating if ServerStats charting is available

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Module compiles without requiring production configuration files (`perl -cw -Ilib lib/ConfigServer/DisplayUI.pm` succeeds in test environment)
- **SC-002**: All existing functionality continues to work (no behavioral regressions)
- **SC-003**: POD documentation passes `podchecker` with zero warnings or errors
- **SC-004**: New test file covers critical paths: module loading, input validation (IP/filename checks), and 2-3 representative action handlers
- **SC-005**: Test file passes `perl -cw -Ilib t/ConfigServer-DisplayUI.t` with no warnings
- **SC-006**: Test file passes `prove -wlvm t/ConfigServer-DisplayUI.t` with all tests passing
- **SC-007**: Running `make test` passes with no regressions to existing tests
- **SC-008**: No Perl 4-style subroutine calls (`&subname`) remain in the module
- **SC-009**: No inter-subroutine `# start` / `# end` comment markers remain

## Assumptions

- The modernization follows the same pattern established for cseUI.pm modernization
- The module will continue to use HTML output format for the UI integration
- External system commands (`/usr/sbin/csf`) will be mocked in tests, not actually executed
- The module's security-sensitive operations (IP blocking, firewall rules) will have their existing validation preserved
- The `/etc/csf/csf.conf` configuration loading pattern already inside `main()` will be preserved
- ConfigServer modules (ConfigServer::Config, ConfigServer::CheckIP, etc.) can continue to use their existing import patterns
