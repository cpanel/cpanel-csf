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

package ConfigServer::DisplayResellerUI;

=head1 NAME

ConfigServer::DisplayResellerUI - Reseller web interface for CSF firewall
management

=head1 SYNOPSIS

    use ConfigServer::DisplayResellerUI ();

    my %form_data = (
        action  => 'qallow',
        ip      => '192.168.1.1',
        comment => 'Allow office IP',
    );

    ConfigServer::DisplayResellerUI::main(
        \%form_data,
        '/cgi/csf.cgi',
        0,
        '/images',
        '1.01'
    );

=head1 DESCRIPTION

This module provides a web-based interface for resellers to manage CSF
(ConfigServer Firewall) operations. It allows authorized reseller users to
perform limited firewall management tasks such as allowing IPs, blocking IPs,
unblocking IPs, and searching for IP addresses in iptables.

Reseller privileges are controlled through the C</etc/csf/csf.resellers>
configuration file, which defines what actions each reseller is permitted to
perform. Available privileges include ALLOW, DENY, UNBLOCK, GREP, and ALERT.

=cut

use cPstrict;

use Fcntl      ();
use POSIX      ();
use IPC::Open3 ();

use Cpanel::Encoder::Tiny ();

use ConfigServer::CheckIP  qw(checkip);
use ConfigServer::Sendmail ();
use ConfigServer::Logger   ();

our $VERSION = 1.01;

umask(0177);

our (
    %FORM,      $script, $script_da, $images, $myv, %rprivs, $hostname,
    $hostshort, $tz,     $panel
);

=head2 main

Renders the reseller web interface for CSF firewall management.

    ConfigServer::DisplayResellerUI::main(
        \%form_data,
        $script_path,
        $script_da,
        $images_path,
        $version
    );

=over 4

=item * C<$form_ref> - Hash reference containing form data with keys:

=over 4

=item * C<action> - Action to perform: 'qallow', 'qdeny', 'qkill', or 'grep'

=item * C<ip> - IP address to operate on

=item * C<comment> - Comment for allow/deny operations (required)

=item * C<mobi> - Mobile flag for form redirects

=back

=item * C<$script> - Script URL path for form actions

=item * C<$script_da> - DirectAdmin script path (unused in current version)

=item * C<images> - Path to images directory

=item * C<myv> - CSF version string

=back

The function performs the following operations based on user privileges:

=over 4

=item * B<Quick Allow> - Adds IP to csf.allow and allows through firewall

=item * B<Quick Deny> - Adds IP to csf.deny and blocks in firewall

=item * B<Quick Unblock> - Removes IP from both temporary and permanent blocks

=item * B<Search for IP> - Searches iptables rules for the specified IP

=back

All actions require appropriate privileges defined in
C</etc/csf/csf.resellers>. If ALERT privilege is enabled, email notifications
are sent for each action performed.

Returns nothing. Outputs HTML directly to STDOUT.

=cut

sub main {
    my $form_ref = shift;
    %FORM      = %{$form_ref};
    $script    = shift;
    $script_da = shift;
    $images    = shift;
    $myv       = shift;

    if ( open( my $IN, "<", "/etc/csf/csf.resellers" ) ) {
        flock( $IN, Fcntl::LOCK_SH ) if fileno($IN);
        while ( my $line = <$IN> ) {
            my ( $user, $alert, $privs ) = split( /\:/, $line );
            $privs //= '';
            $privs =~ s/\s//g;
            foreach my $priv ( split( /\,/, $privs ) ) {
                $rprivs{$user}{$priv} = 1;
            }
            $rprivs{$user}{ALERT} = $alert;
        }
        close($IN);
    }

    if ( open( my $HOSTNAME, "<", "/proc/sys/kernel/hostname" ) ) {
        flock( $HOSTNAME, Fcntl::LOCK_SH );
        $hostname = <$HOSTNAME>;
        chomp $hostname;
        close($HOSTNAME);
    }
    $hostshort = ( split( /\./, $hostname ) )[0];
    $tz        = POSIX::strftime( "%z", localtime );

    $panel = "cPanel";

    $FORM{ip}     //= '';
    $FORM{action} //= '';
    $FORM{mobi}   //= '';

    if ( $FORM{ip} ne "" ) { $FORM{ip} =~ s/(^\s+)|(\s+$)//g }

    if ( $FORM{action} ne "" and !checkip( \$FORM{ip} ) ) {
        print "<table class='table table-bordered table-striped'>\n";
        print "<tr><td>";
        print "[$FORM{ip}] is not a valid IP address\n";
        print "</td></tr></table>\n";
        print "<p><form action='$script' method='post'><input type='submit' class='btn btn-default' value='Return'></form></p>\n";
    }
    else {
        if ( $FORM{action} eq "qallow" and $rprivs{ $ENV{REMOTE_USER} }{ALLOW} ) {
            if ( $FORM{comment} eq "" ) {
                print "<table class='table table-bordered table-striped'>\n";
                print "<tr><td>You must provide a Comment for this option</td></tr></table>\n";
            }
            else {
                $FORM{comment} =~ s/"//g;
                print "<table class='table table-bordered table-striped'>\n";
                print "<tr><td>";
                print "<p>Allowing $FORM{ip}...</p>\n<p><pre style='font-family: Courier New, Courier; font-size: 12px'>\n";
                my $text = _printcmd( "/usr/sbin/csf", "-a", $FORM{ip}, "ALLOW by Reseller $ENV{REMOTE_USER} ($FORM{comment})" );
                print "</p>\n<p>...<b>Done</b>.</p>\n";
                print "</td></tr></table>\n";
                if ( $rprivs{ $ENV{REMOTE_USER} }{ALERT} ) {
                    open( my $IN, "<", "/usr/local/csf/tpl/reselleralert.txt" );
                    flock( $IN, Fcntl::LOCK_SH );
                    my @alert = <$IN>;
                    close($IN);
                    chomp @alert;

                    my @message;
                    foreach my $line (@alert) {
                        $line =~ s/\[reseller\]/$ENV{REMOTE_USER}/ig;
                        $line =~ s/\[action\]/ALLOW/ig;
                        $line =~ s/\[ip\]/$FORM{ip}/ig;
                        $line =~ s/\[rip\]/$ENV{REMOTE_HOST}/ig;
                        $line =~ s/\[text\]/Result of ALLOW:\n\n$text/ig;
                        push @message, $line;
                    }
                    ConfigServer::Sendmail::relay( "", "", @message );
                }
                ConfigServer::Logger::logfile("$panel Reseller [$ENV{REMOTE_USER}]: ALLOW $FORM{ip}");
            }
            print "<p><form action='$script' method='post'><input type='hidden' name='mobi' value='$FORM{mobi}'><input type='submit' class='btn btn-default' value='Return'></form></p>\n";
        }
        elsif ( $FORM{action} eq "qdeny" and $rprivs{ $ENV{REMOTE_USER} }{DENY} ) {
            if ( $FORM{comment} eq "" ) {
                print "<table class='table table-bordered table-striped'>\n";
                print "<tr><td>You must provide a Comment for this option</td></tr></table>\n";
            }
            else {
                $FORM{comment} =~ s/"//g;
                print "<table class='table table-bordered table-striped'>\n";
                print "<tr><td>";
                print "<p>Blocking $FORM{ip}...</p>\n<p><pre style='font-family: Courier New, Courier; font-size: 12px'>\n";
                my $text = _printcmd( "/usr/sbin/csf", "-d", $FORM{ip}, "DENY by Reseller $ENV{REMOTE_USER} ($FORM{comment})" );
                print "</p>\n<p>...<b>Done</b>.</p>\n";
                print "</td></tr></table>\n";
                if ( $rprivs{ $ENV{REMOTE_USER} }{ALERT} ) {
                    open( my $IN, "<", "/usr/local/csf/tpl/reselleralert.txt" );
                    flock( $IN, Fcntl::LOCK_SH );
                    my @alert = <$IN>;
                    close($IN);
                    chomp @alert;

                    my @message;
                    foreach my $line (@alert) {
                        $line =~ s/\[reseller\]/$ENV{REMOTE_USER}/ig;
                        $line =~ s/\[action\]/DENY/ig;
                        $line =~ s/\[ip\]/$FORM{ip}/ig;
                        $line =~ s/\[rip\]/$ENV{REMOTE_HOST}/ig;
                        $line =~ s/\[text\]/Result of DENY:\n\n$text/ig;
                        push @message, $line;
                    }
                    ConfigServer::Sendmail::relay( "", "", @message );
                }
                ConfigServer::Logger::logfile("$panel Reseller [$ENV{REMOTE_USER}]: DENY $FORM{ip}");
            }
            print "<p><form action='$script' method='post'><input type='hidden' name='mobi' value='$FORM{mobi}'><input type='submit' class='btn btn-default' value='Return'></form></p>\n";
        }
        elsif ( $FORM{action} eq "qkill" and $rprivs{ $ENV{REMOTE_USER} }{UNBLOCK} ) {
            my $text = "";
            if ( $rprivs{ $ENV{REMOTE_USER} }{ALERT} ) {
                my ( $childin, $childout );
                my $pid = IPC::Open3::open3( $childin, $childout, $childout, "/usr/sbin/csf", "-g", $FORM{ip} );
                while (<$childout>) { $text .= $_ }
                waitpid( $pid, 0 );
            }
            print "<table class='table table-bordered table-striped'>\n";
            print "<tr><td>";
            print "<p>Unblock $FORM{ip}, trying permanent blocks...</p>\n<p><pre style='font-family: Courier New, Courier; font-size: 12px'>\n";
            my $text1 = _printcmd( "/usr/sbin/csf", "-dr", $FORM{ip} );
            print "</p>\n<p>...<b>Done</b>.</p>\n";
            print "<p>Unblock $FORM{ip}, trying temporary blocks...</p>\n<p><pre style='font-family: Courier New, Courier; font-size: 12px'>\n";
            my $text2 = _printcmd( "/usr/sbin/csf", "-tr", $FORM{ip} );
            print "</p>\n<p>...<b>Done</b>.</p>\n";
            print "</td></tr></table>\n";
            print "<p><form action='$script' method='post'><input type='hidden' name='mobi' value='$FORM{mobi}'><input type='submit' class='btn btn-default' value='Return'></form></p>\n";

            if ( $rprivs{ $ENV{REMOTE_USER} }{ALERT} ) {
                open( my $IN, "<", "/usr/local/csf/tpl/reselleralert.txt" );
                flock( $IN, Fcntl::LOCK_SH );
                my @alert = <$IN>;
                close($IN);
                chomp @alert;

                my @message;
                foreach my $line (@alert) {
                    $line =~ s/\[reseller\]/$ENV{REMOTE_USER}/ig;
                    $line =~ s/\[action\]/UNBLOCK/ig;
                    $line =~ s/\[ip\]/$FORM{ip}/ig;
                    $line =~ s/\[rip\]/$ENV{REMOTE_HOST}/ig;
                    $line =~ s/\[text\]/Result of GREP before UNBLOCK:\n$text\n\nResult of UNBLOCK:\nPermanent:\n$text1\nTemporary:\n$text2\n/ig;
                    push @message, $line;
                }
                ConfigServer::Sendmail::relay( "", "", @message );
            }
            ConfigServer::Logger::logfile("$panel Reseller [$ENV{REMOTE_USER}]: UNBLOCK $FORM{ip}");
        }
        elsif ( $FORM{action} eq "grep" and $rprivs{ $ENV{REMOTE_USER} }{GREP} ) {
            print "<table class='table table-bordered table-striped'>\n";
            print "<tr><td>";
            print "<p>Searching for $FORM{ip}...</p>\n<p><pre style='font-family: Courier New, Courier; font-size: 12px'>\n";
            _printcmd( "/usr/sbin/csf", "-g", $FORM{ip} );
            print "</p>\n<p>...<b>Done</b>.</p>\n";
            print "</td></tr></table>\n";
            print "<p><form action='$script' method='post'><input type='submit' class='btn btn-default' value='Return'></form></p>\n";
        }
        else {
            $ENV{REMOTE_USER} //= '';
            print "<table class='table table-bordered table-striped'>\n";
            print "<thead><tr><th align='left' colspan='2'>csf - ConfigServer Firewall options for $ENV{REMOTE_USER}</th></tr></thead>";
            if ( $rprivs{ $ENV{REMOTE_USER} }{ALLOW} ) {
                print
                  "<tr><td><form action='$script' method='post'><input type='hidden' name='action' value='qallow'><input type='submit' class='btn btn-default' value='Quick Allow'></td><td width='100%'>Allow IP address <input type='text' name='ip' id='allowip' value='' size='18' style='background-color: lightgreen'> through the firewall and add to the allow file (csf.allow).<br>Comment for Allow: <input type='text' name='comment' value='' size='30'> (required)</form></td></tr>\n";
            }
            if ( $rprivs{ $ENV{REMOTE_USER} }{DENY} ) {
                print
                  "<tr><td><form action='$script' method='post'><input type='hidden' name='action' value='qdeny'><input type='submit' class='btn btn-default' value='Quick Deny'></td><td width='100%'>Block IP address <input type='text' name='ip' value='' size='18' style='background-color: pink'> in the firewall and add to the deny file (csf.deny).<br>Comment for Block: <input type='text' name='comment' value='' size='30'> (required)</form></td></tr>\n";
            }
            if ( $rprivs{ $ENV{REMOTE_USER} }{UNBLOCK} ) { print "<tr><td><form action='$script' method='post'><input type='hidden' name='action' value='qkill'><input type='submit' class='btn btn-default' value='Quick Unblock'></td><td width='100%'>Remove IP address <input type='text' name='ip' value='' size='18'> from the firewall (temp and perm blocks)</form></td></tr>\n" }
            if ( $rprivs{ $ENV{REMOTE_USER} }{GREP} )    { print "<tr><td><form action='$script' method='post'><input type='hidden' name='action' value='grep'><input type='submit' class='btn btn-default' value='Search for IP'></td><td width='100%'>Search iptables for IP address <input type='text' name='ip' value='' size='18'></form></td></tr>\n" }
            print "</table><br>\n";
        }
    }

    print "<br>\n";
    print "<pre>csf: v$myv</pre>";
    print "<p>&copy;2006-2023, <a href='http://www.configserver.com' target='_blank'>ConfigServer Services</a> (Jonathan Michaelson)</p>\n";

    return;
}

sub _printcmd {
    my @command = @_;
    my $text;
    my ( $childin, $childout );
    my $pid = IPC::Open3::open3( $childin, $childout, $childout, @command );
    while (<$childout>) {
        my $line = Cpanel::Encoder::Tiny::safe_html_encode_str($_);
        print $line;
        $text .= $line;
    }
    waitpid( $pid, 0 );
    return $text;
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

This program is distributed in the hope that it will be useful, but WITHOUT
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
FOR A PARTICULAR PURPOSE. See the GNU General Public License for more
details.

You should have received a copy of the GNU General Public License along with
this program; if not, see L<https://www.gnu.org/licenses>.

=cut
