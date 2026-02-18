#!/usr/local/cpanel/3rdparty/bin/perl

#                                      Copyright 2025 WebPros International, LLC
#                                                           All rights reserved.
# copyright@cpanel.net                                         http://cpanel.net
# This code is subject to the cPanel license. Unauthorized copying is prohibited.

use lib 't/lib';
use FindBin::libs;

use cPstrict;

use Test2::V0;
use Test2::Plugin::NoWarnings;

use File::Temp qw(tempfile);

use ConfigServer::Slurp;

# Test module basics
subtest 'Module basics' => sub {
    ok( ConfigServer::Slurp->can('slurp'),    'slurp function exists' );
    ok( ConfigServer::Slurp->can('slurpee'),  'slurpee function exists' );
    ok( ConfigServer::Slurp->can('slurpreg'), 'slurpreg function exists' );
    ok( ConfigServer::Slurp->can('cleanreg'), 'cleanreg function exists' );
};

# Test package variables
subtest 'Package variables' => sub {
    ok( defined $ConfigServer::Slurp::VERSION, 'VERSION is defined' );
    is( ref ConfigServer::Slurp->slurpreg(), 'Regexp', 'slurpreg is a regexp' );
    is( ref ConfigServer::Slurp->cleanreg(), 'Regexp', 'cleanreg is a regexp' );
};

# Test slurpreg function
subtest 'slurpreg() returns regex' => sub {
    my $regex = ConfigServer::Slurp->slurpreg();
    is( ref $regex, 'Regexp', 'slurpreg() returns Regexp object' );

    # Test that it matches various line endings
    like( "\n",       qr/^$regex$/, 'Matches Unix line ending (LF)' );
    like( "\r\n",     qr/^$regex$/, 'Matches Windows line ending (CRLF)' );
    like( "\r",       qr/^$regex$/, 'Matches old Mac line ending (CR)' );
    like( "\x0C",     qr/^$regex$/, 'Matches form feed' );
    like( "\x{2028}", qr/^$regex$/, 'Matches Unicode line separator' );
    like( "\x{2029}", qr/^$regex$/, 'Matches Unicode paragraph separator' );
};

# Test cleanreg function
subtest 'cleanreg() returns regex' => sub {
    my $regex = ConfigServer::Slurp->cleanreg();
    is( ref $regex, 'Regexp', 'cleanreg() returns Regexp object' );

    # Test that it matches what it should
    like( "\r",         qr/$regex/, 'Matches carriage return' );
    like( "\n",         qr/$regex/, 'Matches newline' );
    like( "  leading",  qr/$regex/, 'Matches leading whitespace' );
    like( "trailing  ", qr/$regex/, 'Matches trailing whitespace' );
    unlike( "no-match", qr/^$regex$/, 'Does not match text without special chars' );
};

# Test slurp with Unix line endings
subtest 'slurp() reads file with Unix line endings' => sub {
    my ( $fh, $filename ) = tempfile( UNLINK => 1 );
    print $fh "line1\nline2\nline3\n";
    close $fh;

    my @lines = ConfigServer::Slurp::slurp($filename);
    is( scalar @lines, 3,       'Returns correct number of lines' );
    is( $lines[0],     'line1', 'First line correct' );
    is( $lines[1],     'line2', 'Second line correct' );
    is( $lines[2],     'line3', 'Third line correct' );
};

# Test slurp with Windows line endings
subtest 'slurp() reads file with Windows line endings' => sub {
    my ( $fh, $filename ) = tempfile( UNLINK => 1 );
    print $fh "line1\r\nline2\r\nline3\r\n";
    close $fh;

    my @lines = ConfigServer::Slurp::slurp($filename);
    is( scalar @lines, 3,       'Returns correct number of lines' );
    is( $lines[0],     'line1', 'First line correct' );
    is( $lines[1],     'line2', 'Second line correct' );
    is( $lines[2],     'line3', 'Third line correct' );
};

# Test slurp with mixed line endings
subtest 'slurp() handles mixed line endings' => sub {
    my ( $fh, $filename ) = tempfile( UNLINK => 1 );
    print $fh "line1\nline2\r\nline3\rline4";
    close $fh;

    my @lines = ConfigServer::Slurp::slurp($filename);
    is( scalar @lines, 4,       'Returns correct number of lines' );
    is( $lines[0],     'line1', 'First line correct' );
    is( $lines[1],     'line2', 'Second line correct' );
    is( $lines[2],     'line3', 'Third line correct' );
    is( $lines[3],     'line4', 'Fourth line correct (no newline at end)' );
};

# Test slurp with empty file
subtest 'slurp() handles empty file' => sub {
    my ( $fh, $filename ) = tempfile( UNLINK => 1 );
    close $fh;

    my @lines = ConfigServer::Slurp::slurp($filename);
    is( scalar @lines, 0, 'Returns empty array for empty file' );
};

# Test slurp with file containing only newlines
subtest 'slurp() handles file with only newlines' => sub {
    my ( $fh, $filename ) = tempfile( UNLINK => 1 );
    print $fh "\n\n\n";
    close $fh;

    my @lines = ConfigServer::Slurp::slurp($filename);

    # split() removes trailing empty elements, so file with only newlines returns empty array
    is( scalar @lines, 0, 'Returns empty array (split removes trailing empty)' );
};

# Test slurp with empty lines between content
subtest 'slurp() handles empty lines between content' => sub {
    my ( $fh, $filename ) = tempfile( UNLINK => 1 );
    print $fh "line1\n\nline3\n";
    close $fh;

    my @lines = ConfigServer::Slurp::slurp($filename);
    is( scalar @lines, 3,       'Returns correct number of lines' );
    is( $lines[0],     'line1', 'First line correct' );
    is( $lines[1],     '',      'Second line is empty' );
    is( $lines[2],     'line3', 'Third line correct' );
};

# Test slurp with non-existent file
subtest 'slurp() handles non-existent file' => sub {
    my $warning;
    local $SIG{__WARN__} = sub {
        $warning = $_[0];
        return;
    };
    my @lines = ConfigServer::Slurp::slurp('/nonexistent/path/to/file.txt');
    is( \@lines, [], 'File not found does not die' );
    ok( $warning, "Got a warning" );
};

# Test slurp with special characters
subtest 'slurp() preserves special characters' => sub {
    my ( $fh, $filename ) = tempfile( UNLINK => 1 );
    binmode $fh, ':utf8';
    print $fh "line with spaces   \n";
    print $fh "line with\ttabs\n";
    print $fh "line with 'quotes'\n";
    print $fh "line with \"double quotes\"\n";
    close $fh;

    my @lines = ConfigServer::Slurp::slurp($filename);
    is( $lines[0], 'line with spaces   ',       'Preserves trailing spaces in line' );
    is( $lines[1], "line with\ttabs",           'Preserves tabs' );
    is( $lines[2], "line with 'quotes'",        'Preserves single quotes' );
    is( $lines[3], 'line with "double quotes"', 'Preserves double quotes' );
};

# Test slurp return value in scalar context
subtest 'slurp() return values' => sub {
    my ( $fh, $filename ) = tempfile( UNLINK => 1 );
    print $fh "line1\nline2\n";
    close $fh;

    my @lines = ConfigServer::Slurp::slurp($filename);
    is( ref \@lines, 'ARRAY', 'Returns array in list context' );
    ok( scalar @lines > 0, 'Array is not empty' );
};

# Test that slurp can be imported
subtest 'slurp can be imported' => sub {

    # Test by attempting to compile code that imports slurp
    my $test_code = 'use ConfigServer::Slurp qw(slurp); 1;';

    my $result = system( $^X, '-Ilib', '-e', $test_code );
    is( $result, 0, 'slurp can be imported without errors' );
};

# Test slurpee can be imported
subtest 'slurpee can be imported' => sub {

    # Test by attempting to compile code that imports slurpee
    my $test_code = 'use ConfigServer::Slurp qw(slurpee); 1;';

    my $result = system( $^X, '-Ilib', '-e', $test_code );
    is( $result, 0, 'slurpee can be imported without errors' );
};

# Test slurpee() with default options (wantarray => 1)
subtest 'slurpee() with default options returns array' => sub {
    my ( $fh, $filename ) = tempfile( UNLINK => 1 );
    print $fh "line1\nline2\nline3\n";
    close $fh;

    my @lines = ConfigServer::Slurp::slurpee($filename);
    is( scalar @lines, 3,       'Returns correct number of lines' );
    is( $lines[0],     'line1', 'First line correct' );
    is( $lines[1],     'line2', 'Second line correct' );
    is( $lines[2],     'line3', 'Third line correct' );
};

# Test slurpee() with wantarray => 0 returns scalar
subtest 'slurpee() with wantarray => 0 returns scalar' => sub {
    my ( $fh, $filename ) = tempfile( UNLINK => 1 );
    print $fh "line1\nline2\nline3\n";
    close $fh;

    my $content = ConfigServer::Slurp::slurpee( $filename, wantarray => 0 );
    is( ref \$content, 'SCALAR', 'Returns scalar value' );
    like( $content, qr/line1/,          'Contains first line' );
    like( $content, qr/line2/,          'Contains second line' );
    like( $content, qr/line3/,          'Contains third line' );
    like( $content, qr/line1\nline2\n/, 'Preserves line endings' );
};

# Test slurpee() with wantarray => 1 (explicit)
subtest 'slurpee() with wantarray => 1 returns array' => sub {
    my ( $fh, $filename ) = tempfile( UNLINK => 1 );
    print $fh "line1\nline2\n";
    close $fh;

    my @lines = ConfigServer::Slurp::slurpee( $filename, wantarray => 1 );
    is( scalar @lines, 2,       'Returns array with correct number of lines' );
    is( $lines[0],     'line1', 'First line correct' );
    is( $lines[1],     'line2', 'Second line correct' );
};

# Test slurpee() with warn => 0 suppresses warnings
subtest 'slurpee() with warn => 0 suppresses warnings' => sub {
    my $warning;
    local $SIG{__WARN__} = sub {
        $warning = $_[0];
        return;
    };

    my @lines = ConfigServer::Slurp::slurpee( '/nonexistent/file.txt', warn => 0 );
    is( \@lines,  [],  'Returns empty array for non-existent file' );
    is( $warning, U(), 'No warning emitted when warn => 0' );
};

# Test slurpee() with warn => 1 (default) emits warnings
subtest 'slurpee() with warn => 1 emits warnings' => sub {
    my $warning;
    local $SIG{__WARN__} = sub {
        $warning = $_[0];
        return;
    };

    my @lines = ConfigServer::Slurp::slurpee( '/nonexistent/file.txt', warn => 1 );
    is( \@lines, [], 'Returns empty array for non-existent file' );
    like( $warning, qr/\*Error\* File does not exist:/, 'Warning emitted when warn => 1' );
};

# Test slurpee() with fatal => 1 croaks on error
subtest 'slurpee() with fatal => 1 croaks on error' => sub {
    like(
        dies { ConfigServer::Slurp::slurpee( '/nonexistent/file.txt', fatal => 1 ) },
        qr/\*Error\* File does not exist:/,
        'Croaks when fatal => 1 and file does not exist'
    );
};

# Test slurpee() with fatal => 0 (default) does not croak
subtest 'slurpee() with fatal => 0 does not croak' => sub {
    my $warning;
    local $SIG{__WARN__} = sub {
        $warning = $_[0];
        return;
    };

    my $result = lives { ConfigServer::Slurp::slurpee( '/nonexistent/file.txt', fatal => 0 ) };
    ok( $result,         'Does not croak when fatal => 0' );
    ok( length $warning, "Also emits warning" );
};

# Test slurpee() with empty file and wantarray => 0
subtest 'slurpee() with empty file and wantarray => 0' => sub {
    my ( $fh, $filename ) = tempfile( UNLINK => 1 );
    close $fh;

    my $content = ConfigServer::Slurp::slurpee( $filename, wantarray => 0 );
    is( $content, U(), 'Returns undef for empty file when wantarray => 0' );
};

# Test slurpee() with empty file and wantarray => 1
subtest 'slurpee() with empty file and wantarray => 1' => sub {
    my ( $fh, $filename ) = tempfile( UNLINK => 1 );
    close $fh;

    my @lines = ConfigServer::Slurp::slurpee( $filename, wantarray => 1 );
    is( scalar @lines, 0, 'Returns empty array for empty file when wantarray => 1' );
};

# Test slurpee() with mixed line endings and wantarray => 0
subtest 'slurpee() with mixed line endings and wantarray => 0' => sub {
    my ( $fh, $filename ) = tempfile( UNLINK => 1 );
    print $fh "line1\nline2\r\nline3\r";
    close $fh;

    my $content = ConfigServer::Slurp::slurpee( $filename, wantarray => 0 );
    like( $content, qr/line1\nline2\r\nline3\r/, 'Preserves all line endings in scalar mode' );
};

# Test slurpee() with multiple options combined
subtest 'slurpee() with multiple options combined' => sub {
    my ( $fh, $filename ) = tempfile( UNLINK => 1 );
    print $fh "test content\n";
    close $fh;

    my $content = ConfigServer::Slurp::slurpee( $filename, wantarray => 0, warn => 0 );
    like( $content, qr/test content/, 'Combines wantarray => 0 and warn => 0 correctly' );
};

# Test slurpee() preserves Unicode in scalar mode
subtest 'slurpee() preserves Unicode in scalar mode' => sub {
    my ( $fh, $filename ) = tempfile( UNLINK => 1 );
    binmode $fh, ':utf8';
    print $fh "Unicode: \x{2028} line separator\n";
    close $fh;

    my $content = ConfigServer::Slurp::slurpee( $filename, wantarray => 0 );
    like( $content, qr/Unicode:/, 'Contains Unicode content in scalar mode' );
};

# Test slurpee() with Windows line endings in scalar mode
subtest 'slurpee() with Windows line endings in scalar mode' => sub {
    my ( $fh, $filename ) = tempfile( UNLINK => 1 );
    print $fh "line1\r\nline2\r\n";
    close $fh;

    my $content = ConfigServer::Slurp::slurpee( $filename, wantarray => 0 );
    like( $content, qr/line1\r\nline2\r\n/, 'Preserves CRLF in scalar mode' );
};

# Test that slurp() delegates to slurpee() correctly
subtest 'slurp() delegates to slurpee() with defaults' => sub {
    my ( $fh, $filename ) = tempfile( UNLINK => 1 );
    print $fh "line1\nline2\n";
    close $fh;

    my @lines_slurp   = ConfigServer::Slurp::slurp($filename);
    my @lines_slurpee = ConfigServer::Slurp::slurpee($filename);

    is( \@lines_slurp, \@lines_slurpee, 'slurp() returns same result as slurpee() with defaults' );
};

done_testing;
