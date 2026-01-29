# Feature Specification: Remove Ampersand Prefix from Perl Function Calls

**Feature Branch**: `008-remove-ampersand`  
**Created**: January 28, 2026  
**Status**: Draft  
**Input**: User description: "Remove ampersand prefix from Perl function calls"

## Clarifications

### Session 2026-01-28

- Q: When encountering nested ampersand calls like `&foo(&bar())`, should the transformation handle both levels in a single pass or require multiple iterations? → A: Multiple iterations - require running transformation multiple times until no changes
- Q: Some Perl subroutines use prototypes (e.g., `sub foo ($)`) which can change behavior when called with `&foo` vs `foo()`. Should prototyped subroutines be identified and excluded from transformation to avoid subtle behavioral changes? → A: Manual review - flag prototyped subs for developer review before transformation
- Q: When transforming `&functionname` calls without parentheses, should they be converted to `functionname()` with explicit empty parentheses, or is `functionname` without parentheses acceptable in contexts where it's unambiguous? → A: Always add parentheses - `&foo` → `foo()` for all cases

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Modernize Perl Function Call Syntax (Priority: P1)

Developers working with the CSF codebase should see modern Perl function call syntax that follows current best practices. When reading or modifying code, all function calls should use the standard `foo()` syntax with explicit parentheses instead of the legacy `&foo()` or `&foo` syntax.

**Why this priority**: This is the core deliverable. Modern Perl syntax improves code readability, maintainability, and aligns with Perl 5 best practices. The ampersand prefix for function calls has been unnecessary since Perl 5 was released in 1994. Explicit parentheses eliminate ambiguity.

**Independent Test**: Can be fully tested by searching the entire codebase for function calls using `&` prefix and verifying none remain (except where intentionally required for special cases like signal handlers or explicit symbol table manipulation).

**Acceptance Scenarios**:

1. **Given** a Perl file contains `&functionname()` syntax, **When** the modernization is applied, **Then** it is changed to `functionname()`
2. **Given** a Perl file contains `&functionname` syntax (without parentheses), **When** the modernization is applied, **Then** it is changed to `functionname()` with explicit parentheses for clarity
3. **Given** the entire codebase, **When** a search is performed for `&\w+\(` or `&\w+\s`, **Then** no legacy function call patterns are found (except documented special cases)

---

### User Story 2 - Preserve Special Cases (Priority: P1)

Certain legitimate uses of the ampersand prefix must be preserved, such as signal handlers, callbacks passed as references, or explicit symbol table manipulation.

**Why this priority**: Critical to avoid breaking existing functionality. While most `&` prefixes should be removed, some are semantically necessary in Perl.

**Independent Test**: Can be tested by verifying that special cases like `$SIG{__DIE__} = \&handler` or `\&subroutine` (subroutine references) remain unchanged and functional.

**Acceptance Scenarios**:

1. **Given** code uses `\&subroutine` to create a subroutine reference, **When** the modernization is applied, **Then** this syntax is preserved unchanged
2. **Given** code assigns signal handlers like `$SIG{ALRM} = \&timeout`, **When** the modernization is applied, **Then** this syntax is preserved unchanged
3. **Given** code explicitly accesses symbol tables or uses `goto &sub`, **When** the modernization is applied, **Then** these constructs are preserved unchanged

---

### User Story 3 - Verify Code Functionality (Priority: P1)

After removing ampersand prefixes, all existing tests must continue to pass, ensuring that the syntax changes do not alter program behavior.

**Why this priority**: Essential to maintain code correctness. This is a refactoring change that should not affect functionality.

**Independent Test**: Can be tested by running the complete test suite before and after changes and comparing results.

**Acceptance Scenarios**:

1. **Given** the full test suite passes before changes, **When** ampersand prefixes are removed, **Then** the full test suite still passes
2. **Given** any Perl file in the codebase, **When** syntax changes are applied, **Then** the file compiles without errors (`perl -c`)
3. **Given** the modified codebase, **When** critical workflows are executed, **Then** behavior is identical to pre-modification behavior

---

### Edge Cases

- What happens when `&` is used in string literals or comments? (Should be ignored - text content must not be modified)
- How does the system handle `goto &sub` constructs? (Should be preserved - this is a special Perl construct for tail recursion)
- What about `\&subroutine` for creating code references? (Should be preserved - ampersand is required here for reference creation)
- How are signal handlers like `$SIG{ALRM} = \&handler` treated? (Should be preserved - backslash-ampersand syntax creates code reference)
- What about method calls that incorrectly use `&` (e.g., `&$obj->method`)? (Should be corrected to `$obj->method()` if found)
- What happens with ampersands in regular expressions? (Should be ignored - regex syntax is unrelated to function calls)
- How are subroutines with prototypes handled? (Prototyped functions that use `&` should be flagged for manual developer review, as calling with/without `&` can change behavior)

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: All function calls using `&functionname()` syntax MUST be changed to `functionname()`
- **FR-002**: All function calls using `&functionname` syntax (without parentheses) MUST be changed to `functionname()` with explicit parentheses
- **FR-003**: Subroutine references using `\&subroutine` syntax MUST be preserved unchanged
- **FR-004**: Signal handler assignments using `\&handler` MUST be preserved unchanged
- **FR-005**: Special Perl constructs like `goto &sub` MUST be preserved unchanged
- **FR-006**: All modified files MUST pass Perl syntax validation (`perl -c`)
- **FR-007**: All existing tests MUST continue to pass after modifications
- **FR-008**: Changes MUST NOT alter program behavior or functionality
- **FR-009**: Only Perl source files (`.pl`, `.pm`, `.t`) MUST be modified
- **FR-010**: String literals and comments containing `&` MUST NOT be modified
- **FR-011**: Transformation MUST be run iteratively until no more ampersand-prefixed function calls remain (handles nested cases like `&foo(&bar())` through multiple passes)
- **FR-012**: Calls to subroutines with prototypes MUST be flagged for manual developer review before transformation to verify behavioral equivalence

### Scope Boundaries

- **In Scope**: All `.pl`, `.pm`, and `.t` files in the repository
- **Out of Scope**: Documentation files, configuration files, shell scripts
- **Out of Scope**: Ampersands used for bitwise AND operations or in regex patterns
- **Out of Scope**: Any non-Perl code files

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Zero legacy function call patterns (`&functionname()` or `&functionname`) remain in the codebase (except documented special cases)
- **SC-002**: 100% of existing tests pass after modifications
- **SC-003**: 100% of modified Perl files pass syntax validation
- **SC-004**: Code review confirms no functionality changes, only syntax modernization
- **SC-005**: Search for `\b&\w+\s*\(` pattern in Perl files returns only documented special cases

## Assumptions

- The codebase uses Perl 5.x (ampersand prefix for function calls has been unnecessary since Perl 5.0 released in 1994)
- Existing test suite provides adequate coverage to detect functional regressions
- Developers are familiar with modern Perl syntax and this change will improve code quality
- No external code dependencies rely on the specific use of ampersand-prefixed function calls

## Dependencies

- Existing test suite must be functional to validate changes
- Perl syntax validator (`perl -c`) must be available for validation
- Version control system (Git) to track changes and enable rollback if needed

## Out of Scope

- Fixing other Perl modernization issues beyond ampersand prefixes
- Updating documentation to reflect syntax changes
- Creating new tests specifically for this refactoring
- Performance optimization or code restructuring
- Changing coding style beyond the specific ampersand prefix removal
