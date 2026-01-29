# Data Model: Sanity.pm Module State

**Date**: 2026-01-29  
**Feature**: 009-modernize-sanity

## Overview

ConfigServer::Sanity manages configuration validation state using two primary data structures that map configuration item names to their acceptable values and defaults. These structures are lazily loaded from `/usr/local/csf/lib/sanity.txt` on first use and cached for the lifetime of the process.

## State Variables

### %sanity (Hash)

**Purpose**: Maps configuration item names to their acceptable value specifications  
**Scope**: Function-scoped `state` variable in sanity()  
**Lifetime**: Persists across function calls within same process  
**Initialization**: Lazy-loaded on first call to sanity()  

**Structure**:
```perl
(
    'ITEM_NAME' => 'acceptable_value_spec',
    # Examples:
    'AT_ALERT'     => '0-3',        # Range: 0 to 3
    'AUTO_UPDATES' => '0|1',        # Discrete: 0 or 1
    'CC_LOOKUPS'   => '0-4',        # Range: 0 to 4
)
```

**Value Formats**:
- **Range**: `"min-max"` (e.g., `"0-100"`)
- **Discrete**: `"val1|val2|val3"` (e.g., `"0|1|2"`)
- **Mixed**: `"val1|min-max|val2"` (e.g., `"0|10-20|99"`)

---

### %sanitydefault (Hash)

**Purpose**: Maps configuration item names to their default values  
**Scope**: Function-scoped `state` variable in sanity()  
**Lifetime**: Persists across function calls within same process  
**Initialization**: Lazy-loaded on first call to sanity()  

**Structure**:
```perl
(
    'ITEM_NAME' => 'default_value',
    # Examples:
    'AT_ALERT'     => '2',
    'AUTO_UPDATES' => '1',
    'CC_LOOKUPS'   => '1',
    'CC6_LOOKUPS'  => undef,        # No default specified
)
```

**Notes**:
- Values are strings (even numeric values like `'2'`)
- May be `undef` if no default specified in sanity.txt

---

### $loaded (Scalar)

**Purpose**: Flag to track whether sanity.txt has been loaded  
**Scope**: Function-scoped `state` variable in sanity()  
**Lifetime**: Persists across function calls within same process  
**Values**: `1` (loaded) or `undef` (not yet loaded)  

**Usage**:
```perl
state $loaded;

if (!$loaded) {
    # Perform one-time initialization
    # Load sanity.txt, populate %sanity and %sanitydefault
    $loaded = 1;
}
```

---

## State Transitions

### Initial State (Module Load)
```
%sanity         = ()       # Empty hash
%sanitydefault  = ()       # Empty hash
$loaded         = undef    # Not yet loaded
```

### First Call to sanity()
```
Input: sanity('AT_ALERT', '5')

1. Check $loaded → undef, proceed to load
2. Open /usr/local/csf/lib/sanity.txt
3. Read all lines
4. Parse each line: split by '='
5. Populate %sanity and %sanitydefault
6. Check IPSET config value
7. If IPSET enabled: delete DENY_IP_LIMIT entries
8. Set $loaded = 1
9. Proceed with validation
```

### Subsequent Calls to sanity()
```
Input: sanity('AUTO_UPDATES', '0')

1. Check $loaded → 1, skip loading
2. Proceed directly to validation
```

---

## Entity Relationships

```
┌──────────────────────┐
│  sanity.txt file     │
│  (on filesystem)     │
└──────────┬───────────┘
           │ Loaded once on first call
           ▼
┌──────────────────────┐
│  %sanity hash        │◄─────┐
│  (in memory)         │      │ Used by
└──────────────────────┘      │
                              │
┌──────────────────────┐      │
│  %sanitydefault hash │◄─────┤
│  (in memory)         │      │
└──────────────────────┘      │
                              │
┌──────────────────────┐      │
│  sanity() function   │──────┘
│  (public API)        │
└──────────────────────┘
```

---

## Data Flow

### Loading Phase
```
sanity.txt file
    ↓ (read lines)
["AT_ALERT=0-3=2", "AUTO_UPDATES=0|1=1", ...]
    ↓ (split by '=')
[("AT_ALERT", "0-3", "2"), ("AUTO_UPDATES", "0|1", "1"), ...]
    ↓ (populate hashes)
%sanity        = { AT_ALERT => "0-3", AUTO_UPDATES => "0|1", ... }
%sanitydefault = { AT_ALERT => "2",   AUTO_UPDATES => "1",   ... }
    ↓ (apply IPSET filter)
if (IPSET enabled):
    delete %sanity{DENY_IP_LIMIT}
    delete %sanitydefault{DENY_IP_LIMIT}
```

### Validation Phase
```
sanity('AT_ALERT', '5')
    ↓ (lookup in %sanity)
acceptable_spec = "0-3"
    ↓ (split by '|')
["0-3"]
    ↓ (check each part)
"0-3" contains '-' → range check
    ↓ (parse range)
from=0, to=3
    ↓ (compare)
5 >= 0 AND 5 <= 3? → FALSE
    ↓ (result)
$insane = 1 (validation failed)
    ↓ (return)
(1, "0 or 3", "2")
```

---

## File Format Specification

**Source**: `/usr/local/csf/lib/sanity.txt`

**Line Format**:
```
ITEM_NAME=acceptable_values=default_value
```

**Field Definitions**:

1. **ITEM_NAME**: Configuration item identifier
   - Case-sensitive
   - Must match key in csf.conf
   - Examples: `AT_ALERT`, `AUTO_UPDATES`, `DENY_IP_LIMIT`

2. **acceptable_values**: Validation specification
   - **Range format**: `min-max` (e.g., `0-100`)
   - **Discrete format**: `val1|val2|val3` (e.g., `0|1|2`)
   - **Mixed format**: Combine with `|` (e.g., `0|10-20|99`)

3. **default_value**: Recommended default (optional)
   - May be omitted (line ends after second `=`)
   - Should be valid according to acceptable_values

**Examples**:
```
AT_ALERT=0-3=2                    # Range with default
AUTO_UPDATES=0|1=1                # Discrete with default
CC6_LOOKUPS=0-1                   # Range without default
CT_LIMIT=0|1-1000=0               # Mixed (discrete 0, or range 1-1000), default 0
```

---

## Special Cases

### IPSET Conditional Logic

When IPSET is enabled in configuration, DENY_IP_LIMIT validation is skipped.

**Implementation**:
```perl
my $ipset = ConfigServer::Config->get_config('IPSET');
if ($ipset) {
    delete $sanity{DENY_IP_LIMIT};
    delete $sanitydefault{DENY_IP_LIMIT};
}
```

**Rationale**: IPSET uses different data structures that don't have the same limits as traditional iptables rules.

---

### Undefined Sanity Items

If a configuration item is not defined in sanity.txt:

```perl
sanity('UNKNOWN_ITEM', '999')
    ↓
$sanity{UNKNOWN_ITEM} = undef
    ↓
Skip validation (not defined check)
    ↓
return (0, undef, undef)  # Considered sane (no validation rule)
```

---

## Validation Algorithm

```perl
Input: ($sanity_item, $sanity_value)

1. Strip whitespace from both inputs
2. Check if item exists in %sanity
3. If undefined: return (0, undef, undef) - considered sane
4. Set $insane = 1 (assume invalid until proven valid)
5. Split acceptable_spec by '|'
6. For each acceptable part:
   a. If contains '-': parse as range (from-to)
      - If $sanity_value >= from AND <= to: set $insane = 0
   b. Else: treat as exact match
      - If $sanity_value eq part: set $insane = 0
7. Replace '|' with ' or ' in acceptable_spec (for display)
8. Return ($insane, $acceptable_spec, $default_value)
```

**Return Values**:
- `$insane = 0`: Value passes validation
- `$insane = 1`: Value fails validation
- `$acceptable_spec`: Human-readable acceptable values (with '|' → ' or ')
- `$default_value`: Recommended default from sanity.txt

---

## Memory Lifecycle

### Process Lifetime
```
┌────────────────────────────────────────────────┐
│ Process Start (lfd.pl or csf command)          │
├────────────────────────────────────────────────┤
│ use ConfigServer::Sanity ();                   │
│   → Module compiles                            │
│   → No data loaded yet                         │
├────────────────────────────────────────────────┤
│ First call: sanity('AT_ALERT', '2')            │
│   → $loaded = undef                            │
│   → Load sanity.txt                            │
│   → Populate %sanity, %sanitydefault           │
│   → Set $loaded = 1                            │
│   → Perform validation                         │
├────────────────────────────────────────────────┤
│ Second call: sanity('AUTO_UPDATES', '1')       │
│   → $loaded = 1                                │
│   → Skip loading                               │
│   → Perform validation                         │
├────────────────────────────────────────────────┤
│ ... (many more calls, no reloading)            │
├────────────────────────────────────────────────┤
│ Process End                                    │
│   → State variables destroyed                  │
└────────────────────────────────────────────────┘
```

### Configuration Reload Consideration

**Current Behavior**: State persists for entire process lifetime, even if sanity.txt changes on disk

**Future Enhancement**: Could add `sanity_reload()` function to force re-reading:
```perl
sub sanity_reload {
    state %sanity;
    state %sanitydefault;
    state $loaded;
    
    # Clear existing data
    %sanity = ();
    %sanitydefault = ();
    $loaded = undef;
    
    # Next sanity() call will reload
}
```

*Note: Not implementing in this feature; would require spec amendment*

---

## Dependencies

### Required Modules
- `Fcntl` - For file locking (`Fcntl::LOCK_SH`)
- `ConfigServer::Config` - For reading IPSET configuration value
- `Carp` - For error reporting (if file operations fail)

### File Dependencies
- `/usr/local/csf/lib/sanity.txt` - Validation rule definitions
- `/usr/local/csf/etc/csf.conf` - Configuration file (accessed via ConfigServer::Config)

---

## Testing Considerations

### State Isolation in Tests

**Challenge**: `state` variables persist across test cases

**Solution**: Each test must use a fresh Perl process OR clear state between tests

**Recommendation**: 
```perl
# Use done_testing() and restart prove for each test file
# OR use subtest isolation:

subtest 'First scenario' => sub {
    # Fresh module load within subtest fork
};

subtest 'Second scenario' => sub {
    # State persists from previous subtest
    # Need to account for this
};
```

### Mock Data Injection

**Option 1**: Pre-populate state before module uses it
```perl
# Not possible - state variables are lexical to function
```

**Option 2**: Mock file operations
```perl
# Mock the file read to return test data
my $slurp_mock = mock 'ConfigServer::Slurp' => (
    override => [
        slurp => sub {
            return ('AT_ALERT=0-3=2', 'AUTO_UPDATES=0|1=1');
        },
    ],
);
```

**Option 3**: Create test sanity.txt in tmp/
```perl
# Write test data to tmp/sanity-test.txt
# BUT: Module hardcodes path to /usr/local/csf/lib/sanity.txt
# Would need configurable path (not in current spec)
```

**Chosen Approach**: Mock file operations using Test2::Mock

