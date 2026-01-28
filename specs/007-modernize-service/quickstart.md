# Quickstart: Modernize ConfigServer::Service.pm

**Branch**: `007-modernize-service`  
**Date**: 2026-01-28

## Quick Reference

### Files to Modify

| File | Action | Description |
|------|--------|-------------|
| `lib/ConfigServer/Service.pm` | Modify | Modernize module |
| `t/ConfigServer-Service.t` | Create | Unit tests |

### Key Changes

1. Replace `use strict` with `use cPstrict`
2. Remove `use lib '/usr/local/csf/lib'`
3. Disable all imports: `use Module ()`
4. Remove Exporter machinery
5. Remove package-level config loading
6. Remove package-level /proc access
7. Create `_get_init_type()` helper
8. Rename `printcmd` to `_printcmd`
9. Remove ampersand syntax (`&function` → `function`)
10. Add POD documentation
11. Create unit tests

### Validation Commands

```bash
# Syntax check
perl -cw -Ilib lib/ConfigServer/Service.pm

# POD check
podchecker lib/ConfigServer/Service.pm

# Run unit tests
PERL5LIB='' prove -wlvm t/ConfigServer-Service.t

# Run all tests
make test
```

### Success Criteria

```bash
# No package-level loadconfig
grep -n 'loadconfig' lib/ConfigServer/Service.pm | grep -v 'sub\|#'
# Should return nothing outside functions

# No legacy markers
grep -E '# (start|end) ' lib/ConfigServer/Service.pm
# Should return nothing

# No Exporter
grep -E '@EXPORT|@ISA|use Exporter' lib/ConfigServer/Service.pm
# Should return nothing

# Uses cPstrict
grep 'use cPstrict' lib/ConfigServer/Service.pm
# Should find the pragma

# Private function renamed
grep 'sub _printcmd' lib/ConfigServer/Service.pm
# Should find the function
```

## Module Structure (After Modernization)

```perl
# Copyright header (preserved)
# ...

=head1 NAME

ConfigServer::Service - LFD service management for systemd and init systems

=head1 SYNOPSIS
...
=cut

package ConfigServer::Service;

use cPstrict;

use Carp ();
use IPC::Open3 ();

use ConfigServer::Config ();
use ConfigServer::Slurp ();

our $VERSION = 1.02;
our $INIT_TYPE_FILE = '/proc/1/comm';  # For test isolation

# Private helpers
sub _get_init_type { ... }
sub _reset_init_type { ... }  # For tests
sub _printcmd { ... }

# Public API
sub type { ... }
sub startlfd { ... }
sub stoplfd { ... }
sub restartlfd { ... }
sub statuslfd { ... }

1;
```

## Test Structure

```perl
#!/usr/local/cpanel/3rdparty/bin/perl

use cPstrict;

use Test2::V0;
use Test2::Tools::Explain;
use Test2::Plugin::NoWarnings;

use lib 't/lib';
use MockConfig;

use File::Temp ();

# Now load the module under test
use ConfigServer::Service ();

# Set required config values
set_config(
    SYSTEMCTL => '/usr/bin/systemctl',
);

subtest 'Public API exists' => sub { ... };
subtest '_get_init_type returns systemd' => sub { ... };
subtest '_get_init_type returns init for other values' => sub { ... };
# ... more tests ...

done_testing();
```
