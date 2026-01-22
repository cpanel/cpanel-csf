# Feature Specification: Modernize RBLCheck.pm

**Feature Branch**: `001-modernize-rblcheck`  
**Created**: 2026-01-22  
**Status**: Draft  
**Input**: User description: "Modernize RBLCheck.pm: Add POD documentation and unit tests following the same pattern used for CloudFlare.pm modernization"

## User Scenarios & Testing *(mandatory)*

### User Story 0 - Remove Inter-Subroutine Comments (Priority: P0)

As a developer, I need to remove all comments with start/end markers that exist between subroutines in RBLCheck.pm so that the code follows clean formatting standards and matches the CloudFlare.pm pattern.

**Why this priority**: These legacy formatting comments clutter the code and serve no functional purpose. They should be removed before any other modernization work to establish a clean baseline.

**Independent Test**: Run `grep -E '^\s*##+\s*start|^\s*##+\s*end' lib/ConfigServer/RBLCheck.pm` and verify no results are returned.

**Acceptance Scenarios**:

1. **Given** RBLCheck.pm, **When** examining the code between subroutines, **Then** no comments with "start" or "end" markers exist
2. **Given** RBLCheck.pm, **When** running `perl -cw`, **Then** the module still compiles successfully after comment removal

---

### User Story 1 - Remove Global Variables (Priority: P1)

As a developer maintaining the CSF codebase, I need the RBLCheck.pm module to not use global variables at module load time, so that the module can be properly unit tested without requiring production configuration files.

**Why this priority**: Global variables that call `loadconfig()` at module load time prevent unit testing and can cause circular dependency issues. This is the foundation for all other improvements.

**Independent Test**: Run `perl -cw -Ilib lib/ConfigServer/RBLCheck.pm` and verify it compiles without requiring `/etc/csf/csf.conf` to exist.

**Acceptance Scenarios**:

1. **Given** RBLCheck.pm is loaded, **When** no configuration files exist, **Then** the module compiles successfully without errors
2. **Given** the `report()` function is called, **When** configuration is needed, **Then** configuration is loaded within the function scope (not at module load time)

---

### User Story 2 - Code Modernization (Priority: P2)

As a developer, I need RBLCheck.pm to follow modern cPanel Perl coding standards (cPstrict, disabled imports, fully qualified names) so that the code is consistent with other modernized modules in the CSF codebase.

**Why this priority**: Standardized code patterns reduce cognitive load and make the codebase more maintainable. This modernization must happen before private function renaming.

**Independent Test**: Run `perl -cw -Ilib lib/ConfigServer/RBLCheck.pm` and verify it uses `use cPstrict;`, has disabled imports for non-ConfigServer modules, and has removed unused imports.

**Acceptance Scenarios**:

1. **Given** RBLCheck.pm, **When** examining the module header, **Then** it uses `use cPstrict;` instead of separate strict/warnings
2. **Given** RBLCheck.pm, **When** examining imports, **Then** Fcntl uses `use Fcntl ();` with fully qualified constant names
3. **Given** RBLCheck.pm, **When** examining imports, **Then** unused modules like IPC::Open3 are removed
4. **Given** RBLCheck.pm, **When** examining code, **Then** Exporter machinery is removed (no @EXPORT_OK, @ISA)

---

### User Story 3 - Make Subroutines Private (Priority: P3)

As a developer, I need internal helper functions in RBLCheck.pm to be marked as private (with underscore prefix) so that the public API is clear and internal implementation details are not accidentally used by external code.

**Why this priority**: Clear API boundaries make the codebase easier to maintain and refactor. Private functions can be changed without breaking external consumers. This MUST happen before POD documentation so we only document the public API.

**Independent Test**: Verify that internal functions like `startoutput`, `addline`, `addtitle`, `endoutput`, and `getethdev` are renamed to `_startoutput`, `_addline`, `_addtitle`, `_endoutput`, and `_getethdev`.

**Acceptance Scenarios**:

1. **Given** RBLCheck.pm module, **When** examining the subroutine names, **Then** only `report()` is public (no underscore prefix)
2. **Given** RBLCheck.pm module, **When** examining helper functions, **Then** all are prefixed with underscore (`_`)
3. **Given** RBLCheck.pm module, **When** running `perl -cw`, **Then** all function calls use the updated private names

---

### User Story 4 - Add POD Documentation (Priority: P4)

As a developer working with the CSF codebase, I need RBLCheck.pm to have proper POD documentation for PUBLIC functions only, so that I can understand the module's purpose and public API without reading the implementation code.

**Why this priority**: Documentation improves developer productivity and reduces time spent understanding code. Required by cPanel coding standards. This story depends on P3 (private functions) being complete first so we only document the public API.

**Independent Test**: Run `perldoc lib/ConfigServer/RBLCheck.pm` and verify NAME, SYNOPSIS, DESCRIPTION, and METHODS sections are present and properly formatted.

**Acceptance Scenarios**:

1. **Given** RBLCheck.pm, **When** running `podchecker`, **Then** no warnings or errors are reported
2. **Given** RBLCheck.pm, **When** viewing with `perldoc`, **Then** NAME, SYNOPSIS, DESCRIPTION sections are visible
3. **Given** the public `report()` function, **When** viewing documentation, **Then** parameters, return values, and usage examples are documented

---

### User Story 5 - Add Unit Test Coverage (Priority: P5)

As a developer, I need unit tests for RBLCheck.pm so that I can verify the module works correctly and catch regressions when making changes.

**Why this priority**: Tests enable confident refactoring and prevent regressions. This story depends on P1-P4 being complete first.

**Independent Test**: Run `prove -wlvm t/ConfigServer-RBLCheck.t` and verify all tests pass.

**Acceptance Scenarios**:

1. **Given** the test file, **When** running with `prove`, **Then** all tests pass
2. **Given** the test file, **When** running with `perl -cw -Ilib`, **Then** no syntax errors or warnings
3. **Given** the tests, **When** checking coverage, **Then** the `report()` function is tested with mocked dependencies

---

### Edge Cases

- What happens when `/etc/csf/csf.rblconf` configuration file does not exist?
- What happens when RBL DNS lookup times out?
- What happens when server has no public IPv4 addresses?
- What happens when cached RBL results exist in `/var/lib/csf/{ip}.rbls`?
- How does the module handle IPv6 addresses (currently commented out)?

## Requirements *(mandatory)*

### Functional Requirements

#### Code Modernization

- **FR-001**: Module MUST NOT call `loadconfig()` at module load time (package level)
- **FR-002**: Module MUST use `ConfigServer::Config->get_config($key)` for individual config values instead of `%config` hash (unless accessing 10+ config values in a single function). **Note**: Currently N/A as %config is only used in commented-out IPv6 code; existing pattern in report() is acceptable
- **FR-002a**: Module MUST NOT store `$ipv4reg` and `$ipv6reg` as package-level globals; fetch them as local variables when needed using `ConfigServer::Config->ipv4reg` and `ConfigServer::Config->ipv6reg`
- **FR-003**: Module MUST use `use cPstrict;` instead of separate `use strict; use warnings;`
- **FR-004**: Module MUST remove `## no critic` line if no longer needed after modernization
- **FR-005**: Internal helper functions MUST be prefixed with underscore (`_`) to indicate private scope
- **FR-006**: Module MUST remove Exporter machinery (use Exporter, @ISA, @EXPORT_OK) when no exports are defined
- **FR-006a**: Module MUST remove unused imports (e.g., `IPC::Open3`)
- **FR-006b**: For non-ConfigServer modules (e.g., Fcntl), MUST disable imports with empty parens `use Fcntl ();` and use fully qualified names for constants (e.g., `Fcntl::LOCK_SH`). Note: `flock` is a Perl builtin, not a Fcntl function. ConfigServer:: module imports may retain their exports for now
- **FR-007**: Module MUST use `use Module ();` syntax for imports (disable auto-import) except where explicitly exporting
- **FR-008**: Module MUST preserve existing error handling behavior; error handling improvements deferred to future iteration

#### POD Documentation

- **FR-009**: Module MUST include NAME section with module name and brief description
- **FR-010**: Module MUST include SYNOPSIS section with usage example
- **FR-011**: Module MUST include DESCRIPTION section explaining module purpose
- **FR-012**: Public function `report()` MUST have POD documentation with parameters and return value
- **FR-013**: POD MUST pass `podchecker` without warnings or errors
- **FR-014**: POD MUST be placed after `package` declaration but before `use` statements (module-level) and immediately before subroutines (function-level)

#### Unit Tests

- **FR-015**: Test file MUST be named `t/ConfigServer-RBLCheck.t`
- **FR-016**: Test file MUST use shebang `#!/usr/local/cpanel/3rdparty/bin/perl`
- **FR-017**: Test file MUST use `Test2::V0` and `Test2::Plugin::NoWarnings`
- **FR-018**: Test file MUST use `MockConfig` to mock configuration values
- **FR-019**: Tests MUST verify module loads successfully
- **FR-020**: Tests MUST verify public subroutines exist
- **FR-021**: Tests MUST mock external dependencies (`ConfigServer::GetEthDev`, `ConfigServer::RBLLookup`, file I/O)
- **FR-022**: Tests MUST pass `perl -cw -Ilib` syntax check
- **FR-023**: Tests MUST pass when run with `prove -wlvm`

### Key Entities

- **RBLCheck.pm**: Module that checks server IP addresses against Real-time Blackhole Lists (RBLs) for spam/malware detection
- **report()**: Main public function that performs RBL checking and returns HTML-formatted results
- **RBL configuration**: Settings from `/etc/csf/csf.rblconf` and `/usr/local/csf/lib/csf.rbls`
- **IP cache files**: Cached RBL results stored in `/var/lib/csf/{ip}.rbls`

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Module compiles without requiring production configuration files (`perl -cw -Ilib lib/ConfigServer/RBLCheck.pm` succeeds in test environment)
- **SC-002**: All existing functionality continues to work (no behavioral regressions)
- **SC-003**: POD documentation passes `podchecker` with zero warnings or errors
- **SC-004**: New test file achieves at least 60% code coverage for the `report()` function logic
- **SC-005**: Test file passes `perl -cw -Ilib t/ConfigServer-RBLCheck.t` with no warnings
- **SC-006**: Test file passes `prove -wlvm t/ConfigServer-RBLCheck.t` with all tests passing
- **SC-007**: Running `make test` passes with no regressions to existing tests

## Clarifications

### Session 2026-01-22

- Q: Should we remove Exporter machinery entirely when @EXPORT_OK is empty? → A: Always remove exporter if no exports
- Q: How should package-level global variables be handled? → A: For ipv4reg and ipv6reg, populate a local var when they are needed. do not keep a global for them. For %config, we should switch to using ConfigServer::Config->get_config('...') if possible unless a subroutine accesses more than 10 vars. It's hard to know at this point if the globals need persistence so leave the rest defined that way
- Q: Should IPC::Open3 be removed from imports since it's not used? → A: Unused modules should not be loaded
- Q: Should ALL imports be converted to use empty parens and fully qualified names? → A: We want Non ConfigServer::Modules to not import so Fcntl should block imports and the constants should be referred to directly. remember that flock is a builtin function not a Fcntl sub. Leave ConfigServer exports alone for now.
- Q: What should error handling behavior be for missing config files or DNS timeout failures? → A: Keep the existing error handling for now don't attempt to modify behavior. this will come in a later iteration

## Assumptions

- The modernization follows the same pattern established in commits `7bd732d` and `15cdb5a` for CloudFlare.pm
- The IPv6 RBL checking code (currently commented out) will remain commented out and not be activated
- The module will continue to use HTML output format for the UI integration
- External dependencies (`ConfigServer::RBLLookup`, `ConfigServer::GetEthDev`) will be mocked in tests, not replaced
- The `/var/lib/csf/{ip}.rbls` caching mechanism will be preserved
