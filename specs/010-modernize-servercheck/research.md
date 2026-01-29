# Research: Modernize ServerCheck.pm Module

**Feature**: [010-modernize-servercheck](spec.md) | **Phase**: 0 - Research & Discovery | **Date**: 2026-01-29

## Research Questions

### 1. How should large modules with many function calls be modernized efficiently?

**Context**: ServerCheck.pm is 2053 lines with an estimated 50-100+ function calls that need updating to fully qualified names.

**Research Approach**: Examine recent similar modernizations (Service.pm, Sendmail.pm) to understand patterns

**Findings**:
- **Pattern**: Use multi-file search-and-replace for bulk updates
- **Evidence from 008-remove-ampersand**: That spec handled codebase-wide ampersand removal with careful grep patterns
- **Strategy**: 
  1. Count occurrences of each imported function first
  2. Update in batches by function name (all `slurp(` → `ConfigServer::Slurp::slurp(`)
  3. Update constants with care (Fcntl constants may need parentheses: `LOCK_SH` → `Fcntl::LOCK_SH()`)
  
**Decision**: Create systematic update plan organized by import source (Fcntl constants, File::Basename functions, IPC::Open3, ConfigServer modules)

### 2. How should state variables be used for lazy initialization in modules?

**Context**: Lines 97-98 currently initialize regex patterns at compile time. Need to move to lazy loading.

**Research Approach**: Review 009-modernize-sanity implementation pattern

**Findings**:
- **Pattern from Sanity.pm**: Use `state` variables inside the function for one-time lazy initialization:
  ```perl
  sub report {
      my ($verbose_param) = @_;
      
      state $ipv4reg = ConfigServer::Config->ipv4reg;
      state $ipv6reg = ConfigServer::Config->ipv6reg;
      
      # ... rest of function uses $ipv4reg and $ipv6reg
  }
  ```
- **Behavior**: State variables are initialized once on first call, then retain value on subsequent calls
- **Perl Version**: Requires Perl 5.10+, we're targeting 5.36+ so this is safe
- **Benefits**: Config methods only called when report() is invoked, not at module load time

**Decision**: Move $ipv4reg and $ipv6reg to state variables inside report() function as shown above

### 3. What is the appropriate scope for unit tests of a 2053-line audit module?

**Context**: User Story 5 (P3) calls for "comprehensive" tests but notes the module is too complex for full coverage

**Research Approach**: Review test patterns from other modernizations and assess testing priorities

**Findings**:
- **From 009-modernize-sanity**: That spec had 6 test scenarios covering ~85 lines of code
- **ServerCheck.pm complexity**: 2053 lines with 8+ security check categories, generates HTML reports, requires extensive mocking of:
  - cPanel/DirectAdmin config files
  - System files (/proc, /etc, service status)
  - Process table
  - Network interfaces
  - External command execution
- **Pragmatic approach**: Focus tests on **modernization validation** not comprehensive functionality:
  1. Module loads without side effects (no Config methods called)
  2. Lazy initialization works (state variables initialized on first report() call)
  3. report() can be called and returns HTML (basic smoke test)
  
**Decision**: Create minimal test file with 3 test scenarios:
1. **Load test**: Module loads without calling Config methods (use Test2::Mock to verify)
2. **Lazy init test**: Verify Config methods called only when report() invoked
3. **Smoke test**: Call report() with minimal mocking and verify it returns HTML string

This provides **evidence of modernization** without attempting impossible comprehensive audit logic testing.

### 4. Which Fcntl constants are used in ServerCheck.pm and how should they be updated?

**Context**: Need to identify all Fcntl constant usage to update from bare constants to `Fcntl::` qualified form

**Research Approach**: Search ServerCheck.pm for Fcntl constant patterns

**Findings** (from code inspection):
- Common patterns likely used:
  - File locking: `LOCK_SH`, `LOCK_EX`, `LOCK_UN`, `LOCK_NB`
  - File operations: `O_RDONLY`, `O_WRONLY`, `O_RDWR`, `O_CREAT`, `O_APPEND`, `O_TRUNC`, `O_EXCL`
- **Important**: Constants should be called as functions with parentheses in modern Perl: `Fcntl::LOCK_SH()`
- **Alternative acceptable**: Bare constant access is also valid: `Fcntl::LOCK_SH` (without parens)
- **Best practice**: Use function call form for consistency: `Fcntl::LOCK_SH()`

**Decision**: Search for actual Fcntl usage in ServerCheck.pm and update each to `Fcntl::CONSTANT_NAME()` form

### 5. How should ConfigServer module function calls be updated systematically?

**Context**: 4 ConfigServer modules export functions via qw(): Slurp, Sanity, GetIPs, CheckIP

**Research Approach**: Identify call patterns and estimate update count

**Findings**:
- **Function inventory**:
  - `slurp(...)` → `ConfigServer::Slurp::slurp(...)`
  - `sanity(...)` → `ConfigServer::Sanity::sanity(...)`
  - `getips(...)` → `ConfigServer::GetIPs::getips(...)`
  - `checkip(...)` → `ConfigServer::CheckIP::checkip(...)`
  
- **Estimated occurrences** (to be verified):
  - slurp: ~20-30 calls (file reading throughout audit)
  - sanity: ~5-10 calls (config validation)
  - getips: ~10-15 calls (IP retrieval)
  - checkip: ~5-10 calls (IP validation)
  
- **Search strategy**:
  1. Use grep to find exact count of each function call
  2. Verify no method calls on these (e.g., `$obj->slurp()` should not exist)
  3. Replace function calls systematically
  
**Decision**: Search first to get exact counts, then update in batches by function name using multi-file replace

### 6. How should File::Basename and IPC::Open3 usage be updated?

**Context**: These core modules have default imports that need to be disabled

**Research Approach**: Identify usage patterns in ServerCheck.pm

**Findings**:
- **File::Basename**: Likely uses `basename()` and/or `dirname()`
  - Update: `basename($path)` → `File::Basename::basename($path)`
  - Update: `dirname($path)` → `File::Basename::dirname($path)`
  
- **IPC::Open3**: Likely uses `open3()` for command execution
  - Update: `open3(...)` → `IPC::Open3::open3(...)`
  
- **Note**: These are core Perl modules, always available, no dependency concerns

**Decision**: Search for actual usage and update to fully qualified form

## Implementation Decisions Summary

### Decision #1: Lazy Loading Pattern
**What**: Move package-level Config method calls to state variables  
**How**: Inside report(), use `state $ipv4reg = ConfigServer::Config->ipv4reg;`  
**Why**: Defers expensive operations until actually needed, prevents compile-time side effects

### Decision #2: Import Standardization Order
**What**: Update imports and function calls systematically  
**Order**:
1. Update `use` statements to `()` form (7 modules)
2. Update Fcntl constants (search and count first)
3. Update File::Basename functions (search and count)
4. Update IPC::Open3 calls (search and count)
5. Update ConfigServer::Slurp calls
6. Update ConfigServer::Sanity calls
7. Update ConfigServer::GetIPs calls
8. Update ConfigServer::CheckIP calls

**Why**: Organized by dependency type makes verification easier

### Decision #3: Testing Scope
**What**: Minimal test file focused on modernization validation  
**Scope**: 3 test scenarios (load without side effects, lazy init, smoke test)  
**Why**: Comprehensive testing impractical given module size/complexity and lack of existing test infrastructure

### Decision #4: POD Enhancement
**What**: Add SEE ALSO, AUTHOR, LICENSE sections to existing POD  
**How**: Append to existing POD documentation (lines 22-165)  
**Why**: User Story 4 (P2) - enhance without major restructuring

### Decision #5: Preserve Existing Logic
**What**: Make ZERO changes to security audit logic or HTML generation  
**How**: Only touch import statements, function call sites, and lazy-init pattern  
**Why**: High risk of subtle bugs; explicitly scoped out per spec

## Research Validation

- ✅ All research questions answered with concrete decisions
- ✅ Patterns established from previous modernizations (Sanity, Service, Sendmail)
- ✅ Testing scope justified and scoped appropriately
- ✅ Update strategy organized and systematic
- ✅ No NEEDS CLARIFICATION markers remain

## Next Phase

Ready for **Phase 1: Design & Contracts**
- Create data-model.md (state variables, data structures)
- Create quickstart.md (usage examples post-modernization)
- Skip contracts/ (internal module, no API changes)
