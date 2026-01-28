# Feature Specification: Modernize ServerStats.pm

**Feature Branch**: `006-modernize-serverstats`  
**Created**: 2026-01-28  
**Status**: Draft  
**Input**: User description: "Modernize ServerStats.pm: Add strict/warnings, remove global variables at module load time, add POD documentation and unit tests following the same pattern used for other module modernizations"

## User Scenarios & Testing *(mandatory)*

### User Story 0 - Remove Legacy Comment Clutter (Priority: P0)

As a developer, I need to remove legacy formatting comments from ServerStats.pm so that the code follows clean formatting standards and matches the pattern used in other modernized modules.

**Why this priority**: These legacy formatting comments clutter the code and serve no functional purpose. They should be removed before any other modernization work to establish a clean baseline.

**Current State Analysis**: ServerStats.pm contains extensive legacy comment clutter:
- All `# start` and `# end` comment markers (e.g., `# start main`, `# end graphs`)
- All `###...###` divider lines between subroutines (but NOT the copyright header dividers at the top of the file)
- `## no critic` line that disables multiple checks

**What to remove**:
- All `# start` and `# end` comment markers
- All `###...###` divider lines between subroutines
- The broad `## no critic` pragma at the top of the file

**What to keep**:
- The copyright/license header at the top of the file
- Useful inline comments explaining complex logic
- Any comments that provide genuine value to future developers

**Acceptance Scenarios**:

1. **Given** ServerStats.pm, **When** examining the code between subroutines, **Then** no `# start` or `# end` comment markers exist
2. **Given** ServerStats.pm, **When** examining the code between subroutines, **Then** no `###...###` divider lines exist (only the 2 copyright header dividers at top of file remain)
3. **Given** ServerStats.pm, **When** running `perl -cw`, **Then** the module still compiles successfully

---

### User Story 1 - Code Modernization (Priority: P1)

As a developer, I need ServerStats.pm to follow modern Perl coding standards (remove global variables, disabled imports, fully qualified names) so that the code is consistent with other modernized modules in the CSF codebase and is properly testable.

**Why this priority**: The module currently has issues that make unit testing difficult:
- Uses `my %minmaxavg;` at package level (line 32) - this global state makes testing difficult
- Uses `eval()` strings for dynamic module loading (lines 39-45)
- Uses hardcoded path `use lib '/usr/local/csf/lib';`

**Key Modernization Issues**:
1. `my %minmaxavg;` package-level global variable must be refactored
2. `eval('use GD::Graph::bars;')` string evals should be converted to block evals with require
3. Remove `use lib '/usr/local/csf/lib';` (callers should set lib path)
4. Remove Exporter machinery (currently empty `@EXPORT_OK`)
5. Convert imports to disabled import syntax
6. Remove the broad `## no critic` pragma

**Acceptance Scenarios**:

1. **Given** ServerStats.pm, **When** examining the module header, **Then** it uses `use cPstrict;` (which implies strict/warnings)
2. **Given** ServerStats.pm, **When** examining the package-level code, **Then** `%minmaxavg` is internal state with `_reset_stats()` available for test isolation
3. **Given** ServerStats.pm, **When** examining imports, **Then** `use Fcntl qw(:DEFAULT :flock);` is changed to `use Fcntl ();`
4. **Given** ServerStats.pm, **When** examining code, **Then** Exporter machinery is removed (@EXPORT_OK, @ISA, use Exporter) since functions should be called with fully qualified name
5. **Given** ServerStats.pm, **When** examining code, **Then** no string eval for module loading exists
6. **Given** ServerStats.pm, **When** examining code, **Then** `use lib '/usr/local/csf/lib';` is removed

---

### User Story 2 - Make Internal Subroutines Private (Priority: P2)

As a developer, I need internal helper functions in ServerStats.pm to be marked as private (with underscore prefix) so that the public API is clear and internal implementation details are not accidentally used by external code.

**Why this priority**: Clear API boundaries make the codebase easier to maintain and refactor. Private functions can be changed without breaking external consumers. This MUST happen before POD documentation so we only document the public API.

**Public API Analysis**:
- `graphs()` - Public: Generates system statistics graphs (CPU, memory, load, etc.)
- `charts()` - Public: Generates block/allow charts
- `graphs_html()` - Public: Returns HTML for displaying system graphs
- `charts_html()` - Public: Returns HTML for displaying charts

**Removed Functions**:
- `init()` - REMOVED: No longer needed since GD::Graph modules are loaded at compile time

**Internal Helper Analysis**:
- `minmaxavg()` - Internal: Helper to track min/max/avg statistics

**Acceptance Scenarios**:

1. **Given** ServerStats.pm module, **When** examining the subroutine names, **Then** `minmaxavg()` is renamed to `_minmaxavg()` with underscore prefix
2. **Given** ServerStats.pm module, **When** examining all calls to `minmaxavg()`, **Then** they are updated to `_minmaxavg()` (removing Perl 4 `&` prefix)
3. **Given** ServerStats.pm module, **When** examining public functions, **Then** `graphs`, `charts`, `graphs_html`, `charts_html` remain public (no underscore prefix)

---

### User Story 3 - Add POD Documentation (Priority: P3)

As a developer working with the CSF codebase, I need ServerStats.pm to have proper POD documentation for PUBLIC functions only, so that I can understand the module's purpose and public API without reading the implementation code.

**Why this priority**: Documentation improves developer productivity and reduces time spent understanding code. This story depends on P2 (private functions) being complete first so we only document the public API.

**Independent Test**: Run `perldoc lib/ConfigServer/ServerStats.pm` and verify NAME, SYNOPSIS, DESCRIPTION, and FUNCTIONS sections are present and properly formatted.

**Acceptance Scenarios**:

1. **Given** ServerStats.pm, **When** running `podchecker`, **Then** no warnings or errors are reported
2. **Given** ServerStats.pm, **When** viewing with `perldoc`, **Then** NAME, SYNOPSIS, DESCRIPTION sections are visible
3. **Given** each public function (`graphs`, `charts`, `graphs_html`, `charts_html`), **When** viewing documentation, **Then** parameters, return values, and usage examples are documented
4. **Given** the POD documentation, **When** examining content, **Then** it explains what system statistics and charts the module generates

---

### User Story 4 - Add Unit Test Coverage (Priority: P4)

As a developer, I need unit tests for ServerStats.pm so that I can verify the module works correctly and catch regressions when making changes.

**Why this priority**: Tests enable confident refactoring and prevent regressions. This story depends on P1-P3 being complete first.

**Test Focus**: Tests should validate **actual module behavior** (functional testing), not meta-tests that check coding patterns. Since ServerStats generates graphs using GD::Graph, tests will need to:
- Mock GD::Graph modules or skip if not available
- Test the HTML generation functions which don't require GD::Graph
- Test the statistics parsing logic

**Testing Challenges**:
- `graphs()` and `charts()` require GD::Graph::bars, GD::Graph::pie, GD::Graph::lines
- Functions read from `/var/lib/csf/stats/system` file
- Functions write image files to disk
- The `%minmaxavg` state tracking complicates isolated unit tests

**Independent Test**: Run `prove -wlvm t/ConfigServer-ServerStats.t` and verify all tests pass.

**Acceptance Scenarios**:

1. **Given** the test file, **When** running with `prove`, **Then** all tests pass
2. **Given** the test file, **When** running with `perl -cw -Ilib`, **Then** no syntax errors or warnings
3. **Given** the tests, **When** checking coverage, **Then** `graphs_html()` output structure is tested
4. **Given** the tests, **When** checking coverage, **Then** `charts_html()` output structure is tested
5. **Given** the tests, **When** checking coverage, **Then** `_reset_stats()` clears internal state properly

---

### Edge Cases

- What happens when GD::Graph modules are not installed? **→ Module fails to compile (cPanel always provides these)**
- What happens when the stats file doesn't exist? **→ Functions should handle gracefully (empty/no graphs)**
- What happens when the stats file is empty? **→ No graphs generated, but no errors**
- What happens when the image directory doesn't exist? **→ File open will fail (caller's responsibility)**
- What happens when disk is full and image can't be written? **→ File write will fail**
- What happens when stats data is malformed? **→ Graceful handling, skip malformed entries**

## Requirements *(mandatory)*

### Functional Requirements

#### Legacy Comment Cleanup (P0)

- **FR-000**: Module MUST have all `# start`/`# end` comment markers removed
- **FR-001**: Module MUST have all `###...###` divider lines removed (except copyright header)
- **FR-002**: Module MUST have the broad `## no critic` pragma removed or replaced with targeted suppressions

#### Code Modernization (P1)

- **FR-010**: Module MUST use `use cPstrict;` instead of `use strict;`
- **FR-011**: Module MUST keep `%minmaxavg` as internal package state (not exposed as public variable)
- **FR-012**: Module MUST add a `_reset_stats()` private function to clear `%minmaxavg` state for test isolation
- **FR-013**: Module MUST remove `use lib '/usr/local/csf/lib';` hardcoded path
- **FR-014**: Module MUST use `use GD::Graph::bars ();`, `use GD::Graph::pie ();`, `use GD::Graph::lines ();` at module load time (no dynamic loading)
- **FR-015**: Module MUST remove `init()` function (no longer needed - modules loaded at compile time)
- **FR-016**: Module MUST remove runtime `require`/`import` calls for GD::Graph modules inside `graphs()`
- **FR-017**: Module MUST use `use Fcntl ();` with fully qualified constant access
- **FR-018**: Module MUST remove Exporter machinery (use Exporter, @ISA, @EXPORT_OK)
- **FR-019**: Module MUST add `our $STATS_FILE = '/var/lib/csf/stats/system';` for test isolation
- **FR-020**: Module SHOULD keep `$VERSION` for version tracking purposes

#### Private Subroutines (P2)

- **FR-025**: `minmaxavg()` helper function MUST be renamed to `_minmaxavg()`
- **FR-026**: All internal calls to `minmaxavg()` MUST be updated to `_minmaxavg()` (removing Perl 4 `&` prefix per constitution III)
- **FR-027**: See FR-012 for `_reset_stats()` requirement

#### Caller Updates

- **FR-028**: Callers using `init()` check (cpanel/csf.cgi) MUST be updated to remove the check

#### Behavior Preservation

- **FR-030**: Module MUST preserve existing behavior of all public functions
- **FR-031**: Module MUST preserve the graph generation for CPU, memory, load, network, disk, mail, mysql, apache metrics
- **FR-032**: Module MUST preserve the chart generation for block/allow statistics
- **FR-033**: Module MUST preserve the HTML output format for compatibility

#### Documentation

- **FR-040**: Module MUST include POD documentation with NAME, SYNOPSIS, DESCRIPTION sections
- **FR-041**: All public functions MUST be documented with parameters and return values
- **FR-042**: POD documentation SHOULD explain what metrics are tracked and displayed

#### Testing

- **FR-050**: Test file `t/ConfigServer-ServerStats.t` MUST exist and pass
- **FR-051**: Tests MUST cover HTML generation functions (`graphs_html`, `charts_html`)
- **FR-052**: Tests MUST cover `_reset_stats()` function for test isolation
- **FR-053**: Tests SHOULD use `local $ConfigServer::ServerStats::STATS_FILE` for path isolation

### Key Entities

- **$type**: Graph type selector (cpu, mem, load, net, disk, mail, mysql, apache)
- **$system_maxdays**: Maximum days of statistics to include in graphs
- **$imghddir**: Directory path for saving generated graph images
- **$imgdir**: URL path for referencing images in HTML
- **$STATS_FILE**: Package variable with path to stats file (default: `/var/lib/csf/stats/system`)
- **%minmaxavg**: Internal state hash tracking min/max/avg values for statistics

## Clarifications

### Session 2026-01-28

- Q: How should the package-level `%minmaxavg` global variable be refactored? → A: Closure-based encapsulation - keep state internal but add a `_reset_stats()` function to clear between calls for testing
- Q: How should GD::Graph module loading be modernized? → A: Use regular `use` statements at top of file with disabled imports; let Perl fail at compile time if missing (cPanel always provides these modules)
- Q: Should the hardcoded stats file path be configurable for testing? → A: Add `our $STATS_FILE = '/var/lib/csf/stats/system';` package variable that tests can localize

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Module compiles without errors: `perl -cw -Ilib lib/ConfigServer/ServerStats.pm` exits with code 0
- **SC-002**: A `_reset_stats()` function exists to clear internal `%minmaxavg` state for testing
- **SC-003**: No legacy comment markers remain in the code
- **SC-004**: POD documentation is valid: `podchecker lib/ConfigServer/ServerStats.pm` reports no errors
- **SC-005**: All unit tests pass: `prove -wlvm t/ConfigServer-ServerStats.t` exits with code 0
- **SC-006**: No Exporter machinery (@EXPORT_OK, @ISA, use Exporter) remains in the code
- **SC-007**: All non-cPstrict imports use disabled import syntax `use Module ();`
- **SC-008**: No string evals for module loading remain
- **SC-009**: Public functions produce identical output for identical inputs before and after modernization
