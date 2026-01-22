# Tasks: Modernize RBLCheck.pm

**Input**: Design documents from `/specs/001-modernize-rblcheck/`
**Prerequisites**: plan.md ✓, spec.md ✓, research.md ✓, data-model.md ✓, contracts/ ✓, quickstart.md ✓

**Tests**: Unit tests included as User Story 5 (P5) per spec.md

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

---

## Phase 1: Setup

**Purpose**: Verify baseline and prepare for modernization

- [ ] T001 Verify current module compiles with `perl -cw -Ilib lib/ConfigServer/RBLCheck.pm` (baseline)
- [ ] T002 Create feature branch `001-modernize-rblcheck` if not exists
- [ ] T003 Review CloudFlare.pm (commit 7bd732d) for reference pattern

**Checkpoint**: Baseline established, pattern understood

---

## Phase 2: User Story 1 - Remove Global Variables (Priority: P1) 🎯 MVP

**Goal**: Module compiles without requiring `/etc/csf/csf.conf` to exist

**Independent Test**: `perl -cw -Ilib lib/ConfigServer/RBLCheck.pm` succeeds without config files

### Implementation for User Story 1

- [X] T004 [US1] Remove unused `$ipv4reg` global declaration in lib/ConfigServer/RBLCheck.pm (line 44)
- [X] T005 [US1] Remove unused `$ipv6reg` global declaration in lib/ConfigServer/RBLCheck.pm (line 45)
- [X] T006 [US1] Remove `%config` from package-level `my` declaration in lib/ConfigServer/RBLCheck.pm (line 40-42)
- [X] T007 [US1] Ensure `%config` is declared with `my` inside `report()` function in lib/ConfigServer/RBLCheck.pm (line 53)
- [X] T008 [US1] Validate: run `perl -cw -Ilib lib/ConfigServer/RBLCheck.pm` passes

**Checkpoint**: User Story 1 complete - module compiles without config files

---

## Phase 3: User Story 2 - Code Modernization (Priority: P2)

**Goal**: Follow cPstrict and import standards per cPanel coding standards

**Independent Test**: Module compiles with cPstrict, no unused imports, Fcntl uses qualified names

### Implementation for User Story 2

- [X] T009 [US2] Replace `use strict;` with `use cPstrict;` in lib/ConfigServer/RBLCheck.pm (line 22)
- [X] T010 [US2] Remove `## no critic` line in lib/ConfigServer/RBLCheck.pm (line 19)
- [X] T011 [US2] Change `use Fcntl qw(:DEFAULT :flock);` to `use Fcntl ();` in lib/ConfigServer/RBLCheck.pm (line 24)
- [X] T012 [US2] Remove unused `use IPC::Open3;` in lib/ConfigServer/RBLCheck.pm (line 30)
- [X] T013 [US2] Remove `use Exporter qw(import);` in lib/ConfigServer/RBLCheck.pm (line 34)
- [X] T014 [US2] Remove `our @ISA = qw(Exporter);` in lib/ConfigServer/RBLCheck.pm (line 36)
- [X] T015 [US2] Remove `our @EXPORT_OK = qw();` in lib/ConfigServer/RBLCheck.pm (line 37)
- [X] T016 [US2] Update `sysopen()` to use `Fcntl::O_WRONLY | Fcntl::O_CREAT` in lib/ConfigServer/RBLCheck.pm (line 152)
- [X] T017 [US2] Update `flock()` to use `Fcntl::LOCK_EX` in lib/ConfigServer/RBLCheck.pm (line 153)
- [X] T018 [US2] Validate: run `perl -cw -Ilib lib/ConfigServer/RBLCheck.pm` passes

**Checkpoint**: User Story 2 complete - module follows cPstrict and import standards

---

## Phase 4: User Story 3 - Make Subroutines Private (Priority: P3)

**Goal**: Clear public API boundary - only `report()` is public

**Independent Test**: Verify only `report()` lacks underscore prefix; all helper functions are `_` prefixed

### Implementation for User Story 3

- [X] T019 [US3] Rename `sub startoutput` to `sub _startoutput` in lib/ConfigServer/RBLCheck.pm (line 184)
- [X] T020 [US3] Rename `sub addline` to `sub _addline` in lib/ConfigServer/RBLCheck.pm (line 190)
- [X] T021 [US3] Rename `sub addtitle` to `sub _addtitle` in lib/ConfigServer/RBLCheck.pm (line 217)
- [X] T022 [US3] Rename `sub endoutput` to `sub _endoutput` in lib/ConfigServer/RBLCheck.pm (line 232)
- [X] T023 [US3] Rename `sub getethdev` to `sub _getethdev` in lib/ConfigServer/RBLCheck.pm (line 241)
- [X] T024 [US3] Update caller `&startoutput` to `_startoutput()` in lib/ConfigServer/RBLCheck.pm (line 59)
- [X] T025 [US3] Update caller `&getethdev` to `_getethdev()` in lib/ConfigServer/RBLCheck.pm (line 61)
- [X] T026 [US3] Update caller `&addtitle(...)` to `_addtitle(...)` in lib/ConfigServer/RBLCheck.pm (line 121)
- [X] T027 [US3] Update 3 callers `&addline(...)` to `_addline(...)` in lib/ConfigServer/RBLCheck.pm (lines 134, 137, 140)
- [X] T028 [US3] Update caller `&addtitle(...)` to `_addtitle(...)` in lib/ConfigServer/RBLCheck.pm (line 157)
- [X] T029 [US3] Update caller `&addtitle(...)` to `_addtitle(...)` in lib/ConfigServer/RBLCheck.pm (line 162)
- [X] T030 [US3] Update caller `&endoutput` to `_endoutput()` in lib/ConfigServer/RBLCheck.pm (line 176)
- [X] T031 [US3] Validate: run `perl -cw -Ilib lib/ConfigServer/RBLCheck.pm` passes

**Checkpoint**: User Story 3 complete - public API is clear

---

## Phase 5: User Story 4 - Add POD Documentation (Priority: P4)

**Goal**: Document public API only (no POD for private functions)

**Independent Test**: `podchecker lib/ConfigServer/RBLCheck.pm` reports no errors; `perldoc` shows NAME, SYNOPSIS, DESCRIPTION

### Implementation for User Story 4

- [X] T032 [US4] Add module-level POD (NAME, SYNOPSIS, DESCRIPTION) after `package` line in lib/ConfigServer/RBLCheck.pm
- [X] T033 [US4] Add POD for `report()` function with parameters and return value in lib/ConfigServer/RBLCheck.pm
- [X] T034 [US4] Validate: run `podchecker lib/ConfigServer/RBLCheck.pm` reports no errors
- [X] T035 [US4] Validate: run `perldoc lib/ConfigServer/RBLCheck.pm` shows proper documentation

**Checkpoint**: User Story 4 complete - documentation is complete

---

## Phase 6: User Story 5 - Add Unit Test Coverage (Priority: P5)

**Goal**: Test coverage for public API with mocked dependencies

**Independent Test**: `prove -wlvm t/ConfigServer-RBLCheck.t` passes

### Implementation for User Story 5

- [X] T036 [US5] Create test file with shebang and Test2 imports in t/ConfigServer-RBLCheck.t
- [X] T037 [US5] Add MockConfig setup for test isolation in t/ConfigServer-RBLCheck.t
- [X] T038 [US5] Add Test2::Mock for ConfigServer::GetEthDev in t/ConfigServer-RBLCheck.t
- [X] T039 [US5] Add Test2::Mock for ConfigServer::RBLLookup in t/ConfigServer-RBLCheck.t
- [X] T040 [US5] Add subtest 'Module loads correctly' in t/ConfigServer-RBLCheck.t
- [X] T041 [US5] Add subtest 'Public API exists' (can_ok for report) in t/ConfigServer-RBLCheck.t
- [X] T042 [US5] Add subtest 'report() returns expected structure' in t/ConfigServer-RBLCheck.t
- [X] T043 [US5] Add subtest 'report() with no IPs returns zero failures' in t/ConfigServer-RBLCheck.t
- [X] T044 [US5] Validate: run `perl -cw -Ilib t/ConfigServer-RBLCheck.t` passes
- [X] T045 [US5] Validate: run `prove -wlvm t/ConfigServer-RBLCheck.t` all tests pass

**Checkpoint**: User Story 5 complete - tests pass

---

## Phase 7: Polish & Final Validation

**Purpose**: Final checks and ensure no regressions

- [X] T046 Run `make test` to ensure no regressions to existing tests
- [X] T047 Run perltidy on lib/ConfigServer/RBLCheck.pm per `.perltidyrc`
- [X] T048 Run quickstart.md validation checklist
- [X] T049 Commit changes with message: "Modernize RBLCheck.pm: cPstrict, POD, tests"

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **User Story 1 (Phase 2)**: Depends on Setup - foundation for all other stories
- **User Story 2 (Phase 3)**: Depends on User Story 1 (same file, sequential edits)
- **User Story 3 (Phase 4)**: Depends on User Story 2 (same file, sequential edits)
- **User Story 4 (Phase 5)**: Depends on User Story 3 (POD must reference final function names)
- **User Story 5 (Phase 6)**: Depends on User Story 1 (tests need module to compile without config)
- **Polish (Phase 7)**: Depends on all user stories being complete

### User Story Dependencies

```
US1 (P1) ──→ US2 (P2) ──→ US3 (P3) ──→ US4 (P4)
   │
   └──────────────────────────────────→ US5 (P5)
```

- **User Story 1 (P1)**: Foundation - BLOCKS all other stories
- **User Story 2 (P2)**: Sequential after US1 (same file)
- **User Story 3 (P3)**: Sequential after US2 (same file, need imports settled first)
- **User Story 4 (P4)**: Sequential after US3 (need final function names for POD)
- **User Story 5 (P5)**: Can start after US1 (test file is separate from module)

### Parallel Opportunities

- T004, T005 can run together (different lines, same file section)
- T009-T015 (imports) can be done in any order within Phase 3
- T019-T023 (function renames) can run in parallel
- T024-T030 (caller updates) can run in parallel
- T036-T043 (test subtests) can be written in any order
- **US5 can start immediately after US1** (test file is independent of US2-US4)

---

## Parallel Example: User Story 3 (Private Functions)

```bash
# Rename all function definitions together:
T019: Rename startoutput → _startoutput
T020: Rename addline → _addline
T021: Rename addtitle → _addtitle
T022: Rename endoutput → _endoutput
T023: Rename getethdev → _getethdev

# Then update all callers together:
T024-T030: Update &func calls to _func() calls
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup
2. Complete Phase 2: User Story 1 (Remove Globals)
3. **STOP and VALIDATE**: Module compiles without config files
4. Module is now testable - MVP achieved

### Incremental Delivery

1. US1 → Module compiles in test environment ✓
2. US2 → Module follows cPstrict standards ✓
3. US3 → Public API is clear ✓
4. US4 → Documentation complete ✓
5. US5 → Tests prevent regressions ✓

### Optimal Path (Single Developer)

Since all code changes are in the same file (lib/ConfigServer/RBLCheck.pm), the optimal path is sequential:
1. US1 → US2 → US3 → US4 (all in RBLCheck.pm)
2. Start US5 (test file) after US1 is stable
3. Polish after both paths complete

---

## Summary

| Phase | Tasks | Parallel? | Validation |
|-------|-------|-----------|------------|
| Setup | T001-T003 | No | Baseline check |
| US1 - Remove Globals | T004-T008 | Partial | `perl -cw` without config |
| US2 - Code Modernization | T009-T018 | Yes | `perl -cw` |
| US3 - Private Functions | T019-T031 | Yes | `perl -cw` |
| US4 - POD Documentation | T032-T035 | No | `podchecker` |
| US5 - Unit Tests | T036-T045 | Yes | `prove -wlvm` |
| Polish | T046-T049 | No | `make test` |

**Total Tasks**: 49  
**Parallelizable**: ~60% (within phases)  
**Estimated Time**: 2-3 hours (sequential)
