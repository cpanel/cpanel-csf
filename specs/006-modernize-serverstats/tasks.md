# Tasks: Modernize ServerStats.pm

**Input**: Design documents from `/specs/006-modernize-serverstats/`
**Prerequisites**: plan.md ✅, spec.md ✅, research.md ✅, quickstart.md ✅

**Tests**: Unit tests are included per User Story 4 (P4) requirements.

**Organization**: Tasks are grouped by user story (P0-P4) to enable independent implementation and testing.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US0, US1, US2, US3, US4)
- Include exact file paths in descriptions

---

## Phase 1: Setup

**Purpose**: Preparation and baseline verification

- [X] T001 Verify module compiles before changes: `perl -cw -Ilib lib/ConfigServer/ServerStats.pm`
- [X] T002 Create backup snapshot of current module state for behavior comparison

---

## Phase 2: User Story 0 - Remove Legacy Comment Clutter (Priority: P0)

**Goal**: Clean up legacy formatting comments to establish a clean baseline for modernization

**Independent Test**: `grep -c "^# start\|^# end" lib/ConfigServer/ServerStats.pm` returns 0

### Implementation for User Story 0

- [X] T003 [US0] Remove all `# start` and `# end` comment markers in lib/ConfigServer/ServerStats.pm
- [X] T004 [US0] Remove all `###...###` divider lines between subroutines (preserve copyright header lines 1 and 18) in lib/ConfigServer/ServerStats.pm
- [X] T005 [US0] Remove the `## no critic` pragma at line 19 in lib/ConfigServer/ServerStats.pm
- [X] T006 [US0] Verify module still compiles: `perl -cw -Ilib lib/ConfigServer/ServerStats.pm`

**Checkpoint**: Module compiles with no legacy comment markers remaining

---

## Phase 3: User Story 1 - Code Modernization (Priority: P1)

**Goal**: Modernize module to follow cPanel Perl conventions

**Independent Test**: `perl -cw -Ilib lib/ConfigServer/ServerStats.pm` passes with all modernization changes applied

### Implementation for User Story 1

- [X] T007 [US1] Replace `use strict;` with `use cPstrict;` in lib/ConfigServer/ServerStats.pm
- [X] T008 [US1] Remove `use lib '/usr/local/csf/lib';` in lib/ConfigServer/ServerStats.pm
- [X] T009 [US1] Remove Exporter machinery (use Exporter, @ISA, @EXPORT_OK) in lib/ConfigServer/ServerStats.pm
- [X] T010 [US1] Change `use Fcntl qw(:DEFAULT :flock);` to `use Fcntl ();` in lib/ConfigServer/ServerStats.pm
- [X] T011 [US1] Add `use GD::Graph::bars ();`, `use GD::Graph::pie ();`, `use GD::Graph::lines ();` at module load time in lib/ConfigServer/ServerStats.pm
- [X] T012 [US1] Remove the `init()` function entirely in lib/ConfigServer/ServerStats.pm
- [X] T013 [US1] Remove runtime `require`/`import` calls for GD::Graph modules inside `graphs()` in lib/ConfigServer/ServerStats.pm
- [X] T014 [US1] Add `our $STATS_FILE = '/var/lib/csf/stats/system';` package variable in lib/ConfigServer/ServerStats.pm
- [X] T015 [US1] Replace hardcoded `/var/lib/csf/stats/system` paths with `$STATS_FILE` in lib/ConfigServer/ServerStats.pm
- [X] T016 [US1] Convert all `O_RDWR`, `O_CREAT` to `Fcntl::O_RDWR()`, `Fcntl::O_CREAT()` in lib/ConfigServer/ServerStats.pm
- [X] T017 [US1] Convert all `LOCK_SH`, `LOCK_EX` to `Fcntl::LOCK_SH()`, `Fcntl::LOCK_EX()` in lib/ConfigServer/ServerStats.pm
- [X] T018 [US1] Verify module compiles: `perl -cw -Ilib lib/ConfigServer/ServerStats.pm`

**Checkpoint**: Module compiles with all modernization changes, no string evals, no Exporter

---

## Phase 4: User Story 2 - Make Internal Subroutines Private (Priority: P2)

**Goal**: Mark internal helpers with underscore prefix for clear API boundaries

**Independent Test**: `grep -c "^sub minmaxavg" lib/ConfigServer/ServerStats.pm` returns 0 (renamed to _minmaxavg)

### Implementation for User Story 2

- [X] T019 [US2] Rename `sub minmaxavg` to `sub _minmaxavg` in lib/ConfigServer/ServerStats.pm
- [X] T020 [US2] Update all calls from `&minmaxavg(` to `_minmaxavg(` (remove Perl 4 `&` prefix per constitution III) in lib/ConfigServer/ServerStats.pm
- [X] T021 [US2] Add `sub _reset_stats` private function to clear `%minmaxavg` state in lib/ConfigServer/ServerStats.pm
- [X] T022 [US2] Verify module compiles: `perl -cw -Ilib lib/ConfigServer/ServerStats.pm`

**Checkpoint**: All internal functions prefixed with underscore, _reset_stats() exists

---

## Phase 5: User Story 3 - Add POD Documentation (Priority: P3)

**Goal**: Add comprehensive POD documentation for public API

**Independent Test**: `podchecker lib/ConfigServer/ServerStats.pm` reports no errors

### Implementation for User Story 3

- [X] T023 [US3] Add POD header with NAME, SYNOPSIS, DESCRIPTION after copyright header in lib/ConfigServer/ServerStats.pm
- [X] T024 [P] [US3] Add POD documentation for `graphs()` function in lib/ConfigServer/ServerStats.pm
- [X] T025 [P] [US3] Add POD documentation for `charts()` function in lib/ConfigServer/ServerStats.pm
- [X] T026 [P] [US3] Add POD documentation for `graphs_html()` function in lib/ConfigServer/ServerStats.pm
- [X] T027 [P] [US3] Add POD documentation for `charts_html()` function in lib/ConfigServer/ServerStats.pm
- [X] T028 [US3] Add POD footer with AUTHOR, LICENSE sections in lib/ConfigServer/ServerStats.pm
- [X] T029 [US3] Verify POD: `podchecker lib/ConfigServer/ServerStats.pm`

**Checkpoint**: POD documentation valid and viewable with `perldoc`

---

## Phase 6: User Story 4 - Add Unit Test Coverage (Priority: P4)

**Goal**: Create comprehensive unit tests for the module

**Independent Test**: `prove -wlvm t/ConfigServer-ServerStats.t` passes

### Implementation for User Story 4

- [X] T030 [US4] Create test file skeleton with standard headers in t/ConfigServer-ServerStats.t
- [X] T031 [US4] Add test for module compilation and public API existence in t/ConfigServer-ServerStats.t
- [X] T032 [US4] Add tests for `_reset_stats()` function clearing state in t/ConfigServer-ServerStats.t
- [X] T033 [US4] Add tests for `graphs_html()` output structure in t/ConfigServer-ServerStats.t
- [X] T034 [US4] Add tests for `charts_html()` output structure in t/ConfigServer-ServerStats.t
- [X] T035 [US4] Add GD::Graph mocking infrastructure for `graphs()` and `charts()` tests in t/ConfigServer-ServerStats.t
- [X] T036 [US4] Add tests for `graphs()` with mocked GD::Graph in t/ConfigServer-ServerStats.t
- [X] T037 [US4] Add tests for `charts()` with mocked GD::Graph in t/ConfigServer-ServerStats.t
- [X] T038 [US4] Verify all tests pass: `prove -wlvm t/ConfigServer-ServerStats.t`

**Checkpoint**: All unit tests pass, module behavior verified

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: Final verification and cleanup

- [X] T039 Run perltidy on lib/ConfigServer/ServerStats.pm per `.perltidyrc`
- [X] T040 Verify no trailing whitespace in lib/ConfigServer/ServerStats.pm
- [X] T041 Run full test suite: `make test`
- [X] T041a Validate behavior preservation: compare graphs_html/charts_html output before/after (SC-009)
- [X] T042 Update lib/ConfigServer/DisplayUI.pm and csf.pl to remove ConfigServer::ServerStats::init() caller check (per FR-028)
- [X] T043 Run quickstart.md validation commands

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **US0 (Phase 2)**: Depends on Setup - establishes clean baseline
- **US1 (Phase 3)**: Depends on US0 - modernization on clean code
- **US2 (Phase 4)**: Depends on US1 - private functions after modernization
- **US3 (Phase 5)**: Depends on US2 - document public API after privates identified
- **US4 (Phase 6)**: Depends on US1-US3 - test fully modernized module
- **Polish (Phase 7)**: Depends on all user stories

### Parallel Opportunities

Within Phase 5 (Documentation):
```bash
# These POD tasks can run in parallel:
T024 [P] [US3] Add POD documentation for graphs() function
T025 [P] [US3] Add POD documentation for charts() function
T026 [P] [US3] Add POD documentation for graphs_html() function
T027 [P] [US3] Add POD documentation for charts_html() function
```

### Implementation Strategy

**Recommended Order**: Sequential by user story priority (P0 → P1 → P2 → P3 → P4)

Each user story builds on the previous:
1. **P0**: Clean slate (remove clutter)
2. **P1**: Modernize (cPstrict, imports, no string evals)
3. **P2**: Private functions (clear API boundaries)
4. **P3**: Documentation (document public API)
5. **P4**: Tests (verify everything works)

---

## Notes

- Preserve copyright header (lines 1-18) per constitution I
- All Fcntl constants must use fully qualified names per constitution III
- Test file must use `use cPstrict;` per constitution IV
- Run `perl -cw` after each phase to catch issues early
- Total tasks: 43
