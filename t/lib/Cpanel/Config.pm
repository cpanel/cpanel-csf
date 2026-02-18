package Cpanel::Config;

# Stub of Cpanel::Config for use during testsuite execution

use cPstrict;

sub loadcpconf {
    return %{ $Cpanel::Config::CpConfGuard::memory_only // {} };
}

1;
