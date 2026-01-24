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

=head1 NAME

ConfigServer::Ports - Network port inspection and configuration utilities

=head1 SYNOPSIS

    use ConfigServer::Ports;

    # Get hash of listening ports with process information
    my %listening = ConfigServer::Ports::listening();

    # Get hash of configured open ports from CSF config
    my %open = ConfigServer::Ports::openports();

=head1 DESCRIPTION

This module provides utilities for inspecting network ports on Linux systems.
It reads from the /proc filesystem to determine which ports are listening and
which processes own them. It also reads CSF configuration to determine which
ports are configured as open.

=cut

package ConfigServer::Ports;

use cPstrict;

use Fcntl                ();
use ConfigServer::Config ();

our $VERSION = 1.02;

my %printable = ( ( map { chr($_), unpack( 'H2', chr($_) ) } ( 0 .. 255 ) ), "\\" => '\\', "\r" => 'r', "\n" => 'n', "\t" => 't', "\"" => '"' );
my %tcpstates = (
    "01" => "ESTABLISHED",
    "02" => "SYN_SENT",
    "03" => "SYN_RECV",
    "04" => "FIN_WAIT1",
    "05" => "FIN_WAIT2",
    "06" => "TIME_WAIT",
    "07" => "CLOSE",
    "08" => "CLOSE_WAIT",
    "09" => "LAST_ACK",
    "0A" => "LISTEN",
    "0B" => "CLOSING"
);

=head2 listening

    my %listen = ConfigServer::Ports::listening();

Reads /proc/net/tcp, /proc/net/udp, /proc/net/tcp6, and /proc/net/udp6 to
determine which ports are listening. For each listening port, retrieves
process information from /proc/<pid>.

=head3 Returns

A hash with the following structure:

    {
        protocol => {
            port => {
                pid => {
                    user => 'username',
                    exe  => '/path/to/executable',
                    cmd  => 'full command line',
                    conn => connection_count,
                },
            },
        },
    }

Where C<protocol> is 'tcp' or 'udp' (IPv6 ports are mapped to their IPv4
protocol equivalent).

=cut

sub listening {
    my %net;
    my %conn;
    my %listen;

    foreach my $proto ( "tcp", "udp", "tcp6", "udp6" ) {
        my $path = "/proc/net/$proto";
        open( my $IN, "<", $path ) or do {
            warn "Cannot open $path: $!" unless $proto =~ /6$/;    # IPv6 may not exist
            next;
        };
        flock( $IN, Fcntl::LOCK_SH );
        while (<$IN>) {
            my @rec = split();
            if ( $rec[9] =~ /uid/ ) { next }

            my ( $dip, $dport ) = split( /:/, $rec[1] );
            $dport = hex($dport);

            my ( $sip, $sport ) = split( /:/, $rec[2] );
            $sport = hex($sport);

            $dip = _hex2ip($dip);
            $sip = _hex2ip($sip);

            my $inode    = $rec[9];
            my $state    = $tcpstates{ $rec[3] };
            my $protocol = $proto;
            $protocol =~ s/6//;
            if ( $protocol eq "udp" and $state eq "CLOSE" ) { $state = "LISTEN" }

            if ( $state eq "ESTABLISHED" ) { $conn{$dport}{$protocol}++ }

            if ( $dip =~ /^127\./ )      { next }
            if ( $dip =~ /^0\.0\.0\.1/ ) { next }
            if ( $state eq "LISTEN" )    { $net{$inode}{$protocol} = $dport }
        }
        close($IN);
    }

    opendir( my $procdir, "/proc" ) or do {
        warn "Cannot open /proc: $!";
        return %listen;
    };
    while ( my $pid = readdir($procdir) ) {
        if ( $pid !~ /^\d+$/ ) { next }
        my $exe = readlink("/proc/$pid/exe") || "";
        my $cwd = readlink("/proc/$pid/cwd") || "";
        my $uid;
        my $user;

        if ( defined $exe ) { $exe =~ s/([\r\n\t\"\\\x00-\x1f\x7F-\xFF])/\\$printable{$1}/sg }
        open( my $CMDLINE, "<", "/proc/$pid/cmdline" );
        flock( $CMDLINE, Fcntl::LOCK_SH );
        my $cmdline = <$CMDLINE>;
        close($CMDLINE);
        if ( defined $cmdline ) {
            chomp $cmdline;
            $cmdline =~ s/\0$//g;
            $cmdline =~ s/\0/ /g;
            $cmdline =~ s/([\r\n\t\"\\\x00-\x1f\x7F-\xFF])/\\$printable{$1}/sg;
            $cmdline =~ s/\s+$//;
            $cmdline =~ s/^\s+//;
        }
        if ( $exe eq "" ) { next }
        my @fd;
        opendir( my $fddir, "/proc/$pid/fd" ) or next;
        while ( my $file = readdir($fddir) ) {
            if ( $file =~ /^\./ ) { next }
            push( @fd, readlink("/proc/$pid/fd/$file") );
        }
        closedir($fddir);
        open( my $STATUS, "<", "/proc/$pid/status" ) or next;
        flock( $STATUS, Fcntl::LOCK_SH );
        my @status = <$STATUS>;
        close($STATUS);
        chomp @status;
        foreach my $line (@status) {
            if ( $line =~ /^Uid:(.*)/ ) {
                my $uidline = $1;
                my @uids;
                foreach my $bit ( split( /\s/, $uidline ) ) {
                    if ( $bit =~ /^(\d*)$/ ) { push @uids, $1 }
                }
                $uid  = $uids[-1];
                $user = getpwuid($uid);
                if ( $user eq "" ) { $user = $uid }
            }
        }

        my $files;
        my $sockets;
        foreach my $file (@fd) {
            if ( $file =~ /^socket:\[?([0-9]+)\]?$/ ) {
                my $ino = $1;
                if ( $net{$ino} ) {
                    foreach my $protocol ( keys %{ $net{$ino} } ) {
                        $listen{$protocol}{ $net{$ino}{$protocol} }{$pid}{user} = $user;
                        $listen{$protocol}{ $net{$ino}{$protocol} }{$pid}{exe}  = $exe;
                        $listen{$protocol}{ $net{$ino}{$protocol} }{$pid}{cmd}  = $cmdline;
                        $listen{$protocol}{ $net{$ino}{$protocol} }{$pid}{conn} = $conn{ $net{$ino}{$protocol} }{$protocol} // "-";
                    }
                }
            }
        }

    }
    closedir($procdir);
    return %listen;
}

=head2 openports

    my %ports = ConfigServer::Ports::openports();

Reads CSF configuration (TCP_IN, TCP6_IN, UDP_IN, UDP6_IN) to determine
which ports are configured as open.

=head3 Returns

A hash with the following structure:

    {
        tcp   => { port => 1, ... },
        tcp6  => { port => 1, ... },
        udp   => { port => 1, ... },
        udp6  => { port => 1, ... },
    }

Port ranges (e.g., "1000:2000") are expanded to individual port entries.

=cut

sub openports {
    my %ports;

    my $tcp_in  = ConfigServer::Config->get_config('TCP_IN')  // '';
    my $tcp6_in = ConfigServer::Config->get_config('TCP6_IN') // '';
    my $udp_in  = ConfigServer::Config->get_config('UDP_IN')  // '';
    my $udp6_in = ConfigServer::Config->get_config('UDP6_IN') // '';

    $tcp_in =~ s/\s//g;
    foreach my $entry ( split( /,/, $tcp_in ) ) {
        if ( $entry =~ /^(\d+):(\d+)$/ ) {
            my $from = $1;
            my $to   = $2;
            for ( my $port = $from; $port < $to; $port++ ) {
                $ports{tcp}{$port} = 1;
            }
        }
        else {
            $ports{tcp}{$entry} = 1;
        }
    }
    $tcp6_in =~ s/\s//g;
    foreach my $entry ( split( /,/, $tcp6_in ) ) {
        if ( $entry =~ /^(\d+):(\d+)$/ ) {
            my $from = $1;
            my $to   = $2;
            for ( my $port = $from; $port < $to; $port++ ) {
                $ports{tcp6}{$port} = 1;
            }
        }
        else {
            $ports{tcp6}{$entry} = 1;
        }
    }
    $udp_in =~ s/\s//g;
    foreach my $entry ( split( /,/, $udp_in ) ) {
        if ( $entry =~ /^(\d+):(\d+)$/ ) {
            my $from = $1;
            my $to   = $2;
            for ( my $port = $from; $port < $to; $port++ ) {
                $ports{udp}{$port} = 1;
            }
        }
        else {
            $ports{udp}{$entry} = 1;
        }
    }
    $udp6_in =~ s/\s//g;
    foreach my $entry ( split( /,/, $udp6_in ) ) {
        if ( $entry =~ /^(\d+):(\d+)$/ ) {
            my $from = $1;
            my $to   = $2;
            for ( my $port = $from; $port < $to; $port++ ) {
                $ports{udp6}{$port} = 1;
            }
        }
        else {
            $ports{udp6}{$entry} = 1;
        }
    }
    return %ports;
}

sub _hex2ip {
    my ($hex) = @_;

    # Return empty string for invalid input
    return '' if !defined $hex || $hex eq '' || $hex !~ /^[0-9A-Fa-f]+$/;

    my $bin = pack "C*" => map { hex } $hex =~ /../g;
    my @l   = unpack "L*", $bin;

    if ( @l == 4 ) {
        return join ':', map { sprintf "%x:%x", $_ >> 16, $_ & 0xffff } @l;
    }
    elsif ( @l == 1 ) {
        return join '.', map { $_ >> 24, ( $_ >> 16 ) & 0xff, ( $_ >> 8 ) & 0xff, $_ & 0xff } @l;
    }

    return '';
}

=head1 VERSION

1.02

=head1 AUTHOR

Jonathan Michaelson

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2006-2025 Jonathan Michaelson

This program is free software; you can redistribute it and/or modify it under
the terms of the GNU General Public License as published by the Free Software
Foundation; either version 3 of the License, or (at your option) any later
version.

=cut

1;
