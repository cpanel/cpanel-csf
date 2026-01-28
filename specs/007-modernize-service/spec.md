# Feature Specification: Modernize ConfigServer::Service.pm

**Case Number**: CSF-007  
**Feature Branch**: `007-modernize-service`  
**Created**: 2026-01-28  
**Status**: Draft  
**Input**: Modernize ConfigServer::Service.pm following current Perl best practices

## User Scenarios & Testing

### User Story 0 - Remove Legacy Comment Clutter (Priority: P0)

As a maintainer, I need the module free of legacy comment markers (# start/# end, ###...### dividers) that clutter the code and serve no documentation purpose.

**Why this priority**: Foundational cleanup - must be done before any other modernization to ensure clean baseline.

**Independent Test**: Grep for `# start`, `# end`, `###...###` patterns between subroutines. Module compiles after cleanup.

**Acceptance Scenarios**:

1. **Given** the Service.pm module, **When** searching for `# start` or `# end` comment markers, **Then** none are found (except in POD examples if applicable)
2. **Given** the Service.pm module, **When** searching for `###...###` dividers between functions, **Then** none are found (except the copyright header)
3. **Given** the Service.pm module, **When** searching for `## no critic` directives, **Then** none are found

---

### User Story 1 - Code Modernization (Priority: P1) 🎯 MVP

As a developer, I need the module to follow modern Perl practices: use cPstrict, no package-level side effects, disabled imports, no Exporter machinery, and fully qualified function calls.

**Why this priority**: Core modernization that enables testability and removes implicit dependencies.

**Independent Test**: `perl -cw -Ilib lib/ConfigServer/Service.pm` passes, no package-level `loadconfig()` exists, module can be loaded without side effects.

**Acceptance Scenarios**:

1. **Given** the module, **When** loading it, **Then** no package-level configuration is loaded automatically
2. **Given** the module, **When** loading it, **Then** no package-level file access to /proc/1/comm occurs
3. **Given** the module uses external functions, **When** calling them, **Then** all use fully qualified names
4. **Given** the module imports other modules, **When** examining use statements, **Then** all imports are disabled with `()` except those needing class methods
5. **Given** the module, **When** checking for Exporter, **Then** no `@EXPORT_OK`, `@ISA`, or `use Exporter` exists
6. **Given** the module, **When** checking for `use lib`, **Then** no hardcoded lib path exists
7. **Given** the module, **When** checking for cPstrict, **Then** `use cPstrict;` is used instead of `use strict;`

---

### User Story 2 - Make Internal Subroutines Private (Priority: P2)

As a developer, I need to distinguish between the module's public API and internal helper functions by marking internal functions with underscore prefixes.

**Why this priority**: API clarity - makes it obvious which functions are meant for external use.

**Independent Test**: Public API (`type`, `startlfd`, `stoplfd`, `restartlfd`, `statuslfd`) have no underscore, internal helper (`printcmd`) uses `_printcmd` naming.

**Acceptance Scenarios**:

1. **Given** the module has `type()` function, **When** checking its name, **Then** it remains `type` (public API)
2. **Given** the module has `startlfd()` function, **When** checking its name, **Then** it remains `startlfd` (public API)
3. **Given** the module has `stoplfd()` function, **When** checking its name, **Then** it remains `stoplfd` (public API)
4. **Given** the module has `restartlfd()` function, **When** checking its name, **Then** it remains `restartlfd` (public API)
5. **Given** the module has `statuslfd()` function, **When** checking its name, **Then** it remains `statuslfd` (public API)
6. **Given** the module has `printcmd()` helper, **When** refactoring, **Then** it is renamed to `_printcmd` (private)
7. **Given** internal function renamed, **When** called from within module, **Then** calls are updated to use new name

---

### User Story 3 - Add POD Documentation (Priority: P3)

As a developer, I need comprehensive POD documentation explaining what the module does, how to use it, and what each function accepts/returns.

**Why this priority**: Essential for maintainability and onboarding new developers.

**Independent Test**: `podchecker lib/ConfigServer/Service.pm` reports no errors, `perldoc lib/ConfigServer/Service.pm` displays complete documentation.

**Acceptance Scenarios**:

1. **Given** the module, **When** running podchecker, **Then** it reports "pod syntax OK"
2. **Given** the module, **When** viewing with perldoc, **Then** it shows NAME, SYNOPSIS, DESCRIPTION sections
3. **Given** each public function, **When** reading its POD, **Then** parameters, return values, and usage are documented
4. **Given** the module POD, **When** checking for completeness, **Then** it includes SEE ALSO section

---

### User Story 4 - Add Unit Test Coverage (Priority: P4)

As a developer, I need comprehensive unit tests with mocked external dependencies (system calls, process spawning) to verify the module works correctly in isolation.

**Why this priority**: Enables safe refactoring and prevents regressions.

**Independent Test**: `PERL5LIB='' prove -wlvm t/ConfigServer-Service.t` passes with all scenarios covered.

**Acceptance Scenarios**:

1. **Given** a test file, **When** running it, **Then** it loads the module without executing package-level side effects
2. **Given** tests for type(), **When** mocking sysinit detection, **Then** systemd and init paths are tested without accessing /proc
3. **Given** tests for startlfd(), **When** mocking command execution, **Then** systemd and init paths are tested without spawning processes
4. **Given** tests for stoplfd(), **When** mocking command execution, **Then** systemd and init paths are tested without spawning processes
5. **Given** tests for restartlfd(), **When** mocking command execution, **Then** systemd and init paths are tested without spawning processes
6. **Given** tests for statuslfd(), **When** mocking command execution, **Then** systemd and init paths are tested without spawning processes
7. **Given** tests for _printcmd(), **When** mocking IPC::Open3, **Then** command output capture is tested

---

### Edge Cases

- What happens when `/proc/1/comm` is not readable?
- What happens when `SYSTEMCTL` config value is missing?
- How does the module handle missing init scripts?
- What happens when IPC::Open3 fails to spawn the command?

## Requirements

### Functional Requirements

- **FR-001**: Module MUST compile without errors using `perl -cw -Ilib`
- **FR-002**: Module MUST NOT execute `loadconfig()` at package level
- **FR-003**: Module MUST NOT access `/proc/1/comm` at package level
- **FR-004**: Module MUST use `use cPstrict;` instead of `use strict;`
- **FR-005**: Module MUST disable all imports (use `()` syntax)
- **FR-006**: Module MUST NOT use Exporter machinery (`@EXPORT_OK`, `@ISA`, `use Exporter`)
- **FR-007**: Module MUST NOT have hardcoded `use lib` paths
- **FR-008**: Module MUST use fully qualified names for all external function calls (e.g., `Fcntl::LOCK_SH()`)
- **FR-009**: Module MUST NOT contain legacy comment markers (`# start`, `# end`, `###...###` dividers)
- **FR-010**: Module MUST NOT contain `## no critic` directives
- **FR-011**: Module MUST have comprehensive POD documentation
- **FR-012**: Module MUST mark internal helper function with underscore prefix (`_printcmd`)
- **FR-013**: Module MUST have unit tests covering all code paths
- **FR-014**: Module MUST preserve all existing functionality and behavior
- **FR-015**: Module MUST NOT use Perl 4 ampersand syntax (`&function`)

### Key Entities

- **Init System**: Either "systemd" or "init" based on /proc/1/comm detection
- **LFD Service**: The lfd daemon that is started/stopped/restarted
- **Configuration**: CSF configuration containing SYSTEMCTL path

## Success Criteria

### Measurable Outcomes

- **SC-001**: Module compiles without errors: `perl -cw -Ilib lib/ConfigServer/Service.pm`
- **SC-002**: No package-level loadconfig: `grep -n 'loadconfig' lib/ConfigServer/Service.pm | grep -v 'sub\|#'` returns no results outside functions
- **SC-003**: No package-level /proc access: `grep -n '/proc/1/comm' lib/ConfigServer/Service.pm` only in helper function
- **SC-004**: No legacy comment markers: `grep -E '# (start|end) ' lib/ConfigServer/Service.pm` returns no results
- **SC-005**: POD validation passes: `podchecker lib/ConfigServer/Service.pm` reports OK
- **SC-006**: Unit tests pass: `PERL5LIB='' prove -wlvm t/ConfigServer-Service.t` exits 0
- **SC-007**: No Exporter machinery: `grep -E '@EXPORT|@ISA|use Exporter' lib/ConfigServer/Service.pm` returns no results
- **SC-008**: Disabled imports verified: All `use` statements have `()` parameter
- **SC-009**: All test files pass: `make test` completes successfully
- **SC-010**: Private function renamed: `grep 'sub _printcmd' lib/ConfigServer/Service.pm` finds the renamed function
- **SC-011**: Uses cPstrict: `grep 'use cPstrict' lib/ConfigServer/Service.pm` finds the pragma

## Scope

### In Scope

- Remove legacy comment clutter (# start, # end, ###...###, ## no critic)
- Replace `use strict` with `use cPstrict`
- Remove `use lib '/usr/local/csf/lib'`
- Disable imports (add `()` to all use statements)
- Remove Exporter machinery
- Remove package-level configuration loading
- Remove package-level /proc/1/comm file access
- Create `_get_init_type()` helper with lazy initialization
- Update to fully qualified function calls (Fcntl::LOCK_SH())
- Rename internal helper `printcmd` to `_printcmd`
- Remove Perl 4 ampersand syntax from function calls
- Add comprehensive POD documentation
- Create unit test file with mocked dependencies
- Preserve all existing functionality

### Out of Scope

- Changing the service management mechanism (systemd vs init)
- Adding new service management features
- Changing function signatures or return values
- Performance optimizations
- Changing configuration format or options

## Dependencies

- **ConfigServer::Config**: Required for configuration access (SYSTEMCTL path)
- **ConfigServer::Slurp**: Can be used for reading /proc/1/comm file
- **IPC::Open3**: Used for command execution (from core Perl)
- **Fcntl**: Used for file locking constants (from core Perl)
- **Carp**: Used for warnings (from core Perl)
- **Test2::V0**: Required for unit tests
- **MockConfig**: Test utility for mocking configuration

## Assumptions

- The module's service management functionality is critical and must not be broken
- Both systemd and init paths must continue working
- The SYSTEMCTL config value is always set when using systemd
- The /proc/1/comm file exists on all supported systems
- The init script path (/etc/init.d/lfd) is correct for non-systemd systems

## Notes

### Package-Level Variables Analysis

The module currently has package-level initialization:
- `$config` and `%config` - Config loading at package level
- `$sysinit` - Determined by reading /proc/1/comm at package level

These cause the following issues:
1. Config is loaded even when module is just imported
2. /proc filesystem is accessed at module load time
3. Tests cannot mock the init system type

### Functions Analysis

Public API (keep names):
- `type()` - Returns init system type
- `startlfd()` - Starts lfd service
- `stoplfd()` - Stops lfd service
- `restartlfd()` - Restarts lfd service
- `statuslfd()` - Shows lfd status

Private helpers (rename with underscore):
- `printcmd(@command)` → `_printcmd(@command)` - Execute and print command output

### Modernization Pattern

Following the same pattern as Sendmail.pm:
1. Remove legacy comments
2. Add cPstrict
3. Remove use lib
4. Disable all imports with ()
5. Remove Exporter machinery
6. Create lazy init helper for sysinit detection
7. Move config access to function level
8. Rename internal helpers with underscore prefix
9. Remove ampersand syntax (&printcmd → _printcmd)
10. Add POD documentation
11. Create unit tests
