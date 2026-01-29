###############################################################################
# Copyright (C) 2006-2025 Jonathan Michaelson
#
# https://github.com/waytotheweb/scripts
#
# This program is free software; you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation; either version 3 of the License, or (at your option) any later
# version.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. See the GNU General Public License for more
# details.
#
# You should have received a copy of the GNU General Public License along with
# this program; if not, see <https://www.gnu.org/licenses>.
###############################################################################

package ConfigServer::Logger;

=head1 NAME

ConfigServer::Logger - Logging facility for CSF/LFD

=head1 SYNOPSIS

    use ConfigServer::Logger qw(logfile);

    # Log a message
    logfile("Server started successfully");
    logfile("Failed login attempt from 192.168.1.100");

=head1 DESCRIPTION

This module provides logging functionality for the CSF (ConfigServer Security
& Firewall) and LFD (Login Failure Daemon) systems. It writes log messages
to local log files and optionally to syslog if configured.

Log messages are automatically timestamped and include the hostname and
process ID. The module handles file locking to ensure log integrity in
multi-process environments.

=head1 EXPORTS

This module uses L<Exporter> and can export the following functions on request:

=over 4

=item * C<logfile>

=back

=head1 FUNCTIONS

=cut

use cPstrict;

use Fcntl                ();
use ConfigServer::Config ();

use Exporter qw(import);
our $VERSION   = 1.02;
our @ISA       = qw(Exporter);
our @EXPORT_OK = qw(logfile);

=head2 logfile

    logfile($message);

Writes a log message to the appropriate log file and optionally to syslog.

=head3 Parameters

=over 4

=item * C<$message> - String containing the message to log

=back

=head3 Returns

None.

=head3 Behavior

The function writes log messages with the following format:

    Mon DD YYYY hostname lfd[PID]: message

Where:

=over 4

=item * C<Mon DD YYYY> - Timestamp in local time

=item * C<hostname> - Short hostname (first part before first dot)

=item * C<PID> - Process ID

=item * C<message> - The provided log message

=back

=head3 Log Files

=over 4

=item * C</var/log/lfd.log> - Used when running as root (UID 0)

=item * C</var/log/lfd_messenger.log> - Used when running as non-root user

=back

=head3 Syslog Support

If C<SYSLOG> is enabled in the CSF configuration and C<Sys::Syslog> is
available, messages are also sent to syslog with:

=over 4

=item * Facility: C<user>

=item * Level: C<info>

=item * Ident: C<lfd>

=back

=head3 Thread Safety

This function uses file locking (C<LOCK_EX>) to ensure safe concurrent
access to log files in multi-process environments.

=head3 Side Effects

=over 4

=item * Creates log file if it doesn't exist

=item * Appends to existing log file

=item * May write to syslog if configured

=back

=head3 Errors

None - the function does not throw exceptions. Syslog errors are silently
ignored if they occur.

=cut

our $logfile_path = $< == 0 ? "/var/log/lfd.log" : "/var/log/lfd_messenger.log";

sub logfile {
    my $line = shift;
    my @ts   = split( /\s+/, scalar localtime );
    if ( $ts[2] < 10 ) { $ts[2] = " " . $ts[2] }

    sysopen( my $LOGFILE, $logfile_path, Fcntl::O_WRONLY | Fcntl::O_APPEND | Fcntl::O_CREAT );
    flock( $LOGFILE, Fcntl::LOCK_EX );
    print $LOGFILE "$ts[1] $ts[2] $ts[3] " . _get_hostshort() . " lfd[$$]: $line\n";
    close($LOGFILE);

    if ( ConfigServer::Config->get_config('SYSLOG') ) {
        _syslog($line);
    }

    return;
}

our $_hostshort_cache;

sub _get_hostshort {
    return $_hostshort_cache if length $_hostshort_cache;

    my $hostname;
    if ( -e "/proc/sys/kernel/hostname" ) {
        open( my $IN, "<", "/proc/sys/kernel/hostname" );
        flock( $IN, Fcntl::LOCK_SH );
        $hostname = <$IN>;
        chomp $hostname;
        close($IN);
    }
    else {
        $hostname = "unknown";
    }
    return $_hostshort_cache = ( split( /\./, $hostname ) )[0];
}

my $loaded_syslog;

sub _syslog {
    my $line = shift;

    # Only require once in this path.
    if ( !$loaded_syslog ) {
        $loaded_syslog = require Sys::Syslog;
    }

    eval {
        local $SIG{__DIE__} = undef;
        Sys::Syslog::openlog( 'lfd', 'ndelay,pid', 'user' );
        Sys::Syslog::syslog( 'info', $line );
        Sys::Syslog::closelog();
    };

    return;
}

=head1 VERSION

Version 1.02

=head1 AUTHOR

Jonathan Michaelson

=head1 COPYRIGHT

Copyright (C) 2006-2025 Jonathan Michaelson

This program is free software; you can redistribute it and/or modify it under
the terms of the GNU General Public License as published by the Free Software
Foundation; either version 3 of the License, or (at your option) any later
version.

=cut

1;
