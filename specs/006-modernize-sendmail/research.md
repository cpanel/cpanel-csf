# Research: Modernize ConfigServer::Sendmail.pm

**Branch**: `006-modernize-sendmail` | **Date**: 2026-01-28

## Overview

Research findings for modernizing `ConfigServer::Sendmail` module, focusing on mocking strategies for testing, package-level variable refactoring, and Net::SMTP/sendmail binary handling.

---

## 1. Net::SMTP Mocking Strategy

### Decision
Use Test2::Mock to create a mock Net::SMTP object that records method calls.

### Rationale
- Test2::Mock is already available (used in other test files)
- Can intercept `Net::SMTP->new` constructor
- Mock object can track method calls for verification

### Implementation Pattern

```perl
use Test2::Tools::Mock qw(mock);

my @smtp_calls;
my $mock_smtp = mock 'Net::SMTP' => (
    override => [
        new => sub {
            my ($class, $host, %opts) = @_;
            push @smtp_calls, { method => 'new', args => [$host, %opts] };
            return bless {}, 'Net::SMTP';
        },
        mail => sub { push @smtp_calls, { method => 'mail', args => [@_] }; return 1; },
        to   => sub { push @smtp_calls, { method => 'to',   args => [@_] }; return 1; },
        data => sub { push @smtp_calls, { method => 'data', args => [@_] }; return 1; },
        datasend => sub { push @smtp_calls, { method => 'datasend', args => [@_] }; return 1; },
        dataend  => sub { push @smtp_calls, { method => 'dataend',  args => [@_] }; return 1; },
        quit     => sub { push @smtp_calls, { method => 'quit',     args => [@_] }; return 1; },
    ],
);
```

### Alternatives Considered
- **Sub::Override**: Simpler but less integrated with Test2
- **Test::MockModule**: Heavier dependency, redundant with Test2::Mock
- **Manual package override**: Works but less maintainable

---

## 2. sendmail Binary Mocking Strategy

### Decision
Override the pipe open in `relay()` by mocking the `open` builtin or using a test helper that captures the command.

### Rationale
- Can't use CORE::GLOBAL::open easily (scope issues)
- Better to test via integration with a mock sendmail script
- Alternatively, refactor relay() to accept an optional command runner for testing

### Implementation Pattern (Option A - Mock open)

```perl
# In test file - capture pipe opens
my @pipe_commands;
{
    no warnings 'redefine';
    *ConfigServer::Sendmail::_run_sendmail = sub {
        my ($cmd, @message) = @_;
        push @pipe_commands, { cmd => $cmd, message => [@message] };
        return 1;
    };
}
```

### Implementation Pattern (Option B - Refactor)

Refactor relay() to use a helper function that can be mocked:

```perl
sub _run_sendmail ($sendmail, $from, @message) {
    my $pipe_cmd = "| $sendmail -f $from -oi -t";
    ## no critic (InputOutput::RequireBriefOpen)
    open my $mail, $pipe_cmd or do {
        Carp::carp("*Error* Cannot pipe to $pipe_cmd: $!");
        return;
    };
    print $mail @message;
    close $mail;
    return 1;
}
```

### Alternatives Considered
- **IPC::Run**: Too heavy for this use case
- **Capture::Tiny**: Captures STDOUT/STDERR but not pipe commands
- **Test file mock**: Simplest approach, chosen

---

## 3. Hostname Detection Refactoring

### Decision
Create `_get_hostname()` with Perl `state` variable for lazy initialization.

### Rationale
- `state` provides thread-safe lazy initialization
- Only reads /proc once, caches result
- Follows pattern used in other modernized modules

### Implementation

```perl
sub _get_hostname {
    state $hostname;
    return $hostname if defined $hostname;

    my $proc_hostname = '/proc/sys/kernel/hostname';
    if ( -e $proc_hostname ) {
        my @lines = ConfigServer::Slurp::slurp($proc_hostname);
        $hostname = $lines[0];
        chomp $hostname if defined $hostname;
    }

    $hostname //= 'unknown';
    return $hostname;
}
```

### Alternatives Considered
- **Sys::Hostname**: External module, may not work in chroot
- **`hostname` command**: Spawns process, slower
- **Manual open/flock/close**: More verbose, Slurp is simpler
- **Current approach (Slurp)**: Efficient, reuses existing utility

---

## 4. Timezone Handling Refactoring

### Decision
Create `_get_timezone()` with lazy initialization.

### Rationale
- Timezone offset could change during DST transition
- However, for email headers, consistency within a session is fine
- Caching acceptable for performance

### Implementation

```perl
sub _get_timezone {
    state $tz;
    return $tz if defined $tz;
    $tz = POSIX::strftime( "%z", localtime );
    return $tz;
}
```

### Alternatives Considered
- **Re-compute each call**: Correct but slower
- **Environment variable TZ**: Less reliable
- **Cache at first use**: Chosen - simple and efficient

---

## 5. Conditional Net::SMTP Loading

### Decision
Move `require Net::SMTP` inside `relay()`, only when SMTP path is taken.

### Rationale
- Avoids loading Net::SMTP when using sendmail binary
- Module may not be installed on all systems
- Matches original conditional loading behavior

### Implementation

```perl
sub relay {
    my ( $to, $from, @message ) = @_;
    
    if ( ConfigServer::Config->get_config('LF_ALERT_SMTP') ) {
        require Net::SMTP;
        # SMTP path...
    }
    else {
        # sendmail path...
    }
}
```

### Alternatives Considered
- **Keep at package level with eval**: Original approach, has side effects
- **Optional dependency declaration**: Overkill for this case
- **Move inside function**: Chosen - cleanest

---

## 6. ConfigServer::Slurp and POSIX Constants

### Decision
Use ConfigServer::Slurp for file reading (simpler than manual open/flock), and disabled imports with fully qualified function calls for POSIX.

### Implementation

```perl
use ConfigServer::Slurp ();    # For file reading
use POSIX ();                   # For strftime

# Usage:
my @lines = ConfigServer::Slurp::slurp($file);
POSIX::strftime( "%z", localtime );
```

### Note on Slurp
ConfigServer::Slurp provides a simple interface for reading files:
- Returns array of lines
- Handles file open/close automatically
- Already available in the codebase

---

## 7. Test Mock Configuration

### Decision
Use existing MockConfig.pm pattern from other test files.

### Implementation

```perl
use lib 't/lib';
use MockConfig qw(mock_config);

mock_config(
    LF_ALERT_SMTP  => '',           # Use sendmail path
    LF_ALERT_SMTP  => 'smtp.test',  # Use SMTP path
    LF_ALERT_TO    => 'test@example.com',
    LF_ALERT_FROM  => 'csf@example.com',
    SENDMAIL       => '/usr/sbin/sendmail',
    DEBUG          => 0,
);
```

---

## Summary of Key Decisions

| Topic | Decision | Rationale |
|-------|----------|-----------|
| Net::SMTP mocking | Test2::Mock | Already available, integrates with Test2 |
| sendmail mocking | Mock helper function | Simplest, avoids global overrides |
| Hostname | `_get_hostname()` with state | Lazy init, cached, thread-safe |
| Timezone | `_get_timezone()` with state | Lazy init, consistent within session |
| Net::SMTP loading | require inside relay() | No side effects, conditional loading |
| File reading | ConfigServer::Slurp | Simpler than manual open/flock/close |
| POSIX | Disabled imports, FQ calls | Follows constitution standards |
| Config mocking | MockConfig.pm | Consistent with other tests |
