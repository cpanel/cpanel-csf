#!/usr/local/cpanel/3rdparty/bin/perl

#                                      Copyright 2026 WebPros International, LLC
#                                                           All rights reserved.
# copyright@cpanel.net                                         http://cpanel.net
# This code is subject to the cPanel license. Unauthorized copying is prohibited.

use cPstrict;

use Test2::V0;
use Test2::Tools::Explain;
use Test2::Plugin::NoWarnings;

use lib 't/lib';
use MockConfig;

use File::Temp qw(tempdir tempfile);

# Load modules that will be mocked
use HTTP::Tiny;
use LWP::UserAgent;
use HTTP::Request;

use ConfigServer::URLGet;

my $tempdir = tempdir( CLEANUP => 1 );

# Mock HTTP::Tiny
my $http_tiny_mock = mock 'HTTP::Tiny' => (
    override => [
        new => sub {
            my ( $class, %args ) = @_;
            return bless {%args}, $class;
        },
        request => sub {
            my ( $self, $method, $url, $options ) = @_;

            # Simulate successful download
            if ( $url =~ /success/ ) {
                my $content = "Test content from $url";

                # If data_callback is provided (file download)
                if ( $options && $options->{data_callback} ) {
                    my $callback = $options->{data_callback};
                    my $mock_res = { headers => { 'content-length' => length($content) } };
                    $callback->( $content, $mock_res );
                }

                return {
                    success => 1,
                    status  => 200,
                    content => $content,
                    headers => { 'content-length' => length($content) },
                };
            }

            # Simulate failure
            return {
                success => 0,
                status  => 404,
                reason  => 'Not Found',
                content => 'Resource not found',
            };
        },
    ],
);

# Mock LWP::UserAgent
my $lwp_mock = mock 'LWP::UserAgent' => (
    override => [
        new => sub {
            my $class = shift;
            return bless {}, $class;
        },
        agent   => sub { },
        timeout => sub { },
        proxy   => sub { },
        request => sub {
            my ( $self, $req, $callback ) = @_;

            my $url = ref($req) ? $req->uri : '';

            # Create mock response object
            my $mock_response = mock {} => (
                add => [
                    is_success     => sub { $url =~ /success/ ? 1 : 0 },
                    content        => sub { "LWP content from $url" },
                    content_length => sub { 100 },
                    message        => sub { 'Not Found' },
                ],
            );

            # If callback provided (file download)
            if ( $callback && $url =~ /success/ ) {
                $callback->( "LWP content from $url", $mock_response );
            }

            return $mock_response;
        },
    ],
);

# Mock HTTP::Request
my $http_request_mock = mock 'HTTP::Request' => (
    override => [
        new => sub {
            my ( $class, $method, $url ) = @_;
            return bless { method => $method, _uri => $url }, $class;
        },
        uri => sub {
            my $self = shift;
            return $self->{_uri};
        },
    ],
);

# Mock IPC::Open3::open3 for curl/wget
my $open3_mock = mock 'IPC::Open3' => (
    override => [
        open3 => sub {
            my ( $childin, $childout, $childerr, $cmd ) = @_;

            # Simulate curl/wget output by creating a filehandle
            my $content = "";
            if ( $cmd =~ /success/ ) {
                $content = "Binary download content";
            }

            my $fh;
            open( $fh, '<', \$content ) or die "Failed to open scalar: $!";
            $_[1] = $fh;
            $_[2] = $fh;

            return 12345;    # Mock PID
        },
    ],
);

# Mock configuration
set_config(
    CURL => '/usr/bin/curl',
    WGET => '/usr/bin/wget',
);

subtest 'new - option 1 (HTTP::Tiny)' => sub {
    my $urlget = ConfigServer::URLGet->new( 1, "TestAgent/1.0", "" );
    ok( $urlget, 'Created URLGet object with option 1' );
    isa_ok( $urlget, ['ConfigServer::URLGet'], 'Object is correct class' );
};

subtest 'new - option 2 (LWP::UserAgent)' => sub {
    my $urlget = ConfigServer::URLGet->new( 2, "TestAgent/1.0", "" );
    ok( $urlget, 'Created URLGet object with option 2' );
    isa_ok( $urlget, ['ConfigServer::URLGet'], 'Object is correct class' );
};

subtest 'new - option 3 (binary)' => sub {
    my $urlget = ConfigServer::URLGet->new( 3, "TestAgent/1.0", "" );
    ok( $urlget, 'Created URLGet object with option 3' );
    isa_ok( $urlget, ['ConfigServer::URLGet'], 'Object is correct class' );
};

subtest 'urlget - HTTP::Tiny success without file' => sub {
    my $urlget = ConfigServer::URLGet->new( 1, "TestAgent/1.0", "" );

    my ( $status, $text ) = $urlget->urlget("https://example.com/success");

    is( $status, 0, 'Download succeeded' );
    like( $text, qr/Test content/, 'Got expected content' );
};

subtest 'urlget - HTTP::Tiny success with file' => sub {
    my $urlget = ConfigServer::URLGet->new( 1, "TestAgent/1.0", "" );

    my $testfile = "$tempdir/download.txt";
    my ( $status, $text ) = $urlget->urlget( "https://example.com/success", $testfile, 1 );

    is( $status, 0,         'Download to file succeeded' );
    is( $text,   $testfile, 'Returns file path' );
    ok( -e $testfile, 'File was created' );
};

subtest 'urlget - HTTP::Tiny failure triggers _binget' => sub {
    set_config(
        CURL => '',
        WGET => '',
    );

    my $urlget = ConfigServer::URLGet->new( 1, "TestAgent/1.0", "" );

    my ( $status, $text );
    my @warnings = warnings { ( $status, $text ) = $urlget->urlget("https://example.com/fail") };

    # Should fail because binaries are not configured
    is( $status, 1, 'Download failed as expected' );
    like( $text, qr/Unable to download/, 'Got error message' );

    clear_config();
};

subtest 'urlget - LWP success without file' => sub {
    clear_config();
    set_config(
        CURL => '',
        WGET => '',
    );

    my $urlget = ConfigServer::URLGet->new( 2, "TestAgent/1.0", "" );

    my ( $status, $text ) = $urlget->urlget("https://example.com/success");

    is( $status, 0, 'LWP download succeeded' );
    like( $text, qr/LWP content/, 'Got LWP content' );

    clear_config();
};

subtest 'urlget - LWP success with file' => sub {
    clear_config();
    set_config(
        CURL => '',
        WGET => '',
    );

    my $urlget = ConfigServer::URLGet->new( 2, "TestAgent/1.0", "" );

    my $testfile = "$tempdir/lwp_download.txt";
    my ( $status, $text ) = $urlget->urlget( "https://example.com/success", $testfile, 1 );

    is( $status, 0,         'LWP download to file succeeded' );
    is( $text,   $testfile, 'Returns file path' );
    ok( -e $testfile, 'File was created' );

    clear_config();
};

subtest 'urlget - binary option with curl' => sub {
    set_config(
        CURL => '/usr/bin/curl',
        WGET => '/usr/bin/wget',
    );

    # Mock file existence check
    my $file_test_mock = mock 'ConfigServer::URLGet' => (
        override => [
            _binget => sub {
                my ( $url, $file, $quiet, $errormsg ) = @_;

                # Simulate successful curl download
                if ( $url =~ /success/ ) {
                    if ($file) {

                        # Create the file
                        open( my $fh, '>', $file );
                        print $fh "Binary download content";
                        close($fh);
                        return ( 0, $file );
                    }
                    return ( 0, "Binary download content" );
                }
                return ( 1, "Unable to download (CURL/WGET also not present, see csf.conf)" );
            },
        ],
    );

    my $urlget = ConfigServer::URLGet->new( 3, "TestAgent/1.0", "" );

    my ( $status, $text ) = $urlget->urlget("https://example.com/success");

    is( $status, 0, 'Binary download succeeded' );
    like( $text, qr/Binary download/, 'Got binary content' );

    clear_config();
};

subtest 'urlget - redacts key in binary errors' => sub {
    clear_config();

    my ( $curl_fh, $curl_path ) = tempfile( DIR => $tempdir );
    close $curl_fh;

    set_config(
        CURL => $curl_path,
        WGET => '',
    );

    my $urlget = ConfigServer::URLGet->new( 3, "TestAgent/1.0", "" );
    my ( $status, $text ) = $urlget->urlget('https://example.com/fail?key=SUPERSECRET');

    is( $status, 1, 'Binary download fails as expected' );
    like( $text, qr/key=REDACTED/i, 'Error text redacts key parameter' );
    unlike( $text, qr/SUPERSECRET/, 'Error text does not leak secret key' );

    clear_config();
};

subtest 'urlget - missing URL parameter' => sub {
    my $urlget = ConfigServer::URLGet->new( 1, "TestAgent/1.0", "" );

    my @result;
    my @warnings = warnings { @result = $urlget->urlget(undef) };

    is( \@result, [], 'Returns empty list when URL not specified' );
};

subtest 'urlget - proxy support' => sub {
    my $urlget = ConfigServer::URLGet->new( 1, "TestAgent/1.0", "http://proxy:8080" );

    my ( $status, $text ) = $urlget->urlget("https://example.com/success");

    is( $status, 0, 'Download with proxy succeeded' );
};

subtest 'urlget - quiet mode' => sub {
    my $urlget = ConfigServer::URLGet->new( 1, "TestAgent/1.0", "" );

    my $testfile = "$tempdir/quiet_download.txt";
    my ( $status, $text ) = $urlget->urlget( "https://example.com/success", $testfile, 1 );

    is( $status, 0, 'Quiet download succeeded' );
    ok( -e $testfile, 'File was created in quiet mode' );
};

done_testing;
