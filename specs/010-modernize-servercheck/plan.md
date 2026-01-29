# Implementation Plan: Modernize ServerCheck.pm Module

**Branch**: `010-modernize-servercheck` | **Date**: 2026-01-29 | **Spec**: [specs/010-modernize-servercheck/spec.md](spec.md)
**Input**: Feature specification from `/root/projects/csf/specs/010-modernize-servercheck/spec.md`

## Summary

Transform ConfigServer::ServerCheck module to follow cPanel modern Perl standards: eliminate package-level Config method calls (lazy-load regex patterns), standardize all imports to disabled form with fully qualified function calls, remove hardcoded library paths, enhance POD documentation, and create basic unit tests focused on modernization aspects (lazy loading, import patterns). Module is 2053 lines performing comprehensive server security audits - focus on structural modernization without refactoring the complex report generation logic.

## Technical Context

**Language/Version**: Perl 5.36+ (cPanel-provided at `/usr/local/cpanel/3rdparty/bin/perl`)  
**Primary Dependencies**: ConfigServer::Config, ConfigServer::{Slurp,Sanity,GetIPs,CheckIP,Service,GetEthDev,Messenger}, Cpanel::Config, Fcntl (core), File::Basename (core), IPC::Open3 (core)  
**Storage**: File-based CSF configuration (`/usr/local/csf/etc/csf.conf`), cPanel/DirectAdmin configs, system files  
**Testing**: Test2::V0 with Test2::Mock, MockConfig test harness  
**Target Platform**: Linux server (cPanel-managed environments, also DirectAdmin support)  
**Project Type**: Single library module modernization (no new modules created)  
**Performance Goals**: Lazy-load regex patterns on first report() call (defer Config method invocation from compile time to runtime)  
**Constraints**: Must preserve exact HTML output format, must not alter security audit logic, module is 2053 lines (extensive comprehensive testing impractical)  
**Scale/Scope**: Single 2053-line module; 1 function exposed publicly (report); estimated 50-100+ function call updates needed

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

### I. Copyright & Attribution ✅ PASS
- **Check**: Jonathan Michaelson copyright header (lines 1-18) must never be altered
- **Status**: PASS - Existing header will be preserved; no modifications to lines 1-18

### II. Security-First Design ✅ PASS
- **Check**: Use three-argument open(), validate inputs, check error conditions
- **Status**: PASS - Module performs security audits; existing patterns will be preserved
- **Check**: No exposure of sensitive information
- **Status**: PASS - HTML report generator; modernization doesn't affect security checks

### III. Perl Standards Compliance ⚠️ VIOLATIONS (Will Fix)
- **Check**: Use `use cPstrict;`
- **Current**: ✅ Already uses `use cPstrict;` (line 71)
- **Action**: No change needed - already compliant

- **Check**: Disable imports with `()`
- **Current**: ❌ 7 modules use `qw()` imports:
  - `use Fcntl qw(:DEFAULT :flock);` (line 73)
  - `use File::Basename;` (line 74) - default import
  - `use IPC::Open3;` (line 75) - default import
  - `use ConfigServer::Slurp qw(slurp);` (line 78)
  - `use ConfigServer::Sanity qw(sanity);` (line 79)
  - `use ConfigServer::GetIPs qw(getips);` (line 81)
  - `use ConfigServer::CheckIP qw(checkip);` (line 82)
- **Action**: Change all to `()` and update 50-100+ function calls to fully qualified names

- **Check**: No hardcoded `use lib` paths
- **Current**: ❌ `use lib '/usr/local/csf/lib';` (line 77)
- **Action**: Remove per FR-007

- **Check**: No compile-time side effects
- **Current**: ❌ Lines 97-98 call Config class methods at package level:
  ```perl
  my $ipv4reg = ConfigServer::Config->ipv4reg;
  my $ipv6reg = ConfigServer::Config->ipv6reg;
  ```
- **Action**: Move to lazy state variables inside report() per FR-002, FR-003

### IV. Test-First & Isolation ⚠️ NEEDS IMPLEMENTATION
- **Check**: Unit tests must exist with MockConfig
- **Current**: No test file exists at `t/ConfigServer-ServerCheck.t`
- **Action**: Create basic test file per User Story 5 (P3 priority - focused on modernization aspects, not comprehensive audit testing)

### V. Configuration Discipline ⚠️ VIOLATION (Will Fix)
- **Check**: NEVER call Config methods at module load time
- **Current**: ❌ Lines 97-98 call `ConfigServer::Config->ipv4reg` and `->ipv6reg` at package level
- **Action**: Move to lazy state variables within report() function per FR-002, FR-003

### VI. Simplicity & Maintainability ⚠️ CHALLENGE
- **Check**: Functions < 30 lines, < 4 parameters, meaningful names
- **Status**: ⚠️ report() function is extremely large (lines 166-2053, ~1887 lines)
- **Justification**: Breaking apart report() is OUT OF SCOPE per spec section "Out of Scope" - too risky without extensive testing infrastructure
- **Action**: No refactoring of report() logic; focus on structural modernization only

**GATE DECISION**: ⚠️ CONDITIONAL PASS - Violations are documented in spec as intentional fixes. Large function size violation is explicitly scoped out as too risky for this modernization pass.

## Project Structure

### Documentation (this feature)

```text
specs/010-modernize-servercheck/
├── spec.md              # Feature specification (COMPLETE)
├── plan.md              # This file - implementation plan
├── research.md          # Phase 0: Technology decisions & patterns
├── data-model.md        # Phase 1: State variables and data structures
├── quickstart.md        # Phase 1: Usage examples post-modernization
└── contracts/           # N/A - internal module, no API contracts
```

### Source Code (repository root)

```text
/root/projects/csf/
├── lib/
│   └── ConfigServer/
│       └── ServerCheck.pm     # Target module (2053 lines)
├── t/
│   ├── lib/
│   │   └── MockConfig.pm      # Test harness (EXISTING)
│   └── ConfigServer-ServerCheck.t  # Unit test file (TO BE CREATED)
└── .github/
    └── instructions/
        ├── perl.instructions.md           # Perl coding standards (REFERENCE)
        └── tests-perl.instructions.md     # Test2 framework guide (REFERENCE)
```

**Structure Decision**: Single project / library module modernization. No new directories needed - all work happens within existing `lib/ConfigServer/` and `t/` directories. Test harness `MockConfig.pm` already exists in `t/lib/` for configuration mocking.

## Complexity Tracking

> **One constitutional violation requiring justification**

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| report() function ~1887 lines | Comprehensive security audit covering 8+ categories (Firewall, Server, WHM, Mail, PHP, Apache, SSH, Services) with complex HTML generation | Breaking into smaller functions requires extensive testing infrastructure that doesn't exist; high risk of subtle bugs in security audit logic; explicitly scoped out per spec's "Out of Scope" section |

**Justification**: The report() function is the entire purpose of the module - it generates a comprehensive HTML security audit report. While it violates the 30-line guideline, refactoring it into smaller functions would require:
1. Mocking entire cPanel environment (config files, system files, process table, etc.)
2. Comprehensive integration tests to verify identical HTML output
3. Deep understanding of all 8+ security check categories and their interdependencies
4. Risk of introducing subtle bugs in security-critical audit logic

This modernization focuses on **structural improvements** (imports, lazy-loading) that can be validated with minimal testing, leaving the complex audit logic untouched per the spec's explicit scoping.

---

## Phase 0: Research & Discovery

### Research Questions

1. **How should large modules with many function calls be modernized efficiently?**
   - Examined patterns from 008-remove-ampersand and recent modernizations
   - Decision: Systematic update by import source with grep-based counting first

2. **How should state variables be used for lazy initialization?**
   - Reviewed 009-modernize-sanity pattern
   - Decision: Use `state $var = Module->method();` inside report() function

3. **What is appropriate test scope for 2053-line audit module?**
   - Assessed complexity vs. benefit trade-off
   - Decision: Minimal tests focused on modernization validation (3 scenarios)

4. **Which Fcntl constants are used and how to update?**
   - Identified common patterns (LOCK_*, O_*)
   - Decision: Search actual usage, update to `Fcntl::CONSTANT()` form

5. **How to update ConfigServer module calls systematically?**
   - Inventoried 4 modules with qw() imports
   - Decision: Count occurrences first, batch update by function name

6. **How to update File::Basename and IPC::Open3?**
   - Identified core module functions likely used
   - Decision: Search for actual usage, update to qualified form

**Output**: ✅ COMPLETE - [research.md](research.md)

**Key Findings**:
- Lazy loading pattern: `state` variables inside function (one-time initialization)
- Update strategy: Organized by import source, count first then batch replace
- Test scope: 3 minimal scenarios (load, lazy-init, smoke test)
- No NEEDS CLARIFICATION items - all decisions made

---

## Phase 1: Design & Contracts

### Design Artifacts Generated

1. **data-model.md** ✅ COMPLETE
   - Documented package-level variable inventory (unchanged by modernization)
   - Defined lazy-loaded state variables (ipv4reg, ipv6reg inside report())
   - Specified import changes (before/after comparison)
   - Detailed function call update patterns by module
   - Cataloged report output structure (HTML format unchanged)

2. **quickstart.md** ✅ COMPLETE
   - Basic usage examples (loading module, generating reports)
   - Module loading behavior comparison (before/after modernization)
   - Lazy initialization demonstration with Test2::Mock
   - Integration examples (web interface, CLI, monitoring)
   - Testing patterns for modernized module
   - Migration guide for existing code
   - Report output structure documentation
   - Troubleshooting guide

3. **contracts/** - N/A
   - Internal library module, no external API contracts
   - Function signature unchanged: `report($verbose)` remains compatible

### Constitution Check (Post-Design Re-evaluation)

**Re-checking against design decisions from research.md and data-model.md:**

#### I. Copyright & Attribution ✅ PASS
- **Status**: Design preserves copyright header lines 1-18
- **Evidence**: No changes to module header documented in any design artifact

#### II. Security-First Design ✅ PASS
- **Status**: Design preserves all existing security check logic
- **Evidence**: data-model.md explicitly states "report() logic: Unchanged"
- **Scope**: Only structural changes (imports, lazy-loading), zero logic changes

#### III. Perl Standards Compliance ✅ WILL COMPLY
- **Status**: All violations documented as fixes in research.md and data-model.md
- **Changes Designed**:
  - Already uses `use cPstrict;` ✓
  - Will change 7 imports from `qw()` to `()` ✓
  - Will update 50-100+ calls to fully qualified names ✓
  - Will remove `use lib '/usr/local/csf/lib'` ✓
  - Will move Config method calls from package-level to lazy state variables ✓

#### IV. Test-First & Isolation ✅ PLANNED
- **Status**: Test strategy documented in research.md Decision #3
- **Approach**: 3 minimal test scenarios focused on modernization validation
- **Justification**: Comprehensive testing impractical for 2053-line module
- **Coverage**: Load test, lazy-init test, smoke test

#### V. Configuration Discipline ✅ WILL COMPLY
- **Status**: Design moves Config method calls from compile-time to runtime
- **Evidence**: data-model.md shows state variables inside report() function
- **Before**: Lines 97-98 call Config->ipv4reg/ipv6reg at package level
- **After**: State variables initialize lazily on first report() call

#### VI. Simplicity & Maintainability ⚠️ ACKNOWLEDGED
- **Status**: report() function ~1887 lines violates 30-line guideline
- **Justification**: Documented in Complexity Tracking table
- **Mitigation**: Explicitly scoped out - refactoring too risky without extensive test infrastructure

**GATE DECISION**: ✅ PASS - Design fully addresses all fixable violations. report() function size violation is acknowledged and justified per spec's "Out of Scope" section.

### Agent Context Update

Run the update script to add ServerCheck modernization context:

```bash
cd /root/projects/csf
.specify/scripts/bash/update-agent-context.sh copilot
```

This updates `.specify/memory/copilot-agent-context.md` with ServerCheck module patterns and modernization details.

---

## Phase 2: Task Breakdown

**Status**: ⏸️ NOT STARTED - Requires separate `/speckit.tasks` command

Task breakdown will be generated in [tasks.md](tasks.md) by the `/speckit.tasks` command. That command will:
1. Read this plan and the specification
2. Generate detailed implementation tasks with acceptance criteria
3. Create a task tracking file for implementation progress

---

## Summary & Next Steps

### Artifacts Completed

- ✅ **plan.md** - This file (implementation plan)
- ✅ **research.md** - Research findings and decisions
- ✅ **data-model.md** - State variables and data structures
- ✅ **quickstart.md** - Usage guide and examples
- ✅ **Constitution Check** - All gates passed (with justified violation)

### Ready for Implementation

The planning phase is complete. Next steps:

1. **Run `/speckit.tasks`** to generate detailed task breakdown
2. **Review tasks.md** to understand implementation sequence
3. **Begin implementation** following the systematic update strategy:
   - Update import statements (7 modules)
   - Move lazy-loading pattern (2 state variables)
   - Update function calls (50-100+ updates by batch)
   - Enhance POD documentation
   - Create unit test file

### Key Implementation Notes

- **Batch updates**: Use grep to count occurrences before bulk replacing
- **Verification**: Run `perl -cw -Ilib` after each batch
- **Testing**: Run `make test` frequently to catch regressions
- **Preservation**: Make ZERO changes to security audit logic
- **HTML output**: Must remain byte-for-byte identical

### Success Criteria Checklist

Before considering implementation complete, verify all success criteria from spec.md:

- [ ] SC-001: Module loads without side effects
- [ ] SC-002: No package-level Config method calls
- [ ] SC-003: Lazy initialization with state variables
- [ ] SC-004: No qw() imports remain
- [ ] SC-005: No hardcoded lib path
- [ ] SC-006: All calls fully qualified
- [ ] SC-007: POD validation passes
- [ ] SC-008: Unit tests exist and pass
- [ ] SC-009: Full test suite passes
- [ ] SC-010: Functionality preserved (HTML output unchanged)
