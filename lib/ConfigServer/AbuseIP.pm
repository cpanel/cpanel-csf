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

package ConfigServer::AbuseIP;

=head1 NAME

ConfigServer::AbuseIP - Look up abuse contact information for IP addresses

=head1 SYNOPSIS

    use ConfigServer::AbuseIP qw(abuseip);
    
    my ($contact, $message) = abuseip('192.0.2.1');
    
    if ($contact) {
        print "Abuse contact: $contact\n";
        print "Message:\n$message\n";
    }

=head1 DESCRIPTION

This module provides functionality to look up abuse contact information for 
IP addresses using the Abuse Contact Database provided by abusix.com. The 
database aggregates abuse contact information from Regional Internet Registries 
(RIRs) and makes it available via DNS TXT record lookups.

=cut

use strict;
use lib '/usr/local/csf/lib';
use Carp;
use IPC::Open3;
use Net::IP;
use ConfigServer::Config;
use ConfigServer::CheckIP qw(checkip);

use Exporter qw(import);
our $VERSION   = 1.03;
our @ISA       = qw(Exporter);
our @EXPORT_OK = qw(abuseip);

my $abusemsg = 'Abuse Contact for [ip]: [[contact]]

The Abuse Contact of this report was provided by the Abuse Contact DB by abusix.com. abusix.com does not maintain the content of the database. All information which we pass out, derives from the RIR databases and is processed for ease of use. If you want to change or report non working abuse contacts please contact the appropriate RIR. If you have any further question, contact abusix.com directly via email (info@abusix.com). Information about the Abuse Contact Database can be found here:

https://abusix.com/global-reporting/abuse-contact-db

abusix.com is neither responsible nor liable for the content or accuracy of this message.';

my $config = ConfigServer::Config->loadconfig();
my %config = $config->config();

=head2 abuseip

Looks up the abuse contact information for the given IP address using the Abuse 
Contact Database provided by abusix.com.

=over 4

=item B<Parameters>

=over 4

=item * C<$ip> - The IP address to look up (IPv4 or IPv6)

=back

=item B<Returns>

In scalar context: the abuse contact email address (or undef if not found)

In list context: a two-element list containing the abuse contact email address 
and a formatted message explaining the source of the contact information

=item B<Implementation>

The function performs DNS TXT record lookups against abuse-contacts.abusix.org 
after reversing the IP address format. It uses a 10-second timeout for the 
external host command.

=item B<Example>

    my ($contact, $msg) = abuseip('8.8.8.8');
    if ($contact) {
        print "Abuse contact: $contact\n";
    }

=back

=cut

sub abuseip {
    my $ip    = shift;
    my $abuse = "";
    my $netip;
    my $reversed_ip;

    if ( checkip( \$ip ) ) {
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
            $reversed_ip .= ".abuse-contacts.abusix.org";

            my $cmdpid;
            eval {
                local $SIG{__DIE__} = undef;
                local $SIG{'ALRM'}  = sub { die };
                alarm(10);
                my ( $childin, $childout );
                $cmdpid = open3( $childin, $childout, $childout, $config{HOST}, "-W", "5", "-t", "TXT", $reversed_ip );
                close $childin;
                my @results = <$childout>;
                waitpid( $cmdpid, 0 );
                chomp @results;
                if ( $results[0] =~ /^${reversed_ip}.+"(.*)"$/ ) { $abuse = $1 }
                alarm(0);
            };
            alarm(0);
            if ( $cmdpid =~ /\d+/ and $cmdpid > 1 and kill( 0, $cmdpid ) ) { kill( 9, $cmdpid ) }

            if ( $abuse ne "" ) {
                my $msg = $abusemsg;
                $msg =~ s/\[ip\]/$ip/g;
                $msg =~ s/\[contact\]/$abuse/g;
                return $abuse, $msg;
            }
        }
    }
}

1;

__END__

=head1 DEPENDENCIES

=over 4

=item * L<Net::IP> - For IP address manipulation and reversal

=item * L<IPC::Open3> - For executing external commands

=item * L<ConfigServer::Config> - For system configuration

=item * L<ConfigServer::CheckIP> - For IP address validation

=back

=head1 EXTERNAL SERVICES

This module queries the Abuse Contact Database provided by abusix.com:

=over 4

=item * B<Service:> abusix.com Abuse Contact DB

=item * B<Query Method:> DNS TXT record lookup

=item * B<Domain:> abuse-contacts.abusix.org

=item * B<Timeout:> 10 seconds

=back

=head1 SEE ALSO

=over 4

=item * L<https://abusix.com/global-reporting/abuse-contact-db>

=item * L<ConfigServer::CheckIP>

=item * L<Net::IP>

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
