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

ConfigServer::Slurp - File reading utilities with line-ending normalization

=head1 SYNOPSIS

    use ConfigServer::Slurp qw(slurp);

    # Read file and split by line endings
    my @lines = slurp('/path/to/file.txt');

    # Get line-ending regex pattern
    my $regex = ConfigServer::Slurp->slurpreg();

    # Get cleanup regex for whitespace/line endings
    my $cleanup = ConfigServer::Slurp->cleanreg();

=head1 DESCRIPTION

This module provides utilities for reading files and handling various line-ending
formats (Unix LF, Windows CRLF, old Mac CR, Unicode line separators). It includes
helper functions to access pre-compiled regular expressions for line-ending
detection and cleanup.

=cut

use cPstrict;

use Carp;

use Cpanel::Slurper;

use Exporter qw(import);
our $VERSION   = 1.02;
our @ISA       = qw(Exporter);
our @EXPORT_OK = qw(slurp slurpee);

my $slurpreg = qr/(?>\x0D\x0A?|[\x0A-\x0C\x85\x{2028}\x{2029}])/;
my $cleanreg = qr/(\r)|(\n)|(^\s+)|(\s+$)/;

=head1 FUNCTIONS

=head2 slurp

Reads a file and returns its contents as an array of lines, split by various
line-ending formats.

    my @lines = slurp($filepath);

=head3 Parameters

=over 4

=item * C<$filepath> - Path to the file to read

=back

=head3 Returns

In list context, returns an array of lines from the file (split by line endings).
Returns an empty list if the file does not exist or cannot be read.

=head3 Side Effects

=over 4

=item * Opens and locks the file for shared reading using C<flock>

=item * Emits a warning via C<Carp::carp> if the file cannot be opened, locked, or does not exist

=item * Closes the file handle after reading

=back

=head3 Errors

Issues warnings (via C<Carp::carp>) for:

=over 4

=item * File does not exist

=item * Unable to open file

=item * Unable to lock file

=back

=head3 Line Ending Support

Recognizes and splits on:

=over 4

=item * Unix line feed (LF, C<\x0A>)

=item * Windows carriage return + line feed (CRLF, C<\x0D\x0A>)

=item * Old Mac carriage return (CR, C<\x0D>)

=item * Form feed (C<\x0C>)

=item * Unicode line separator (C<\x{2028}>)

=item * Unicode paragraph separator (C<\x{2029}>)

=back

=cut

sub slurp ($file) {
    return slurpee($file);
}

my %defaults = (
    'warn'      => 1,
    'wantarray' => 1,
    'fatal'     => 0,
);

=head2 slurpee

Same as slurp, but accepts option hash for whether you `wantarray` or desire
warnings, etc..

The 'ee' stands for 'Extended Edition'.

=head3 Arguments

=over 4

=item * $file - File to slurp

=item * %opts - Options hash. Possible opts:

=over 4

=item - wantarray => Whether you want to return LIST or SCALAR.

=item - warn => Whether you want to warn on file slurp failing.

=item - fatal => Whether you want to die on file slurp failing.

=back

=back

=cut

sub slurpee ($file, %opts) {
    %opts = ( %defaults, %opts );
    local $@;
    my $text = eval { Cpanel::Slurper::read($file) };
    if ( !defined $text ) {
        my $err = "*Error* File does not exist: [$file]";
        Carp::croak($err) if $opts{'fatal'};
        Carp::carp($err)  if $opts{'warn'};
        return;
    }
    if(length $text ) {
        return split( /$slurpreg/, $text ) if $opts{'wantarray'};
        return $text;
    }
    return;
}

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
