# Research: Modernize ConfigServer::Service.pm

**Date**: 2026-01-28  
**Status**: Complete

## Current Module Analysis

### File: `lib/ConfigServer/Service.pm`

**Lines**: ~110  
**Functions**: 6 (type, startlfd, stoplfd, restartlfd, statuslfd, printcmd)

### Current Issues

1. **Package-level config loading** (lines 29-30):
   ```perl
   my $config = ConfigServer::Config->loadconfig();
   my %config = $config->config();
   ```

2. **Package-level /proc access** (lines 32-38):
   ```perl
   open( my $IN, "<", "/proc/1/comm" );
   flock( $IN, LOCK_SH );
   my $sysinit = <$IN>;
   close($IN);
   chomp $sysinit;
   if ( $sysinit ne "systemd" ) { $sysinit = "init" }
   ```

3. **Hardcoded lib path** (line 24):
   ```perl
   use lib '/usr/local/csf/lib';
   ```

4. **Non-disabled imports** (lines 25-27):
   ```perl
   use Carp;
   use IPC::Open3;
   use Fcntl qw(:DEFAULT :flock);
   ```

5. **Exporter machinery** (lines 31-33):
   ```perl
   use Exporter qw(import);
   our @ISA       = qw(Exporter);
   our @EXPORT_OK = qw();
   ```

6. **Legacy comment markers**: `# start`, `# end`, `###...###`

7. **Perl 4 ampersand syntax** (line 55, etc.):
   ```perl
   &printcmd( $config{SYSTEMCTL}, "start",  "lfd.service" );
   ```

8. **`## no critic` directive** (line 20)

## Refactoring Strategy

### Init Type Detection

Create `_get_init_type()` with lazy initialization:

```perl
our $INIT_TYPE_FILE = '/proc/1/comm';  # Package variable for test isolation

sub _get_init_type {
    state $init_type;
    return $init_type if defined $init_type;

    my $proc_comm = $INIT_TYPE_FILE;
    if ( -r $proc_comm ) {
        my @lines = ConfigServer::Slurp::slurp($proc_comm);
        my $sysinit = $lines[0] // '';
        chomp $sysinit;
        $init_type = ( $sysinit eq 'systemd' ) ? 'systemd' : 'init';
    }
    else {
        $init_type = 'init';  # Safe default
    }

    return $init_type;
}

sub _reset_init_type {
    state $init_type;
    undef $init_type;
    return;
}
```

### Config Access

Replace package-level config hash with direct get_config() calls:

```perl
# Before
&printcmd( $config{SYSTEMCTL}, "start", "lfd.service" );

# After
my $systemctl = ConfigServer::Config->get_config('SYSTEMCTL');
_printcmd( $systemctl, "start", "lfd.service" );
```

### Fcntl Constants

Change to fully qualified names (though we won't need Fcntl after using Slurp):

```perl
# Before
use Fcntl qw(:DEFAULT :flock);
flock( $IN, LOCK_SH );

# After
# Fcntl not needed - using ConfigServer::Slurp instead
```

### IPC::Open3 Usage

Keep IPC::Open3 but disable imports:

```perl
# Before
use IPC::Open3;
my $pid = open3( $childin, $childout, $childout, @command );

# After
use IPC::Open3 ();
my $pid = IPC::Open3::open3( $childin, $childout, $childout, @command );
```

## Test Mocking Strategy

### Mocking Init Type Detection

Use package variable `$INIT_TYPE_FILE` to redirect file path in tests:

```perl
# In test file
local $ConfigServer::Service::INIT_TYPE_FILE = $test_file;
ConfigServer::Service::_reset_init_type();  # Clear cached value
my $type = ConfigServer::Service::type();
```

### Mocking Command Execution

Mock `_printcmd` or track calls via package variable:

```perl
our @EXECUTED_COMMANDS;

sub _printcmd {
    my @command = @_;
    push @EXECUTED_COMMANDS, \@command;
    
    my ( $childin, $childout );
    my $pid = IPC::Open3::open3( $childin, $childout, $childout, @command );
    while (<$childout>) { print $_ }
    waitpid( $pid, 0 );
    
    return;
}
```

Or mock at test level:

```perl
my @captured_commands;
my $mock = mock 'ConfigServer::Service' => (
    override => [
        _printcmd => sub {
            push @captured_commands, [@_];
            return;
        },
    ],
);
```

## Dependencies

### Required (will use)
- `cPstrict` - Modern Perl features
- `ConfigServer::Config ()` - Configuration access
- `ConfigServer::Slurp ()` - File reading
- `IPC::Open3 ()` - Command execution
- `Carp ()` - Warnings

### Removed (no longer needed)
- `use lib` - Hardcoded path
- `Exporter` - Not exporting anything
- `Fcntl` - Using Slurp instead of manual flock

## Test Coverage Plan

| Test Case | Description |
|-----------|-------------|
| Module loads | `use ConfigServer::Service ()` succeeds |
| Public API exists | can_ok for all 5 public functions |
| type() returns systemd | When /proc/1/comm contains "systemd" |
| type() returns init | When /proc/1/comm contains other value |
| type() caches result | Second call doesn't re-read file |
| startlfd() systemd path | Calls systemctl start/status |
| startlfd() init path | Calls /etc/init.d/lfd start |
| stoplfd() systemd path | Calls systemctl stop |
| stoplfd() init path | Calls /etc/init.d/lfd stop |
| restartlfd() systemd path | Calls systemctl restart/status |
| restartlfd() init path | Calls /etc/init.d/lfd restart |
| statuslfd() systemd path | Calls systemctl status |
| statuslfd() init path | Calls /etc/init.d/lfd status |
| statuslfd() returns 0 | Return value is 0 |
| _printcmd() execution | Executes command and captures output |
