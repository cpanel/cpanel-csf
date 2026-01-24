# Research: Modernize cseUI.pm

**Feature**: 002-modernize-cseui  
**Date**: 2026-01-23

## Module Analysis

### Current State

**File**: `lib/ConfigServer/cseUI.pm`  
**Lines**: 1094  
**Version**: 2.03  
**Subroutines**: 19

### Import Analysis

| Current Import | Issue | Resolution |
|----------------|-------|------------|
| `use strict;` | Should use cPstrict | Replace with `use cPstrict;` |
| `use Fcntl qw(:DEFAULT :flock);` | Imports symbols | Use `use Fcntl ();` + fully qualified `Fcntl::LOCK_SH`, `Fcntl::LOCK_EX`, `Fcntl::O_RDONLY`, `Fcntl::O_WRONLY`, `Fcntl::O_CREAT`, `Fcntl::O_TRUNC` |
| `use File::Find;` | Imports `find()` | Use `use File::Find ();` + `File::Find::find()` |
| `use File::Copy;` | Imports `copy()` | Use `use File::Copy ();` + `File::Copy::copy()` |
| `use IPC::Open3;` | Imports `open3()` | Use `use IPC::Open3 ();` + `IPC::Open3::open3()` |
| `use Exporter qw(import);` | Unused | Remove entirely (no exports defined) |

### Global Variables Analysis

**Block 1 (line 36-38)**:
```perl
our (
    $chart, $ipscidr6, $ipv6reg, $ipv4reg, %config, %ips, $mobile,
    %FORM, $script, $script_da, $images, $myv
);
```

| Variable | Used? | Action |
|----------|-------|--------|
| `$chart` | No | Remove |
| `$ipscidr6` | No | Remove |
| `$ipv6reg` | No | Remove |
| `$ipv4reg` | No | Remove |
| `%config` | Yes (loaded via loadconfig) | Keep, populate in main() |
| `%ips` | No | Remove |
| `$mobile` | No | Remove |
| `%FORM` | Yes | Keep as `our` for inter-sub communication |
| `$script` | Yes | Keep as `our` for inter-sub communication |
| `$script_da` | Yes | Keep as `our` for inter-sub communication |
| `$images` | Yes | Keep as `our` for inter-sub communication |
| `$myv` | Yes | Keep as `our` for inter-sub communication |

**Block 2 (line 40-45)**:
```perl
our (
    $act, $destpath, $element, $extramessage, $fieldname, $fileinc,
    $filetemp, $message, $name, $origpath, $storepath, $tgid, $thisdir,
    $tuid, $value, $webpath, %ele, %header, @bits, @dirs, @filebodies,
    @filenames, @files, @months, @parts, @passrecs, @thisdirs, @thisfiles,
    $files
);
```

These are all used for inter-subroutine communication. Keep as `our` variables for now; refactoring to parameters would be a larger scope change.

### Perl 4-Style Calls

All subroutine calls use `&subname` syntax. Found instances:

| Call | Line(s) | New Syntax |
|------|---------|------------|
| `&loadconfig` | 56 | `_loadconfig()` |
| `&view` | 62 | `_view()` |
| `&browse` | 136, 152, etc. | `_browse()` |
| `&setp` | multiple | `_setp()` |
| `&seto` | multiple | `_seto()` |
| `&ren` | multiple | `_ren()` |
| `&moveit` | multiple | `_moveit()` |
| `&copyit` | multiple | `_copyit()` |
| `&cnewd` | multiple | `_cnewd()` |
| `&cnewf` | multiple | `_cnewf()` |
| `&del` | multiple | `_del()` |
| `&console` | multiple | `_console()` |
| `&cd` | multiple | `_cd()` |
| `&edit` | multiple | `_edit()` |
| `&save` | multiple | `_save()` |
| `&uploadfile` | multiple | `_uploadfile()` |

### Comment Markers to Remove

| Pattern | Location | Action |
|---------|----------|--------|
| `# start main` | Line 47-48 | Remove |
| `# end main` | Line 155 | Remove |
| Similar markers | Between other subs | Remove all |

### Fcntl Constants Usage

The module uses Fcntl for file locking. Need to identify all usages:

```perl
# Current usage patterns to update:
flock($fh, LOCK_SH)  →  flock($fh, Fcntl::LOCK_SH)
flock($fh, LOCK_EX)  →  flock($fh, Fcntl::LOCK_EX)
sysopen(..., O_RDONLY)  →  sysopen(..., Fcntl::O_RDONLY)
# etc.
```

Note: `flock`, `sysopen`, `opendir`, `readdir`, `closedir` are Perl builtins, not Fcntl functions.

### loadconfig() Function

Located at line 1067. Currently reads `/etc/csf/csf.conf` directly. This function should be:
1. Renamed to `_loadconfig()`
2. Called within `main()` scope (already is, just uses Perl 4 syntax)
3. Continue using direct file reading (matches existing pattern in CSF codebase)

## Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Keep `our` for form/config vars | Yes | Refactoring to pass as parameters would be a larger scope change |
| Remove unused `our` variables | Yes | Clean up dead code |
| Use fully qualified Fcntl constants | Yes | Constitution requires disabled imports |
| Private function prefix | `_` | Standard Perl convention for internal functions |
| Test approach | Mock file I/O at high level | Simpler than mocking syscalls |

## Alternatives Considered

| Alternative | Rejected Because |
|-------------|------------------|
| Convert all `our` to function params | Too large a scope change; would require significant refactoring of all 19 functions |
| Use ConfigServer::Config instead of custom loadconfig | The custom loadconfig reads a different format; would change behavior |
| Full refactor of module structure | Out of scope for modernization task |
