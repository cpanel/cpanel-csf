# Implementation Plan: Modernize cseUI.pm

**Branch**: `002-modernize-cseui` | **Date**: 2026-01-23 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/002-modernize-cseui/spec.md`

## Summary

Modernize ConfigServer::cseUI module by removing global variables at module load time, adding `cPstrict`, disabling imports for external modules, renaming internal functions to private (`_` prefix), adding POD documentation, and creating comprehensive unit tests. This follows the same pattern used for RBLCheck.pm modernization.

## Technical Context

**Language/Version**: Perl 5.36+ (cPanel-provided at `/usr/local/cpanel/3rdparty/bin/perl`)  
**Primary Dependencies**: Fcntl, File::Find, File::Copy, IPC::Open3, ConfigServer::Config  
**Storage**: File system operations (read/write/copy/delete files and directories)  
**Testing**: Test2::V0 with MockConfig for configuration isolation  
**Target Platform**: Linux server (cPanel/WHM environment)  
**Project Type**: Single module modernization  
**Performance Goals**: N/A (code modernization, no performance changes)  
**Constraints**: Must preserve existing behavior; no functional changes  
**Scale/Scope**: 1 module (~1094 lines), 19 subroutines, 1 test file

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
|-----------|--------|-------|
| **I. Security-First Design** | ✅ PASS | FR-007 preserves existing security/error handling; file validation unchanged |
| **II. Perl Standards Compliance** | ✅ PASS | FR-002 adds cPstrict; FR-006 disables imports; FR-008 removes Perl 4 calls |
| **III. Test-First & Isolation** | ✅ PASS | FR-019-027 define test requirements per constitution standards |
| **IV. Configuration Discipline** | ✅ PASS | FR-001/FR-011 move loadconfig() into main() scope |
| **V. Simplicity & Maintainability** | ✅ PASS | FR-004 clarifies public API with underscore convention |

**Constitution Gate: PASSED** - No violations requiring justification.

## Project Structure

### Documentation (this feature)

```text
specs/002-modernize-cseui/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output (minimal for code modernization)
├── quickstart.md        # Phase 1 output
└── tasks.md             # Phase 2 output (created by /speckit.tasks)
```

### Source Code (repository root)

```text
lib/ConfigServer/
└── cseUI.pm             # Module under modernization (1094 lines, 19 subs)

t/
├── lib/
│   └── MockConfig.pm    # Existing test utility for config mocking
└── ConfigServer-cseUI.t # New test file to create
```

**Structure Decision**: This is a single-module modernization within an existing codebase structure. No new directories required.

## Phase 0: Research

### Unknowns Resolved

| Question | Resolution | Rationale |
|----------|------------|-----------|
| How does cseUI.pm currently load config? | `&loadconfig` called in main() at line 56, but uses Perl 4 syntax and loadconfig() sub exists at line 1067 | Move to `_loadconfig()` call within main() scope, remove Perl 4 `&` syntax |
| What modules need import disabling? | Fcntl, File::Find, File::Copy, IPC::Open3 | These use explicit imports; need `use Module ();` with fully qualified names |
| Which functions should be private? | All 18 non-main subs: browse, setp, seto, ren, moveit, copyit, mycopy, cnewd, cnewf, del, view, console, cd, edit, save, uploadfile, countfiles, loadconfig | Only `main()` is the public API entry point |
| What global variables exist? | Two `our()` blocks at lines 36-43 declaring ~40 variables | Convert to `my` within main() scope where possible |
| What Perl 4-style calls exist? | `&loadconfig`, `&view`, `&browse`, `&setp`, `&seto`, `&ren`, `&moveit`, `&copyit`, `&cnewd`, `&cnewf`, `&del`, `&console`, `&cd`, `&edit`, `&save`, `&uploadfile` | Convert all to modern `_subname()` syntax |
| Are there `# start`/`# end` comment markers? | Yes, at lines 47-48 (`# start main`), line 155 (`# end main`), and between other subs | Remove all inter-subroutine comment markers |

### Best Practices Applied

| Technology | Best Practice | Application |
|------------|---------------|-------------|
| cPstrict | Use instead of separate strict/warnings | Replace `use strict;` with `use cPstrict;` |
| Module imports | Disable with `()` and use fully qualified names | `use Fcntl ();` then `Fcntl::LOCK_SH` |
| Private functions | Underscore prefix convention | `sub browse` → `sub _browse` |
| Configuration | Load within function scope, not module load | Move `loadconfig()` call inside `main()` |
| Test isolation | Mock external dependencies | Use MockConfig + mock file operations |

## Phase 1: Design

### Data Model

This is a code modernization task with no data model changes. The existing entities remain:

| Entity | Type | Description |
|--------|------|-------------|
| `%config` | Hash | CSF configuration loaded from `/etc/csf/csf.conf` |
| `%FORM` | Hash | Form input data (action, path, filename, etc.) |
| `main()` | Function | Public entry point, receives form data and dispatches actions |
| `_browse()` | Function | Directory listing display |
| `_edit()` | Function | File editor view |
| `_save()` | Function | File save operation |
| `_del()` | Function | File/directory deletion |
| `_view()` | Function | File view/download |
| (14 more) | Functions | Other action handlers |

### API Contracts

No API changes. The public interface remains:

```perl
# Public API (unchanged)
ConfigServer::cseUI::main(\%form_data, $fileinc, $script, $script_da, $images, $version);
```

### Quickstart

See [quickstart.md](quickstart.md) for implementation steps.

## Complexity Tracking

> No constitution violations requiring justification.

| Aspect | Complexity | Justification |
|--------|------------|---------------|
| Module size | 1094 lines, 19 subs | Existing code; no refactoring of structure in this iteration |
| Global variables | ~40 package variables | Converting to function-scoped where possible; some may need to remain for inter-function communication |
| Test mocking | File I/O operations | Will mock at function level rather than syscall level for simplicity |
