# Feature Specification: Modernize Sanity.pm Module

**Case Number**: CPANEL-51301  
**Feature Branch**: `009-modernize-sanity`  
**Created**: January 29, 2026  
**Status**: Draft  
**Input**: User description: "Update and modernize Sanity.pm with POD documentation and cleanup subroutine separators"

## User Scenarios & Testing *(mandatory)*

### User Story 0 - Remove Legacy Comment Clutter (Priority: P0)

As a maintainer, I need the module free of legacy comment markers (# start/# end, ###...### dividers) that clutter the code and serve no documentation purpose.

**Why this priority**: Foundational cleanup - must be done before any other modernization to ensure clean baseline.

**Independent Test**: Grep for `# start`, `# end`, `###...###` patterns between subroutines. Module compiles after cleanup.

**Acceptance Scenarios**:

1. **Given** the Sanity.pm module, **When** searching for `# start` or `# end` comment markers, **Then** none are found (except in POD examples if applicable)
2. **Given** the Sanity.pm module, **When** searching for `###...###` dividers between functions, **Then** none are found (except the copyright header)

---

### User Story 1 - Code Modernization (Priority: P1) 🎯 MVP

As a developer, I need the module to follow modern Perl practices: no package-level side effects, disabled imports, no Exporter machinery, and fully qualified function calls.

**Why this priority**: Core modernization that enables testability and removes implicit dependencies. The current compile-time loading of sanity.txt and config causes failures if files are missing and makes testing difficult.

**Independent Test**: `perl -cw -Ilib lib/ConfigServer/Sanity.pm` passes, no package-level file I/O exists, module can be loaded without side effects.

**Acceptance Scenarios**:

1. **Given** the module, **When** loading it, **Then** no sanity.txt file is read at compile time
2. **Given** the module, **When** loading it, **Then** no configuration is loaded at compile time
3. **Given** the module uses external functions, **When** calling them, **When** examining use statements, **Then** all imports are disabled with `()` except those needing class methods
4. **Given** the module, **When** checking for Exporter, **Then** no `@EXPORT_OK`, `@ISA`, or `use Exporter` exists
5. **Given** package-level variables exist (%sanity, %sanitydefault), **When** refactoring, **Then** they are moved to lexical scope within functions or lazily initialized on first use
6. **Given** sanity.txt needs to be read, **When** sanity() is first called, **Then** data is loaded lazily and cached

---

### User Story 2 - Add POD Documentation (Priority: P2)

As a developer, I need comprehensive POD documentation explaining what the module does, how to use it, and what each function accepts/returns.

**Why this priority**: Essential for maintainability and brings module in line with other modernized ConfigServer modules.

**Independent Test**: `podchecker lib/ConfigServer/Sanity.pm` reports no errors, `perldoc ConfigServer::Sanity` displays complete documentation.

**Acceptance Scenarios**:

1. **Given** the module, **When** running podchecker, **Then** it reports "pod syntax OK"
2. **Given** the module, **When** viewing with perldoc, **Then** it shows NAME, SYNOPSIS, DESCRIPTION sections at the top
3. **Given** the sanity() function, **When** reading its POD before the function, **Then** parameters, return values, and usage examples are documented
4. **Given** the module POD, **When** checking end-of-file sections, **Then** it includes SANITY CHECK FILE FORMAT, DEPENDENCIES, FILES, SEE ALSO, AUTHOR, COPYRIGHT sections
5. **Given** the module POD, **When** reading examples, **Then** at least 2 working code examples showing both range and discrete value validation exist

---

### User Story 3 - Add Unit Test Coverage (Priority: P3)

As a developer, I need comprehensive unit tests with mocked filesystem access to verify the module works correctly without requiring actual sanity.txt or csf.conf files.

**Why this priority**: Enables safe refactoring and prevents regressions, especially important after moving from compile-time to lazy-loading.

**Independent Test**: `PERL5LIB='' prove -wlvm t/ConfigServer-Sanity.t` passes with all scenarios covered.

**Acceptance Scenarios**:

1. **Given** a test file, **When** running it, **Then** it loads the module without reading sanity.txt at compile time
2. **Given** tests for sanity(), **When** mocking sanity.txt content, **Then** range validation (e.g., "0-100") is tested
3. **Given** tests for sanity(), **When** mocking sanity.txt content, **Then** discrete value validation (e.g., "0|1|2") is tested
4. **Given** tests for sanity(), **When** providing undefined sanity items, **Then** function returns sane (0) result
5. **Given** tests for sanity(), **When** IPSET is enabled, **Then** DENY_IP_LIMIT check is skipped
6. **Given** tests for sanity(), **When** sanity.txt is missing or unreadable, **Then** appropriate error handling occurs

---

### Edge Cases

- What happens when sanity.txt doesn't exist at module load time (should not fail)?
- What happens when sanity.txt doesn't exist when sanity() is first called (should fail gracefully)?
- How does the module handle malformed lines in sanity.txt?
- What happens if POD formatting contains special characters that could break perldoc rendering?
- What happens when a configuration item is checked that doesn't exist in sanity.txt?
- What if future modifications add new functions - will the POD template be clear enough for maintainers to follow?

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Module MUST NOT execute file I/O operations at compile time (no reading sanity.txt when module loads)
- **FR-002**: Module MUST lazy-load sanity.txt data on first call to sanity() function
- **FR-003**: Module MUST cache sanity.txt data after first load to avoid repeated file reads
- **FR-004**: Module MUST use fully qualified function calls (e.g., `ConfigServer::Config->loadconfig()` instead of importing)
- **FR-005**: Module MUST disable all imports with `()` except for modules needing class methods
- **FR-006**: Module MUST NOT use Exporter (remove @EXPORT_OK, @ISA, use Exporter)
- **FR-007**: Module MUST have all subroutine separator patterns (`# end xxx`, `###...`, `# start xxx`) removed
- **FR-008**: Module MUST maintain single blank line separation between functions after cleanup
- **FR-009**: Module MUST include module-level POD documentation positioned after the `package` declaration
- **FR-010**: Module MUST include function-level POD documentation positioned immediately before the `sanity()` function
- **FR-011**: Module MUST include end-of-file POD sections after `__END__` marker for supplementary information
- **FR-012**: POD MUST follow the structure: NAME, SYNOPSIS, DESCRIPTION (module-level), then function docs, then SANITY CHECK FILE FORMAT, DEPENDENCIES, FILES, SEE ALSO, AUTHOR, COPYRIGHT (end-of-file)
- **FR-013**: POD MUST include executable code examples that demonstrate actual usage
- **FR-014**: POD MUST document both the range validation (e.g., "0-100") and discrete value (e.g., "0|1|2") checking capabilities
- **FR-015**: POD MUST explain the sanity.txt file format with examples
- **FR-016**: POD MUST document the special IPSET handling for DENY_IP_LIMIT
- **FR-017**: Module MUST handle missing or unreadable sanity.txt file gracefully with appropriate error messages
- **FR-018**: Module MUST compile successfully with `perl -cw -Ilib lib/ConfigServer/Sanity.pm`

### Key Entities

- **sanity()**: The primary validation function that checks configuration values against acceptable ranges/values defined in sanity.txt. Lazy-loads data on first call.
- **sanity.txt**: Configuration file defining validation rules in format `ITEM_NAME=acceptable_values=default_value`
- **Module POD Sections**: Documentation organized into module-level (top), function-level (before functions), and supplementary (after __END__)
- **Lazy Loading**: Pattern where expensive operations (file I/O, config loading) are deferred until first actual use
- **State Cache**: Package-scoped lexical variables that cache loaded data across multiple function calls

## Success Criteria *(mandatory)*

- **SC-001**: Module loads successfully without reading any files (`perl -e 'use lib "lib"; use ConfigServer::Sanity; print "OK\n"'`)
- **SC-002**: Module compiles with warnings enabled: `perl -cw -Ilib lib/ConfigServer/Sanity.pm` exits 0
- **SC-003**: Developers can view complete module documentation using `perldoc ConfigServer::Sanity` command
- **SC-004**: All POD sections pass `podchecker lib/ConfigServer/Sanity.pm` validation with zero errors
- **SC-005**: Function documentation includes at least 2 working code examples showing both range and discrete value validation
- **SC-006**: Module has zero subroutine separator patterns when checked with `grep -E "^# (end|start) \w+$" lib/ConfigServer/Sanity.pm`
- **SC-007**: Module has zero Exporter usage when checked with `grep -E "(use Exporter|@EXPORT|@ISA)" lib/ConfigServer/Sanity.pm`
- **SC-008**: Module matches the modernization pattern established in ConfigServer::Sendmail (lazy-loading, no Exporter, disabled imports)
- **SC-009**: All 24 ConfigServer modules have POD documentation (Sanity.pm is the last one)
- **SC-010**: Unit test file exists at `t/ConfigServer-Sanity.t` and passes with `prove -wlvm t/ConfigServer-Sanity.t`
