# Implementation Plan: Modernize RBLLookup.pm

**Branch**: `005-modernize-rbllookup` | **Date**: 2026-01-24 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/005-modernize-rbllookup/spec.md`

## Summary

Modernize `ConfigServer::RBLLookup` module to follow cPanel Perl coding standards: remove package-level config loading, remove Exporter machinery, use disabled imports with fully qualified names, remove unused Fcntl import, add POD documentation, and create comprehensive unit tests with mocked external dependencies.

## Technical Context

**Language/Version**: Perl 5.36+ (cPanel-provided at `/usr/local/cpanel/3rdparty/bin/perl`)  
**Primary Dependencies**: ConfigServer::Config, ConfigServer::CheckIP, IPC::Open3, Net::IP  
**Storage**: N/A (performs external DNS queries via `host` command)  
**Testing**: Test2::V0 framework with MockConfig for configuration mocking  
**Target Platform**: Linux server with `host` command available  
**Project Type**: Single Perl module modernization  
**Performance Goals**: N/A (existing behavior preserved)  
**Constraints**: DNS queries have 4-second timeout; external dependencies must be mockable for tests  
**Scale/Scope**: Single 107-line module with 1 subroutine

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Copyright & Attribution | ✅ PASS | Copyright header (lines 1-18) will be preserved exactly |
| II. Security-First Design | ✅ PASS | Uses three-arg open3, validates IP input via checkip() |
| III. Perl Standards Compliance | ✅ WILL FIX | Currently violates: Exporter, package-level loadconfig, imports without () |
| IV. Test-First & Isolation | ✅ WILL ADD | Creating t/ConfigServer-RBLLookup.t with MockConfig |
| V. Configuration Discipline | ✅ WILL FIX | Config loaded at module level - must move to function |
| VI. Simplicity & Maintainability | ✅ PASS | Module is already simple (1 function) |

**Gate Result**: PASS - No blocking violations. Modernization will bring module into compliance.

## Project Structure

### Documentation (this feature)

```text
specs/005-modernize-rbllookup/
├── spec.md              # Feature specification
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output (N/A for this feature)
├── quickstart.md        # Phase 1 output
└── checklists/
    └── requirements.md  # Validation checklist
```

### Source Code (repository root)

```text
lib/
└── ConfigServer/
    └── RBLLookup.pm     # Module to modernize

t/
├── lib/
│   └── MockConfig.pm    # Existing test mock utility
└── ConfigServer-RBLLookup.t # New test file to create
```

**Structure Decision**: Single module modernization - no new directories needed. Test file follows existing `t/ConfigServer-*.t` naming convention.

## Phase 0: Research

### Dependencies to Research

1. **IPC::Open3 mocking** - How to mock open3 calls for testing DNS responses
2. **Net::IP behavior** - How Net::IP->reverse_ip() works for IPv4/IPv6
3. **Existing test patterns** - Review MockConfig usage and IPC mocking patterns

### Research Tasks

| Topic | Finding |
|-------|---------|
| IPC::Open3 mocking | Use Test2::Mock to override `IPC::Open3::open3` - can capture calls and return controlled output via filehandle manipulation |
| Net::IP reverse behavior | IPv4: `1.2.3.4` → `4.3.2.1.in-addr.arpa.`; IPv6: compressed → expanded `.ip6.arpa.` format |
| MockConfig patterns | Already provides ConfigServer::Config mocking via `set_config()` |
| ConfigServer::CheckIP | Uses `checkip(\$ip)` to validate IP addresses - already mocked via MockConfig (same config dependency) |
| Fcntl usage | Module imports `:DEFAULT :flock` but never uses any Fcntl constants - can remove entirely |

### Open Questions Resolved

All clarification questions answered in spec:
- Invalid IP → Return empty strings (checkip fails, no lookup performed)
- DNS timeout → Return "timeout" as rblhit, empty rblhittxt
- Missing HOST config → Die with error (or fail when open3 fails)
- No TXT record → Return rblhit with empty rblhittxt

## Phase 1: Design

### Data Model

No new entities to design. Function signature and return values preserved:

| Entity | Type | Description |
|--------|------|-------------|
| $ip | Input | IP address to check (IPv4 or IPv6) |
| $rbl | Input | RBL domain name (e.g., "zen.spamhaus.org") |
| $rblhit | Output | IP if listed, "timeout" on timeout, empty if not listed |
| $rblhittxt | Output | TXT record explanation from RBL (may be empty) |

### API Contracts

**Public API** (unchanged signature):

```perl
# rbllookup($ip, $rbl) - Perform RBL lookup for IP address
# Should be called as: ConfigServer::RBLLookup::rbllookup($ip, $rbl)
sub rbllookup {
    my $ip  = shift;
    my $rbl = shift;
    
    # Returns: ($rblhit, $rblhittxt)
    #   $rblhit    - IP if listed, "timeout" on timeout, "" if not listed
    #   $rblhittxt - TXT record text, "" if none or timeout
    return ( $rblhit, $rblhittxt );
}
```

### Implementation Phases

#### Phase 1: P0 - Verify No Legacy Comment Clutter

**Files to examine**: `lib/ConfigServer/RBLLookup.pm`

**Status**: Already clean - no `# start`/`# end` markers or `###...###` dividers between subroutines. Only copyright header dividers exist (lines 1 and 18). No changes needed.

#### Phase 2: P1 - Code Modernization

**Files to modify**: `lib/ConfigServer/RBLLookup.pm`

**Changes**:
1. Remove `use Fcntl qw(:DEFAULT :flock);` entirely (unused)
2. Change `use IPC::Open3;` to `use IPC::Open3 ();`
3. Change `use Net::IP;` to `use Net::IP ();`
4. Change `use ConfigServer::CheckIP qw(checkip);` to `use ConfigServer::CheckIP ();`
5. Remove `use Exporter qw(import);`
6. Remove `our @ISA = qw(Exporter);`
7. Remove `our @EXPORT_OK = qw(rbllookup);`
8. Remove package-level `my $config = ConfigServer::Config->loadconfig();`
9. Remove package-level `my %config = $config->config();`
10. Replace `checkip(\$ip)` with `ConfigServer::CheckIP::checkip(\$ip)` in rbllookup()
11. Replace `open3(...)` calls with `IPC::Open3::open3(...)` (2 locations)
12. Replace `$config{HOST}` with `ConfigServer::Config->get_config('HOST')` (2 locations)

#### Phase 3: P2 - Make Internal Subroutines Private

**Files to examine**: `lib/ConfigServer/RBLLookup.pm`

**Status**: No changes needed - module has only one function (`rbllookup`) which is the public API. No internal helpers exist.

#### Phase 4: P3 - Add POD Documentation

**Files to modify**: `lib/ConfigServer/RBLLookup.pm`

**Sections to add**:
1. Module-level POD after line 18 (NAME, SYNOPSIS, DESCRIPTION)
2. `=head2 rbllookup` documentation before the subroutine
3. `=head1 SEE ALSO` section referencing related modules
4. `=head1 LICENSE` section (brief, referencing GPL header)

**POD Content**:
```pod
=head1 NAME

ConfigServer::RBLLookup - Perform Real-time Blackhole List (RBL) lookups

=head1 SYNOPSIS

    use ConfigServer::RBLLookup ();
    
    my ($hit, $txt) = ConfigServer::RBLLookup::rbllookup($ip, $rbl_domain);
    
    if ($hit && $hit ne 'timeout') {
        print "IP $ip is listed: $txt\n";
    }

=head1 DESCRIPTION

This module performs DNS-based Real-time Blackhole List (RBL) lookups for
IP addresses. RBLs are DNS-based databases that list IP addresses known
for spam, malware, or other malicious activity.

The lookup works by reversing the IP address and querying the RBL domain.
For example, checking 1.2.3.4 against zen.spamhaus.org queries:
4.3.2.1.zen.spamhaus.org

=head2 rbllookup

    my ($hit, $txt) = ConfigServer::RBLLookup::rbllookup($ip, $rbl);

Performs an RBL lookup for the given IP address against the specified RBL domain.

Parameters:

=over 4

=item $ip - IP address to check (IPv4 or IPv6 format)

=item $rbl - RBL domain name (e.g., "zen.spamhaus.org")

=back

Returns a list of two values:

=over 4

=item $hit - The response IP if listed, "timeout" on DNS timeout, or empty string if not listed

=item $txt - The TXT record explanation from the RBL, or empty string if none

=back

=head1 SEE ALSO

L<ConfigServer::RBLCheck>, L<ConfigServer::CheckIP>

=head1 LICENSE

See the GPL license in the source file header.

=cut
```

#### Phase 5: P4 - Add Unit Test Coverage

**Files to create**: `t/ConfigServer-RBLLookup.t`

**Test Scenarios**:

1. **Module loading** - Verify module loads without package-level side effects
2. **Invalid IP handling** - Invalid IPs return empty strings without DNS query
3. **IPv4 address handling** - Valid IPv4 triggers correct reversed lookup
4. **IPv6 address handling** - Valid IPv6 triggers correct reversed lookup
5. **RBL hit with TXT** - Mocked A record hit followed by TXT lookup
6. **RBL hit without TXT** - Mocked A record hit, no TXT record
7. **RBL not listed** - Mocked no A record response
8. **Timeout handling** - Mocked timeout returns "timeout"

**Mocking Strategy**:
- Use MockConfig for `HOST` configuration value
- Use Test2::Mock to override `IPC::Open3::open3` to control DNS responses
- May need to mock `ConfigServer::CheckIP::checkip` if it has file dependencies

**Test File Structure**:
```perl
#!/usr/local/cpanel/3rdparty/bin/perl

use cPstrict;

use Test2::V0;
use Test2::Tools::Explain;
use Test2::Plugin::NoWarnings;

use lib 't/lib';
use MockConfig;

# Set required config
set_config(
    HOST => '/usr/bin/host',
);

# Load module after config is mocked
use ConfigServer::RBLLookup ();

# Tests here...

done_testing();
```

## Complexity Tracking

No constitution violations to justify - this is a straightforward modernization.

