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

package ConfigServer::CheckIP;

=head1 NAME

ConfigServer::CheckIP - IP address validation and type detection

=head1 SYNOPSIS

    use ConfigServer::CheckIP qw(checkip cccheckip);

    # Check any IP address
    my $ip = "192.0.2.1";
    my $type = checkip(\$ip);
    if ($type == 4) {
        print "Valid IPv4 address\n";
    } elsif ($type == 6) {
        print "Valid IPv6 address (normalized to $ip)\n";
    }

    # Check only public IP addresses
    my $public_ip = "8.8.8.8";
    my $type = cccheckip(\$public_ip);
    if ($type) {
        print "Valid public IP address\n";
    }

=head1 DESCRIPTION

This module provides functions to validate IP addresses (both IPv4 and IPv6),
determine their type, and optionally normalize their format. It can distinguish
between valid IPs and filter out loopback or private addresses.

=cut

use cPstrict;

use Carp;
use Net::IP;
use ConfigServer::Config;

use Exporter qw(import);
our $VERSION   = 1.03;
our @ISA       = qw(Exporter);
our @EXPORT_OK = qw(checkip cccheckip);

my $ipv4reg = ConfigServer::Config->ipv4reg;
my $ipv6reg = ConfigServer::Config->ipv6reg;

=head2 checkip

Validates an IP address and determines if it is IPv4 or IPv6. Filters out
loopback addresses. For IPv6 addresses passed by reference, normalizes them
to short form.

=over 4

=item B<Parameters>

=over 4

=item * C<$ip> - IP address string or scalar reference. May include CIDR notation (e.g., "192.0.2.0/24")

=back

=item B<Returns>

=over 4

=item * C<0> - Invalid IP, loopback address, or invalid CIDR

=item * C<4> - Valid IPv4 address

=item * C<6> - Valid IPv6 address (normalized if passed by reference)

=back

=item B<Side Effects>

When passed a scalar reference containing an IPv6 address, modifies the
referenced value to the normalized short form.

=item B<Example>

    my $ip = "2001:0db8::1";
    my $type = checkip(\$ip);
    # $type = 6, $ip = "2001:db8::1" (normalized)

    my $invalid = checkip("127.0.0.1");
    # returns 0 (loopback filtered)

=back

=cut

sub checkip {
    my $ipin = shift;
    length $ipin or return 0;
    my $ret   = 0;
    my $ipref = 0;
    my $ip;
    my $cidr;
    if ( ref $ipin ) {
        length $$ipin or return;
        ( $ip, $cidr ) = split( /\//, ${$ipin} );
        $ipref = 1;
    }
    else {
        length $ipin or return;
        ( $ip, $cidr ) = split( /\//, $ipin );
    }
    my $testip = $ip;

    if ( length $cidr ) {
        return 0 unless $cidr =~ /^\d+$/;
    }

    if ( $ip =~ /^$ipv4reg$/ ) {
        $ret = 4;
        if ($cidr) {
            unless ( $cidr >= 1 && $cidr <= 32 ) { return 0 }
        }
        if ( $ip eq "127.0.0.1" ) { return 0 }
    }

    if ( $ip =~ /^$ipv6reg$/ ) {
        $ret = 6;
        if ($cidr) {
            unless ( $cidr >= 1 && $cidr <= 128 ) { return 0 }
        }
        $ip =~ s/://g;
        $ip =~ s/^0*//g;
        return 0 if $ip eq '1';    # Found a loopback address

        if ($ipref) {
            eval {
                local $SIG{__DIE__} = undef;
                my $netip = Net::IP->new($testip);
                my $myip  = $netip->short();
                if ( $myip ne "" ) {
                    unless ( length $cidr ) {
                        ${$ipin} = $myip;
                    }
                    else {
                        ${$ipin} = $myip . "/" . $cidr;
                    }
                }
            };
            if ($@) { return 0 }
        }
    }

    return $ret;
}

=head2 cccheckip

Validates an IP address and determines if it is a PUBLIC IPv4 or IPv6 address.
Filters out loopback and private/reserved addresses. For IPv6 addresses passed
by reference, normalizes them to short form.

=over 4

=item B<Parameters>

=over 4

=item * C<$ip> - IP address string or scalar reference. May include CIDR notation (e.g., "8.8.8.8/32")

=back

=item B<Returns>

=over 4

=item * C<0> - Invalid IP, non-public IP, loopback, or invalid CIDR

=item * C<4> - Valid public IPv4 address

=item * C<6> - Valid public IPv6 address (normalized if passed by reference)

=back

=item B<Side Effects>

When passed a scalar reference containing an IPv6 address, modifies the
referenced value to the normalized short form.

=item B<Example>

    my $ip = "8.8.8.8";
    my $type = cccheckip(\$ip);
    # $type = 4 (public IPv4)

    my $private = cccheckip("192.168.1.1");
    # returns 0 (private address filtered)

=back

=cut

sub cccheckip {
    my $ipin  = shift;
    my $ret   = 0;
    my $ipref = 0;
    my $ip;
    my $cidr;
    if ( ref $ipin ) {
        ( $ip, $cidr ) = split( /\//, ${$ipin} );
        $ipref = 1;
    }
    else {
        ( $ip, $cidr ) = split( /\//, $ipin );
    }
    my $testip = $ip;

    return 0 unless length $ip;
    return 0 if length $cidr and $cidr !~ /^\d+$/;

    if ( $ip =~ /^$ipv4reg$/ ) {
        $ret = 4;
        if ($cidr) {
            unless ( $cidr >= 1 && $cidr <= 32 ) { return 0 }
        }
        if ( $ip eq "127.0.0.1" ) { return 0 }
        my $type;
        eval {
            local $SIG{__DIE__} = undef;
            my $netip = Net::IP->new($testip);
            $type = $netip->iptype();
        };
        if ($@)                  { return 0 }
        if ( $type ne "PUBLIC" ) { return 0 }
    }

    if ( $ip =~ /^$ipv6reg$/ ) {
        $ret = 6;
        if ($cidr) {
            unless ( $cidr >= 1 && $cidr <= 128 ) { return 0 }
        }
        $ip =~ s/://g;
        $ip =~ s/^0*//g;
        return 0 if $ip eq '1';    # loopback found.

        if ($ipref) {
            eval {
                local $SIG{__DIE__} = undef;
                my $netip = Net::IP->new($testip);
                my $myip  = $netip->short();
                if ( $myip ne "" ) {
                    if ( !length $cidr ) {
                        ${$ipin} = $myip;
                    }
                    else {
                        ${$ipin} = $myip . "/" . $cidr;
                    }
                }
            };
            if ($@) { return 0 }
        }
    }

    return $ret;
}

1;

__END__

=head1 DEPENDENCIES

=over 4

=item * L<Net::IP> - For IP address manipulation, validation, and normalization

=item * L<ConfigServer::Config> - For IPv4 and IPv6 regex patterns

=back

=head1 IP ADDRESS VALIDATION

Both functions support:

=over 4

=item * IPv4 addresses in dotted-quad notation (e.g., "192.0.2.1")

=item * IPv6 addresses in standard notation (e.g., "2001:db8::1")

=item * CIDR notation for both IPv4 and IPv6 (e.g., "192.0.2.0/24", "2001:db8::/32")

=back

B<Validation rules:>

=over 4

=item * IPv4 CIDR must be between 1 and 32

=item * IPv6 CIDR must be between 1 and 128

=item * Loopback addresses (127.0.0.1, ::1) are rejected by both functions

=item * C<cccheckip> additionally rejects private and reserved address spaces

=back

=head1 NORMALIZATION

When an IPv6 address is passed by reference, both functions normalize it to
the short form using L<Net::IP>. This converts addresses like "2001:0db8:0000:0000:0000:0000:0000:0001"
to "2001:db8::1".

=head1 SEE ALSO

=over 4

=item * L<Net::IP>

=item * L<ConfigServer::Config>

=back

=head1 AUTHOR

Jonathan Michaelson

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2006-2025 Jonathan Michaelson

This program is free software; you can redistribute it and/or modify it under
the terms of the GNU General Public License as published by the Free Software
Foundation; either version 3 of the License, or (at your option) any later
version.

=cut
