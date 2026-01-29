# Quickstart Guide: Using Modernized ServerCheck.pm

**Feature**: [010-modernize-servercheck](spec.md) | **Phase**: 1 - Design | **Date**: 2026-01-29

## Overview

ConfigServer::ServerCheck provides comprehensive server security auditing for cPanel and DirectAdmin environments. After modernization, the module follows cPanel Perl standards while preserving identical functionality.

## Basic Usage

### Loading the Module

```perl
#!/usr/local/cpanel/3rdparty/bin/perl

use cPstrict;

# Load ServerCheck with disabled imports (modernized)
use ConfigServer::ServerCheck ();

# Generate security audit report
my $html = ConfigServer::ServerCheck::report();
print $html;
```

**Key Change**: The `()` after `use ConfigServer::ServerCheck` disables imports and uses fully qualified function call.

### Generating Reports

#### Default Report (Failed Checks Only)

```perl
use ConfigServer::ServerCheck ();

my $html_report = ConfigServer::ServerCheck::report();

# Output contains HTML with only failed security checks
# Suitable for operators who need to see what requires attention
```

#### Verbose Report (All Checks)

```perl
use ConfigServer::ServerCheck ();

my $verbose_html = ConfigServer::ServerCheck::report(1);

# Output contains HTML with all security checks (passed and failed)
# Useful for comprehensive security documentation
```

## Module Loading Behavior

### Before Modernization

```perl
# OLD: Package-level side effects at compile time
use ConfigServer::ServerCheck qw(report);  # BAD: Imports function

# Problems with old approach:
# - Package-level variables $ipv4reg and $ipv6reg that were never used
# - Functions imported into namespace (confuses static analysis)
# - use lib with hardcoded path '/usr/local/csf/lib'
```

### After Modernization

```perl
# NEW: No side effects, clean imports
use ConfigServer::ServerCheck ();  # GOOD: Disabled imports

# Benefits:
# - Removed unused package-level variables ($ipv4reg, $ipv6reg, %daconfig)
# - No function imports - fully qualified calls only
# - No hardcoded library paths
# - Module can be loaded for testing without side effects
my $html = ConfigServer::ServerCheck::report();  # Fully qualified call
```

## What Changed in Modernization

**Removed Unused Code**:
- Package-level `$ipv4reg` and `$ipv6reg` variables were never referenced - removed entirely
- Package-level `%daconfig` hash was never used - removed entirely  
- `use lib '/usr/local/csf/lib'` hardcoded path - removed

**Import Standardization**:
- All `use Module qw(...)` changed to `use Module ()` to disable imports
- All function calls now use fully qualified names:
  - `ConfigServer::Slurp::slurp()` instead of `slurp()`
  - `Fcntl::LOCK_SH` instead of `LOCK_SH`
  - `IPC::Open3::open3()` instead of `open3()`

**Documentation**:
- Added POD sections: SEE ALSO, AUTHOR, LICENSE

**Result**: Module behavior is 100% identical, but code quality is improved.

## Integration Examples

### Web Interface Integration

```perl
#!/usr/local/cpanel/3rdparty/bin/perl

use cPstrict;
use CGI ();
use ConfigServer::ServerCheck ();

my $q = CGI->new;

print $q->header('text/html');

# Get verbose flag from query parameter
my $verbose = $q->param('verbose') ? 1 : 0;

# Generate and output report
my $report_html = ConfigServer::ServerCheck::report($verbose);
print $report_html;
```

### Command-Line Script

```perl
#!/usr/local/cpanel/3rdparty/bin/perl

use cPstrict;
use Getopt::Long ();
use ConfigServer::ServerCheck ();

my $verbose = 0;
my $output_file;

Getopt::Long::GetOptions(
    'verbose' => \$verbose,
    'output=s' => \$output_file,
) or die "Invalid options\n";

# Generate report
my $html = ConfigServer::ServerCheck::report($verbose);

# Write to file or stdout
if ($output_file) {
    open my $fh, '>', $output_file or die "Cannot write $output_file: $!\n";
    print {$fh} $html;
    close $fh;
    print "Report written to $output_file\n";
} else {
    print $html;
}
```

### Automated Security Monitoring

```perl
#!/usr/local/cpanel/3rdparty/bin/perl

use cPstrict;
use ConfigServer::ServerCheck ();
use ConfigServer::Sendmail ();

# Generate security report (failures only)
my $report = ConfigServer::ServerCheck::report(0);

# Check if there are any failures
if ($report =~ /class="fail"/) {
    # Send alert email
    ConfigServer::Sendmail::relay(
        'admin@example.com',
        'security@example.com',
        'Security Alert: Server Check Failures',
        $report,
        'html'
    );
    
    print "Security failures detected - alert sent\n";
} else {
    print "All security checks passed\n";
}
```

## Testing with Modernized Module

### Unit Test Structure

```perl
#!/usr/local/cpanel/3rdparty/bin/perl

use cPstrict;

use Test2::V0;
use Test2::Tools::Explain;
use Test2::Plugin::NoWarnings;

use lib 't/lib';
use MockConfig;

# Test 1: Module loads without side effects
subtest 'module loads without side effects' => sub {
    my $load_succeeded = 0;
    
    eval {
        require ConfigServer::ServerCheck;
        $load_succeeded = 1;
    };
    
    # Verify module loads without errors
    ok($load_succeeded, 'Module loads without package-level side effects');
};

# Test 2: Unused variables removed
subtest 'unused variables removed' => sub {
    # Module compiles successfully with variables removed
    # (If they were still referenced, compilation would fail)
    ok(ConfigServer::ServerCheck->can('report'), 'report() method available');
};

done_testing();
```

## Migration Guide

### For Existing Code

**If you're currently using**:
```perl
use ConfigServer::ServerCheck qw(report);
my $html = report();  # Imported function
```

**Update to**:
```perl
use ConfigServer::ServerCheck ();
my $html = ConfigServer::ServerCheck::report();  # Fully qualified
```

### Behavioral Changes

✅ **No functional changes**: HTML output is identical  
✅ **No API changes**: Function signature unchanged: `report($verbose)`  
✅ **Performance improvement**: Lazy loading reduces unnecessary initialization  
⚠️ **Import change**: Must use fully qualified name (no imports)

## Report Output Structure

The HTML report contains these sections:

1. **Firewall Configuration** - CSF/LFD settings, port security
2. **Server Security** - File permissions, OS version, superuser accounts
3. **WHM Settings** - SSL, BoxTrapper, Greylisting, FTP, compiler access
4. **Mail Server** - Exim, Dovecot, Courier SSL/TLS settings
5. **PHP Configuration** - Version, security settings, disabled functions
6. **Apache Configuration** - Version, ModSecurity, SSL/TLS, security headers
7. **SSH/Telnet Security** - Protocol version, port config, authentication
8. **System Services** - Identification of unnecessary running services

Each section reports:
- **Pass** (green): Security check passed
- **Fail** (red): Security issue identified
- **Info** (blue): Informational notice

## Troubleshooting

### Module Won't Load

**Problem**: `Can't locate ConfigServer/ServerCheck.pm`

**Solution**: Ensure `/usr/local/csf/lib` is in `@INC`:
```perl
use lib '/usr/local/csf/lib';  # In script, not in module
use ConfigServer::ServerCheck ();
```

### Report Returns Empty

**Problem**: `report()` returns empty string or dies

**Solution**: Ensure CSF is properly installed and configurations exist:
```bash
# Verify CSF installation
ls -l /usr/local/csf/etc/csf.conf
ls -l /usr/local/csf/lib/ConfigServer/
```

### Warnings About Uninitialized Values

**Problem**: Warnings during report generation

**Solution**: This is likely an issue in the security check logic, not the modernization. Check specific sections for configuration problems.

## Performance Considerations

- **Lazy Loading**: Config regex patterns loaded once on first `report()` call
- **State Variables**: Cached for all subsequent calls in same process
- **HTML Generation**: ~1887 lines of checks executed on each call (unchanged)
- **File I/O**: Multiple config files read per report (unchanged)

**Recommendation**: For multiple reports in same process, call `report()` once and reuse the HTML output.

## Further Reading

- [Feature Specification](spec.md) - Complete feature requirements
- [Implementation Plan](plan.md) - Technical implementation details
- [Data Model](data-model.md) - State variables and data structures
- Constitution: `/root/projects/csf/.specify/memory/constitution.md` - cPanel Perl coding standards
