# Quickstart: Modernize Ports.pm

**Feature**: 004-modernize-ports  
**Date**: 2026-01-24

## Prerequisites

- Branch `004-modernize-ports` checked out
- Access to cPanel Perl: `/usr/local/cpanel/3rdparty/bin/perl`

## Implementation Steps

### Step 1: Remove Legacy Comment Clutter (P0)

Remove these patterns from `lib/ConfigServer/Ports.pm`:

```bash
# Remove ## no critic line (line 19)
# Remove # start/end markers
# Remove ###...### dividers between functions (NOT copyright header)
# Remove ##no critic from %printable line
```

**Verify**: `perl -cw -Ilib lib/ConfigServer/Ports.pm` compiles

### Step 2: Modernize Imports (P1)

1. Add `use warnings;` after `use strict;`
2. Remove `use lib '/usr/local/csf/lib';`
3. Change `use Fcntl qw(:DEFAULT :flock);` to `use Fcntl ();`
4. Remove Exporter:
   ```perl
   # DELETE these lines:
   use Exporter qw(import);
   our @ISA       = qw(Exporter);
   our @EXPORT_OK = qw();
   ```

### Step 3: Replace Bareword Handles (P1)

Replace bareword directory handles with lexical handles:

```perl
# Before
opendir( PROCDIR, "/proc" );
while ( my $pid = readdir(PROCDIR) ) { ... }
closedir(PROCDIR);

# After
opendir( my $procdir, "/proc" ) or do {
    warn "Could not open /proc: $!\n";
    return %listen;
};
while ( my $pid = readdir($procdir) ) { ... }
closedir($procdir);
```

Same for `DIR` handle → `$fddir`.

### Step 4: Fix Perl 4-Style Calls (P1 + P2)

```perl
# Before
$dip = &hex2ip($dip);

# After
$dip = _hex2ip($dip);
```

### Step 5: Fully Qualify Fcntl Constants (P1)

```perl
# Before
flock( $IN, LOCK_SH );

# After
flock( $IN, Fcntl::LOCK_SH );
```

### Step 6: Rename hex2ip to _hex2ip (P2)

```perl
sub _hex2ip {
    my ($hex) = @_;
    
    # Add input validation
    return '' unless defined $hex && length($hex) && $hex =~ /^[0-9A-Fa-f]+$/;
    
    my $bin = pack "C*" => map { hex } $hex =~ /../g;
    my @l   = unpack "L*", $bin;
    if ( @l == 4 ) {
        return join ':', map { sprintf "%x:%x", $_ >> 16, $_ & 0xffff } @l;
    }
    elsif ( @l == 1 ) {
        return join '.', map { $_ >> 24, ( $_ >> 16 ) & 0xff, ( $_ >> 8 ) & 0xff, $_ & 0xff } @l;
    }
    
    return '';
}
```

### Step 7: Add POD Documentation (P3)

Add after line 18 (after copyright header):

```pod
=head1 NAME

ConfigServer::Ports - Network port inspection and configuration utilities

=head1 SYNOPSIS

    use ConfigServer::Ports;
    
    # Get hash of listening ports with process info
    my %listening = ConfigServer::Ports::listening();
    
    # Get hash of ports configured as open in CSF
    my %open = ConfigServer::Ports::openports();

=head1 DESCRIPTION

This module provides utilities for inspecting network port usage on Linux
systems. It reads from the /proc filesystem to identify which processes
are listening on which ports, and from CSF configuration to determine
which ports are configured to be open.

=cut
```

Add before each public function:

```pod
=head2 listening

    my %listen = ConfigServer::Ports::listening();

Returns a hash of all listening network ports with associated process
information. Reads from /proc/net/tcp, /proc/net/udp, and their IPv6
variants.

=head3 Returns

Hash with structure: C<< {protocol}{port}{pid}{attribute} >>

Attributes include: C<user>, C<exe>, C<cmd>, C<conn>

=cut
```

### Step 8: Create Unit Tests (P4)

Create `t/ConfigServer-Ports.t`:

```perl
#!/usr/local/cpanel/3rdparty/bin/perl

use cPstrict;

use Test2::V0;
use Test2::Tools::Explain;
use Test2::Plugin::NoWarnings;

use lib 't/lib';
use MockConfig;

use ConfigServer::Ports;

subtest 'Module loads correctly' => sub {
    ok( defined $ConfigServer::Ports::VERSION, 'VERSION is defined' );
};

subtest '_hex2ip converts IPv4 correctly' => sub {
    # 127.0.0.1 in little-endian hex = 0100007F
    is( ConfigServer::Ports::_hex2ip('0100007F'), '127.0.0.1', 'localhost IPv4' );
};

subtest '_hex2ip converts IPv6 correctly' => sub {
    # ::1 = 00000000000000000000000000000001
    my $result = ConfigServer::Ports::_hex2ip('00000000000000000000000000000001');
    like( $result, qr/::?1$/, 'localhost IPv6' );
};

subtest '_hex2ip handles malformed input' => sub {
    is( ConfigServer::Ports::_hex2ip(''),        '', 'empty string' );
    is( ConfigServer::Ports::_hex2ip(undef),     '', 'undef' );
    is( ConfigServer::Ports::_hex2ip('ZZZZ'),    '', 'non-hex chars' );
};

subtest 'openports returns correct structure with mocked config' => sub {
    set_config(
        TCP_IN  => '22,80,443',
        TCP6_IN => '22,80',
        UDP_IN  => '53',
        UDP6_IN => '53',
    );
    
    my %ports = ConfigServer::Ports::openports();
    
    ok( $ports{tcp}{22},  'TCP 22 is open' );
    ok( $ports{tcp}{80},  'TCP 80 is open' );
    ok( $ports{tcp}{443}, 'TCP 443 is open' );
    ok( $ports{udp}{53},  'UDP 53 is open' );
};

done_testing();
```

## Validation Commands

```bash
# Syntax check
perl -cw -Ilib lib/ConfigServer/Ports.pm

# POD check
podchecker lib/ConfigServer/Ports.pm

# Run tests
prove -wlvm t/ConfigServer-Ports.t

# Check for legacy patterns (should return nothing)
grep -n '# start\|# end\|^###' lib/ConfigServer/Ports.pm | grep -v '^1:' | grep -v '^18:'
grep -n '&hex2ip\|PROCDIR\|opendir.*DIR' lib/ConfigServer/Ports.pm
```

## Common Issues

1. **Test fails on non-Linux**: Use `skip_all` if not on Linux or if /proc not accessible
2. **Cpanel::Slurp not found**: Fall back to manual open/read in tests
3. **Config keys not found**: MockConfig must provide all four port config keys
