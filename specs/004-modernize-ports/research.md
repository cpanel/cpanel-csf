# Research: Modernize Ports.pm

**Feature**: 004-modernize-ports  
**Date**: 2026-01-24

## Research Summary

This document consolidates findings from Phase 0 research tasks.

## Dependencies

### Cpanel::Slurp

**Decision**: Use `Cpanel::Slurp` for reading /proc files  
**Rationale**: Provides consistent error handling and cleaner code than manual open/flock/read patterns  
**Alternatives considered**: 
- Manual open/flock/read (current approach) - more verbose, inconsistent error handling
- File::Slurp (CPAN) - not a cPanel module, adds external dependency

**Usage patterns**:
- `Cpanel::Slurp::slurp($file)` - dies on error, use for required files
- `Cpanel::Slurp::slurpee($file)` - returns undef on error, use for optional files

**Note**: For `/proc/net/tcp6` and `/proc/net/udp6`, use `slurpee` since these may not exist when IPv6 is disabled.

### Fcntl Constants

**Decision**: Use `Fcntl::LOCK_SH` instead of importing `LOCK_SH`  
**Rationale**: Follows cPanel standard of disabling imports with `use Module ();`  
**Impact**: If switching to Cpanel::Slurp, LOCK_SH may not be needed at all (Slurp handles locking internally)

### Logging Approach

**Decision**: Use `warn` for non-fatal /proc access issues  
**Rationale**: 
- ConfigServer::Logger exists but is typically used for security events, not debug/info messages
- Simple `warn` is idiomatic Perl and captured by test frameworks
- Other ConfigServer modules use `warn` for similar situations

**Format**: `warn "Could not open /proc/net/$proto: $!";`

## Testing Strategy

### MockConfig Usage

The existing `t/lib/MockConfig.pm` provides:
- Automatic mocking of `ConfigServer::Config`
- `set_config(%hash)` to set config values
- `clear_config()` to reset between tests
- Proper handling of `loadconfig()`, `get_config()`, and `config()` methods

### Test Structure

Following the pattern from `t/ConfigServer-RBLCheck.t`:

```perl
#!/usr/local/cpanel/3rdparty/bin/perl

use cPstrict;

use Test2::V0;
use Test2::Tools::Explain;
use Test2::Plugin::NoWarnings;

use lib 't/lib';
use MockConfig;

# Load module under test
use ConfigServer::Ports;

# Tests...

done_testing();
```

### Testing Challenges

| Function | Challenge | Solution |
|----------|-----------|----------|
| `_hex2ip()` | None - pure function | Direct testing with known inputs |
| `openports()` | Requires config | MockConfig with set_config() |
| `listening()` | Requires /proc | Skip with `skip_all` if not Linux or no access |

## Clarifications Applied

All questions from the specification clarification session have been resolved:

| Question | Answer | Implementation |
|----------|--------|----------------|
| Permission denied on /proc | Log warning, continue | `warn` + continue to next entry |
| Missing config keys | Die with error | Add validation before processing |
| Malformed hex input | Return empty string | Guard clause at start of `_hex2ip` |
| File reading approach | Use Cpanel::Slurp | Replace open/flock/read with slurpee |
| Process race conditions | Silent skip | Preserve existing `or next` pattern |

## Edge Case Handling

### _hex2ip() Malformed Input

```perl
sub _hex2ip {
    my ($hex) = @_;
    
    # Return empty string for invalid input
    return '' unless defined $hex && length($hex) && $hex =~ /^[0-9A-Fa-f]+$/;
    
    # ... rest of implementation
}
```

### openports() Missing Config

```perl
sub openports {
    my $config = ConfigServer::Config->loadconfig();
    my %config = $config->config();
    
    # Validate required config keys
    for my $key (qw(TCP_IN TCP6_IN UDP_IN UDP6_IN)) {
        die "Required configuration key '$key' is missing\n" 
            unless exists $config{$key};
    }
    
    # ... rest of implementation
}
```

### listening() /proc Access

```perl
foreach my $proto ( "tcp", "udp", "tcp6", "udp6" ) {
    my $content = Cpanel::Slurp::slurpee("/proc/net/$proto");
    unless (defined $content) {
        warn "Could not read /proc/net/$proto: $!\n";
        next;
    }
    
    for my $line (split /\n/, $content) {
        # ... process line
    }
}
```

## Conclusion

All research tasks complete. No blocking issues identified. Ready to proceed with implementation.
