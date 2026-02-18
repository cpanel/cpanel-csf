#!/usr/local/cpanel/3rdparty/bin/perl
# HARNESS-DURATION-LONG

#                                      Copyright 2024 WebPros International, LLC
#                                                           All rights reserved.
# copyright@cpanel.net                                         http://cpanel.net
# This code is subject to the cPanel license. Unauthorized copying is prohibited.

use lib 't/lib';
use FindBin::libs;

use cPstrict;

use Test2::V0;
use Test2::Plugin::NoWarnings;

use File::Find ();
use Perl::Tidy ();
use MCE::Loop chunk_size => 1;

# Find all Perl files
my @files;
File::Find::find(
    {
        wanted => sub {
            my $file = $File::Find::name;
            return if $file =~ m{/tmp/};
            return if $file =~ m{/BUILD/};
            return if $file =~ m{/RPMS/};
            return if $file =~ m{/SRPMS/};
            return if $file =~ m{/SOURCES/};
            return if $file =~ m{/SPECS/};
            return if $file =~ m{/cover_db/};
            return if $file =~ m{/nytprof/};
            return if $file =~ m{/debify/};
            return if -d $file;
            return unless $file =~ /\.(?:pl|pm|t)$/;
            push @files, $file;
        },
        no_chdir => 1,
    },
    '.'
);

# Process files in parallel and collect results
my @results = mce_loop {
    my $file   = $_;
    my $source = '';

    # Read the file
    if ( open my $fh, '<', $file ) {
        local $/;
        $source = <$fh>;
        close $fh;
    }
    else {
        MCE->gather( $file, "cannot open: $!" );
        return;
    }

    # Run perltidy
    my $tidied = '';
    my $err    = Perl::Tidy::perltidy(
        source      => \$source,
        destination => \$tidied,
        stderr      => \my $stderr,
        errorfile   => \my $errorfile,
        perltidyrc  => '.perltidyrc',
    );

    if ($err) {
        MCE->gather( $file, "perltidy error: $err" );
        return;
    }

    # Return result: file, error (if any), source, tidied
    MCE->gather( $file, ( $tidied eq $source ? undef : 'not tidy' ) );
    return;
}
\@files;

# Output test results sequentially
for ( my $i = 0; $i < @results; $i += 2 ) {
    my $file  = $results[$i];
    my $error = $results[ $i + 1 ];

    if ($error) {
        fail("$file - $error");
    }
    else {
        ok( 1, $file );
    }
}

done_testing;
