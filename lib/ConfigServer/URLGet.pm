#                                      Copyright 2026 WebPros International, LLC
#                                                           All rights reserved.
# copyright@cpanel.net                                         http://cpanel.net
# This code is subject to the cPanel license. Unauthorized copying is prohibited.

package ConfigServer::URLGet;

=head1 NAME

ConfigServer::URLGet - HTTP/HTTPS URL retrieval utility with multiple backend support

=head1 SYNOPSIS

    use ConfigServer::URLGet;

    # Create a URLGet object
    # Option 1: HTTP::Tiny (default, fastest)
    my $urlget = ConfigServer::URLGet->new(1, "MyAgent/1.0", "http://proxy:8080");

    # Option 2: LWP::UserAgent (requires LWP)
    my $urlget = ConfigServer::URLGet->new(2, "MyAgent/1.0", "http://proxy:8080");

    # Option 3: Binary fallback (curl/wget)
    my $urlget = ConfigServer::URLGet->new(3, "MyAgent/1.0", "");

    # Download URL content to a string
    my ($status, $content) = $urlget->urlget("https://example.com/data.txt");
    if ($status == 0) {
        print "Success: $content\n";
    } else {
        print "Error: $content\n";
    }

    # Download URL to a file
    my ($status, $message) = $urlget->urlget("https://example.com/file.zip", "/tmp/file.zip");
    if ($status == 0) {
        print "Downloaded to: $message\n";
    } else {
        print "Error: $message\n";
    }

    # Download quietly (no progress output)
    my ($status, $content) = $urlget->urlget("https://example.com/data.txt", undef, 1);

=head1 DESCRIPTION

ConfigServer::URLGet provides a flexible HTTP/HTTPS URL retrieval mechanism with
support for multiple backends. It automatically selects the best available method
for downloading content, with fallback support for environments where Perl HTTP
modules are not available.

The module supports three download methods:

=over 4

=item 1. HTTP::Tiny (Default)

Lightweight, pure-Perl HTTP client. Best for most use cases. Automatically falls
back to binary methods if the download fails.

=item 2. LWP::UserAgent

Full-featured HTTP client with extensive protocol support. Requires the LWP module
to be installed. Falls back to binary methods on failure.

=item 3. Binary Fallback

Uses system curl or wget commands. Useful when Perl HTTP modules are unavailable
or unreliable. Configurable via csf.conf CURL and WGET settings.

=back

All methods support:

=over 4

=item * Progress indication for file downloads

=item * Proxy support

=item * Timeout handling (300-1200 seconds depending on method)

=item * Automatic retry with fallback methods

=item * Custom User-Agent strings

=back

=head1 CONFIGURATION

The binary fallback method reads configuration from ConfigServer::Config:

=over 4

=item * C<CURL> - Path to curl binary (e.g., /usr/bin/curl)

=item * C<WGET> - Path to wget binary (e.g., /usr/bin/wget)

=back

=head1 DEPENDENCIES

=over 4

=item * L<Fcntl> - File locking operations

=item * L<Carp> - Error reporting

=item * L<IPC::Open3> - Process execution for binary fallback

=item * L<ConfigServer::Config> - Configuration file access

=item * L<HTTP::Tiny> - HTTP client (option 1, usually available)

=item * L<LWP::UserAgent> - HTTP client (option 2, optional)

=back

System dependencies (for option 3 or fallback):

=over 4

=item * curl or wget command-line utilities

=back

=head1 SEE ALSO

L<ConfigServer::Config>, L<HTTP::Tiny>, L<LWP::UserAgent>

=cut

use cPstrict;

use Fcntl      ();
use Carp       ();
use IPC::Open3 ();

use ConfigServer::Config ();

our $VERSION = 2.00;

my $agent  = "ConfigServer";
my $option = 1;
my $proxy  = "";

$SIG{PIPE} = 'IGNORE';

=head2 new

    my $urlget = ConfigServer::URLGet->new($option, $agent, $proxy);

Creates a new URLGet object.

B<Parameters:>

=over 4

=item * C<$option> - Integer specifying the download method:

=over 4

=item * C<1> - Use HTTP::Tiny (default, recommended)

=item * C<2> - Use LWP::UserAgent (requires LWP module)

=item * C<3> - Use binary curl/wget fallback only

=back

=item * C<$agent> - String containing the User-Agent header value (default: "ConfigServer")

=item * C<$proxy> - String containing proxy URL (e.g., "http://proxy:8080") or empty string for no proxy

=back

B<Returns:> Blessed URLGet object, or C<undef> if option 2 is selected but LWP is not available

=cut

sub new {
    my $class = shift;
    $option = shift;
    $agent  = shift;
    $proxy  = shift;
    my $self = {};
    bless $self, $class;

    if ( $option == 3 ) {
        return $self;
    }
    elsif ( $option == 2 ) {
        eval('use LWP::UserAgent;');    ## no critic (BuiltinFunctions::ProhibitStringyEval) - Optional module load - falls back to HTTP::Tiny if unavailable
        if ($@) { return undef }
    }
    else {
        eval {
            local $SIG{__DIE__} = undef;
            eval('use HTTP::Tiny;');    ## no critic (BuiltinFunctions::ProhibitStringyEval) - Optional module load - lightweight HTTP client fallback
        };
    }

    return $self;
}

=head2 urlget

    my ($status, $text) = $urlget->urlget($url);
    my ($status, $text) = $urlget->urlget($url, $file);
    my ($status, $text) = $urlget->urlget($url, $file, $quiet);

Downloads content from a URL.

B<Parameters:>

=over 4

=item * C<$url> - String containing the URL to download (required)

=item * C<$file> - Optional string containing the destination file path. If provided,
content is saved to this file. If omitted, content is returned as a string.

=item * C<$quiet> - Optional boolean. If true, suppresses progress output during download.

=back

B<Returns:> Two-element list C<($status, $text)>

=over 4

=item * C<$status> - Integer status code:

=over 4

=item * C<0> - Success

=item * C<1> - Failure

=back

=item * C<$text> - On success:

=over 4

=item * If C<$file> was provided: The file path where content was saved

=item * If C<$file> was omitted: The downloaded content as a string

=back

On failure: Error message describing what went wrong

=back

B<File Downloads:>

When downloading to a file, the method creates a temporary file (C<$file.tmp>)
during download and renames it to the final name upon success. Progress is shown
as percentage completion (in 5% increments) unless C<$quiet> is true.

B<Automatic Fallback:>

If the primary method (HTTP::Tiny or LWP) fails, the module automatically attempts
to download using the binary fallback method (curl or wget) as configured in csf.conf.

=cut

sub urlget {
    my $self  = shift;
    my $url   = shift;
    my $file  = shift;
    my $quiet = shift;
    my $status;
    my $text;

    if ( !defined $url ) { Carp::carp("url not specified"); return }

    if ( $option == 3 ) {
        ( $status, $text ) = _binget( $url, $file, $quiet );
    }
    elsif ( $option == 2 ) {
        ( $status, $text ) = _urlgetLWP( $url, $file, $quiet );
    }
    else {
        ( $status, $text ) = _urlgetTINY( $url, $file, $quiet );
    }
    return ( $status, $text );
}

sub _urlgetTINY {
    my $url     = shift;
    my $file    = shift;
    my $quiet   = shift;
    my $status  = 0;
    my $timeout = 1200;
    if ( $proxy eq "" ) { undef $proxy }
    my $ua = HTTP::Tiny->new(
        'agent'   => $agent,
        'timeout' => 300,
        'proxy'   => $proxy
    );
    my $res;
    my $text;
    ( $status, $text ) = eval {
        local $SIG{__DIE__} = undef;
        local $SIG{'ALRM'}  = sub { die "Download timeout after $timeout seconds" };
        alarm($timeout);
        if ($file) {
            local $| = 1;
            my $expected_length;
            my $bytes_received = 0;
            my $per            = 0;
            my $oldper         = 0;
            open( my $OUT, ">", "$file\.tmp" ) or return ( 1, "Unable to open $file\.tmp: $!" );
            flock( $OUT, Fcntl::LOCK_EX );
            binmode($OUT);
            $res = $ua->request(
                'GET', $url,
                {
                    data_callback => sub {
                        my ( $chunk, $res ) = @_;
                        $bytes_received += length($chunk);
                        unless ( defined $expected_length ) { $expected_length = $res->{headers}->{'content-length'} || 0 }
                        if     ($expected_length) {
                            my $per = int( 100 * $bytes_received / $expected_length );
                            if ( ( int( $per / 5 ) == $per / 5 ) and ( $per != $oldper ) and !$quiet ) {
                                print "...$per\%\n";
                                $oldper = $per;
                            }
                        }
                        else {
                            unless ($quiet) { print "." }
                        }
                        print $OUT $chunk;
                    }
                }
            );
            close($OUT);
            unless ($quiet) { print "\n" }
        }
        else {
            $res = $ua->request( 'GET', $url );
        }
        alarm(0);
        if ( $res->{success} ) {
            if ($file) {
                rename( "$file\.tmp", "$file" ) or return ( 1, "Unable to rename $file\.tmp to $file: $!" );
                return ( 0, $file );
            }
            else {
                return ( 0, $res->{content} );
            }
        }
        else {
            my $reason = $res->{reason};
            if ( $res->{status} == 599 ) { $reason = $res->{content} }
            ( $status, $text ) = _binget( $url, $file, $quiet, $reason );
            return ( $status, $text );
        }
    };
    alarm(0);
    if ($@) { return ( 1, $@ ) }
    return ( $status, $text );
}

sub _urlgetLWP {
    my $url     = shift;
    my $file    = shift;
    my $quiet   = shift;
    my $status  = 0;
    my $timeout = 300;
    my $ua      = LWP::UserAgent->new;
    $ua->agent($agent);
    $ua->timeout(30);
    if ( $proxy ne "" ) { $ua->proxy( [ 'http', 'https' ], $proxy ) }

    #use LWP::ConnCache;
    #my $cache = LWP::ConnCache->new;
    #$cache->total_capacity([1]);
    #$ua->conn_cache($cache);
    my $req = HTTP::Request->new( GET => $url );
    my $res;
    my $text;
    ( $status, $text ) = eval {
        local $SIG{__DIE__} = undef;
        local $SIG{'ALRM'}  = sub { die "Download timeout after $timeout seconds" };
        alarm($timeout);
        if ($file) {
            local $| = 1;
            my $expected_length;
            my $bytes_received = 0;
            my $per            = 0;
            my $oldper         = 0;
            open( my $OUT, ">", "$file\.tmp" ) or return ( 1, "Unable to open $file\.tmp: $!" );
            flock( $OUT, Fcntl::LOCK_EX );
            binmode($OUT);
            $res = $ua->request(
                $req,
                sub {
                    my ( $chunk, $res ) = @_;
                    $bytes_received += length($chunk);
                    unless ( defined $expected_length ) { $expected_length = $res->content_length || 0 }
                    if     ($expected_length) {
                        my $per = int( 100 * $bytes_received / $expected_length );
                        if ( ( int( $per / 5 ) == $per / 5 ) and ( $per != $oldper ) and !$quiet ) {
                            print "...$per\%\n";
                            $oldper = $per;
                        }
                    }
                    else {
                        unless ($quiet) { print "." }
                    }
                    print $OUT $chunk;
                }
            );
            close($OUT);
            unless ($quiet) { print "\n" }
        }
        else {
            $res = $ua->request($req);
        }
        alarm(0);
        if ( $res->is_success ) {
            if ($file) {
                rename( "$file\.tmp", "$file" ) or return ( 1, "Unable to rename $file\.tmp to $file: $!" );
                return ( 0, $file );
            }
            else {
                return ( 0, $res->content );
            }
        }
        else {
            ( $status, $text ) = _binget( $url, $file, $quiet, $res->message );
            return ( $status, $text );
        }
    };
    alarm(0);
    if ($@) {
        return ( 1, $@ );
    }
    if ($text) {
        return ( $status, $text );
    }
    else {
        return ( 1, "Download timeout after $timeout seconds" );
    }
}

sub _binget {
    my $url      = shift;
    my $file     = shift;
    my $quiet    = shift;
    my $errormsg = shift;
    my $url_for_output = _redact_key_from_text($url);
    $url = "'$url'";
    my $quoted_url_for_output = "'$url_for_output'";

    my $cmd;
    my $curl_bin = ConfigServer::Config->get_config('CURL');
    my $wget_bin = ConfigServer::Config->get_config('WGET');
    if ( -e $curl_bin ) {
        $cmd = $curl_bin . " -skLf -m 120";
        if ($file) { $cmd = $curl_bin . " -kLf -m 120 -o"; }
    }
    elsif ( -e $wget_bin ) {
        $cmd = $wget_bin . " -qT 120 -O-";
        if ($file) { $cmd = $wget_bin . " -T 120 -O" }
    }
    if ( $cmd ne "" ) {
        if ($file) {
            my ( $childin, $childout );
            my $cmdpid = IPC::Open3::open3( $childin, $childout, $childout, $cmd . " $file\.tmp $url" );
            my @output = <$childout>;
            waitpid( $cmdpid, 0 );
            unless ( $quiet and $option != 3 ) {
                print "Using fallback [$cmd]\n";
                print map { _redact_key_from_text($_) } @output;
            }
            if ( -e "$file\.tmp" ) {
                rename( "$file\.tmp", "$file" ) or return ( 1, "Unable to rename $file\.tmp to $file: $!" );
                return ( 0, $file );
            }
            else {
                if ( $option == 3 ) {
                    my $output_for_error = join( "", map { _redact_key_from_text($_) } @output );
                    return ( 1, "Unable to download: " . $cmd . " $file\.tmp $quoted_url_for_output" . $output_for_error );
                }
                else {
                    return ( 1, "Unable to download: " . $errormsg );
                }
            }
        }
        else {
            my ( $childin, $childout );
            my $cmdpid = IPC::Open3::open3( $childin, $childout, $childout, $cmd . " $url" );
            my @output = <$childout>;
            waitpid( $cmdpid, 0 );
            if ( scalar @output > 0 ) {
                return ( 0, join( "", @output ) );
            }
            else {
                if ( $option == 3 ) {
                    my $output_for_error = join( "", map { _redact_key_from_text($_) } @output );
                    return ( 1, "Unable to download: [$cmd $quoted_url_for_output]" . $output_for_error );
                }
                else {
                    return ( 1, "Unable to download: " . $errormsg );
                }
            }
        }
    }
    if ( $option == 3 ) {
        return ( 1, "Unable to download (CURL/WGET also not present, see csf.conf)" );
    }
    else {
        return ( 1, "Unable to download (CURL/WGET also not present, see csf.conf): " . $errormsg );
    }
}

sub _redact_key_from_text {
    my $text = shift;
    return $text if !defined $text;

    $text =~ s/([?&])key=[^&\s'\"]*/${1}key=REDACTED/ig;

    return $text;
}

1;

=head1 VERSION

Version 2.00

=head1 AUTHOR

Jonathan Michaelson

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2006-2025 Jonathan Michaelson

This program is free software; you can redistribute it and/or modify it under
the terms of the GNU General Public License as published by the Free Software
Foundation; either version 3 of the License, or (at your option) any later
version.

=cut
