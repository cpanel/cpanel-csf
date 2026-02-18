#!/usr/bin/env perl
package debify::mongler;

use strict;
use warnings;

use Cwd            ();
use File::Basename ();
use File::Slurper  ();

exit run(@ARGV) unless caller;

# This script exists to keep the %install and override_dh_auto_install.sh
# script N*Sync because debifain't no lie baby bye bye bye

sub run {
    my @args = @_;

    my $boilerplate = <<'BOIL';
#!/bin/bash

# Fix buildroot for Debian builds - it should be debian/tmp
# The vars.sh file sets it to /usr/src/packages/BUILD which is wrong
source debian/vars.sh
export buildroot="debian/tmp"

BOIL

    my $repo_dir  = Cwd::abs_path( File::Basename::dirname(__FILE__) . '/../' );
    my $spec2open = "$repo_dir/SPECS/cpanel-csf.spec";
    open( my $fh, "<", $spec2open ) or die "Can't open '$spec2open': $!";
    my $file_contents = "$boilerplate\n";
    my $in_install    = 0;
    while (<$fh>) {
        my $line = $_;
        if ( !$in_install ) {
            $in_install = index( $line, '%install' ) == 0;
            next;
        }
        next unless $in_install;
        $in_install = index( $line, '# END INSTALL' ) == -1;
        last if !$in_install;
        $file_contents .= $line;
    }
    close $fh;

    # Do a variable brain transplant
    $file_contents =~ s/%\{buildroot\}/\$buildroot/g;

    # Write out the override file with updated install.
    my $file = "$repo_dir/debify/debian/override_dh_auto_install.sh";
    File::Slurper::write_text( $file, $file_contents );
    system( qw{chmod +x}, $file ) and die "Can't chmod +x '$file', script exited $?";

    return 0;
}

1;
