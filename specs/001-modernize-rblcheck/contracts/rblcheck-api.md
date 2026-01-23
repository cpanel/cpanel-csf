# API Contract: ConfigServer::RBLCheck

**Date**: 2026-01-22  
**Module**: `lib/ConfigServer/RBLCheck.pm`

## Public API

### `report($verbose, $images, $ui)`

Performs RBL checking on all server public IP addresses.

**Parameters**:

| Name | Type | Required | Description |
|------|------|----------|-------------|
| `$verbose` | integer | Yes | Verbosity level: 0=basic, 1=detailed, 2=all IPs |
| `$images` | string | Yes | Path to UI images (passed through, not used in current impl) |
| `$ui` | boolean | Yes | If true, print output directly; if false, accumulate and return |

**Returns**: `($failures, $output)`

| Return | Type | Description |
|--------|------|-------------|
| `$failures` | integer | Count of IPs found on RBLs |
| `$output` | string | HTML-formatted results (only populated when `$ui=0`) |

**Example**:

```perl
use ConfigServer::RBLCheck;

# Get HTML output without printing
my ($failures, $html) = ConfigServer::RBLCheck::report(1, "/images", 0);
print "Found $failures IPs on blocklists\n";
print $html;

# Print directly to STDOUT (UI mode)
ConfigServer::RBLCheck::report(2, "/images", 1);
```

**Behavior**:

1. Loads configuration via `ConfigServer::Config->loadconfig()`
2. Discovers server IP addresses via `ConfigServer::GetEthDev`
3. Parses RBL list from `/usr/local/csf/lib/csf.rbls`
4. Applies user overrides from `/etc/csf/csf.rblconf` (if exists)
5. For each PUBLIC IP:
   - If cached result exists: use cache
   - If `$verbose` and no cache: perform RBL lookups, cache result
   - If not `$verbose` and no cache: mark as "Not Checked"
6. Returns failure count and HTML output

**Error Handling**: Preserves existing behavior; no exceptions thrown.

---

## Private API (Internal Use Only)

These functions are implementation details and should not be called externally.

### `_startoutput()`

Initializes output. Currently a no-op placeholder.

### `_addline($status, $rbl, $rblurl, $comment)`

Adds a single RBL check result line to output.

| Param | Type | Description |
|-------|------|-------------|
| `$status` | boolean | True if IP was found on this RBL |
| `$rbl` | string | RBL name |
| `$rblurl` | string | URL for RBL info page |
| `$comment` | string | Result text (OK, TIMEOUT, or listing details) |

### `_addtitle($title)`

Adds a section title to output.

### `_endoutput()`

Finalizes output with trailing newline.

### `_getethdev()`

Populates `%ips` hash with server IPv4 addresses via `ConfigServer::GetEthDev`.

---

## Dependencies

### Required Modules

| Module | Import Style | Usage |
|--------|--------------|-------|
| `Fcntl` | `use Fcntl ();` | `Fcntl::O_WRONLY`, `Fcntl::O_CREAT`, `Fcntl::LOCK_EX` |
| `Net::IP` | `use Net::IP;` | IP type detection |
| `ConfigServer::Config` | `use ConfigServer::Config;` | Config loading |
| `ConfigServer::CheckIP` | `qw(checkip)` | IP validation |
| `ConfigServer::Slurp` | `qw(slurp)` | File reading |
| `ConfigServer::GetIPs` | `qw(getips)` | (imported but appears unused) |
| `ConfigServer::RBLLookup` | `qw(rbllookup)` | DNS RBL lookups |
| `ConfigServer::GetEthDev` | full import | Network interface discovery |

### Removed Modules

| Module | Reason |
|--------|--------|
| `IPC::Open3` | Unused in module |
| `Exporter` | No exports defined |

---

## Compatibility Notes

- **IPv6**: Currently commented out; not activated in this modernization
- **Caching**: Existing cache files in `/var/lib/csf/*.rbls` remain compatible
- **UI Integration**: HTML output format unchanged for backward compatibility
