<!--
SYNC IMPACT REPORT
==================
Version change: 1.0.6 → 1.0.7 (MINOR)
Modified principles: None
Added sections: 
  - V. Version Control & Commits: Requires case numbers and commit creation in speckit workflow
Templates requiring updates:
  ✅ spec-template.md - Added Case Number field to header
  ✅ plan-template.md - No changes needed
  ✅ tasks-template.md - No changes needed
Follow-up TODOs: 
  - Update speckit mode instructions to prompt for case number if not provided
  - Update speckit.implement to include commit creation as final step
-->

# CSF (ConfigServer Security & Firewall) Constitution

**Version:** 1.0.7  
**Ratified:** 2026-01-22  
**Last Amended:** 2026-01-23

## Core Principles

### I. Security-First Design (NON-NEGOTIABLE)

CSF is security infrastructure software. Every code change MUST prioritize security over convenience.

**Non-Negotiable Rules:**
- All code MUST use fail-closed designs: default to secure states and restrictive permissions
- Input validation MUST use whitelists for allowed inputs; never munge or alter untrusted inputs
- File operations MUST use three-argument form of `open()` - two-argument opens are considered significant bugs
- External command execution MUST use `Cpanel::SafeRun::Object` in production code (backticks tolerable in tests only)
- Sensitive information (stack traces, internal paths) MUST NOT be exposed in user-facing interfaces
- All errors from commands MUST be checked and handled (`$!`, `$@`, `$?`, `$^E`)

**Rationale:** CSF manages firewall rules and intrusion detection. A security flaw could compromise entire server infrastructure.

### II. Perl Standards Compliance

All Perl code MUST follow cPanel Perl conventions and modern idiomatic Perl practices.

**Non-Negotiable Rules:**
- Target Perl version: 5.36+ (cPanel-provided at `/usr/local/cpanel/3rdparty/bin/perl`)
- Every module MUST begin with `use strict;` and `use warnings;`
- MUST disable imports: use `use Module ();` instead of `use Module;` (exception: `Data::Dumper`)
- MUST use fully qualified names when referencing functions/variables from other packages
- NEVER use Perl 4 style subroutine calls (`&function` or `&function($arg)`)
- NEVER use experimental features: smart match (`~~`), `given/when`
- NEVER use bareword filehandles (exception: `STDIN`, `STDOUT`, `STDERR`)
- MUST use lexical filehandles with three-argument `open()`
- Every subroutine MUST have an explicit `return` statement
- Code MUST be tidied using `.perltidyrc` configuration (4-space indent, 400 char line limit)
- NEVER leave trailing whitespace, including in POD documentation

**Rationale:** Consistent Perl standards ensure maintainability, reduce bugs, and enable effective code review across the cPanel ecosystem.

### III. Test-First & Isolation

All new code and bug fixes MUST have corresponding unit tests using the Test2 framework.

**Non-Negotiable Rules:**
- Test files MUST use shebang: `#!/usr/local/cpanel/3rdparty/bin/perl`
- Test files MUST use `use cPstrict;` (NOT separate `use strict;` and `use warnings;`)
- Test files MUST include `Test2::V0` and `Test2::Plugin::NoWarnings`
- Test files MUST use `Test2::Tools::Explain` for complex data structure output
- Test files MUST use `use lib 't/lib';` to load test utilities
- Test files MUST use `MockConfig` when testing modules that depend on ConfigServer::Config
- Copyright headers are optional; when present, the standardized structure follows immediately after
- Test files MUST follow this standardized structure (starting after any optional copyright header):
  ```perl
  #!/usr/local/cpanel/3rdparty/bin/perl

  use cPstrict;

  use Test2::V0;
  use Test2::Tools::Explain;
  use Test2::Plugin::NoWarnings;

  use lib 't/lib';
  use MockConfig;
  ```
- NEVER load `Test2::Mock` or `Test2::Tools::Mock` separately - automatically included in `Test2::V0`
- Tests MUST NOT depend on system configuration files - use `MockConfig` for isolation
- NEVER use `require_ok()` or `use_ok()` - use regular `use Module;` statements
- Configuration loading MUST NOT occur at module load time (outside subroutines)
- Tests MUST pass `perl -cw -Ilib` syntax check before execution
- After modifying any test, `make test` MUST pass to catch regressions
- Module mocking MUST use `Test2::Mock` - NEVER use `BEGIN` blocks with `$INC` manipulation
- Module under test MUST be loaded FIRST, then create mocks for dependencies

**Rationale:** Isolated, reproducible tests enable confident refactoring and prevent regressions in security-critical code. Using `cPstrict` ensures consistency with cPanel coding standards. The `mock()` function from Test2::Mock is automatically available via Test2::V0, eliminating redundant imports. Standardized test file headers ensure consistency and completeness across the test suite.

### IV. Configuration Discipline

Configuration access MUST be deferred and isolated to enable testing and prevent side effects.

**Non-Negotiable Rules:**
- NEVER call `ConfigServer::Config->loadconfig()` at module load time (package level)
- For single/few config values: use `ConfigServer::Config->get_config($key)`
- For multiple values (5+): call `loadconfig()` within the function and create local hash copy
- Tests MUST use `MockConfig` module to mock configuration values
- Set `$Cpanel::Config::CpConfGuard::memory_only` AFTER loading dependent modules

**Rationale:** Deferred configuration loading enables unit testing without file system dependencies and prevents circular dependency issues during module compilation.

### V. Simplicity & Maintainability

Code MUST favor simplicity and clarity over cleverness.

**Non-Negotiable Rules:**
- Subroutines SHOULD use fewer than 4 arguments when possible
- Subroutines SHOULD be fewer than 30 lines when possible
- Avoid global variables; pass parameters explicitly
- Use meaningful variable names; avoid single-letter variables except in short loops
- Prefer `unless` only when it reads more naturally than `if (!$cond)`
- Avoid `unless/else` and `unless/elsif` constructs entirely
- Prefer `//` over `||` for default values
- Do not use `map` or `grep` in void context
- NEVER use `goto`

**Rationale:** CSF is long-lived infrastructure software. Maintainability over years requires readable, straightforward code.

## Security & Compliance Requirements

### Secure Coding Mandates

- All external input MUST be validated before use
- IP address validation MUST use the established `$ipv4reg` and `$ipv6reg` patterns from `ConfigServer::Config`
- File paths MUST be validated to prevent directory traversal attacks
- Command arguments MUST be sanitized to prevent injection attacks
- Log messages MUST NOT contain sensitive data (passwords, keys, tokens)

### Error Handling Standards

- Use exceptions (`die`, `croak`) judiciously; ensure callers expect them
- Prefer `Try::Tiny`, block `eval`, or `Cpanel::Try` for exception handling
- Report errors to logs or users appropriately, without exposing sensitive info
- Avoid bulk functions with incompatible error reporting (e.g., `chown`, `chmod`, `unlink` on arrays)

### Dependency Management

- Prefer cPanel-constructed modules over CPAN equivalents when available at `/usr/local/cpanel/Cpanel`
- Do NOT use `Cpanel::CPAN` modules
- When no cPanel module exists, prefer CPAN modules already used in the codebase
- For tests, CPAN modules may be preferred to minimize spurious failures

## Development Workflow

### Version Control

- All production code MUST be under Git version control
- Code merged upstream MUST be reviewed by a second developer (unless pair programming)
- Follow conventions of the module being modified; keep style consistent

### Commit Message Format

```
Brief summary (≤50 chars)

case CPANEL-XXXXX: Full description of the changeset.
Additional context and reasoning as needed.
Wrap lines at 72-80 characters.

Changelog: Customer-facing description in active voice (wrap with leading space if needed)
```

- Multiple commits per case are allowed; each MUST be atomic and functional
- Fix multiple bugs in separate paragraphs
- `Changelog:` may be blank if change is not customer-relevant

### Code Review Requirements

- All PRs MUST verify compliance with this constitution
- Changes that modify external API interfaces MUST be documented
- Complexity MUST be justified with clear rationale

### Testing Requirements

- Run `perl -cw -Ilib t/YourTest.t` before committing test files
- Run `make test` after any changes to verify no regressions
- All unit tests MUST pass before committing any work
- `make test` MUST return successful exit status before committing
- Unit tests MUST NOT emit warnings from code under test.
- Test naming: `t/ConfigServer-ModuleName.t` or `t/ConfigServer-ModuleName_description.t`

## Governance

### Constitutional Authority

This constitution supersedes all other practices. When conflicts arise between this document and other guidelines, this constitution takes precedence.

### Amendment Process

1. Proposed amendments MUST be documented with clear rationale
2. Amendments MUST be reviewed and approved before implementation
3. Version number MUST be incremented according to semantic versioning:
   - MAJOR: Backward-incompatible governance/principle changes
   - MINOR: New principles or materially expanded guidance
   - PATCH: Clarifications, wording, typo fixes
4. `LAST_AMENDED_DATE` MUST be updated to reflect amendment date

### Compliance Review

- All code reviews MUST verify adherence to Core Principles
- Violations MUST be documented and resolved before merge
- Complexity deviations MUST include justification in PR description

### Reference Documents

- Perl Standards: `.github/instructions/perl.instructions.md`
- Test Standards: `.github/instructions/tests-perl.instructions.md`
- Code Formatting: `.perltidyrc`

**Version**: 1.0.6 | **Ratified**: 2026-01-22 | **Last Amended**: 2026-01-23
