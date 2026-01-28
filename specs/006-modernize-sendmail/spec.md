# Feature Specification: Modernize ConfigServer::Sendmail.pm

**Case Number**: CSF-006  
**Feature Branch**: `006-modernize-sendmail`  
**Created**: 2026-01-28  
**Status**: Draft  
**Input**: Modernize ConfigServer::Sendmail.pm following current Perl best practices

## User Scenarios & Testing

### User Story 0 - Remove Legacy Comment Clutter (Priority: P0)

As a maintainer, I need the module free of legacy comment markers (# start/# end, ###...### dividers) that clutter the code and serve no documentation purpose.

**Why this priority**: Foundational cleanup - must be done before any other modernization to ensure clean baseline.

**Independent Test**: Grep for `# start`, `# end`, `###...###` patterns between subroutines. Module compiles after cleanup.

**Acceptance Scenarios**:

1. **Given** the Sendmail.pm module, **When** searching for `# start` or `# end` comment markers, **Then** none are found (except in POD examples if applicable)
2. **Given** the Sendmail.pm module, **When** searching for `###...###` dividers between functions, **Then** none are found (except the copyright header)

---

### User Story 1 - Code Modernization (Priority: P1) 🎯 MVP

As a developer, I need the module to follow modern Perl practices: no package-level side effects, disabled imports, no Exporter machinery, and fully qualified function calls.

**Why this priority**: Core modernization that enables testability and removes implicit dependencies.

**Independent Test**: `perl -cw -Ilib lib/ConfigServer/Sendmail.pm` passes, no package-level `loadconfig()` exists, module can be loaded without side effects.

**Acceptance Scenarios**:

1. **Given** the module, **When** loading it, **Then** no package-level configuration is loaded automatically
2. **Given** the module uses external functions, **When** calling them, **Then** all use fully qualified names (e.g., `ConfigServer::Slurp::slurp()`)
3. **Given** the module imports other modules, **When** examining use statements, **Then** all imports are disabled with `()` except those needing class methods
4. **Given** the module, **When** checking for Exporter, **Then** no `@EXPORT_OK`, `@ISA`, or `use Exporter` exists
5. **Given** package-level variables exist (hostname, timezone), **When** refactoring, **Then** they are moved to function scope or lazily initialized

---

### User Story 2 - Make Internal Subroutines Private (Priority: P2)

As a developer, I need to distinguish between the module's public API and internal helper functions by marking internal functions with underscore prefixes.

**Why this priority**: API clarity - makes it obvious which functions are meant for external use.

**Independent Test**: Public API (`relay`) has no underscore, internal helpers (`wraptext`) use `_wraptext` naming.

**Acceptance Scenarios**:

1. **Given** the module has `relay()` function, **When** checking its name, **Then** it remains `relay` (public API)
2. **Given** the module has `wraptext()` helper, **When** refactoring, **Then** it is renamed to `_wraptext` (private)
3. **Given** internal function renamed, **When** called from within module, **Then** calls are updated to use new name

---

### User Story 3 - Add POD Documentation (Priority: P3)

As a developer, I need comprehensive POD documentation explaining what the module does, how to use it, and what each function accepts/returns.

**Why this priority**: Essential for maintainability and onboarding new developers.

**Independent Test**: `podchecker lib/ConfigServer/Sendmail.pm` reports no errors, `perldoc lib/ConfigServer/Sendmail.pm` displays complete documentation.

**Acceptance Scenarios**:

1. **Given** the module, **When** running podchecker, **Then** it reports "pod syntax OK"
2. **Given** the module, **When** viewing with perldoc, **Then** it shows NAME, SYNOPSIS, DESCRIPTION sections
3. **Given** the relay() function, **When** reading its POD, **Then** parameters, return values, and usage examples are documented
4. **Given** the module POD, **When** checking for completeness, **Then** it includes VERSION, AUTHOR, COPYRIGHT sections

---

### User Story 4 - Add Unit Test Coverage (Priority: P4)

As a developer, I need comprehensive unit tests with mocked external dependencies (Net::SMTP, sendmail binary, filesystem) to verify the module works correctly in isolation.

**Why this priority**: Enables safe refactoring and prevents regressions.

**Independent Test**: `PERL5LIB='' prove -wlvm t/ConfigServer-Sendmail.t` passes with all scenarios covered.

**Acceptance Scenarios**:

1. **Given** a test file, **When** running it, **Then** it loads the module without executing package-level side effects
2. **Given** tests for relay(), **When** mocking Net::SMTP, **Then** SMTP delivery path is tested without network calls
3. **Given** tests for relay(), **When** mocking sendmail binary, **Then** sendmail delivery path is tested without spawning processes
4. **Given** tests for relay(), **When** providing email addresses, **Then** address sanitization is verified
5. **Given** tests for _wraptext(), **When** providing long text, **Then** text wrapping behavior is verified
6. **Given** hostname/timezone functionality, **When** mocking filesystem, **Then** these values are testable without /proc access

---

### Edge Cases

- What happens when `LF_ALERT_SMTP` is set but Net::SMTP cannot connect?
- How does the module handle missing `/proc/sys/kernel/hostname`?
- What happens if sendmail binary path is invalid or not executable?
- How does `_wraptext()` handle edge cases: empty strings, text shorter than column width, infinite loop prevention?
- What happens when email addresses contain invalid characters?

## Requirements

### Functional Requirements

- **FR-001**: Module MUST compile without errors using `perl -cw -Ilib`
- **FR-002**: Module MUST NOT execute `loadconfig()` at package level
- **FR-003**: Module MUST disable all imports except those needing class methods (ConfigServer::Config)
- **FR-004**: Module MUST NOT use Exporter machinery (`@EXPORT_OK`, `@ISA`, `use Exporter`)
- **FR-005**: Module MUST use fully qualified names for all external function calls
- **FR-006**: Module MUST NOT contain legacy comment markers (`# start`, `# end`, `###...###` dividers)
- **FR-007**: Module MUST have comprehensive POD documentation
- **FR-008**: Module MUST mark internal helper functions with underscore prefix (`_wraptext`)
- **FR-009**: Module MUST have unit tests covering all code paths
- **FR-010**: Module MUST preserve all existing functionality and behavior
- **FR-011**: Package-level variables (hostname, timezone) MUST be refactored to avoid side effects
- **FR-012**: Conditional Net::SMTP import MUST be handled without package-level execution

### Key Entities

- **Email Message**: Represents an email with from/to addresses, headers, and body content
- **Configuration**: CSF configuration controlling SMTP vs sendmail delivery, alert recipients
- **SMTP Connection**: Net::SMTP connection object when using SMTP delivery
- **Sendmail Process**: External sendmail binary process when using sendmail delivery

## Success Criteria

### Measurable Outcomes

- **SC-001**: Module compiles without errors: `perl -cw -Ilib lib/ConfigServer/Sendmail.pm`
- **SC-002**: No package-level loadconfig: `grep -n 'loadconfig' lib/ConfigServer/Sendmail.pm | grep -v 'sub\|#'` returns no results
- **SC-003**: No legacy comment markers: `grep -E '# (start|end) ' lib/ConfigServer/Sendmail.pm` returns no results
- **SC-004**: POD validation passes: `podchecker lib/ConfigServer/Sendmail.pm` reports OK
- **SC-005**: Unit tests pass: `PERL5LIB='' prove -wlvm t/ConfigServer-Sendmail.t` exits 0
- **SC-006**: No Exporter machinery: `grep -E '@EXPORT|@ISA|use Exporter' lib/ConfigServer/Sendmail.pm` returns no results (excluding imports in POD examples)
- **SC-007**: Disabled imports verified: All `use` statements except ConfigServer::Config have `()` parameter
- **SC-008**: All test files pass: `make test` completes successfully (20+ files)
- **SC-009**: Existing functionality preserved: Module behavior identical to pre-modernization (verified via integration tests or manual testing)
- **SC-010**: Private functions renamed: `grep 'sub _wraptext' lib/ConfigServer/Sendmail.pm` finds the renamed function

## Scope

### In Scope

- Remove legacy comment clutter
- Disable imports (except those needing class methods)
- Remove Exporter machinery
- Remove package-level configuration loading
- Refactor package-level variables (hostname, timezone)
- Update to fully qualified function calls
- Rename internal helper functions with underscore prefix
- Add comprehensive POD documentation
- Create unit test file with mocked dependencies
- Preserve all existing functionality

### Out of Scope

- Changing the email delivery mechanism (SMTP vs sendmail)
- Modifying the wraptext algorithm
- Adding new features or capabilities
- Changing function signatures or return values
- Performance optimizations
- Changing configuration format or options

## Dependencies

- **ConfigServer::Config**: Required for configuration access (class methods)
- **ConfigServer::Slurp**: Used for reading hostname file (simpler than manual open/flock)
- **ConfigServer::CheckIP**: Not needed (was imported but never used, removed)
- **Net::SMTP**: Conditionally loaded for SMTP delivery
- **POSIX**: Used for strftime (timezone formatting)
- **Carp**: Used for warning messages
- **Test2::V0**: Required for unit tests
- **MockConfig**: Test utility for mocking configuration

## Assumptions

- The module's email delivery functionality is critical and must not be broken
- SMTP and sendmail delivery paths must both continue working
- Email address sanitization logic must be preserved exactly
- Text wrapping behavior must remain unchanged
- Hostname detection from /proc is acceptable for now
- The infinite loop protection in wraptext (1000 iterations) is intentional
- Configuration values (LF_ALERT_SMTP, LF_ALERT_TO, LF_ALERT_FROM, SENDMAIL, DEBUG) remain available via ConfigServer::Config

## Notes

### Package-Level Variables Analysis

The module currently has package-level initialization:
- `$config` and `%config` - Move to lazy initialization within functions
- `$tz` - Timezone string - Move to function scope or lazy init
- `$hostname` - System hostname - Move to function scope or lazy init  
- Conditional Net::SMTP require/import - Handle without package-level execution

### Functions Analysis

- `relay($to, $from, @message)` - Public API, keeps name
- `wraptext($text, $column)` - Internal helper, rename to `_wraptext`

### Import Analysis

- `Carp` - Disable: `use Carp ();`
- `POSIX qw(strftime)` - Disable: `use POSIX ();` → use `POSIX::strftime()`
- `ConfigServer::Slurp` - Add: `use ConfigServer::Slurp ();` → use `ConfigServer::Slurp::slurp()`
- `ConfigServer::Config` - Keep enabled (class methods needed)
- `ConfigServer::CheckIP qw(checkip)` - Remove entirely (imported but never used)
- `Exporter qw(import)` - Remove entirely
- `Net::SMTP` - Conditional require/import - refactor to lazy loading in function

### Test Mocking Strategy

- Mock ConfigServer::Config for configuration values
- Mock Net::SMTP to test SMTP delivery without network
- Mock IPC::Open3 or similar for sendmail binary execution
- Mock filesystem reads for hostname detection
- Mock time functions if needed for timezone testing
