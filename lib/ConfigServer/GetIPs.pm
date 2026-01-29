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

package ConfigServer::GetIPs;

=head1 NAME

ConfigServer::GetIPs - Hostname to IP address resolver for CSF

=head1 SYNOPSIS

    use ConfigServer::GetIPs qw(getips);

    # Resolve a hostname to IP addresses
    my @ips = getips('example.com');
    foreach my $ip (@ips) {
        print "IP: $ip\n";
    }

    # May return IPv4 and/or IPv6 addresses
    my @all_ips = getips('google.com');

=head1 DESCRIPTION

This module provides hostname-to-IP address resolution functionality for
CSF (ConfigServer Security & Firewall). It attempts to resolve hostnames
using the most appropriate method available on the system.

The module uses one of two resolution strategies:

=over 4

=item 1. B<host command> (preferred)

If the C<host> command is available and executable, it is used to perform
DNS lookups with a 5-second timeout per query and a 10-second overall alarm
timeout. This method supports both IPv4 and IPv6 address resolution.

=item 2. B<Perl Socket resolution> (fallback)

If the C<host> command is not available, the module falls back to Perl's
built-in socket functions. If the Socket6 module is available, it uses
C<getaddrinfo()> for full IPv4/IPv6 support. Otherwise, it uses
C<gethostbyname()> for IPv4-only resolution.

=back

=head1 FUNCTIONS

=cut

use cPstrict;

use Socket     ();
use IPC::Open3 ();

use ConfigServer::Config;

use Exporter qw(import);
our $VERSION   = 1.03;
our @ISA       = qw(Exporter);
our @EXPORT_OK = qw(getips);

=head2 getips

    my @ips = getips($hostname);

    my @ips = getips('www.example.com');
    my @ips = getips('ipv6.google.com');

Resolves a hostname to one or more IP addresses.

This function attempts to resolve the given hostname using the C<host>
command if available, or falls back to Perl's socket functions. It
supports both IPv4 and IPv6 address resolution depending on the
available system tools and Perl modules.

=head3 Parameters

=over 4

=item * C<$hostname> - String containing the hostname or FQDN to resolve

=back

=head3 Returns

A list of IP addresses (both IPv4 and IPv6) associated with the hostname.
Returns an empty list if the hostname cannot be resolved or if resolution
times out.

=over 4

=item * IPv4 addresses are returned in dotted-decimal notation (e.g., C<192.0.2.1>)

=item * IPv6 addresses are returned in standard notation (e.g., C<2001:db8::1>)

=back

=head3 Side Effects

=over 4

=item * May execute the C<host> command as a subprocess if available

=item * Sets and clears alarm signals with 10-second timeout

=item * May kill subprocess on timeout using signal 9

=item * May load Socket6 module dynamically via eval

=back

=head3 Errors

=over 4

=item * Returns empty list if hostname resolution fails

=item * Returns empty list if resolution times out after 10 seconds

=item * Does not die or throw exceptions - failures result in empty list

=back

=head3 Example

    use ConfigServer::GetIPs qw(getips);

    # Resolve hostname
    my @ips = getips('www.example.com');
    if (@ips) {
        print "Resolved to: " . join(", ", @ips) . "\n";
    } else {
        print "Could not resolve hostname\n";
    }

    # Check for both IPv4 and IPv6
    foreach my $ip (@ips) {
        if ($ip =~ /:/) {
            print "IPv6: $ip\n";
        } else {
            print "IPv4: $ip\n";
        }
    }

=cut

sub getips {
    my $hostname = shift;
    my @ips;

    my $host_bin = ConfigServer::Config->get_config('HOST');

    if ( -e $host_bin && -x _ ) {

        my $ipv4reg = ConfigServer::Config->ipv4reg;
        my $ipv6reg = ConfigServer::Config->ipv6reg;

        my $cmdpid;
        eval {
            local $SIG{__DIE__} = undef;
            local $SIG{'ALRM'}  = sub { die };
            alarm(10);
            my ( $childin, $childout );
            $cmdpid = IPC::Open3::open3( $childin, $childout, $childout, $host_bin, "-W", "5", $hostname );
            close $childin;
            my @results = <$childout>;
            waitpid( $cmdpid, 0 );
            chomp @results;

            foreach my $line (@results) {
                if ( $line =~ /($ipv4reg|$ipv6reg)/ ) { push @ips, $1 }
            }
            alarm(0);
        };
        alarm(0);
        if ( $cmdpid =~ /\d+/ and $cmdpid > 1 and kill( 0, $cmdpid ) ) { kill( 9, $cmdpid ) }
    }
    else {
        local $SIG{__DIE__} = undef;
        eval('use Socket6;');    ## no critic (BuiltinFunctions::ProhibitStringyEval)
        if ($@) {
            my @iplist;
            my ( undef, undef, undef, undef, @addrs ) = Socket::gethostbyname($hostname);
            foreach (@addrs) { push( @iplist, join( ".", unpack( "C4", $_ ) ) ) }
            push @ips, $_ foreach (@iplist);
        }
        else {
            ## no critic (BuiltinFunctions::ProhibitStringyEval)
            eval( '
				use Socket6;
				my @res = Socket6::getaddrinfo($hostname, undef, Socket6::AF_UNSPEC, Socket6::SOCK_STREAM);
				while(scalar(@res)>=5){
					my $saddr;
					(undef, undef, undef, $saddr, undef, @res) = @res;
					my ($host, undef) = Socket6::getnameinfo($saddr, Socket6::NI_NUMERICHOST | Socket6::NI_NUMERICSERV);
					push @ips,$host;

				}
			' );
        }
    }

    return @ips;
}

=head1 VERSION

Version 1.03

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
