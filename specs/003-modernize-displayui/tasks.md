# Tasks: Modernize DisplayUI.pm

**Case**: CPANEL-51229  
**Branch**: `cp51229-modernize-displayui`  
**Input**: Design documents from `/specs/003-modernize-displayui/`

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US0, US1, US2, etc.)
- Includes exact file paths in descriptions

---

## Phase 1: Setup

**Purpose**: No setup needed - this is a single-module refactoring

- [X] T001 Verify branch is clean and DisplayUI.pm compiles: `perl -cw -Ilib lib/ConfigServer/DisplayUI.pm`

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: No foundational tasks needed - working on existing module

**Checkpoint**: Ready to proceed with user story implementation

---

## Phase 3: User Story 0 - Remove Legacy Comment Clutter (Priority: P0)

**Goal**: Clean up legacy formatting comments to establish a clean baseline

**Independent Test**: `grep -c "# start\|# end" lib/ConfigServer/DisplayUI.pm` returns 0

### Implementation for User Story 0

- [X] T002 [US0] Remove all `# start <name>` comment markers in lib/ConfigServer/DisplayUI.pm
- [X] T003 [US0] Remove all `# end <name>` comment markers in lib/ConfigServer/DisplayUI.pm
- [X] T004 [US0] Remove all `###...###` divider lines between subroutines (preserve copyright header lines 1 and 18) in lib/ConfigServer/DisplayUI.pm
- [X] T005 [US0] Verify module compiles: `perl -cw -Ilib lib/ConfigServer/DisplayUI.pm`

**Checkpoint**: Legacy comment clutter removed, module compiles

---

## Phase 4: User Story 1 - Remove Global Variables at Module Load Time (Priority: P1)

**Goal**: Module can be loaded without requiring production configuration files

**Independent Test**: `perl -cw -Ilib lib/ConfigServer/DisplayUI.pm` succeeds in test environment without /etc/csf/csf.conf

### Implementation for User Story 1

- [X] T006 [US1] Remove unused `$slurpreg` declaration (line 54) in lib/ConfigServer/DisplayUI.pm
- [X] T007 [US1] Remove `$cleanreg` package-level declaration (line 55) in lib/ConfigServer/DisplayUI.pm
- [X] T008 [US1] Add `my $cleanreg = ConfigServer::Slurp->cleanreg;` at start of main() subroutine in lib/ConfigServer/DisplayUI.pm
- [X] T009 [US1] Verify module compiles: `perl -cw -Ilib lib/ConfigServer/DisplayUI.pm`

**Checkpoint**: No package-level variable initialization, module compiles

---

## Phase 5: User Story 2 - Code Modernization (Priority: P2)

**Goal**: Module follows modern Perl standards with disabled imports and fully qualified names

**Independent Test**: Module compiles with `use strict;` and `use warnings;`, no Exporter machinery

### Implementation for User Story 2

- [X] T010 [US2] Remove `## no critic (...)` line (line 19) in lib/ConfigServer/DisplayUI.pm
- [X] T011 [US2] Add `use warnings;` after `use strict;` in lib/ConfigServer/DisplayUI.pm
- [X] T012 [US2] Remove `use lib '/usr/local/csf/lib';` line in lib/ConfigServer/DisplayUI.pm
- [X] T013 [US2] Change `use Fcntl qw(:DEFAULT :flock);` to `use Fcntl ();` in lib/ConfigServer/DisplayUI.pm
- [X] T014 [P] [US2] Change `use File::Basename;` to `use File::Basename ();` in lib/ConfigServer/DisplayUI.pm
- [X] T015 [P] [US2] Change `use File::Copy;` to `use File::Copy ();` in lib/ConfigServer/DisplayUI.pm
- [X] T016 [P] [US2] Change `use IPC::Open3;` to `use IPC::Open3 ();` in lib/ConfigServer/DisplayUI.pm
- [X] T017 [P] [US2] Change `use Net::CIDR::Lite;` to `use Net::CIDR::Lite ();` in lib/ConfigServer/DisplayUI.pm
- [X] T018 [US2] Remove Exporter machinery (`use Exporter`, `@ISA`, `@EXPORT_OK`) in lib/ConfigServer/DisplayUI.pm
- [X] T019 [US2] Update all Fcntl constant references to fully qualified names (O_RDWR→Fcntl::O_RDWR, LOCK_SH→Fcntl::LOCK_SH, etc.) in lib/ConfigServer/DisplayUI.pm
- [X] T020 [US2] Update all IPC::Open3 function calls to `IPC::Open3::open3(...)` in lib/ConfigServer/DisplayUI.pm
- [X] T021 [US2] Update all File::Copy function calls to `File::Copy::copy(...)` in lib/ConfigServer/DisplayUI.pm
- [X] T022 [US2] Update all File::Basename function calls to fully qualified names if any exist in lib/ConfigServer/DisplayUI.pm
- [X] T023 [US2] Convert all Perl 4-style `&subroutine` calls to modern `_subroutine()` syntax in lib/ConfigServer/DisplayUI.pm
- [X] T024 [US2] Remove dead `&modsec` branch (lines 141-143) - pre-existing bug: undefined subroutine in lib/ConfigServer/DisplayUI.pm
- [X] T025 [US2] Verify module compiles with no warnings: `perl -cw -Ilib lib/ConfigServer/DisplayUI.pm`

**Checkpoint**: Modern Perl standards applied, module compiles

---

## Phase 6: User Story 2.5 - Replace Exit Calls (Priority: P2.5)

**Goal**: Module uses `return` instead of `exit` for testability

**Independent Test**: `grep -c '\bexit\b' lib/ConfigServer/DisplayUI.pm` returns 0

### Implementation for User Story 2.5

- [X] T026 [US2.5] Replace `exit;` with `return;` at line 104 in lib/ConfigServer/DisplayUI.pm
- [X] T027 [US2.5] Replace `exit;` with `return;` at line 1083 in lib/ConfigServer/DisplayUI.pm
- [X] T028 [US2.5] Verify no exit calls remain: `grep '\bexit\b' lib/ConfigServer/DisplayUI.pm`
- [X] T029 [US2.5] Verify module compiles: `perl -cw -Ilib lib/ConfigServer/DisplayUI.pm`

**Checkpoint**: Exit calls replaced with return, module compiles

---

## Phase 7: User Story 3 - Make Subroutines Private (Priority: P3)

**Goal**: Clear public API with only `main()` exposed, all helpers prefixed with underscore

**Independent Test**: `grep "^sub " lib/ConfigServer/DisplayUI.pm` shows only `sub main` without underscore

### Implementation for User Story 3

- [X] T030 [US3] Rename `sub printcmd` to `sub _printcmd` in lib/ConfigServer/DisplayUI.pm
- [X] T031 [P] [US3] Rename `sub getethdev` to `sub _getethdev` in lib/ConfigServer/DisplayUI.pm
- [X] T032 [P] [US3] Rename `sub chart` to `sub _chart` in lib/ConfigServer/DisplayUI.pm
- [X] T033 [P] [US3] Rename `sub systemstats` to `sub _systemstats` in lib/ConfigServer/DisplayUI.pm
- [X] T034 [P] [US3] Rename `sub editfile` to `sub _editfile` in lib/ConfigServer/DisplayUI.pm
- [X] T035 [P] [US3] Rename `sub savefile` to `sub _savefile` in lib/ConfigServer/DisplayUI.pm
- [X] T036 [P] [US3] Rename `sub cloudflare` to `sub _cloudflare` in lib/ConfigServer/DisplayUI.pm
- [X] T037 [P] [US3] Rename `sub resize` to `sub _resize` in lib/ConfigServer/DisplayUI.pm
- [X] T038 [P] [US3] Rename `sub printreturn` to `sub _printreturn` in lib/ConfigServer/DisplayUI.pm
- [X] T039 [P] [US3] Rename `sub confirmmodal` to `sub _confirmmodal` in lib/ConfigServer/DisplayUI.pm
- [X] T040 [P] [US3] Rename `sub csgetversion` to `sub _csgetversion` in lib/ConfigServer/DisplayUI.pm
- [X] T041 [P] [US3] Rename `sub manualversion` to `sub _manualversion` in lib/ConfigServer/DisplayUI.pm
- [X] T042 [US3] Verify only `sub main` is public: `grep "^sub " lib/ConfigServer/DisplayUI.pm`
- [X] T043 [US3] Verify module compiles: `perl -cw -Ilib lib/ConfigServer/DisplayUI.pm`

**Checkpoint**: All internal subroutines private, module compiles

---

## Phase 8: User Story 4 - Add POD Documentation (Priority: P4)

**Goal**: Module has proper POD documentation for public API

**Independent Test**: `podchecker lib/ConfigServer/DisplayUI.pm` reports no errors

### Implementation for User Story 4

- [X] T044 [US4] Add module-level POD (NAME, SYNOPSIS, DESCRIPTION) after package declaration in lib/ConfigServer/DisplayUI.pm
- [X] T045 [US4] Add POD documentation for `main()` subroutine (parameters, returns) in lib/ConfigServer/DisplayUI.pm
- [X] T046 [US4] Add end-of-file POD sections (VERSION, AUTHOR, COPYRIGHT) after final `1;` in lib/ConfigServer/DisplayUI.pm
- [X] T047 [US4] Verify POD is valid: `podchecker lib/ConfigServer/DisplayUI.pm`
- [X] T048 [US4] Verify POD renders: `perldoc lib/ConfigServer/DisplayUI.pm`

**Checkpoint**: POD documentation complete and valid

---

## Phase 9: User Story 5 - Add Unit Test Coverage (Priority: P5)

**Goal**: Unit tests cover critical paths: module loading, input validation, representative handlers

**Independent Test**: `PERL5LIB='' prove -wlvm t/ConfigServer-DisplayUI.t` passes

### Implementation for User Story 5

- [X] T049 [US5] Create test file skeleton with standard header (use cPstrict per constitution) in t/ConfigServer-DisplayUI.t
- [X] T050 [US5] Add test: module loads successfully in t/ConfigServer-DisplayUI.t
- [X] T051 [US5] Add test: public subroutine `main` exists in t/ConfigServer-DisplayUI.t
- [X] T052 [US5] Add test: private subroutines exist (spot check) in t/ConfigServer-DisplayUI.t
- [X] T053 [US5] Add test: invalid IP address rejected in t/ConfigServer-DisplayUI.t
- [X] T054 [US5] Add test: invalid filename rejected in t/ConfigServer-DisplayUI.t
- [X] T055 [US5] Add test: RESTRICT_UI=2 disables UI in t/ConfigServer-DisplayUI.t
- [X] T056 [US5] Verify test file compiles: `perl -cw -Ilib t/ConfigServer-DisplayUI.t`
- [X] T057 [US5] Verify all tests pass: `PERL5LIB='' prove -wlvm t/ConfigServer-DisplayUI.t`

**Checkpoint**: Unit tests complete and passing

---

## Phase 10: Polish & Final Verification

**Purpose**: Final verification and regression testing

- [X] T058 Run full module verification: `perl -cw -Ilib lib/ConfigServer/DisplayUI.pm`
- [X] T059 Run POD verification: `podchecker lib/ConfigServer/DisplayUI.pm`
- [X] T060 Run test suite: `PERL5LIB='' prove -wlvm t/ConfigServer-DisplayUI.t`
- [X] T061 Run regression tests: `make test`

**Checkpoint**: All verifications pass, ready for review

---

## Dependencies

```
T001 (setup)
  └── T002-T005 (US0: comments)
        └── T006-T009 (US1: globals)
              └── T010-T025 (US2: modernization + modsec cleanup)
                    └── T026-T029 (US2.5: exit→return)
                          └── T030-T043 (US3: private subs)
                                └── T044-T048 (US4: POD)
                                      └── T049-T057 (US5: tests)
                                            └── T058-T061 (polish)
```

## Parallel Execution Opportunities

Within each phase, tasks marked with `[P]` can be executed in parallel:

- **Phase 5 (US2)**: T014, T015, T016, T017 can run in parallel
- **Phase 7 (US3)**: T031-T041 can run in parallel (different subroutines, same file)

## Implementation Strategy

**MVP**: Complete through Phase 6 (US2.5) - module modernized and testable
**Full**: Complete all phases including tests and POD

**Commit Points**:
1. After Phase 4 (US1): "Remove global variables from DisplayUI.pm"
2. After Phase 6 (US2.5): "Modernize DisplayUI.pm imports and exit calls"
3. After Phase 7 (US3): "Make DisplayUI.pm internal functions private"
4. After Phase 8 (US4): "Add POD documentation to DisplayUI.pm"
5. After Phase 9 (US5): "Add unit tests for DisplayUI.pm"
