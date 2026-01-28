# Quickstart: Modernize ConfigServer::Sendmail.pm

**Branch**: `006-modernize-sendmail` | **Date**: 2026-01-28

## Overview

Quick reference for implementing the Sendmail.pm modernization. Covers key patterns, expected changes, and validation commands.

---

## File Locations

| Purpose | Path |
|---------|------|
| Source module | `lib/ConfigServer/Sendmail.pm` |
| Test file (new) | `t/ConfigServer-Sendmail.t` |
| Mock utilities | `t/lib/MockConfig.pm` |
| Spec | `specs/006-modernize-sendmail/spec.md` |
| Plan | `specs/006-modernize-sendmail/plan.md` |

---

## Key Modernization Patterns

### 1. Disabled Imports

**Before:**
```perl
use Carp;
use POSIX qw(strftime);
use Fcntl qw(:DEFAULT :flock);
use Exporter qw(import);
```

**After:**
```perl
use Carp ();
use POSIX ();
use ConfigServer::Slurp ();
# No Exporter (Fcntl removed - using Slurp instead)
```

### 2. Package-Level Side Effects Removal

**Before (remove all):**
```perl
my $config = ConfigServer::Config->loadconfig();
my %config = $config->config();
my $tz     = strftime( "%z", localtime );
my $hostname;
if ( -e "/proc/sys/kernel/hostname" ) { ... }
eval { require Net::SMTP; import Net::SMTP; };
```

**After (add helper functions):**
```perl
sub _get_hostname {
    state $hostname;
    return $hostname if defined $hostname;
    # Read from /proc or default to 'unknown'
    ...
    return $hostname;
}

sub _get_timezone {
    state $tz;
    return $tz if defined $tz;
    $tz = POSIX::strftime( "%z", localtime );
    return $tz;
}
```

### 3. Config Access

**Before:**
```perl
$config{LF_ALERT_SMTP}
$config{SENDMAIL}
```

**After:**
```perl
ConfigServer::Config->get_config('LF_ALERT_SMTP')
ConfigServer::Config->get_config('SENDMAIL')
```

### 4. Function Renames

| Old Name | New Name | Reason |
|----------|----------|--------|
| `wraptext()` | `_wraptext()` | Internal helper, underscore prefix |

### 5. Fully Qualified Calls

**Before:**
```perl
carp("error");
strftime("%z", localtime);
open(...); flock(..., LOCK_SH); ...
```

**After:**
```perl
Carp::carp("error");
POSIX::strftime("%z", localtime);
my @lines = ConfigServer::Slurp::slurp($file);
```

---

## Test Structure

```perl
#!/usr/bin/env perl
use cPstrict;
use Test2::V0 -target => 'ConfigServer::Sendmail';
use Test2::Plugin::NoWarnings;
use Test2::Tools::Mock qw(mock);

use lib 't/lib';
use MockConfig qw(mock_config);

# Test: Module loads without side effects
subtest 'Module loads cleanly' => sub {
    ok( $CLASS, 'Module loaded' );
    can_ok( $CLASS, 'relay' );
};

# Test: Internal helpers exist
subtest 'Private helpers' => sub {
    can_ok( $CLASS, '_wraptext' );
    can_ok( $CLASS, '_get_hostname' );
    can_ok( $CLASS, '_get_timezone' );
};

# Test: wraptext functionality
subtest '_wraptext' => sub {
    is( ConfigServer::Sendmail::_wraptext('short', 80), 'short', 'Short text unchanged' );
    # ... more tests
};

# Test: SMTP path (mocked)
subtest 'relay via SMTP' => sub {
    mock_config( LF_ALERT_SMTP => 'smtp.example.com' );
    
    my @smtp_calls;
    my $mock = mock 'Net::SMTP' => (
        override => [
            new => sub { ... },
            mail => sub { ... },
            # ...
        ],
    );
    
    ConfigServer::Sendmail::relay($to, $from, @message);
    # Verify SMTP calls
};

done_testing();
```

---

## Validation Commands

```bash
# Compile check
perl -cw -Ilib lib/ConfigServer/Sendmail.pm

# POD validation
podchecker lib/ConfigServer/Sendmail.pm

# Run new tests only
PERL5LIB='' prove -wlvm t/ConfigServer-Sendmail.t

# Run full test suite
make test
```

---

## Expected Assertions

| Test Category | Expected Count |
|---------------|----------------|
| Module loading | 5-10 |
| API existence | 5-10 |
| _wraptext unit tests | 20-30 |
| _get_hostname tests | 10-15 |
| _get_timezone tests | 5-10 |
| relay SMTP path | 15-25 |
| relay sendmail path | 15-25 |
| Edge cases | 10-20 |
| **Total** | **85-145** |

---

## Dependencies

### Required for Tests
- `Test2::V0`
- `Test2::Plugin::NoWarnings`
- `Test2::Tools::Mock`
- `MockConfig` (local)

### Module Dependencies
- `ConfigServer::Config` - Configuration access
- `ConfigServer::Slurp` - Simple file reading
- `Carp` - Error reporting
- `POSIX` - Date/time formatting
- `Net::SMTP` - SMTP mail delivery (optional, loaded at runtime)

---

## Phase Checklist

- [ ] P0: Remove legacy comment markers
- [ ] P1: Modernize imports and remove side effects
- [ ] P2: Rename wraptext → _wraptext
- [ ] P3: Add POD documentation
- [ ] P4: Create comprehensive test file

---

## Common Pitfalls

1. **Net::SMTP loading**: Must use `require` inside relay(), not at package level
2. **State variables**: Require Perl 5.10+ (we use 5.36, so fine)
3. **Slurp usage**: Use `ConfigServer::Slurp::slurp()` for simple file reading
4. **Config caching**: Don't cache config values; call get_config() each time
5. **Email sanitization**: Preserve exact regex for security
