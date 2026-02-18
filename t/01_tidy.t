#!/usr/local/cpanel/3rdparty/bin/perl
# HARNESS-DURATION-LONG

#                                      Copyright 2024 WebPros International, LLC
#                                                           All rights reserved.
# copyright@cpanel.net                                         http://cpanel.net
# This code is subject to the cPanel license. Unauthorized copying is prohibited.

use Test::PerlTidy qw( run_tests );

run_tests(
    path    => '.',
    exclude => [
        qr{/tmp/},         # Temporary files directory
        qr{/BUILD/},       # Build artifacts
        qr{/RPMS/},        # RPM build output
        qr{/SRPMS/},       # Source RPM build output
        qr{/cover_db/},    # Coverage database
        qr{/nytprof/},     # Profiling output
    ],
);
