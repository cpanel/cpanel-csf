---
applyTo: "t/*.t"
description: "Perl unit testing conventions using Test2 framework"
---

**CRITICAL: Always read the full document when adding or updating unit tests.**

## Perl Unit Tests naming convention

- Perl unit tests are located to `t/*.t`.
- Test files are named using package prefix where `-` is used instead of `::` and `_` is used at the end to add a custom name.

For example `ConfigServer::AbuseIP` package, which exists on disk at `lib/ConfigServer/AbuseIP.pm` will have all their tests in multiple files like
`t/ConfigServer-AbuseIP.t` or `t/ConfigServer-AbuseIP_*.t`.

## Test Framework

When writing tests prefer using Test2 framework.
Read the [Test2 Framework Guide](#test2-framework-guide) section for more details.

## Running tests

Every test file created or updated should pass `perl -cw -Ilib` syntax check.
Every test file should pass when running `prove` command to run it locally.

Before running a single test file, ensure the file has no syntax error using `perl -cw -Ilib`.
When running tests locally, prefer using `prove` command with `-wlvm`.
```bash
prove -wlvm t/ConfigServer-AbuseIP.t
```

Also make sure that `PERL5LIB=''` environment variable is set to avoid loading any local modules when running yath:
```bash
PERL5LIB='' prove -wlvm t/ConfigServer-AbuseIP.t
```

**Note:** The `-l` flag in `prove -wlvm` automatically adds the `lib/` directory to `@INC`, so there is no need to include `use lib` statements in test files. Test files should not contain `use lib` directives.

### Regression Testing

After completing work on a test and verifying it passes, **always run `make test`** to ensure all existing tests still pass. This catches any regressions introduced by changes to shared modules or dependencies.

```bash
make test
```

This is critical because changes to one module (like ConfigServer::Slurp) can affect multiple test files that depend on it.

## Packages Requirements

### NoWarnings

- Tests should always inclide `Test2::Plugin::NoWarnings`.

### done_testing

You should prefer to use `done_testing();` at the end of your run not providing a test count at the start of the test file.

### subroutines

Place any subroutines in your code after `done_testing;` to make the test code more legible.

### Loading Modules

- **NEVER use `require_ok()` or `use_ok()`** - these functions are from Test::More and should not be used
- Instead, use regular `use Module::Name;` statements directly
- If the module fails to load, the test will fail automatically with a clear error message
- This approach is cleaner and more idiomatic in Test2

Example:
```perl
# CORRECT - just use the module
use ConfigServer::CloudFlare;

# WRONG - do not use require_ok or use_ok
require_ok('ConfigServer::CloudFlare');  # NEVER DO THIS
use_ok('ConfigServer::CloudFlare');      # NEVER DO THIS
```

### Mocking Cpanel::Config

When testing modules that use `Cpanel::Config::loadcpconf()`, use the memory-only configuration guard:

```perl
use YourModule;  # Load the module first (which loads Cpanel::Config as a dependency)

# Set memory_only AFTER Cpanel::Config is loaded
$Cpanel::Config::CpConfGuard::memory_only = {
    alwaysredirecttossl => 1,
    skipboxtrapper      => 1,
    maxemailsperhour    => 500,
    nativessl           => 1,
    ftpserver           => 'pure-ftpd',
};

# Now tests can run with the mocked configuration
```

**Important:** Set `$Cpanel::Config::CpConfGuard::memory_only` AFTER loading modules that depend on Cpanel::Config, as the variable must be set after the Cpanel::Config module is loaded into memory.

### Mocking ConfigServer::Config

When testing modules that depend on `ConfigServer::Config`, **ALWAYS use MockConfig** to isolate tests from distribution configuration files and behavior.

#### Using MockConfig

MockConfig is a reusable test utility located at `t/lib/MockConfig.pm` that provides:
- Prevention of actual `ConfigServer::Config` module loading via `$INC` manipulation
- Clean configuration state management between tests
- Simple API for setting test-specific configuration values

**Example usage:**

```perl
use lib 't/lib';
use MockConfig;

# Set configuration values for your test
set_config(
    LF_LOOKUPS  => 1,
    CC_LOOKUPS  => 2,
    HOST        => '/usr/bin/host',
);

# Run your test code
my $result = some_function_that_uses_config();

# Clear configuration between subtests
clear_config();
```

#### Benefits of MockConfig

- **Test Isolation**: Tests don't depend on system configuration files or distribution-specific behavior
- **Reproducibility**: Tests produce consistent results across different environments
- **Speed**: No file I/O for configuration loading
- **Clarity**: Configuration values are explicit in the test code

#### MockConfig API

```perl
# Set one or more configuration values
set_config(
    KEY1 => 'value1',
    KEY2 => 'value2',
);

# Clear all configuration (use between subtests)
clear_config();

# Get the mock configuration hash (for advanced usage)
my $config = get_mock_config();
```

#### When to Use MockConfig

Use MockConfig when testing any module that calls:
- `ConfigServer::Config->loadconfig()`
- `ConfigServer::Config->get_config($key)`
- `ConfigServer::Config->config()`
- Any other `ConfigServer::Config` methods

**Example test structure:**

```perl
use Test2::V0;
use Test2::Plugin::NoWarnings;

use lib 't/lib';
use MockConfig;

use YourModule qw(your_function);

subtest 'test with specific config' => sub {
    set_config(
        OPTION1 => 1,
        OPTION2 => 'test',
    );

    my $result = your_function();
    is($result, 'expected', 'function behaves as expected');

    clear_config();
};

done_testing;
```

## Example header code.
This is what the header for most tests should look like, depending on the year you modified the file.

```
#!/usr/local/cpanel/3rdparty/bin/perl

#                                      Copyright 2025 WebPros International, LLC
#                                                           All rights reserved.
# copyright@cpanel.net                                         http://cpanel.net
# This code is subject to the cPanel license. Unauthorized copying is prohibited.

use strict;
use warnings;

use Test2::V0;
use Test2::Tools::Explain;
use Test2::Plugin::NoWarnings;
```
- Insert the current year in copyright as a static value (e.g., 2025) based on the system date at the time
of generation.

## Test2 Framework Guide

Test2 is the modern testing framework that replaces Test::More. It provides better diagnostics, cleaner APIs, and more powerful features.

### Test2 Bundles

#### Test2::V0 (Required)
The recommended bundle that loads most commonly needed tools and plugins:

```perl
use Test2::V0;
```

This bundle includes:
- `strict` and `warnings` pragmas
- `utf8` pragma
- Test2::Plugin::UTF8
- Test2::API (intercept() & context())
- Test2::Tools::Basic (ok, pass, fail, diag, note, etc.)
- Test2::Tools::Compare (is, like, etc.)
- Test2::Tools::ClassicCompare (cmp_ok)
- Test2::Tools::Subtest (buffered subtests)
- Test2::Tools::Class (isa_ok, can_ok, DOES_ok)
- Test2::Tools::Ref (ref_ok, ref_is, ref_is_not)
- Test2::Tools::Exports (imported_ok, not_imported_ok)
- Test2::Tools::Mock (mock & mocked)
- Test2::Tools::Exception (dies, lives)

### Test Planning

#### Using done_testing() (Preferred)
```perl
use Test2::V0;

# Your tests here
ok(1, "This passes");
is(2 + 2, 4, "Math works");

done_testing;
```

### Basic Assertions

#### Simple Assertions
```perl
# Basic boolean test
ok($result, "Test description");

# Diagnostics
diag("Diagnostic message visible to user");
note("Note message for verbose output");
```

Do not use `pass` or `fail` calls if you can help it.

#### Comparisons
```perl
# Exact comparison. undef tolerant. Prefer this over ok()
is($got, $expected, "Values are identical");

# Pattern/partial matching
like($got, $pattern_or_structure, "Got matches pattern");

# Negation
isnt($got, $unexpected, "Values are different");
unlike($got, $pattern, "Does not match pattern");
```

#### Comparison Functions

```perl
use Test2::V0;

# is() - Strict comparison (like Test::More's is_deeply but better)
is($got, $expected, "Strict match");

# like() - Relaxed comparison (NEW in Test2, no Test::More equivalent)
like($got, $pattern, "Relaxed/partial match");

# isnt/unlike() - Negated versions
isnt($got, $unexpected, "Should not match");
unlike($got, $bad_pattern, "Should not match pattern");
```

#### Simple State Checks
```perl
use Test2::V0;

# Boolean checks that can be nested
is($data, T(), "Value is truthy");
is($data, F(), "Value is falsy (but may be defined)");
is($data, D(), "Value is defined");
is($data, U(), "Value is undefined");
is($data, DF(), "Value is defined but false");

# Existence checks
is($data, E(), "Value exists (even if undef)");
is($data, DNE(), "Value does not exist");
is($data, FDNE(), "Value is false or does not exist");

# Length check
is($data, L(), "Value has length (not undef or empty string)");
```

#### Array Comparisons
```perl
use Test2::V0;

# Exact array match
is(
    $got_array,
    [1, 2, 3, "string"],
    "Array matches exactly"
);

# Partial array match with nested checks
like(
    $got_array,
    [
        1,
        T(),  # Second element is truthy
        hash { # Third element is a hash
            field name => "John";
            field age  => number(25, 35); # Between 25-35
            etc(); # Other fields may exist
        },
    ],
    "Array structure matches"
);

# Array with order checking
is($array, array {
    item 0 => "first";
    item 1 => "second";
    end(); # No more items allowed
}, "Ordered array check");

# BAG Testing - Order-Independent Arrays
# CRITICAL: Test2's bag() is fundamentally different from Test::More's is_deeply
# bag() ignores element order completely, while Test::More required exact order

# Test::More (old way) - ORDER MATTERS
# is_deeply([1, 2, 3], [3, 2, 1], "Arrays match"); # FAILS in Test::More

# Test2 bag() - ORDER DOES NOT MATTER
is(
    [1, 2, 3],
    bag {
        item 1;
        item 2;
        item 3;
        end(); # Ensure no extra items
    },
    "Bag matches regardless of order"
);

# Both [1, 2, 3] and [3, 2, 1] will pass this test
is([3, 2, 1], bag { item 1; item 2; item 3; end(); }, "Order ignored");

# Bag with duplicates - counts matter
is(
    [1, 2, 2, 3],
    bag {
        item 1;
        item 2;  # First occurrence
        item 2;  # Second occurrence
        item 3;
        end();
    },
    "Bag handles duplicates correctly"
);

# Bag with complex structures
is(
    [
        { name => "Alice", age => 30 },
        { name => "Bob",   age => 25 },
        { name => "Carol", age => 35 }
    ],
    bag {
        item hash { field name => "Bob";   field age => 25; end(); };
        item hash { field name => "Alice"; field age => 30; end(); };
        item hash { field name => "Carol"; field age => 35; end(); };
        end();
    },
    "Bag with hash structures - any order"
);

# Bag allows extra items (without end())
is(
    [1, 2, 3, 4, 5],
    bag {
        item 2;
        item 4;
        # Don't use end() - allows extra items 1, 3, 5
    },
    "Bag allows extra items when end() not used"
);

# Key Differences: Test::More vs Test2 bag()
# 1. Test::More is_deeply([1,2], [2,1]) FAILS - order matters
# 2. Test2 bag: is([1,2], bag{item 1; item 2; end()}) PASSES - order ignored
# 3. Test::More cannot ignore order without manual sorting
# 4. Test2 bag handles nested structures with order independence
# 5. Test2 bag provides better error messages showing which items are missing/extra
```

#### Hash Comparisons
```perl
use Test2::V0;

# Exact hash match
is(
    $got_hash,
    {
        name => "John",
        age  => 30,
        city => "Boston"
    },
    "Hash matches exactly"
);

# Partial hash match
like(
    $got_hash,
    hash {
        field name => "John";
        field age  => number(20, 40);
        # Other fields may exist
    },
    "Hash contains expected fields"
);

# Strict hash checking (no extra fields)
is($hash, hash {
    field name => "John";
    field age  => 30;
    end(); # No other fields allowed
}, "Exact hash with no extra fields");
```

#### Object Testing
```perl
use Test2::V0;

# Object property testing
is($object, object {
    call name => "John";
    call age  => 30;
    prop blessed => "Person";
    prop reftype => "HASH";
}, "Object has expected properties");

# Meta checks
is($value, meta {
    prop blessed => "MyClass";
    prop reftype => "HASH";
    prop size    => 3;
    prop this    => $value; # Self-reference
}, "Meta-checks pass");
```

#### Advanced Builders and Patterns

**Ordered Subset Testing:**
```perl
use Test2::V0;

# Test that items appear in order, but allow extras in between
is(
    [1, 'extra', 2, 'more', 3, 'stuff'],
    subset {
        item 1;
        item 2;
        item 3;
        # Skips over 'extra', 'more', 'stuff' automatically
    },
    "Finds items in order within larger array"
);

# Test::More had NO equivalent for this - required manual filtering
```

**Value Specifications:**
```perl
use Test2::V0;

# Number comparisons with tolerance
is($pi_approx, float(3.14159, tolerance => 0.001), "Pi approximation");
is($rounded, rounded(3.14159, 2), "Rounded to 2 decimal places");
is($range, within(50, 10), "Value within range 40-60");

# String and regex patterns
is($string, match(qr/^\d+$/), "String matches pattern");
is($string, !match(qr/[a-z]/), "String does not contain lowercase");

# Boolean logic
is($value, bool(1), "Has same boolean value as 1");
is($value, !bool(0), "Has different boolean value from 0");

# Custom validators
is($value, validator(
    name => 'positive_even',
    check => sub { $_[0] > 0 && $_[0] % 2 == 0 }
), "Value is positive and even");
```

**Set Operations:**
```perl
use Test2::V0;

# Value must match ALL checks
is($value, check_set(
    T(),                    # Must be truthy
    number(1, 100),        # Must be 1-100
    validator(sub { $_[0] % 2 == 0 }) # Must be even
), "Value passes all checks");

# Value must match ONE OR MORE checks
is($value, in_set(
    string("admin"),
    string("user"),
    string("guest")
), "Value is valid role");

# Value must match NONE of the checks
is($value, not_in_set(
    U(),           # Not undefined
    string(""),    # Not empty string
    number(0)      # Not zero
), "Value is not empty/zero/undef");
```

#### Meta Testing and Object Inspection

```perl
use Test2::V0;

# Meta checks for references and objects
is($object, meta {
    prop blessed => "MyClass";      # Blessed as specific class
    prop reftype => "HASH";         # Underlying reference type
    prop isa     => "BaseClass";    # Instance of class/role
    prop size    => 5;              # Number of hash keys or array elements
    prop this    => $object;        # The object itself
}, "Object meta-properties");

# Object method testing
is($user_obj, object {
    call name => "John Doe";                    # Call ->name() method
    call age  => validator(sub { $_[0] >= 18 }); # Call ->age(), validate result
    call ['get_roles'] => bag {                 # Call ->get_roles(), test as bag
        item "admin";
        item "user";
        end();
    };

    # For blessed hashes, can check underlying hash fields
    field '_private' => DNE();                  # Private field should not exist
    field 'created'  => D();                    # Created field should be defined

    # Meta properties
    prop blessed => "User";
    prop reftype => "HASH";

    end(); # No extra methods/fields
}, "User object validation");
```

#### Error Handling and Exception Patterns

```perl
use Test2::V0;

# Exception testing with detailed validation
my $exception = dies {
    MyClass->new(invalid => "parameter");
};

like($exception, qr/Invalid parameter/, "Got expected error message");

# More complex exception testing
is(
    dies { risky_operation() },
    object {
        call message => match(qr/operation failed/i);
        call code    => 500;
        prop isa     => "MyApp::Exception";
    },
    "Exception object has expected structure"
);

# Test that code lives (doesn't die)
lives { safe_operation() };

# Test warning patterns
my $warnings = warnings {
    deprecated_function();
};

is(
    $warnings,
    array {
        item match(qr/deprecated/i);
        end(); # Exactly one warning
    },
    "Got deprecation warning"
);
```

#### Practical Migration Examples: Test::More → Test2

**Old Test::More patterns and their Test2 equivalents:**

```perl
# OLD: Test::More way - limited and fragile
use Test::More;

# Array testing - ORDER MATTERED, no flexibility
is_deeply(\@got, [1, 2, 3], "Array exact match only");

# Hash testing - ALL fields required
is_deeply(\%got, { a => 1, b => 2, c => 3 }, "Hash exact match only");

# No way to test partial structures or ignore order
# Required manual array sorting: is_deeply([sort @got], [sort @expected])

# NEW: Test2 way - flexible and powerful
use Test2::V0;

# Array testing - multiple approaches available
is(\@got, [1, 2, 3], "Strict array match");                    # Exact order
is(\@got, bag { item 1; item 2; item 3; end(); }, "Bag match"); # Any order
like(\@got, [1, T(), D()], "Partial match - flexible");        # Partial structure

# Hash testing - exact or partial as needed
is(\%got, { a => 1, b => 2, c => 3 }, "Strict hash match");    # All fields required
like(\%got, { a => 1, b => T() }, "Partial hash match");       # Only specified fields
is(\%got, hash {                                               # Declarative builder
    field a => 1;
    field b => number(1, 10);  # Range validation
    etc();                     # Allow other fields
}, "Advanced hash validation");
```

#### Performance and Debugging Benefits

**Better Error Messages:**
```perl
# Test::More error (unhelpful):
# not ok 1 - deep structure
#   Failed test 'deep structure'
#   Structures begin differing at:
#        $got->[2]{users}[1] = '25'
#   $expected->[2]{users}[1] = 30

# Test2 error (detailed and actionable):
# not ok 1 - user data structure
# Failed test 'user data structure'
# +-------+--------------------------------+-------+---------+
# | PATH  | GOT                            | OP    | CHECK   |
# +-------+--------------------------------+-------+---------+
# | [2]   | HASH(0x7f8b1a0c4e60)          | eq    | <HASH>  |
# | {users} | ARRAY(0x7f8b1a0c4e78)        | eq    | <ARRAY> |
# | [1]   | 25                             | eq    | 30      |
# +-------+--------------------------------+-------+---------+
```

#### Custom Validators and Complex Logic
```perl
use Test2::V0;

# Custom check function
my $even_number = validator(
    name => 'even_number',
    check => sub {
        my ($got, %params) = @_;
        return $got % 2 == 0;
    }
);

is(4, $even_number, "4 is even");

# Inline validator with context information
is($value, validator(
    name => 'positive_and_small',
    check => sub {
        my ($got, %params) = @_;

        # Access validation context
        my $exists = $params{exists};     # Does the value exist?
        my $name   = $params{name};       # Validator name
        my $op     = $params{operator};   # Comparison operator

        # Multiple validation conditions
        return 0 unless defined $got;
        return 0 unless $got > 0;
        return 0 unless $got < 100;
        return 1;
    }
), "Value is positive and less than 100");

# Composite validators combining multiple checks
my $valid_email = validator(
    name => 'valid_email',
    check => sub {
        my $email = shift;
        return 0 unless defined $email;
        return 0 unless $email =~ /^[^@]+@[^@]+\.[^@]+$/;
        return 0 if length($email) > 255;
        return 1;
    }
);

is($user_email, $valid_email, "User has valid email address");

# Reference validation
is($data, exact_ref($expected_ref), "Exact same reference");
```

#### Set Operations
```perl
use Test2::V0;

# Match ANY of the specified checks
is($value, any(1, 2, 3), "Value is 1, 2, or 3");

# Match NONE of the specified checks
is($value, none(undef, "", 0), "Value is not undef, empty, or zero");

# Match ALL of the specified checks
is($value, all(
    T(),                    # Is truthy
    number(1, 100),        # Between 1-100
    validator(sub { $_[0] % 2 == 0 }) # Is even
), "Value meets all criteria");
```

### Exception Testing

```perl
use Test2::V0;

# Test that code dies
my $exception = dies { dangerous_code() };
is($exception, qr/expected error/, "Got expected exception");

# Test that code lives
lives { safe_code() };

# More complex exception testing
my $error = dies {
    My::Module->new(invalid => "params");
};
like($error, qr/Invalid parameter/, "Constructor validates parameters");
```

### Warning Testing

```perl
use Test2::V0;

# Count warnings (and silence them)
my $warning_count = warns { code_that_warns() };
is($warning_count, 1, "Got exactly one warning");

# Capture single warning
my $warning = warning { code_with_one_warning() };
like($warning, qr/deprecated/, "Got deprecation warning");

# Capture all warnings
my $warnings = warnings { code_with_multiple_warnings() };
is(scalar @$warnings, 2, "Got two warnings");

# Verify no warnings
no_warnings { clean_code() };
```

### Subtest Organization

Don't add `return` to the end of subtests. it creats a lot of noise.

```perl
use Test2::V0;

# Buffered subtest (recommended)
subtest "User authentication" => sub {
    my $user = User->new(name => "test");

    ok($user->login("password"), "Login succeeds");
    ok($user->is_authenticated, "User is authenticated");

    $user->logout;
    ok(!$user->is_authenticated, "User logged out");
};

# Multiple related tests
subtest "Database operations" => sub {
    my $db = setup_test_db();

    subtest "Insert operations" => sub {
        ok($db->insert(name => "test"), "Insert succeeds");
        is($db->count, 1, "Count updated");
    };

    subtest "Query operations" => sub {
        my $result = $db->find(name => "test");
        is($result->{name}, "test", "Found inserted record");
    };
};
```

### Mocking with Test2

#### Class Mocking
```perl
use Test2::V0;

# Mock an entire class
my $mock = mock 'HTTP::Client' => (
    override => [
        get => sub { return fake_response() },
        post => sub { return fake_response() },
    ]
);

# Use the mocked class
my $client = HTTP::Client->new;
my $response = $client->get("http://example.com");
is($response->status, 200, "Mocked response");

# Mock is automatically cleaned up when $mock goes out of scope
```

#### Object Mocking
```perl
use Test2::V0;

# Create a mock object
my $mock_obj = mock_obj {
    name => "Test User",
    age  => 25,
    get_name => sub { return shift->{name} },
};

is($mock_obj->name, "Test User", "Mock object property");
is($mock_obj->get_name, "Test User", "Mock object method");

# Mock objects auto-vivify methods as getters/setters
$mock_obj->email("test@example.com");
is($mock_obj->email, "test@example.com", "Auto-vivified method");
```

#### Method Override and Restore
```perl
use Test2::V0;

my $mock = mock 'MyClass' => (
    add => [
        new_method => sub { return "added" },
    ],
    override => [
        existing_method => sub { return "overridden" },
    ]
);

# Later in test
$mock->restore('existing_method');  # Restore original
$mock->reset('new_method');         # Remove added method
```

### Test2 Plugins

#### NoWarnings Plugin
```perl
use Test2::V0;
use Test2::Plugin::NoWarnings;

# Any warnings will cause test failure
# Already included when using Test::Cpanel::Policy
```

#### SRand Plugin
```perl
use Test2::V0;
use Test2::Plugin::SRand;

# Makes random tests reproducible
# Uses date-based seed (YYYYMMDD)
# Override with T2_RAND_SEED environment variable
my $random_value = rand(100);  # Reproducible across runs on same day
```

### TODO Tests

```perl
use Test2::V0;

# TODO block
todo "Not implemented yet" => sub {
    ok(unimplemented_feature(), "Feature works");
};

# TODO variable (preserves stack depth)
my $todo = todo "Known issue with edge case";
ok(buggy_function(), "Function handles edge case");
$todo = undef; # Clear TODO
```

### Class Testing Tools

```perl
use Test2::V0;

# Test inheritance and capabilities
isa_ok($object, "BaseClass", "Object inherits from BaseClass");
isa_ok("MyClass", "BaseClass", "Class inherits from BaseClass");

can_ok($object, "method_name", "Object can call method");
can_ok("MyClass", "class_method", "Class has class method");

DOES_ok($object, "Role::Interface", "Object does role");

# Multiple checks at once
isa_ok($object, ["BaseClass", "OtherBase"], "Multiple inheritance");
can_ok($object, ["method1", "method2"], "Has multiple methods");
```

### Reference Testing

```perl
use Test2::V0;

# Check reference types
ref_ok($value, "Check if value is a reference");
ref_ok($value, "HASH", "Value is hash reference");
ref_ok($value, "ARRAY", "Value is array reference");

# Check reference identity
my $ref1 = [];
my $ref2 = $ref1;
my $ref3 = [];

ref_is($ref1, $ref2, "Same reference");
ref_is_not($ref1, $ref3, "Different references");
```

### Export Testing

```perl
use Test2::V0;

# Test that functions are exported
imported_ok("function_name", "Function was imported");

# Test multiple exports
imported_ok(["func1", "func2"], "Multiple functions imported");
```

**Important:** Do not write tests to validate that private subroutines (prefixed with `_`) exist. If they are needed and missing, the code will fail during normal test execution. Testing for their existence adds no value and creates maintenance overhead.

### Best Practices

#### Test Organization
```perl
use Test2::V0;

# Group related tests in subtests
subtest "Input validation" => sub {
    # Test various input scenarios
};

subtest "Normal operation" => sub {
    # Test expected behavior
};

subtest "Error handling" => sub {
    # Test error conditions
};

done_testing;
```

#### Diagnostic Information
```perl
use Test2::V0;

# Use diag() for user-visible messages
diag("Setting up test environment");

# Use note() for verbose-only messages
note("Internal test state: $state");

# Better failure diagnostics with explain()
use Test2::Tools::Explain;
is($complex_structure, $expected, "Complex comparison")
    or diag("Got: " . explain($complex_structure));
```

#### Test Dependencies
When using Test2 tools in distributions, always explicitly declare dependencies:

```perl
# In cpanfile or Makefile.PL, declare each tool separately:
test_requires 'Test2::V0';
test_requires 'Test2::Tools::Exception';
test_requires 'Test2::Plugin::NoWarnings';
# Don't just depend on Test2::Suite
```
