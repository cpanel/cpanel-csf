# Quickstart: Modernize cseUI.pm

**Feature**: 002-modernize-cseui  
**Date**: 2026-01-23

## Prerequisites

- Perl 5.36+ (cPanel-provided)
- Access to `lib/ConfigServer/cseUI.pm`
- Test2::V0 testing framework

## Implementation Order

Follow user stories in priority order (P0 → P5):

### P0: Remove Inter-Subroutine Comments

```bash
# Remove all # start/# end comment markers
grep -n '^\s*#.*\(start\|end\)' lib/ConfigServer/cseUI.pm
# Manually remove identified lines
```

### P1: Remove Global Variables at Module Load Time

1. Remove unused `our` variables from declaration blocks (lines 36-45)
2. Keep only: `%config`, `%FORM`, `$script`, `$script_da`, `$images`, `$myv`, and the used variables from block 2
3. Ensure `loadconfig()` is only called inside `main()` (already true, just needs syntax fix)

### P2: Code Modernization

1. Replace `use strict;` with `use cPstrict;`
2. Remove `## no critic` line
3. Update imports:
   ```perl
   # Before
   use Fcntl qw(:DEFAULT :flock);
   use File::Find;
   use File::Copy;
   use IPC::Open3;
   use Exporter qw(import);
   
   # After
   use Fcntl ();
   use File::Find ();
   use File::Copy ();
   use IPC::Open3 ();
   # Remove Exporter entirely
   ```
4. Remove `@ISA` and `@EXPORT_OK` declarations
5. Update all Fcntl constant usages to fully qualified names:
   - `LOCK_SH` → `Fcntl::LOCK_SH`
   - `LOCK_EX` → `Fcntl::LOCK_EX`
   - `O_RDONLY` → `Fcntl::O_RDONLY`
   - etc.
6. Update function calls:
   - `find(...)` → `File::Find::find(...)`
   - `copy(...)` → `File::Copy::copy(...)`
   - `open3(...)` → `IPC::Open3::open3(...)`

### P3: Make Subroutines Private

Rename all non-main subroutines with underscore prefix:

| Old Name | New Name |
|----------|----------|
| `browse` | `_browse` |
| `setp` | `_setp` |
| `seto` | `_seto` |
| `ren` | `_ren` |
| `moveit` | `_moveit` |
| `copyit` | `_copyit` |
| `mycopy` | `_mycopy` |
| `cnewd` | `_cnewd` |
| `cnewf` | `_cnewf` |
| `del` | `_del` |
| `view` | `_view` |
| `console` | `_console` |
| `cd` | `_cd` |
| `edit` | `_edit` |
| `save` | `_save` |
| `uploadfile` | `_uploadfile` |
| `countfiles` | `_countfiles` |
| `loadconfig` | `_loadconfig` |

Also update all Perl 4-style calls (`&subname`) to modern syntax (`_subname()`).

### P4: Add POD Documentation

Add POD sections:

```perl
=head1 NAME

ConfigServer::cseUI - ConfigServer Explorer web interface

=head1 SYNOPSIS

    use ConfigServer::cseUI ();
    
    ConfigServer::cseUI::main(\%form_data, $fileinc, $script, $script_da, $images, $version);

=head1 DESCRIPTION

This module provides a web-based file manager interface for the ConfigServer
Explorer (CSE) component of CSF. It allows administrators to browse, view,
edit, copy, move, and delete files through a web interface.

=cut
```

Add function-level POD for `main()`:

```perl
=head2 main

    ConfigServer::cseUI::main(\%form, $fileinc, $script, $script_da, $images, $version);

Main entry point for the ConfigServer Explorer UI.

=over 4

=item * C<\%form> - Hash reference containing form data

=item * C<$fileinc> - File upload reference

=item * C<$script> - Script URL path

=item * C<$script_da> - DirectAdmin script path

=item * C<$images> - Images directory path

=item * C<$version> - CSE version string

=back

=cut
```

### P5: Add Unit Tests

Create `t/ConfigServer-cseUI.t`:

```perl
#!/usr/local/cpanel/3rdparty/bin/perl

use cPstrict;

use Test2::V0;
use Test2::Tools::Explain;
use Test2::Plugin::NoWarnings;

use lib 't/lib';
use MockConfig;

# Mock file operations before loading module
# ... (see test patterns in t/ConfigServer-RBLCheck.t)

use ConfigServer::cseUI ();

subtest "Module loading" => sub {
    ok(defined $ConfigServer::cseUI::VERSION, "Module has VERSION");
    can_ok('ConfigServer::cseUI', ['main']);
};

# Add more subtests for each action handler

done_testing;
```

## Verification Commands

```bash
# Syntax check
perl -cw -Ilib lib/ConfigServer/cseUI.pm

# POD check
podchecker lib/ConfigServer/cseUI.pm

# Run tests
prove -wlvm t/ConfigServer-cseUI.t

# Full test suite
make test
```

## Success Verification

- [ ] `perl -cw -Ilib lib/ConfigServer/cseUI.pm` passes
- [ ] `podchecker lib/ConfigServer/cseUI.pm` reports no errors
- [ ] `prove -wlvm t/ConfigServer-cseUI.t` passes
- [ ] `make test` passes with no regressions
- [ ] No `## no critic` line remains
- [ ] No Perl 4-style `&subname` calls remain
- [ ] No `# start`/`# end` comment markers remain
- [ ] All non-main functions prefixed with `_`
