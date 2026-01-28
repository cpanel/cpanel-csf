# Feature Specification: Modernize RBLLookup.pm

**Feature Branch**: `005-modernize-rbllookup`  
**Created**: 2026-01-24  
**Status**: Draft  
**Input**: User description: "Modernize RBLLookup.pm: Add strict/warnings, remove global variables at module load time, add POD documentation and unit tests following the same pattern used for Ports.pm modernization"

## User Scenarios & Testing *(mandatory)*

### User Story 0 - Remove Legacy Comment Clutter (Priority: P0)

As a developer, I need to remove legacy formatting comments from RBLLookup.pm so that the code follows clean formatting standards and matches the pattern used in other modernized modules.

**Why this priority**: These legacy formatting comments clutter the code and serve no functional purpose. They should be removed before any other modernization work to establish a clean baseline.

**Context**: This is a one-time cleanup task, not a permanent rule against comments. Future developers may add useful comments as needed. The goal is to remove the specific legacy cruft that was common in older Perl code.

**What to remove**:
- All `# start` and `# end` comment markers (e.g., `# start main`, `# end listening`)
- All `###...###` divider lines between subroutines (but NOT the copyright header dividers at the top of the file)
- All `## start`/`## end` comment markers
- Standalone `#` empty comment lines that serve no purpose

**What to keep**:
- The copyright/license header at the top of the file
- Useful inline comments explaining complex logic
- Any comments that provide genuine value to future developers

**Current State Analysis**: RBLLookup.pm does NOT contain legacy comment clutter - no `# start`/`# end` markers or `###...###` dividers exist between subroutines. Only the copyright header dividers exist at the top of the file.

**Acceptance Scenarios**:

1. **Given** RBLLookup.pm, **When** examining the code between subroutines, **Then** no `# start` or `# end` comment markers exist ✓ (already clean)
2. **Given** RBLLookup.pm, **When** examining the code between subroutines, **Then** no `###...###` divider lines exist (only the 2 copyright header dividers at top of file remain) ✓ (already clean)
3. **Given** RBLLookup.pm, **When** running `perl -cw`, **Then** the module still compiles successfully

---

### User Story 1 - Code Modernization (Priority: P1)

As a developer, I need RBLLookup.pm to follow modern Perl coding standards (remove global config loading at module load time, disabled imports, fully qualified names) so that the code is consistent with other modernized modules in the CSF codebase and is properly testable.

**Why this priority**: The module currently loads configuration at module load time via `my $config = ConfigServer::Config->loadconfig()` at the package level (lines 33-34), which makes unit testing difficult and causes unnecessary system calls during module compilation. This is the primary modernization issue.

**Independent Test**: Run `perl -cw -Ilib lib/ConfigServer/RBLLookup.pm` and verify it compiles without the global config loading, uses disabled imports for non-ConfigServer modules, and has removed unused imports.

**Acceptance Scenarios**:

1. **Given** RBLLookup.pm, **When** examining the module header, **Then** it uses `use cPstrict;` (which implies strict/warnings)
2. **Given** RBLLookup.pm, **When** examining the package-level code, **Then** `ConfigServer::Config->loadconfig()` is NOT called at module load time
3. **Given** RBLLookup.pm, **When** examining imports, **Then** Fcntl is removed entirely (it's currently importing `:DEFAULT :flock` but not using any Fcntl functions)
4. **Given** RBLLookup.pm, **When** examining imports, **Then** `use IPC::Open3;` is changed to `use IPC::Open3 ();`
5. **Given** RBLLookup.pm, **When** examining imports, **Then** `use Net::IP;` is changed to `use Net::IP ();`
6. **Given** RBLLookup.pm, **When** examining code, **Then** Exporter machinery is removed (no @EXPORT_OK, @ISA, use Exporter) since `rbllookup()` should be called with fully qualified name
7. **Given** RBLLookup.pm, **When** examining code, **Then** the `checkip` import is changed to use fully qualified `ConfigServer::CheckIP::checkip()`
8. **Given** RBLLookup.pm, **When** examining the `rbllookup()` function, **Then** `$config{HOST}` is accessed via `ConfigServer::Config->get_config('HOST')` instead of package-level hash

---

### User Story 2 - Make Internal Subroutines Private (Priority: P2)

As a developer, I need internal helper functions in RBLLookup.pm to be marked as private (with underscore prefix) so that the public API is clear and internal implementation details are not accidentally used by external code.

**Why this priority**: Clear API boundaries make the codebase easier to maintain and refactor. Private functions can be changed without breaking external consumers. This MUST happen before POD documentation so we only document the public API.

**Public API Analysis**:
- `rbllookup()` - Public: Performs RBL lookup for an IP address against a specified RBL domain

**Current State Analysis**: RBLLookup.pm has only ONE function (`rbllookup`) which is the public API. There are NO internal helper functions to make private.

**Acceptance Scenarios**:

1. **Given** RBLLookup.pm module, **When** examining the subroutine names, **Then** `rbllookup()` remains public (no underscore prefix) ✓ (no changes needed)
2. **Given** RBLLookup.pm module, **When** examining the code, **Then** no internal helper functions exist that need renaming ✓ (already clean)

---

### User Story 3 - Add POD Documentation (Priority: P3)

As a developer working with the CSF codebase, I need RBLLookup.pm to have proper POD documentation for PUBLIC functions only, so that I can understand the module's purpose and public API without reading the implementation code.

**Why this priority**: Documentation improves developer productivity and reduces time spent understanding code. This story depends on P2 (private functions) being complete first so we only document the public API. This module has only one public function so documentation is straightforward.

**Independent Test**: Run `perldoc lib/ConfigServer/RBLLookup.pm` and verify NAME, SYNOPSIS, DESCRIPTION, and FUNCTIONS sections are present and properly formatted.

**Acceptance Scenarios**:

1. **Given** RBLLookup.pm, **When** running `podchecker`, **Then** no warnings or errors are reported
2. **Given** RBLLookup.pm, **When** viewing with `perldoc`, **Then** NAME, SYNOPSIS, DESCRIPTION sections are visible
3. **Given** the `rbllookup()` function, **When** viewing documentation, **Then** parameters, return values, and usage examples are documented
4. **Given** the POD documentation, **When** examining content, **Then** it explains what RBL (Real-time Blackhole List) lookups are and how the function uses DNS queries

---

### User Story 4 - Add Unit Test Coverage (Priority: P4)

As a developer, I need unit tests for RBLLookup.pm so that I can verify the module works correctly and catch regressions when making changes.

**Why this priority**: Tests enable confident refactoring and prevent regressions. This story depends on P1-P3 being complete first so config can be properly mocked.

**Test Focus**: Tests should validate **actual module behavior** (functional testing), not meta-tests that check coding patterns. Since `rbllookup()` makes external DNS queries via the `host` command, tests will need to mock `IPC::Open3::open3` or use appropriate skip conditions.

**Testing Challenges**:
- `rbllookup()` calls external `host` command via `IPC::Open3::open3`
- DNS lookups depend on network availability and external RBL servers
- The function uses `alarm()` for timeout handling which can complicate testing

**Independent Test**: Run `prove -wlvm t/ConfigServer-RBLLookup.t` and verify all tests pass.

**Acceptance Scenarios**:

1. **Given** the test file, **When** running with `prove`, **Then** all tests pass
2. **Given** the test file, **When** running with `perl -cw -Ilib`, **Then** no syntax errors or warnings
3. **Given** the tests, **When** checking coverage, **Then** IP validation (valid/invalid IPs) is tested
4. **Given** the tests, **When** checking coverage, **Then** IPv4 and IPv6 address handling is tested
5. **Given** the tests, **When** checking coverage, **Then** timeout handling behavior is tested
6. **Given** the tests, **When** checking coverage, **Then** mocked DNS responses are tested for both A and TXT record lookups

---

### Edge Cases

- What happens when an invalid IP address is passed? **→ Return empty strings (no lookup performed)**
- What happens when the `host` command is not found? **→ Die or return timeout (current behavior preserved)**
- What happens when the DNS lookup times out? **→ Return "timeout" as the rblhit value, empty rblhittxt**
- What happens when the RBL server is unreachable? **→ Return empty strings (no match found)**
- What happens when Net::IP->new() fails for malformed IP? **→ Return empty strings (reversed_ip will be empty)**
- What happens when `$config{HOST}` (the host binary path) is not configured? **→ Die with error (fail-closed per constitution II)**
- What happens when the IP is listed on the RBL but has no TXT record? **→ Return rblhit with empty rblhittxt**

## Requirements *(mandatory)*

### Functional Requirements

#### Legacy Comment Cleanup (P0)

- **FR-000**: Module does NOT require legacy comment cleanup - no `# start`/`# end` markers or `###...###` dividers exist (verified clean)

#### Code Modernization (P1)

- **FR-001**: Module MUST remove package-level `ConfigServer::Config->loadconfig()` call (lines 33-34)
- **FR-002**: Module MUST remove package-level `%config` hash that stores loaded configuration
- **FR-003**: `rbllookup()` MUST use `ConfigServer::Config->get_config('HOST')` to access the host binary path
- **FR-004**: Module MUST remove `use Fcntl qw(:DEFAULT :flock);` entirely (Fcntl is not used in the code)
- **FR-005**: Module MUST use `use IPC::Open3 ();` with fully qualified `IPC::Open3::open3()` calls
- **FR-006**: Module MUST use `use Net::IP ();` with fully qualified `Net::IP->new()` calls (already OO-style)
- **FR-007**: Module MUST use `use ConfigServer::CheckIP ();` and call `ConfigServer::CheckIP::checkip()`
- **FR-008**: Module MUST remove Exporter machinery (use Exporter, @ISA, @EXPORT_OK) - function should be called fully qualified
- **FR-009**: Module SHOULD keep `$VERSION` for version tracking purposes

#### Private Subroutines (P2)

- **FR-009a**: No changes required - RBLLookup.pm has only one function (`rbllookup`) which is the public API; no internal helpers exist

#### Behavior Preservation

- **FR-010**: Module MUST preserve existing behavior of `rbllookup()` function
- **FR-011**: Module MUST preserve the 4-second timeout for DNS lookups
- **FR-012**: Module MUST preserve the return value format: `($rblhit, $rblhittxt)`
- **FR-013**: Module MUST preserve the IP reversal logic for both IPv4 and IPv6
- **FR-014**: Module MUST preserve the process cleanup logic (`kill(9, $cmdpid)`) for timed-out processes

#### Documentation

- **FR-015**: Module MUST include POD documentation with NAME, SYNOPSIS, DESCRIPTION sections
- **FR-016**: `rbllookup()` function MUST be documented with parameters (IP address, RBL domain) and return values
- **FR-017**: POD documentation SHOULD explain what RBL lookups are and the DNS query mechanism

#### Testing

- **FR-018**: Test file `t/ConfigServer-RBLLookup.t` MUST exist and pass
- **FR-019**: Tests MUST cover valid and invalid IP address inputs
- **FR-020**: Tests MUST cover both IPv4 and IPv6 address handling
- **FR-021**: Tests MUST mock external dependencies (IPC::Open3, ConfigServer::Config) for isolation
- **FR-022**: Tests SHOULD cover timeout scenarios

### Key Entities

- **$ip**: Input IP address to check against the RBL (IPv4 or IPv6 format)
- **$rbl**: The RBL domain name to query (e.g., "zen.spamhaus.org")
- **$rblhit**: Return value indicating the RBL listing status (IP address if listed, "timeout" on timeout, empty if not listed)
- **$rblhittxt**: Return value containing the TXT record explanation from the RBL (may be empty)
- **$reversed_ip**: Internally computed reversed IP address for DNS PTR-style lookup

## Clarifications

*No clarifications needed - requirements are clear based on the pattern established in 004-modernize-ports.*

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Module compiles without errors: `perl -cw -Ilib lib/ConfigServer/RBLLookup.pm` exits with code 0
- **SC-002**: No package-level `loadconfig()` call exists in the module
- **SC-003**: No legacy comment markers remain in the code (already clean - verification only)
- **SC-004**: POD documentation is valid: `podchecker lib/ConfigServer/RBLLookup.pm` reports no errors
- **SC-005**: All unit tests pass: `prove -wlvm t/ConfigServer-RBLLookup.t` exits with code 0
- **SC-006**: No Exporter machinery (@EXPORT_OK, @ISA, use Exporter) remains in the code
- **SC-007**: All imports use disabled import syntax `use Module ();` except for cPstrict
- **SC-008**: No unused imports remain (Fcntl removed entirely)
- **SC-009**: The `rbllookup()` function produces identical output for identical inputs before and after modernization
