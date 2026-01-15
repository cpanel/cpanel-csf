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

package ConfigServer::Slurp;

=head1 NAME

ConfigServer::Slurp - File reading regexes with line-ending normalization

=head1 SYNOPSIS

    use ConfigServer::Slurp ();

    # Get line-ending regex pattern
    my $regex = ConfigServer::Slurp->slurpreg();

    # Get cleanup regex for whitespace/line endings
    my $cleanup = ConfigServer::Slurp->cleanreg();

=head1 DESCRIPTION

This module provides regexes for reading files and handling various line-ending
formats (Unix LF, Windows CRLF, old Mac CR, Unicode line separators). It includes
helper functions to access pre-compiled regular expressions for line-ending
detection and cleanup.

=cut

use cPstrict;

use Fcntl ();
use Carp  ();

our $VERSION   = 1.02;

our $slurpreg = qr/(?>\x0D\x0A?|[\x0A-\x0C\x85\x{2028}\x{2029}])/;
our $cleanreg = qr/(\r)|(\n)|(^\s+)|(\s+$)/;

=head1 FUNCTIONS

=head2 slurpreg

Returns a pre-compiled regular expression for matching line endings.

    my $regex = ConfigServer::Slurp->slurpreg();

=head3 Returns

A compiled C<Regexp> object that matches various line-ending formats including
Unix (LF), Windows (CRLF), old Mac (CR), form feed, and Unicode line/paragraph separators.

=head3 Side Effects

None.

=head3 Errors

None.

=cut

sub slurpreg {
    return $slurpreg;
}

=head2 cleanreg

Returns a pre-compiled regular expression for matching/removing carriage returns,
newlines, and leading/trailing whitespace.

    my $regex = ConfigServer::Slurp->cleanreg();
    $line =~ s/$regex//g;  # Remove all matched patterns

=head3 Returns

A compiled C<Regexp> object that matches:

=over 4

=item * Carriage return (C<\r>)

=item * Newline (C<\n>)

=item * Leading whitespace (C<^\s+>)

=item * Trailing whitespace (C<\s+$>)

=back

=head3 Side Effects

None.

=head3 Errors

None.

=cut

sub cleanreg {
    return $cleanreg;
}

=head1 EXPORTS

The C<slurp> function can be imported:

    use ConfigServer::Slurp qw(slurp);

=head1 VERSION

Version 1.02

=head1 AUTHOR

Jonathan Michaelson

=head1 COPYRIGHT

Copyright (C) 2006-2025 Jonathan Michaelson

This program is free software; you can redistribute it and/or modify it under
the terms of the GNU General Public License as published by the Free Software
Foundation; either version 3 of the License, or (at your option) any later
version.

=cut

1;
