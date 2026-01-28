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

ConfigServer::Sendmail - Email delivery via SMTP or sendmail binary

=head1 SYNOPSIS

    use ConfigServer::Sendmail ();

    # Send an email alert
    ConfigServer::Sendmail::relay($to, $from, @message_lines);

    # Using defaults from configuration
    ConfigServer::Sendmail::relay('', '', @message_lines);

=head1 DESCRIPTION

This module provides email delivery functionality for CSF (ConfigServer Security
& Firewall) alerts. It supports two delivery methods:

=over 4

=item * B<SMTP> - Direct SMTP delivery via Net::SMTP when C<LF_ALERT_SMTP> is configured

=item * B<sendmail> - Local sendmail binary when SMTP is not configured

=back

The module handles email address sanitization, header parsing and replacement,
and automatic text wrapping for long lines.

=head1 FUNCTIONS

=head2 relay

    ConfigServer::Sendmail::relay($to, $from, @message);

Sends an email message via SMTP or sendmail.

B<Parameters:>

=over 4

=item C<$to> - Recipient email address. If empty, uses C<LF_ALERT_TO> from config.

=item C<$from> - Sender email address. If empty, uses C<LF_ALERT_FROM> from config.

=item C<@message> - Array of message lines including headers and body.

=back

The message may contain placeholders:

=over 4

=item C<[time]> - Replaced with current timestamp and timezone

=item C<[hostname]> - Replaced with system hostname

=back

B<Returns:> Nothing (void).

=head1 CONFIGURATION

The following configuration values are used (via C<ConfigServer::Config>):

=over 4

=item C<LF_ALERT_SMTP> - SMTP server hostname. If set, uses SMTP delivery.

=item C<LF_ALERT_TO> - Default recipient email address.

=item C<LF_ALERT_FROM> - Default sender email address.

=item C<SENDMAIL> - Path to sendmail binary (used when SMTP not configured).

=item C<DEBUG> - If true, logs sendmail failures.

=back

=head1 SEE ALSO

L<ConfigServer::Config>, L<Net::SMTP>

=cut

package ConfigServer::Sendmail;

use cPstrict;

use Carp ();
use POSIX ();
use Net::SMTP ();

use ConfigServer::Config ();
use ConfigServer::Logger ();
use ConfigServer::Slurp ();

our $VERSION = 1.02;

sub _get_hostname {
    state $hostname;
    return $hostname if defined $hostname;

    my $proc_hostname = '/proc/sys/kernel/hostname';
    if ( -e $proc_hostname ) {
        my @lines = ConfigServer::Slurp::slurp($proc_hostname);
        $hostname = $lines[0];
        chomp $hostname if defined $hostname;
    }

    $hostname //= 'unknown';
    return $hostname;
}

sub _get_timezone {
    state $tz;
    return $tz if defined $tz;
    $tz = POSIX::strftime( '%z', localtime );
    return $tz;
}

sub relay {
    my ( $to, $from, @message ) = @_;
    my $time = localtime(time);

    my $lf_alert_to   = ConfigServer::Config->get_config('LF_ALERT_TO');
    my $lf_alert_from = ConfigServer::Config->get_config('LF_ALERT_FROM');
    my $lf_alert_smtp = ConfigServer::Config->get_config('LF_ALERT_SMTP');
    my $sendmail      = ConfigServer::Config->get_config('SENDMAIL');
    my $debug         = ConfigServer::Config->get_config('DEBUG');
    my $hostname      = _get_hostname();
    my $tz            = _get_timezone();

    if   ( $to eq '' ) { $to          = $lf_alert_to }
    else               { $lf_alert_to = $to }
    if   ( $from eq '' ) { $from          = $lf_alert_from }
    else                 { $lf_alert_from = $from }
    my $data;

    if ( $from =~ /([\w\.\=\-\_]+\@[\w\.\-\_]+)/ ) { $from = $1 }
    if ( $from eq '' )                             { $from = 'root' }
    if ( $to =~ /([\w\.\=\-\_]+\@[\w\.\-\_]+)/ )   { $to   = $1 }
    if ( $to eq '' )                               { $to   = 'root' }

    my $header = 1;
    foreach my $line (@message) {
        $line =~ s/\r//;
        if ( $line eq '' ) { $header = 0 }
        $line =~ s/\[time\]/$time $tz/ig;
        $line =~ s/\[hostname\]/$hostname/ig;
        if ($header) {
            if ( $line =~ /^To:\s*(.*)\s*$/i ) {
                my $totxt = $1;
                if ( $lf_alert_to ne '' ) {
                    $line =~ s/^To:.*$/To: $lf_alert_to/i;
                }
                else {
                    $to = $totxt;
                }
            }
            if ( $line =~ /^From:\s*(.*)\s*$/i ) {
                my $fromtxt = $1;
                if ( $lf_alert_from ne '' ) {
                    $line =~ s/^From:.*$/From: $lf_alert_from/i;
                }
                else {
                    $from = $1;
                }
            }
        }
        $data .= $line . "\n";
    }

    $data = _wraptext( $data, 990 );

    if ($lf_alert_smtp) {
        if ( $from !~ /\@/ ) { $from .= '@' . $hostname }
        if ( $to   !~ /\@/ ) { $to   .= '@' . $hostname }
        my $smtp = Net::SMTP->new( $lf_alert_smtp, Timeout => 10 ) or Carp::carp("Unable to send SMTP alert via [$lf_alert_smtp]: $!");
        if ( defined $smtp ) {
            $smtp->mail($from);
            $smtp->to($to);
            $smtp->data();
            $smtp->datasend($data);
            $smtp->dataend();
            $smtp->quit();
        }
    }
    else {
        local $SIG{CHLD} = 'DEFAULT';
        my $error = 0;
        open( my $MAIL, '|-', "$sendmail -f $from -t" ) or Carp::carp("Unable to send SENDMAIL alert via [$sendmail]: $!");
        print $MAIL $data;
        close($MAIL) or $error = 1;
        if ( $error and $debug ) {
            ConfigServer::Logger::logfile("Failed to send message via sendmail binary: $?");
            ConfigServer::Logger::logfile("Failed message: [$data]");
        }
    }

    return;
}

sub _wraptext {
    my $text     = shift;
    my $column   = shift;
    my $original = $text;
    my $return   = "";
    my $hit      = 1;
    my $loop     = 0;
    while ($hit) {
        $hit    = 0;
        $return = "";
        foreach my $line ( split( /\n/, $text ) ) {
            if ( length($line) > $column ) {
                foreach ( $line =~ /(.{1,$column})/g ) {
                    my $chunk    = $_;
                    my $newchunk = "";
                    my $thishit  = 0;
                    my @chars    = split( //, $chunk );
                    for ( my $x = length($chunk) - 1; $x >= 0; $x-- ) {
                        if ( $chars[$x] =~ /\s/ ) {
                            for ( 0 .. $x ) { $newchunk .= $chars[$_] }
                            $newchunk .= "\n";
                            for ( $x + 1 .. length($chunk) - 1 ) { $newchunk .= $chars[$_] }
                            $thishit = 1;
                            last;
                        }
                    }
                    if ($thishit) {
                        $hit     = 1;
                        $thishit = 0;
                        $return .= $newchunk;
                    }
                    else {
                        $return .= $chunk . "\n";
                    }
                }
            }
            else {
                $return .= $line . "\n";
            }
        }
        $text = $return;
        $loop++;
        if ( $loop > 1000 ) {
            return $original;
            last;
        }
    }
    if ( length($return) < length($original) ) { $return = $original }
    return $return;
}

1;

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
