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

package ConfigServer::RegexMain;

=head1 NAME

ConfigServer::RegexMain - Log file pattern matching and processing for CSF

=head1 SYNOPSIS

    use ConfigServer::RegexMain ();

    my %globlogs = (
        SSHD_LOG  => { '/var/log/secure' => 1 },
        IMAPD_LOG => { '/var/log/maillog' => 1 },
    );

    my ($reason, $ip, $app) = ConfigServer::RegexMain::processline(
        $log_line,
        $logfile_path,
        \%globlogs
    );

    if ($reason) {
        print "Detected: $reason from $ip (app: $app)\n";
    }

=head1 DESCRIPTION

ConfigServer::RegexMain provides log file pattern matching and processing
functionality for ConfigServer Security & Firewall (CSF). It analyzes log
lines from various services (SSH, FTP, SMTP, HTTP, etc.) and extracts
security-relevant information such as failed login attempts, successful
logins, and suspicious activities.

This module is primarily used by the Login Failure Daemon (lfd.pl) to
monitor system logs and trigger appropriate security responses.

=head1 FUNCTIONS

=cut

use cPstrict;

use IPC::Open3 ();

use ConfigServer::Config    ();
use ConfigServer::Logger    ();
use ConfigServer::GetEthDev ();
use ConfigServer::CheckIP   qw(checkip);

use Cpanel::Config::LoadWwwAcctConf ();

our $VERSION = 1.03;

our ( %config, %globlogs, %brd, %ips );

sub _config {
    return if %config;

    my $config = ConfigServer::Config->loadconfig();
    %config = $config->config;

    if ( $config{LF_APACHE_ERRPORT} == 0 ) {
        my $apachebin = "";
        if    ( -e "/usr/local/apache/bin/httpd" ) { $apachebin = "/usr/local/apache/bin/httpd" }
        elsif ( -e "/usr/sbin/httpd" )             { $apachebin = "/usr/sbin/httpd" }
        elsif ( -e "/usr/sbin/apache2" )           { $apachebin = "/usr/sbin/apache2" }
        elsif ( -e "/usr/sbin/httpd2" )            { $apachebin = "/usr/sbin/httpd2" }
        if    ( -e $apachebin ) {
            my ( $childin, $childout );
            my $mypid   = IPC::Open3::open3( $childin, $childout, $childout, $apachebin, "-v" );
            my @version = <$childout>;
            waitpid( $mypid, 0 );
            chomp @version;
            $version[0] =~ /Apache\/(\d+)\.(\d+)\.(\d+)/;
            my $mas = $1;
            my $maj = $2;
            my $min = $3;
            if ( "$mas.$maj" < 2.4 ) { $config{LF_APACHE_ERRPORT} = 1 }
        }
    }
    unless ( $config{LF_APACHE_ERRPORT} == 1 ) {
        $config{LF_APACHE_ERRPORT} = 2;
    }

    ConfigServer::Logger::logfile("LF_APACHE_ERRPORT: Set to [$config{LF_APACHE_ERRPORT}]");

    return;
}

sub _eth_info {
    return if %brd or %ips;    # Loaded already.

    my $ethdev = ConfigServer::GetEthDev->new();
    %brd = $ethdev->brd;
    %ips = $ethdev->ipv4;
    return;
}

if ( -e "/usr/local/csf/bin/regex.custom.pm" ) {

    # Pre-load these in the event something was manipulating it.
    _config();
    _eth_info();

    require "/usr/local/csf/bin/regex.custom.pm";    ## no critic (Modules::RequireBarewordIncludes)
}

=head2 processline

Processes a single log line to detect failed authentication attempts and
security events.

    my ($reason, $ip, $app, $trigger, $ports, $temp, $cf) =
        ConfigServer::RegexMain::processline($line, $logfile, \%globlogs);

Arguments:

=over 4

=item * C<$line> - The log line to process

=item * C<$logfile> - Path to the log file being processed

=item * C<\%globlogs> - Hash reference mapping log types to file paths

=back

Returns a list of values when a match is found:

=over 4

=item * C<$reason> - Description of the event (e.g., "Failed SSH login from")

=item * C<$ip> - IP address involved (may include account name as "ip|account")

=item * C<$app> - Application/service name (e.g., "sshd", "pop3d")

=item * C<$trigger> - Custom trigger (from regex.custom.pm)

=item * C<$ports> - Port numbers (from custom rules)

=item * C<$temp> - Temporary block flag (from custom rules)

=item * C<$cf> - CloudFlare flag (from custom rules)

=back

Returns empty list if no match found.

=cut

sub processline {
    my $line         = shift;
    my $lgfile       = shift;
    my $globlogs_ref = shift;
    %globlogs = %{$globlogs_ref};

    $line =~ s/\n//g;
    $line =~ s/\r//g;

    if ( -e "/usr/local/csf/bin/regex.custom.pm" ) {
        my ( $text, $ip, $app, $trigger, $ports, $temp, $cf ) = custom_line( $line, $lgfile );
        if ($text) {
            return ( $text, $ip, $app, $trigger, $ports, $temp, $cf );
        }
    }

    # Be sure %config is loaded.
    _config();

    #openSSH
    #RH
    if ( ( $config{LF_SSHD} ) and ( ( $lgfile eq "/var/log/messages" ) or ( $lgfile eq "/var/log/secure" ) or ( $globlogs{SSHD_LOG}{$lgfile} ) ) and ( $line =~ /^(\S+|\S+\s+\d+\s+\S+) (\S+ )?sshd\[\d+\]: pam_unix\(sshd:auth\): authentication failure; logname=\S* uid=\S* euid=\S* tty=\S* ruser=\S* rhost=(\S+)\s+(user=(\S+))?/ ) ) {
        my $ip  = $3;
        my $acc = $5;
        $ip =~ s/^::ffff://;
        if ( checkip( \$ip ) ) { return ( "Failed SSH login from", "$ip|$acc", "sshd" ) }
        else                   { return }
    }
    if ( ( $config{LF_SSHD} ) and ( ( $lgfile eq "/var/log/messages" ) or ( $lgfile eq "/var/log/secure" ) or ( $globlogs{SSHD_LOG}{$lgfile} ) ) and ( $line =~ /^(\S+|\S+\s+\d+\s+\S+) (\S+ )?sshd\[\d+\]: Failed none for (\S*) from (\S+) port \S+/ ) ) {
        my $ip  = $4;
        my $acc = $3;
        $ip =~ s/^::ffff://;
        if ( checkip( \$ip ) ) { return ( "Failed SSH login from", "$ip|$acc", "sshd" ) }
        else                   { return }
    }
    if ( ( $config{LF_SSHD} ) and ( ( $lgfile eq "/var/log/messages" ) or ( $lgfile eq "/var/log/secure" ) or ( $globlogs{SSHD_LOG}{$lgfile} ) ) and ( $line =~ /^(\S+|\S+\s+\d+\s+\S+) (\S+ )?sshd\[\d+\]: Failed password for (invalid user |illegal user )?(\S*) from (\S+)( port \S+ \S+\s*)?/ ) ) {
        my $ip  = $5;
        my $acc = $4;
        $ip =~ s/^::ffff://;
        if ( checkip( \$ip ) ) { return ( "Failed SSH login from", "$ip|$acc", "sshd" ) }
        else                   { return }
    }
    if ( ( $config{LF_SSHD} ) and ( ( $lgfile eq "/var/log/messages" ) or ( $lgfile eq "/var/log/secure" ) or ( $globlogs{SSHD_LOG}{$lgfile} ) ) and ( $line =~ /^(\S+|\S+\s+\d+\s+\S+) (\S+ )?sshd\[\d+\]: Failed keyboard-interactive(\/pam)? for (invalid user )?(\S*) from (\S+) port \S+/ ) ) {
        my $ip  = $6;
        my $acc = $4;
        $ip =~ s/^::ffff://;
        if ( checkip( \$ip ) ) { return ( "Failed SSH login from", "$ip|$acc", "sshd" ) }
        else                   { return }
    }
    if ( ( $config{LF_SSHD} ) and ( ( $lgfile eq "/var/log/messages" ) or ( $lgfile eq "/var/log/secure" ) or ( $globlogs{SSHD_LOG}{$lgfile} ) ) and ( $line =~ /^(\S+|\S+\s+\d+\s+\S+) (\S+ )?sshd\[\d+\]: Invalid user (\S*) from (\S+)/ ) ) {
        my $ip  = $4;
        my $acc = $3;
        $ip =~ s/^::ffff://;
        if ( checkip( \$ip ) ) { return ( "Failed SSH login from", "$ip|$acc", "sshd" ) }
        else                   { return }
    }
    if ( ( $config{LF_SSHD} ) and ( ( $lgfile eq "/var/log/messages" ) or ( $lgfile eq "/var/log/secure" ) or ( $globlogs{SSHD_LOG}{$lgfile} ) ) and ( $line =~ /^(\S+|\S+\s+\d+\s+\S+) (\S+ )?sshd\[\d+\]: User (\S*) from (\S+)\s* not allowed because not listed in AllowUsers/ ) ) {
        my $ip  = $4;
        my $acc = $3;
        $ip =~ s/^::ffff://;
        if ( checkip( \$ip ) ) { return ( "Failed SSH login from", "$ip|$acc", "sshd" ) }
        else                   { return }
    }
    if ( ( $config{LF_SSHD} ) and ( ( $lgfile eq "/var/log/messages" ) or ( $lgfile eq "/var/log/secure" ) or ( $globlogs{SSHD_LOG}{$lgfile} ) ) and ( $line =~ /^(\S+|\S+\s+\d+\s+\S+) (\S+ )?sshd\[\d+\]: Did not receive identification string from (\S+)/ ) ) {
        my $ip  = $3;
        my $acc = "";
        $ip =~ s/^::ffff://;
        if ( checkip( \$ip ) ) { return ( "Failed SSH login from", "$ip|$acc", "sshd" ) }
        else                   { return }
    }
    if ( ( $config{LF_SSHD} ) and ( ( $lgfile eq "/var/log/messages" ) or ( $lgfile eq "/var/log/secure" ) or ( $globlogs{SSHD_LOG}{$lgfile} ) ) and ( $line =~ /^(\S+|\S+\s+\d+\s+\S+) (\S+ )?sshd\[\d+\]: refused connect from (\S+)/ ) ) {
        my $ip  = $3;
        my $acc = "";
        $ip =~ s/^::ffff://;
        if ( checkip( \$ip ) ) { return ( "Failed SSH login from", "$ip|$acc", "sshd" ) }
        else                   { return }
    }
    if ( ( $config{LF_SSHD} ) and ( ( $lgfile eq "/var/log/messages" ) or ( $lgfile eq "/var/log/secure" ) or ( $globlogs{SSHD_LOG}{$lgfile} ) ) and ( $line =~ /^(\S+|\S+\s+\d+\s+\S+) (\S+ )?sshd\[\d+\]: error: maximum authentication attempts exceeded for (\S*) from (\S+)/ ) ) {
        my $ip  = $4;
        my $acc = "";
        $ip =~ s/^::ffff://;
        if ( checkip( \$ip ) ) { return ( "Failed SSH login from", "$ip|$acc", "sshd" ) }
        else                   { return }
    }

    #Debian/Ubuntu
    if ( ( $config{LF_SSHD} ) and ( ( $lgfile eq "/var/log/messages" ) or ( $lgfile eq "/var/log/secure" ) or ( $globlogs{SSHD_LOG}{$lgfile} ) ) and ( $line =~ /^(\S+|\S+\s+\d+\s+\S+) (\S+ )?sshd\[\d+\]: Illegal user (\S*) from (\S+)/ ) ) {
        my $ip  = $4;
        my $acc = $3;
        $ip =~ s/^::ffff://;
        if ( checkip( \$ip ) ) { return ( "Failed SSH login from", "$ip|$acc", "sshd" ) }
        else                   { return }
    }

    #dovecot
    if ( ( $config{LF_POP3D} ) and ( $globlogs{POP3D_LOG}{$lgfile} ) and ( $line =~ /^(\S+|\S+\s+\d+\s+\S+) \S+ dovecot(\[\d+\])?: pop3-login: (Disconnected: )?(Aborted login( by logging out)?|Connection closed|Disconnected|Disconnected: Inactivity)(:\s*\S+\sfailed: Connection reset by peer)?(\s*\(auth failed, \d+ attempts( in \d+ secs)?\))?: (user=(<\S*>)?, )?(method=\S+, )?rip=(\S+), lip=/ ) ) {
        my $ip  = $12;
        my $acc = $10;
        $ip  =~ s/^::ffff://;
        $acc =~ s/^<|>$//g;
        if ( checkip( \$ip ) ) { return ( "Failed POP3 login from", "$ip|$acc", "pop3d" ) }
        else                   { return }
    }
    if ( ( $config{LF_IMAPD} ) and ( $globlogs{IMAPD_LOG}{$lgfile} ) and ( $line =~ /^(\S+|\S+\s+\d+\s+\S+) \S+ dovecot(\[\d+\])?: imap-login: (Disconnected: )?(Aborted login( by logging out)?|Connection closed|Disconnected|Disconnected: Inactivity)(:\s*\S+\sfailed: Connection reset by peer)?(\s*\(auth failed, \d+ attempts( in \d+ secs)?\))?: (user=(<\S*>)?, )?(method=\S+, )?rip=(\S+), lip=/ ) ) {
        my $ip  = $12;
        my $acc = $10;
        $ip  =~ s/^::ffff://;
        $acc =~ s/^<|>$//g;
        if ( checkip( \$ip ) ) { return ( "Failed IMAP login from", "$ip|$acc", "imapd" ) }
        else                   { return }
    }
    if ( ( $config{LF_POP3D} ) and ( $globlogs{POP3D_LOG}{$lgfile} ) and ( $line =~ /^(\S+|\S+\s+\d+\s+\S+) pop3-login(\[\d+\])?: Info: (Aborted login( by logging out)?|Connection closed|Disconnected|Disconnected: Inactivity)(\s*\(auth failed, \d+ attempts( in \d+ secs)?\))?: (user=(<\S*>)?, )?(method=\S+, )?rip=(\S+), lip=/ ) ) {
        my $ip  = $10;
        my $acc = $8;
        $ip  =~ s/^::ffff://;
        $acc =~ s/^<|>$//g;
        if ( checkip( \$ip ) ) { return ( "Failed POP3 login from", "$ip|$acc", "pop3d" ) }
        else                   { return }
    }
    if ( ( $config{LF_IMAPD} ) and ( $globlogs{IMAPD_LOG}{$lgfile} ) and ( $line =~ /^(\S+|\S+\s+\d+\s+\S+) imap-login(\[\d+\])?: Info: (Aborted login( by logging out)?|Connection closed|Disconnected|Disconnected: Inactivity)(\s*\(auth failed, \d+ attempts( in \d+ secs)?\))?: (user=(<\S*>)?, )?(method=\S+, )?rip=(\S+), lip=/ ) ) {
        my $ip  = $10;
        my $acc = $8;
        $ip  =~ s/^::ffff://;
        $acc =~ s/^<|>$//g;
        if ( checkip( \$ip ) ) { return ( "Failed IMAP login from", "$ip|$acc", "imapd" ) }
        else                   { return }
    }

    #pure-ftpd
    #Nov 10 04:28:04 w212 pure-ftpd[3269638]: (?@152.57.198.52) [WARNING] Authentication failed for user [www]
    if ( ( $config{LF_FTPD} ) and ( $globlogs{FTPD_LOG}{$lgfile} ) and ( $line =~ /^(\S+|\S+\s+\d+\s+\S+) \S+ pure-ftpd(\[\d+\])?: \(\?\@(\S+)\) \[WARNING\] Authentication failed for user \[(\S*)\]/ ) ) {
        my $ip  = $3;
        my $acc = $4;
        $ip =~ s/^::ffff://;
        $ip =~ s/\_/\:/g;
        if ( checkip( \$ip ) ) { return ( "Failed FTP login from", "$ip|$acc", "ftpd" ) }
        else                   { return }
    }

    #proftpd
    if ( ( $config{LF_FTPD} ) and ( $globlogs{FTPD_LOG}{$lgfile} ) and ( $line =~ /^(\S+|\S+\s+\d+\s+\S+) \S+ proftpd\[\d+\]:? \S+ \([^\[]+\[(\S+)\]\)( -)?:? - no such user \'(\S*)\'/ ) ) {
        my $ip  = $2;
        my $acc = $4;
        $ip  =~ s/^::ffff://;
        $acc =~ s/:$//g;
        if ( checkip( \$ip ) ) { return ( "Failed FTP login from", "$ip|$acc", "ftpd" ) }
        else                   { return }
    }
    if ( ( $config{LF_FTPD} ) and ( $globlogs{FTPD_LOG}{$lgfile} ) and ( $line =~ /^(\S+|\S+\s+\d+\s+\S+) \S+ proftpd\[\d+\]:? \S+ \([^\[]+\[(\S+)\]\)( -)?:? USER (\S*) no such user found from/ ) ) {
        my $ip  = $2;
        my $acc = $4;
        $ip  =~ s/^::ffff://;
        $acc =~ s/:$//g;
        if ( checkip( \$ip ) ) { return ( "Failed FTP login from", "$ip|$acc", "ftpd" ) }
        else                   { return }
    }
    if ( ( $config{LF_FTPD} ) and ( $globlogs{FTPD_LOG}{$lgfile} ) and ( $line =~ /^(\S+|\S+\s+\d+\s+\S+) \S+ proftpd\[\d+\]:? \S+ \([^\[]+\[(\S+)\]\)( -)?:? - SECURITY VIOLATION/ ) ) {
        my $ip  = $2;
        my $acc = "";
        $ip  =~ s/^::ffff://;
        $acc =~ s/:$//g;
        if ( checkip( \$ip ) ) { return ( "Failed FTP login from", "$ip|$acc", "ftpd" ) }
        else                   { return }
    }
    if ( ( $config{LF_FTPD} ) and ( $globlogs{FTPD_LOG}{$lgfile} ) and ( $line =~ /^(\S+|\S+\s+\d+\s+\S+) \S+ proftpd\[\d+\]:? \S+ \([^\[]+\[(\S+)\]\)( -)?:? - USER (\S*) \(Login failed\): Incorrect password/ ) ) {
        my $ip  = $2;
        my $acc = $4;
        $ip  =~ s/^::ffff://;
        $acc =~ s/:$//g;
        if ( checkip( \$ip ) ) { return ( "Failed FTP login from", "$ip|$acc", "ftpd" ) }
        else                   { return }
    }

    #vsftpd
    if ( ( $config{LF_FTPD} ) and ( $globlogs{FTPD_LOG}{$lgfile} ) and ( $line =~ /^\S+\s+\S+\s+\d+\s+\S+\s+\d+ \[pid \d+] \[(\S+)\] FAIL LOGIN: Client "(\S+)"/ ) ) {
        my $ip  = $2;
        my $acc = $1;
        $ip =~ s/^::ffff://;
        if ( checkip( \$ip ) ) { return ( "Failed FTP login from", "$ip|$acc", "ftpd" ) }
        else                   { return }
    }
    if ( ( $config{LF_FTPD} ) and ( $globlogs{FTPD_LOG}{$lgfile} ) and ( $line =~ /^(\S+|\S+\s+\d+\s+\S+) \S+ vsftpd\[\d+\]: pam_unix\(\S+\): authentication failure; logname=\S*\s+\S+\s+\S+\s+\S+\s+ruser=\S*\s+rhost=(\S+)(\s+user=(\S*))?/ ) ) {
        my $ip  = $2;
        my $acc = $4;
        $ip =~ s/^::ffff://;
        if ( checkip( \$ip ) ) { return ( "Failed FTP login from", "$ip|$acc", "ftpd" ) }
        else                   { return }
    }
    if ( ( $config{LF_FTPD} ) and ( $globlogs{FTPD_LOG}{$lgfile} ) and ( $line =~ /^(\S+|\S+\s+\d+\s+\S+) \S+ vsftpd\(pam_unix\)\[\d+\]: authentication failure; logname=\S*\s+\S+\s+\S+\s+\S+\s+ruser=\S*\s+rhost=(\S+)(\s+user=(\S*))?/ ) ) {
        my $ip  = $2;
        my $acc = $4;
        $ip =~ s/^::ffff://;
        if ( checkip( \$ip ) ) { return ( "Failed FTP login from", "$ip|$acc", "ftpd" ) }
        else                   { return }
    }

    #apache htaccess
    if ( ( $config{LF_HTACCESS} ) and ( $globlogs{HTACCESS_LOG}{$lgfile} ) and ( $line =~ /^\[\S+\s+\S+\s+\S+\s+\S+\s+\S+\] \[(\S*:)?error\] (\[pid \d+(:tid \d+)?\] )?\[(client|remote) (\S+)\] (\w+: )?user (\S*)(( not found:)|(: authentication failure for))/ ) ) {
        my $ip  = $5;
        my $acc = $7;
        $ip =~ s/^::ffff://;
        if   ( $config{LF_APACHE_ERRPORT} == 2 and $ip =~ /(.*):\d+$/ ) { $ip = $1 }
        if   ( checkip( \$ip ) )                                        { return ( "Failed web page login from", "$ip|$acc", "htpasswd" ) }
        else                                                            { return }
    }

    #nginx
    if ( ( $config{LF_HTACCESS} ) and ( $globlogs{HTACCESS_LOG}{$lgfile} ) and ( $line =~ /^\S+ \S+ \[error\] \S+ \*\S+ no user\/password was provided for basic authentication, client: (\S+),/ ) ) {
        my $ip  = $1;
        my $acc = "";
        $ip =~ s/^::ffff://;
        if ( checkip( \$ip ) ) { return ( "Failed web page login from", "$ip|$acc", "htpasswd" ) }
        else                   { return }
    }
    if ( ( $config{LF_HTACCESS} ) and ( $globlogs{HTACCESS_LOG}{$lgfile} ) and ( $line =~ /^\S+ \S+ \[error\] \S+ \*\S+ user \"(\S*)\": password mismatch, client: (\S+),/ ) ) {
        my $ip  = $2;
        my $acc = $1;
        $ip =~ s/^::ffff://;
        if ( checkip( \$ip ) ) { return ( "Failed web page login from", "$ip|$acc", "htpasswd" ) }
        else                   { return }
    }
    if ( ( $config{LF_HTACCESS} ) and ( $globlogs{HTACCESS_LOG}{$lgfile} ) and ( $line =~ /^\S+ \S+ \[error\] \S+ \*\S+ user \"(\S*)\" was not found in \".*?\", client: (\S+),/ ) ) {
        my $ip  = $2;
        my $acc = $1;
        $ip =~ s/^::ffff://;
        if ( checkip( \$ip ) ) { return ( "Failed web page login from", "$ip|$acc", "htpasswd" ) }
        else                   { return }
    }

    #cxs Apache
    if ( ( $config{LF_CXS} ) and ( $globlogs{MODSEC_LOG}{$lgfile} ) and ( $line =~ /^\[\S+\s+\S+\s+\S+\s+\S+\s+\S+\] \[(\S*:)?error\] (\[pid \d+(:tid \d+)?\] )?\[(client|remote) (\S+)\]( \[client \S+\])? (\w+: )?ModSecurity:(( \[[^]]+\])*)? Access denied with code \d\d\d \(phase 2\)\. File \"[^\"]*\" rejected by the approver script \"\/etc\/cxs\/cxscgi\.sh\"/ ) ) {
        my $ip     = $5;
        my $acc    = "";
        my $domain = "";
        if ( $line =~ /\] \[hostname "([^\"]+)"\] \[/ ) { $domain = $1 }
        $ip =~ s/^::ffff://;
        if   ( $config{LF_APACHE_ERRPORT} == 2 and $ip =~ /(.*):\d+$/ ) { $ip = $1 }
        if   ( checkip( \$ip ) )                                        { return ( "cxs mod_security triggered by", "$ip|$acc|$domain", "cxs" ) }
        else                                                            { return }
    }

    #cxs Litespeed
    if ( ( $config{LF_CXS} ) and ( $globlogs{MODSEC_LOG}{$lgfile} ) and ( $line =~ /^\[\S+\s+\S+\s+\S+\s+\S+\s+\S+\] \[(\S*:)?error\] (\[pid \d+(:tid \d+)?\] )?\[(client|remote) (\S+)\]( \[client \S+\])? (\w+: )?ModSecurity:(( \[[^]]+\])*)? Access denied with code \d\d\d, \[Rule: 'FILES_TMPNAMES' '\@inspectFile \/etc\/cxs\/cxscgi\.sh'\] \[id "1010101"\]/ ) ) {
        my $ip     = $5;
        my $acc    = "";
        my $domain = "";
        if ( $line =~ /\] \[hostname "([^\"]+)"\] \[/ ) { $domain = $1 }
        $ip =~ s/^::ffff://;
        if   ( $config{LF_APACHE_ERRPORT} == 2 and $ip =~ /(.*):\d+$/ ) { $ip = $1 }
        if   ( checkip( \$ip ) )                                        { return ( "cxs mod_security triggered by", "$ip|$acc|$domain", "cxs" ) }
        else                                                            { return }
    }

    #mod_security v1
    if ( ( $config{LF_MODSEC} ) and ( $globlogs{MODSEC_LOG}{$lgfile} ) and ( $line =~ /^\[\S+\s+\S+\s+\S+\s+\S+\s+\S+\] \[error\] \[(client|remote) (\S+)\] mod_security: Access denied/ ) ) {
        my $ip     = $2;
        my $acc    = "";
        my $domain = "";
        if ( $line =~ /\] \[hostname "([^\"]+)"\] \[/ ) { $domain = $1 }
        $ip =~ s/^::ffff://;
        if ( checkip( \$ip ) ) { return ( "mod_security triggered by", "$ip|$acc|$domain", "mod_security" ) }
        else                   { return }
    }

    #mod_security v2 (apache)
    if ( ( $config{LF_MODSEC} ) and ( $globlogs{MODSEC_LOG}{$lgfile} ) and ( $line =~ /^\[\S+\s+\S+\s+\S+\s+\S+\s+\S+\] \[(\S*:)?error\] (\[pid \d+(:tid \d+)?\] )?\[(client|remote) (\S+)\]( \[client \S+\])? (\w+: )?ModSecurity:(( \[[^]]+\])*)? Access denied/ ) ) {
        my $ip     = $5;
        my $acc    = "";
        my $domain = "";
        if ( $line =~ /\] \[hostname "([^\"]+)"\] \[/ ) { $domain = $1 }
        $ip =~ s/^::ffff://;
        if ( $config{LF_APACHE_ERRPORT} == 2 and $ip =~ /(.*):\d+$/ ) { $ip = $1 }
        my $ruleid = "unknown";
        if   ( $line =~ /\[id "(\d+)"\]/ ) { $ruleid = $1 }
        if   ( checkip( \$ip ) )           { return ( "mod_security (id:$ruleid) triggered by", "$ip|$acc|$domain", "mod_security" ) }
        else                               { return }
    }

    #mod_security v2 (nginx)
    if ( ( $config{LF_MODSEC} ) and ( $globlogs{MODSEC_LOG}{$lgfile} ) and ( $line =~ /^\S+ \S+ \[\S+\] \S+ \[(client|remote) (\S+)\] ModSecurity:(( \[[^]]+\])*)? Access denied/ ) ) {
        my $ip     = $2;
        my $acc    = "";
        my $domain = "";
        if ( $line =~ /\] \[hostname "([^\"]+)"\] \[/ ) { $domain = $1 }
        $ip =~ s/^::ffff://;
        my $ruleid = "unknown";
        if   ( $line =~ /\[id "(\d+)"\]/ ) { $ruleid = $1 }
        if   ( checkip( \$ip ) )           { return ( "mod_security (id:$ruleid) triggered by", "$ip|$acc|$domain", "mod_security" ) }
        else                               { return }
    }

    #BIND
    if ( ( $config{LF_BIND} ) and ( $globlogs{BIND_LOG}{$lgfile} ) and ( $line =~ /^(\S+|\S+\s+\d+\s+\S+) \S+ named\[\d+\]: client( \S+)? (\S+)\#\d+(\s\(\S+\))?\:( view external\:)? (update|zone transfer|query \(cache\)) \'[^\']*\' denied$/ ) ) {
        my $ip  = $3;
        my $acc = "";
        $ip =~ s/^::ffff://;
        if ( checkip( \$ip ) ) { return ( "bind triggered by", "$ip|$acc", "bind" ) }
        else                   { return }
    }

    #suhosin
    if ( ( $config{LF_SUHOSIN} ) and ( $globlogs{SUHOSIN_LOG}{$lgfile} ) and ( $line =~ /^(\S+|\S+\s+\d+\s+\S+) \S+ suhosin\[\d+\]: ALERT - .* \(attacker \'(\S+)\'/ ) ) {
        my $ip  = $2;
        my $acc = "";
        $ip =~ s/^::ffff://;
        if ( $line !~ /script tried to increase memory_limit/ ) {
            if ( checkip( \$ip ) ) { return ( "Suhosin triggered by", "$ip|$acc", "suhosin" ) }
            else                   { return }
        }
    }

    #cPanel/WHM
    if ( ( $config{LF_CPANEL} ) and ( $globlogs{CPANEL_LOG}{$lgfile} ) and ( $line =~ /^\[\S+\s+\S+\s+\S+\] \w+ \[\w+] (\S+) - (\S+) \"[^\"]+\" FAILED LOGIN/ ) ) {
        my $ip  = $1;
        my $acc = $2;
        $ip =~ s/^::ffff://;
        if ( checkip( \$ip ) ) { return ( "Failed cPanel login from", "$ip|$acc", "cpanel" ) }
        else                   { return }
    }
    if ( ( $config{LF_CPANEL} ) and ( $globlogs{CPANEL_LOG}{$lgfile} ) and ( $line =~ /^(\S+) - (\S+)? \[\S+ \S+\] \"[^\"]*\" FAILED LOGIN/ ) ) {
        my $ip  = $1;
        my $acc = $2;
        $ip =~ s/^::ffff://;
        if ( checkip( \$ip ) ) { return ( "Failed cPanel login from", "$ip|$acc", "cpanel" ) }
        else                   { return }
    }

    #Exim SMTP AUTH
    if ( ( $config{LF_SMTPAUTH} ) and ( $globlogs{SMTPAUTH_LOG}{$lgfile} ) and ( $line =~ /^\S+\s+\S+\s+(\[\d+\] )?(\S+) authenticator failed for \S+ (\S+ )?\[(\S+)\](:\S*:?)?( I=\S+| \d+\:)? 535 Incorrect authentication data( \(set_id=(\S+)\))?/ ) ) {
        my $ip  = $4;
        my $acc = $8;
        $ip =~ s/^::ffff://;
        if ( checkip( \$ip ) ) { return ( "Failed SMTP AUTH login from", "$ip|$acc", "smtpauth" ) }
        else                   { return }
    }

    #Exim Syntax Errors
    if ( ( $config{LF_EXIMSYNTAX} ) and ( $globlogs{SMTPAUTH_LOG}{$lgfile} ) and ( $line =~ /^\S+\s+\S+\s+(\[\d+\] )?SMTP call from (\S+ )?\[(\S+)\](:\S*:?)?( I=\S+)? dropped: too many syntax or protocol errors/ ) ) {
        my $ip  = $3;
        my $acc = "";
        $ip =~ s/^::ffff://;
        if ( checkip( \$ip ) ) { return ( "Exim syntax errors from", "$ip|$acc", "eximsyntax" ) }
        else                   { return }
    }
    if ( ( $config{LF_EXIMSYNTAX} ) and ( $globlogs{SMTPAUTH_LOG}{$lgfile} ) and ( $line =~ /^\S+\s+\S+\s+(\[\d+\] )?SMTP protocol error in \"[^\"]+\" H=\S+ (\S+ )?\[(\S+)\](:\S*:?)?( I=\S+)? AUTH command used when not advertised/ ) ) {
        my $ip  = $3;
        my $acc = "";
        $ip =~ s/^::ffff://;
        if ( checkip( \$ip ) ) { return ( "Exim syntax errors from", "$ip|$acc", "eximsyntax" ) }
        else                   { return }
    }

    #mod_qos
    if ( ( $config{LF_QOS} ) and ( $globlogs{HTACCESS_LOG}{$lgfile} ) and ( $line =~ /^\[\S+\s+\S+\s+\S+\s+\S+\s+\S+\] \[(\S*:)?error\] (\[pid \d+(:tid \d+)?\] )?\[(client|remote) (\S+)\] (\w+: )?mod_qos\(\d+\): access denied,/ ) ) {
        my $ip  = $5;
        my $acc = "";
        $ip =~ s/^::ffff://;
        if   ( $config{LF_APACHE_ERRPORT} == 2 and $ip =~ /(.*):\d+$/ ) { $ip = $1 }
        if   ( checkip( \$ip ) )                                        { return ( "mod_qos triggered by", "$ip|$acc", "mod_qos" ) }
        else                                                            { return }
    }

    #Apache symlink race condition
    if ( ( $config{LF_SYMLINK} ) and ( $globlogs{MODSEC_LOG}{$lgfile} ) and ( $line =~ /^\[\S+\s+\S+\s+\S+\s+\S+\s+\S+\] \[(\S*:)?error\] (\[pid \d+(:tid \d+)?\] )?\[(client|remote) (\S+)\] (\w+: )?Caught race condition abuser/ ) ) {
        my $ip  = $5;
        my $acc = "";
        $ip =~ s/^::ffff://;
        if ( $config{LF_APACHE_ERRPORT} == 2 and $ip =~ /(.*):\d+$/ ) { $ip = $1 }
        if ( $line !~ /\/cgi-sys\/suspendedpage\.cgi$/ ) {
            if ( checkip( \$ip ) ) { return ( "symlink race condition triggered by", "$ip|$acc", "symlink" ) }
            else                   { return }
        }
    }
}

=head2 processloginline

Processes successful login attempts for tracking purposes.

    my ($app, $account, $ip) = ConfigServer::RegexMain::processloginline($line);

Arguments:

=over 4

=item * C<$line> - The log line to process

=back

Returns a list when a successful login is detected:

=over 4

=item * C<$app> - Application name ("pop3d" or "imapd")

=item * C<$account> - User account name

=item * C<$ip> - IP address of the connection

=back

=cut

sub processloginline {
    my $line = shift;

    _config();    # Make sure config is loaded.

    #courier-imap
    if ( ( $config{LT_POP3D} ) and ( $line =~ /^(\S+|\S+\s+\d+\s+\S+) \S+ pop3d(-ssl)?: LOGIN, user=(\S*), ip=\[(\S+)\], port=\S+/ ) ) {
        my $ip  = $4;
        my $acc = $3;
        $ip =~ s/^::ffff://;
        if ( checkip( \$ip ) ) { return ( "pop3d", $acc, $ip ) }
        else                   { return }
    }
    if ( ( $config{LT_IMAPD} ) and ( $line =~ /^(\S+|\S+\s+\d+\s+\S+) \S+ imapd(-ssl)?: LOGIN, user=(\S*), ip=\[(\S+)\], port=\S+/ ) ) {
        my $ip  = $4;
        my $acc = $3;
        $ip =~ s/^::ffff://;
        if ( checkip( \$ip ) ) { return ( "imapd", $acc, $ip ) }
        else                   { return }
    }

    #dovecot
    if ( ( $config{LT_POP3D} ) and ( $line =~ /^(\S+|\S+\s+\d+\s+\S+) \S+ dovecot(\[\d+\])?: pop3-login: Login: user=<(\S*)>, method=\S+, rip=(\S+), lip=/ ) ) {
        my $ip  = $4;
        my $acc = $3;
        $ip =~ s/^::ffff://;
        if ( checkip( \$ip ) ) { return ( "pop3d", $acc, $ip ) }
        else                   { return }
    }
    if ( ( $config{LT_IMAPD} ) and ( $line =~ /^(\S+|\S+\s+\d+\s+\S+) \S+ dovecot(\[\d+\])?: imap-login: Login: user=<(\S*)>, method=\S+, rip=(\S+), lip=/ ) ) {
        my $ip  = $4;
        my $acc = $3;
        $ip =~ s/^::ffff://;
        if ( checkip( \$ip ) ) { return ( "imapd", $acc, $ip ) }
        else                   { return }
    }
}

=head2 processsshline

Processes successful SSH login attempts for alert purposes.

    my ($account, $ip, $method) = ConfigServer::RegexMain::processsshline($line);

Arguments:

=over 4

=item * C<$line> - The log line to process

=back

Returns a list when a successful SSH login is detected:

=over 4

=item * C<$account> - User account name

=item * C<$ip> - IP address of the connection

=item * C<$method> - Authentication method used (e.g., "password", "publickey")

=back

=cut

sub processsshline {
    my $line = shift;

    _config();    # Make sure config is loaded.

    if ( ( $config{LF_SSH_EMAIL_ALERT} ) and ( $line =~ /^(\S+|\S+\s+\d+\s+\S+) (\S+ )?sshd\[\d+\]: Accepted (\S+) for (\S+) from (\S+) port \S+/ ) ) {
        my $ip  = $5;
        my $acc = $4;
        my $how = $3;
        $ip =~ s/^::ffff://;
        if ( checkip( \$ip ) ) { return ( $acc, $ip, $how ) }
        else                   { return }
    }
}

=head2 processsuline

Processes su (switch user) login attempts.

    my ($to_user, $from_user, $status) = ConfigServer::RegexMain::processsuline($line);

Arguments:

=over 4

=item * C<$line> - The log line to process

=back

Returns a list when an su attempt is detected:

=over 4

=item * C<$to_user> - Target user account

=item * C<$from_user> - Source user account

=item * C<$status> - "Successful login" or "Failed login"

=back

=cut

sub processsuline {
    my $line = shift;

    _config();    # Make sure config is loaded.

    #RH + Debian/Ubuntu
    if ( ( $config{LF_SU_EMAIL_ALERT} ) and ( $line =~ /^(\S+|\S+\s+\d+\s+\S+) (\S+ )?su(\[\d+\])?: pam_unix\(su(-l)?:session\): session opened for user\s+(\S+)\s+by\s+(\S+)\s*$/ ) ) {
        return ( $5, $6, "Successful login" );
    }
    if ( ( $config{LF_SU_EMAIL_ALERT} ) and ( $line =~ /^(\S+|\S+\s+\d+\s+\S+) (\S+ )?su(\[\d+\])?: pam_unix\(su(-l)?:auth\): authentication failure; logname=\S*\s+\S+\s+\S+\s+\S+\s+ruser=(\S+)+\s+\S+\s+user=(\S+)\s*$/ ) ) {
        return ( $6, $5, "Failed login" );
    }

    if ( ( $config{LF_SU_EMAIL_ALERT} ) and ( $line =~ /^(\S+|\S+\s+\d+\s+\S+) (\S+ )?su(\[\d+\])?: pam_unix\(su(-l)?:session\): session opened for user\s+(\S+)\s+by\s+(\S+)\s*$/ ) ) {
        return ( $5, $6, "Successful login" );
    }
    if ( ( $config{LF_SU_EMAIL_ALERT} ) and ( $line =~ /^(\S+|\S+\s+\d+\s+\S+) (\S+ )?su(\[\d+\])?: pam_unix\(su(-l)?:auth\): authentication failure; logname=\S*\s+\S+\s+\S+\s+\S+\s+ruser=(\S+)+\s+\S+\s+user=(\S+)\s*$/ ) ) {
        return ( $6, $5, "Failed login" );
    }

    if ( ( $config{LF_SU_EMAIL_ALERT} ) and ( $line =~ /^(\S+|\S+\s+\d+\s+\S+) (\S+ )?su\(pam_unix\)\[\d+\]: session opened for user\s+(\S+)\s+by\s+(\S+)\s*$/ ) ) {
        return ( $3, $4, "Successful login" );
    }
    if ( ( $config{LF_SU_EMAIL_ALERT} ) and ( $line =~ /^(\S+|\S+\s+\d+\s+\S+) (\S+ )?su\(pam_unix\)\[\d+\]: authentication failure; logname=\S*\s+\S+\s+\S+\s+\S+\s+ruser=(\S+)+\s+\S+\s+user=(\S+)\s*$/ ) ) {
        return ( $4, $3, "Failed login" );
    }
    return;
}

=head2 processsudoline

Processes sudo command execution attempts.

    my ($to_user, $from_user, $status) = ConfigServer::RegexMain::processsudoline($line);

Arguments:

=over 4

=item * C<$line> - The log line to process

=back

Returns a list when a sudo attempt is detected:

=over 4

=item * C<$to_user> - Target user account

=item * C<$from_user> - Source user account

=item * C<$status> - "Successful login" or "Failed login"

=back

=cut

sub processsudoline {
    my $line = shift;

    _config();    # Make sure config is loaded.

    if ( ( $config{LF_SUDO_EMAIL_ALERT} ) and ( $line =~ /^(\S+|\S+\s+\d+\s+\S+) (\S+ )?sudo(\[\d+\])?: pam_unix\(sudo(-l)?:auth\): authentication failure; logname=\S*\s+\S+\s+\S+\s+\S+\s+ruser=(\S+)+\s+\S+\s+user=(\S+)\s*$/ ) ) {
        return ( $6, $5, "Failed login" );
    }
    if ( ( $config{LF_SUDO_EMAIL_ALERT} ) and ( $line =~ /^(\S+|\S+\s+\d+\s+\S+) (\S+ )?sudo\(pam_unix\)\[\d+\]: authentication failure; logname=\S*\s+\S+\s+\S+\s+\S+\s+ruser=(\S+)+\s+\S+\s+user=(\S+)\s*$/ ) ) {
        return ( $4, $3, "Failed login" );
    }

    if ( ( $config{LF_SUDO_EMAIL_ALERT} ) and ( $line =~ /^(\S+|\S+\s+\d+\s+\S+) (\S+ )?sudo(\[\d+\])?:\s+(\S+)\s+:\s+(.*)$/ ) ) {
        my $from  = $4;
        my @items = split( /\s+;\s+/, $5 );
        if ( $items[0] =~ /^TTY/ ) {
            if ( $items[2] =~ /^USER=(\S+)$/ ) {
                return ( $1, $from, "Successful login" );
            }
        }
        elsif ( $items[0] =~ /^user NOT in sudoers/ ) {
            if ( $items[3] =~ /^USER=(\w+)$/ ) {
                return ( $1, $from, "Failed login" );
            }
        }
    }
    return;
}

=head2 processconsoleline

Detects root console logins.

    my $status = ConfigServer::RegexMain::processconsoleline($line);

Arguments:

=over 4

=item * C<$line> - The log line to process

=back

Returns 1 if a root console login is detected, undef otherwise.

=cut

sub processconsoleline {
    my $line = shift;

    _config();    # Make sure config is loaded.

    if ( ( $config{LF_CONSOLE_EMAIL_ALERT} ) and ( $line =~ /^(\S+|\S+\s+\d+\s+\S+) \S+ login(\[\d+\])?: ROOT LOGIN/ ) ) {
        return 1;
    }
}

=head2 processcpanelline

Processes successful cPanel login attempts.

    my ($ip, $account) = ConfigServer::RegexMain::processcpanelline($line);

Arguments:

=over 4

=item * C<$line> - The log line to process

=back

Returns a list when a cPanel login is detected:

=over 4

=item * C<$ip> - IP address of the connection

=item * C<$account> - User account name

=back

=cut

sub processcpanelline {
    my $line = shift;

    _config();    # Make sure config is loaded.

    if ( $config{LF_CPANEL_ALERT} and ( $line =~ /^(\S+)\s+\-\s+(\w+)\s+\[[^\]]+\]\s\"[^\"]+\"\s200\s/ ) ) {
        my $ip  = $1;
        my $acc = $2;
        $ip =~ s/^::ffff://;
        if ( checkip( \$ip ) ) { return ( $ip, $acc ) }
        else                   { return }
    }
}

our $_cpconfig;

=head2 scriptlinecheck

Checks log lines for script execution in user home directories.

    my \$path = ConfigServer::RegexMain::scriptlinecheck(\$line);

Arguments:

=over 4

=item * C<\$line> - The log line to process

=back

Returns the full directory path if script execution is detected in /home
or other configured directories, undef otherwise.

=cut

sub scriptlinecheck {
    my $line = shift;

    _config();    # Make sure config is loaded.

    if ( $config{LF_SCRIPT_ALERT} ) {
        my $fulldir;
        if    ( $line =~ /^\S+\s+\S+\s+(\[\d+\]\s)?cwd=(.*) \d+ args:/ )                             { $fulldir = $2 }
        elsif ( $line =~ /^\S+\s+\S+\s+(\[\d+\]\s)?\S+ H=localhost (.*)PWD=(.*)  REMOTE_ADDR=\S+$/ ) { $fulldir = $3 }
        if    ( $fulldir ne "" ) {
            my ( undef, $dir, undef ) = split( /\//, $fulldir );
            return $fulldir if $dir eq "home";

            $_cpconfig //= Cpanel::Config::LoadWwwAcctConf::loadwwwacctconf();

            my $homedir = $_cpconfig->{HOMEDIR};
            return $fulldir if ( length $homedir and $fulldir =~ /^$homedir/ );

            my $homematch = $_cpconfig->{HOMEMATCH};
            return $fulldir if ( length $homematch and $dir =~ /$homematch/ );
        }
    }
    return;
}

=head2 relaycheck

Detects email relay attempts in mail server logs.

    my ($ip, $check) = ConfigServer::RegexMain::relaycheck($line);

Arguments:

=over 4

=item * C<$line> - The log line to process

=back

Returns a list when a relay attempt is detected:

=over 4

=item * C<$ip> - IP address attempting the relay or username for local relay

=item * C<$check> - Type of relay check triggered ("LOCALRELAY", "AUTHRELAY", "RELAY")

=back

=cut

sub relaycheck {
    my $line  = shift;
    my $tline = $line;
    $tline =~ s/".*"/""/g;
    my @bits = split( /\s+/, $tline );
    my $ip;

    if ( $tline !~ /^\S+\s+\S+\s+(\[\d+\]\s)?\S+ <=/ ) { return }

    #exim
    if ( $tline =~ / U=(\S+) P=local / ) {
        return ( $1, "LOCALRELAY" );
    }

    if ( $tline =~ / H=[^=]*\[(\S+)\]/ ) {
        $ip = $1;
        unless ( checkip( \$ip ) or $ip eq "127.0.0.1" or $ip eq "::1" ) { return }
    }
    else {
        return;
    }

    if ( ( $tline =~ / A=(courier_plain|courier_login|dovecot_plain|dovecot_login|fixed_login|fixed_plain|login|plain):/ ) and ( $tline =~ / P=(esmtpa|esmtpsa) / ) ) {
        return ( $ip, "AUTHRELAY" );
    }

    if ( $tline =~ / P=(smtp|esmtp|esmtps) / ) {
        return ( $ip, "RELAY" );
    }

}

=head2 pslinecheck

Processes port scan detection from iptables logs.

    my ($ip, $port) = ConfigServer::RegexMain::pslinecheck($line);

Arguments:

=over 4

=item * C<$line> - The log line to process

=back

Returns a list when a port scan is detected:

=over 4

=item * C<$ip> - IP address performing the scan

=item * C<$port> - Port number or protocol (e.g., "ICMP", "ICMPv6")

=back

=cut

sub pslinecheck {
    my $line = shift;

    _config();    # Make sure config is loaded.

    if ( $line !~ /^(\S+|\S+\s+\d+\s+\S+) \S+ kernel:\s(\[[^\]]+\]\s)?Firewall:/ ) { return }
    if ( $line =~ /^(\S+|\S+\s+\d+\s+\S+) \S+ kernel:\s(\[[^\]]+\]\s)?Firewall: \*INVALID\*/ and $config{PS_PORTS} !~ /INVALID/ ) { return }

    if ( $line =~ /IN=\S+.*SRC=(\S+).*DST=(\S+).*PROTO=(\w+).*DPT=(\d+)/ ) {
        my $ip    = $1;
        my $dst   = $2;
        my $proto = $3;
        my $port  = $4;
        $ip =~ s/^::ffff://;

        _eth_info();
        if ( $config{PS_PORTS} !~ /BRD/ and $proto eq "UDP" and $brd{$dst} and !$ips{$dst} ) { return }
        if ( $config{PS_PORTS} !~ /OPEN/ ) {
            my $hit = 0;
            if ( $proto eq "TCP" and $line =~ /kernel:\s(\[[^\]]+\]\s)?Firewall: \*TCP_IN Blocked\*/ ) {
                foreach my $ports ( split( /\,/, $config{TCP_IN} ) ) {
                    if ( $ports =~ /\:/ ) {
                        my ( $start, $end ) = split( /\:/, $ports );
                        if ( $port >= $start and $port <= $end ) { $hit = 1 }
                    }
                    elsif ( $port == $ports ) { $hit = 1 }
                    if    ($hit)              { last }
                }
                if ($hit) {
                    if ( $config{DEBUG} >= 1 ) { ConfigServer::Logger::logfile("debug: *Port Scan* ignored TCP_IN port: $ip:$port") }
                    return;
                }
            }
            elsif ( $proto eq "UDP" and $line =~ /kernel:\s(\[[^\]]+\]\s)?Firewall: \*UDP_IN Blocked\*/ ) {
                foreach my $ports ( split( /\,/, $config{UDP_IN} ) ) {
                    if ( $ports =~ /\:/ ) {
                        my ( $start, $end ) = split( /\:/, $ports );
                        if ( $port >= $start and $port <= $end ) { $hit = 1 }
                    }
                    elsif ( $port == $ports ) { $hit = 1 }
                    if    ($hit)              { last }
                }
                if ($hit) {
                    if ( $config{DEBUG} >= 1 ) { ConfigServer::Logger::logfile("debug: *Port Scan* ignored UDP_IN port: $ip:$port") }
                    return;
                }
            }
        }
        if ( checkip( \$ip ) ) { return ( $ip, $port ) }
        else                   { return }
    }
    if ( $line =~ /IN=\S+.*SRC=(\S+).*PROTO=(ICMP)/ ) {
        my $ip   = $1;
        my $port = $2;
        $ip =~ s/^::ffff://;
        if ( checkip( \$ip ) ) { return ( $ip, $port ) }
        else                   { return }
    }
    if ( $line =~ /IN=\S+.*SRC=(\S+).*PROTO=(ICMPv6)/ ) {
        my $ip   = $1;
        my $port = $2;
        $ip =~ s/^::ffff://;
        if ( checkip( \$ip ) ) { return ( $ip, $port ) }
        else                   { return }
    }
}

=head2 uidlinecheck

Detects outbound firewall blocks by UID from kernel logs.

    my (\$port, \$uid) = ConfigServer::RegexMain::uidlinecheck(\$line);

Arguments:

=over 4

=item * C<\$line> - The log line to process

=back

Returns a list when a UID-based firewall event is detected:

=over 4

=item * C<\$port> - Destination port

=item * C<\$uid> - User ID that triggered the event

=back

=cut

sub uidlinecheck {
    my $line = shift;
    if ( $line !~ /^(\S+|\S+\s+\d+\s+\S+) \S+ kernel(\[\d+\])?:\s(\[[^\]]+\]\s)?Firewall:/ ) { return }
    if ( $line =~ /OUT=\S+.*DPT=(\S+).*UID=(\d+)/ )                                          { return ( $1, $2 ) }
}

=head2 portknockingcheck

Detects port knocking attempts from kernel logs.

    my (\$ip, \$port) = ConfigServer::RegexMain::portknockingcheck(\$line);

Arguments:

=over 4

=item * C<\$line> - The log line to process

=back

Returns a list when a port knock is detected:

=over 4

=item * C<\$ip> - IP address performing the knock

=item * C<\$port> - Port number knocked

=back

=cut

sub portknockingcheck {
    my $line = shift;
    if ( $line !~ /^(\S+|\S+\s+\d+\s+\S+) \S+ kernel(\[\d+\])?:\s(\[[^\]]+\]\s)?Knock: \*\d+_IN\*/ ) { return }

    if ( $line =~ /SRC=(\S+).*DPT=(\d+)/ ) {
        my $ip   = $1;
        my $port = $2;
        $ip =~ s/^::ffff://;
        if ( checkip( \$ip ) ) { return ( $ip, $port ) }
        else                   { return }
    }
}

=head2 processdistftpline

Processes successful FTP login attempts for distributed tracking.

    my (\$ip, \$account) = ConfigServer::RegexMain::processdistftpline(\$line);

Arguments:

=over 4

=item * C<\$line> - The log line to process

=back

Returns a list when an FTP login is detected:

=over 4

=item * C<\$ip> - IP address of the connection

=item * C<\$account> - User account name

=back

Supports pure-ftpd and proftpd log formats.

=cut

sub processdistftpline {
    my $line = shift;

    #pure-ftpd
    if ( $line =~ /^(\S+|\S+\s+\d+\s+\S+) \S+ pure-ftpd(\[\d+\])?: \(\?\@(\S+)\) \[INFO\] (\S*) is now logged in$/ ) {
        my $ip  = $3;
        my $acc = $4;
        $ip =~ s/^::ffff://;
        if ( checkip( \$ip ) ) { return ( $ip, $acc ) }
        else                   { return }
    }

    #proftpd
    if ( $line =~ /^(\S+|\S+\s+\d+\s+\S+) \S+ proftpd\[\d+\]: \S+ \([^\[]+\[(\S+)\]\) - USER (\S*): Login successful\.\s*$/ ) {
        my $ip  = $2;
        my $acc = $3;
        $ip =~ s/^::ffff://;
        if ( checkip( \$ip ) ) { return ( $ip, $acc ) }
        else                   { return }
    }
}

sub processdistsmtpline {
    my $line  = shift;
    my $tline = $line;
    $tline =~ s/".*"/""/g;
    my @bits = split( /\s+/, $tline );
    my $ip;

    #postfix
    if ( $line =~ /^(\S+|\S+\s+\d+\s+\S+) \S+ postfix\/(submission\/)?smtpd(?:\[\d+\])?: \w+: client=\S+\[(\S+)\], sasl_method=(?:(?i)LOGIN|PLAIN|(?:CRAM|DIGEST)-MD5), sasl_username=(\S+)$/ ) {
        $ip = $3;
        my $account = $4;
        $ip =~ s/^::ffff://;
        if ( checkip( \$ip ) and $ip ne "127.0.0.1" and $ip ne "::1" ) { return ( $ip, $account ) }
        else                                                           { return }
    }

    #exim
    if ( $tline !~ /^\S+\s+\S+\s+(\[\d+\]\s)?\S+ <=/ ) { return }

    if ( $tline =~ / U=(\S+) P=local / ) { return }

    if ( $tline =~ / H=[^=]*\[(\S+)\]/ ) {
        $ip = $1;
        unless ( checkip( \$ip ) or $ip eq "127.0.0.1" or $ip eq "::1" ) { return }
    }
    else {
        return;
    }

    if ( ( $tline =~ / A=(courier_plain|courier_login|dovecot_plain|dovecot_login|fixed_login|fixed_plain|login|plain):(\S+)/ ) ) {
        my $account = $2;
        if ( ( $tline =~ / P=(esmtpa|esmtpsa) / ) ) { return ( $ip, $account ) }
    }
}

=head2 loginline404

Detects Apache 404 errors from error logs.

    my $ip = ConfigServer::RegexMain::loginline404($line);

Arguments:

=over 4

=item * C<$line> - The log line to process

=back

Returns the IP address if a 404 error is detected, undef otherwise.

=cut

sub loginline404 {
    my $line = shift;

    _config();    # Make sure config is loaded.

    if ( $line =~ /^\[\S+\s+\S+\s+\S+\s+\S+\s+\S+\] \[(\S*:)?(error|info)\] (\[pid \d+(:tid \d+)?\] )?\[(client|remote) (\S+)\] (\w+: )?File does not exist\:/ ) {
        my $ip = $6;
        $ip =~ s/^::ffff://;
        if   ( $config{LF_APACHE_ERRPORT} == 2 and $ip =~ /(.*):\d+$/ ) { $ip = $1 }
        if   ( checkip( \$ip ) )                                        { return ($ip) }
        else                                                            { return }
    }
}

=head2 loginline403

Detects Apache 403 Forbidden errors from error logs.

    my \$ip = ConfigServer::RegexMain::loginline403(\$line);

Arguments:

=over 4

=item * C<\$line> - The log line to process

=back

Returns the IP address if a 403 error is detected, undef otherwise.

=cut

sub loginline403 {
    my $line = shift;

    _config();    # Make sure config is loaded.

    if ( $line =~ /^\[\S+\s+\S+\s+\S+\s+\S+\s+\S+\] \[(\S*:)?error\] (\[pid \d+(:tid \d+)?\] )?\[(client|remote) (\S+)\] (\w+: )?client denied by server configuration\:/ ) {
        my $ip = $5;
        $ip =~ s/^::ffff://;
        if   ( $config{LF_APACHE_ERRPORT} == 2 and $ip =~ /(.*):\d+$/ ) { $ip = $1 }
        if   ( checkip( \$ip ) )                                        { return ($ip) }
        else                                                            { return }
    }
}

=head2 loginline401

Detects Apache 401 Unauthorized authentication failures from error logs.

    my \$ip = ConfigServer::RegexMain::loginline401(\$line);

Arguments:

=over 4

=item * C<\$line> - The log line to process

=back

Returns the IP address if a 401 authentication failure is detected,
undef otherwise.

=cut

sub loginline401 {
    my $line = shift;

    _config();    # Make sure config is loaded.

    if ( $line =~ /^\[\S+\s+\S+\s+\S+\s+\S+\s+\S+\] \[(\S*:)?error\] (\[pid \d+(:tid \d+)?\] )?\[(client|remote) (\S+)\] (\w+: )?(user  not found|user \w+ not found|user \w+: authentication failure for "\/\w+\/")\:/ ) {
        my $ip = $5;
        $ip =~ s/^::ffff://;
        if   ( $config{LF_APACHE_ERRPORT} == 2 and $ip =~ /(.*):\d+$/ ) { $ip = $1 }
        if   ( checkip( \$ip ) )                                        { return ($ip) }
        else                                                            { return }
    }
}

=head2 statscheck

Checks if a log line is a firewall or port knocking statistics line.

    my \$is_stats = ConfigServer::RegexMain::statscheck(\$line);

Arguments:

=over 4

=item * C<\$line> - The log line to process

=back

Returns 1 if the line is a statistics line, undef otherwise.

=cut

sub statscheck {
    my $line = shift;
    if ( $line =~ /^(\S+|\S+\s+\d+\s+\S+) \S+ kernel:\s(\[[^\]]+\]\s)?(Firewall|Knock):/ ) { return 1 }
}

=head2 syslogcheckline

Verifies syslog check codes from lfd log entries.

    my \$matched = ConfigServer::RegexMain::syslogcheckline(\$line, \$code);

Arguments:

=over 4

=item * C<\$line> - The log line to process

=item * C<\$syslogcheckcode> - The expected syslog check code

=back

Returns 1 if the check code matches, undef otherwise.

=cut

sub syslogcheckline {
    my $line            = shift;
    my $syslogcheckcode = shift;
    if ( $line =~ /^(\S+|\S+\s+\d+\s+\S+) \S+ lfd\[\d+\]: SYSLOG check \[(\S+)\]\s*$/ ) {
        if   ( $2 eq $syslogcheckcode ) { return 1 }
        else                            { return }
    }
}

1;

=head1 SEE ALSO

L<ConfigServer::Config>, L<ConfigServer::CheckIP>, L<ConfigServer::Logger>

=head1 VERSION

1.03

=head1 AUTHOR

Jonathan Michaelson

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2006-2025 Jonathan Michaelson

This program is free software; you can redistribute it and/or modify it
under the terms of the GNU General Public License as published by the Free
Software Foundation; either version 3 of the License, or (at your option)
any later version.

This program is distributed in the hope that it will be useful, but WITHOUT
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for
more details.

You should have received a copy of the GNU General Public License along
with this program; if not, see L<https://www.gnu.org/licenses>.

=cut
