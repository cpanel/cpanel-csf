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
package ConfigServer::LookUpIP;

=head1 NAME

ConfigServer::LookUpIP - IP address lookup with geolocation and DNS resolution

=head1 SYNOPSIS

    use ConfigServer::LookUpIP qw(iplookup);

    # Full IP lookup with geolocation and hostname
    my $result = iplookup('8.8.8.8');
    # Returns: "8.8.8.8 (US/United States/hostname)"

    # Country code only lookup
    my $cc = iplookup('8.8.8.8', 1);
    # Returns: "US"

=head1 DESCRIPTION

This module provides IP address lookup functionality including geolocation
data and DNS hostname resolution. It supports both IPv4 and IPv6 addresses
and can query multiple geolocation data sources.

The module performs binary search lookups against local GeoIP CSV databases
for fast geolocation resolution. It also provides DNS caching to improve
performance for repeated hostname lookups.

=head1 FUNCTIONS

=cut

use strict;
use warnings;

use Carp             ();
use Cpanel::JSON::XS ();
use Fcntl            ();
use IPC::Open3       ();
use Net::IP          ();
use Socket           ();

use ConfigServer::CheckIP qw(checkip);
use ConfigServer::Config  ();
use ConfigServer::URLGet  ();

use Exporter qw(import);
our $VERSION   = 2.00;
our @ISA       = qw(Exporter);
our @EXPORT_OK = qw(iplookup);

my $_urlget;

sub _urlget {
    return $_urlget if defined $_urlget;

    # Only called if CC_LOOKUPS == 4
    my $urlget_mode = ConfigServer::Config->get_config('URLGET');
    my $urlproxy    = ConfigServer::Config->get_config('URLPROXY');

    $_urlget = ConfigServer::URLGet->new( $urlget_mode, "", $urlproxy );

    if ( !defined $_urlget ) {
        $_urlget = ConfigServer::URLGet->new( 1, "", $urlproxy );
    }
    return $_urlget;
}

=head2 iplookup

    my $result = iplookup($ip);
    my $result = iplookup($ip, $cconly);

Performs IP address lookup with geolocation and optional DNS resolution.

=over 4

=item B<Parameters>

=over 4

=item * C<$ip> - IP address to lookup (IPv4 or IPv6)

=item * C<$cconly> - Optional boolean flag. When true, returns only country
code (and ASN if CC_LOOKUPS=3). When false or omitted, returns full
geolocation and hostname information.

=back

=item B<Returns>

When C<$cconly> is false (default):

=over 4

=item * With CC_LOOKUPS=1: C<"IP (CC/Country/hostname)">

=item * With CC_LOOKUPS=2 or 4: C<"IP (CC/Country/Region/City/hostname)">

=item * With CC_LOOKUPS=3: C<"IP (CC/Country/Region/City/hostname/[ASN])">

=item * With LF_LOOKUPS only: C<"IP (hostname)">

=item * Without lookups: C<"IP">

=back

When C<$cconly> is true:

=over 4

=item * With CC_LOOKUPS=3: Returns array C<($country_code, $asn)>

=item * Otherwise: Returns scalar C<$country_code>

=back

=item B<Configuration>

Behavior is controlled by configuration settings:

=over 4

=item * C<LF_LOOKUPS> - Enable DNS hostname lookups

=item * C<CC_LOOKUPS> - Country code lookup mode (1-4)

=item * C<CC6_LOOKUPS> - Enable IPv6 country lookups

=item * C<CC_SRC> - Geolocation data source ("1" for GeoLite2, "2" for DB-IP)

=item * C<HOST> - Path to host command for DNS lookups

=back

=back

=cut

sub iplookup {
    my $ip     = shift;
    my $cconly = shift;
    my $host   = "-";
    my $iptype = checkip( \$ip );

    if ( ConfigServer::Config->get_config('LF_LOOKUPS') and !$cconly ) {
        my $dnsip;
        my $dnsrip;
        my $dnshost;
        my $cachehit;
        open( my $DNS, "<", "/var/lib/csf/csf.dnscache" );
        flock( $DNS, Fcntl::LOCK_SH );
        while ( my $line = <$DNS> ) {
            chomp $line;
            ( $dnsip, $dnsrip, $dnshost ) = split( /\|/, $line );
            if ( $ip eq $dnsip ) {
                $cachehit = 1;
                last;
            }
        }
        close($DNS);
        if ($cachehit) {
            $host = $dnshost;
        }
        else {
            my $host_bin = ConfigServer::Config->get_config('HOST');
            if ( -e $host_bin and -x $host_bin ) {
                my $cmdpid;
                eval {
                    local $SIG{__DIE__} = undef;
                    local $SIG{'ALRM'}  = sub { die };
                    alarm(10);
                    my ( $childin, $childout );
                    $cmdpid = IPC::Open3::open3( $childin, $childout, $childout, $host_bin, "-W", "5", $ip );
                    close $childin;
                    my @results = <$childout>;
                    waitpid( $cmdpid, 0 );
                    chomp @results;
                    if ( $results[0] =~ /(\S+)\.$/ ) { $host = $1 }
                    alarm(0);
                };
                alarm(0);
                if ( $cmdpid =~ /\d+/ and $cmdpid > 1 and kill( 0, $cmdpid ) ) { kill( 9, $cmdpid ) }
            }
            else {
                if ( $iptype == 4 ) {
                    eval {
                        local $SIG{__DIE__} = undef;
                        local $SIG{'ALRM'}  = sub { die };
                        alarm(10);
                        my $ipaddr = Socket::inet_aton($ip);
                        $host = gethostbyaddr( $ipaddr, Socket::AF_INET );
                        alarm(0);
                    };
                    alarm(0);
                }
                elsif ( $iptype == 6 ) {
                    eval {
                        local $SIG{__DIE__} = undef;
                        local $SIG{'ALRM'}  = sub { die };
                        alarm(10);
                        eval('use Socket6;');    ##no critic
                        my $ipaddr = Socket::inet_pton( Socket::AF_INET6, $ip );
                        $host = gethostbyaddr( $ipaddr, Socket::AF_INET6 );
                        alarm(0);
                    };
                    alarm(0);
                }
            }
            sysopen( my $dns, "/var/lib/csf/csf.dnscache", Fcntl::O_WRONLY | Fcntl::O_APPEND | Fcntl::O_CREAT );
            flock( $dns, Fcntl::LOCK_EX );
            print $dns "$ip|$ip|$host\n";
            close($dns);
        }
        if ( $host eq "" ) { $host = "-" }
    }

    my $cc_lookups  = ConfigServer::Config->get_config('CC_LOOKUPS');
    my $cc6_lookups = ConfigServer::Config->get_config('CC6_LOOKUPS');
    if ( ( $cc_lookups and $iptype == 4 ) or ( $cc_lookups and $cc6_lookups and $iptype == 6 ) ) {
        my @result;
        eval {
            local $SIG{__DIE__} = undef;
            @result = geo_binary( $ip, $iptype );
        };
        my $asn = $result[4];
        if   ( $result[0] eq "" ) { $result[0] = "-" }
        if   ( $result[1] eq "" ) { $result[1] = "-" }
        if   ( $result[2] eq "" ) { $result[2] = "-" }
        if   ( $result[3] eq "" ) { $result[3] = "-" }
        if   ( $result[4] eq "" ) { $result[4] = "-" }
        else                      { $result[4] = "[$result[4]]" }

        if ( $cc_lookups == 3 ) {
            if ($cconly) { return ( $result[0], $asn ) }
            my $return = "$ip ($result[0]/$result[1]/$result[2]/$result[3]/$host/$result[4])";
            if ( $result[0] eq "-" ) { $return = "$ip ($host)" }
            $return =~ s/'|"//g;
            return $return;
        }
        elsif ( $cc_lookups == 2 or $cc_lookups == 4 ) {
            if ($cconly) { return $result[0] }
            my $return = "$ip ($result[0]/$result[1]/$result[2]/$result[3]/$host)";
            if ( $result[0] eq "-" ) { $return = "$ip ($host)" }
            $return =~ s/'|"//g;
            return $return;
        }
        else {
            if ($cconly) { return $result[0] }
            my $return = "$ip ($result[0]/$result[1]/$host)";
            if ( $result[0] eq "-" ) { $return = "$ip ($host)" }
            $return =~ s/'|"//g;
            return $return;
        }
    }

    if ( ConfigServer::Config->get_config('LF_LOOKUPS') ) {
        if ( $host eq "-" ) { $host = "Unknown" }
        my $return = "$ip ($host)";
        $return =~ s/'//g;
        return $return;
    }
    else {
        return $ip;
    }
}

sub geo_binary {
    my $myip = shift;
    my $ipv  = shift;
    my @return;

    my $netip = Net::IP->new($myip);
    my $ip    = $netip->binip();
    my $type  = $netip->iptype();
    if ( $type eq "PRIVATE" ) { return }

    my $cc_lookups = ConfigServer::Config->get_config('CC_LOOKUPS');
    if ( $cc_lookups == 4 ) {
        my ( $status, $text ) = _urlget()->urlget("http://api.db-ip.com/v2/free/$myip");
        if ($status) { $text = "" }
        if ( $text ne "" ) {
            my $json = Cpanel::JSON::XS::decode_json($text);
            return ( $json->{countryCode}, $json->{countryName}, $json->{stateProv}, $json->{city} );
        }
        else {
            return;
        }
        return;
    }

    my $cc_src = ConfigServer::Config->get_config('CC_SRC');
    if ( $cc_src eq "" or $cc_src eq "1" ) {
        my $file = "/var/lib/csf/Geo/GeoLite2-Country-Blocks-IPv${ipv}.csv";
        if ( $cc_lookups == 2 or $cc_lookups == 3 ) {
            $file = "/var/lib/csf/Geo/GeoLite2-City-Blocks-IPv${ipv}.csv";
        }
        my $start = 0;
        my $end   = -s $file;
        $end += 4;
        my $cnt = 0;
        my $last;
        my $range;
        my $geoid;
        open( my $CSV, "<", $file );
        flock( $CSV, Fcntl::LOCK_SH );

        while (1) {
            my $mid = int( ( $end + $start ) / 2 );
            seek( $CSV, $mid, 0 );
            my $a = <$CSV>;
            my $b = <$CSV>;
            chomp $b;
            ( $range, $geoid, undef ) = split( /\,/, $b );
            if ( $range !~ /^\d/ or $range eq $last or $range eq "" ) { return }
            $last = $range;
            my $netip  = Net::IP->new($range);
            my $lastip = $netip->last_ip();
            $lastip = Net::IP::ip_iptobin( $lastip, $ipv );
            my $firstip = $netip->ip();
            $firstip = Net::IP::ip_iptobin( $firstip, $ipv );

            if ( Net::IP::ip_bincomp( $ip, 'lt', $firstip ) == 1 ) {
                $end = $mid;
            }
            elsif ( Net::IP::ip_bincomp( $ip, 'gt', $lastip ) == 1 ) {
                $start = $mid;
            }
            else {
                last;
            }
            $cnt++;
            if ( $cnt > 200 ) { return }
        }
        close($CSV);

        if ( $geoid > 0 ) {
            my $file = "/var/lib/csf/Geo/GeoLite2-Country-Locations-en.csv";
            if ( $cc_lookups == 2 or $cc_lookups == 3 ) {
                $file = "/var/lib/csf/Geo/GeoLite2-City-Locations-en.csv";
            }
            my $start = 0;
            my $end   = -s $file;
            $end += 4;
            my $cnt = 0;
            my $last;
            open( my $CSV, "<", $file );
            flock( $CSV, Fcntl::LOCK_SH );

            while (1) {
                my $mid = int( ( $end + $start ) / 2 );
                seek( $CSV, $mid, 0 );
                my $a = <$CSV>;
                my $b = <$CSV>;
                chomp $b;
                my @bits = split( /\,/, $b );
                if ( $range !~ /^\d/ or $bits[0] eq $last or $bits[0] eq "" ) { last }
                $last = $bits[0];

                if ( $geoid < $bits[0] ) {
                    $end = $mid;
                }
                elsif ( $geoid > $bits[0] ) {
                    $start = $mid + 1;
                }
                else {
                    $b =~ s/\"//g;
                    my ( $geoname_id, $locale_code, $continent_code, $continent_name, $country_iso_code, $country_name, $subdivision_1_iso_code, $subdivision_1_name, $subdivision_2_iso_code, $subdivision_2_name, $city_name, $metro_code, $time_zone ) = split( /\,/, $b );
                    my $region = $subdivision_2_name;
                    if ( $region eq "" or $region eq $city_name ) { $region = $subdivision_1_name }
                    $return[0] = $country_iso_code;
                    $return[1] = $country_name;
                    $return[2] = $region;
                    $return[3] = $city_name;
                    last;
                }
                $cnt++;
                if ( $cnt > 200 ) { return }
            }
            close($CSV);
        }

        if ( $cc_lookups == 3 ) {
            my $file  = "/var/lib/csf/Geo/GeoLite2-ASN-Blocks-IPv${ipv}.csv";
            my $start = 0;
            my $end   = -s $file;
            $end += 4;
            my $cnt = 0;
            my $last;
            my $range;
            my $asn;
            my $asnorg;
            open( my $CSV, "<", $file );
            flock( $CSV, Fcntl::LOCK_SH );

            while (1) {
                my $mid = int( ( $end + $start ) / 2 );
                seek( $CSV, $mid, 0 );
                my $a = <$CSV>;
                my $b = <$CSV>;
                chomp $b;
                ( $range, $asn, $asnorg ) = split( /\,/, $b, 3 );
                if ( $range !~ /^\d/ or $range eq $last or $range eq "" ) { last }
                $last = $range;
                my $netip  = Net::IP->new($range);
                my $lastip = $netip->last_ip();
                $lastip = Net::IP::ip_iptobin( $lastip, $ipv );
                my $firstip = $netip->ip();
                $firstip = Net::IP::ip_iptobin( $firstip, $ipv );

                if ( Net::IP::ip_bincomp( $ip, 'lt', $firstip ) == 1 ) {
                    $end = $mid;
                }
                elsif ( Net::IP::ip_bincomp( $ip, 'gt', $lastip ) == 1 ) {
                    $start = $mid + 1;
                }
                else {
                    $return[4] = "AS$asn $asnorg";
                    last;
                }
                $cnt++;
                if ( $cnt > 200 ) { last }
            }
            close($CSV);
        }
    }
    elsif ( $cc_src eq "2" ) {
        my %country_name;
        open( my $CC, "<", "/var/lib/csf/Geo/countryInfo.txt" );
        flock( $CC, Fcntl::LOCK_SH );
        foreach my $line (<$CC>) {
            if ( $line eq "" or $line =~ /^\#/ or $line =~ /^\s/ ) { next }
            my ( $cc, undef, undef, undef, $country, undef ) = split( /\t/, $line );
            if ( $cc ne "" and $country ne "" ) { $country_name{$cc} = $country }
        }
        close($CC);

        my $file = "/var/lib/csf/Geo/dbip-country-lite.csv";
        if ( $cc_lookups == 2 or $cc_lookups == 3 ) {
            $file = "/var/lib/csf/Geo/dbip-city-lite.csv";
        }
        my $start = 0;
        my $end   = -s $file;
        $end += 4;
        my $cnt = 0;
        my $last;
        my $range;
        my $geoid;
        open( my $CSV, "<", $file );
        flock( $CSV, Fcntl::LOCK_SH );

        while (1) {
            my $mid = int( ( $end + $start ) / 2 );
            seek( $CSV, $mid, 0 );
            my $a = <$CSV>;
            my $b = <$CSV>;
            chomp $b;
            my ( $firstip, $lastip, $cc_lookups1, $country_iso_code, $region, $city_name, undef ) = split( /\,/, $b );
            if ( $firstip eq $lastip or $firstip eq "" ) { return }
            if ( checkip( \$firstip ) ne $ipv ) {
                if ( $ipv eq "6" ) {
                    $start = $mid;
                }
                else {
                    $end = $mid;
                }
            }
            else {
                my $netfirstip = Net::IP->new($firstip);
                my $firstip    = $netfirstip->binip();
                my $netlastip  = Net::IP->new($lastip);
                my $lastip     = $netlastip->binip();
                if ( Net::IP::ip_bincomp( $ip, 'lt', $firstip ) == 1 ) {
                    $end = $mid;
                }
                elsif ( Net::IP::ip_bincomp( $ip, 'gt', $lastip ) == 1 ) {
                    $start = $mid + 1;
                }
                else {
                    if ( $cc_lookups == 1 )          { $country_iso_code = $cc_lookups1 }
                    if ( $country_iso_code eq "ZZ" ) { last }
                    $return[0] = $country_iso_code;
                    $return[1] = $country_name{$country_iso_code};
                    $return[2] = $region;
                    $return[3] = $city_name;
                    last;
                }
            }
            $cnt++;
            if ( $cnt > 200 ) { return }
        }
        close($CSV);

        if ( $cc_lookups == 3 ) {
            my $file  = "/var/lib/csf/Geo/ip2asn-combined.tsv";
            my $start = 0;
            my $end   = -s $file;
            $end += 4;
            my $cnt = 0;
            my $last;
            my $range;
            my $asn;
            my $asnorg;
            open( my $CSV, "<", $file );
            flock( $CSV, Fcntl::LOCK_SH );

            while (1) {
                my $mid = int( ( $end + $start ) / 2 );
                seek( $CSV, $mid, 0 );
                my $a = <$CSV>;
                my $b = <$CSV>;
                chomp $b;
                my ( $firstip, $lastip, $asn, undef, $asnorg ) = split( /\t/, $b );
                if ( $firstip eq $lastip or $firstip eq "" ) { last }
                if ( checkip( \$firstip ) ne $ipv ) {
                    if ( $ipv eq "6" ) {
                        $start = $mid;
                    }
                    else {
                        $end = $mid;
                    }
                }
                else {
                    my $netfirstip = Net::IP->new($firstip);
                    my $firstip    = $netfirstip->binip();
                    my $netlastip  = Net::IP->new($lastip);
                    my $lastip     = $netlastip->binip();
                    if ( Net::IP::ip_bincomp( $ip, 'lt', $firstip ) == 1 ) {
                        $end = $mid;
                    }
                    elsif ( Net::IP::ip_bincomp( $ip, 'gt', $lastip ) == 1 ) {
                        $start = $mid + 1;
                    }
                    else {
                        if ( $asn eq "0" ) { last }
                        $return[4] = "AS$asn $asnorg";
                        last;
                    }
                }
                $cnt++;
                if ( $cnt > 200 ) { last }
            }
            close($CSV);
        }
    }
    return @return;
}

1;

=head1 SEE ALSO

L<ConfigServer::CheckIP>, L<ConfigServer::Config>, L<ConfigServer::URLGet>

=cut
