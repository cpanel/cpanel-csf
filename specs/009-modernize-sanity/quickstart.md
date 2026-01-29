# Quick Start: ConfigServer::Sanity Usage

**Date**: 2026-01-29  
**Feature**: 009-modernize-sanity  
**Audience**: Developers using ConfigServer::Sanity module

## Installation

No separate installation needed - ConfigServer::Sanity is part of the CSF distribution.

**Location**: `/usr/local/csf/lib/ConfigServer/Sanity.pm`  
**Data File**: `/usr/local/csf/lib/sanity.txt`

## Basic Usage

### Import the Module

```perl
use ConfigServer::Sanity ();
```

**Note**: Use `()` to disable imports (per cPanel Perl standards)

### Validate a Configuration Value

```perl
# Validate that AT_ALERT value is acceptable
my ($insane, $acceptable, $default) = ConfigServer::Sanity::sanity('AT_ALERT', '2');

if ($insane) {
    print "Invalid value! Acceptable values: $acceptable\n";
    print "Using default: $default\n";
} else {
    print "Value is valid!\n";
}
```

**Output**:
```
Value is valid!
```

### Handle Invalid Value

```perl
my ($insane, $acceptable, $default) = ConfigServer::Sanity::sanity('AT_ALERT', '99');

if ($insane) {
    print "Invalid value 99!\n";
    print "Acceptable values: $acceptable\n";     # "0 or 3"
    print "Recommended default: $default\n";       # "2"
}
```

**Output**:
```
Invalid value 99!
Acceptable values: 0 or 3
Recommended default: 2
```

## Common Patterns

### Validate with Default Fallback

```perl
my $value = $config{AT_ALERT};  # Get from configuration

my ($insane, $acceptable, $default) = ConfigServer::Sanity::sanity('AT_ALERT', $value);

if ($insane) {
    warn "Invalid AT_ALERT value '$value' (acceptable: $acceptable)\n";
    $value = $default;  # Use recommended default
}

# Proceed with validated $value
```

### Validate Multiple Configuration Items

```perl
my @items = qw(AT_ALERT AUTO_UPDATES CC_LOOKUPS CT_INTERVAL);
my @errors;

foreach my $item (@items) {
    my $value = $config{$item};
    my ($insane, $acceptable, $default) = ConfigServer::Sanity::sanity($item, $value);
    
    if ($insane) {
        push @errors, {
            item       => $item,
            value      => $value,
            acceptable => $acceptable,
            default    => $default,
        };
    }
}

if (@errors) {
    print "Configuration validation failed:\n";
    foreach my $err (@errors) {
        print "  $err->{item}: '$err->{value}' invalid (acceptable: $err->{acceptable})\n";
    }
}
```

### Skip Validation for Undefined Items

```perl
my ($insane, $acceptable, $default) = ConfigServer::Sanity::sanity('UNKNOWN_ITEM', '999');

# For items not in sanity.txt:
#   $insane    = 0     (considered sane, no validation rule)
#   $acceptable = undef
#   $default    = undef

if (!defined $acceptable) {
    print "No validation rule for UNKNOWN_ITEM - accepting any value\n";
}
```

## Validation Types

### Range Validation

Validates that a value falls within a numeric range.

**Example sanity.txt entry**:
```
AT_INTERVAL=10-3600=60
```

**Usage**:
```perl
# Valid: 10, 60, 100, 3600
ConfigServer::Sanity::sanity('AT_INTERVAL', '60');   # ($insane = 0)

# Invalid: 5, 9, 3601, 10000
ConfigServer::Sanity::sanity('AT_INTERVAL', '5');    # ($insane = 1)
```

### Discrete Value Validation

Validates that a value matches one of specific allowed values.

**Example sanity.txt entry**:
```
AUTO_UPDATES=0|1=1
```

**Usage**:
```perl
# Valid: exactly 0 or 1
ConfigServer::Sanity::sanity('AUTO_UPDATES', '0');   # ($insane = 0)
ConfigServer::Sanity::sanity('AUTO_UPDATES', '1');   # ($insane = 0)

# Invalid: anything else
ConfigServer::Sanity::sanity('AUTO_UPDATES', '2');   # ($insane = 1)
ConfigServer::Sanity::sanity('AUTO_UPDATES', 'yes'); # ($insane = 1)
```

### Mixed Validation

Combines ranges and discrete values.

**Example sanity.txt entry**:
```
CT_LIMIT=0|1-1000=0
```

**Usage**:
```perl
# Valid: exactly 0, OR anything from 1 to 1000
ConfigServer::Sanity::sanity('CT_LIMIT', '0');     # ($insane = 0)
ConfigServer::Sanity::sanity('CT_LIMIT', '1');     # ($insane = 0)
ConfigServer::Sanity::sanity('CT_LIMIT', '500');   # ($insane = 0)
ConfigServer::Sanity::sanity('CT_LIMIT', '1000');  # ($insane = 0)

# Invalid: negative, or > 1000 (except 0)
ConfigServer::Sanity::sanity('CT_LIMIT', '-1');    # ($insane = 1)
ConfigServer::Sanity::sanity('CT_LIMIT', '1001');  # ($insane = 1)
```

## Special Cases

### IPSET Configuration

When IPSET is enabled in csf.conf, DENY_IP_LIMIT validation is automatically skipped.

**Configuration**:
```
# /usr/local/csf/etc/csf.conf
IPSET = "1"
```

**Behavior**:
```perl
# IPSET enabled → DENY_IP_LIMIT validation skipped
my ($insane, $acceptable, $default) = ConfigServer::Sanity::sanity('DENY_IP_LIMIT', '99999');
# Returns: (0, undef, undef) - always considered valid
```

**Rationale**: IPSET uses different data structures without the same limits as traditional iptables.

### Items Without Defaults

Some sanity.txt entries don't specify a default value.

**Example sanity.txt entry**:
```
CC6_LOOKUPS=0-1
```

**Usage**:
```perl
my ($insane, $acceptable, $default) = ConfigServer::Sanity::sanity('CC6_LOOKUPS', '2');

# Returns:
#   $insane    = 1         (invalid)
#   $acceptable = "0 or 1" (acceptable range)
#   $default    = undef    (no default specified)

if ($insane && !defined $default) {
    print "No recommended default available for CC6_LOOKUPS\n";
}
```

## Complete Example: Configuration Validation Script

```perl
#!/usr/local/cpanel/3rdparty/bin/perl

use cPstrict;

use ConfigServer::Config ();
use ConfigServer::Sanity ();

# Load configuration
my $config = ConfigServer::Config->loadconfig();
my %config = $config->config();

# Define items to validate
my @validation_items = qw(
    AT_ALERT
    AT_INTERVAL
    AUTO_UPDATES
    CC_LOOKUPS
    CT_INTERVAL
    CT_LIMIT
);

my $errors = 0;

print "Validating CSF configuration...\n\n";

foreach my $item (@validation_items) {
    my $value = $config{$item};
    
    # Skip if item not configured
    next unless defined $value;
    
    my ($insane, $acceptable, $default) = ConfigServer::Sanity::sanity($item, $value);
    
    if ($insane) {
        $errors++;
        print "❌ $item = '$value' (INVALID)\n";
        print "   Acceptable: $acceptable\n";
        print "   Default: " . (defined $default ? $default : "N/A") . "\n\n";
    } else {
        print "✓ $item = '$value' (valid)\n";
    }
}

if ($errors) {
    print "\nValidation failed with $errors error(s)\n";
    exit 1;
} else {
    print "\nAll configuration values are valid!\n";
    exit 0;
}
```

**Sample Output**:
```
Validating CSF configuration...

✓ AT_ALERT = '2' (valid)
✓ AT_INTERVAL = '60' (valid)
✓ AUTO_UPDATES = '1' (valid)
❌ CC_LOOKUPS = '5' (INVALID)
   Acceptable: 0 or 4
   Default: 1

✓ CT_INTERVAL = '30' (valid)
✓ CT_LIMIT = '0' (valid)

Validation failed with 1 error(s)
```

## Performance Notes

### Lazy Loading

The module uses lazy loading - sanity.txt is **NOT** read when the module is loaded. Instead:

1. **First call** to `sanity()`: Reads and parses sanity.txt, caches data in memory
2. **Subsequent calls**: Use cached data, no file I/O

**Implication**: First validation is slightly slower (~few ms for file I/O), all subsequent validations are extremely fast (hash lookups).

### Process Lifetime

Cached data persists for the entire process lifetime:

- **Long-running daemon** (lfd.pl): Data loaded once at first validation, reused for hours/days
- **Short script** (csf commands): Data loaded once per execution, then discarded when script exits

### Configuration Changes

If sanity.txt is modified on disk while a process is running, changes will **NOT** be picked up until the process restarts.

**Mitigation**: Restart lfd after modifying sanity.txt:
```bash
csf -ra  # Restart LFD
```

## Troubleshooting

### Module Won't Load

**Symptom**:
```
Can't locate ConfigServer/Sanity.pm in @INC
```

**Solution**: Ensure `/usr/local/csf/lib` is in Perl's include path:
```perl
use lib '/usr/local/csf/lib';
use ConfigServer::Sanity ();
```

### Validation Always Returns "Sane"

**Symptom**: All values pass validation regardless of actual value

**Possible Causes**:
1. **Item not in sanity.txt**: Check that the item name matches exactly (case-sensitive)
2. **IPSET enabled**: If validating DENY_IP_LIMIT with IPSET=1, validation is skipped
3. **Typo in item name**: Double-check spelling

**Debug**:
```perl
my ($insane, $acceptable, $default) = ConfigServer::Sanity::sanity('AT_ALERT', '999');

if (!defined $acceptable) {
    print "No validation rule found for AT_ALERT - check sanity.txt\n";
}
```

### File Permission Errors

**Symptom**:
```
Can't open /usr/local/csf/lib/sanity.txt: Permission denied
```

**Solution**: Ensure the process has read permission on sanity.txt:
```bash
chmod 644 /usr/local/csf/lib/sanity.txt
```

## Further Reading

- **POD Documentation**: `perldoc ConfigServer::Sanity`
- **Source Code**: `/usr/local/csf/lib/ConfigServer/Sanity.pm`
- **Validation Rules**: `/usr/local/csf/lib/sanity.txt`
- **CSF Configuration**: `/usr/local/csf/etc/csf.conf`

## API Reference

### sanity($item, $value)

Validates a configuration value against acceptable range/values.

**Parameters**:
- `$item` (string): Configuration item name (e.g., 'AT_ALERT')
- `$value` (string): Value to validate

**Returns**: 3-element list
1. `$insane` (integer): 0 = valid, 1 = invalid
2. `$acceptable` (string|undef): Human-readable acceptable values ("0 or 3")
3. `$default` (string|undef): Recommended default value

**Example**:
```perl
my ($insane, $acceptable, $default) = ConfigServer::Sanity::sanity('AT_ALERT', '2');
```

---

**Questions?** See `perldoc ConfigServer::Sanity` for complete documentation.
