package Cpanel::Slurper;

# Bozo module of Cpanel::Slurper to be ran during testsuite execution

use cPstrict;

use File::Slurper;

no warnings qw{once};

*read = \&File::Slurper::read_binary;
*read_lines = \&File::Slurper::read_lines;

sub read_dir ($path) {
    my $dh;
    opendir( $dh, $path )    #
      or die "Can't open '$path': $!";
    return ( grep { defined $_ && $_ ne '.' && $_ ne '..' } readdir($dh) );
}

*write = \&File::Slurper::write_binary;

1;
