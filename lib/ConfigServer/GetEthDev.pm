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

package ConfigServer::GetEthDev;

=head1 NAME

ConfigServer::GetEthDev - Network interface and IP address detector for CSF

=head1 SYNOPSIS

    use ConfigServer::GetEthDev;

    my $ethdev = ConfigServer::GetEthDev->new();

    # Check if network detection was successful
    if ( $ethdev->{status} == 0 ) {
        # Get network interfaces
        my %ifaces = $ethdev->ifaces();
        foreach my $iface (keys %ifaces) {
            print "Interface: $iface\n";
        }

        # Get IPv4 addresses
        my %ipv4 = $ethdev->ipv4();
        foreach my $ip (keys %ipv4) {
            print "IPv4: $ip\n";
        }

        # Get IPv6 addresses
        my %ipv6 = $ethdev->ipv6();
        foreach my $ip (keys %ipv6) {
            print "IPv6: $ip\n";
        }

        # Get broadcast addresses
        my %brd = $ethdev->brd();
        foreach my $ip (keys %brd) {
            print "Broadcast: $ip\n";
        }
    }

=head1 DESCRIPTION

This module detects network interfaces, IP addresses (both IPv4 and IPv6),
and broadcast addresses on the system. It uses either the C<ip> command
(preferred) or C<ifconfig> command to gather network information.

The module also handles cPanel NAT configurations by reading C</var/cpanel/cpnat>
to include external NAT IP addresses.

=head1 METHODS

=cut

use cPstrict;

use Fcntl      ();
use IPC::Open3 ();
use POSIX      ();

use ConfigServer::Config  ();
use ConfigServer::CheckIP qw(checkip);

our $VERSION = 1.01;

my ( %ifaces, %ipv4, %ipv6, %brd );

=head2 new

    my $ethdev = ConfigServer::GetEthDev->new();

Creates a new GetEthDev object and detects network configuration.

This constructor automatically detects all network interfaces, IPv4/IPv6
addresses, and broadcast addresses on the system using either the C<ip>
command or C<ifconfig> command (whichever is available).

=head3 Returns

A blessed hash reference containing:

=over 4

=item * C<status> - Integer status code: 0 for success, 1 if neither C<ip>
nor C<ifconfig> commands are available

=back

=head3 Side Effects

=over 4

=item * Executes C<ip -oneline addr> or C<ifconfig> to detect network configuration

=item * Populates internal hashes with detected interfaces and IP addresses

=item * Reads C</var/cpanel/cpnat> if it exists to include NAT IP addresses

=back

=head3 Errors

None - constructor always returns an object. Check C<< $ethdev->{status} >>
to determine if network detection was successful.

=cut

sub new {
    my $class = shift;
    my $self  = {};
    bless $self, $class;

    my $status;
    my $config  = ConfigServer::Config->loadconfig();
    my %config  = $config->config();
    my $ipv4reg = $config->ipv4reg;
    my $ipv6reg = $config->ipv6reg;
    $brd{"255.255.255.255"} = 1;
    POSIX::setlocale( POSIX::LC_ALL, "POSIX" );

    if ( length $config{IP} && -e $config{IP} ) {
        my ( $childin, $childout );
        my $pid      = IPC::Open3::open3( $childin, $childout, $childout, $config{IP}, "-oneline", "addr" );
        my @ifconfig = <$childout>;
        waitpid( $pid, 0 );
        chomp @ifconfig;

        foreach my $line (@ifconfig) {
            if ( $line =~ /^\d+:\s+([\w\.\-]+)/ ) {
                $ifaces{$1} = 1;
            }
            if ( $line =~ /inet.*?($ipv4reg)/ ) {
                my ( $ip, undef ) = split( /\//, $1 );
                if ( checkip( \$ip ) ) {
                    $ipv4{$ip} = 1;
                }
            }
            if ( $line =~ /brd\s+($ipv4reg)/ ) {
                my ( $ip, undef ) = split( /\//, $1 );
                if ( checkip( \$ip ) ) {
                    $brd{$ip} = 1;
                }
            }
            if ( $line =~ /inet6.*?($ipv6reg)/ ) {
                my ( $ip, undef ) = split( /\//, $1 );
                $ip .= "/128";
                if ( checkip( \$ip ) ) {
                    $ipv6{$ip} = 1;
                }
            }
        }
        $status = 0;
    }
    elsif ( length $config{IFCONFIG} && -e $config{IFCONFIG} ) {
        my ( $childin, $childout );
        my $pid      = IPC::Open3::open3( $childin, $childout, $childout, $config{IFCONFIG} );
        my @ifconfig = <$childout>;
        waitpid( $pid, 0 );
        chomp @ifconfig;

        foreach my $line (@ifconfig) {
            if ( $line =~ /^([\w\.\-]+)/ ) {
                $ifaces{$1} = 1;
            }
            if ( $line =~ /inet.*?($ipv4reg)/ ) {
                my ( $ip, undef ) = split( /\//, $1 );
                if ( checkip( \$ip ) ) {
                    $ipv4{$ip} = 1;
                }
            }
            if ( $line =~ /Bcast:($ipv4reg)/ ) {
                my ( $ip, undef ) = split( /\//, $1 );
                if ( checkip( \$ip ) ) {
                    $brd{$ip} = 1;
                }
            }
            if ( $line =~ /inet6.*?($ipv6reg)/ ) {
                my ( $ip, undef ) = split( /\//, $1 );
                $ip .= "/128";
                if ( checkip( \$ip ) ) {
                    $ipv6{$ip} = 1;
                }
            }
        }
        $status = 0;
    }
    else {
        $status = 1;
    }

    if ( -e "/var/cpanel/cpnat" ) {
        open( my $NAT, "<", "/var/cpanel/cpnat" );
        flock( $NAT, Fcntl::LOCK_SH );
        while ( my $line = <$NAT> ) {
            chomp $line;
            if ( $line =~ /^([#\n\r])/ ) { next }
            my ( $internal, $external ) = split( /\s+/, $line );
            if ( checkip( \$internal ) and checkip( \$external ) ) {
                $ipv4{$external} = 1;
            }
        }
        close($NAT);
    }

    $self->{status} = $status;
    return $self;
}

=head2 ifaces

    my %ifaces = $ethdev->ifaces();

Returns a hash of detected network interface names.

=head3 Returns

A hash where keys are interface names (e.g., C<eth0>, C<lo>, C<docker0>)
and values are C<1>. This is a presence hash - if an interface name is
a key in the hash, it exists on the system.

=head3 Side Effects

None.

=head3 Errors

None.

=cut

sub ifaces {
    return %ifaces;
}

=head2 ipv4

    my %ipv4 = $ethdev->ipv4();

Returns a hash of detected IPv4 addresses.

=head3 Returns

A hash where keys are IPv4 addresses (e.g., C<192.168.1.10>, C<10.0.0.5>)
and values are C<1>. This includes all IPv4 addresses assigned to any
network interface on the system, plus any external NAT addresses from
C</var/cpanel/cpnat> if present.

=head3 Side Effects

None.

=head3 Errors

None.

=cut

sub ipv4 {
    return %ipv4;
}

=head2 ipv6

    my %ipv6 = $ethdev->ipv6();

Returns a hash of detected IPv6 addresses.

=head3 Returns

A hash where keys are IPv6 addresses with /128 prefix (e.g.,
C<2001:db8::1/128>, C<fe80::1/128>) and values are C<1>. This includes
all IPv6 addresses assigned to any network interface on the system.

Note: All IPv6 addresses are normalized to include the C</128> prefix
to represent single host addresses.

=head3 Side Effects

None.

=head3 Errors

None.

=cut

sub ipv6 {
    return %ipv6;
}

=head2 brd

    my %brd = $ethdev->brd();

Returns a hash of detected broadcast addresses.

=head3 Returns

A hash where keys are broadcast IPv4 addresses (e.g., C<192.168.1.255>,
C<255.255.255.255>) and values are C<1>. This includes all broadcast
addresses detected on network interfaces.

The address C<255.255.255.255> is always included by default.

=head3 Side Effects

None.

=head3 Errors

None.

=cut

sub brd {
    return %brd;
}

=head1 VERSION

Version 1.01

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
