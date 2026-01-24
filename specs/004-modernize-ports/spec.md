# Feature Specification: Modernize Ports.pm

**Feature Branch**: `004-modernize-ports`  
**Created**: 2026-01-24  
**Status**: Draft  
**Input**: User description: "Modernize Ports.pm: Add strict/warnings, remove global variables at module load time, add POD documentation and unit tests following the same pattern used for cseUI.pm modernization"

## User Scenarios & Testing *(mandatory)*

### User Story 0 - Remove Legacy Comment Clutter (Priority: P0)

As a developer, I need to remove legacy formatting comments from Ports.pm so that the code follows clean formatting standards and matches the pattern used in other modernized modules.

**Why this priority**: These legacy formatting comments clutter the code and serve no functional purpose. They should be removed before any other modernization work to establish a clean baseline.

**Context**: This is a one-time cleanup task, not a permanent rule against comments. Future developers may add useful comments as needed. The goal is to remove the specific legacy cruft that was common in older Perl code.

**What to remove**:
- All \`# start\` and \`# end\` comment markers (e.g., \`# start main\`, \`# end listening\`)
- All \`###...###\` divider lines between subroutines (but NOT the copyright header dividers at the top of the file)
- All \`## start\`/\`## end\` comment markers
- Standalone \`#\` empty comment lines that serve no purpose

**What to keep**:
- The copyright/license header at the top of the file
- Useful inline comments explaining complex logic (e.g., the \`##no critic\` on the \`%printable\` line can be removed after modernization)
- Any comments that provide genuine value to future developers

**Acceptance Scenarios**:

1. **Given** Ports.pm, **When** examining the code between subroutines, **Then** no \`# start\` or \`# end\` comment markers exist
2. **Given** Ports.pm, **When** examining the code between subroutines, **Then** no \`###...###\` divider lines exist (only the 2 copyright header dividers at top of file remain)
3. **Given** Ports.pm, **When** running \`perl -cw\`, **Then** the module still compiles successfully after comment removal

---

### User Story 1 - Code Modernization (Priority: P1)

As a developer, I need Ports.pm to follow modern Perl coding standards (strict, warnings, disabled imports, fully qualified names) so that the code is consistent with other modernized modules in the CSF codebase.

**Why this priority**: Standardized code patterns reduce cognitive load and make the codebase more maintainable. This modernization enables proper unit testing.

**Independent Test**: Run \`perl -cw -Ilib lib/ConfigServer/Ports.pm\` and verify it uses \`use strict;\` and \`use warnings;\`, has disabled imports for non-ConfigServer modules, and has removed unused imports.

**Acceptance Scenarios**:

1. **Given** Ports.pm, **When** examining the module header, **Then** it uses \`use strict;\` and \`use warnings;\`
2. **Given** Ports.pm, **When** examining the module header, **Then** the \`## no critic\` line is removed
3. **Given** Ports.pm, **When** examining imports, **Then** Fcntl uses \`use Fcntl ();\` with fully qualified constant names (e.g., \`Fcntl::LOCK_SH\`)
4. **Given** Ports.pm, **When** examining code, **Then** Exporter machinery is removed (no @EXPORT_OK, @ISA, use Exporter)
5. **Given** Ports.pm, **When** examining code, **Then** the hardcoded \`use lib '/usr/local/csf/lib';\` is removed (caller should set up @INC)
6. **Given** Ports.pm, **When** examining code, **Then** all Perl 4-style subroutine calls (\`&hex2ip\`) are converted to modern syntax (\`_hex2ip()\`)
7. **Given** Ports.pm, **When** examining code, **Then** bareword directory handles (\`PROCDIR\`, \`DIR\`) are replaced with lexical handles

---

### User Story 2 - Make Internal Subroutines Private (Priority: P2)

As a developer, I need internal helper functions in Ports.pm to be marked as private (with underscore prefix) so that the public API is clear and internal implementation details are not accidentally used by external code.

**Why this priority**: Clear API boundaries make the codebase easier to maintain and refactor. Private functions can be changed without breaking external consumers. This MUST happen before POD documentation so we only document the public API.

**Independent Test**: Verify that internal functions like \`hex2ip\` are renamed with underscore prefix.

**Public API Analysis**:
- \`listening()\` - Public: Returns hash of listening ports with process information
- \`openports()\` - Public: Returns hash of configured open ports from CSF config
- \`hex2ip()\` - Private: Internal helper to convert hex IP addresses

**Acceptance Scenarios**:

1. **Given** Ports.pm module, **When** examining the subroutine names, **Then** \`listening()\` and \`openports()\` remain public (no underscore prefix)
2. **Given** Ports.pm module, **When** examining helper functions, **Then** \`hex2ip\` is renamed to \`_hex2ip\`
3. **Given** Ports.pm module, **When** running \`perl -cw\`, **Then** all internal function calls use the updated private names

---

### User Story 3 - Add POD Documentation (Priority: P3)

As a developer working with the CSF codebase, I need Ports.pm to have proper POD documentation for PUBLIC functions only, so that I can understand the module's purpose and public API without reading the implementation code.

**Why this priority**: Documentation improves developer productivity and reduces time spent understanding code. This story depends on P2 (private functions) being complete first so we only document the public API.

**Independent Test**: Run \`perldoc lib/ConfigServer/Ports.pm\` and verify NAME, SYNOPSIS, DESCRIPTION, and METHODS sections are present and properly formatted.

**Acceptance Scenarios**:

1. **Given** Ports.pm, **When** running \`podchecker\`, **Then** no warnings or errors are reported
2. **Given** Ports.pm, **When** viewing with \`perldoc\`, **Then** NAME, SYNOPSIS, DESCRIPTION sections are visible
3. **Given** the public \`listening()\` function, **When** viewing documentation, **Then** parameters, return values, and usage examples are documented
4. **Given** the public \`openports()\` function, **When** viewing documentation, **Then** parameters, return values, and usage examples are documented

---

### User Story 4 - Add Unit Test Coverage (Priority: P4)

As a developer, I need unit tests for Ports.pm so that I can verify the module works correctly and catch regressions when making changes.

**Why this priority**: Tests enable confident refactoring and prevent regressions. This story depends on P1-P3 being complete first.

**Test Focus**: Tests should validate **actual module behavior** (functional testing), not meta-tests that check coding patterns. Since this is a modernization effort, validating coding patterns adds no value - the patterns are already enforced by the modernization process itself.

**Testing Challenges**:
- \`listening()\` reads from \`/proc/net/*\` and \`/proc/*/\` which requires root access and live system state
- \`openports()\` calls \`ConfigServer::Config->loadconfig()\` which requires CSF configuration files
- \`_hex2ip()\` is a pure function that can be easily unit tested

**Independent Test**: Run \`prove -wlvm t/ConfigServer-Ports.t\` and verify all tests pass.

**Acceptance Scenarios**:

1. **Given** the test file, **When** running with \`prove\`, **Then** all tests pass
2. **Given** the test file, **When** running with \`perl -cw -Ilib\`, **Then** no syntax errors or warnings
3. **Given** the tests, **When** checking coverage, **Then** the \`_hex2ip()\` function is tested with IPv4 and IPv6 inputs
4. **Given** the tests, **When** checking coverage, **Then** \`openports()\` is tested with mocked ConfigServer::Config
5. **Given** the tests, **When** checking coverage, **Then** \`listening()\` is tested with mocked /proc filesystem or appropriate skip conditions

---

### Edge Cases

- What happens when `/proc/net/tcp` or other network files are not readable? **→ Log warning, continue processing**
- What happens when `/proc/<pid>/fd` is not accessible (permission denied)? **→ Log warning, continue processing**
- What happens when a process exits between reading /proc/net and /proc/<pid>? **→ Silent skip (expected race)**
- What happens when `getpwuid()` returns an empty string for a UID? **→ Use numeric UID as fallback**
- What happens when CSF configuration keys (TCP_IN, UDP_IN, etc.) are missing or empty? **→ Die with error**
- What happens when port ranges are malformed (e.g., `100:50` where start > end)? **→ Skip silently (invalid range ignored)**
- How does `_hex2ip()` handle malformed hex input? **→ Return empty string**

## Requirements *(mandatory)*

### Functional Requirements

#### Code Modernization

- **FR-001**: Module MUST use \`use strict;\` and \`use warnings;\`
- **FR-002**: Module MUST remove \`## no critic\` line after modernization
- **FR-003**: Module MUST remove \`use lib '/usr/local/csf/lib';\` (caller sets up @INC)
- **FR-004**: Module MUST remove Exporter machinery (use Exporter, @ISA, @EXPORT_OK) since nothing is exported
- **FR-005**: Module MUST use \`use Fcntl ();\` with fully qualified constant names (e.g., \`Fcntl::LOCK_SH\`)
- **FR-005a**: Module SHOULD use `Cpanel::Slurp` (slurp or slurpee) for reading /proc files instead of manual open/flock/read patterns
- **FR-005b**: `openports()` MUST use `ConfigServer::Config->get_config($key)` for each config key instead of `loadconfig()`
- **FR-006**: All Perl 4-style subroutine calls (\`&hex2ip\`) MUST be converted to modern syntax (\`_hex2ip()\`)
- **FR-007**: All bareword directory handles (\`PROCDIR\`, \`DIR\`) MUST be replaced with lexical handles
- **FR-008**: Module MUST remove legacy comment clutter: (a) \`# start\`/\`# end\` markers, (b) \`###...###\` divider lines between subroutines (NOT the copyright header), (c) \`## start\`/\`## end\` markers
- **FR-009**: Internal helper function \`hex2ip\` MUST be renamed to \`_hex2ip\` to indicate private scope

#### Behavior Preservation

- **FR-010**: Module MUST preserve existing behavior of \`listening()\` function
- **FR-011**: Module MUST preserve existing behavior of \`openports()\` function
- **FR-012**: Module MUST preserve the \`%tcpstates\` lookup table at package level (these are constants)
- **FR-013**: Module MUST preserve the \`%printable\` escape map at package level (these are constants)

#### Documentation

- **FR-014**: Module MUST include POD documentation with NAME, SYNOPSIS, DESCRIPTION sections
- **FR-015**: Public functions \`listening()\` and \`openports()\` MUST be documented with parameters and return values

#### Testing

- **FR-016**: Test file \`t/ConfigServer-Ports.t\` MUST exist and pass
- **FR-017**: Tests MUST cover \`_hex2ip()\` with both IPv4 and IPv6 inputs
- **FR-018**: Tests MUST mock or skip tests requiring live \`/proc\` filesystem access
- **FR-019**: Tests MUST mock ConfigServer::Config for \`openports()\` testing

### Key Entities

- **%listen**: Nested hash returned by \`listening()\` - structure: \`{protocol}{port}{pid}{attribute}\`
- **%ports**: Nested hash returned by \`openports()\` - structure: \`{protocol}{port} = 1\`
- **%tcpstates**: Lookup table mapping hex TCP state codes to human-readable names
- **%printable**: Escape map for sanitizing non-printable characters in command lines

## Clarifications

### Session 2026-01-24

- Q: When `/proc/net/tcp` or `/proc/<pid>/fd` is not readable (permission denied), what should happen? → A: Log a warning but continue processing
- Q: When CSF configuration keys (TCP_IN, UDP_IN, etc.) are missing or empty, what should happen? → A: Die with an error indicating required config is missing
- Q: When `_hex2ip()` receives malformed hex input, what should happen? → A: Return an empty string
- Q: How should file reading be handled for /proc/net files? → A: Use Cpanel::Slurp (slurp or slurpee as appropriate)
- Q: When a process exits between reading /proc/net and /proc/<pid>, what should happen? → A: Preserve silent skip (race conditions are expected)

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Module compiles without errors: \`perl -cw -Ilib lib/ConfigServer/Ports.pm\` exits with code 0
- **SC-002**: Module has no perlcritic violations at severity 5
- **SC-003**: POD documentation is valid: \`podchecker lib/ConfigServer/Ports.pm\` reports no errors
- **SC-004**: All unit tests pass: \`prove -wlvm t/ConfigServer-Ports.t\` exits with code 0
- **SC-005**: No legacy comment markers remain in the code
- **SC-006**: No Perl 4-style subroutine calls (\`&function\`) remain in the code
- **SC-007**: No bareword filehandles or directory handles remain (except STDIN, STDOUT, STDERR)
