package cPstrict;

#                                      Copyright 2024 WebPros International, LLC
#                                                           All rights reserved.
# copyright@cpanel.net                                         http://cpanel.net
# This code is subject to the cPanel license. Unauthorized copying is prohibited.

use strict;
use warnings;

=pod

This is importing the following to your namespace

    use strict;
    use warnings;
    use v5.30;

    use feature 'signatures';
    no warnings 'experimental::signatures';

=cut

sub import {
    if ( $] < 5.030 ) {
        require Carp;
        Carp::confess("cPstrict is being loaded from an unsupported perl ($^X)");
    }

    # auto import strict and warnings to our caller

    warnings->import();
    strict->import();

    require feature;
    feature->import( ':5.30', 'signatures' );
    warnings->unimport('experimental::signatures');

    return;
}

1;
