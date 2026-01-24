#!/usr/local/cpanel/3rdparty/bin/perl
#WHMADDON:csf:ConfigServer Security & Firewall
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
use strict;
use File::Find;
use Fcntl         qw(:DEFAULT :flock);
use Sys::Hostname qw(hostname);
use IPC::Open3;

use lib '/usr/local/csf/lib';
use ConfigServer::DisplayUI;
use ConfigServer::DisplayResellerUI;
use ConfigServer::Config;
use ConfigServer::Slurp qw(slurp slurpee);

use lib '/usr/local/cpanel';
require Cpanel::Form;
require Cpanel::Config;
require Whostmgr::ACLS;
require Cpanel::Rlimit;
require Cpanel::Template;
require Cpanel::Version::Tiny;
###############################################################################
# start main

our ( $reseller, $script, $images, %rprivs, $myv, %FORM );

Whostmgr::ACLS::init_acls();

%FORM = Cpanel::Form::parseform();

# Remove any params with HTML looking stuff (script tags, iframes, etc.)
%FORM = map { $_ => $FORM{$_} } grep { $FORM{$_} !~ m/<\w+|%3C\w+/ } keys(%FORM);

my $config   = ConfigServer::Config->loadconfig();
my %config   = $config->config;
my $slurpreg = ConfigServer::Slurp->slurpreg;
my $cleanreg = ConfigServer::Slurp->cleanreg;

Cpanel::Rlimit::set_rlimit_to_infinity();

$script = "csf.cgi";
$images = "csf";

foreach my $line ( slurp("/etc/csf/csf.resellers") ) {
    $line =~ s/$cleanreg//g;
    my ( $user, $alert, $privs ) = split( /\:/, $line );
    $privs =~ s/\s//g;
    foreach my $priv ( split( /\,/, $privs ) ) {
        $rprivs{$user}{$priv} = 1;
    }
    $rprivs{$user}{ALERT} = $alert;
}

$reseller = 0;
if ( !Whostmgr::ACLS::hasroot() ) {
    if ( $rprivs{ $ENV{REMOTE_USER} }{USE} ) {
        $reseller = 1;
    }
    else {
        print "Content-type: text/html\r\n\r\n";
        print "You do not have access to this feature\n";
        exit();
    }
}
($myv) = slurpee( '/etc/csf/version.txt', 'fatal' => 1 );

my @header;
my @footer;
my $htmltag = '';

if ( $config{STYLE_CUSTOM} ) {
    @header = slurpee('/etc/csf/csf.header', 'warn' => 0 );
    @footer = slurpee('/etc/csf/csf.footer', 'warn' => 0 );
    $htmltag = "data-post='$FORM{action}'";
}

my $thisapp = "csf";
my $reregister;
my $modalstyle;
if ( $Cpanel::Version::Tiny::major_version >= 65 ) {
    if ( -e "/usr/local/cpanel/whostmgr/docroot/cgi/configserver/${thisapp}/${thisapp}.conf" ) {
        sysopen( my $CONF, "/usr/local/cpanel/whostmgr/docroot/cgi/configserver/${thisapp}/${thisapp}.conf", O_RDWR | O_CREAT );
        flock( $CONF, LOCK_EX );
        my @confdata = <$CONF>;
        chomp @confdata;
        for ( 0 .. scalar(@confdata) ) {
            if ( $confdata[$_] =~ /^target=mainFrame/ ) {
                $confdata[$_] = "target=_self";
                $reregister = 1;
            }
        }
        if ($reregister) {
            seek( $CONF, 0, 0 );
            truncate( $CONF, 0 );
            foreach (@confdata) {
                print $CONF "$_\n";
            }
            &printcmd( "/usr/local/cpanel/bin/register_appconfig", "/usr/local/cpanel/whostmgr/docroot/cgi/configserver/${thisapp}/${thisapp}.conf" );
            $reregister = "<div class='bs-callout bs-callout-info'><h4>Updated application. The next time you login to WHM this will open within the native WHM main window instead of launching a separate window</h4></div>\n";
        }
        close($CONF);
    }
}

print "Content-type: text/html\r\n\r\n";

#if ($Cpanel::Version::Tiny::major_version < 65) {$modalstyle = "style='top:120px'"}

my $templatehtml;
my $SCRIPTOUT;
unless ( $FORM{action} eq "tailcmd" or $FORM{action} =~ /^cf/ or $FORM{action} eq "logtailcmd" or $FORM{action} eq "loggrepcmd" ) {

    #	open(STDERR, ">&STDOUT");
    open( $SCRIPTOUT, '>', \$templatehtml );
    select $SCRIPTOUT;

    print <<EOF;
	<link href='$images/configserver.css' rel='stylesheet' type='text/css'>
<style>
.toplink {
top: 140px;
}
.mobilecontainer {
display:none;
}
.normalcontainer {
display:block;
}
EOF
    if ( $config{STYLE_MOBILE} or $reseller ) {
        print <<EOF;
\@media (max-width: 600px) {
.mobilecontainer {
	display:block;
}
.normalcontainer {
	display:none;
}
}
EOF
    }
    print "</style>\n";
    print @header;
}

unless ( $FORM{action} eq "tailcmd" or $FORM{action} =~ /^cf/ or $FORM{action} eq "logtailcmd" or $FORM{action} eq "loggrepcmd" ) {
    print <<EOF;
<div id="loader"></div>
EOF
    if ( $reregister ne "" ) { print $reregister }
}

if ($reseller) {
    ConfigServer::DisplayResellerUI::main( \%FORM, $script, 0, $images, $myv );
}
else {
    ConfigServer::DisplayUI::main( \%FORM, $script, 0, $images, $myv );
}

unless ( $FORM{action} eq "tailcmd" or $FORM{action} =~ /^cf/ or $FORM{action} eq "logtailcmd" or $FORM{action} eq "loggrepcmd" ) {
    print @footer;
}
unless ( $FORM{action} eq "tailcmd" or $FORM{action} =~ /^cf/ or $FORM{action} eq "logtailcmd" or $FORM{action} eq "loggrepcmd" ) {
    close($SCRIPTOUT);
    select STDOUT;
    Cpanel::Template::process_template(
        'whostmgr',
        {
            "template_file"     => "${thisapp}.tmpl",
            "${thisapp}_output" => $templatehtml,
            "print"             => 1,
            'config'            => \%config,
            'reseller'          => $reseller,
            'app_key'           => 'csf', # Both this and icon work around failures of Whostmgr's templates/appconfig code to do the right thing.
            'icon'              => 'csf_small.png',
        }
    );
}

# end main
###############################################################################
## start printcmd
sub printcmd {
    my @command = @_;
    my ( $childin, $childout );
    my $pid = open3( $childin, $childout, $childout, @command );
    while (<$childout>) { print $_ }
    waitpid( $pid, 0 );
    return;
}
## end printcmd
###############################################################################

1;
