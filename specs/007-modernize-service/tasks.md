# Tasks: Modernize ConfigServer::Service.pm

**Input**: Design documents from `/specs/007-modernize-service/`  
**Prerequisites**: plan.md (required), spec.md (required), research.md, quickstart.md

**Tests**: Included as User Story 4 (P4) - tests are part of the spec requirements.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story?] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US0-US4)
- Include exact file paths in descriptions

---

## Phase 1: Setup

**Purpose**: Verify module compiles before making changes.

- [ ] T001 Verify module compiles before changes: `perl -cw -Ilib lib/ConfigServer/Service.pm`

---

## Phase 2: User Story 0 - Remove Legacy Comment Clutter (Priority: P0)

**Goal**: Remove all legacy comment markers (`# start`, `# end`, `###...###` dividers, `## no critic`) that clutter the code.

**Independent Test**: `grep -E '# (start|end) ' lib/ConfigServer/Service.pm` returns no results. Module compiles.

### Implementation for User Story 0

- [ ] T002 [US0] Remove `## no critic` directive from lib/ConfigServer/Service.pm
- [ ] T003 [US0] Remove `# start main` comment marker from lib/ConfigServer/Service.pm
- [ ] T004 [US0] Remove `# end main` comment marker from lib/ConfigServer/Service.pm
- [ ] T005 [US0] Remove `###...###` divider after main section from lib/ConfigServer/Service.pm
- [ ] T006 [US0] Remove `# start type` comment marker from lib/ConfigServer/Service.pm
- [ ] T007 [US0] Remove `# end type` comment marker from lib/ConfigServer/Service.pm
- [ ] T008 [US0] Remove `###...###` divider after type section from lib/ConfigServer/Service.pm
- [ ] T009 [US0] Remove `# start startlfd` comment marker from lib/ConfigServer/Service.pm
- [ ] T010 [US0] Remove `# end startlfd` comment marker from lib/ConfigServer/Service.pm
- [ ] T011 [US0] Remove `###...###` divider after startlfd section from lib/ConfigServer/Service.pm
- [ ] T012 [US0] Remove `# start stoplfd` comment marker from lib/ConfigServer/Service.pm
- [ ] T013 [US0] Remove `# end stoplfd` comment marker from lib/ConfigServer/Service.pm
- [ ] T014 [US0] Remove `###...###` divider after stoplfd section from lib/ConfigServer/Service.pm
- [ ] T015 [US0] Remove `# start restartlfd` (for restartlfd function) comment marker from lib/ConfigServer/Service.pm
- [ ] T016 [US0] Remove `# end restartlfd` (for restartlfd function) comment marker from lib/ConfigServer/Service.pm
- [ ] T017 [US0] Remove `###...###` divider after restartlfd section from lib/ConfigServer/Service.pm
- [ ] T018 [US0] Remove `# start restartlfd` (for statuslfd function - mislabeled) comment marker from lib/ConfigServer/Service.pm
- [ ] T019 [US0] Remove `# end restartlfd` (for statuslfd function - mislabeled) comment marker from lib/ConfigServer/Service.pm
- [ ] T020 [US0] Remove `###...###` divider after statuslfd section from lib/ConfigServer/Service.pm
- [ ] T021 [US0] Remove `# start printcmd` comment marker from lib/ConfigServer/Service.pm
- [ ] T022 [US0] Remove `# end printcmd` comment marker from lib/ConfigServer/Service.pm
- [ ] T023 [US0] Remove `###...###` divider after printcmd section from lib/ConfigServer/Service.pm
- [ ] T024 [US0] Verify module compiles after cleanup: `perl -cw -Ilib lib/ConfigServer/Service.pm`

**Checkpoint**: Module free of legacy markers, compiles successfully.

---

## Phase 3: User Story 1 - Code Modernization (Priority: P1) 🎯 MVP

**Goal**: Modernize imports, remove package-level side effects, add helper functions for init type detection.

**Independent Test**: `perl -cw -Ilib lib/ConfigServer/Service.pm` passes. No package-level `loadconfig()` calls. Module loads without side effects.

### Implementation for User Story 1

#### Step 1: Update Pragmas and Remove Hardcoded Paths

- [ ] T025 [US1] Replace `use strict;` with `use cPstrict;` in lib/ConfigServer/Service.pm
- [ ] T026 [US1] Remove `use lib '/usr/local/csf/lib';` from lib/ConfigServer/Service.pm

#### Step 2: Disable Imports

- [ ] T027 [US1] Change `use Carp;` to `use Carp ();` in lib/ConfigServer/Service.pm
- [ ] T028 [US1] Change `use IPC::Open3;` to `use IPC::Open3 ();` in lib/ConfigServer/Service.pm
- [ ] T029 [US1] Change `use Fcntl qw(:DEFAULT :flock);` to `use Fcntl ()` in lib/ConfigServer/Service.pm
- [ ] T030 [US1] Change `use ConfigServer::Config;` to `use ConfigServer::Config ();` in lib/ConfigServer/Service.pm
- [ ] T031 [US1] Add `use ConfigServer::Slurp ();` for file reading in lib/ConfigServer/Service.pm

#### Step 3: Remove Exporter Machinery

- [ ] T032 [US1] Remove `use Exporter qw(import);` statement from lib/ConfigServer/Service.pm
- [ ] T033 [US1] Remove `our @ISA = qw(Exporter);` statement from lib/ConfigServer/Service.pm
- [ ] T034 [US1] Remove `our @EXPORT_OK = qw();` statement from lib/ConfigServer/Service.pm

#### Step 4: Remove Package-Level Side Effects

- [ ] T035 [US1] Remove `my $config = ConfigServer::Config->loadconfig();` from lib/ConfigServer/Service.pm
- [ ] T036 [US1] Remove `my %config = $config->config();` from lib/ConfigServer/Service.pm
- [ ] T037 [US1] Remove the /proc/1/comm file reading block (open/flock/read/close/chomp/if) from lib/ConfigServer/Service.pm
- [ ] T038 [US1] Remove `$sysinit` variable declaration from lib/ConfigServer/Service.pm

#### Step 5: Add Package Variables for Testing

- [ ] T039 [US1] Add `our $INIT_TYPE_FILE = '/proc/1/comm';` package variable for test isolation in lib/ConfigServer/Service.pm

#### Step 6: Add Helper Functions

- [ ] T040 [US1] Add `_get_init_type()` function with lazy initialization using state variable in lib/ConfigServer/Service.pm
- [ ] T041 [US1] Add `_reset_init_type()` function for clearing cached state in tests in lib/ConfigServer/Service.pm

#### Step 7: Update Function Implementations

- [ ] T042 [US1] Update `type()` function to call `_get_init_type()` instead of returning `$sysinit` in lib/ConfigServer/Service.pm
- [ ] T043 [US1] Update `startlfd()` to use `_get_init_type()` and `ConfigServer::Config->get_config('SYSTEMCTL')` in lib/ConfigServer/Service.pm
- [ ] T044 [US1] Update `stoplfd()` to use `_get_init_type()` and `ConfigServer::Config->get_config('SYSTEMCTL')` in lib/ConfigServer/Service.pm
- [ ] T045 [US1] Update `restartlfd()` to use `_get_init_type()` and `ConfigServer::Config->get_config('SYSTEMCTL')` in lib/ConfigServer/Service.pm
- [ ] T046 [US1] Update `statuslfd()` to use `_get_init_type()` and `ConfigServer::Config->get_config('SYSTEMCTL')` in lib/ConfigServer/Service.pm

#### Step 8: Update IPC::Open3 Calls

- [ ] T047 [US1] Replace `open3(...)` with `IPC::Open3::open3(...)` in _printcmd() function in lib/ConfigServer/Service.pm

- [ ] T048 [US1] Verify module compiles after modernization: `perl -cw -Ilib lib/ConfigServer/Service.pm`

**Checkpoint**: Module modernized, no package-level side effects, compiles successfully.

---

## Phase 4: User Story 2 - Make Internal Subroutines Private (Priority: P2)

**Goal**: Rename internal helper function `printcmd()` to `_printcmd()` to indicate private API.

**Independent Test**: `grep 'sub _printcmd' lib/ConfigServer/Service.pm` finds the function. `grep 'sub printcmd[^_]' lib/ConfigServer/Service.pm` finds nothing.

### Implementation for User Story 2

- [ ] T049 [US2] Rename `sub printcmd` to `sub _printcmd` in lib/ConfigServer/Service.pm
- [ ] T050 [US2] Update call from `&printcmd(...)` to `_printcmd(...)` in startlfd() function in lib/ConfigServer/Service.pm
- [ ] T051 [US2] Update call from `&printcmd(...)` to `_printcmd(...)` in stoplfd() function in lib/ConfigServer/Service.pm
- [ ] T052 [US2] Update call from `&printcmd(...)` to `_printcmd(...)` in restartlfd() function in lib/ConfigServer/Service.pm
- [ ] T053 [US2] Update call from `&printcmd(...)` to `_printcmd(...)` in statuslfd() function in lib/ConfigServer/Service.pm
- [ ] T054 [US2] Verify module compiles after rename: `perl -cw -Ilib lib/ConfigServer/Service.pm`

**Checkpoint**: Internal function properly marked as private.

---

## Phase 5: User Story 3 - Add POD Documentation (Priority: P3)

**Goal**: Add comprehensive POD documentation for the module.

**Independent Test**: `podchecker lib/ConfigServer/Service.pm` reports "pod syntax OK".

### Implementation for User Story 3

- [ ] T055 [US3] Add POD NAME section after copyright header in lib/ConfigServer/Service.pm
- [ ] T056 [US3] Add POD SYNOPSIS section with usage example in lib/ConfigServer/Service.pm
- [ ] T057 [US3] Add POD DESCRIPTION section explaining service management in lib/ConfigServer/Service.pm
- [ ] T058 [US3] Add POD FUNCTIONS section documenting type(), startlfd(), stoplfd(), restartlfd(), statuslfd() in lib/ConfigServer/Service.pm
- [ ] T059 [US3] Add POD CONFIGURATION section listing SYSTEMCTL config value in lib/ConfigServer/Service.pm
- [ ] T060 [US3] Add POD SEE ALSO section in lib/ConfigServer/Service.pm
- [ ] T061 [US3] Verify POD syntax: `podchecker lib/ConfigServer/Service.pm`

**Checkpoint**: Full POD documentation added and validated.

---

## Phase 6: User Story 4 - Add Unit Test Coverage (Priority: P4)

**Goal**: Create comprehensive unit tests with mocked external dependencies.

**Independent Test**: `PERL5LIB='' prove -wlvm t/ConfigServer-Service.t` passes.

### Implementation for User Story 4

- [ ] T062 [US4] Create test file skeleton with proper shebang and imports in t/ConfigServer-Service.t
- [ ] T063 [US4] Add subtest 'Public API exists' verifying can_ok for all 5 public functions in t/ConfigServer-Service.t
- [ ] T064 [US4] Add subtest '_get_init_type returns systemd' with mocked /proc file in t/ConfigServer-Service.t
- [ ] T065 [US4] Add subtest '_get_init_type returns init for other values' with mocked /proc file in t/ConfigServer-Service.t
- [ ] T066 [US4] Add subtest '_get_init_type returns init when file missing' in t/ConfigServer-Service.t
- [ ] T067 [US4] Add subtest 'type() returns init type' in t/ConfigServer-Service.t
- [ ] T068 [US4] Add subtest 'startlfd calls correct commands for systemd' with mocked _printcmd in t/ConfigServer-Service.t
- [ ] T069 [US4] Add subtest 'startlfd calls correct commands for init' with mocked _printcmd in t/ConfigServer-Service.t
- [ ] T070 [US4] Add subtest 'stoplfd calls correct commands for systemd' with mocked _printcmd in t/ConfigServer-Service.t
- [ ] T071 [US4] Add subtest 'stoplfd calls correct commands for init' with mocked _printcmd in t/ConfigServer-Service.t
- [ ] T072 [US4] Add subtest 'restartlfd calls correct commands for systemd' with mocked _printcmd in t/ConfigServer-Service.t
- [ ] T073 [US4] Add subtest 'restartlfd calls correct commands for init' with mocked _printcmd in t/ConfigServer-Service.t
- [ ] T074 [US4] Add subtest 'statuslfd calls correct commands for systemd' with mocked _printcmd in t/ConfigServer-Service.t
- [ ] T075 [US4] Add subtest 'statuslfd calls correct commands for init' with mocked _printcmd in t/ConfigServer-Service.t
- [ ] T076 [US4] Add subtest 'statuslfd returns 0' in t/ConfigServer-Service.t
- [ ] T077 [US4] Add done_testing() and verify test file syntax: `perl -cw -Ilib t/ConfigServer-Service.t`
- [ ] T078 [US4] Run unit tests: `PERL5LIB='' prove -wlvm t/ConfigServer-Service.t`

**Checkpoint**: All unit tests pass.

---

## Phase 7: Final Validation

**Goal**: Verify all requirements are met and all tests pass.

- [ ] T079 Run `make test` to ensure all existing tests still pass
- [ ] T080 Verify no legacy markers: `grep -E '# (start|end) ' lib/ConfigServer/Service.pm`
- [ ] T081 Verify no Exporter: `grep -E '@EXPORT|@ISA|use Exporter' lib/ConfigServer/Service.pm`
- [ ] T082 Verify cPstrict: `grep 'use cPstrict' lib/ConfigServer/Service.pm`
- [ ] T083 Update checklist in specs/007-modernize-service/checklists/requirements.md

**Checkpoint**: All validation checks pass, feature complete.
