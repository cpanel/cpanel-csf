# Tasks: Modernize cseUI.pm

**Input**: Design documents from `/specs/002-modernize-cseui/`
**Prerequisites**: plan.md, spec.md, research.md

**Tests**: Tests are requested in User Story 5 (P5) - included in Phase 8.

**Organization**: Tasks grouped by user story (P0→P5) to enable independent implementation and testing.

## Format: `[ID] [P?] [Story?] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US0-US5)
- File paths are relative to repository root

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: No new infrastructure needed - this is a single-module modernization within existing codebase.

- [X] T001 Create backup of lib/ConfigServer/cseUI.pm before modifications
- [X] T002 Verify existing tests pass with `make test`

---

## Phase 2: Foundational (No blocking tasks for this feature)

**Purpose**: All foundational infrastructure already exists (MockConfig, Test2 framework, etc.)

**Checkpoint**: Ready to proceed with user story implementation.

---

## Phase 3: User Story 0 - Remove Inter-Subroutine Comments (Priority: P0)

**Goal**: Remove all `# start`/`# end` comment markers to establish clean baseline

**Independent Test**: `grep -E '^\s*##+\s*(start|end)' lib/ConfigServer/cseUI.pm` returns no results

### Implementation for User Story 0

- [X] T003 [US0] Identify all `# start`/`# end` comment markers in lib/ConfigServer/cseUI.pm
- [X] T004 [US0] Remove `# start main` and blank comment line at lines 47-48 in lib/ConfigServer/cseUI.pm
- [X] T005 [US0] Remove `# end main` marker at line 155 in lib/ConfigServer/cseUI.pm
- [X] T006 [US0] Remove all remaining inter-subroutine `# start`/`# end` markers in lib/ConfigServer/cseUI.pm
- [X] T007 [US0] Verify module compiles with `perl -cw -Ilib lib/ConfigServer/cseUI.pm`

**Checkpoint**: US0 complete - no `# start`/`# end` markers remain in module

---

## Phase 4: User Story 1 - Remove Global Variables at Module Load Time (Priority: P1)

**Goal**: Module compiles without requiring `/etc/csf/csf.conf`

**Independent Test**: `perl -cw -Ilib lib/ConfigServer/cseUI.pm` succeeds without config file

### Implementation for User Story 1

- [X] T008 [US1] Remove unused `our` variables ($chart, $ipscidr6, $ipv6reg, $ipv4reg, %ips, $mobile) from line 36-38 in lib/ConfigServer/cseUI.pm
- [X] T009 [US1] Consolidate remaining `our` declarations into single block in lib/ConfigServer/cseUI.pm
- [X] T010 [US1] Verify `_loadconfig()` is only called inside `main()` (already true, needs syntax fix in P2)
- [X] T011 [US1] Verify module compiles with `perl -cw -Ilib lib/ConfigServer/cseUI.pm`

**Checkpoint**: US1 complete - module compiles without production config files

---

## Phase 5: User Story 2 - Code Modernization (Priority: P2)

**Goal**: Module follows modern cPanel Perl coding standards

**Independent Test**: Module uses `cPstrict`, disabled imports, no Perl 4 calls, no Exporter

### Implementation for User Story 2

- [X] T012 [US2] Replace `use strict;` with `use cPstrict;` in lib/ConfigServer/cseUI.pm
- [X] T013 [US2] Remove `## no critic` line at line 19 in lib/ConfigServer/cseUI.pm
- [X] T014 [US2] Change `use Fcntl qw(:DEFAULT :flock);` to `use Fcntl ();` in lib/ConfigServer/cseUI.pm
- [X] T015 [P] [US2] Change `use File::Find;` to `use File::Find ();` in lib/ConfigServer/cseUI.pm
- [X] T016 [P] [US2] Change `use File::Copy;` to `use File::Copy ();` in lib/ConfigServer/cseUI.pm
- [X] T017 [P] [US2] Change `use IPC::Open3;` to `use IPC::Open3 ();` in lib/ConfigServer/cseUI.pm
- [X] T018 [US2] Remove `use Exporter qw(import);` line in lib/ConfigServer/cseUI.pm
- [X] T019 [US2] Remove `our @ISA = qw(Exporter);` line in lib/ConfigServer/cseUI.pm
- [X] T020 [US2] Remove `our @EXPORT_OK = qw();` line in lib/ConfigServer/cseUI.pm
- [X] T021 [US2] Update all `LOCK_SH` to `Fcntl::LOCK_SH` in lib/ConfigServer/cseUI.pm
- [X] T022 [US2] Update all `LOCK_EX` to `Fcntl::LOCK_EX` in lib/ConfigServer/cseUI.pm
- [X] T023 [US2] Update all `O_RDONLY`, `O_WRONLY`, `O_CREAT`, `O_TRUNC` to fully qualified `Fcntl::*` in lib/ConfigServer/cseUI.pm
- [X] T024 [US2] Update all `find(...)` calls to `File::Find::find(...)` in lib/ConfigServer/cseUI.pm
- [X] T025 [US2] Update all `copy(...)` calls to `File::Copy::copy(...)` in lib/ConfigServer/cseUI.pm
- [X] T026 [US2] Update all `open3(...)` calls to `IPC::Open3::open3(...)` in lib/ConfigServer/cseUI.pm
- [X] T027 [US2] Verify module compiles with `perl -cw -Ilib lib/ConfigServer/cseUI.pm`

**Checkpoint**: US2 complete - module uses modern Perl standards

---

## Phase 6: User Story 3 - Make Subroutines Private (Priority: P3)

**Goal**: All internal functions prefixed with underscore, all calls use modern syntax

**Independent Test**: Only `main()` is public; all Perl 4-style `&subname` calls removed

### Implementation for User Story 3

- [X] T028 [US3] Rename `sub loadconfig` to `sub _loadconfig` in lib/ConfigServer/cseUI.pm
- [X] T029 [US3] Rename `sub browse` to `sub _browse` in lib/ConfigServer/cseUI.pm
- [X] T030 [P] [US3] Rename `sub setp` to `sub _setp` in lib/ConfigServer/cseUI.pm
- [X] T031 [P] [US3] Rename `sub seto` to `sub _seto` in lib/ConfigServer/cseUI.pm
- [X] T032 [P] [US3] Rename `sub ren` to `sub _ren` in lib/ConfigServer/cseUI.pm
- [X] T033 [P] [US3] Rename `sub moveit` to `sub _moveit` in lib/ConfigServer/cseUI.pm
- [X] T034 [P] [US3] Rename `sub copyit` to `sub _copyit` in lib/ConfigServer/cseUI.pm
- [X] T035 [P] [US3] Rename `sub mycopy` to `sub _mycopy` in lib/ConfigServer/cseUI.pm
- [X] T036 [P] [US3] Rename `sub cnewd` to `sub _cnewd` in lib/ConfigServer/cseUI.pm
- [X] T037 [P] [US3] Rename `sub cnewf` to `sub _cnewf` in lib/ConfigServer/cseUI.pm
- [X] T038 [P] [US3] Rename `sub del` to `sub _del` in lib/ConfigServer/cseUI.pm
- [X] T039 [P] [US3] Rename `sub view` to `sub _view` in lib/ConfigServer/cseUI.pm
- [X] T040 [P] [US3] Rename `sub console` to `sub _console` in lib/ConfigServer/cseUI.pm
- [X] T041 [P] [US3] Rename `sub cd` to `sub _cd` in lib/ConfigServer/cseUI.pm
- [X] T042 [P] [US3] Rename `sub edit` to `sub _edit` in lib/ConfigServer/cseUI.pm
- [X] T043 [P] [US3] Rename `sub save` to `sub _save` in lib/ConfigServer/cseUI.pm
- [X] T044 [P] [US3] Rename `sub uploadfile` to `sub _uploadfile` in lib/ConfigServer/cseUI.pm
- [X] T045 [P] [US3] Rename `sub countfiles` to `sub _countfiles` in lib/ConfigServer/cseUI.pm
- [X] T046 [US3] Update `&loadconfig` call to `_loadconfig()` in main() in lib/ConfigServer/cseUI.pm
- [X] T047 [US3] Update `&view` call to `_view()` in main() in lib/ConfigServer/cseUI.pm
- [X] T048 [US3] Update all `&browse` calls to `_browse()` in lib/ConfigServer/cseUI.pm
- [X] T049 [US3] Update all `&setp` calls to `_setp()` in lib/ConfigServer/cseUI.pm
- [X] T050 [US3] Update all `&seto` calls to `_seto()` in lib/ConfigServer/cseUI.pm
- [X] T051 [US3] Update all `&ren` calls to `_ren()` in lib/ConfigServer/cseUI.pm
- [X] T052 [US3] Update all `&moveit` calls to `_moveit()` in lib/ConfigServer/cseUI.pm
- [X] T053 [US3] Update all `&copyit` calls to `_copyit()` in lib/ConfigServer/cseUI.pm
- [X] T054 [US3] Update all `&mycopy` calls to `_mycopy()` in lib/ConfigServer/cseUI.pm
- [X] T055 [US3] Update all `&cnewd` calls to `_cnewd()` in lib/ConfigServer/cseUI.pm
- [X] T056 [US3] Update all `&cnewf` calls to `_cnewf()` in lib/ConfigServer/cseUI.pm
- [X] T057 [US3] Update all `&del` calls to `_del()` in lib/ConfigServer/cseUI.pm
- [X] T058 [US3] Update all `&console` calls to `_console()` in lib/ConfigServer/cseUI.pm
- [X] T059 [US3] Update all `&cd` calls to `_cd()` in lib/ConfigServer/cseUI.pm
- [X] T060 [US3] Update all `&edit` calls to `_edit()` in lib/ConfigServer/cseUI.pm
- [X] T061 [US3] Update all `&save` calls to `_save()` in lib/ConfigServer/cseUI.pm
- [X] T062 [US3] Update all `&uploadfile` calls to `_uploadfile()` in lib/ConfigServer/cseUI.pm
- [X] T063 [US3] Update all `&countfiles` calls to `_countfiles()` in lib/ConfigServer/cseUI.pm
- [X] T064 [US3] Verify no Perl 4-style `&subname` calls remain with `grep -E '&\w+' lib/ConfigServer/cseUI.pm`
- [X] T065 [US3] Verify module compiles with `perl -cw -Ilib lib/ConfigServer/cseUI.pm`

**Checkpoint**: US3 complete - only `main()` is public, all internal functions are private

---

## Phase 7: User Story 4 - Add POD Documentation (Priority: P4)

**Goal**: Module has proper POD documentation for NAME, SYNOPSIS, DESCRIPTION, and main()

**Independent Test**: `podchecker lib/ConfigServer/cseUI.pm` reports no errors

### Implementation for User Story 4

- [X] T066 [US4] Add module-level POD (NAME, SYNOPSIS, DESCRIPTION) after package declaration in lib/ConfigServer/cseUI.pm
- [X] T067 [US4] Add POD documentation for `main()` function in lib/ConfigServer/cseUI.pm
- [X] T068 [US4] Add VERSION and AUTHOR POD sections at end of lib/ConfigServer/cseUI.pm
- [X] T069 [US4] Verify POD with `podchecker lib/ConfigServer/cseUI.pm`
- [X] T070 [US4] Verify POD renders correctly with `perldoc lib/ConfigServer/cseUI.pm`

**Checkpoint**: US4 complete - POD documentation passes podchecker

---

## Phase 8: User Story 5 - Add Unit Test Coverage (Priority: P5)

**Goal**: Comprehensive unit tests for cseUI.pm

**Independent Test**: `prove -wlvm t/ConfigServer-cseUI.t` passes

### Tests for User Story 5

- [X] T071 [US5] Create test file t/ConfigServer-cseUI.t with standardized header
- [X] T072 [US5] Add subtest "Module loading" to verify VERSION and main() exist in t/ConfigServer-cseUI.t
- [X] T073 [US5] Add subtest "main function exists and is callable" in t/ConfigServer-cseUI.t
- [X] T074 [US5] Add mock for file I/O operations in t/ConfigServer-cseUI.t
- [X] T075 [US5] Add subtest testing `do=browse` action with mocked directory in t/ConfigServer-cseUI.t
- [X] T076 [US5] Add subtest testing `do=edit` action with mocked file in t/ConfigServer-cseUI.t
- [X] T077 [US5] Add subtest testing `do=view` action with mocked file in t/ConfigServer-cseUI.t
- [X] T078 [US5] Add subtest testing unknown action falls through to browse in t/ConfigServer-cseUI.t
- [X] T079 [US5] Add subtest testing output capture helper function in t/ConfigServer-cseUI.t
- [X] T080 [US5] Verify test file syntax with `perl -cw -Ilib t/ConfigServer-cseUI.t`
- [X] T081 [US5] Verify tests pass with `prove -wlvm t/ConfigServer-cseUI.t`

**Checkpoint**: US5 complete - tests pass with prove

---

## Phase 9: Polish & Cross-Cutting Concerns

**Purpose**: Final validation and cleanup

- [X] T082 Run `make test` to verify no regressions to existing tests
- [X] T083 Run `perltidy` on lib/ConfigServer/cseUI.pm per .perltidyrc
- [X] T084 Run quickstart.md validation checklist
- [X] T085 Final review: verify SC-001 through SC-009 success criteria are met

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - start immediately
- **Foundational (Phase 2)**: N/A - no foundational tasks needed
- **US0 (Phase 3)**: Depends on Setup - establishes clean baseline
- **US1 (Phase 4)**: Depends on US0 - removes unused globals
- **US2 (Phase 5)**: Depends on US1 - modernizes imports and pragmas
- **US3 (Phase 6)**: Depends on US2 - renames functions and updates calls
- **US4 (Phase 7)**: Depends on US3 - documents public API (only main())
- **US5 (Phase 8)**: Depends on US4 - tests the modernized module
- **Polish (Phase 9)**: Depends on all user stories complete

### User Story Dependencies

- **US0**: Must complete before US1 (clean baseline)
- **US1**: Must complete before US2 (global variables cleaned up)
- **US2**: Must complete before US3 (imports modernized before function renaming)
- **US3**: Must complete before US4 (private functions named before documenting public API)
- **US4**: Must complete before US5 (POD complete before testing)
- **US5**: Final user story - tests the complete modernization

### Parallel Opportunities

**Within US2 (T015-T017)**: Import changes can be done in parallel
**Within US3 (T030-T045)**: Function renames can be done in parallel (all are independent)

---

## Parallel Example: User Story 3 Function Renames

```bash
# Launch all function renames together (T030-T045):
Task: "Rename sub setp to sub _setp"
Task: "Rename sub seto to sub _seto"  
Task: "Rename sub ren to sub _ren"
Task: "Rename sub moveit to sub _moveit"
# ... etc.
# Then sequentially update all calls (T046-T063)
```

---

## Implementation Strategy

### Sequential Delivery (Recommended for Single Developer)

1. Complete Phase 1: Setup (T001-T002)
2. Complete Phase 3: US0 - Clean baseline (T003-T007)
3. Complete Phase 4: US1 - Global variables (T008-T011)
4. Complete Phase 5: US2 - Code modernization (T012-T027)
5. Complete Phase 6: US3 - Private functions (T028-T065)
6. Complete Phase 7: US4 - POD documentation (T066-T070)
7. Complete Phase 8: US5 - Unit tests (T071-T081)
8. Complete Phase 9: Polish (T082-T085)

### Verification at Each Checkpoint

After each user story, verify: `perl -cw -Ilib lib/ConfigServer/cseUI.pm`

---

## Summary

| Phase | User Story | Task Range | Task Count |
|-------|-----------|------------|------------|
| 1 | Setup | T001-T002 | 2 |
| 2 | Foundational | (none) | 0 |
| 3 | US0: Remove Comments | T003-T007 | 5 |
| 4 | US1: Global Variables | T008-T011 | 4 |
| 5 | US2: Code Modernization | T012-T027 | 16 |
| 6 | US3: Private Functions | T028-T065 | 38 |
| 7 | US4: POD Documentation | T066-T070 | 5 |
| 8 | US5: Unit Tests | T071-T081 | 11 |
| 9 | Polish | T082-T085 | 4 |
| **Total** | | | **85** |

**Parallel Opportunities**: 22 tasks marked [P]
**Independent Test Criteria**: Each user story has verification command
**Suggested MVP Scope**: Complete through US3 (Phase 6) for a functional modernized module; US4-US5 add documentation and tests
