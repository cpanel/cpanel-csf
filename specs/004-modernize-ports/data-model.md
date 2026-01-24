# Data Model: Modernize Ports.pm

**Feature**: 004-modernize-ports  
**Date**: 2026-01-24

## Overview

This is a module modernization effort. No new data models are introduced. This document describes the existing data structures that must be preserved.

## Entities

### Package-Level Constants

#### %tcpstates

Lookup table mapping hex TCP state codes to human-readable names.

```perl
my %tcpstates = (
    "01" => "ESTABLISHED",
    "02" => "SYN_SENT",
    "03" => "SYN_RECV",
    "04" => "FIN_WAIT1",
    "05" => "FIN_WAIT2",
    "06" => "TIME_WAIT",
    "07" => "CLOSE",
    "08" => "CLOSE_WAIT",
    "09" => "LAST_ACK",
    "0A" => "LISTEN",
    "0B" => "CLOSING"
);
```

**Used by**: `listening()` to convert `/proc/net/tcp` state column to readable string.

#### %printable

Escape map for sanitizing non-printable characters in command lines.

```perl
my %printable = (
    # Auto-generated for bytes 0-255: chr($_) => unpack('H2', chr($_))
    # Plus special overrides:
    "\\" => '\\',
    "\r" => 'r',
    "\n" => 'n',
    "\t" => 't',
    "\"" => '"'
);
```

**Used by**: `listening()` to sanitize `exe` and `cmdline` values from `/proc/<pid>/`.

### Return Value Structures

#### %listen (from listening())

Nested hash containing information about processes listening on network ports.

```
%listen = {
    $protocol => {           # "tcp" | "udp"
        $port => {           # Port number (integer)
            $pid => {        # Process ID (integer)
                user => $username,   # Username or UID if lookup fails
                exe  => $exe_path,   # Executable path (sanitized)
                cmd  => $cmdline,    # Full command line (sanitized)
                conn => $count       # Connection count or "-"
            }
        }
    }
}
```

**Example**:
```perl
{
    tcp => {
        22 => {
            1234 => {
                user => "root",
                exe  => "/usr/sbin/sshd",
                cmd  => "sshd: /usr/sbin/sshd -D",
                conn => 5
            }
        },
        80 => {
            5678 => {
                user => "www-data",
                exe  => "/usr/sbin/apache2",
                cmd  => "/usr/sbin/apache2 -k start",
                conn => 42
            }
        }
    },
    udp => {
        53 => {
            9999 => {
                user => "named",
                exe  => "/usr/sbin/named",
                cmd  => "/usr/sbin/named -u named",
                conn => "-"
            }
        }
    }
}
```

#### %ports (from openports())

Simple nested hash indicating which ports are configured as open in CSF.

```
%ports = {
    $protocol => {           # "tcp" | "tcp6" | "udp" | "udp6"
        $port => 1           # Port number => 1 (boolean flag)
    }
}
```

**Example**:
```perl
{
    tcp => {
        22 => 1,
        80 => 1,
        443 => 1
    },
    tcp6 => {
        22 => 1,
        80 => 1,
        443 => 1
    },
    udp => {
        53 => 1
    },
    udp6 => {
        53 => 1
    }
}
```

## Configuration Keys Used

The `openports()` function reads these keys from CSF configuration:

| Key | Type | Description |
|-----|------|-------------|
| TCP_IN | String | Comma-separated list of allowed TCP ports |
| TCP6_IN | String | Comma-separated list of allowed TCP6 ports |
| UDP_IN | String | Comma-separated list of allowed UDP ports |
| UDP6_IN | String | Comma-separated list of allowed UDP6 ports |

**Port format**: Individual ports (`22`) or ranges (`6000:6100`)

## State Transitions

None. This module provides read-only inspection of system state.

## Validation Rules

- Port numbers: Integer 0-65535
- Protocol: One of "tcp", "tcp6", "udp", "udp6"
- Hex IP input to `_hex2ip()`: Even-length string of hex characters (8 chars for IPv4, 32 chars for IPv6)
