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

use cPstrict;

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
require Cpanel::Encoder::Tiny;

our ( $reseller, $script, $images, %rprivs, $myv, %FORM );

Whostmgr::ACLS::init_acls();

%FORM = Cpanel::Form::parseform();

# Encode any params with HTML looking stuff (script tags, iframes, etc.)
%FORM = map { $_ => Cpanel::Encoder::Tiny::safe_html_encode_str( $FORM{$_} ) } keys(%FORM);

# Guard form parameters against undef warnings
my $form_action = $FORM{action} // '';

# Check if this is a raw/streamed output action (no template wrapper needed)
my $is_raw_output = ( $form_action eq "tailcmd" or $form_action =~ /^cf/ or $form_action eq "logtailcmd" or $form_action eq "loggrepcmd" ) ? 1 : 0;

my $config   = ConfigServer::Config->loadconfig();
my %config   = $config->config;
my $slurpreg = ConfigServer::Slurp->slurpreg;
my $cleanreg = ConfigServer::Slurp->cleanreg;

Cpanel::Rlimit::set_rlimit_to_infinity();

$script = "csf.cgi";
$images = "csf";

# Guard environment variable against undef warnings
$ENV{REMOTE_USER} //= '';

foreach my $line ( slurp("/etc/csf/csf.resellers") ) {
    $line =~ s/$cleanreg//g;
    my ( $user, $alert, $privs ) = split( /\:/, $line );
    $user  //= '';
    $alert //= '';
    $privs //= '';
    next if $user eq '';
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
    @header  = slurpee( '/etc/csf/csf.header', 'warn' => 0 );
    @footer  = slurpee( '/etc/csf/csf.footer', 'warn' => 0 );
    $htmltag = "data-post='$form_action'";
}

my $thisapp = "csf";
my $reregister;
if ( $Cpanel::Version::Tiny::major_version >= 65 ) {
    if ( -e "/usr/local/cpanel/whostmgr/docroot/cgi/configserver/${thisapp}/${thisapp}.conf" ) {
        sysopen( my $CONF, "/usr/local/cpanel/whostmgr/docroot/cgi/configserver/${thisapp}/${thisapp}.conf", O_RDWR | O_CREAT );
        flock( $CONF, LOCK_EX );
        my @confdata = <$CONF>;
        chomp @confdata;
        foreach my $line (@confdata) {
            if ( $line =~ /^target=mainFrame/ ) {
                $line       = "target=_self";
                $reregister = 1;
            }
        }
        if ($reregister) {
            seek( $CONF, 0, 0 );
            truncate( $CONF, 0 );
            foreach (@confdata) {
                print $CONF "$_\n";
            }
            printcmd( "/usr/local/cpanel/bin/register_appconfig", "/usr/local/cpanel/whostmgr/docroot/cgi/configserver/${thisapp}/${thisapp}.conf" );
            $reregister = "<div class='bs-callout bs-callout-info'><h4>Updated application. The next time you login to WHM this will open within the native WHM main window instead of launching a separate window</h4></div>\n";
        }
        close($CONF);
    }
}

print "Content-type: text/html\r\n\r\n";

#if ($Cpanel::Version::Tiny::major_version < 65) {$modalstyle = "style='top:120px'"}

my $templatehtml;
my $SCRIPTOUT;
my $old_fh;
unless ($is_raw_output) {

    #	open(STDERR, ">&STDOUT");
    open( $SCRIPTOUT, '>', \$templatehtml );
    $old_fh = select $SCRIPTOUT;    ## no critic (InputOutput::ProhibitOneArgSelect) - Temporarily redirect default output to capture template content

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

unless ($is_raw_output) {
    print <<EOF;
<div id="loader"></div>
EOF
    if ( length $reregister ) { print $reregister }
}

my $ui_status;
if ($reseller) {
    $ui_status = ConfigServer::DisplayResellerUI::main( \%FORM, $script, 0, $images, $myv, 0 );
}
else {
    $ui_status = ConfigServer::DisplayUI::main( \%FORM, $script, 0, $images, $myv, 0 );
}
if ( defined $ui_status and $ui_status =~ /^\d+$/ ) {
    exit($ui_status);
}

unless ($is_raw_output) {
    print @footer;
}
unless ($is_raw_output) {
    close($SCRIPTOUT);
    select $old_fh;    ## no critic (InputOutput::ProhibitOneArgSelect) - Restore previously saved default output filehandle
    Cpanel::Template::process_template(
        'whostmgr',
        {
            "template_file"     => "${thisapp}.tmpl",
            "${thisapp}_output" => $templatehtml,
            "print"             => 1,
            'config'            => \%config,
            'reseller'          => $reseller,
            'app_key'           => 'csf',               # Both this and icon work around failures of Whostmgr's templates/appconfig code to do the right thing.
            'icon'              => 'csf_small.png',
        }
    );
}

sub printcmd {
    my @command = @_;
    my ( $childin, $childout );
    my $pid = open3( $childin, $childout, $childout, @command );
    while (<$childout>) { print $_ }
    waitpid( $pid, 0 );
    return;
}

1;
