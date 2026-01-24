# Feature Specification: Modernize cseUI.pm

**Feature Branch**: `002-modernize-cseui`  
**Created**: 2026-01-23  
**Status**: Draft  
**Input**: User description: "Modernize cseUI.pm: Add cPstrict, remove global variables at module load time, add POD documentation and unit tests following the same pattern used for RBLCheck.pm modernization"

## User Scenarios & Testing *(mandatory)*

### User Story 0 - Remove Legacy Comment Clutter (Priority: P0)

As a developer, I need to remove legacy formatting comments from cseUI.pm so that the code follows clean formatting standards and matches the RBLCheck.pm pattern.

**Why this priority**: These legacy formatting comments clutter the code and serve no functional purpose. They should be removed before any other modernization work to establish a clean baseline.

**Context**: This is a one-time cleanup task, not a permanent rule against comments. Future developers may add useful comments as needed. The goal is to remove the specific legacy cruft that was common in older Perl code.

**What to remove**:
- All \`# start\` and \`# end\` comment markers
- All \`###...###\` divider lines between subroutines (but NOT the copyright header dividers at the top of the file)
- All \`# subroutine_name\` label comments immediately before function definitions (e.g., \`# loadconfig\` before \`sub _loadconfig\`)
- Standalone \`#\` empty comment lines that serve no purpose

**What to keep**:
- The copyright/license header at the top of the file
- Useful inline comments explaining complex logic
- Any comments that provide genuine value to future developers

**Acceptance Scenarios**:

1. **Given** cseUI.pm, **When** examining the code between subroutines, **Then** no \`# start\` or \`# end\` comment markers exist
2. **Given** cseUI.pm, **When** examining the code between subroutines, **Then** no \`###...###\` divider lines exist (only the 2 copyright header dividers at top of file remain)
3. **Given** cseUI.pm, **When** running \`perl -cw\`, **Then** the module still compiles successfully after comment removal

---

### User Story 1 - Remove Global Variables at Module Load Time (Priority: P1)

As a developer maintaining the CSF codebase, I need the cseUI.pm module to not call \`loadconfig()\` or access configuration at module load time, so that the module can be properly unit tested without requiring production configuration files.

**Why this priority**: Global variables populated at module load time prevent unit testing and can cause circular dependency issues. This is the foundation for all other improvements.

**Independent Test**: Run \`perl -cw -Ilib lib/ConfigServer/cseUI.pm\` and verify it compiles without requiring \`/etc/csf/csf.conf\` to exist.

**Acceptance Scenarios**:

1. **Given** cseUI.pm is loaded, **When** no configuration files exist, **Then** the module compiles successfully without errors
2. **Given** the \`main()\` function is called, **When** configuration is needed, **Then** configuration is loaded within the function scope (not at module load time)
3. **Given** cseUI.pm, **When** examining package-level code, **Then** no configuration loading occurs outside of subroutines

---

### User Story 2 - Code Modernization (Priority: P2)

As a developer, I need cseUI.pm to follow modern cPanel Perl coding standards (cPstrict, disabled imports, fully qualified names) so that the code is consistent with other modernized modules in the CSF codebase.

**Why this priority**: Standardized code patterns reduce cognitive load and make the codebase more maintainable. This modernization must happen before private function renaming.

**Independent Test**: Run \`perl -cw -Ilib lib/ConfigServer/cseUI.pm\` and verify it uses \`use cPstrict;\`, has disabled imports for non-ConfigServer modules, and has removed unused imports.

**Acceptance Scenarios**:

1. **Given** cseUI.pm, **When** examining the module header, **Then** it uses \`use cPstrict;\` instead of separate \`use strict;\`
2. **Given** cseUI.pm, **When** examining imports, **Then** Fcntl uses \`use Fcntl ();\` with fully qualified constant names
3. **Given** cseUI.pm, **When** examining imports, **Then** IPC::Open3 uses \`use IPC::Open3 ();\` with fully qualified function names
4. **Given** cseUI.pm, **When** examining imports, **Then** File::Find uses \`use File::Find ();\` with fully qualified function names
5. **Given** cseUI.pm, **When** examining imports, **Then** File::Copy uses \`use File::Copy ();\` with fully qualified function names
6. **Given** cseUI.pm, **When** examining code, **Then** Exporter machinery is removed (no @EXPORT_OK, @ISA)
7. **Given** cseUI.pm, **When** examining code, **Then** the \`## no critic\` line is removed or updated appropriately

---

### User Story 3 - Make Subroutines Private (Priority: P3)

As a developer, I need internal helper functions in cseUI.pm to be marked as private (with underscore prefix) so that the public API is clear and internal implementation details are not accidentally used by external code.

**Why this priority**: Clear API boundaries make the codebase easier to maintain and refactor. Private functions can be changed without breaking external consumers. This MUST happen before POD documentation so we only document the public API.

**Independent Test**: Verify that internal functions like \`browse\`, \`setp\`, \`seto\`, \`ren\`, \`moveit\`, \`copyit\`, \`mycopy\`, \`cnewd\`, \`cnewf\`, \`del\`, \`view\`, \`console\`, \`cd\`, \`edit\`, \`save\`, \`uploadfile\`, \`countfiles\`, and \`loadconfig\` are renamed with underscore prefix.

**Acceptance Scenarios**:

1. **Given** cseUI.pm module, **When** examining the subroutine names, **Then** only \`main()\` is public (no underscore prefix)
2. **Given** cseUI.pm module, **When** examining helper functions, **Then** all are prefixed with underscore (\`_\`)
3. **Given** cseUI.pm module, **When** running \`perl -cw\`, **Then** all internal function calls use the updated private names

---

### User Story 4 - Add POD Documentation (Priority: P4)

As a developer working with the CSF codebase, I need cseUI.pm to have proper POD documentation for PUBLIC functions only, so that I can understand the module's purpose and public API without reading the implementation code.

**Why this priority**: Documentation improves developer productivity and reduces time spent understanding code. Required by cPanel coding standards. This story depends on P3 (private functions) being complete first so we only document the public API.

**Independent Test**: Run \`perldoc lib/ConfigServer/cseUI.pm\` and verify NAME, SYNOPSIS, DESCRIPTION, and METHODS sections are present and properly formatted.

**Acceptance Scenarios**:

1. **Given** cseUI.pm, **When** running \`podchecker\`, **Then** no warnings or errors are reported
2. **Given** cseUI.pm, **When** viewing with \`perldoc\`, **Then** NAME, SYNOPSIS, DESCRIPTION sections are visible
3. **Given** the public \`main()\` function, **When** viewing documentation, **Then** parameters, return values, and usage examples are documented

---

### User Story 5 - Add Unit Test Coverage (Priority: P5)

As a developer, I need unit tests for cseUI.pm so that I can verify the module works correctly and catch regressions when making changes.

**Why this priority**: Tests enable confident refactoring and prevent regressions. This story depends on P1-P4 being complete first.

**Test Focus**: Tests should validate **actual module behavior** (functional testing), not meta-tests that check coding patterns. Since this is a modernization effort, validating coding patterns (e.g., checking for cPstrict usage in the source file) adds no value - the patterns are already enforced by the modernization process itself. Functional tests validate that the module works correctly.

**Independent Test**: Run \`prove -wlvm t/ConfigServer-cseUI.t\` and verify all tests pass.

**Acceptance Scenarios**:

1. **Given** the test file, **When** running with \`prove\`, **Then** all tests pass
2. **Given** the test file, **When** running with \`perl -cw -Ilib\`, **Then** no syntax errors or warnings
3. **Given** the tests, **When** checking coverage, **Then** the \`main()\` function is tested with mocked dependencies
4. **Given** the tests, **When** checking coverage, **Then** key helper functions are tested for core functionality

---

### Edge Cases

- What happens when \`/etc/csf/csf.conf\` configuration file does not exist?
- What happens when \`\$fileinc\` (file upload) contains malicious filenames?
- What happens when a user attempts directory traversal via \`\$FORM{p}\`?
- What happens when file permissions prevent read/write operations?
- What happens when the requested file or directory does not exist?
- How does the module handle files with special characters in names (quotes, pipes, backticks)?
- What happens when \`\$FORM{do}\` contains an unrecognized action?

## Requirements *(mandatory)*

### Functional Requirements

#### Code Modernization

- **FR-001**: Module MUST NOT call \`loadconfig()\` at module load time (package level)
- **FR-002**: Module MUST use \`use cPstrict;\` instead of separate \`use strict;\`
- **FR-003**: Module MUST remove \`## no critic\` line after modernization
- **FR-004**: Internal helper functions MUST be prefixed with underscore (\`_\`) to indicate private scope
- **FR-005**: Module MUST remove Exporter machinery (use Exporter, @ISA, @EXPORT_OK) since no exports are defined
- **FR-006**: For non-ConfigServer modules (Fcntl, IPC::Open3, File::Find, File::Copy), MUST disable imports with empty parens \`use Module ();\` and use fully qualified names (e.g., \`Fcntl::LOCK_SH\`, \`IPC::Open3::open3\`, \`File::Find::find\`, \`File::Copy::copy\`). Note: \`flock\`, \`sysopen\`, \`opendir\`, etc. are Perl builtins, not Fcntl functions
- **FR-007**: Module MUST preserve existing **working** error handling behavior; error handling improvements deferred to future iteration. **Exception**: Calls to undefined subroutines (pre-existing bugs) SHOULD be replaced with appropriate `die` or `warn` statements
- **FR-008**: All Perl 4-style subroutine calls (\`&subname\`) to **internal** functions MUST be converted to modern syntax (\`_subname()\`). Calls to undefined external functions are pre-existing bugs and SHOULD be fixed
- **FR-009**: Module MUST remove legacy comment clutter: (a) \`# start\`/\`# end\` markers, (b) \`###...###\` divider lines between subroutines (NOT the copyright header), (c) \`# subroutine_name\` labels before functions. This is a one-time cleanup task; useful comments may be added in the future.

#### Exit Calls (BLOCKING ISSUE)

- **FR-009a**: Production modules MUST NOT use \`exit\` statements. The \`exit\` function terminates the entire process, which:
  - Prevents unit testing (tests cannot run code that calls exit without forking)
  - Violates separation of concerns (modules should not control process lifecycle)
  - Makes the module unusable in long-running processes or mod_perl environments
  - **STOP AND CLARIFY**: If \`exit\` calls are discovered during modernization, implementation MUST pause to discuss refactoring options with the user before proceeding. Options include:
    - (a) Replace \`exit\` with \`return\` and document that caller is responsible for exiting
    - (b) Add a testable flag/parameter that controls whether to exit
    - (c) Throw an exception that the caller can catch
    - (d) Accept the limitation and document that functional testing requires forking (current workaround)
  - **Current Status**: cseUI.pm contains \`exit\` calls in \`main()\` (lines 131 and 224). This is a known limitation that blocks proper functional testing. The current test file uses forking as a workaround, but this is not ideal.

#### Global Variables

- **FR-010**: Package-level \`our\` variables that are only used within \`main()\` scope SHOULD be converted to \`my\` variables within \`main()\`
- **FR-011**: The \`%config\` hash MUST be populated by calling \`_loadconfig()\` within \`main()\`, not at package level
- **FR-012**: Form variables (\`%FORM\`, \`\$script\`, \`\$images\`, etc.) MUST be passed as parameters or initialized within \`main()\`

#### POD Documentation

- **FR-013**: Module MUST include NAME section with module name and brief description
- **FR-014**: Module MUST include SYNOPSIS section with usage example
- **FR-015**: Module MUST include DESCRIPTION section explaining module purpose
- **FR-016**: Public function \`main()\` MUST have POD documentation with parameters and return value
- **FR-017**: POD MUST pass \`podchecker\` without warnings or errors
- **FR-018**: POD MUST be placed after \`package\` declaration but before \`use\` statements (module-level) and immediately before subroutines (function-level)

#### Unit Tests

- **FR-019**: Test file MUST be named \`t/ConfigServer-cseUI.t\`
- **FR-020**: Test file MUST use shebang \`#!/usr/local/cpanel/3rdparty/bin/perl\`
- **FR-021**: Test file MUST use standardized header: \`cPstrict\`, \`Test2::V0\`, \`Test2::Tools::Explain\`, \`Test2::Plugin::NoWarnings\`, \`use lib 't/lib'\`, \`MockConfig\`
- **FR-022**: Test file MUST use \`MockConfig\` to mock configuration values
- **FR-023**: Tests MUST verify module loads successfully
- **FR-024**: Tests MUST verify public subroutines exist
- **FR-025**: Tests MUST mock external dependencies (file I/O, directory operations)
- **FR-026**: Tests MUST pass \`perl -cw -Ilib\` syntax check
- **FR-027**: Tests MUST pass when run with \`prove -wlvm\`

### Key Entities

- **cseUI.pm**: ConfigServer Explorer UI module providing a web-based file manager interface
- **main()**: Main public entry point that processes form input and dispatches to appropriate action handlers
- **Action handlers**: Internal functions (\`_browse\`, \`_edit\`, \`_save\`, \`_del\`, etc.) that perform file/directory operations
- **%config**: Configuration hash loaded from \`/etc/csf/csf.conf\`
- **%FORM**: Form data hash containing user input (action, path, filename, etc.)

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Module compiles without requiring production configuration files (\`perl -cw -Ilib lib/ConfigServer/cseUI.pm\` succeeds in test environment)
- **SC-002**: All existing functionality continues to work (no behavioral regressions)
- **SC-003**: POD documentation passes \`podchecker\` with zero warnings or errors
- **SC-004**: New test file achieves at least 60% code coverage for the \`main()\` function dispatch logic
- **SC-005**: Test file passes \`perl -cw -Ilib t/ConfigServer-cseUI.t\` with no warnings
- **SC-006**: Test file passes \`prove -wlvm t/ConfigServer-cseUI.t\` with all tests passing
- **SC-007**: Running \`make test\` passes with no regressions to existing tests
- **SC-008**: No Perl 4-style subroutine calls (\`&subname\`) remain in the module
- **SC-009**: No inter-subroutine \`# start\` / \`# end\` comment markers remain

## Assumptions

- The modernization follows the same pattern established for RBLCheck.pm modernization
- The module will continue to use HTML output format for the UI integration
- External file system operations will be mocked in tests, not actually performed
- The module's security-sensitive operations (file upload, delete, chmod, chown) will have their existing validation preserved
- The \`/etc/csf/csf.conf\` configuration loading pattern will be preserved but moved into the \`main()\` function scope
