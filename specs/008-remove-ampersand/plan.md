# Implementation Plan: Remove Ampersand Prefix from Perl Function Calls

**Branch**: `008-remove-ampersand` | **Date**: 2026-01-28 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/008-remove-ampersand/spec.md`

**Note**: This template is filled in by the `/speckit.plan` command. See `.specify/templates/commands/plan.md` for the execution workflow.

## Summary

Modernize CSF Perl codebase by removing legacy ampersand (`&`) prefixes from function calls throughout all `.pl`, `.pm`, and `.t` files. Transform `&function()` to `function()` and `&function` to `function()` while preserving special cases like subroutine references (`\&sub`), signal handlers, and `goto &sub` constructs. Use iterative transformation approach with manual review of prototyped subroutines. Validate all changes with 100% test pass rate and Perl syntax validation.

## Technical Context

**Language/Version**: Perl 5.36+ (cPanel-provided at `/usr/local/cpanel/3rdparty/bin/perl`)  
**Primary Dependencies**: None (pure refactoring, no new dependencies)  
**Storage**: File system (modify existing `.pl`, `.pm`, `.t` files in place)  
**Testing**: Test2::V0 framework with `MockConfig` (existing test suite must pass 100%)  
**Target Platform**: Linux server (CSF/LFD security software)
**Project Type**: Single codebase refactoring (no new projects or services)  
**Performance Goals**: N/A (one-time transformation, not runtime performance)  
**Constraints**: Zero behavioral changes, 100% test pass rate, all files must pass `perl -c` validation  
**Scale/Scope**: All Perl files in repository (~50-100 files estimated based on workspace structure)

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

### I. Copyright & Attribution ✓ PASS
- **Rule**: Jonathan Michaelson copyright header (lines 1-18) must never be altered
- **Status**: This refactoring only modifies function call syntax within code bodies, not file headers
- **Compliance**: No copyright headers will be modified

### II. Security-First Design ✓ PASS
- **Rule**: Every code change must prioritize security; fail-closed designs required
- **Status**: This is a syntax-only refactoring with no behavioral changes
- **Compliance**: No security implications - transformation preserves all logic and error handling

### III. Perl Standards Compliance ✓ PASS
- **Rule**: NEVER use Perl 4 style subroutine calls (`&function` or `&function($arg)`)
- **Status**: This refactoring ENFORCES this rule by removing all `&` prefixes from function calls
- **Compliance**: Perfect alignment - this work directly supports constitutional compliance

### IV. Test-First & Isolation ✓ PASS
- **Rule**: All code changes must have corresponding unit tests
- **Status**: Existing test suite provides coverage; refactoring must not break tests
- **Compliance**: FR-007 requires 100% test pass rate; SC-002 measures this

### V. Configuration Discipline ✓ PASS
- **Rule**: Never call `loadconfig()` at module load time
- **Status**: No configuration loading changes; only function call syntax modified
- **Compliance**: No impact on configuration discipline

### VI. Simplicity & Maintainability ✓ PASS
- **Rule**: Code must favor simplicity and clarity over cleverness
- **Status**: Removing ampersands IMPROVES readability and modernizes codebase
- **Compliance**: Direct improvement to maintainability

**Overall Status**: ✓ ALL GATES PASS - No violations to justify

## Project Structure

### Documentation (this feature)

```text
specs/008-remove-ampersand/
├── plan.md              # This file (/speckit.plan command output)
├── research.md          # Phase 0 output (transformation patterns and tools)
├── data-model.md        # Phase 1 output (N/A - no data entities for syntax refactoring)
├── quickstart.md        # Phase 1 output (workflow and validation steps)
├── contracts/           # Phase 1 output (N/A - no API contracts for refactoring)
├── checklists/          # Existing quality checklists
│   └── requirements.md
└── tasks.md             # Phase 2 output (/speckit.tasks command - NOT created by /speckit.plan)
```

### Source Code (repository root)

```text
# No new source files - modifying existing Perl codebase in place

# Files to be transformed:
*.pl                     # Root-level Perl scripts (csf.pl, lfd.pl, auto.pl, etc.)
lib/ConfigServer/*.pm    # Perl modules (AbuseIP.pm, ServerStats.pm, etc.)
bin/*.pl                 # Utility scripts
t/*.t                    # Test files
cpanel/*.cgi             # CGI scripts

# Excluded from transformation:
etc/                     # Configuration files
tpl/                     # Template files
.github/                 # Documentation and instructions
*.sh                     # Shell scripts
*.md                     # Markdown documentation
```

**Structure Decision**: Single codebase refactoring - no new directories or projects created. All work modifies existing files in place, maintaining current project structure.

## Complexity Tracking

> **No violations to justify** - All constitutional gates pass. This refactoring enforces Perl standard compliance (Constitution III) by removing legacy Perl 4 syntax.

---

## Post-Design Constitution Re-Check

*Executed after Phase 1 design completion*

### I. Copyright & Attribution ✓ PASS
- **Status**: Quickstart workflow explicitly preserves file headers
- **Design Impact**: No change - transformations only affect code bodies

### II. Security-First Design ✓ PASS  
- **Status**: Regex patterns use negative lookbehind to exclude special cases
- **Design Impact**: No security implications - syntax-only changes

### III. Perl Standards Compliance ✓ PASS
- **Status**: Research confirms transformation enforces constitutional requirement
- **Design Impact**: **DIRECTLY IMPROVES COMPLIANCE** - removes Perl 4 style calls

### IV. Test-First & Isolation ✓ PASS
- **Status**: Quickstart includes test validation after every phase
- **Design Impact**: Phased approach (tests → modules → scripts) ensures incremental validation

### V. Configuration Discipline ✓ PASS
- **Status**: No configuration changes
- **Design Impact**: No impact

### VI. Simplicity & Maintainability ✓ PASS
- **Status**: Quickstart uses simple, auditable regex transformations
- **Design Impact**: **IMPROVES MAINTAINABILITY** - modern syntax more readable

**Post-Design Verdict**: ✅ ALL GATES STILL PASS - Design reinforces constitutional compliance
