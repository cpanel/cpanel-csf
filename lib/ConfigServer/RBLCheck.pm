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
# start main
package ConfigServer::RBLCheck;

=head1 NAME

ConfigServer::RBLCheck - Check server IPs against Real-time Blackhole Lists

=head1 SYNOPSIS

    use ConfigServer::RBLCheck;
    
    # Get HTML output without printing
    my ($failures, $html) = ConfigServer::RBLCheck::report(1, "/images", 0);
    print "Found $failures IPs on blocklists\n";
    print $html;
    
    # Print directly to STDOUT (UI mode)
    ConfigServer::RBLCheck::report(2, "/images", 1);

=head1 DESCRIPTION

This module checks all public IP addresses on the server against configured
Real-time Blackhole Lists (RBLs) to detect if any IPs are listed for spam
or malware activity.

RBL configuration is loaded from F</usr/local/csf/lib/csf.rbls> (default list)
and F</etc/csf/csf.rblconf> (user overrides). Results are cached in
F</var/lib/csf/{ip}.rbls> to avoid redundant DNS lookups.

Only public IPv4 addresses are checked. Private IPs and IPv6 addresses are
skipped. IPv6 checking is not currently implemented.

=cut

use cPstrict;
use lib '/usr/local/csf/lib';
use Fcntl ();
use ConfigServer::Config;
use ConfigServer::CheckIP   qw(checkip);
use ConfigServer::Slurp     qw(slurp);
use ConfigServer::GetIPs    qw(getips);
use ConfigServer::RBLLookup qw(rbllookup);
use Net::IP;
use ConfigServer::GetEthDev;

our $VERSION = 1.01;

my (
    $ui,       $failures, $verbose, $cleanreg, $status, %ips, $images,
    $ipresult, $output
);

# end main
###############################################################################
# start report

=head2 report($verbose, $images, $ui)

Checks all server public IPs against configured RBLs.

=head3 Parameters

=over 4

=item C<$verbose> - Integer verbosity level

    0 = Basic output (only failures shown)
    1 = Detailed output (all checks shown)
    2 = All IPs including private addresses

=item C<$images> - String path to UI images directory

Path prefix for images used in HTML output (e.g., C</images>).

=item C<$ui> - Boolean UI mode flag

If true (1), prints output directly to STDOUT.
If false (0), accumulates output and returns it.

=back

=head3 Returns

List of C<($failures, $output)>:

=over 4

=item C<$failures> - Integer count of IPs found on blocklists

Number of public IPs that were listed on one or more RBLs.

=item C<$output> - String containing HTML output

Complete HTML report of all checks. Empty string if C<$ui> is true.

=back

=head3 Behavior

=over 4

=item * Discovers all server IP addresses via ConfigServer::GetEthDev

=item * Loads RBL configuration from csf.rbls and csf.rblconf

=item * Checks only PUBLIC IPv4 addresses (skips private/reserved ranges)

=item * Uses cached results from F</var/lib/csf/{ip}.rbls> when available

=item * Performs DNS lookups via ConfigServer::RBLLookup for new checks

=item * Caches new results to avoid redundant lookups

=back

=head3 Example

    # Get report without printing
    my ($count, $html) = ConfigServer::RBLCheck::report(1, "/images", 0);
    if ($count > 0) {
        print "WARNING: $count IPs are listed on RBLs!\n";
        print $html;
    }

=cut

sub report {
    $verbose = shift;
    $images  = shift;
    $ui      = shift;
    my $config = ConfigServer::Config->loadconfig();
    my %config = $config->config();
    $cleanreg = ConfigServer::Slurp->cleanreg;
    $failures = 0;

    $| = 1;

    _startoutput();

    _getethdev();

    my @RBLS = slurp("/usr/local/csf/lib/csf.rbls");

    if ( -e "/etc/csf/csf.rblconf" ) {
        my @entries = slurp("/etc/csf/csf.rblconf");
        foreach my $line (@entries) {
            if ( $line =~ /^Include\s*(.*)$/ ) {
                my @incfile = slurp($1);
                push @entries, @incfile;
            }
        }
        foreach my $line (@entries) {
            $line =~ s/$cleanreg//g;
            if ( $line eq "" ) { next }
            if ( $line =~ /^\s*\#|Include/ ) { next }
            if ( $line =~ /^enablerbl:(.*)$/ ) {
                push @RBLS, $1;
            }
            elsif ( $line =~ /^disablerbl:(.*)$/ ) {
                my $hit = $1;
                for ( 0 .. @RBLS ) {
                    my $x = $_;
                    my ( $rbl, $rblurl ) = split( /:/, $RBLS[$x], 2 );
                    if ( $rbl eq $hit ) { $RBLS[$x] = "" }
                }
            }
            if ( $line =~ /^enableip:(.*)$/ ) {
                if ( checkip( \$1 ) ) { $ips{$1} = 1 }
            }
            elsif ( $line =~ /^disableip:(.*)$/ ) {
                if ( checkip( \$1 ) ) { delete $ips{$1} }
            }
        }
    }
    @RBLS = sort @RBLS;

    foreach my $ip ( sort keys %ips ) {
        my $netip = Net::IP->new($ip);
        my $type  = $netip->iptype();
        if ( $type eq "PUBLIC" ) {

            if ( $verbose and -e "/var/lib/csf/${ip}.rbls" ) {
                unlink "/var/lib/csf/${ip}.rbls";
            }

            if ( -e "/var/lib/csf/${ip}.rbls" ) {
                my $text = join( "\n", slurp("/var/lib/csf/${ip}.rbls") );
                if   ($ui) { print $text }
                else       { $output .= $text }
            }
            else {
                if ($verbose) {
                    $ipresult = "";
                    my $hits = 0;
                    _addtitle( "Checked $ip ($type) on " . localtime() );

                    foreach my $line (@RBLS) {
                        my ( $rbl, $rblurl ) = split( /:/, $line, 2 );
                        if ( $rbl eq "" ) { next }

                        my ( $rblhit, $rbltxt ) = rbllookup( $ip, $rbl );
                        my @tmptxt = $rbltxt;
                        $rbltxt = "";
                        foreach my $line (@tmptxt) {
                            next unless defined $line;
                            $line =~ s/(http(\S+))/<a target="_blank" href="$1">$1<\/a>/g;
                            $rbltxt .= "${line}\n";
                        }
                        $rbltxt =~ s/\n/<br>\n/g;

                        if ( $rblhit eq "timeout" ) {
                            _addline( 0, $rbl, $rblurl, "TIMEOUT" );
                        }
                        elsif ( $rblhit eq "" ) {
                            if ( $verbose == 2 ) {
                                _addline( 0, $rbl, $rblurl, "OK" );
                            }
                        }
                        else {
                            _addline( 1, $rbl, $rblurl, $rbltxt );
                            $hits++;
                        }
                    }
                    unless ($hits) {
                        my $text;
                        $text .= "<div style='clear: both;background: #BDECB6;padding: 8px;border: 1px solid #DDDDDD;'>OK</div>\n";
                        if   ($ui) { print $text }
                        else       { $output .= $text }
                        $ipresult .= $text;
                    }
                    sysopen( my $OUT, "/var/lib/csf/${ip}.rbls", Fcntl::O_WRONLY | Fcntl::O_CREAT );
                    flock( $OUT, Fcntl::LOCK_EX );
                    print $OUT $ipresult;
                    close($OUT);
                }
                else {
                    _addtitle("New $ip ($type)");
                    my $text;
                    $text .= "<div style='clear: both;background: #FFD1DC;padding: 8px;border: 1px solid #DDDDDD;'>Not Checked</div>\n";
                    if   ($ui) { print $text }
                    else       { $output .= $text }
                }
            }
        }
        else {
            if ( $verbose == 2 ) {
                _addtitle("Skipping $ip ($type)");
                my $text;
                $text .= "<div style='clear: both;background: #BDECB6;padding: 8px;border: 1px solid #DDDDDD;'>OK</div>\n";
                if   ($ui) { print $text }
                else       { $output .= $text }
            }
        }
    }
    _endoutput();

    return ( $failures, $output );
}

# end report
###############################################################################
# start _startoutput
sub _startoutput {
    return;
}

# end _startoutput
###############################################################################
# start _addline
sub _addline {
    my $status  = shift;
    my $rbl     = shift;
    my $rblurl  = shift;
    my $comment = shift;
    my $text;
    my $check = $rbl;
    if ( $rblurl ne "" ) { $check = "<a href='$rblurl' target='_blank'>$rbl</a>" }

    if ($status) {
        $text .= "<div style='display: flex;width: 100%;clear: both;'>\n";
        $text .= "<div style='width: 250px;background: #FFD1DC;padding: 8px;border-bottom: 1px solid #DDDDDD;border-left: 1px solid #DDDDDD;border-right: 1px solid #DDDDDD;'>$check</div>\n";
        $text .= "<div style='flex: 1;padding: 8px;border-bottom: 1px solid #DDDDDD;border-right: 1px solid #DDDDDD;'>$comment</div>\n";
        $text .= "</div>\n";
        $failures++;
        $ipresult .= $text;
    }
    elsif ($verbose) {
        $text .= "<div style='display: flex;width: 100%;clear: both;'>\n";
        $text .= "<div style='width: 250px;background: #BDECB6;padding: 8px;border-bottom: 1px solid #DDDDDD;border-left: 1px solid #DDDDDD;border-right: 1px solid #DDDDDD;'>$check</div>\n";
        $text .= "<div style='flex: 1;padding: 8px;border-bottom: 1px solid #DDDDDD;border-right: 1px solid #DDDDDD;'>$comment</div>\n";
        $text .= "</div>\n";
    }
    if   ($ui) { print $text }
    else       { $output .= $text }

    return;
}

# end _addline
###############################################################################
# start _addtitle
sub _addtitle {
    my $title = shift;
    my $text;

    $text .= "<br><div style='clear: both;padding: 8px;background: #F4F4EA;border: 1px solid #DDDDDD;border-top-right-radius: 5px;border-top-left-radius: 5px;'><strong>$title</strong></div>\n";

    $ipresult .= $text;
    if   ($ui) { print $text }
    else       { $output .= $text }

    return;
}

# end _addtitle
###############################################################################
# start _endoutput
sub _endoutput {
    if   ($ui) { print "<br>\n" }
    else       { $output .= "<br>\n" }

    return;
}

# end _endoutput
###############################################################################
# start _getethdev
sub _getethdev {
    my $ethdev = ConfigServer::GetEthDev->new();
    my %g_ipv4 = $ethdev->ipv4;
    my %g_ipv6 = $ethdev->ipv6;
    foreach my $key ( keys %g_ipv4 ) {
        $ips{$key} = 1;
    }

    #	if ($config{IPV6}) {
    #		foreach my $key (keys %g_ipv6) {
    #			eval {
    #				local $SIG{__DIE__} = undef;
    #				$ipscidr6->add($key);
    #			};
    #		}
    #	}

    return;
}

# end getethdev
###############################################################################

1;
