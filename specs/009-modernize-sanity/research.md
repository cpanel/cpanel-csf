# Research: Modernize Sanity.pm Module

**Date**: 2026-01-29  
**Feature**: 009-modernize-sanity

## Research Questions & Findings

### 1. Lazy-Loading Pattern from Modernized Modules

**Research Task**: Examine ConfigServer::Sendmail to extract lazy-loading pattern

**Findings**:
- **Pattern**: Use `state` variables to cache data on first access
- **Example** (from Sendmail.pm lines 120-128):
  ```perl
  sub _get_hostname {
      state $hostname;
      return $hostname if defined $hostname;
      
      # ... expensive operation (file read) ...
      $hostname = $lines[0];
      chomp $hostname if defined $hostname;
      
      $hostname //= 'unknown';
      return $hostname;
  }
  ```
- **Key Points**:
  - Check if `state` variable is already defined, return immediately if so
  - Perform expensive operation (file I/O) only on first call
  - Use `//=` for default fallback values
  - Store result in `state` variable for subsequent calls

**Decision**: Apply `state` variable pattern in sanity() function to cache %sanity and %sanitydefault hashes

---

### 2. Sanity.txt File Format & Validation Logic

**Research Task**: Analyze current Sanity.pm logic and sanity.txt format

**Current Implementation** (lines 36-45):
```perl
open( my $IN, "<", $sanityfile );
flock( $IN, LOCK_SH );
my @data = <$IN>;
close($IN);
chomp @data;
foreach my $line (@data) {
    my ( $name, $value, $def ) = split( /\=/, $line );
    $sanity{$name}        = $value;
    $sanitydefault{$name} = $def;
}
```

**Sanity.txt Format** (from /usr/local/csf/lib/sanity.txt):
```
ITEM_NAME=acceptable_values=default_value
```

**Examples**:
```
AT_ALERT=0-3=2                    # Range: 0 to 3, default 2
AUTO_UPDATES=0-1=1                # Discrete: 0 or 1, default 1
CC_LOOKUPS=0-4=1                  # Range: 0 to 4, default 1
CC6_LOOKUPS=0-1                   # Range without default
```

**Validation Logic** (lines 58-73):
- Split acceptable values by `|` (e.g., "0|1|2" or "0-100")
- For ranges (contains `-`): check if value is between min and max
- For discrete values: check if value matches exactly
- Returns tuple: `($insane, $acceptable_values, $default_value)`
  - `$insane = 0`: value is acceptable
  - `$insane = 1`: value violates sanity check

**Special Case** (lines 49-52):
```perl
if ( $config{IPSET} ) {
    delete $sanity{"DENY_IP_LIMIT"};
    delete $sanitydefault{"DENY_IP_LIMIT"};
}
```
When IPSET is enabled, DENY_IP_LIMIT validation is skipped.

**Decision**: 
- Preserve exact file format parsing logic
- Move file reading into lazy-load function
- Keep IPSET special handling but move to runtime
- Maintain current validation algorithm exactly

---

### 3. POD Documentation Structure

**Research Task**: Review POD in AbuseIP.pm and CheckIP.pm for template

**Common Pattern Across Both Modules**:

1. **Module-level POD** (after `package` declaration):
   ```
   =head1 NAME
   
   =head1 SYNOPSIS
   
   =head1 DESCRIPTION
   
   =cut
   ```

2. **Function-level POD** (immediately before each function):
   ```
   =head2 function_name
   
   Description
   
   B<Parameters:>
   
   B<Returns:>
   
   B<Examples:>
   
   =cut
   ```

3. **End-of-file POD** (after `__END__`):
   ```
   =head1 DEPENDENCIES
   
   =head1 FILES (if applicable)
   
   =head1 SEE ALSO
   
   =head1 AUTHOR
   
   =head1 COPYRIGHT
   
   =cut
   ```

**Decision**: Follow three-part POD structure:
- Part 1: Module overview after package declaration
- Part 2: Function docs before sanity() function
- Part 3: Supplementary docs after __END__

---

### 4. Test2::Mock Patterns for Filesystem Operations

**Research Task**: Examine existing tests for mocking patterns

**Pattern from ConfigServer-Sendmail.t** (lines 31-66):

```perl
# Mock Net::SMTP using Test2::Mock
my $smtp_mock = mock 'Net::SMTP' => (
    override => [
        new => sub {
            my ( $class, $host, %opts ) = @_;
            push @main::smtp_calls, { action => 'new', host => $host, opts => \%opts };
            return unless $main::mock_smtp_success;
            my $self = bless { host => $host }, $class;
            return $self;
        },
        # ... more method overrides ...
    ],
);
```

**Key Insights**:
- Use `mock()` from Test2::V0 to override module behavior
- Track calls in package-scoped arrays (e.g., `@main::smtp_calls`)
- Return mock objects or values based on test scenarios

**For File Operations**:
- Cannot easily mock `open()` builtin
- **Better approach**: Mock the module's internal data loading
- **Alternative**: Use Test2::Mock to override the lazy-loading function before first call

**Decision**: 
- Create test helper that pre-populates the `state` variables
- OR: Use `mock()` to override internal _load_sanity_data() helper function
- Avoid mocking Perl builtins (open, read, etc.)

---

### 5. MockConfig Usage Pattern

**Research Task**: Review MockConfig.pm and its usage in existing tests

**From ConfigServer-Sendmail.t** (lines 9-21):
```perl
use lib 't/lib';
use MockConfig;

# Now load the module under test
use ConfigServer::Sendmail ();

# Set required config values
set_config(
    LF_ALERT_TO   => 'admin@example.com',
    LF_ALERT_FROM => 'csf@example.com',
    LF_ALERT_SMTP => '',
    SENDMAIL      => '/usr/sbin/sendmail',
    DEBUG         => 0,
);
```

**Pattern**:
1. Load MockConfig BEFORE loading module under test
2. Call `set_config()` to define configuration values
3. Module under test will read mocked values via ConfigServer::Config

**For Sanity.pm Tests**:
```perl
use lib 't/lib';
use MockConfig;

# Load module under test
use ConfigServer::Sanity ();

# Set IPSET config to test conditional logic
set_config(
    IPSET => 0,  # or 1 to test IPSET handling
);
```

**Decision**: Follow established MockConfig pattern in all Sanity.pm tests

---

## Implementation Decisions Summary

### 1. Lazy-Loading Architecture

**Decision**: Implement lazy-loading using `state` variables  
**Rationale**: Matches ConfigServer::Sendmail pattern; well-tested approach  
**Implementation**:
```perl
sub sanity {
    state %sanity;
    state %sanitydefault;
    state $loaded;
    
    if (!$loaded) {
        # Load sanity.txt here
        # Apply IPSET logic here
        $loaded = 1;
    }
    
    # ... existing validation logic ...
}
```

---

### 2. File Format & Parsing

**Decision**: Preserve exact current parsing logic  
**Rationale**: Maintains backward compatibility with existing sanity.txt files  
**No Changes**: Split by `=`, handle ranges (`-`) and discrete values (`|`)

---

### 3. Exporter Removal

**Decision**: Remove all Exporter machinery, keep function name unchanged  
**Rationale**: FR-006 requires no Exporter; callers already use `ConfigServer::Sanity::sanity()`  
**Changes**:
- Remove `use Exporter qw(import);`
- Remove `@ISA`, `@EXPORT_OK`
- Keep function name `sanity` for backward compatibility

---

### 4. POD Structure

**Decision**: Use three-part POD structure matching AbuseIP.pm/CheckIP.pm  
**Rationale**: Consistency across all ConfigServer modules  
**Sections**:
1. NAME, SYNOPSIS, DESCRIPTION (module-level)
2. sanity() function docs with parameters, returns, examples
3. SANITY CHECK FILE FORMAT, DEPENDENCIES, FILES, SEE ALSO, AUTHOR, COPYRIGHT (after __END__)

---

### 5. Testing Strategy

**Decision**: Use MockConfig + Test2::Mock for comprehensive unit tests  
**Rationale**: Proven pattern from existing tests; isolated from filesystem  
**Approach**:
- Mock ConfigServer::Config using MockConfig
- Create helper to pre-populate sanity data OR mock internal loader
- Test scenarios:
  - Range validation (0-100)
  - Discrete validation (0|1|2)
  - Undefined sanity items
  - IPSET enabled/disabled
  - Missing/unreadable sanity.txt

---

### 6. Import Discipline

**Decision**: Disable all imports, use fully qualified names  
**Rationale**: Constitution III requires `use Module ();`  
**Changes**:
- `use Fcntl ();` instead of `use Fcntl qw(:DEFAULT :flock);`
- Use `Fcntl::LOCK_SH` instead of `LOCK_SH`
- `use ConfigServer::Config ();`
- `use Carp ();`

---

## Alternatives Considered

### Alternative 1: Keep Exporter for Backward Compatibility
**Rejected Because**: Constitution III explicitly forbids Exporter; callers already use fully qualified names

### Alternative 2: Load sanity.txt once at startup in daemon
**Rejected Because**: Would violate FR-001 (no compile-time I/O); testing would remain difficult

### Alternative 3: Use JSON for sanity.txt format
**Rejected Because**: Breaking change to existing deployments; unnecessary complexity

### Alternative 4: Mock `open()` builtin in tests
**Rejected Because**: Extremely fragile; better to mock at higher abstraction level

---

## Risk Assessment

### Low Risk
- ✅ POD addition: Pure documentation, no code changes
- ✅ Comment separator removal: Cosmetic cleanup
- ✅ Import discipline: Makes dependencies explicit without behavior change

### Medium Risk
- ⚠️ Lazy-loading refactor: Changes when files are read (compile → runtime)
  - **Mitigation**: Thorough testing with mocked filesystem
  - **Validation**: Manual test with actual sanity.txt file

### High Risk
- ❌ None identified - changes preserve existing validation logic exactly

---

## Next Steps (Phase 1)

1. Create data-model.md documenting state management
2. Generate quickstart.md with usage examples
3. No contracts/ needed (internal library module, not API)
4. Re-evaluate Constitution Check with design in place

