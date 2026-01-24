---
applyTo: "**/*.{pm,pl,t}"
description: "Perl development standards, module patterns, and Perl conventions"
---

## Perl Version

- CSF uses cpanel-perl. It is designed to run on cPanel versions 110+ which use Perl versions 5.36 or 5.42.
- The Perl binary is located at `/usr/local/cpanel/3rdparty/bin/perl`
  - This is actually a symlink to the real location of the perl binary.
- The latest Perl version we use is 5.42.0
- The Perl binary automatically adds the `/usr/local/cpanel` to the beginning of the @INC path.

## File Structure

### Perl Modules

- Perl modules end with the file extension `.pm`
- Each module should start with the `package My::Package` declaration where `My::Package` is the name corresponds to the file name under `lib/`
- The first package it should then include is `strict` using `use strict;`.
- The first package it should then include is `warnings` using `use warnings;`.
- All other packages (with a few exceptions) included after should not import any functions and prefer the syntax `use Package ();`

### cPstrict Module

The `use cPstrict;` pragma is a cPanel-specific module that provides a convenient way to enable modern Perl features. When you see `use cPstrict;` in code, it is equivalent to:

```perl
use strict;
use warnings;
use v5.30;
use feature 'signatures';
no warnings 'experimental::signatures';
```

**What `cPstrict` enables:**
- **`strict`**: Enforces strict variable declarations and references
- **`warnings`**: Enables all standard Perl warnings
- **`v5.30` features**: Enables Perl 5.30 feature bundle (includes `say`, `state`, `current_sub`, `fc`, etc.)
- **Function signatures**: Enables the `signatures` feature for subroutine parameter declarations
- **Disables signature warnings**: Suppresses the experimental warnings for signatures

**Usage:**
```perl
package My::Module;
use cPstrict;

sub greet ($name) {    # Function signatures are enabled
    say "Hello, $name!";
    return;
}
```

**Requirements:**
- Requires Perl 5.30 or higher (will `confess` if loaded from an older Perl)
- Available at `/usr/local/cpanel/cPstrict.pm`

**When to use:**
- `use cPstrict;` is preferred for new cPanel modules that want modern Perl features
- It is a drop-in replacement for `use strict; use warnings;` with additional modern features
- Existing code using `use strict; use warnings;` is still acceptable

## Perl Standards

- Prefer idiomatic Perl over least common denominator Perl.
- Always disable imports: use `use Module ();` instead of `use Module;`.
  - **Exception**: `Data::Dumper` may be imported without `()` as `use Data::Dumper;` since `Dumper` is commonly used for debugging.
- Always use fully qualified names when referencing functions or variables from another package.
- Use `unless` sparingly; prefer when it reads more naturally than `if (!$cond)`.
- When refactoring modules, remove `use Exporter` and related variables (`@EXPORT`, `@EXPORT_OK`) if the module is not exporting anything. You should also remove `@ISA` if it's only there for `Exporter`.
- **Never use Perl 4 style subroutine calls**: Use `function()` instead of `&function;` and `function($arg)` instead of `&function($arg)`. The ampersand (`&`) is only needed for special cases like passing `@_` implicitly or taking references to subroutines.

## Preferred Modules

- For new code, consider using cPanel-constructed modules over CPAN equivalents whenever available at /usr/local/cpanel/Cpanel
- Do not use `Cpanel::CPAN` modules.
- When no cPanel module exists, prefer CPAN modules already used in the codebase.
- For tests, CPAN modules may be preferred to minimize spurious failures.

## ConfigServer::Config Usage

- **Never call `loadconfig()` at module load time** (outside of subroutines).
- Calling `loadconfig()` at the package level happens when the module is loaded, which:
  - Complicates unit testing by requiring configuration files to exist
  - Makes unnecessary system calls during module compilation
  - Prevents mocking configuration in tests
  - Can cause circular dependency issues

### Patterns for Accessing Configuration

When refactoring code that has `loadconfig()` calls at module load time, use one of these patterns:

#### Pattern 1: Use `get_config()` for Individual Values

When accessing a single or few configuration values, use `ConfigServer::Config->get_config($key)`:

```perl
# BAD - calls loadconfig at module load time
my $config = ConfigServer::Config->loadconfig();
my %config = $config->config();

sub my_function {
    my $host = $config{HOST};
    # ...
}

# GOOD - calls loadconfig only when needed
sub my_function {
    my $host_bin = ConfigServer::Config->get_config('HOST');
    # ...
}
```

The `get_config()` method automatically loads configuration if not already loaded, and returns the specific value you need.

#### Pattern 2: Use `config()` for Multiple Values

When accessing many configuration values within a function, call `config()` and create a local hash copy:

```perl
# BAD - calls loadconfig at module load time
my $config = ConfigServer::Config->loadconfig();
my %config = $config->config();

sub my_function {
    if ($config{IPV6} && $config{IPV6_SPI}) {
        my $raw = $config{RAW6};
        # ... many more config accesses
    }
}

# GOOD - loads config within the function
sub my_function {
    my $config = ConfigServer::Config->loadconfig();
    my %config = $config->config();
    
    if ($config{IPV6} && $config{IPV6_SPI}) {
        my $raw = $config{RAW6};
        # ... many more config accesses
    }
}
```

This pattern is preferred when:
- You need to access many (5+) configuration values
- The function already has the config loading pattern
- Performance is critical (single hash lookup vs. multiple method calls)

#### Choosing the Right Pattern

- **Single/few values**: Use `get_config()`
- **Many values (5+)**: Use `config()` with local copy
- **Tests**: Both patterns support mocking via `local` for package variables

## Error Handling

- Execute external commands using `Cpanel::SafeRun::Object` whenever possible in production code. Backticks are tolerable in unit tests.
- Always check and handle errors from commands (`$!`, `$@`, `$?`, `$^E`).
- Avoid bulk functions with incompatible error reporting (e.g., `chown`, `chmod`, `unlink` on arrays).
- Report errors to logs or users as appropriate, without exposing sensitive info (e.g., stack traces in UIs).
- Use exceptions (`die`, `croak`) judiciously; ensure callers expect them.
- Prefer `Try::Tiny`, block `eval`, or `Cpanel::Try` for exception handling.

## General Principles

- All production code must be under version control.
- Code merged upstream must be reviewed by a second developer (unless pair programming).
- Follow conventions of the module being modified; keep style consistent.
- Avoid changes that modify external API interfaces unless necessary and properly documented.

## Version control Guidelines
- Our version control system is `git`.
- Commit messages follow a specific template which should be adhered to.
  - All lines must not exceed 80 characters. Unless otherwise specified, wrap to the next line if necessary.
  - The first line must be a very brief summary of the change. Do not wrap here, instead truncate if greater than 80 characters.
  - The second line must be blank.
  - The third line must begin with `case CPANEL-XXXXX: ` where the 'X' characters are to be replaced with a "case number" (if known from prompting or the branch name). After this it is acceptable to begin full description of the changeset.
  - Once done describing the changeset in the commit message, end your commit with a line beginning with `Changelog: `. This is to be formatted in the style of a proper git commit trailer, which means that when you must wrap lines, you prefix the new lines with a leading space. This entry is to describe the change in one sentence using active voice so that customers can have an idea of what this change entails without going into too much detail.

## Secure Coding Guidelines

- Prefer fail-closed designs: default to secure states and restrictive permissions.
- Use whitelists for allowed inputs; never munge or alter inputs.
- Always use the three-argument form of `open()`.
  - 2 arg opens are considered a significant bug and should be fixed.

## Execution Phases

- Avoid `INIT` or `BEGIN` phase in code except in tests and only if needed.

## Commit Message Standards

- Start with short summary (≤50 chars), leave second line blank, add `Case CPANEL-####:` on third line.
- Use imperative mood, wrap at 72-80 characters,
- Include `Changelog:` as the last line of the commit. Leave it blank if the change is not customer relevant.
- Multiple commits per case are allowed; each should be atomic and functional.
- Fix multiple bugs in separate paragraphs.

## Code convention

- Code should be tidy using the Perl Tidy Policy located in the base of the repo `.perltidyrc`
- Perl code must never have trailing whitespace, including in POD documentation.
- Each function should always use an explicit `return` statement at the end.
- Subroutines should use less than 4 arguments when posible.
- Subroutine names should be less than 30 lines when possible.
- Avoid global variables; pass parameters explicitly.
- Use meaningful variable names and avoid single-letter variables except in short loops

### File Handling
- Never use bareword directory and filehandles; use lexical filehandles instead.
- Exceptions for this are: `STDIN`, `STDOUT`, and `STDERR`.

### Syntax Preferences
- Prefer `my` over `local` unless dynamic scoping is required.
- Never use `goto`.
- Use `unless` sparingly; prefer `if (!$cond)` unless `unless` improves readability.
- Avoid `unless/else` and `unless/elsif` constructs.
- Use `map`, `grep`, and `foreach` idiomatically.
- Prefer `//` over `||` for default values.
- Do not use `map` or `grep` in void context.
- Never use wantarray in new code.

### glob()
- Use `glob()` sparingly and prefer `readdir()` when possible.
- If using `glob()`:
  - Use `File::Glob ()` in binaries.
  - Avoid complex shell patterns.
  - Never use `glob()` in scalar context.

### Experimental Features
- These experimental features should never be used.
  - Smart match (`~~`)
  - `given/when`
- The new class functionality added in perl 5.40 is not yet compatible with compiled perl but can be used in uncompiled perl code.

### Code Smells to Avoid
- Avoid "Insatiable Match Variables".
- Avoid function prototypes; use subroutine signatures instead.
- Complex conditionals, magic literals, vague identifiers, inconsistent names.
- Perl-specific: C-style for loops (prefer `foreach`), inappropriate use of globals.
  - `for(my $x = 1; $x < 5; $x++) {...}`
- Use named constants instead of raw literals; avoid expensive setup requirements.
- Avoid returning list from function
- Never use wantarray.

### Concise Conditionals and Guards
- Prefer postfix conditionals for simple guards: `return 0 unless condition;` instead of `if (!condition) { return 0 }`
- Use `return 0 unless length $var;` instead of `if (!defined $var || !length $var) { return 0 }`
- Combine conditions concisely: `return 0 if length $cidr and $cidr !~ /^\d+$/;`
- For `length`, `defined`, and truthiness checks:
  - `length $var` handles both undef and empty string (returns 0 for both)
  - Only check `defined` explicitly when you need to distinguish undef from empty string or 0
  - Prefer `!length $var` over `!defined $var || $var eq ""`
- Keep postfix conditionals on one line when the statement is short and readable

### Regular Expressions
- Use `\s` for any whitespace; use space character for literal spaces.
- Prefer `[A-Za-z0-9_]` over `\w`, and `[0-9]` over `\d`
- `\d` can be used when in combination with the `/a` modifier
- Complex RegExp should prefer the `/xms` modifier to improve readability and maintenance.
- Use `tr/A-Z/a-z/` instead of `tr/[A-Z]/[a-z]/`.

## POD Standards

- New modules must include inline POD documentation.
- Document all new public functions and modules using inline POD.
- Module-level POD documentation (NAME, SYNOPSIS, DESCRIPTION, etc.) should be placed after the `package` declaration but before any `use` statements.
- Subroutine POD documentation should be placed immediately before the subroutine declaration it documents.
- Use `=head2` for subroutine documentation (e.g., `=head2 new`, `=head2 urlget`).
- End each POD block with `=cut` before the subroutine declaration.
- No need to add documentation for private functions. by convention private functions start with an underscore `_`.
- At least 50% of the public interface must be documented.
- Document the public interface of modules with POD: constructors, attributes, functions, and methods.
- Ensure proper indentation and line breaks for readability.
- Required sections: NAME, SYNOPSIS, DESCRIPTION; additional sections as needed.
- The SYNOPSIS section should include example usage.
- The code example from the SYNOPSIS should be linted and indented for easier reading.
- The DESCRIPTION section should provide an overview of the module's purpose and functionality.
- Optional sections: METHODS, FUNCTIONS, ATTRIBUTES, EXAMPLES, SEE ALSO.
- Encouraged end-of-file sections (placed after the final `1;`): VERSION, AUTHOR, COPYRIGHT (or COPYRIGHT AND LICENSE).
- End-of-file POD sections should be placed at the end of the file, after all code and the final `1;` statement.
- When writing POD never add the following prohibited sections: BUGS, TODO.
- Remove empty sections.
- Use proper POD format for compatibility with `perldoc` and related tools.
- Audience: cPanel developers and customers; follow cPanel communication policies.
- Ensure POD is well-formed and passes `podcheck` without warnings or errors.
- Use `perldoc` to verify formatting and readability.
- Follow the structure outlined in `perlpod` and `perlpodstyle`.
- Use proper capitalization for section titles (e.g., "SYNOPSIS", "DESCRIPTION").
- Use `=head1`, `=head2`, etc., for section headers.
- Use `=over`, `=item`, and `=back` for lists.
- Use `L<Module::Name>` for cross-references to other modules.
- Use `C<code>`, `B<bold>`, and `I<italic>` for inline formatting.
- Avoid using `=begin` and `=end` blocks unless necessary.
- Avoid deprecated POD commands like `=for`, `=begin`, and `=end`.
- Avoid trailing whitespace in POD sections.
- Avoid excessive blank lines; use single blank lines to separate paragraphs.
- Avoid overly long lines; wrap text at 72 characters for readability.
- Avoid using non-standard POD commands or extensions.
- Avoid using HTML tags in POD.
- Avoid using POD for non-documentation purposes (e.g., code comments).
- Avoid using POD in scripts that are not intended for end-user documentation.
- Avoid using POD in test files unless the tests are intended to be run as standalone scripts.
- Avoid using POD in files that are not Perl code (e.g., configuration files, data files).
- Avoid using POD in files that are not intended to be distributed (e.g., temporary files, backup files).
- Avoid using POD in files that are not intended to be read by humans (e.g., machine-readable files, binary files).
- Avoid using POD in files that are not intended to be executed (e.g., scripts that are not meant to be run).
- Avoid using POD in files that are not intended to be installed (e.g., files in `t/`, `examples/`, `docs/`).
- Avoid using POD in files that are not intended to be shared (e.g., files in `private/`, `local/`).
- Avoid using POD in files that are not intended to be version controlled (e.g., files in `.gitignore`).
- Avoid using POD in files that are not intended to be maintained (e.g., files in `deprecated/`, `legacy/`).

## Adding Test Coverage

- When adding new code always prefer to add test coverage using the test conventions from `.github/instructions/tests-perl.instructions.md`.
