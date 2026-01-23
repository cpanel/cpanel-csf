# Data Model: RBLCheck.pm

**Date**: 2026-01-22  
**Plan**: [plan.md](plan.md)

## Entities

### ConfigServer::RBLCheck (Module)

The module checks server IP addresses against Real-time Blackhole Lists (RBLs) for spam/malware detection.

**Package Variables** (after modernization):

| Variable | Type | Purpose | Scope |
|----------|------|---------|-------|
| `$VERSION` | scalar | Module version | Package |
| `$ui` | scalar (bool) | Whether to print directly to UI | Package (shared state) |
| `$failures` | scalar (int) | Count of RBL hits | Package (accumulator) |
| `$verbose` | scalar (int) | Verbosity level (0, 1, 2) | Package (shared state) |
| `$cleanreg` | scalar (regex) | Cleanup pattern from Slurp | Package (cached) |
| `%ips` | hash | IP addresses to check | Package (populated by _getethdev) |
| `$images` | scalar | Image path for UI | Package (shared state) |
| `$ipresult` | scalar | HTML output for single IP | Package (accumulator) |
| `$output` | scalar | Full HTML output | Package (accumulator) |

**Removed Variables**:
- `$ipv4reg` - was unused
- `$ipv6reg` - was unused
- `%config` - moved to lexical scope in `report()`

### RBL Entry

Represents a single RBL service for lookup.

| Field | Type | Source | Example |
|-------|------|--------|---------|
| `rbl` | string | csf.rbls / csf.rblconf | `"zen.spamhaus.org"` |
| `rblurl` | string | After `:` delimiter | `"https://www.spamhaus.org/lookup/"` |

**Format in config files**: `rbl:url` (e.g., `zen.spamhaus.org:https://...`)

### IP Cache Entry

Cached RBL check results stored in `/var/lib/csf/{ip}.rbls`.

| Field | Type | Description |
|-------|------|-------------|
| `filename` | string | IP address with `.rbls` extension |
| `content` | HTML | Rendered HTML of RBL check results |

### RBL Lookup Result

Return from `ConfigServer::RBLLookup::rbllookup()`.

| Field | Type | Values |
|-------|------|--------|
| `$rblhit` | string | Empty (not listed), `"timeout"`, or IP response |
| `$rbltxt` | string | Descriptive text from RBL |

## State Transitions

### IP Check Flow

```text
[Server IPs] → _getethdev() → [%ips hash]
     ↓
[For each IP]
     ↓
[Net::IP->iptype()] → "PUBLIC" / "PRIVATE" / etc.
     ↓
[If PUBLIC + cache exists] → Output cached HTML
     ↓
[If PUBLIC + no cache + verbose] → Check all RBLs → Cache result
     ↓
[If PUBLIC + no cache + !verbose] → Output "Not Checked"
     ↓
[If !PUBLIC + verbose==2] → Output "Skipping"
```

## Validation Rules

### IP Address Validation

- Uses `ConfigServer::CheckIP::checkip()` for validation
- Only PUBLIC IP types (per Net::IP) are checked against RBLs
- IPv6 checking is commented out (not implemented)

### RBL Configuration Validation

- Lines starting with `#` are comments
- `Include` directive loads additional files
- `enablerbl:` adds RBL to check list
- `disablerbl:` removes RBL from check list
- `enableip:` adds specific IP to check
- `disableip:` removes specific IP from check

## File Locations

| File | Purpose | Access |
|------|---------|--------|
| `/usr/local/csf/lib/csf.rbls` | Default RBL list | Read |
| `/etc/csf/csf.rblconf` | User RBL configuration | Read |
| `/var/lib/csf/{ip}.rbls` | Per-IP cache files | Read/Write |
