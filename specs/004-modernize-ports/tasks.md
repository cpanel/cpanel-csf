# Tasks: Modernize Ports.pm

**Input**: Design documents from `/specs/004-modernize-ports/`  
**Prerequisites**: plan.md ✓, spec.md ✓, research.md ✓, data-model.md ✓, quickstart.md ✓

**Tests**: Included (requested in spec User Story 4)

**Organization**: Tasks grouped by user story to enable independent implementation.

## Format: `[ID] [P?] [Story?] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US0, US1)
- Include exact file paths in descriptions

## Path Conventions

- **Module**: `lib/ConfigServer/Ports.pm`
- **Test**: `t/ConfigServer-Ports.t`

---

## Phase 1: Setup

**Purpose**: Verify starting state

- [X] T001 Verify module compiles: `perl -cw -Ilib lib/ConfigServer/Ports.pm`

**Checkpoint**: Starting point validated

---

## Phase 2: User Story 0 - Remove Legacy Comment Clutter (Priority: P0)

**Goal**: Clean up legacy formatting comments to establish baseline

**Independent Test**: `grep -c '# start\|# end\|^###' lib/ConfigServer/Ports.pm` should return 2 (only copyright header dividers)

### Implementation for User Story 0

- [X] T003 [US0] Remove `## no critic` line (line 19) in lib/ConfigServer/Ports.pm
- [X] T004 [US0] Remove `# start main` comment (line 20) in lib/ConfigServer/Ports.pm
- [X] T005 [US0] Remove `# end main` and following `###...###` divider in lib/ConfigServer/Ports.pm
- [X] T006 [US0] Remove `# start listening` comment in lib/ConfigServer/Ports.pm
- [X] T007 [US0] Remove `# end listening` and following `###...###` divider in lib/ConfigServer/Ports.pm
- [X] T008 [US0] Remove `# start openports` comment in lib/ConfigServer/Ports.pm
- [X] T009 [US0] Remove `# end openports` and following `###...###` divider in lib/ConfigServer/Ports.pm
- [X] T010 [US0] Remove `## start hex2ip` comment in lib/ConfigServer/Ports.pm
- [X] T011 [US0] Remove `## end hex2ip` and trailing `###...###` divider in lib/ConfigServer/Ports.pm
- [X] T012 [US0] Remove `##no critic` from %printable line in lib/ConfigServer/Ports.pm
- [X] T013 [US0] Verify module compiles: `perl -cw -Ilib lib/ConfigServer/Ports.pm`

**Checkpoint**: All legacy comments removed, module compiles

---

## Phase 3: User Story 1 - Code Modernization (Priority: P1)

**Goal**: Apply modern Perl coding standards

**Independent Test**: `perl -cw -Ilib lib/ConfigServer/Ports.pm` passes with no warnings

### Implementation for User Story 1

- [X] T014 [US1] Add `use warnings;` after `use strict;` in lib/ConfigServer/Ports.pm
- [X] T015 [US1] Remove `use lib '/usr/local/csf/lib';` in lib/ConfigServer/Ports.pm
- [X] T016 [US1] Change `use Fcntl qw(:DEFAULT :flock);` to `use Fcntl ();` in lib/ConfigServer/Ports.pm
- [X] T017 [US1] Remove Exporter machinery (use Exporter, @ISA, @EXPORT_OK) in lib/ConfigServer/Ports.pm
- [X] T018 [US1] Replace `LOCK_SH` with `Fcntl::LOCK_SH` (3 occurrences) in lib/ConfigServer/Ports.pm
- [X] T019 [US1] Replace `&hex2ip(...)` with `_hex2ip(...)` (2 occurrences) in lib/ConfigServer/Ports.pm
- [X] T019a [US1] Replace `loadconfig()` with `get_config()` calls for TCP_IN, TCP6_IN, UDP_IN, UDP6_IN in lib/ConfigServer/Ports.pm
- [X] T020 [US1] Replace bareword `PROCDIR` with lexical `$procdir` handle in lib/ConfigServer/Ports.pm
- [X] T021 [US1] Replace bareword `DIR` with lexical `$fddir` handle in lib/ConfigServer/Ports.pm
- [X] T022 [US1] Add error handling for /proc/net file opens (warn on failure, continue) in lib/ConfigServer/Ports.pm
- [X] T023 [US1] Add `warn` for /proc opendir failures, continue processing in lib/ConfigServer/Ports.pm
- [X] T024 [US1] Verify module compiles: `perl -cw -Ilib lib/ConfigServer/Ports.pm`

**Checkpoint**: Code follows modern Perl standards, module compiles

---

## Phase 4: User Story 2 - Make Internal Subroutines Private (Priority: P2)

**Goal**: Rename internal functions with underscore prefix

**Independent Test**: `grep -c 'sub _hex2ip' lib/ConfigServer/Ports.pm` returns 1

### Implementation for User Story 2

- [X] T025 [US2] Rename `sub hex2ip` to `sub _hex2ip` in lib/ConfigServer/Ports.pm
- [X] T026 [US2] Add input validation: return '' for undef/empty/non-hex input in lib/ConfigServer/Ports.pm
- [X] T027 [US2] Add explicit `return '';` for unrecognized input lengths in lib/ConfigServer/Ports.pm
- [X] T028 [US2] Verify module compiles: `perl -cw -Ilib lib/ConfigServer/Ports.pm`

**Checkpoint**: Private functions marked, input validation added

---

## Phase 5: User Story 3 - Add POD Documentation (Priority: P3)

**Goal**: Add complete POD documentation for public API

**Independent Test**: `podchecker lib/ConfigServer/Ports.pm` reports no errors

### Implementation for User Story 3

- [X] T029 [US3] Add module-level POD (NAME, SYNOPSIS, DESCRIPTION) after copyright header in lib/ConfigServer/Ports.pm
- [X] T030 [US3] Add `=head2 listening` documentation before subroutine in lib/ConfigServer/Ports.pm
- [X] T031 [US3] Add `=head2 openports` documentation before subroutine in lib/ConfigServer/Ports.pm
- [X] T032 [US3] Add end-of-file POD (VERSION, AUTHOR, COPYRIGHT AND LICENSE) in lib/ConfigServer/Ports.pm
- [X] T033 [US3] Verify POD: `podchecker lib/ConfigServer/Ports.pm`

**Checkpoint**: POD documentation complete and valid

---

## Phase 6: User Story 4 - Add Unit Test Coverage (Priority: P4)

**Goal**: Create comprehensive unit tests

**Independent Test**: `prove -wlvm t/ConfigServer-Ports.t` passes

### Implementation for User Story 4

- [X] T034 [US4] Create test file skeleton with standard headers in t/ConfigServer-Ports.t
- [X] T035 [US4] Add 'Module loads correctly' subtest in t/ConfigServer-Ports.t
- [X] T036 [US4] Add '_hex2ip converts IPv4 correctly' subtest in t/ConfigServer-Ports.t
- [X] T037 [US4] Add '_hex2ip converts IPv6 correctly' subtest in t/ConfigServer-Ports.t
- [X] T038 [US4] Add '_hex2ip handles malformed input' subtest in t/ConfigServer-Ports.t
- [X] T039 [US4] Add 'openports returns correct structure' subtest with MockConfig in t/ConfigServer-Ports.t
- [X] T040 [US4] Add 'openports handles port ranges' subtest with MockConfig in t/ConfigServer-Ports.t
- [X] T041 [US4] Add 'listening skips gracefully on non-Linux' subtest in t/ConfigServer-Ports.t
- [X] T042 [US4] Verify test compiles: `perl -cw -Ilib t/ConfigServer-Ports.t`
- [X] T043 [US4] Run tests: `prove -wlvm t/ConfigServer-Ports.t`

**Checkpoint**: All tests pass

---

## Phase 7: Polish & Validation

**Purpose**: Final validation and cleanup

- [X] T044 Run full validation: `perl -cw -Ilib lib/ConfigServer/Ports.pm`
- [X] T045 Run POD check: `podchecker lib/ConfigServer/Ports.pm`
- [X] T046 Run all tests: `prove -wlvm t/ConfigServer-Ports.t`
- [X] T047 Verify no legacy patterns: `grep -E '&hex2ip|PROCDIR|opendir.*DIR,' lib/ConfigServer/Ports.pm` (should be empty)
- [X] T048 Verify copyright header unchanged (lines 1-18)
- [X] T049 Run perlcritic at severity 5: `perlcritic --severity 5 lib/ConfigServer/Ports.pm`

**Checkpoint**: Modernization complete, all acceptance criteria met

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1 (Setup)**: No dependencies
- **Phase 2 (US0)**: Depends on Phase 1
- **Phase 3 (US1)**: Depends on Phase 2
- **Phase 4 (US2)**: Depends on Phase 3 (function renamed after Perl 4 calls fixed)
- **Phase 5 (US3)**: Depends on Phase 4 (document after private functions renamed)
- **Phase 6 (US4)**: Depends on Phase 5 (test final API)
- **Phase 7 (Polish)**: Depends on all previous phases

### Sequential Requirement

This is a single-file modernization. Tasks MUST be executed sequentially within each phase since they modify the same file.

### Parallel Opportunities

- T003-T012 could be combined into a single editing session
- T014-T023 could be combined into a single editing session
- T034-T041 all touch the same new file but are sequential steps

---

## Implementation Strategy

### Recommended Approach

1. Complete all phases in order (single-file, single-developer task)
2. Each phase ends with a compile check
3. Final phase validates all acceptance criteria
4. Total estimated effort: 1-2 hours

### Commit Strategy

Commit after each phase checkpoint:
1. `git commit -m "chore: remove legacy comment clutter from Ports.pm"`
2. `git commit -m "refactor: modernize Ports.pm imports and handles"`
3. `git commit -m "refactor: rename hex2ip to _hex2ip"`
4. `git commit -m "docs: add POD documentation to Ports.pm"`
5. `git commit -m "test: add unit tests for ConfigServer::Ports"`

---

## Summary

| Phase | Tasks | Story | Description |
|-------|-------|-------|-------------|
| 1 | T001 | Setup | Verify starting state |
| 2 | T003-T013 | US0 | Remove legacy comments |
| 3 | T014-T024 | US1 | Code modernization |
| 4 | T025-T028 | US2 | Private functions |
| 5 | T029-T033 | US3 | POD documentation |
| 6 | T034-T043 | US4 | Unit tests |
| 7 | T044-T049 | Polish | Final validation |

**Total Tasks**: 48  
**Tasks per Story**: Setup(1), US0(11), US1(11), US2(4), US3(5), US4(10), Polish(6)
