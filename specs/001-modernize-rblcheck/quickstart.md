# Quickstart: Modernize RBLCheck.pm

**Date**: 2026-01-22  
**Estimated Time**: 2-3 hours  
**Prerequisites**: CloudFlare.pm modernization pattern (commit 7bd732d)

---

## Implementation Order

Complete each phase before moving to the next. Run validation after each step.

### Phase 1: Remove Package-Level Config Loading (P1)

**Goal**: Module compiles without `/etc/csf/csf.conf`

1. **Remove unused globals** (lines 44-45):
   ```perl
   # DELETE these lines:
   my $ipv4reg = ConfigServer::Config->ipv4reg;
   my $ipv6reg = ConfigServer::Config->ipv6reg;
   ```

2. **Remove `%config` from package-level declaration** (line 40-42):
   ```perl
   # Change from:
   my ($ui, $failures, $verbose, $cleanreg, $status, %ips, $images, %config, $ipresult, $output);
   
   # To:
   my ($ui, $failures, $verbose, $cleanreg, $status, %ips, $images, $ipresult, $output);
   ```

3. **Add `my` to `%config` in `report()`** (line 53):
   ```perl
   # Already correct - loadconfig() is called in report(), just ensure %config is my
   my $config = ConfigServer::Config->loadconfig();
   my %config = $config->config();
   ```

**Validate**: `perl -cw -Ilib lib/ConfigServer/RBLCheck.pm`

---

### Phase 2: Code Modernization (P2)

**Goal**: Follow cPstrict and import standards

1. **Replace strict/warnings with cPstrict** (line 22-23):
   ```perl
   # Change from:
   use strict;
   
   # To:
   use cPstrict;
   ```

2. **Remove `## no critic` line** (line 19):
   ```perl
   # DELETE this line:
   ## no critic (RequireUseWarnings, ProhibitExplicitReturnUndef, ProhibitMixedBooleanOperators, RequireBriefOpen)
   ```

3. **Disable Fcntl imports** (line 24):
   ```perl
   # Change from:
   use Fcntl qw(:DEFAULT :flock);
   
   # To:
   use Fcntl ();
   ```

4. **Remove unused import** (line 30):
   ```perl
   # DELETE this line:
   use IPC::Open3;
   ```

5. **Remove Exporter machinery** (lines 34-37):
   ```perl
   # DELETE these lines:
   use Exporter qw(import);
   our @ISA       = qw(Exporter);
   our @EXPORT_OK = qw();
   ```

6. **Update Fcntl constants to fully qualified** (line 152-153):
   ```perl
   # Change from:
   sysopen( my $OUT, "/var/lib/csf/${ip}.rbls", O_WRONLY | O_CREAT );
   flock( $OUT, LOCK_EX );
   
   # To:
   sysopen( my $OUT, "/var/lib/csf/${ip}.rbls", Fcntl::O_WRONLY | Fcntl::O_CREAT );
   flock( $OUT, Fcntl::LOCK_EX );
   ```

**Validate**: `perl -cw -Ilib lib/ConfigServer/RBLCheck.pm`

---

### Phase 3: Make Subroutines Private (P3)

**Goal**: Clear public API boundary

1. **Rename function definitions**:
   | Line | From | To |
   |------|------|-----|
   | 184 | `sub startoutput` | `sub _startoutput` |
   | 190 | `sub addline` | `sub _addline` |
   | 217 | `sub addtitle` | `sub _addtitle` |
   | 232 | `sub endoutput` | `sub _endoutput` |
   | 241 | `sub getethdev` | `sub _getethdev` |

2. **Update all callers** (convert Perl 4 `&func` to `_func()`):
   | Line | From | To |
   |------|------|-----|
   | 59 | `&startoutput` | `_startoutput()` |
   | 61 | `&getethdev` | `_getethdev()` |
   | 121 | `&addtitle(...)` | `_addtitle(...)` |
   | 134 | `&addline(...)` | `_addline(...)` |
   | 137 | `&addline(...)` | `_addline(...)` |
   | 140 | `&addline(...)` | `_addline(...)` |
   | 157 | `&addtitle(...)` | `_addtitle(...)` |
   | 162 | `&addtitle(...)` | `_addtitle(...)` |
   | 176 | `&endoutput` | `_endoutput()` |

**Validate**: `perl -cw -Ilib lib/ConfigServer/RBLCheck.pm`

---

### Phase 4: Add POD Documentation (P4)

**Goal**: Document public API only

1. **Add module-level POD after `package` line**:
   ```perl
   package ConfigServer::RBLCheck;
   
   =head1 NAME
   
   ConfigServer::RBLCheck - Check server IPs against Real-time Blackhole Lists
   
   =head1 SYNOPSIS
   
       use ConfigServer::RBLCheck;
       
       my ($failures, $html) = ConfigServer::RBLCheck::report(1, "/images", 0);
   
   =head1 DESCRIPTION
   
   This module checks all public IP addresses on the server against configured
   Real-time Blackhole Lists (RBLs) to detect if any IPs are listed for spam
   or malware activity.
   
   =cut
   
   use cPstrict;
   ```

2. **Add POD for `report()` function** (before `sub report`):
   ```perl
   =head2 report($verbose, $images, $ui)
   
   Checks all server public IPs against configured RBLs.
   
   =head3 Parameters
   
   =over 4
   
   =item C<$verbose> - Integer verbosity level (0=basic, 1=detailed, 2=all)
   
   =item C<$images> - String path to UI images
   
   =item C<$ui> - Boolean; if true, prints directly to STDOUT
   
   =back
   
   =head3 Returns
   
   List of C<($failures, $output)> where C<$failures> is count of IPs on blocklists
   and C<$output> is HTML string (empty if C<$ui> is true).
   
   =cut
   
   sub report {
   ```

**Validate**: `podchecker lib/ConfigServer/RBLCheck.pm`

---

### Phase 5: Add Unit Tests (P5)

**Goal**: Test coverage for public API

1. **Create test file** `t/ConfigServer-RBLCheck.t`:
   ```perl
   #!/usr/local/cpanel/3rdparty/bin/perl
   
   use strict;
   use warnings;
   
   use Test2::V0;
   use Test2::Plugin::NoWarnings;
   use Test2::Tools::Mock;
   
   use lib 't/lib';
   use MockConfig;
   
   # Setup mock config before loading module
   MockConfig->setup();
   
   # Mock dependencies
   my $mock_ethdev = mock 'ConfigServer::GetEthDev' => (
       override => [
           new  => sub { bless {}, shift },
           ipv4 => sub { return () },
           ipv6 => sub { return () },
       ]
   );
   
   # Now load the module under test
   use ConfigServer::RBLCheck;
   
   subtest 'Module loads correctly' => sub {
       ok(1, 'ConfigServer::RBLCheck loaded');
   };
   
   subtest 'Public API exists' => sub {
       can_ok('ConfigServer::RBLCheck', 'report');
   };
   
   subtest 'report() returns expected structure' => sub {
       my ($failures, $output) = ConfigServer::RBLCheck::report(0, '', 0);
       is($failures, 0, 'No failures with no IPs');
       like($output, qr/<br>/, 'Output contains HTML');
   };
   
   done_testing();
   ```

**Validate**:
```bash
perl -cw -Ilib t/ConfigServer-RBLCheck.t
prove -wlvm t/ConfigServer-RBLCheck.t
make test
```

---

## Validation Checklist

- [ ] `perl -cw -Ilib lib/ConfigServer/RBLCheck.pm` passes (no config files needed)
- [ ] `podchecker lib/ConfigServer/RBLCheck.pm` reports no errors
- [ ] `perl -cw -Ilib t/ConfigServer-RBLCheck.t` passes
- [ ] `prove -wlvm t/ConfigServer-RBLCheck.t` all tests pass
- [ ] `make test` no regressions
- [ ] Only `report()` is public (no underscore)
- [ ] All internal functions prefixed with `_`
- [ ] No Perl 4 `&function` calls remain
- [ ] No `use Exporter` in module
- [ ] `Fcntl` uses `()` empty import with qualified constants
