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
# start main
package ConfigServer::Config;

=head1 NAME

ConfigServer::Config - Configuration loader and system capability detector
for CSF (ConfigServer Security & Firewall)

=head1 SYNOPSIS

    use ConfigServer::Config;

    # Load the configuration
    my $config_obj = ConfigServer::Config->loadconfig();

    # Check for warnings during configuration load
    if ( $config_obj->{warning} ) {
        print "Warnings: $config_obj->{warning}\n";
    }

    # Get IPv4 and IPv6 regex patterns
    my $ipv4_pattern = ConfigServer::Config->ipv4reg();
    my $ipv6_pattern = ConfigServer::Config->ipv6reg();

    # Validate an IP address
    if ( $ip =~ /^$ipv4_pattern$/ ) {
        print "Valid IPv4 address\n";
    }

=head1 DESCRIPTION

This module loads the CSF configuration from C</etc/csf/csf.conf> and
detects system capabilities including iptables version, kernel features,
and available netfilter tables. It validates configuration settings and
provides warnings for problematic or incompatible configurations.

The module performs extensive system detection to determine:

=over 4

=item * iptables and ip6tables version and capabilities

=item * Availability of raw, mangle, and nat tables

=item * Kernel version and IPv6 support

=item * cPanel-specific configuration options

=item * VPS/virtualization environment detection

=item * Country code and ASN database sources

=back

Configuration is loaded once and cached in package variables for
performance. The module also provides regex patterns for validating
IPv4 and IPv6 addresses.

=head1 METHODS

=cut

use strict;
use warnings;

use version    ();
use Carp       ();
use IPC::Open3 ();
use Fcntl      ();

use lib '/usr/local/csf/lib';
use ConfigServer::Slurp ();

our $VERSION = 1.05;

my $ipv4reg = qr/(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)/;
my $ipv6reg =
  qr/((([0-9A-Fa-f]{1,4}:){7}([0-9A-Fa-f]{1,4}|:))|(([0-9A-Fa-f]{1,4}:){6}(:[0-9A-Fa-f]{1,4}|((25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)(\.(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)){3})|:))|(([0-9A-Fa-f]{1,4}:){5}(((:[0-9A-Fa-f]{1,4}){1,2})|:((25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)(\.(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)){3})|:))|(([0-9A-Fa-f]{1,4}:){4}(((:[0-9A-Fa-f]{1,4}){1,3})|((:[0-9A-Fa-f]{1,4})?:((25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)(\.(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)){3}))|:))|(([0-9A-Fa-f]{1,4}:){3}(((:[0-9A-Fa-f]{1,4}){1,4})|((:[0-9A-Fa-f]{1,4}){0,2}:((25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)(\.(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)){3}))|:))|(([0-9A-Fa-f]{1,4}:){2}(((:[0-9A-Fa-f]{1,4}){1,5})|((:[0-9A-Fa-f]{1,4}){0,3}:((25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)(\.(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)){3}))|:))|(([0-9A-Fa-f]{1,4}:){1}(((:[0-9A-Fa-f]{1,4}){1,6})|((:[0-9A-Fa-f]{1,4}){0,4}:((25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)(\.(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)){3}))|:))|(:(((:[0-9A-Fa-f]{1,4}){1,7})|((:[0-9A-Fa-f]{1,4}){0,5}:((25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)(\.(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)){3}))|:)))(%.+)?/;

my %config;
my %configsetting;
my $warning;
my $version;

my $configfile = "/etc/csf/csf.conf";

# end main
###############################################################################
# start loadconfig

=head2 loadconfig

    my $config = ConfigServer::Config->loadconfig();

    if ( $config->{warning} ) {
        print "Configuration warnings:\n$config->{warning}";
    }

Loads the CSF configuration file and detects system capabilities.

This method reads C</etc/csf/csf.conf>, parses configuration settings,
and performs extensive system detection including iptables version,
kernel capabilities, and available netfilter tables. It validates
configuration values and generates warnings for problematic settings.

The configuration is loaded once and cached in package variables.
Subsequent calls return the cached configuration without re-parsing.

=head3 Returns

A blessed hash reference containing:

=over 4

=item * C<warning> - String containing any configuration warnings or errors
generated during loading. Empty string if no warnings.

=back

=head3 Side Effects

=over 4

=item * Populates package variables C<%config> and C<%configsetting> with
configuration data

=item * May execute iptables commands to detect system capabilities

=item * May modify C</proc/sys/net/netfilter/nf_conntrack_helper> if
nf_conntrack_helper is disabled

=item * Reads various system files to detect environment (VPS, cPanel, etc.)

=back

=head3 Errors

Dies (via C<Carp::croak>) if:

=over 4

=item * Configuration file contains invalid syntax

=item * Duplicate configuration settings are found

=item * iptables path is not set or executable not found

=item * iptables --wait option times out (when WAITLOCK enabled)

=back

=cut

sub loadconfig {
    my $class = shift;
    my $self  = {};
    bless $self, $class;

    if (%config) {
        $self->{warning} = $warning;
        return $self;
    }

    undef %configsetting;
    undef %config;
    undef $warning;

    my $cleanreg = ConfigServer::Slurp->cleanreg();
    my @file     = ConfigServer::Slurp::slurp($configfile);
    foreach my $line (@file) {
        $line =~ s/$cleanreg//g;
        if ( $line =~ /^(\s|\#|$)/ ) { next }
        if ( $line !~ /=/ )          { next }
        my ( $name, $value ) = split( /=/, $line, 2 );
        $name =~ s/\s//g;
        if ( $value =~ /\"(.*)\"/ ) {
            $value = $1;
        }
        else {
            Carp::croak "*Error* Invalid configuration line [$line] in $configfile";
        }
        if ( $configsetting{$name} ) {
            Carp::croak "*Error* Setting $name is repeated in $configfile - you must remove the duplicates and then restart csf and lfd";
        }
        $config{$name}        = $value;
        $configsetting{$name} = 1;
    }

    if ( $config{LF_IPSET} ) {
        unless ( $config{LF_IPSET_HASHSIZE} ) {
            $config{LF_IPSET_HASHSIZE}        = "1024";
            $configsetting{LF_IPSET_HASHSIZE} = 1;
        }
        unless ( $config{LF_IPSET_MAXELEM} ) {
            $config{LF_IPSET_MAXELEM}        = "65536";
            $configsetting{LF_IPSET_MAXELEM} = 1;
        }
    }

    if ( $config{USE_FTPHELPER} eq "1" ) {
        $warning .= "USE_FTPHELPER should be set to your FTP server port (21), not 1. USE_FTPHELPER has been disabled\n";
        $config{USE_FTPHELPER} = 0;
    }

    if ( $config{IPTABLES} eq "" or !( -x $config{IPTABLES} ) ) {
        Carp::croak "*Error* The path to iptables is either not set or incorrect for IPTABLES [$config{IPTABLES}] in /etc/csf/csf.conf";
    }

    if ( -e "/proc/sys/net/netfilter/nf_conntrack_helper" and !$config{USE_FTPHELPER} ) {
        my $setting = ConfigServer::Slurp::slurp("/proc/sys/net/netfilter/nf_conntrack_helper");
        chomp $setting;

        if ( $setting == 0 ) {
            open( my $PROC, ">", "/proc/sys/net/netfilter/nf_conntrack_helper" );
            print $PROC "1\n";
            close $PROC;
        }
    }

    $config{IPTABLESWAIT} = $config{WAITLOCK} ? "--wait" : "";
    my @results = _systemcmd("$config{IPTABLES} $config{IPTABLESWAIT} --version");
    if ( $results[0] =~ /iptables v(\d+\.\d+\.\d+)/ ) {
        $version = $1;

        $config{IPTABLESWAIT} = "";
        if ( $config{WAITLOCK} ) {
            my @ipdata;
            eval {
                local $SIG{__DIE__} = undef;
                local $SIG{'ALRM'}  = sub { die "alarm\n" };
                alarm( $config{WAITLOCK_TIMEOUT} );
                my ( $childin, $childout );
                my $cmdpid = IPC::Open3::open3( $childin, $childout, $childout, "$config{IPTABLES} --wait -L OUTPUT -nv" );
                @ipdata = <$childout>;
                waitpid( $cmdpid, 0 );
                chomp @ipdata;
                if ( $ipdata[0] =~ /# Warning: iptables-legacy tables present/ ) { shift @ipdata }
                alarm(0);
            };
            alarm(0);
            if ( $@ eq "alarm\n" ) {
                Carp::croak "*ERROR* Timeout after $config{WAITLOCK_TIMEOUT} seconds for iptables --wait - WAITLOCK\n";
            }
            if ( $ipdata[0] =~ /^Chain OUTPUT/ ) {
                $config{IPTABLESWAIT} = "--wait";
            }
            else {
                $warning .= "*WARNING* This version of iptables does not support the --wait option - disabling WAITLOCK\n";
                $config{WAITLOCK} = 0;
            }
        }
    }
    else {
        $warning .= "*WARNING* Unable to detect iptables version [$results[0]]\n";
    }

    if ( $config{CC_LOOKUPS} and $config{CC_LOOKUPS} != 4 and $config{CC_SRC} eq "1" ) {
        if ( $config{MM_LICENSE_KEY} eq "" ) {
            $warning .= "*ERROR*: Country Code Lookups setting MM_LICENSE_KEY must be set in /etc/csf/csf.conf to continue using the MaxMind databases\n";
        }
    }

    foreach my $cclist ( "CC_DENY", "CC_ALLOW", "CC_ALLOW_FILTER", "CC_ALLOW_PORTS", "CC_DENY_PORTS", "CC_ALLOW_SMTPAUTH" ) {
        $config{$cclist} =~ s/\s//g;
        my $newcclist;
        foreach my $cc ( split( /\,/, $config{$cclist} ) ) {
            if ( $cc ne "" and ( ( length($cc) == 2 and $cc =~ /^[a-zA-Z][a-zA-Z]$/i ) or ( length($cc) > 2 and $cc =~ /^AS\d+$/i ) ) ) {
                $cc = lc $cc;
                if ( $newcclist eq "" ) { $newcclist = "$cc" }
                else                    { $newcclist .= ",$cc" }
            }
            else {
                $warning .= "*WARNING* $cclist contains an invalid entry [$cc]\n";
            }
        }
        $config{$cclist} = $newcclist;
    }

    if ( $config{CC_DENY} or $config{CC_ALLOW} or $config{CC_ALLOW_FILTER} or $config{CC_ALLOW_PORTS} or $config{CC_DENY_PORTS} or $config{CC_ALLOW_SMTPAUTH} ) {
        if ( $config{MM_LICENSE_KEY} eq "" and $config{CC_SRC} eq "1" ) {
            $warning .= "*ERROR*: Country Code Filters setting MM_LICENSE_KEY must be set in /etc/csf/csf.conf to continue updating the MaxMind databases\n";
        }
    }

    if ( $config{DROP_OUT} ne "DROP" ) {
        my @data = _systemcmd("$config{IPTABLES} $config{IPTABLESWAIT} -N TESTDENY");
        unless ( length $data[0] && $data[0] =~ /^iptables/ ) {
            my @ipdata = _systemcmd("$config{IPTABLES} $config{IPTABLESWAIT} -I TESTDENY -j $config{DROP_OUT}");
            if ( length $ipdata[0] && $ipdata[0] =~ /^iptables/ ) {
                $warning .= "*WARNING* Cannot use DROP_OUT value of [$config{DROP_OUT}] on this server, set to DROP\n";
                $config{DROP_OUT} = "DROP";
            }
            _systemcmd("$config{IPTABLES} $config{IPTABLESWAIT} -F TESTDENY");
            _systemcmd("$config{IPTABLES} $config{IPTABLESWAIT} -X TESTDENY");
        }
    }
    my @raw = _systemcmd("$config{IPTABLES} $config{IPTABLESWAIT} -L PREROUTING -t raw");
    if   ( $raw[0] =~ /^Chain PREROUTING/ ) { $config{RAW} = 1 }
    else                                    { $config{RAW} = 0 }
    my @mangle = _systemcmd("$config{IPTABLES} $config{IPTABLESWAIT} -L PREROUTING -t mangle");
    if   ( $mangle[0] =~ /^Chain PREROUTING/ ) { $config{MANGLE} = 1 }
    else                                       { $config{MANGLE} = 0 }

    if ( $config{IPV6} and -x $config{IP6TABLES} and $version ) {
        if ( $config{USE_CONNTRACK} and version->parse($version) <= version->parse("1.3.5") )  { $config{USE_CONNTRACK}  = 0 }
        if ( $config{PORTFLOOD}     and version->parse($version) >= version->parse("1.4.3") )  { $config{PORTFLOOD6}     = 1 }
        if ( $config{CONNLIMIT}     and version->parse($version) >= version->parse("1.4.3") )  { $config{CONNLIMIT6}     = 1 }
        if ( $config{MESSENGER}     and version->parse($version) >= version->parse("1.4.17") ) { $config{MESSENGER6}     = 1 }
        if ( $config{SMTP_REDIRECT} and version->parse($version) >= version->parse("1.4.17") ) { $config{SMTP_REDIRECT6} = 1 }
        my @ipdata = _systemcmd("$config{IP6TABLES} $config{IPTABLESWAIT} -t nat -L POSTROUTING -nv");
        if ( $ipdata[0] =~ /^Chain POSTROUTING/ ) {
            $config{NAT6} = 1;
        }
        elsif ( version->parse($version) >= version->parse("1.4.17") ) {
            if ( $config{SMTP_REDIRECT} ) {
                $warning .= "*WARNING* ip6tables nat table not present - disabling SMTP_REDIRECT for IPv6\n";
                $config{SMTP_REDIRECT6} = 0;
            }
            if ( $config{MESSENGER} ) {
                $warning .= "*WARNING* ip6tables nat table not present - disabling MESSENGER Service for IPv6\n";
                $config{MESSENGER6} = 0;
            }
            if ( $config{DOCKER} and $config{DOCKER_NETWORK6} ne "" ) {
                $warning .= "*WARNING* ip6tables nat table not present - disabling DOCKER for IPv6\n";
            }
        }
        my @raw = _systemcmd("$config{IP6TABLES} $config{IPTABLESWAIT} -L PREROUTING -t raw");
        if   ( $raw[0] =~ /^Chain PREROUTING/ ) { $config{RAW6} = 1 }
        else                                    { $config{RAW6} = 0 }
        my @mangle = _systemcmd("$config{IP6TABLES} $config{IPTABLESWAIT} -L PREROUTING -t mangle");
        if   ( $mangle[0] =~ /^Chain PREROUTING/ ) { $config{MANGLE6} = 1 }
        else                                       { $config{MANGLE6} = 0 }
    }
    elsif ( $config{IPV6} ) {
        $warning .= "*WARNING* incorrect ip6tables binary location [$config{IP6TABLES}] - IPV6 disabled\n";
        $config{IPV6} = 0;
    }

    if ( -e "/var/cpanel/dnsonly" ) { $config{DNSONLY} = 1 }

    if ( -e "/var/cpanel/smtpgidonlytweak" ) {
        if ( $config{DNSONLY} ) {
            $warning .= "*WARNING* The cPanel option to 'Restrict outgoing SMTP to root, exim, and mailman' is incompatible with this firewall. The option must be disabled using \"/usr/local/cpanel/scripts/smtpmailgidonly off\" and the SMTP_BLOCK alternative in csf used instead\n";
        }
        else {
            $warning .= "*WARNING* The option \"WHM > Tweak Settings > Restrict outgoing SMTP to root, exim, and mailman (FKA SMTP Tweak)\" is incompatible with this firewall. The option must be disabled in WHM and the SMTP_BLOCK alternative in csf used instead\n";
        }
    }
    if ( -e "/proc/vz/veinfo" ) { $config{VPS} = 1 }
    else {
        foreach my $line ( ConfigServer::Slurp::slurp("/proc/self/status") ) {
            $line =~ s/$cleanreg//g;
            if ( $line =~ /^envID:\s*(\d+)\s*$/ ) {
                if ( $1 > 0 ) {
                    $config{VPS} = 1;
                    last;
                }
            }
        }
    }
    if ( $config{DROP_IP_LOGGING} and $config{PS_INTERVAL} ) {
        $warning .= "*WARNING* Cannot use PS_INTERVAL with DROP_IP_LOGGING enabled. DROP_IP_LOGGING disabled\n";
        $config{DROP_IP_LOGGING} = 0;
    }

    if ( $config{FASTSTART} ) {
        unless ( -x $config{IPTABLES_RESTORE} ) {
            $warning .= "*WARNING* Unable to use FASTSTART as [$config{IPTABLES_RESTORE}] is not executable or does not exist\n";
            $config{FASTSTART} = 0;
        }
        if ( $config{IPV6} ) {
            unless ( -x $config{IP6TABLES_RESTORE} ) {
                $warning .= "*WARNING* Unable to use FASTSTART as (IPv6) [$config{IP6TABLES_RESTORE}] is not executable or does not exist\n";
                $config{FASTSTART} = 0;
            }
        }
    }

    if ( $config{MESSENGER} ) {
        if ( $config{MESSENGERV2} ) {
            if ( !-e "/etc/cpanel/ea4/is_ea4" ) {
                $warning .= "*WARNING* EA4 is not in use - disabling MESSENGERV2 and MESSENGER HTTPS Service\n";
                $config{MESSENGERV2}              = "0";
                $config{MESSENGER_HTTPS_IN}       = "";
                $config{MESSENGER_HTTPS_DISABLED} = "*WARNING* EA4 is not in use - disabling MESSENGERV2 and MESSENGER HTTPS Service";
            }
        }
        if ( $config{MESSENGER_HTTPS_IN} and ( !$config{MESSENGERV2} or $config{MESSENGER_HTTPS_DISABLED} ) ) {
            eval {
                local $SIG{__DIE__} = undef;
                require IO::Socket::SSL;
            };
            if ($@) {
                $warning .= "*WARNING* Perl module IO::Socket::SSL missing - disabling MESSENGER HTTPS Service\n";
                $config{MESSENGER_HTTPS_IN}       = "";
                $config{MESSENGER_HTTPS_DISABLED} = "*WARNING* Perl module IO::Socket::SSL missing - disabling MESSENGER HTTPS Service";
            }
            elsif ( version->parse($IO::Socket::SSL::VERSION) < version->parse("1.83") ) {
                $warning .= "*WARNING* Perl module IO::Socket::SSL v$IO::Socket::SSL::VERSION does not support SNI - disabling MESSENGER HTTPS Service\n";
                $config{MESSENGER_HTTPS_IN}       = "";
                $config{MESSENGER_HTTPS_DISABLED} = "*WARNING* Perl module IO::Socket::SSL v$IO::Socket::SSL::VERSION does not support SNI - disabling MESSENGER HTTPS Service";
            }
        }
        my $pcnt = 0;
        foreach my $port ( split( /\,/, $config{MESSENGER_HTML_IN} ) ) {
            $pcnt++;
        }
        if ( $pcnt > 15 ) {
            $warning .= "*WARNING* MESSENGER_HTML_IN contains more than 15 ports - disabling MESSENGER Service\n";
            $config{MESSENGER} = 0;
        }
        else {
            $pcnt = 0;
            foreach my $port ( split( /\,/, $config{MESSENGER_TEXT_IN} ) ) {
                $pcnt++;
            }
            if ( $pcnt > 15 ) {
                $warning .= "*WARNING* MESSENGER_TEXT_IN contains more than 15 ports - disabling MESSENGER Service\n";
                $config{MESSENGER} = 0;
            }
            else {
                $pcnt = 0;
                foreach my $port ( split( /\,/, $config{MESSENGER_HTTPS_IN} ) ) {
                    $pcnt++;
                }
                if ( $pcnt > 15 ) {
                    $warning .= "*WARNING* MESSENGER_HTTPS_IN contains more than 15 ports - disabling MESSENGER Service\n";
                    $config{MESSENGER} = 0;
                }
            }
        }
    }

    if ( $config{IPV6} and $config{IPV6_SPI} ) {
        my @data = ConfigServer::Slurp::slurp("/proc/sys/kernel/osrelease");
        chomp @data;
        if ( $data[0] =~ /^(\d+)\.(\d+)\.(\d+)/ ) {
            my $maj = $1;
            my $mid = $2;
            my $min = $3;
            if ( ( $maj > 2 ) or ( ( $maj > 1 ) and ( $mid > 6 ) ) or ( ( $maj > 1 ) and ( $mid > 5 ) and ( $min > 19 ) ) ) {
            }
            else {
                $warning .= "*WARNING* Kernel $data[0] may not support an ip6tables SPI firewall. You should set IPV6_SPI to \"0\" in /etc/csf/csf.conf\n\n";
            }
        }
    }

    if ( ( $config{CLUSTER_SENDTO} or $config{CLUSTER_RECVFROM} ) ) {
        if ( -f $config{CLUSTER_SENDTO} ) {
            if ( $config{DEBUG} >= 1 ) { $warning .= "*DEBUG* CLUSTER_SENDTO retrieved from $config{CLUSTER_SENDTO} and set to: " }
            $config{CLUSTER_SENDTO} = join( ",", ConfigServer::Slurp::slurp( $config{CLUSTER_SENDTO} ) );
            if ( $config{DEBUG} >= 1 ) { $warning .= "[$config{CLUSTER_SENDTO}]\n" }
        }
        if ( -f $config{CLUSTER_RECVFROM} ) {
            if ( $config{DEBUG} >= 1 ) { $warning .= "*DEBUG* CLUSTER_RECVFROM retrieved from $config{CLUSTER_RECVFROM} and set to: " }
            $config{CLUSTER_RECVFROM} = join( ",", ConfigServer::Slurp::slurp( $config{CLUSTER_RECVFROM} ) );
            if ( $config{DEBUG} >= 1 ) { $warning .= "[$config{CLUSTER_RECVFROM}]\n" }
        }
    }

    my @ipdata = _systemcmd("$config{IPTABLES} $config{IPTABLESWAIT} -t nat -L POSTROUTING -nv");
    if ( $ipdata[0] =~ /^Chain POSTROUTING/ ) {
        $config{NAT} = 1;
    }
    else {
        if ( $config{MESSENGER} ) {
            $warning .= "*WARNING* iptables nat table not present - disabling MESSENGER Service\n";
            $config{MESSENGER} = 0;
        }
    }

    if ( $config{PT_USERKILL} ) {
        $warning .= "*WARNING* PT_USERKILL should not normally be enabled as it can easily lead to legitimate processes being terminated, use csf.pignore instead\n";
    }

    $config{cc_src}     = "MaxMind";
    $config{asn_src}    = "MaxMind";
    $config{cc_country} = "https://download.maxmind.com/app/geoip_download?edition_id=GeoLite2-Country-CSV&suffix=zip&license_key=$config{MM_LICENSE_KEY}";
    $config{cc_city}    = "https://download.maxmind.com/app/geoip_download?edition_id=GeoLite2-City-CSV&suffix=zip&license_key=$config{MM_LICENSE_KEY}";
    $config{cc_asn}     = "https://download.maxmind.com/app/geoip_download?edition_id=GeoLite2-ASN-CSV&suffix=zip&license_key=$config{MM_LICENSE_KEY}";
    if ( $config{CC_SRC} eq "2" ) {
        $config{cc_src}  = "DB-IP";
        $config{asn_src} = "iptoasn.com";
        $config{ccl_src} = "ipdeny.com";
        my ( $month, $year ) = sub { 1 + shift, 1900 + shift }
          ->( ( localtime time )[ 4, 5 ] );
        $month              = sprintf( "%02d", $month );
        $config{cc_country} = "http://download.db-ip.com/free/dbip-country-lite-$year-$month.csv.gz";
        $config{cc_city}    = "http://download.db-ip.com/free/dbip-city-lite-$year-$month.csv.gz";
        $config{cc_asn}     = "http://iptoasn.com/data/ip2asn-combined.tsv.gz";
        $config{cc_cc}      = "http://download.geonames.org/export/dump/countryInfo.txt";
    }

    $config{DOWNLOADSERVER} = _getdownloadserver();

    $self->{warning} = $warning;

    return $self;
}

=head2 config

    my %config = ConfigServer::Config::config();
    my $iptables_path = $config{IPTABLES};

Returns the loaded configuration hash.

This method provides access to the parsed configuration settings from
C</etc/csf/csf.conf> along with any system-detected values added during
the configuration load process.

=head3 Returns

A hash containing all configuration keys and values. Common keys include:

=over 4

=item * C<IPTABLES> - Path to iptables binary

=item * C<IP6TABLES> - Path to ip6tables binary

=item * C<IPV6> - Whether IPv6 support is enabled

=item * C<RAW>, C<MANGLE>, C<NAT> - Whether iptables tables are available

=item * C<VPS> - Whether running in a VPS environment

=back

Note: The configuration must be loaded via C<loadconfig()> before this
method returns meaningful data.

=head3 Side Effects

None.

=head3 Errors

None.

=cut

# start config
sub config {
    return %config;
}

=head2 get_config

    my $value = ConfigServer::Config->get_config($key);

    my $tcp_in = ConfigServer::Config->get_config('TCP_IN');
    my $ipv6   = ConfigServer::Config->get_config('IPV6');

Gets a single configuration value by key, automatically loading the
configuration if not already loaded.

This method provides a convenient way to retrieve individual configuration
values without needing to explicitly call C<loadconfig()> first. If the
configuration hash is empty, it will automatically load the configuration
before returning the requested value.

=head3 Parameters

=over 4

=item * C<$key> - String name of the configuration setting to retrieve

=back

=head3 Returns

The value of the requested configuration setting, or C<undef> if the key
does not exist in the configuration.

=head3 Side Effects

=over 4

=item * Calls C<loadconfig()> if C<%config> is empty

=item * Populates package-level C<%config> and C<%configsetting> hashes

=back

=head3 Errors

None - returns C<undef> for non-existent keys.

=head3 Example

    # These are equivalent:
    my $config_obj = ConfigServer::Config->loadconfig();
    my %cfg = $config_obj->config();
    my $tcp_in = $cfg{TCP_IN};

    # Simpler approach:
    my $tcp_in = ConfigServer::Config->get_config('TCP_IN');

=cut

sub get_config {
    my ( $class, $key ) = @_;

    # Load config if hash is empty
    if ( !%config ) {
        $class->loadconfig();
    }

    return %config if !defined $key;    # They didn't pass a key so just give the whole hash back.
    return $config{$key};
}

sub _resetconfig {
    undef %config;
    undef %configsetting;
    undef $warning;

    return;
}

=head2 configsetting

    my %configsetting = ConfigServer::Config::configsetting();

    if ( $configsetting{IPTABLES} ) {
        print "IPTABLES setting was found in config file\n";
    }

Returns a hash tracking which configuration settings were defined.

This method provides a boolean hash where keys are configuration setting
names and values are C<1> if that setting was found in the configuration
file. This is useful for distinguishing between settings that are explicitly
set versus default values.

=head3 Returns

A hash where:

=over 4

=item * Keys are configuration setting names (e.g., C<IPTABLES>, C<IPV6>)

=item * Values are C<1> if the setting was defined in C</etc/csf/csf.conf>

=item * Undefined keys indicate settings not present in the config file

=back

=head3 Side Effects

None.

=head3 Errors

None.

=cut

# start configsetting
sub configsetting {
    return %configsetting;
}

=head2 ipv4reg

    my $ipv4_regex = ConfigServer::Config->ipv4reg();

    if ( $address =~ /^$ipv4_regex$/ ) {
        print "Valid IPv4 address\n";
    }

Returns a compiled regular expression for validating IPv4 addresses.

The regex matches standard dotted-decimal IPv4 addresses with proper
range validation (0-255 for each octet). This pattern is suitable for
validating individual IPv4 addresses but does not match CIDR notation.

=head3 Returns

A compiled C<Regexp> object (C<qr//>) that matches valid IPv4 addresses.

=cut

sub ipv4reg {
    return $ipv4reg;
}

=head2 ipv6reg

    my $ipv6_regex = ConfigServer::Config->ipv6reg();

    if ( $address =~ /^$ipv6_regex$/ ) {
        print "Valid IPv6 address\n";
    }

Returns a compiled regular expression for validating IPv6 addresses.

The regex matches standard IPv6 addresses including compressed notation,
full notation, IPv4-mapped IPv6 addresses, and link-local addresses. It
supports all valid IPv6 formats including zone IDs (scope identifiers).

=head3 Returns

A compiled C<Regexp> object (C<qr//>) that matches valid IPv6 addresses
in any standard format.

=cut

sub ipv6reg {
    return $ipv6reg;
}

# start _systemcmd
sub _systemcmd {
    my @command = @_;
    my @result;

    eval {
        my ( $childin, $childout );
        my $pid = IPC::Open3::open3( $childin, $childout, $childout, @command );
        @result = <$childout>;
        waitpid( $pid, 0 );
        chomp @result;
        if ( length $result[0] && $result[0] =~ /# Warning: iptables-legacy tables present/ ) { shift @result }
    };

    return @result;
}

sub _getdownloadserver {
    my $cleanreg = ConfigServer::Slurp->cleanreg();
    my @servers;
    my $downloadservers = "/etc/csf/downloadservers";
    my $chosen;
    if ( -e $downloadservers ) {
        foreach my $line ( ConfigServer::Slurp::slurp($downloadservers) ) {
            $line =~ s/$cleanreg//g;
            if ( $line =~ /^download/ ) { push @servers, $line }
        }
        $chosen = $servers[ rand @servers ];
    }
##	if ($chosen eq "") {$chosen = "download.configserver.com"}
    return $chosen;
}

1;
