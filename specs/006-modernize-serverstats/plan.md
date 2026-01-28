# Implementation Plan: Modernize ServerStats.pm

**Branch**: `006-modernize-serverstats` | **Date**: 2026-01-28 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/006-modernize-serverstats/spec.md`

## Summary

Modernize ConfigServer::ServerStats.pm to follow cPanel Perl conventions: use `cPstrict`, remove legacy comment clutter, convert string evals to compile-time module loading, add `_reset_stats()` for test isolation, rename internal helpers with underscore prefix, add POD documentation, and create comprehensive unit tests. The module generates system statistics graphs (CPU, memory, load, etc.) and block/allow charts using GD::Graph.

## Technical Context

**Language/Version**: Perl 5.36+ (cPanel-provided at `/usr/local/cpanel/3rdparty/bin/perl`)  
**Primary Dependencies**: GD::Graph::bars, GD::Graph::pie, GD::Graph::lines, Fcntl  
**Storage**: Reads from `/var/lib/csf/stats/system`, writes GIF images to configurable directory  
**Testing**: Test2::V0, Test2::Tools::Explain, Test2::Plugin::NoWarnings, MockConfig  
**Target Platform**: Linux server (cPanel environment)  
**Project Type**: Single Perl module within existing CSF codebase  
**Performance Goals**: N/A (refactoring preserves existing behavior)  
**Constraints**: Must maintain backward compatibility with existing callers  
**Scale/Scope**: 1 module (~3700 lines), 6 subroutines → 6 (init removed, _reset_stats added)

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Copyright & Attribution | ✅ PASS | Jonathan Michaelson header (lines 1-18) preserved exactly |
| II. Security-First Design | ✅ PASS | No security changes; file operations already use three-arg open() |
| III. Perl Standards | ✅ PASS | Will use `use cPstrict;`, disabled imports, fully qualified names |
| IV. Test-First & Isolation | ✅ PASS | Adding `_reset_stats()` and `$STATS_FILE` for test isolation |
| V. Configuration Discipline | ✅ PASS | Module doesn't use ConfigServer::Config |
| VI. Simplicity & Maintainability | ✅ PASS | Removing legacy clutter, no new complexity added |

## Project Structure

### Documentation (this feature)

```text
specs/006-modernize-serverstats/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── quickstart.md        # Phase 1 output
└── tasks.md             # Phase 2 output (created by /speckit.tasks)
```

### Source Code (repository root)

```text
lib/
└── ConfigServer/
    └── ServerStats.pm   # Module being modernized

t/
├── lib/
│   └── MockConfig.pm    # Test utility (existing)
└── ConfigServer-ServerStats.t  # New test file
```

**Structure Decision**: Single module modernization within existing CSF codebase structure. No new directories needed.

## Complexity Tracking

No constitution violations detected. All principles pass without exceptions.

## Post-Design Constitution Re-Check

*Verified after Phase 1 design completion.*

| Principle | Status | Post-Design Notes |
|-----------|--------|-------------------|
| I. Copyright & Attribution | ✅ PASS | Header lines 1-18 explicitly preserved in research.md |
| II. Security-First Design | ✅ PASS | Three-arg sysopen() preserved, flock() patterns unchanged |
| III. Perl Standards | ✅ PASS | Fcntl fully-qualified (Fcntl::O_RDWR()), no string evals |
| IV. Test-First & Isolation | ✅ PASS | _reset_stats() and $STATS_FILE documented in research |
| V. Configuration Discipline | ✅ PASS | No loadconfig() at module level |
| VI. Simplicity & Maintainability | ✅ PASS | Removing 12+ structural comments, init() function |

**Gate Status**: ✅ PASS - Ready for Phase 2 task generation
