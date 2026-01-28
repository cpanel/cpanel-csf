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

ConfigServer::RBLLookup - Perform DNS-based Realtime Blackhole List (RBL) lookups

=head1 SYNOPSIS

    use ConfigServer::RBLLookup ();

    my ($rbl_hit, $rbl_text) = ConfigServer::RBLLookup::rbllookup(
        "192.0.2.1",
        "zen.spamhaus.org"
    );

    if ($rbl_hit) {
        if ($rbl_hit eq "timeout") {
            print "RBL lookup timed out\n";
        } else {
            print "IP is listed: $rbl_hit\n";
            print "Reason: $rbl_text\n" if $rbl_text;
        }
    } else {
        print "IP is not listed\n";
    }

=head1 DESCRIPTION

ConfigServer::RBLLookup provides functionality to check if an IP address is listed
in a DNS-based Realtime Blackhole List (RBL). RBLs are used to identify IP addresses
associated with spam, abuse, or other malicious activity.

The module performs two types of DNS queries:

=over 4

=item * A record lookup to check if the IP is listed

=item * TXT record lookup to retrieve the reason for listing

=back

The module supports both IPv4 and IPv6 addresses and includes timeout protection
to prevent hanging on slow DNS responses.

=head1 FUNCTIONS

=head2 rbllookup($ip, $rbl)

Performs an RBL lookup for the specified IP address against the given RBL server.

B<Parameters:>

=over 4

=item * C<$ip> - The IP address to check (IPv4 or IPv6)

=item * C<$rbl> - The RBL server domain (e.g., "zen.spamhaus.org")

=back

B<Returns:>

A list of two values:

=over 4

=item * C<$rbl_hit> - The RBL response IP address if listed, "timeout" if the query
timed out, or empty string if not listed

=item * C<$rbl_text> - The TXT record explanation if available, or undef

=back

B<Example:>

    my ($hit, $text) = ConfigServer::RBLLookup::rbllookup("1.2.3.4", "zen.spamhaus.org");

B<Notes:>

=over 4

=item * Invalid IP addresses return empty strings without performing DNS queries

=item * DNS queries have a 4-second timeout to prevent hanging

=item * The module uses the system's C<host> command for DNS lookups

=item * Requires ConfigServer::Config for the HOST binary path

=back

=head1 SEE ALSO

L<ConfigServer::RBLCheck>, L<ConfigServer::CheckIP>

=head1 LICENSE

This program is free software; you can redistribute it and/or modify it under
the terms of the GNU General Public License as published by the Free Software
Foundation; either version 3 of the License, or (at your option) any later
version.

=cut

package ConfigServer::RBLLookup;

use cPstrict;

use IPC::Open3 ();
use Net::IP    ();
use ConfigServer::Config;
use ConfigServer::CheckIP ();

our $VERSION = 1.01;

sub rbllookup ($ip, $rbl) {
    my %rblhits;
    my $netip;
    my $reversed_ip = '';
    my $timeout     = 4;
    my $rblhit      = '';
    my @rblhittxt;

    if ( ConfigServer::CheckIP::checkip( \$ip ) ) {
        eval {
            local $SIG{__DIE__} = undef;
            $netip       = Net::IP->new($ip);
            $reversed_ip = $netip->reverse_ip();
        };

        if ( $reversed_ip =~ /^(\S+)\.in-addr\.arpa/ )         { $reversed_ip = $1 }
        if ( $reversed_ip =~ /^(\S+)\s+(\S+)\.in-addr\.arpa/ ) { $reversed_ip = $2 }
        if ( $reversed_ip =~ /^(\S+)\.ip6\.arpa/ )             { $reversed_ip = $1 }
        if ( $reversed_ip =~ /^(\S+)\s+(\S+)\.ip6\.arpa/ )     { $reversed_ip = $2 }

        if ( $reversed_ip ne "" ) {
            my $lookup_ip = $reversed_ip . "." . $rbl;

            my $cmdpid;
            eval {
                local $SIG{__DIE__} = undef;
                local $SIG{'ALRM'}  = sub { die };
                alarm($timeout);
                my ( $childin, $childout );
                $cmdpid = IPC::Open3::open3( $childin, $childout, $childout, ConfigServer::Config->get_config('HOST'), "-t", "A", $lookup_ip );
                close $childin;
                my @results = <$childout>;
                waitpid( $cmdpid, 0 );
                chomp @results;
                my $ipv4reg = ConfigServer::Config->ipv4reg;
                my $ipv6reg = ConfigServer::Config->ipv6reg;
                if ( $results[0] && $results[0] =~ /^${reversed_ip}.+ ($ipv4reg|$ipv6reg)$/ ) { $rblhit = $1 }
                alarm(0);
            };
            alarm(0);
            if ($@)                                                                        { $rblhit = "timeout" }
            if ( length $cmdpid && $cmdpid =~ /\d+/ && $cmdpid > 1 && kill( 0, $cmdpid ) ) { kill( 9, $cmdpid ) }

            if ( $rblhit ne "" ) {
                if ( $rblhit ne "timeout" ) {
                    my $cmdpid;
                    eval {
                        local $SIG{__DIE__} = undef;
                        local $SIG{'ALRM'}  = sub { die };
                        alarm($timeout);
                        my ( $childin, $childout );
                        $cmdpid = IPC::Open3::open3( $childin, $childout, $childout, ConfigServer::Config->get_config('HOST'), "-t", "TXT", $lookup_ip );
                        close $childin;
                        my @results = <$childout>;
                        waitpid( $cmdpid, 0 );
                        chomp @results;

                        foreach my $line (@results) {
                            if ( $line =~ /^${reversed_ip}.+ "([^\"]+)"$/ ) {
                                push @rblhittxt, $1;
                            }
                        }
                        alarm(0);
                    };
                    alarm(0);
                    if ( length $cmdpid && $cmdpid =~ /\d+/ && $cmdpid > 1 && kill( 0, $cmdpid ) ) { kill( 9, $cmdpid ) }
                }
            }
        }
    }
    return ( $rblhit, @rblhittxt );
}

1;

=head1 VERSION

1.01

=head1 AUTHOR

Jonathan Michaelson

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2006-2025 Jonathan Michaelson

This program is free software; you can redistribute it and/or modify it under
the terms of the GNU General Public License as published by the Free Software
Foundation; either version 3 of the License, or (at your option) any later
version.

=cut
