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
## no critic (RequireUseWarnings, ProhibitExplicitReturnUndef, ProhibitMixedBooleanOperators, RequireBriefOpen)

package ConfigServer::KillSSH;

=head1 NAME

ConfigServer::KillSSH - Terminate SSH connections from blocked IP addresses

=head1 SYNOPSIS

    use ConfigServer::KillSSH;

    # Kill all SSH connections from a blocked IP on specific ports
    ConfigServer::KillSSH::find('192.0.2.100', '22,2222');

    # Kill SSH connections from an IPv6 address
    ConfigServer::KillSSH::find('2001:db8::1', '22');

=head1 DESCRIPTION

This module provides functionality to forcibly terminate active SSH daemon
(sshd) processes that are connected to a blocked IP address. It is used by
CSF's process tracking feature (PT_SSHDKILL) to ensure that SSH connections
from banned IPs are immediately dropped.

The module works by:

=over 4

=item 1. Reading network connection data from C</proc/net/tcp> and C</proc/net/tcp6>

=item 2. Identifying socket inodes for connections from the specified IP address

=item 3. Scanning all running processes to find sshd processes using those sockets

=item 4. Sending SIGKILL (9) to matching sshd processes

=back

This ensures that SSH sessions from blocked IPs are terminated immediately,
preventing continued access even if the IP has been added to the firewall
deny list.

=head1 FUNCTIONS

=cut

use strict;
use warnings;

use Fcntl                ();
use ConfigServer::Logger ();

our $VERSION = 1.00;

=head2 find

    ConfigServer::KillSSH::find($ip, $ports);

    ConfigServer::KillSSH::find('192.168.1.100', '22');
    ConfigServer::KillSSH::find('10.0.0.5', '22,2222,22022');

Finds and terminates all SSH daemon processes connected to the specified
IP address on the given ports.

This function reads the system's network connection table from C</proc/net>,
identifies active connections from the specified IP to the specified ports,
determines which processes are handling those connections, and sends SIGKILL
to any sshd processes found.

=head3 Parameters

=over 4

=item * C<$ip> - IP address (IPv4 or IPv6) to search for. Can be in dotted-decimal
notation for IPv4 (e.g., C<192.168.1.1>) or standard notation for IPv6
(e.g., C<2001:db8::1>).

=item * C<$ports> - Comma-separated list of port numbers to match (e.g., C<22> or
C<22,2222,22022>). Only connections to these source ports will be considered.

=back

=head3 Returns

None. This function always returns undef.

=head3 Side Effects

=over 4

=item * Reads C</proc/net/tcp> and C</proc/net/tcp6> to enumerate network connections

=item * Iterates through all processes in C</proc> to find file descriptors

=item * Sends SIGKILL (signal 9) to matching sshd processes

=item * Logs termination events via C<ConfigServer::Logger::logfile()>

=back

=head3 Errors

=over 4

=item * Returns immediately without action if C<$ip> or C<$ports> is empty

=item * Silently skips processes that cannot be accessed (permission denied)

=item * Does not throw exceptions - failures are silent

=back

=head3 Example

    use ConfigServer::KillSSH;

    # Block an IP and kill its SSH connections
    my $blocked_ip = '203.0.113.50';
    my $ssh_ports = '22,2222';
    
    ConfigServer::KillSSH::find($blocked_ip, $ssh_ports);
    # Any sshd processes connected from that IP will be terminated

=cut

sub find {
    my $ip    = shift;
    my $ports = shift;

    my %inodes;

    if ( $ports eq "" or $ip eq "" ) { return }

    foreach my $proto ( "tcp", "tcp6" ) {
        open( my $IN, "<", "/proc/net/$proto" );
        flock( $IN, Fcntl::LOCK_SH );
        while (<$IN>) {
            my @rec = split();
            if ( $rec[9] =~ /uid/ ) { next }

            my ( $dip, $dport ) = split( /:/, $rec[2] );
            $dport = hex($dport);

            my ( $sip, $sport ) = split( /:/, $rec[1] );
            $sport = hex($sport);

            $dip = hex2ip($dip);
            $sip = hex2ip($sip);

            if ( $sip eq '0.0.0.1' ) { next }
            if ( $dip eq $ip ) {
                foreach my $port ( split( /\,/, $ports ) ) {
                    if ( $port eq $sport ) {
                        $inodes{ $rec[9] } = 1;
                    }
                }
            }
        }
        close($IN);
    }

    opendir( my $PROCDIR, "/proc" );
    while ( my $pid = readdir($PROCDIR) ) {
        if ( $pid !~ /^\d+$/ ) { next }
        opendir( DIR, "/proc/$pid/fd" ) or next;
        while ( my $file = readdir(DIR) ) {
            if ( $file =~ /^\./ ) { next }
            my $fd = readlink("/proc/$pid/fd/$file");
            if ( $fd =~ /^socket:\[?([0-9]+)\]?$/ ) {
                if ( $inodes{$1} and readlink("/proc/$pid/exe") =~ /sshd/ ) {
                    kill( 9, $pid );
                    ConfigServer::Logger::logfile("*PT_SSHDKILL*: Process PID:[$pid] killed for blocked IP:[$ip]");
                }
            }
        }
        closedir(DIR);
    }
    closedir($PROCDIR);
    return;
}

=head2 hex2ip

    my $ip = hex2ip($hex_string);

    my $ipv4 = hex2ip('0100007F');  # Returns '127.0.0.1'
    my $ipv6 = hex2ip('00000000000000000000000001000000'); # Returns IPv6

Converts hexadecimal IP address representation from C</proc/net/tcp> and
C</proc/net/tcp6> to standard IP address notation.

This is an internal utility function that handles the hex-encoded IP
addresses found in Linux's C</proc/net> files, which store addresses in
network byte order as hexadecimal strings.

=head3 Parameters

=over 4

=item * C<$hex_string> - Hexadecimal string representation of an IP address.
For IPv4, this is 8 hex characters. For IPv6, this is 32 hex characters.

=back

=head3 Returns

A string containing the IP address in standard notation:

=over 4

=item * IPv4 addresses are returned in dotted-decimal format (e.g., C<192.168.1.1>)

=item * IPv6 addresses are returned in colon-separated hexadecimal format
(e.g., C<2001:db8::1>)

=back

=head3 Side Effects

None.

=head3 Errors

Returns C<undef> if the input doesn't match expected IPv4 or IPv6 format.

=head3 Example

    # IPv4 conversion
    my $ipv4 = hex2ip('0100007F');
    # Returns: '127.0.0.1'

    # IPv6 conversion
    my $ipv6 = hex2ip('20010DB8000000000000000000000001');
    # Returns: '2001:db8::1' (formatted)

=cut

sub hex2ip {
    my $bin = pack "C*" => map hex, $_[0] =~ /../g;
    my @l   = unpack "L*", $bin;
    if ( @l == 4 ) {
        return join ':', map { sprintf "%x:%x", $_ >> 16, $_ & 0xffff } @l;
    }
    elsif ( @l == 1 ) {
        return join '.', map { $_ >> 24, ( $_ >> 16 ) & 0xff, ( $_ >> 8 ) & 0xff, $_ & 0xff } @l;
    }
}

=head1 VERSION

Version 1.00

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
