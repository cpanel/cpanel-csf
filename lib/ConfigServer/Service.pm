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

=head1 NAME

ConfigServer::Service - LFD service management for systemd and init systems

=head1 SYNOPSIS

    use ConfigServer::Service ();

    # Get init system type
    my $type = ConfigServer::Service::type();

    # Start the lfd service
    ConfigServer::Service::startlfd();

    # Stop the lfd service
    ConfigServer::Service::stoplfd();

    # Restart the lfd service
    ConfigServer::Service::restartlfd();

    # Show lfd service status
    ConfigServer::Service::statuslfd();

=head1 DESCRIPTION

This module provides service management functions for the CSF lfd daemon,
supporting both systemd and traditional SysV init systems. It detects the
init system at runtime and executes the appropriate commands to start, stop,
restart, or check the status of lfd.

All configuration is accessed via ConfigServer::Config. The module is
designed for testability and does not perform any side effects at package load time.

=head1 FUNCTIONS

The following public functions provide the primary interface to this module.
See the corresponding C<=head2> entries below for full details:

=over 4

=item * L</type>

Detect and return the type of init system in use (e.g. C<systemd> or C<init>).

=item * L</startlfd>

Start the C<lfd> service using the appropriate init mechanism.

=item * L</stoplfd>

Stop the C<lfd> service.

=item * L</restartlfd>

Restart the C<lfd> service.

=item * L</statuslfd>

Display the current status of the C<lfd> service.

=back

=head1 CONFIGURATION

The following configuration value is used:

=over 4

=item * SYSTEMCTL - Path to the systemctl binary (required for systemd)

=back

=head1 SEE ALSO

L<ConfigServer::Config>, L<ConfigServer::Slurp>, L<IPC::Open3>

=cut

package ConfigServer::Service;

use cPstrict;

use Carp                 ();
use IPC::Open3           ();
use ConfigServer::Config ();
use ConfigServer::Slurp  ();

our $VERSION        = 1.02;
our $INIT_TYPE_FILE = '/proc/1/comm';

our $_init_type_cache;

sub _get_init_type {
    return $_init_type_cache if length( $_init_type_cache // '' );

    my $proc_comm = $INIT_TYPE_FILE;
    if ( -r $proc_comm ) {
        my @lines   = ConfigServer::Slurp::slurp($proc_comm);
        my $sysinit = $lines[0] // '';
        chomp $sysinit;
        $_init_type_cache = ( $sysinit eq 'systemd' ) ? 'systemd' : 'init';
    }
    else {
        $_init_type_cache = 'init';
    }

    return $_init_type_cache;
}

sub _reset_init_type {
    undef $_init_type_cache;
    return;
}

=head2 type

    my $type = ConfigServer::Service::type();

Returns the init system type: 'systemd' or 'init'.

=cut

sub type {
    return _get_init_type();
}

=head2 startlfd

    ConfigServer::Service::startlfd();

Starts the lfd service using the appropriate method for the detected init system.

=cut

sub startlfd {
    my $init = _get_init_type();
    if ( $init eq 'systemd' ) {
        my $systemctl = ConfigServer::Config->get_config('SYSTEMCTL') || 'systemctl';
        _printcmd( $systemctl, 'start',  'lfd.service' );
        _printcmd( $systemctl, 'status', 'lfd.service' );
    }
    else {
        _printcmd( '/etc/init.d/lfd', 'start' );
    }
    return;
}

=head2 stoplfd

    ConfigServer::Service::stoplfd();

Stops the lfd service using the appropriate method for the detected init system.

=cut

sub stoplfd {
    my $init = _get_init_type();
    if ( $init eq 'systemd' ) {
        my $systemctl = ConfigServer::Config->get_config('SYSTEMCTL') || 'systemctl';
        _printcmd( $systemctl, 'stop', 'lfd.service' );
    }
    else {
        _printcmd( '/etc/init.d/lfd', 'stop' );
    }
    return;
}

=head2 restartlfd

    ConfigServer::Service::restartlfd();

Restarts the lfd service using the appropriate method for the detected init system.

=cut

sub restartlfd {
    my $init = _get_init_type();
    if ( $init eq 'systemd' ) {
        my $systemctl = ConfigServer::Config->get_config('SYSTEMCTL') || 'systemctl';
        _printcmd( $systemctl, 'restart', 'lfd.service' );
        _printcmd( $systemctl, 'status',  'lfd.service' );
    }
    else {
        _printcmd( '/etc/init.d/lfd', 'restart' );
    }
    return;
}

=head2 statuslfd

    ConfigServer::Service::statuslfd();

Shows the status of the lfd service using the appropriate method for the detected init system. Returns 0.

=cut

sub statuslfd {
    my $init = _get_init_type();
    if ( $init eq 'systemd' ) {
        my $systemctl = ConfigServer::Config->get_config('SYSTEMCTL') || 'systemctl';
        _printcmd( $systemctl, 'status', 'lfd.service' );
    }
    else {
        _printcmd( '/etc/init.d/lfd', 'status' );
    }
    return 0;
}

sub _printcmd {
    my @command = @_;
    my ( $childin, $childout );
    my $pid = IPC::Open3::open3( $childin, $childout, $childout, @command );
    while (<$childout>) { print $_ }
    waitpid( $pid, 0 );
    return;
}

1;

=head1 VERSION

1.02

=head1 AUTHOR

Jonathan Michaelson <waytotheweb@gmail.com>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2006-2025 Jonathan Michaelson

This program is free software; you can redistribute it and/or modify it under
the terms of the GNU General Public License as published by the Free Software
Foundation; either version 3 of the License, or (at your option) any later
version.

This program is distributed in the hope that it will be useful, but WITHOUT
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
FOR A PARTICULAR PURPOSE. See the GNU General Public License for more
details.

You should have received a copy of the GNU General Public License along with
this program; if not, see <https://www.gnu.org/licenses>.
