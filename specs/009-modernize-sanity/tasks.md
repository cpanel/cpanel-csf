# Tasks: Modernize Sanity.pm Module

**Input**: Design documents from `/root/projects/csf/specs/009-modernize-sanity/`  
**Prerequisites**: ✅ plan.md, ✅ spec.md, ✅ research.md, ✅ data-model.md, ✅ quickstart.md

**Tests**: Unit tests explicitly requested in User Story 3 (P3) - included below

**Organization**: Tasks grouped by user story (P0 → P1 → P2 → P3) for independent implementation and testing

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US0, US1, US2, US3)
- Include exact file paths in descriptions

## Phase 1: Setup

**Purpose**: Verify environment and ensure design documents are complete

- [ ] T001 Verify all design documents exist in specs/009-modernize-sanity/
- [ ] T002 Verify current module loads: `perl -e 'use lib "lib"; use ConfigServer::Sanity; print "OK\n"'`
- [ ] T003 Create tmp/sanity-backup.pm backup of original module

---

## Phase 2: Foundational

**Purpose**: No foundational tasks needed - single module modernization with no shared infrastructure

**Checkpoint**: Skip to User Story implementation (P0 first)

---

## Phase 3: User Story 0 - Remove Legacy Comment Clutter (Priority: P0)

**Goal**: Clean module of legacy comment markers (# start/# end, ###...###) for clean baseline

**Independent Test**: `grep -E "^# (end|start) \w+$" lib/ConfigServer/Sanity.pm` returns nothing, module compiles

### Implementation for User Story 0

- [ ] T004 [US0] Search for comment separators in lib/ConfigServer/Sanity.pm
- [ ] T005 [US0] Remove any `# start` and `# end` markers (if present) in lib/ConfigServer/Sanity.pm
- [ ] T006 [US0] Remove any `###...###` dividers between functions (if present) in lib/ConfigServer/Sanity.pm
- [ ] T007 [US0] Ensure single blank line separates functions in lib/ConfigServer/Sanity.pm
- [ ] T008 [US0] Verify module compiles: `perl -cw -Ilib lib/ConfigServer/Sanity.pm`

**Checkpoint**: Module has no comment clutter, compiles successfully (SC-006 verified)

---

## Phase 4: User Story 1 - Code Modernization (Priority: P1) 🎯 MVP

**Goal**: Transform to modern Perl with lazy-loading, no Exporter, disabled imports, fully qualified calls

**Independent Test**: `perl -cw -Ilib lib/ConfigServer/Sanity.pm` passes, no compile-time file I/O, module loads without side effects

### Implementation for User Story 1

- [ ] T009 [P] [US1] Replace `use strict;` with `use cPstrict;` in lib/ConfigServer/Sanity.pm line 21
- [ ] T010 [P] [US1] Change `use Fcntl qw(:DEFAULT :flock);` to `use Fcntl ();` in lib/ConfigServer/Sanity.pm line 23
- [ ] T011 [P] [US1] Add `use Carp ();` after Fcntl import in lib/ConfigServer/Sanity.pm
- [ ] T012 [US1] Remove `use Exporter qw(import);` in lib/ConfigServer/Sanity.pm line 27
- [ ] T013 [US1] Remove `our @ISA = qw(Exporter);` in lib/ConfigServer/Sanity.pm line 29
- [ ] T014 [US1] Remove `our @EXPORT_OK = qw(sanity);` in lib/ConfigServer/Sanity.pm line 30
- [ ] T015 [US1] Move package-level variables ($sanityfile) into sanity() function scope in lib/ConfigServer/Sanity.pm
- [ ] T016 [US1] Replace package-level %sanity and %sanitydefault with `state` variables in sanity() in lib/ConfigServer/Sanity.pm
- [ ] T017 [US1] Add `state $loaded;` flag in sanity() function in lib/ConfigServer/Sanity.pm
- [ ] T018 [US1] Move file opening/reading code (lines 36-45) into lazy-load block in sanity() in lib/ConfigServer/Sanity.pm
- [ ] T019 [US1] Change `LOCK_SH` to `Fcntl::LOCK_SH` in lazy-load block in lib/ConfigServer/Sanity.pm
- [ ] T020 [US1] Move IPSET config check (lines 47-52) into lazy-load block in sanity() in lib/ConfigServer/Sanity.pm
- [ ] T021 [US1] Change config loading to use `ConfigServer::Config->get_config('IPSET')` in lib/ConfigServer/Sanity.pm
- [ ] T022 [US1] Add error handling for file operations with Carp::croak() in lib/ConfigServer/Sanity.pm
- [ ] T023 [US1] Set `$loaded = 1;` at end of lazy-load block in lib/ConfigServer/Sanity.pm
- [ ] T024 [US1] Verify no compile-time I/O: `perl -e 'use lib "lib"; use ConfigServer::Sanity; print "OK\n"'`
- [ ] T025 [US1] Verify module compiles: `perl -cw -Ilib lib/ConfigServer/Sanity.pm`
- [ ] T026 [US1] Verify no Exporter: `grep -E "(use Exporter|@EXPORT|@ISA)" lib/ConfigServer/Sanity.pm` returns nothing

**Checkpoint**: Module modernized with lazy-loading, no Exporter, all imports disabled (SC-001, SC-002, SC-007, SC-008 verified)

---

## Phase 5: User Story 2 - Add POD Documentation (Priority: P2)

**Goal**: Add comprehensive POD documentation following ConfigServer module patterns

**Independent Test**: `podchecker lib/ConfigServer/Sanity.pm` reports no errors, `perldoc ConfigServer::Sanity` displays complete docs

### Implementation for User Story 2

- [ ] T027 [US2] Add module-level POD after package declaration in lib/ConfigServer/Sanity.pm
- [ ] T028 [US2] Add =head1 NAME section with "ConfigServer::Sanity - Configuration value validation" in lib/ConfigServer/Sanity.pm
- [ ] T029 [US2] Add =head1 SYNOPSIS section with usage examples in lib/ConfigServer/Sanity.pm
- [ ] T030 [US2] Add =head1 DESCRIPTION section explaining module purpose in lib/ConfigServer/Sanity.pm
- [ ] T031 [US2] Add =cut to close module-level POD in lib/ConfigServer/Sanity.pm
- [ ] T032 [US2] Add function-level POD before sanity() function in lib/ConfigServer/Sanity.pm
- [ ] T033 [US2] Add =head2 sanity section with function description in lib/ConfigServer/Sanity.pm
- [ ] T034 [US2] Document parameters ($item, $value) with B<Parameters:> section in lib/ConfigServer/Sanity.pm
- [ ] T035 [US2] Document return values with B<Returns:> section in lib/ConfigServer/Sanity.pm
- [ ] T036 [US2] Add range validation example in B<Examples:> section in lib/ConfigServer/Sanity.pm
- [ ] T037 [US2] Add discrete validation example in B<Examples:> section in lib/ConfigServer/Sanity.pm
- [ ] T038 [US2] Add =cut to close function-level POD in lib/ConfigServer/Sanity.pm
- [ ] T039 [US2] Add __END__ marker after sanity() function in lib/ConfigServer/Sanity.pm
- [ ] T040 [US2] Add =head1 SANITY CHECK FILE FORMAT section after __END__ in lib/ConfigServer/Sanity.pm
- [ ] T041 [US2] Document sanity.txt format with examples in lib/ConfigServer/Sanity.pm
- [ ] T042 [US2] Add =head1 DEPENDENCIES section listing required modules in lib/ConfigServer/Sanity.pm
- [ ] T043 [US2] Add =head1 FILES section documenting sanity.txt path in lib/ConfigServer/Sanity.pm
- [ ] T044 [US2] Add =head1 SEE ALSO section with related modules in lib/ConfigServer/Sanity.pm
- [ ] T045 [US2] Add =head1 AUTHOR section with copyright reference in lib/ConfigServer/Sanity.pm
- [ ] T046 [US2] Add =head1 COPYRIGHT section referencing header in lib/ConfigServer/Sanity.pm
- [ ] T047 [US2] Add final =cut after COPYRIGHT section in lib/ConfigServer/Sanity.pm
- [ ] T048 [US2] Verify POD syntax: `podchecker lib/ConfigServer/Sanity.pm`
- [ ] T049 [US2] Verify POD renders: `perldoc ConfigServer::Sanity` (manual check)
- [ ] T050 [US2] Verify code examples work by testing them manually

**Checkpoint**: Complete POD documentation following three-part structure (SC-003, SC-004, SC-005 verified)

---

## Phase 6: User Story 3 - Add Unit Test Coverage (Priority: P3)

**Goal**: Create comprehensive unit tests with mocked filesystem for isolated testing

**Independent Test**: `prove -wlvm t/ConfigServer-Sanity.t` passes with all scenarios covered

### Tests for User Story 3

- [ ] T051 [US3] Create t/ConfigServer-Sanity.t with shebang `#!/usr/local/cpanel/3rdparty/bin/perl`
- [ ] T052 [US3] Add standard test header with `use cPstrict;` in t/ConfigServer-Sanity.t
- [ ] T053 [US3] Add `use Test2::V0;` in t/ConfigServer-Sanity.t
- [ ] T054 [US3] Add `use Test2::Tools::Explain;` in t/ConfigServer-Sanity.t
- [ ] T055 [US3] Add `use Test2::Plugin::NoWarnings;` in t/ConfigServer-Sanity.t
- [ ] T056 [US3] Add `use lib 't/lib';` in t/ConfigServer-Sanity.t
- [ ] T057 [US3] Add `use MockConfig;` in t/ConfigServer-Sanity.t
- [ ] T058 [US3] Load module under test: `use ConfigServer::Sanity ();` in t/ConfigServer-Sanity.t
- [ ] T059 [P] [US3] Create subtest 'Module loads without file I/O' verifying no sanity.txt read at compile time in t/ConfigServer-Sanity.t
- [ ] T060 [P] [US3] Create subtest 'Range validation' testing 0-100 range with valid/invalid values in t/ConfigServer-Sanity.t
- [ ] T061 [P] [US3] Create subtest 'Discrete validation' testing 0|1|2 discrete values in t/ConfigServer-Sanity.t
- [ ] T062 [P] [US3] Create subtest 'Undefined sanity items' testing missing items return sane (0) in t/ConfigServer-Sanity.t
- [ ] T063 [P] [US3] Create subtest 'IPSET enabled' mocking IPSET=1 and verifying DENY_IP_LIMIT skipped in t/ConfigServer-Sanity.t
- [ ] T064 [P] [US3] Create subtest 'IPSET disabled' mocking IPSET=0 and verifying DENY_IP_LIMIT validated in t/ConfigServer-Sanity.t
- [ ] T065 [P] [US3] Create subtest 'Missing sanity.txt' testing error handling for unreadable file in t/ConfigServer-Sanity.t
- [ ] T066 [P] [US3] Create mock for file reading to inject test sanity.txt data in t/ConfigServer-Sanity.t
- [ ] T067 [US3] Add `done_testing();` at end of t/ConfigServer-Sanity.t
- [X] T068 [US3] Verify test file compiles: `perl -cw -Ilib t/ConfigServer-Sanity.t`
- [X] T069 [US3] Run tests: `prove -wlvm t/ConfigServer-Sanity.t`
- [X] T070 [US3] Run full test suite: `make test` to verify no regressions

**Checkpoint**: Comprehensive unit tests pass with mocked filesystem (SC-010 verified)

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: Final validation and documentation updates

- [X] T071 [P] Verify all success criteria from spec.md (SC-001 through SC-010)
- [X] T072 [P] Verify all 24 ConfigServer modules now have POD: `find lib/ConfigServer -name '*.pm' -exec grep -L "^=head1" {} \;` returns nothing
- [X] T073 Run full syntax check: `perl -cw -Ilib lib/ConfigServer/Sanity.pm`
- [X] T074 Run POD validation: `podchecker lib/ConfigServer/Sanity.pm`
- [X] T075 Test manual usage per quickstart.md examples
- [X] T076 Update plan.md with implementation results and any deviations
- [X] T077 Prepare commit message following constitution format
- [X] T078 Final verification: `make test` passes with zero warnings

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: N/A - no foundational tasks for single module
- **User Story 0 (Phase 3)**: Can start after Setup - MUST complete before US1
- **User Story 1 (Phase 4)**: Depends on US0 completion - MVP target
- **User Story 2 (Phase 5)**: Can start after US1 - Independent of US3
- **User Story 3 (Phase 6)**: Can start after US1 - Independent of US2
- **Polish (Phase 7)**: Depends on US0, US1, US2, US3 completion

### User Story Dependencies

- **User Story 0 (P0)**: BLOCKING - Must complete before US1 (clean baseline required)
- **User Story 1 (P1)**: Can start after US0 - No dependency on US2 or US3
- **User Story 2 (P2)**: Can start after US1 - Independent of US3 (different file sections)
- **User Story 3 (P3)**: Can start after US1 - Independent of US2 (separate test file)

### Within Each User Story

**User Story 0 (Comment Cleanup)**:
- T004 → T005 → T006 → T007 → T008 (sequential)

**User Story 1 (Modernization)**:
- T009, T010, T011 can run in parallel (different import lines)
- T012, T013, T014 sequential (removing Exporter machinery)
- T015 → T016 → T017 → T018 → T019 → T020 → T021 → T022 → T023 (sequential refactor)
- T024, T025, T026 verification (after implementation)

**User Story 2 (POD)**:
- T027-T031 (module-level POD) before T032-T038 (function POD)
- T039 (__END__ marker) before T040-T047 (end-of-file POD)
- T048, T049, T050 verification (after all POD added)

**User Story 3 (Tests)**:
- T051-T058 (test file header) before T059-T066 (test cases)
- T059-T066 (individual subtests) can run in parallel [P]
- T067-T070 verification (after all tests written)

### Parallel Opportunities

- **Setup Phase**: All 3 tasks can run in parallel
- **US0**: Sequential (same file, overlapping changes)
- **US1 Imports**: T009, T010, T011 in parallel
- **US1 Verification**: T024, T025, T026 in parallel
- **US2**: Sequential (same file sections build on each other)
- **US3 Header**: T051-T058 can run in parallel (different lines)
- **US3 Tests**: T059-T066 can run in parallel (independent subtests)
- **Polish**: T071, T072 can run in parallel

---

## Parallel Example: User Story 1 (Imports)

```bash
# Launch all import changes together:
Task T009: "Replace use strict; with use cPstrict; in lib/ConfigServer/Sanity.pm line 21"
Task T010: "Change use Fcntl qw(:DEFAULT :flock); to use Fcntl (); in lib/ConfigServer/Sanity.pm line 23"
Task T011: "Add use Carp (); after Fcntl import in lib/ConfigServer/Sanity.pm"
```

## Parallel Example: User Story 3 (Test Cases)

```bash
# Launch all test subtests together:
Task T059: "Create subtest 'Module loads without file I/O' in t/ConfigServer-Sanity.t"
Task T060: "Create subtest 'Range validation' in t/ConfigServer-Sanity.t"
Task T061: "Create subtest 'Discrete validation' in t/ConfigServer-Sanity.t"
Task T062: "Create subtest 'Undefined sanity items' in t/ConfigServer-Sanity.t"
Task T063: "Create subtest 'IPSET enabled' in t/ConfigServer-Sanity.t"
Task T064: "Create subtest 'IPSET disabled' in t/ConfigServer-Sanity.t"
Task T065: "Create subtest 'Missing sanity.txt' in t/ConfigServer-Sanity.t"
```

---

## Implementation Strategy

### MVP First (User Stories 0 + 1 Only)

1. Complete Phase 1: Setup
2. Complete Phase 3: User Story 0 (Comment Cleanup)
3. Complete Phase 4: User Story 1 (Modernization)
4. **STOP and VALIDATE**: 
   - Module compiles without warnings
   - Module loads without file I/O
   - No Exporter machinery
   - Lazy-loading works correctly
5. Can stop here for minimal viable modernization

### Incremental Delivery

1. US0: Comment Cleanup → Test compile → Commit
2. US1: Modernization → Test no side effects → Commit (MVP!)
3. US2: POD Documentation → Test with perldoc → Commit
4. US3: Unit Tests → Test with prove → Commit
5. Phase 7: Polish → Final validation → Commit

### Sequential Developer Strategy

Single developer working alone:

1. Work through US0 (T004-T008) - ~30 minutes
2. Work through US1 (T009-T026) - ~2-3 hours
3. **CHECKPOINT**: MVP complete, verify independently
4. Work through US2 (T027-T050) - ~2 hours
5. Work through US3 (T051-T070) - ~3-4 hours
6. Work through Phase 7 (T071-T078) - ~30 minutes

**Total Estimated Time**: 8-10 hours for complete implementation

---

## Task Summary

- **Total Tasks**: 78
- **User Story 0 Tasks**: 5 (T004-T008)
- **User Story 1 Tasks**: 18 (T009-T026)
- **User Story 2 Tasks**: 24 (T027-T050)
- **User Story 3 Tasks**: 20 (T051-T070)
- **Polish Tasks**: 8 (T071-T078)
- **Parallel Opportunities**: 15 tasks marked [P]
- **MVP Tasks**: Setup (3) + US0 (5) + US1 (18) = 26 tasks

---

## Notes

- All tasks reference exact file paths (lib/ConfigServer/Sanity.pm or t/ConfigServer-Sanity.t)
- [P] tasks can run in parallel within their phase
- [US0], [US1], [US2], [US3] labels map to spec.md user stories
- Each user story has independent verification checkpoint
- Stop at any checkpoint to validate story independently before proceeding
- MVP (US0 + US1) can be delivered without US2 or US3
- Follow constitution commit message format when committing
- Verify `make test` passes after each user story completion
