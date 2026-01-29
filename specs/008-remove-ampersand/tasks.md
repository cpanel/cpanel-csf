# Tasks: Remove Ampersand Prefix from Perl Function Calls

**Input**: Design documents from `/specs/008-remove-ampersand/`
**Prerequisites**: plan.md (required), spec.md (required for user stories), research.md, quickstart.md

**Tests**: No new tests needed - existing Test2 suite validates refactoring

**Organization**: Tasks are grouped by transformation phase to enable incremental validation

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US1, US2, US3)
- Include exact file paths in descriptions

## Phase 0: Setup & Baseline

**Purpose**: Establish clean baseline and backup strategy before transformations

- [X] T001 [US3] Verify clean git working directory: `git status` shows no uncommitted changes
- [X] T002 [US3] Run baseline test suite: `make test > /tmp/baseline-test-results.txt 2>&1`
- [X] T003 [US3] Record baseline exit code: `echo $? > /tmp/baseline-exit-code.txt`
- [X] T004 [US3] Syntax-check all Perl files: `find . -type f \( -name '*.pl' -o -name '*.pm' -o -name '*.t' \) ! -path './etc/*' ! -path './.git/*' ! -path './tpl/*' | xargs -I {} sh -c 'perl -cw -Ilib {} 2>&1 || echo "FAIL: {}"' > /tmp/baseline-syntax-check.txt`
- [X] T005 [US1] Count ampersand instances: `grep -r '&\w\+(' --include='*.pl' --include='*.pm' --include='*.t' . 2>/dev/null | wc -l > /tmp/baseline-ampersand-count.txt`

**Checkpoint**: Baseline established, ready for transformation

---

## Phase 1: Transform Test Files (Lowest Risk)

**Purpose**: Modernize test file function calls with immediate validation

**⚠️ CRITICAL**: Test files first to minimize risk - tests validate themselves

### User Story 1 - Modernize Test Files

- [X] T006 [US1] Find all test files: `find t/ -name '*.t' > /tmp/test-files.txt`
- [X] T007 [US1] Create test files backup: `tar czf /tmp/csf-tests-backup-$(date +%Y%m%d-%H%M%S).tar.gz t/`
- [X] T008 [US1] Transform test files - Iteration 1: `find t/ -name '*.t' | while read file; do perl -i.bak -pe 's/(?<!\\\\)(?<!goto\\s)&(\\w+)\\s*\\(/$1(/g' "$file"; done`
- [X] T009 [US1] Transform test files - Iteration 2 (nested): `find t/ -name '*.t' | while read file; do perl -i -pe 's/(?<!\\\\)(?<!goto\\s)&(\\w+)\\s*\\(/$1(/g' "$file"; done`
- [X] T010 [US2] Manual review of test files for preserved patterns: Check t/*.t for `\&`, `goto &` remain unchanged
- [X] T011 [US3] Validate test syntax: `find t/ -name '*.t' | xargs -I {} perl -cw -Ilib {} 2>&1 | tee /tmp/tests-syntax-check.txt`
- [X] T012 [US3] Run test suite after test transformation: `make test | tee /tmp/tests-after-transformation.txt`
- [X] T013 [US3] Verify test exit code is 0: Check `$?` equals 0
- [X] T014 [US1] Remove .bak files from tests: `find t/ -name '*.bak' -delete`

**Checkpoint**: Test files modernized and validated - proceed to modules

---

## Phase 2: Transform Library Modules

**Purpose**: Modernize library module function calls with validation

### User Story 1 - Modernize Library Modules

- [X] T015 [US1] Find all module files: `find lib/ConfigServer/ -name '*.pm' > /tmp/module-files.txt`
- [X] T016 [US1] Create modules backup: `tar czf /tmp/csf-lib-backup-$(date +%Y%m%d-%H%M%S).tar.gz lib/`
- [X] T017 [US1] Transform modules - Iteration 1: `find lib/ConfigServer/ -name '*.pm' | while read file; do perl -i.bak -pe 's/(?<!\\\\)(?<!goto\\s)&(\\w+)\\s*\\(/$1(/g' "$file"; done`
- [X] T018 [US1] Transform modules - Iteration 2 (nested): `find lib/ConfigServer/ -name '*.pm' | while read file; do perl -i -pe 's/(?<!\\\\)(?<!goto\\s)&(\\w+)\\s*\\(/$1(/g' "$file"; done`
- [X] T019 [US2] Check for prototyped functions in modules: `grep -rn 'sub \\w\\+\\s*([^)]*)\\s*{' lib/ConfigServer/ --include='*.pm'` (flag any legacy prototypes for manual review per FR-012)
- [X] T020 [US2] Manual review of modules for preserved patterns: Check lib/ConfigServer/*.pm for `\&`, `goto &` remain unchanged
- [X] T021 [US3] Validate module syntax: `find lib/ConfigServer/ -name '*.pm' | xargs -I {} perl -cw -Ilib {} 2>&1 | tee /tmp/modules-syntax-check.txt`
- [X] T022 [US3] Run test suite after module transformation: `make test | tee /tmp/modules-after-transformation.txt`
- [X] T023 [US3] Verify module test exit code is 0
- [X] T024 [US1] Remove .bak files from modules: `find lib/ConfigServer/ -name '*.bak' -delete`

**Checkpoint**: Library modules modernized and validated - proceed to scripts

---

## Phase 3: Transform Root Scripts

**Purpose**: Modernize root-level Perl script function calls

### User Story 1 - Modernize Root Scripts

- [X] T025 [US1] Find root-level Perl scripts: `find . -maxdepth 1 -name '*.pl' > /tmp/root-scripts.txt`
- [X] T026 [US1] Create root scripts backup: `tar czf /tmp/csf-root-scripts-backup-$(date +%Y%m%d-%H%M%S).tar.gz *.pl`
- [X] T027 [US1] Transform root scripts - Iteration 1: `find . -maxdepth 1 -name '*.pl' | while read file; do perl -i.bak -pe 's/(?<!\\\\)(?<!goto\\s)&(\\w+)\\s*\\(/$1(/g' "$file"; done`
- [X] T028 [US1] Transform root scripts - Iteration 2 (nested): `find . -maxdepth 1 -name '*.pl' | while read file; do perl -i -pe 's/(?<!\\\\)(?<!goto\\s)&(\\w+)\\s*\\(/$1(/g' "$file"; done`
- [X] T029 [US2] Manual review of root scripts for preserved patterns: Check *.pl for `\&`, `goto &` remain unchanged
- [X] T030 [US3] Validate root script syntax: `find . -maxdepth 1 -name '*.pl' | xargs -I {} perl -cw -Ilib {} 2>&1 | tee /tmp/scripts-syntax-check.txt`
- [X] T031 [US3] Run test suite after script transformation: `make test | tee /tmp/scripts-after-transformation.txt`
- [X] T032 [US3] Verify script test exit code is 0
- [X] T033 [US1] Remove .bak files from root scripts: `find . -maxdepth 1 -name '*.bak' -delete`

**Checkpoint**: Root scripts modernized and validated - proceed to utilities

---

## Phase 4: Transform Utilities and CGI

**Purpose**: Modernize utility and CGI script function calls

### User Story 1 - Modernize Utilities and CGI Scripts

- [X] T034 [P] [US1] Transform bin/ utilities - Iteration 1: `find bin/ -name '*.pl' | while read file; do perl -i.bak -pe 's/(?<!\\\\)(?<!goto\\s)&(\\w+)\\s*\\(/$1(/g' "$file"; done`
- [X] T035 [P] [US1] Transform bin/ utilities - Iteration 2: `find bin/ -name '*.pl' | while read file; do perl -i -pe 's/(?<!\\\\)(?<!goto\\s)&(\\w+)\\s*\\(/$1(/g' "$file"; done`
- [X] T036 [P] [US1] Transform cpanel/ CGI - Iteration 1: `find cpanel/ \( -name '*.cgi' -o -name '*.pl' \) | while read file; do perl -i.bak -pe 's/(?<!\\\\)(?<!goto\\s)&(\\w+)\\s*\\(/$1(/g' "$file"; done`
- [X] T037 [P] [US1] Transform cpanel/ CGI - Iteration 2: `find cpanel/ \( -name '*.cgi' -o -name '*.pl' \) | while read file; do perl -i -pe 's/(?<!\\\\)(?<!goto\\s)&(\\w+)\\s*\\(/$1(/g' "$file"; done`
- [X] T038 [US2] Manual review utilities for preserved patterns: Check bin/*.pl, cpanel/*.cgi for `\&`, `goto &`
- [X] T039 [US3] Validate utilities syntax: `find bin/ cpanel/ \( -name '*.pl' -o -name '*.cgi' \) | xargs -I {} perl -cw -Ilib {} 2>&1 | tee /tmp/utilities-syntax-check.txt`
- [X] T040 [US3] Run test suite after utility transformation: `make test | tee /tmp/utilities-after-transformation.txt`
- [X] T041 [US3] Verify utilities test exit code is 0
- [X] T042 [US1] Remove .bak files from utilities: `find bin/ cpanel/ -name '*.bak' -delete`

**Checkpoint**: All Perl files transformed - proceed to final validation

---

## Phase 5: Final Validation & Verification

**Purpose**: Comprehensive validation of all transformations against success criteria

### User Story 3 - Verify Code Functionality

- [X] T043 [US3] Run final test suite: `make test > /tmp/final-test-results.txt 2>&1`
- [X] T044 [US3] Record final exit code: `echo $? > /tmp/final-exit-code.txt`
- [X] T045 [US3] Compare test exit codes: `diff /tmp/baseline-exit-code.txt /tmp/final-exit-code.txt` (SC-002: must match)
- [X] T046 [US3] Syntax-check all Perl files final: `find . -type f \( -name '*.pl' -o -name '*.pm' -o -name '*.t' \) ! -path './etc/*' ! -path './.git/*' ! -path './tpl/*' | xargs -I {} sh -c 'perl -cw -Ilib {} 2>&1 || echo "FAIL: {}"'` (SC-003: must all pass)
- [X] T047 [US1] Count remaining ampersands: `grep -r '&\w\+(' --include='*.pl' --include='*.pm' --include='*.t' . 2>/dev/null > /tmp/remaining-ampersands.txt`
- [X] T048 [US2] Verify only special cases remain: `cat /tmp/remaining-ampersands.txt | grep -v '\\&' | grep -v 'goto &' | grep -v '&nbsp;' | grep -v '&copy;'` (SC-001: should be empty)

**Checkpoint**: All success criteria validated

---

## Phase 6: Manual Review & Quality Assurance

**Purpose**: Human verification of transformation quality

### User Story 1 & 2 - Review Sample Transformations

- [X] T049 [US1] Review sample test file: Manually inspect `t/ConfigServer-ServerStats.t` for correct transformations
- [X] T050 [US1] Review sample module: Manually inspect `lib/ConfigServer/URLGet.pm` for correct transformations
- [X] T051 [US1] Review sample script: Manually inspect `auto.pl` for correct transformations
- [X] T052 [US1] Review sample utility: Manually inspect `bin/csftest.pl` for correct transformations
- [X] T053 [US2] Verify signal handlers preserved: Check `lfd.pl` for `$SIG{INT} = \&cleanup` unchanged
- [X] T054 [US2] Verify goto constructs preserved: Check `t/ConfigServer-KillSSH.t` for `goto &CORE::flock` unchanged
- [X] T055 [US2] Verify string literals unchanged: Check for `&nbsp;`, `&copy;` in HTML output
- [X] T056 [US3] Compare test output details: Review `/tmp/baseline-test-results.txt` vs `/tmp/final-test-results.txt` for identical behavior (SC-004)

**Checkpoint**: Manual review complete, quality verified

---

## Phase 7: Commit & Documentation

**Purpose**: Create proper commit with constitutional compliance

### Finalization

- [ ] T057 Stage all changes: `git add -A`
- [ ] T058 Create commit with proper message format (per constitution Section V):
```
Modernize Perl function call syntax

case CPANEL-XXXXX: Remove legacy ampersand prefix from all function calls.
Transform &function() to function() and &function to function() throughout
codebase per Constitution Section III Perl Standards Compliance.

Preserve special cases:
- Subroutine references: \&sub
- Signal handlers: $SIG{FOO} = \&handler  
- Tail call optimization: goto &sub

Validated with 100% test pass rate and full syntax check.

Changelog: Modernized Perl function call syntax by removing legacy
 ampersand prefixes, improving code readability and maintainability while
 maintaining full backward compatibility and test coverage.
```

**Checkpoint**: Feature complete and committed

---

## Task Summary

**Total Tasks**: 58
- **Phase 0 (Setup)**: 5 tasks
- **Phase 1 (Tests)**: 9 tasks  
- **Phase 2 (Modules)**: 10 tasks
- **Phase 3 (Scripts)**: 9 tasks
- **Phase 4 (Utilities)**: 9 tasks
- **Phase 5 (Validation)**: 6 tasks
- **Phase 6 (Review)**: 8 tasks
- **Phase 7 (Commit)**: 2 tasks

**Parallel Opportunities**: T034-T037 (bin/ and cpanel/ can run simultaneously)

**Critical Path**: Phase 0 → Phase 1 → Phase 2 → Phase 3 → Phase 4 → Phase 5 → Phase 6 → Phase 7 (mostly sequential due to validation dependencies)

**Time Estimate**: ~75 minutes total (per quickstart.md)

## Success Criteria Mapping

| Success Criterion | Validated By Tasks |
|-------------------|-------------------|
| SC-001: Zero legacy patterns | T005, T047, T048 |
| SC-002: 100% test pass | T002, T012, T022, T031, T040, T043, T045 |
| SC-003: All files pass syntax | T004, T011, T021, T030, T039, T046 |
| SC-004: No functionality changes | T045, T056 |
| SC-005: Only special cases remain | T048 |

## Functional Requirements Mapping

| Requirement | Implemented By Tasks |
|-------------|---------------------|
| FR-001: Transform &func() | T008-T009, T017-T018, T027-T028, T034-T037 |
| FR-002: Transform &func with parens | T008-T009, T017-T018, T027-T028, T034-T037 |
| FR-003: Preserve \&ref | T010, T020, T029, T038 |
| FR-004: Preserve signal handlers | T053 |
| FR-005: Preserve goto & | T054 |
| FR-006: Syntax validation | T004, T011, T021, T030, T039, T046 |
| FR-007: Tests pass | T002, T012, T022, T031, T040, T043 |
| FR-008: No behavioral changes | T045, T056 |
| FR-009: Only .pl/.pm/.t files | T006, T015, T025, T034, T036 |
| FR-010: Preserve strings/comments | T055 |
| FR-011: Iterative transformation | All iteration 1 & 2 tasks |
| FR-012: Prototype review | T019 |
