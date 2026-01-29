# Feature Specification: Modernize ConfigServer::ServerCheck.pm

**Case Number**: CPANEL-TBD  
**Feature Branch**: `010-modernize-servercheck`  
**Created**: 2026-01-29  
**Status**: Draft  
**Input**: User description: "Modernize ServerCheck.pm to follow cPanel coding standards: update imports to use () and fully qualified function calls, ensure consistent lazy-loading pattern, improve POD documentation, and add comprehensive unit tests"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Eliminate Package-Level Side Effects (Priority: P1) 🎯 MVP

As a developer, I need the module to load without executing any package-level code that accesses external resources or performs expensive operations. Currently, lines 97-98 call ConfigServer::Config class methods at package level, which means these methods execute every time the module is loaded, even if the `report()` function is never called.

**Why this priority**: Core modernization issue. Package-level method calls create implicit dependencies and prevent the module from being loaded without side effects. This is critical for testability.

**Independent Test**: Can be fully tested by loading the module and verifying that no Config class methods are invoked.

**Acceptance Scenarios**:

1. **Given** the modernized module, **When** it is loaded with `use ConfigServer::ServerCheck ()`, **Then** no ConfigServer::Config methods are called
2. **Given** the modernized module, **When** examined for package-level assignments, **Then** only variable declarations exist, no Config method calls

**Implementation Note**: Analysis revealed that `$ipv4reg` and `$ipv6reg` were never actually used in the module code. Rather than converting them to lazy state variables, they were simply removed entirely (lines 97-98 deleted).

---

### User Story 2 - Standardize Import Patterns (Priority: P1) 🎯 MVP

As a developer, I need all module imports to follow the standard pattern of disabled imports (`use Module ()`) with fully qualified function calls. Currently, the module uses mixed import styles: some modules use `qw()` to import functions (Slurp, Sanity, GetIPs, CheckIP), while others are already correct.

**Why this priority**: Essential modernization that eliminates implicit namespace pollution and makes all dependencies explicit. This is a key part of cPanel's modern Perl standards.

**Independent Test**: Can be tested by searching for `qw\(` in use statements - should find none. All function calls should use `Module::function()` syntax.

**Acceptance Scenarios**:

1. **Given** the module imports ConfigServer::Slurp, **When** checking the use statement, **Then** it uses `()` instead of `qw(slurp)`
2. **Given** the module imports ConfigServer::Sanity, **When** checking the use statement, **Then** it uses `()` instead of `qw(sanity)`
3. **Given** the module imports ConfigServer::GetIPs, **When** checking the use statement, **Then** it uses `()` instead of `qw(getips)`
4. **Given** the module imports ConfigServer::CheckIP, **When** checking the use statement, **Then** it uses `()` instead of `qw(checkip)`
5. **Given** the module imports Fcntl, **When** checking the use statement, **Then** it uses `()` instead of `qw(:DEFAULT :flock)`
6. **Given** the module imports File::Basename, **When** checking the use statement, **Then** it uses `()` to disable default imports
7. **Given** the module imports IPC::Open3, **When** checking the use statement, **Then** it uses `()` to disable default imports
8. **Given** any function call from imported modules, **When** examining the code, **Then** all use fully qualified names (e.g., `ConfigServer::Slurp::slurp()`, `Fcntl::LOCK_SH()`)

---

### User Story 3 - Remove Hardcoded Library Path (Priority: P1) 🎯 MVP

As a developer, I need the module to not hardcode the library path. Currently line 77 has `use lib '/usr/local/csf/lib'` which creates deployment dependencies and prevents the module from being used in different installation locations.

**Why this priority**: Standard modernization requirement. Hardcoded paths are a deployment anti-pattern and all other modernized modules have this removed.

**Independent Test**: Can be tested by grepping for `use lib` - should return no results.

**Acceptance Scenarios**:

1. **Given** the modernized module, **When** searching for `use lib`, **Then** no hardcoded library paths are found
2. **Given** the modernized module, **When** loaded in a test environment, **Then** it uses the standard Perl library search path

---

### User Story 4 - Enhance POD Documentation (Priority: P2)

As a developer, I need comprehensive POD documentation that fully explains the module's purpose, the `report()` function's parameters and return value, and provides usage examples. The current POD (lines 22-165) is good but could be more complete with additional sections.

**Why this priority**: While POD exists, enhancement improves maintainability and helps developers understand the complex audit report generation logic.

**Independent Test**: Can be tested with `podchecker` reporting "pod syntax OK" and `perldoc` showing complete NAME, SYNOPSIS, DESCRIPTION, FUNCTIONS, SEE ALSO sections.

**Acceptance Scenarios**:

1. **Given** the modernized module, **When** running podchecker, **Then** it reports "pod syntax OK"
2. **Given** the module POD, **When** viewing with perldoc, **Then** it includes comprehensive DESCRIPTION section explaining the audit report purpose
3. **Given** the report() function POD, **When** reading it, **Then** all return value formats are documented (HTML structure, check categories)
4. **Given** the module POD, **When** checking completeness, **Then** it includes SEE ALSO section referencing related modules
5. **Given** the module POD, **When** checking completeness, **Then** it includes AUTHOR and LICENSE sections

---

### User Story 5 - Add Minimal Unit Tests (Priority: P3)

As a developer, I need unit tests that verify the module's functionality without requiring a full CSF installation, cPanel environment, or system access. Tests should mock external dependencies and verify that modernization changes don't break existing functionality.

**Why this priority**: Enables safe refactoring and prevents regressions. Lower priority because the module is complex (2053 lines) and comprehensive mocking of its many checks would be extensive work. Focus on minimal tests covering modernization aspects only.

**Independent Test**: Can be tested by running `prove -wlvm t/ConfigServer-ServerCheck.t` and verifying it passes without system dependencies.

**Acceptance Scenarios**:

1. **Given** a test file, **When** running it, **Then** the module loads without package-level side effects
2. **Given** tests for report(), **When** mocking Config/cPanel dependencies, **Then** the function can be tested in isolation
3. **Given** tests for lazy initialization, **When** tracking Config method calls, **Then** they only occur when report() is first called
4. **Given** the test suite, **When** run without cPanel installed, **Then** all tests pass using mocked dependencies

---

### Edge Cases

- **When ConfigServer::Config->ipv4reg or ipv6reg returns undef**: State variables will be undef, validation logic should handle gracefully (existing behavior preserved)
- **When configuration files are missing**: Module uses existing error handling, generates partial report with warnings (no changes to error handling logic)
- **When called in a non-cPanel environment**: DirectAdmin checks activate, cPanel-specific sections show N/A (existing multi-environment support preserved)
- **When errors occur in individual security checks**: Each check is isolated, errors don't crash entire report() function (existing error handling preserved)
- **With very large numbers of processes or violations**: HTML output may be large but functional (existing behavior, no optimization in this modernization)

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Module MUST compile without errors using `perl -cw -Ilib`
- **FR-002**: Module MUST NOT execute ConfigServer::Config class methods at package level
- **FR-003**: Module MUST remove unused package-level variables `$ipv4reg` and `$ipv6reg` (they are never referenced in the code)
- **FR-004**: Module MUST disable all imports using `()` syntax for all use statements
- **FR-005**: Module MUST NOT import functions using `qw()` syntax
- **FR-006**: Module MUST use fully qualified names for all imported function calls:
  - `ConfigServer::Slurp::slurp()` instead of `slurp()`
  - `ConfigServer::Sanity::sanity()` instead of `sanity()`
  - `ConfigServer::GetIPs::getips()` instead of `getips()`
  - `ConfigServer::CheckIP::checkip()` instead of `checkip()`
  - `Fcntl::LOCK_SH()`, `Fcntl::LOCK_EX()`, `Fcntl::LOCK_UN()` instead of unqualified constants
  - `File::Basename::basename()`, `File::Basename::dirname()` instead of unqualified functions
  - `IPC::Open3::open3()` instead of unqualified function
  - And all other Fcntl constants (O_RDWR, O_CREAT, etc.) and functions used in the module (see data-model.md for complete inventory)
- **FR-007**: Module MUST NOT contain hardcoded `use lib` paths
- **FR-008**: Module MUST preserve all existing functionality of the `report()` function
- **FR-009**: Module MUST preserve the HTML output format exactly as it currently is
- **FR-010**: Module MUST enhance POD documentation to include standard sections: SEE ALSO, AUTHOR, and LICENSE
- **FR-011**: Module MUST have unit tests covering at minimum: module loading without side effects, lazy initialization of regex patterns
- **FR-012**: Module MUST maintain cPstrict usage (already present on line 71)
- **FR-013**: All existing test files that depend on ServerCheck MUST continue to pass

### Key Entities

- **Security Audit Report**: HTML document containing comprehensive server security analysis
- **Audit Categories**: Firewall, Server Security, WHM, Mail, PHP, Apache, SSH, Services
- **Regex Patterns**: IPv4 and IPv6 validation patterns from ConfigServer::Config
- **Configuration State**: CSF/LFD config, cPanel config, DirectAdmin config
- **Audit Execution**: Single report() function generating HTML output

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Module loads without side effects: Loading the module does not invoke ConfigServer::Config class methods
- **SC-002**: No package-level method calls: `grep -n 'ConfigServer::Config->' lib/ConfigServer/ServerCheck.pm` outside of function bodies returns 0 results
- **SC-003**: Unused variables removed: `grep -n '\$ipv4reg\|\$ipv6reg' lib/ConfigServer/ServerCheck.pm` returns 0 results
- **SC-004**: No qw() imports: `grep 'use.*qw(' lib/ConfigServer/ServerCheck.pm` returns 0 results
- **SC-005**: No hardcoded lib path: `grep 'use lib' lib/ConfigServer/ServerCheck.pm` returns 0 results
- **SC-006**: Fully qualified calls verified: Search finds all imported functions called with full package names
- **SC-007**: POD validation passes: `podchecker lib/ConfigServer/ServerCheck.pm` reports "pod syntax OK"
- **SC-008**: Unit tests exist and pass: `prove -wlvm t/ConfigServer-ServerCheck.t` exits with code 0
- **SC-009**: Full test suite passes: `make test` or equivalent runs all tests successfully
- **SC-010**: Functionality preserved: Manual testing or integration tests verify report() output is unchanged

## Scope

### In Scope

- Remove unused package-level `$ipv4reg` and `$ipv6reg` variables (lines 97-98) - analysis showed they are never referenced
- Change all `qw()` imports to `()` (Slurp, Sanity, GetIPs, CheckIP, Fcntl, File::Basename, IPC::Open3)
- Update all function calls to use fully qualified names
- Remove `use lib '/usr/local/csf/lib'`
- Enhance POD documentation with additional sections (SEE ALSO, AUTHOR, LICENSE)
- Create unit test file (t/ConfigServer-ServerCheck.t) with basic tests for module loading and lazy initialization
- Update all Fcntl constant references (LOCK_SH, LOCK_EX, LOCK_UN, etc.) to fully qualified form
- Ensure all File::Basename and IPC::Open3 calls are fully qualified

### Out of Scope

- Refactoring the report() function logic or HTML generation
- Adding new security checks or modifying existing check logic
- Changing function signatures or return values
- Performance optimizations
- Breaking the report() function into smaller functions (too risky without extensive testing)
- Comprehensive unit test coverage of all security checks (module is too large/complex)
- Adding new features or capabilities
- Changing the HTML output format

## Dependencies

- **ConfigServer::Config**: Required for configuration access and regex patterns
- **ConfigServer::Slurp**: Required for file reading operations
- **ConfigServer::Sanity**: Required for configuration validation
- **ConfigServer::GetIPs**: Required for IP address retrieval
- **ConfigServer::CheckIP**: Required for IP address validation
- **ConfigServer::Service**: Required for service management
- **ConfigServer::GetEthDev**: Required for network device information
- **ConfigServer::Messenger**: Required for messaging functionality
- **Cpanel::Config**: Required when running in cPanel environment
- **Fcntl**: Core module for file locking constants
- **File::Basename**: Core module for path manipulation
- **IPC::Open3**: Core module for process execution
- **Carp**: Core module for error reporting (already uses () import)
- **Test2::V0**: Required for unit tests
- **Test2::Mock**: Required for mocking in unit tests

## Assumptions

- The module's security audit functionality is critical and must not be altered
- The HTML output format is expected by consuming code and must remain exactly the same
- The package-level regex initialization is purely an optimization and can be moved to lazy initialization without functional impact
- All imported functions are available in the modules' namespaces as expected
- The test environment can mock cPanel and system dependencies sufficiently
- Existing code that calls `report()` will not be affected by these internal changes

## Notes

### Current Import Analysis

The module currently has these import patterns:

**Already Correct:**
- `use Carp ();` ✓
- `use ConfigServer::Config;` ✓ (no imports)
- `use ConfigServer::Service;` ✓ (no imports)
- `use ConfigServer::GetEthDev;` ✓ (no imports)
- `use ConfigServer::Messenger ();` ✓
- `use Cpanel::Config ();` ✓

**Need Fixing:**
- `use Fcntl qw(:DEFAULT :flock);` → `use Fcntl ();`
- `use File::Basename;` → `use File::Basename ();` 
- `use IPC::Open3;` → `use IPC::Open3 ();`
- `use ConfigServer::Slurp qw(slurp);` → `use ConfigServer::Slurp ();`
- `use ConfigServer::Sanity qw(sanity);` → `use ConfigServer::Sanity ();`
- `use ConfigServer::GetIPs qw(getips);` → `use ConfigServer::GetIPs ();`
- `use ConfigServer::CheckIP qw(checkip);` → `use ConfigServer::CheckIP ();`

### Package-Level Issues

Lines 97-98 currently execute at package load time:
```perl
my $ipv4reg = ConfigServer::Config->ipv4reg;
my $ipv6reg = ConfigServer::Config->ipv6reg;
```

These should be moved inside `report()` as state variables:
```perl
sub report {
    my ($verbose_param) = @_;
    
    state $ipv4reg = ConfigServer::Config->ipv4reg;
    state $ipv6reg = ConfigServer::Config->ipv6reg;
    
    # ... rest of function
}
```

This ensures the Config class methods are only called when `report()` is actually invoked, and only once (cached in state variables).

### Function Call Updates

See FR-006 for complete list of function calls requiring fully qualified names. Actual counts documented in data-model.md based on code analysis.

### Size Consideration

This module is 2053 lines long, significantly larger than other modernized modules:
- Sendmail.pm: ~400 lines
- Service.pm: ~300 lines
- Sanity.pm: ~200 lines (estimated)

The large size means:
1. More function call updates needed (potentially 50-100+ updates)
2. Comprehensive unit testing is impractical for P1 (would require mocking entire cPanel environment)
3. Focus on structural modernization (imports, lazy-loading) rather than extensive refactoring
4. Unit tests should cover the modernization aspects (lazy loading, import patterns) not comprehensive functionality

### Modernization Pattern

Following the established pattern from Service.pm and other modernized modules:
1. Remove `use lib` hardcoded path
2. Change all imports to `()` disabled form
3. Update all function calls to fully qualified names
4. Move package-level method calls to lazy state variables
5. Enhance POD documentation
6. Create basic unit tests focused on modernization concerns
