# Research: Modernize RBLLookup.pm

**Feature**: 005-modernize-rbllookup  
**Date**: 2026-01-24  
**Status**: Complete

## Research Tasks

### 1. IPC::Open3 Mocking Strategy

**Question**: How to mock `IPC::Open3::open3` calls for testing DNS responses?

**Decision**: Use Test2::Mock to override `IPC::Open3::open3`

**Rationale**: 
- Test2::Mock is already available via Test2::V0 (per constitution)
- Can intercept open3 calls and provide controlled output via in-memory filehandles
- Allows testing all code paths without actual DNS queries

**Implementation Pattern**:
```perl
my @open3_calls;
my $mock_output = "4.3.2.1.zen.spamhaus.org has address 127.0.0.2\n";

my $ipc_mock = mock 'IPC::Open3' => (
    override => [
        open3 => sub {
            my ($childin, $childout, $childerr, @cmd) = @_;
            push @open3_calls, \@cmd;
            
            # Create in-memory filehandle with mock output
            open my $mock_fh, '<', \$mock_output or die "Cannot open mock: $!";
            $_[1] = $mock_fh;  # Set childout
            
            return 12345;  # Fake PID
        },
    ],
);
```

**Alternatives Considered**:
- Actually calling host command → Rejected: requires network, unreliable in tests
- Subclassing → Rejected: more complex, harder to verify call arguments

### 2. Net::IP Behavior for IP Reversal

**Question**: How does Net::IP->reverse_ip() work for IPv4 and IPv6?

**Decision**: Document existing behavior for test assertions

**Findings**:
- IPv4 `1.2.3.4` → `4.3.2.1.in-addr.arpa.`
- IPv6 `2001:db8::1` → expanded nibble format `.ip6.arpa.`
- The code strips the `.in-addr.arpa` and `.ip6.arpa` suffixes after calling reverse_ip()

**Rationale**: Understanding this allows proper test assertions for reversed IP format.

### 3. Fcntl Usage Analysis

**Question**: Is Fcntl actually used in RBLLookup.pm?

**Decision**: Remove `use Fcntl qw(:DEFAULT :flock);` entirely

**Rationale**: 
- Searched the module for Fcntl constants: `LOCK_SH`, `LOCK_EX`, `LOCK_NB`, `O_RDONLY`, etc.
- None found in RBLLookup.pm
- The import is dead code, likely copy-pasted from another module

**Alternatives Considered**:
- Keep as `use Fcntl ();` → Rejected: no point loading unused module

### 4. ConfigServer::CheckIP Mocking

**Question**: Does ConfigServer::CheckIP have dependencies that need mocking?

**Decision**: CheckIP uses ConfigServer::Config internally - MockConfig handles this

**Findings**:
- `ConfigServer::CheckIP::checkip()` validates IP format using regex patterns
- It accesses `ipv4reg` and `ipv6reg` from ConfigServer::Config
- MockConfig already stubs these methods with the correct patterns

**Rationale**: No additional mocking needed - MockConfig provides the regex patterns.

### 5. Package-Level Config Loading Impact

**Question**: What is the impact of moving loadconfig() from package level to function?

**Decision**: Move to `ConfigServer::Config->get_config('HOST')` within rbllookup()

**Rationale**:
- Only one config value needed: `HOST` (path to host binary)
- `get_config()` is simpler than loadconfig() for single values
- Matches pattern recommended in perl.instructions.md
- Called twice in function (A query and TXT query) - minimal overhead

**Implementation**:
```perl
# Before (package level):
my $config = ConfigServer::Config->loadconfig();
my %config = $config->config();
# ... in function:
open3(..., $config{HOST}, ...)

# After (function level):
my $host_bin = ConfigServer::Config->get_config('HOST');
open3(..., $host_bin, ...)
```

## Summary of Decisions

| Topic | Decision | Impact |
|-------|----------|--------|
| Fcntl import | Remove entirely | Reduces unused dependencies |
| IPC::Open3 mocking | Test2::Mock override | Enables reliable DNS response testing |
| Config access | Use `get_config('HOST')` | Removes package-level side effects |
| CheckIP mocking | Use existing MockConfig | No additional mocking needed |
| Net::IP usage | Keep as `use Net::IP ();` | Standard OO usage, no changes to calls |
