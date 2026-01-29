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
package ConfigServer::cseUI;

=head1 NAME

ConfigServer::cseUI - ConfigServer Explorer web-based file manager interface

=head1 SYNOPSIS

    use ConfigServer::cseUI ();

    # Called from CGI context with form data
    ConfigServer::cseUI::main(\%FORM, $fileinc, $script, $script_da, $images, $version);

=head1 DESCRIPTION

ConfigServer Explorer (CSE) provides a web-based file manager interface for
cPanel/WHM environments. It allows administrators to browse, view, edit,
copy, move, and delete files and directories through a web interface.

This module handles the UI rendering and file operations for the CSE tool.
It is designed to be called from a CGI script with appropriate authentication
and authorization already verified.

=head1 VERSION

Version 2.03

=cut

use cPstrict;

use ConfigServer::Config ();
use Fcntl                ();
use File::Find           ();
use File::Copy           ();
use IPC::Open3           ();

our $VERSION = 2.03;

umask(0177);

our (
    %FORM,      $script,   $script_da, $images,       $myv,
    $act,       $destpath, $element,   $extramessage, $fieldname, $fileinc,
    $filetemp,  $message,  $name,      $origpath,     $tgid,      $thisdir,
    $tuid,      $value,    $webpath,   %ele,          %header,    @bits,     @dirs, @filebodies,
    @filenames, @files,    @months,    @parts,        @passrecs,  @thisdirs, @thisfiles,
    $files
);

# Storage path for htpasswd files - empty by default (feature disabled)
our $storepath = '';

=head1 FUNCTIONS

=head2 main

    ConfigServer::cseUI::main(\%FORM, $fileinc, $script, $script_da, $images, $version);

Main entry point for the ConfigServer Explorer UI. Processes form input and
dispatches to appropriate action handlers.

=head3 Parameters

=over 4

=item C<\%FORM>

Hash reference containing form input data. Key fields include:

=over 8

=item C<do> - Action to perform (b=browse, view, edit, save, del, etc.)

=item C<p> - Current path

=item C<f> - Current file

=back

=item C<$fileinc>

File upload data reference (if any).

=item C<$script>

URL path to the CGI script.

=item C<$script_da>

URL path to the direct access script.

=item C<$images>

URL path to the images directory.

=item C<$version>

Version string for display.

=back

=head3 Returns

This function outputs HTML directly to STDOUT and does not return a value.

=cut

sub main {
    my $FORM_ref = shift;
    %FORM      = %{$FORM_ref};
    $fileinc   = shift;
    $script    = shift;
    $script_da = shift;
    $images    = shift;
    $myv       = shift;
    $|         = 1;

    $webpath = '/';

    if ( $FORM{do} eq "view" ) {
        _view();
        return 0;
    }

    print "Content-type: text/html\r\n\r\n";

    my $bootstrapcss = "<link rel='stylesheet' href='$images/bootstrap/css/bootstrap.min.css'>";
    my $jqueryjs     = "<script src='$images/jquery.min.js'></script>";
    my $bootstrapjs  = "<script src='$images/bootstrap/js/bootstrap.min.js'></script>";

    print <<EOF;
<!doctype html>
<html lang='en'>
<head>
	<title>ConfigServer Explorer</title>
	<meta charset='utf-8'>
	<meta name='viewport' content='width=device-width, initial-scale=1'>
	$bootstrapcss
	<link href='$images/configserver.css' rel='stylesheet' type='text/css'>
	$jqueryjs
	$bootstrapjs
</head>
<body>
<div id="loader"></div>
EOF

    unless ( $FORM{do} eq "console" ) {
        print "<div class='container-fluid'>\n";
        print "<div class='pull-right' style='margin:8px'>\n";
        my $ui_cxs = ConfigServer::Config->get_config('UI_CXS');
        my $ui_cse = ConfigServer::Config->get_config('UI_CSE');
        if ( $ui_cxs or $ui_cse ) {
            print "<form action='$script' method='post'><select name='csfapp'><option>csf</option>";
            if ($ui_cxs) { print "<option>cxs</option>" }
            if ($ui_cse) { print "<option selected>cse</option>" }
            print "<", "/select> <input class='btn btn-default' type='submit' value='Switch'></form>\n";
        }
        print " <a class='btn btn-default' href='$script?csfaction=csflogout'>cse Logout</a>\n";
        print "</div>\n";
        print <<EOF;
<div class='panel panel-default panel-body'>
<h4><span class="glyphicon glyphicon-folder-open icon-configserver"></span> ConfigServer Explorer - cse</h4>
</div>
EOF
    }

    $message = "";

    if    ($fileinc)                    { _uploadfile() }
    elsif ( $FORM{do} eq "" )           { _browse() }
    elsif ( ( $FORM{quit} // 0 ) == 2 ) { _browse() }
    elsif ( $FORM{do} eq "b" )          { _browse() }
    elsif ( $FORM{do} eq "p" )          { _browse() }
    elsif ( $FORM{do} eq "o" )          { _browse() }
    elsif ( $FORM{do} eq "c" )          { _browse() }
    elsif ( $FORM{do} eq "m" )          { _browse() }
    elsif ( $FORM{do} eq "pw" )         { _browse() }
    elsif ( $FORM{do} eq "r" )          { _browse() }
    elsif ( $FORM{do} eq "newf" )       { _browse() }
    elsif ( $FORM{do} eq "newd" )       { _browse() }
    elsif ( $FORM{do} eq "cnewf" )      { _cnewf() }
    elsif ( $FORM{do} eq "cnewd" )      { _cnewd() }
    elsif ( $FORM{do} eq "ren" )        { _ren() }
    elsif ( $FORM{do} eq "del" )        { _del() }
    elsif ( $FORM{do} eq "setp" )       { _setp() }
    elsif ( $FORM{do} eq "seto" )       { _seto() }
    elsif ( $FORM{do} eq "cd" )         { _cd() }
    elsif ( $FORM{do} eq "console" )    { _console() }
    elsif ( $FORM{do} eq "edit" )       { _edit() }
    elsif ( $FORM{do} eq "Cancel" )     { _browse() }
    elsif ( $FORM{do} eq "Save" )       { _save() }
    elsif ( $FORM{do} eq "copyit" )     { _copyit() }
    elsif ( $FORM{do} eq "moveit" )     { _moveit() }
    else                                { print "Invalid action" }

    unless ( $FORM{do} eq "console" ) {
        print "<p>&copy;2006-2023, <a href='http://www.configserver.com' target='_blank'>ConfigServer Services</a> (Jonathan Michaelson)</p>\n";
    }
    print <<EOF;
</div>
<script>
	\$("#loader").hide();
	\$(document).ready(function(){
		\$('[data-tooltip="tooltip"]').tooltip();
	});
</script>
</body>
</html>
EOF
    return 0;
}

sub _browse {
    my $extra = '';
    $FORM{c} //= '';
    $FORM{m} //= '';
    if ( $FORM{c} ) {
        if ( -e "$webpath$FORM{c}" ) {
            $extra = "&c=$FORM{c}";
        }
        else {
            $FORM{c} = "";
        }
    }
    if ( $FORM{m} ) {
        if ( -e "$webpath$FORM{m}" ) {
            $extra = "&m=$FORM{m}";
        }
        else {
            $FORM{m} = "";
        }
    }

    print "<script language='javascript'>\n";
    print "	function check(file) {return confirm('Click OK to '+file)}\n";
    print "</script>\n";

    $thisdir = $webpath;
    if ( $thisdir !~ /\/$/ ) { $thisdir .= "/" }
    $thisdir .= $FORM{p};
    $thisdir =~ s/\/+/\//g;
    @months = ( "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" );

    my $errordir = 0;
    opendir( DIR, "$thisdir" ) or $errordir = 1;
    while ( my $file = readdir(DIR) ) {
        if ( -d "$thisdir/$file" ) {
            if ( $file !~ /^\.$|^\.\.$/ ) { push( @thisdirs, $file ) }
        }
        else {
            push( @thisfiles, $file );
        }

    }
    closedir(DIR);

    @thisdirs  = sort @thisdirs;
    @thisfiles = sort @thisfiles;

    print "<div class='bs-callout bs-callout-danger'>\n";
    print "<span class='label label-danger'>WARNING!</span> While this utility can be very useful it is also very dangerous indeed. You can easily render your server inoperable and unrecoverable by performing ill advised actions. No warranty or guarantee is provided with the product that protects against system damage.\n";
    print "</div>\n";

    if ($message) { print "<div class='bs-callout bs-callout-success'><h3 class='text-center'>$message</h3></div>\n"; }
    print "<table class='table table-bordered table-striped table-condensed'>\n";
    print "<tr><td colspan='7'>";
    print "[<a href=\"$script?do=b&p=$extra\">Home</a>]";
    my $path = "";
    my $cnt  = 2;
    my @path = split( /\//, $FORM{p} );
    foreach my $dir (@path) {
        if ( $dir ne "" and ( $dir ne "/" ) ) {
            if ( $cnt == @path ) {
                print "<code>/$dir</code>";
            }
            else {
                print "<code>/</code><a href=\"$script?do=b&p=$path/$dir$extra\">$dir</a>";
            }
            $path .= "/$dir";
            $cnt++;
        }
    }
    if ( $FORM{c} ) { print "&nbsp;&nbsp;&nbsp;&nbsp;Copy buffer:<code>$FORM{c}</code> <a class='btn btn-default glyphicon glyphicon-paste' data-tooltip='tooltip' title='Paste Here' href='$script?do=c&p=$FORM{p}$extra\#new'></a>\n" }
    if ( $FORM{m} ) { print "&nbsp;&nbsp;&nbsp;&nbsp;Move buffer:<code>$FORM{m}</code> <a class='btn btn-default glyphicon glyphicon-paste' data-tooltip='tooltip' title='Move Here' href='$script?do=m&p=$FORM{p}$extra\#new'></a>\n" }
    print "</td></tr>\n";
    if ($errordir) {
        print "<tr><td colspan='10'>Permission Denied</td></tr>";
    }
    else {
        if ( @thisdirs > 0 ) {
            print "<thead>\n";
            print "<tr>";
            print "<th>Directory Name</th>";
            print "<th>Size</th>";
            print "<th>Date</th>";
            print "<th>User(uid)/Group(gid)</th>";
            print "<th>Perms</th>";
            print "<th colspan='2'>Actions</th>";
            print "</tr></thead>\n";
        }
        my $class = "tdshade2";
        foreach my $dir (@thisdirs) {
            if ( $dir =~ /'|"|\||\`/ ) {
                print "<td colspan='7'>" . quotemeta($dir) . "Invalid directory name - ignored</td>";
                next;
            }
            my ( $dev, $ino, $mode, $nlink, $uid, $gid, $rdev, $size, $atime, $mtime, $ctime, $blksize, $blocks ) = stat("$thisdir/$dir");
            next unless defined $size;
            if ( $size < 1024 ) {
            }
            elsif ( $size < ( 1024 * 1024 ) ) {
                $size = sprintf( "%.1f", ( $size / 1024 ) );
                $size .= "k";
            }
            else {
                $size = sprintf( "%.1f", ( $size / ( 1024 * 1024 ) ) );
                $size .= "M";
            }
            $mode = sprintf "%04o", $mode & oct("07777");
            $tgid = getgrgid($gid);
            if ( $tgid eq "" ) { $tgid = $gid }
            $tuid = getpwuid($uid);
            if ( $tuid eq "" ) { $tuid = $uid }
            my ( $sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst ) = localtime($mtime);
            $year += 1900;
            my $time = sprintf "%02d:%02d:%02d", $hour, $min, $sec;
            $mday  = sprintf "%02d", $mday;
            $mtime = "$mday-$months[$mon]-$year $time";
            my $pp       = "";
            my $passfile = "$FORM{p}/$dir";
            $passfile =~ s/\//\_/g;
            $passfile =~ s/\\/\_/g;
            $passfile =~ s/\:/\_/g;

            if ( -e "$storepath/$passfile.htpasswd" ) {
                open( my $PASSFILE, "<", "$storepath/$passfile.htpasswd" ) or die $!;
                flock( $PASSFILE, Fcntl::LOCK_SH );
                @passrecs = <$PASSFILE>;
                close($PASSFILE);
                chomp @passrecs;
                if ( @passrecs > 0 ) { $pp = "**" }
            }

            print "<tr>";
            if ( $FORM{do} eq "r" and ( $FORM{f} eq $dir ) ) {
                print "<form action='$script' method='post'>\n";
                print "<td>";
                print "<input type='hidden' name='do' value='ren'>\n";
                print "<input type='hidden' name='p' value='$FORM{p}'>\n";
                print "<input type='hidden' name='c' value='$FORM{c}'>\n";
                print "<input type='hidden' name='m' value='$FORM{m}'>\n";
                print "<input type='hidden' name='f' value='$dir'>\n";
                print "<input type='text' size='10' name='newf' value='$dir'>\n";
                print "<input type='submit' class='btn btn-default' value='OK'>\n";
                print "$pp<a name='new'></a></td>";
                print "</form>\n";
            }
            elsif ( -r "$webpath$FORM{p}/$dir" ) {
                print "<td><a data-tooltip='tooltip' title='Enter Directory' href='$script?do=b&p=$FORM{p}/$dir$extra\#new'>$dir</a>$pp</td>";
            }
            else {
                print "<td>$dir</td>";
            }
            print "<td align='right'>$size</td>";
            print "<td align='right'>$mtime</td>";
            if ( $FORM{do} eq "o" and ( $FORM{f} eq $dir ) ) {
                print "<form action='$script' method='post'>\n";
                print "<td align='right'>";
                print "<input type='hidden' name='do' value='seto'>\n";
                print "<input type='hidden' name='p' value='$FORM{p}'>\n";
                print "<input type='hidden' name='c' value='$FORM{c}'>\n";
                print "<input type='hidden' name='m' value='$FORM{m}'>\n";
                print "<input type='hidden' name='f' value='$dir'>\n";
                print "<input type='text' size='20' name='newo' value='$tuid:$tgid'>\n";
                print "<input type='submit' class='btn btn-default' value='OK'>\n";
                print "<a name='new'></a></td>";
                print "</form>\n";
            }
            else {
                print "<td align='right'><a data-tooltip='tooltip' title='Directory Owner' href='$script?do=o&p=$FORM{p}&f=$dir$extra\#new'>$tuid($uid)/$tgid($gid)</a></td>";
            }
            if ( $FORM{do} eq "p" and ( $FORM{f} eq $dir ) ) {
                print "<form action='$script' method='post'>\n";
                print "<td align='right'>";
                print "<input type='hidden' name='do' value='setp'>\n";
                print "<input type='hidden' name='p' value='$FORM{p}'>\n";
                print "<input type='hidden' name='c' value='$FORM{c}'>\n";
                print "<input type='hidden' name='m' value='$FORM{m}'>\n";
                print "<input type='hidden' name='f' value='$dir'>\n";
                print "<input type='text' size='3' name='newp' value='$mode'>\n";
                print "<input type='submit' class='btn btn-default' value='OK'>\n";
                print "<a name='new'></a></td>";
                print "</form>\n";
            }
            else {
                print "<td align='right'><a data-tooltip='tooltip' title='Permissions (CHMOD)' href='$script?do=p&p=$FORM{p}&f=$dir$extra\#new'>$mode</a></td>";
            }
            print "<td>&nbsp;</td>";
            print "<td><a class='btn btn-danger glyphicon glyphicon-trash' data-tooltip='tooltip' title='Delete Directory' href='$script?do=del&p=$FORM{p}&f=$dir$extra' onClick='return check(\"DELETE $dir\")'></a>";
            print " <a class='btn btn-primary glyphicon glyphicon-wrench' data-tooltip='tooltip' title='Rename Directory' href='$script?do=r&p=$FORM{p}&f=$dir$extra\#new'></a>";
            print " <a class='btn btn-success glyphicon glyphicon-copy' data-tooltip='tooltip' title='Copy Directory' href='$script?do=b&p=$FORM{p}&c=$FORM{p}/$dir\#new'></a>";
            print " <a class='btn btn-warning glyphicon glyphicon-move' data-tooltip='tooltip' title='Move Directory' href='$script?do=b&p=$FORM{p}&m=$FORM{p}/$dir\#new'></a></td>";
            print "</tr>\n";
        }
        if ( $FORM{do} eq "newd" ) {
            print "<tr>";
            print "<form action='$script' method='post'>\n";
            print "<td>";
            print "<input type='hidden' name='do' value='cnewd'>\n";
            print "<input type='hidden' name='p' value='$FORM{p}'>\n";
            print "<input type='hidden' name='c' value='$FORM{c}'>\n";
            print "<input type='hidden' name='m' value='$FORM{m}'>\n";
            print "<input type='text' size='10' name='newf' value=''>\n";
            print "<input type='submit' class='btn btn-default' value='OK'>\n";
            print "<a name='new'></a></td>";
            print "</form>\n";
            print "<td>&nbsp;</td>";
            print "<td>&nbsp;</td>";
            print "<td>&nbsp;</td>";
            print "<td>&nbsp;</td>";
            print "<td colspan='5'>&nbsp;</td>";
            print "</tr>\n";
        }
        if ( ( $FORM{do} eq "c" ) and ( -d "$webpath$FORM{c}" ) ) {
            my $newf = ( split( /\//, $FORM{c} ) )[-1];
            print "<tr>";
            print "<form action='$script' method='post'>\n";
            print "<td>";
            print "<input type='hidden' name='do' value='copyit'>\n";
            print "<input type='hidden' name='p' value='$FORM{p}'>\n";
            print "<input type='hidden' name='c' value='$FORM{c}'>\n";
            print "<input type='hidden' name='m' value='$FORM{m}'>\n";
            print "<input type='text' size='10' name='newf' value='$newf'>\n";
            print "<input type='submit' class='btn btn-default' value='OK'>\n";
            print "<a name='new'></a></td>";
            print "</form>\n";
            print "<td>&nbsp;</td>";
            print "<td>&nbsp;</td>";
            print "<td>&nbsp;</td>";
            print "<td>&nbsp;</td>";
            print "<td colspan='2'>&nbsp;</td>";
            print "</tr>\n";
        }
        if ( ( $FORM{do} eq "m" ) and ( -d "$webpath$FORM{m}" ) ) {
            my $newf = ( split( /\//, $FORM{m} ) )[-1];
            print "<tr>";
            print "<form action='$script' method='post'>\n";
            print "<td>";
            print "<input type='hidden' name='do' value='moveit'>\n";
            print "<input type='hidden' name='p' value='$FORM{p}'>\n";
            print "<input type='hidden' name='c' value='$FORM{c}'>\n";
            print "<input type='hidden' name='m' value='$FORM{m}'>\n";
            print "<input type='text' size='10' name='newf' value='$newf'>\n";
            print "<input type='submit' class='btn btn-default' value='OK'>\n";
            print "<a name='new'></a></td>";
            print "</form>\n";
            print "<td>&nbsp;</td>";
            print "<td>&nbsp;</td>";
            print "<td>&nbsp;</td>";
            print "<td>&nbsp;</td>";
            print "<td colspan='2'>&nbsp;</td>";
            print "</tr>\n";
        }

        if ( @thisfiles > 0 ) {
            print "<tr><td colspan='7'>&nbsp;</td></tr>\n";
            print "<thead><tr>";
            print "<th>File Name</th>";
            print "<th>Size</th>";
            print "<th>Date</th>";
            print "<th>User(uid)/Group(gid)</th>";
            print "<th>Perms</th>";
            print "<th colspan='2'>Actions</th>";
            print "</tr></thead>\n";
        }
        $class = "tdshade2";
        foreach my $file (@thisfiles) {
            if ( $file =~ /'|"|\||\`/ ) {
                print "<td colspan='7'>" . quotemeta($file) . "Invalid file name - ignored</td>";
                next;
            }
            my ( $dev, $ino, $mode, $nlink, $uid, $gid, $rdev, $size, $atime, $mtime, $ctime, $blksize, $blocks ) = stat("$thisdir/$file");
            next unless defined $size;
            if ( $size < 1024 ) {
            }
            elsif ( $size < ( 1024 * 1024 ) ) {
                $size = sprintf( "%.1f", ( $size / 1024 ) );
                $size .= "k";
            }
            else {
                $size = sprintf( "%.1f", ( $size / ( 1024 * 1024 ) ) );
                $size .= "M";
            }
            $mode = sprintf "%03o", $mode & oct("00777");
            $tgid = getgrgid($gid);
            if ( $tgid eq "" ) { $tgid = $gid }
            $tuid = getpwuid($uid);
            if ( $tuid eq "" ) { $tuid = $uid }
            my ( $sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst ) = localtime($mtime);
            $year += 1900;
            my $time = sprintf "%02d:%02d:%02d", $hour, $min, $sec;
            $mday  = sprintf "%02d", $mday;
            $mtime = "$mday-$months[$mon]-$year $time";
            print "<tr>";

            if ( $FORM{do} eq "r" and ( $FORM{f} eq $file ) ) {
                print "<form action='$script' method='post'>\n";
                print "<td>";
                print "<input type='hidden' name='do' value='ren'>\n";
                print "<input type='hidden' name='p' value='$FORM{p}'>\n";
                print "<input type='hidden' name='c' value='$FORM{c}'>\n";
                print "<input type='hidden' name='m' value='$FORM{m}'>\n";
                print "<input type='hidden' name='f' value='$file'>\n";
                print "<input type='text' size='20' name='newf' value='$file'>\n";
                print "<input type='submit' class='btn btn-default' value='OK'>\n";
                print "<a name='new'></a></td>";
                print "</form>\n";
            }
            else {
                $act = "$script?do=view&p=$FORM{p}&f=$file$extra\#new";
                print "<td><a href='$act' data-tooltip='tooltip' title='Download File' target='_blank'>$file</a></td>";
            }
            print "<td align='right'>$size</td>";
            print "<td align='right'>$mtime</td>";
            if ( $FORM{do} eq "o" and ( $FORM{f} eq $file ) ) {
                print "<form action='$script' method='post'>\n";
                print "<td align='right'>";
                print "<input type='hidden' name='do' value='seto'>\n";
                print "<input type='hidden' name='p' value='$FORM{p}'>\n";
                print "<input type='hidden' name='c' value='$FORM{c}'>\n";
                print "<input type='hidden' name='m' value='$FORM{m}'>\n";
                print "<input type='hidden' name='f' value='$file'>\n";
                print "<input type='text' size='20' name='newo' value='$tuid:$tgid'>\n";
                print "<input type='submit' class='btn btn-default' value='OK'>\n";
                print "<a name='new'></a></td>";
                print "</form>\n";
            }
            else {
                print "<td align='right'><a data-tooltip='tooltip' title='File Owner' href='$script?do=o&p=$FORM{p}&f=$file$extra\#new'>$tuid($uid)/$tgid($gid)</a></td>";
            }
            if ( $FORM{do} eq "p" and ( $FORM{f} eq $file ) ) {
                print "<form action='$script' method='post'>\n";
                print "<td align='right'>";
                print "<input type='hidden' name='do' value='setp'>\n";
                print "<input type='hidden' name='p' value='$FORM{p}'>\n";
                print "<input type='hidden' name='c' value='$FORM{c}'>\n";
                print "<input type='hidden' name='m' value='$FORM{m}'>\n";
                print "<input type='hidden' name='f' value='$file'>\n";
                print "<input type='text' size='3' name='newp' value='$mode'>\n";
                print "<input type='submit' class='btn btn-default' value='OK'>\n";
                print "<a name='new'></a></td>";
                print "</form>\n";
            }
            else {
                print "<td align='right'><a data-tooltip='tooltip' title='Permissions (CHMOD)' href='$script?do=p&p=$FORM{p}&f=$file$extra\#new'>$mode</a></td>";
            }
            my $ext = ( split( /\./, $file ) )[-1];
            if ( -T "$webpath$FORM{p}/$file" ) {
                my $act = "";
                print "<td><a class='btn btn-info glyphicon glyphicon-edit' data-tooltip='tooltip' title='Edit File' href='$script?do=edit&p=$FORM{p}&f=$file$extra\#new'></a>$act</td>";
            }
            else {
                print "<td>&nbsp;</td>";
            }
            print "<td nowrap><a class='btn btn-danger glyphicon glyphicon-trash' data-tooltip='tooltip' title='Delete File' href='$script?do=del&p=$FORM{p}&f=$file$extra' onClick='return check(\"DELETE $file\")'></a>";
            print " <a class='btn btn-primary glyphicon glyphicon-wrench' data-tooltip='tooltip' title='Rename File' href='$script?do=r&p=$FORM{p}&f=$file$extra\#new'></a>";
            print " <a class='btn btn-success glyphicon glyphicon-copy' data-tooltip='tooltip' title='Copy File' href='$script?do=b&p=$FORM{p}&c=$FORM{p}/$file\#new'></a>";
            print " <a class='btn btn-warning glyphicon glyphicon-move' data-tooltip='tooltip' title='Move File' href='$script?do=b&p=$FORM{p}&m=$FORM{p}/$file\#new'></a></td>";
            print "</tr>\n";
        }
        if ( $FORM{do} eq "newf" ) {
            print "<tr>";
            print "<form action='$script' method='post'>\n";
            print "<td>";
            print "<input type='hidden' name='do' value='cnewf'>\n";
            print "<input type='hidden' name='p' value='$FORM{p}'>\n";
            print "<input type='hidden' name='c' value='$FORM{c}'>\n";
            print "<input type='hidden' name='m' value='$FORM{m}'>\n";
            print "<input type='text' size='10' name='newf' value=''>\n";
            print "<input type='submit' class='btn btn-default' value='OK'>\n";
            print "<a name='new'></a></td>";
            print "</form>\n";
            print "<td>&nbsp;</td>";
            print "<td>&nbsp;</td>";
            print "<td>&nbsp;</td>";
            print "<td>&nbsp;</td>";
            print "<td colspan='2'>&nbsp;</td>";
            print "</tr>\n";
        }
        if ( ( $FORM{do} eq "c" ) and ( -f "$webpath$FORM{c}" ) ) {
            my $newf = ( split( /\//, $FORM{c} ) )[-1];
            print "<tr>";
            print "<form action='$script' method='post'>\n";
            print "<td>";
            print "<input type='hidden' name='do' value='copyit'>\n";
            print "<input type='hidden' name='p' value='$FORM{p}'>\n";
            print "<input type='hidden' name='c' value='$FORM{c}'>\n";
            print "<input type='hidden' name='m' value='$FORM{m}'>\n";
            print "<input type='text' size='10' name='newf' value='$newf'>\n";
            print "<input type='submit' class='btn btn-default' value='OK'>\n";
            print "<a name='new'></a></td>";
            print "</form>\n";
            print "<td>&nbsp;</td>";
            print "<td>&nbsp;</td>";
            print "<td>&nbsp;</td>";
            print "<td>&nbsp;</td>";
            print "<td colspan='2'>&nbsp;</td>";
            print "</tr>\n";
        }
        if ( ( $FORM{do} eq "m" ) and ( -f "$webpath$FORM{m}" ) ) {
            my $newf = ( split( /\//, $FORM{m} ) )[-1];
            print "<tr>";
            print "<form action='$script' method='post'>\n";
            print "<td>";
            print "<input type='hidden' name='do' value='moveit'>\n";
            print "<input type='hidden' name='p' value='$FORM{p}'>\n";
            print "<input type='hidden' name='c' value='$FORM{c}'>\n";
            print "<input type='hidden' name='m' value='$FORM{m}'>\n";
            print "<input type='text' size='10' name='newf' value='$newf'>\n";
            print "<input type='submit' class='btn btn-default' value='OK'>\n";
            print "<a name='new'></a></td>";
            print "</form>\n";
            print "<td>&nbsp;</td>";
            print "<td>&nbsp;</td>";
            print "<td>&nbsp;</td>";
            print "<td>&nbsp;</td>";
            print "<td colspan='2'>&nbsp;</td>";
            print "</tr>\n";
        }
    }
    print "</table>\n";

    print "<div class='bs-callout bs-callout-warning'>All the following actions apply to the current directory</div>\n";
    print "<form action='$script' method='post'>\n";
    my $form_c = $FORM{c} // '';
    my $form_m = $FORM{m} // '';
    print "<input type='hidden' name='p' value='$FORM{p}'>\n";
    print "<input type='hidden' name='c' value='$form_c'>\n";
    print "<input type='hidden' name='m' value='$form_m'>\n";
    print "<input type='hidden' name='do' value='search'>\n";
    print "<table class='table table-bordered table-striped table-condensed'>\n";
    print "<thead><tr><th colspan='2'>Search for filenames or directories</th></tr></thead>\n";
    print "<tr><td colspan='2'>";
    print "<input type='text' name='words' size='20'> <select name='type'>\n";
    print "<option value='and'>AND words</option>\n";
    print "<option value='or'>OR words</option>\n";
    print "<option value='match'>MATCH words</option></select>\n";
    print "<input type='submit' class='btn btn-default' value='Search'></td></tr>\n";
    print "</table>\n";
    print "</form>\n";
    print "<table class='table table-bordered table-striped table-condensed'>\n";
    print "<thead><tr><th colspan='2'>Create New...</th></tr></thead>\n";
    print "<tr><td><a class='btn btn-default' href='$script?do=newd&p=$FORM{p}$extra\#new'>Create New Directory</a></td>\n<td><a class='btn btn-default' href='$script?do=newf&p=$FORM{p}$extra\#new'>Create Empty File</a></td></tr>\n";
    print "</table>\n";
    print "<form action='$script' method='post' enctype='multipart/form-data'>\n";
    print "<input type='hidden' name='p' value='$FORM{p}'>\n";
    print "<input type='hidden' name='c' value='$FORM{c}'>\n";
    print "<input type='hidden' name='m' value='$FORM{m}'>\n";
    print "<table class='table table-bordered table-striped table-condensed'>\n";
    print "<thead><tr><th colspan='2'>Upload Files...</th></tr></thead>\n";
    print "<tr><td colspan='2'><input type='file' class='btn btn-default' size='15' name='file0'><br>\n";
    print "<tr><td colspan='2'>Mode: <label><input type='radio' name='type' value='ascii'><code>Ascii</code></label> <label><input type='radio' name='type' value='binary' checked><code>Binary</code></label> <input type='submit' class='btn btn-default' value='Upload'></td></tr>\n";
    print "</table>\n";
    print "</form>\n";
    print "<form action='$script' method='post'>\n";
    print "<input type='hidden' name='p' value='$FORM{p}'>\n";
    print "<input type='hidden' name='c' value='$FORM{c}'>\n";
    print "<input type='hidden' name='m' value='$FORM{m}'>\n";
    print "<input type='hidden' name='do' value='cd'>\n";
    print "<table class='table table-bordered table-striped table-condensed'>\n";
    print "<thead><tr><th colspan='2'>Change Directory...</th></tr></thead>\n";
    print "<tr><td colspan='2'>";
    print "<input type='text' name='directory' value='$thisdir' size='40'>\n";
    print " <input type='submit' class='btn btn-default' value='Change Directory'></td></tr>\n";
    print "</table><br>\n";
    print "</form>\n";

    print "<form action='$script' method='post' target='WHMConsole'>\n";
    print "<input type='hidden' name='p' value='$FORM{p}'>\n";
    print "<input type='hidden' name='c' value='$FORM{c}'>\n";
    print "<input type='hidden' name='m' value='$FORM{m}'>\n";
    print "<input type='hidden' name='do' value='console'>\n";
    print "<table class='table table-bordered table-striped table-condensed'>\n";
    print "<thead><tr><th colspan='2'>Virtual Console <code>$thisdir</code></th></tr></thead>\n";
    print "<tr><td colspan='2'>";
    print "<iframe width='100%' height='500' name='WHMConsole' style='border: 1px black solid' border='0' frameborder='0' src='$script?do=console&cmd=ls%20-la&p=$FORM{p}'></iframe>\n";
    print "<p>Command: <input type='text' name='cmd' value='' size='50' onFocus='this.value=\"\"'>\n";
    print " <input type='submit' class='btn btn-default' value='Send'></p>\n";
    print "<div class='bs-callout bs-callout-info'>Note: You cannot change directory within the console. Use the <em>Change Directory</em> feature above.</div>\n";
    print "</td></tr>\n";
    print "</table>\n";
    print "</form>\n";
    return;
}

sub _setp {
    my $status = 0;
    chmod( oct("0$FORM{newp}"), "$webpath$FORM{p}/$FORM{f}" ) or $status = $!;
    if   ($status) { $message = "Operation Failed - $status" }
    else           { $message = "" }
    _browse();
    return;
}

sub _seto {
    my $status = "";
    my ( $uid, $gid ) = split( /\:/, $FORM{newo} );
    if ( $uid !~ /^\d/ ) { $uid = ( getpwnam($uid) )[2] }
    if ( $gid !~ /^\d/ ) { $gid = ( getgrnam($gid) )[2] }
    if ( $uid eq "" )    { $message .= "No such user<br>\n" }
    if ( $gid eq "" )    { $message .= "No such group<br>\n" }

    if ( $message eq "" ) {
        chown( $uid, $gid, "$webpath$FORM{p}/$FORM{f}" ) or $status = $!;
        if   ($status) { $message = "Operation Failed - $status" }
        else           { $message = "" }
    }
    _browse();
    return;
}

sub _ren {
    my $status = 0;
    rename( "$webpath$FORM{p}/$FORM{f}", "$webpath$FORM{p}/$FORM{newf}" ) or $status = $!;
    if   ($status) { $message = "Operation Failed - $status" }
    else           { $message = "" }
    _browse();
    return;
}

sub _moveit {
    if ( "$webpath$FORM{m}" eq "$webpath$FORM{p}/$FORM{newf}" ) {
        $message = "Move Failed - Cannot overwrite original";
    }
    elsif ( ( -d "$webpath$FORM{m}" ) and ( "$webpath$FORM{p}/$FORM{newf}" =~ /^$webpath$FORM{m}\// ) ) {
        $message = "Move Failed - Cannot move inside original";
    }
    else {
        my $status = 0;
        rename( "$webpath$FORM{m}", "$webpath$FORM{p}/$FORM{newf}" ) or $status = $!;
        if   ($status) { $message = "Operation Failed - $status" }
        else           { $message = "" }
    }
    if ( $message eq "" ) { $FORM{m} = "" }
    _browse();
    return;
}

sub _copyit {
    if ( "$webpath$FORM{c}" eq "$webpath$FORM{p}/$FORM{newf}" ) {
        $message = "Copy Failed - Cannot overwrite original";
    }
    elsif ( ( -d "$webpath$FORM{c}" ) and ( "$webpath$FORM{p}/$FORM{newf}" =~ /^$webpath$FORM{c}\// ) ) {
        $message = "Copy Failed - Cannot copy inside original";
    }
    else {
        if ( -d "$webpath$FORM{c}" ) {
            $origpath = "$webpath$FORM{c}";
            $destpath = "$webpath$FORM{p}/$FORM{newf}";
            File::Find::find( \&_mycopy, $origpath );
        }
        else {
            File::Copy::copy( "$webpath$FORM{c}", "$webpath$FORM{p}/$FORM{newf}" ) or $message = "Copy Failed - $!";
            if ( $message eq "" ) {
                my $mode = sprintf "%04o", ( stat("$webpath$FORM{c}") )[2] & oct("00777");
                chmod( oct($mode), "$webpath$FORM{p}/$FORM{newf}" ) or $message = "Permission Change Failed - $!";
            }
        }
    }
    if ( $message eq "" ) { $FORM{c} = "" }
    _browse();
    return;
}

sub _mycopy {
    my $file = $File::Find::name;
    ( my $dest = $file ) =~ s/^\Q$origpath/$destpath/;
    my $status = "";
    if ( -d $file ) {
        my $err = ( split( /\//, $dest ) )[-1];
        mkpath($dest) or $status = "Copy Failed Making New Dir [$err] - $!<br>\n";
    }
    elsif ( -f $file ) {
        my $err = ( split( /\//, $file ) )[-1];
        File::Copy::copy( $file, $dest ) or $status = "Copy Failed [$err] - $!<br>\n";
    }
    if ( $status eq "" ) {
        my $err  = ( split( /\//, $file ) )[-1];
        my $mode = sprintf "%04o", ( stat("$file") )[2] & oct("00777");
        chmod( oct($mode), "$dest" ) or $message .= "Copy Failed Setting Perms [$err] - $!<br>\n";
    }
    else {
        $message .= $status;
    }
    return;
}

sub _cnewd {
    my $status = 0;
    if ( $FORM{newf} ne "" ) {
        mkdir( "$webpath$FORM{p}/$FORM{newf}", 0777 ) or $status = $!;
    }
    if   ($status) { $message = "Operation Failed - $status" }
    else           { $message = "" }
    _browse();
    return;
}

sub _cnewf {
    my $status = 0;
    if ( $FORM{newf} ne "" ) {
        if ( -f "$webpath$FORM{p}/$FORM{newf}" ) {
            $status = "File exists";
        }
        else {
            open( my $OUT, ">", "$webpath$FORM{p}/$FORM{newf}" ) or $status = $!;
            flock( $OUT, Fcntl::LOCK_EX );
            close($OUT);
        }
    }
    if   ($status) { $message = "Operation Failed - $status" }
    else           { $message = "" }
    _browse();
    return;
}

sub _del {
    my $status = 0;
    if ( -d "$webpath$FORM{p}/$FORM{f}" ) {
        rmtree( "$webpath$FORM{p}/$FORM{f}", 0, 0 ) or $status = $!;
    }
    else {
        unlink("$webpath$FORM{p}/$FORM{f}") or $status = $!;
    }
    if   ($status) { $message = "Operation Failed - $status" }
    else           { $message = "" }
    _browse();
    return;
}

sub _view {
    if ( -e "$webpath$FORM{p}/$FORM{f}" ) {
        if ( -T "$webpath$FORM{p}/$FORM{f}" ) {
            print "content-type: text/plain\r\n";
        }
        else {
            print "content-type: application/octet-stream\r\n";
        }
        print "content-disposition: attachment; filename=$FORM{f}\r\n\r\n";

        open( my $IN, "<", "$webpath$FORM{p}/$FORM{f}" ) or die $!;
        flock( $IN, Fcntl::LOCK_SH );
        while (<$IN>) { print }
        close($IN);
    }
    else {
        print "content-type: text/html\r\n\r\n";
        print "File [$webpath$FORM{p}/$FORM{f}] not found!";
    }
    return;
}

sub _console {
    my $thisdir = "$webpath$FORM{p}";
    $thisdir =~ s/\/+/\//g;

    print "<p><pre style='white-space:pre-wrap;'>\n";
    print "root [$thisdir]# $FORM{cmd}\n";
    chdir $thisdir;

    $| = 1;
    my ( $childin, $childout );
    my $cmdpid = IPC::Open3::open3( $childin, $childout, $childout, $FORM{cmd} );
    while ( my $line = <$childout> ) {
        $line =~ s/\</\&lt\;/g;
        $line =~ s/\>/\&gt\;/g;
        print $line;
    }
    waitpid( $cmdpid, 0 );
    print "root [$thisdir]# _</pre></p>\n";
    print "<script>window.scrollTo(0,10000000);</script>";
    return;
}

sub _cd {
    if ( -d $FORM{directory} ) {
        $FORM{p} = $FORM{directory};
    }
    else {
        $message = "No such directory [$FORM{directory}]";
    }

    _browse();
    return;
}

sub _edit {
    open( my $IN, "<", "$webpath$FORM{p}/$FORM{f}" ) or die $!;
    flock( $IN, Fcntl::LOCK_SH );
    my @data = <$IN>;
    close($IN);

    my $filedata;
    foreach my $line (@data) {
        $line =~ s/\</&lt;/g;
        $line =~ s/\>/&gt;/g;
        $filedata .= $line;
    }

    my $lf = 0;
    if ( $filedata =~ /\r/ ) { $lf = 1 }

    print "<script language='javascript'>\n";
    print "	function check(file) {return confirm('Click OK to '+file)}\n";
    print "</script>\n";
    print "<form action='$script' method='post'>\n";
    print "<table class='table table-bordered table-striped'>\n";
    print "<tr><td align='center'>";
    print "<input type='hidden' name='p' value='$FORM{p}'>\n";
    print "<input type='hidden' name='f' value='$FORM{f}'>\n";
    print "<input type='hidden' name='lf' value='$lf'>\n";
    print "<textarea cols='100' rows='25' name='newf' style='width:100%'>$filedata</textarea>\n";
    print "</td></tr>\n";
    print "<tr><td align='center'>";
    print "<input type='submit' class='btn btn-default' name='do' value='Save'> \n";
    print "<input type='submit' class='btn btn-default' name='do' value='Cancel'>\n";
    print "</td>";
    print "</table>\n";
    print "</form>\n";
    return;
}

sub _save {
    unless ( $FORM{lf} ) { $FORM{newf} =~ s/\r//g }
    my $status = 0;
    open( my $OUT, ">", "$webpath$FORM{p}/$FORM{f}" ) or $status = $!;
    flock( $OUT, Fcntl::LOCK_EX );
    print $OUT $FORM{newf};
    close($OUT);

    if   ($status) { $message = "Operation Failed - $status" }
    else           { $message = "" }
    _browse();
    return;
}

sub _uploadfile {
    my $crlf = "\r\n";
    my @data = split( /$crlf/, $fileinc );

    my $boundary = $data[0];

    $boundary =~ s/\"//g;
    $boundary =~ s/$crlf//g;

    my $start    = 0;
    my $part_cnt = -1;
    undef @parts;
    my $fileno = 0;

    foreach my $line (@data) {
        if ( $line =~ /^$boundary--/ ) {
            last;
        }
        if ( $line =~ /^$boundary/ ) {
            $part_cnt++;
            $start = 1;
            next;
        }
        if ($start) {
            $parts[$part_cnt] .= $line . $crlf;
        }
    }

    foreach my $part (@parts) {
        my @partdata = split( /$crlf/, $part );
        undef %header;
        my $body          = "";
        my $dobody        = 0;
        my $lastfieldname = "";

        foreach my $line (@partdata) {
            if ( ( $line eq "" ) and !($dobody) ) {
                $dobody = 1;
                next;
            }

            if ($dobody) {
                $body .= $line . $crlf;
            }
            else {
                if ( $line =~ /^\s/ ) {
                    $header{$lastfieldname} .= $line;
                }
                else {
                    ( $fieldname, $value ) = split( /\:\s/, $line, 2 );
                    $fieldname = lc $fieldname;
                    $fieldname =~ s/-/_/g;
                    $header{$fieldname} = $value;
                    $lastfieldname = $fieldname;
                }
            }
        }

        my @elements = split( /\;/, $header{content_disposition} );
        foreach my $element (@elements) {
            $element =~ s/\s//g;
            $element =~ s/\"//g;
            ( $name, $value ) = split( /\=/, $element );
            $FORM{$value}      = $body;
            $ele{$name}        = $value;
            $ele{ $ele{name} } = $value;
            if ( $value =~ /^file(.*)$/ ) { $files = $1 }
        }

        my $filename = $ele{"file$files"};
        if ( $filename ne "" ) {
            $fileno++;
            $filename =~ s/\"//g;
            $filename =~ s/\r//g;
            $filename =~ s/\n//g;
            @bits     = split( /\\/, $filename );
            $filetemp = $bits[-1];
            @bits     = split( /\//, $filetemp );
            $filetemp = $bits[-1];
            @bits     = split( /\:/, $filetemp );
            $filetemp = $bits[-1];
            @bits     = split( /\"/, $filetemp );
            $filename = $bits[0];
            push( @filenames,  $filename );
            push( @filebodies, $body );
        }
    }

    $FORM{p}      =~ s/\r//g;
    $FORM{p}      =~ s/\n//g;
    $FORM{type}   =~ s/\r//g;
    $FORM{type}   =~ s/\n//g;
    $FORM{c}      =~ s/\r//g;
    $FORM{c}      =~ s/\n//g;
    $FORM{m}      =~ s/\r//g;
    $FORM{m}      =~ s/\n//g;
    $FORM{caller} =~ s/\r//g;
    $FORM{caller} =~ s/\n//g;

    for ( my $x = 0; $x < @filenames; $x++ ) {
        $filenames[$x] =~ s/\r//g;
        $filenames[$x] =~ s/\n//g;
        $filenames[$x] =~ s/^file-//g;
        $filenames[$x] = ( split( /\\/, $filenames[$x] ) )[-1];
        $filenames[$x] = ( split( /\//, $filenames[$x] ) )[-1];
        if ( $FORM{type} eq "ascii" ) { $filebodies[$x] =~ s/\r//g }
        if ( -e "$webpath$FORM{p}/$filenames[$x]" ) {
            $extramessage .= "<br>$filenames[$x] - Already exists, delete the original first";
            $fileno--;
            next;
        }
        sysopen( my $OUT, "$webpath$FORM{p}/$filenames[$x]", Fcntl::O_WRONLY | Fcntl::O_CREAT );
        flock( $OUT, Fcntl::LOCK_EX );
        print $OUT $filebodies[$x];
        close($OUT);
        $extramessage .= "<br>$filenames[$x] - Uploaded";
    }

    $message = "$fileno File(s) Uploaded" . $extramessage;

    _browse();
    return;
}

sub _countfiles {
    if   ( -d $File::Find::name ) { push( @dirs,  $File::Find::name ) }
    else                          { push( @files, $File::Find::name ) }
    return;
}

1;

__END__

=head1 AUTHOR

Jonathan Michaelson, Way to the Web Limited, L<https://www.configserver.com>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2006-2025 Jonathan Michaelson

This program is free software; you can redistribute it and/or modify it under
the terms of the GNU General Public License as published by the Free Software
Foundation; either version 3 of the License, or (at your option) any later
version.

=cut
