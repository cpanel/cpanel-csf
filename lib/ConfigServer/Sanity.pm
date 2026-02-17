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
package ConfigServer::Sanity;

=head1 NAME

ConfigServer::Sanity - Configuration value validation against acceptable ranges

=head1 SYNOPSIS

    use ConfigServer::Sanity ();

    # Validate a configuration value
    my ($insane, $acceptable, $default) = ConfigServer::Sanity::sanity('AT_ALERT', '2');

    if ($insane) {
        warn "Invalid value! Acceptable: $acceptable, Default: $default\n";
    }

    # Check multiple values
    foreach my $item (qw(AT_ALERT CC_LOOKUPS)) {
        my ($insane, $acceptable, $default) = ConfigServer::Sanity::sanity($item, $config{$item});
        if ($insane) {
            print "$item validation failed\n";
        }
    }

=head1 DESCRIPTION

This module provides configuration value validation for CSF (ConfigServer Security
& Firewall). It validates configuration values against acceptable ranges and discrete
values defined in the sanity.txt file.

The module uses lazy-loading - the sanity.txt file is not read until the first call
to C<sanity()>, and the data is cached for the lifetime of the process.

Validation rules support:

=over 4

=item * B<Range validation> - Numeric ranges (e.g., "0-100")

=item * B<Discrete validation> - Specific allowed values (e.g., "0|1|2")

=item * B<Mixed validation> - Combinations of ranges and discrete values

=back

Special handling is provided for IPSET configurations, where DENY_IP_LIMIT
validation is automatically skipped when IPSET is enabled.

=cut

use cPstrict;

use Fcntl                ();
use Carp                 ();
use ConfigServer::Config ();

our $VERSION = 1.02;

=head2 sanity

    my ($insane, $acceptable, $default) = ConfigServer::Sanity::sanity($item, $value);

Validates a configuration value against acceptable range or discrete values defined
in sanity.txt.

B<Parameters:>

=over 4

=item C<$item> - Configuration item name (e.g., 'AT_ALERT')

=item C<$value> - Value to validate

=back

B<Returns:> Three-element list:

=over 4

=item C<$insane> - 0 if value is valid, 1 if invalid

=item C<$acceptable> - Human-readable acceptable values string (e.g., "0 or 3")

=item C<$default> - Recommended default value from sanity.txt (may be undef)

=back

B<Examples:>

Range validation:

    # AT_INTERVAL=10-3600=60 in sanity.txt
    my ($insane, $acceptable, $default) = ConfigServer::Sanity::sanity('AT_INTERVAL', '60');
    # Returns: (0, "10-3600", "60") - valid

    my ($bad, $acceptable, $default) = ConfigServer::Sanity::sanity('AT_INTERVAL', '5');
    # Returns: (1, "10-3600", "60") - invalid

=cut

# Package variables for caching sanity data (accessible to tests)
our %sanity;
our %sanitydefault;
our $loaded     = 0;
our $sanityfile = "/usr/local/csf/lib/sanity.txt";

sub sanity {
    my $sanity_item  = shift;
    my $sanity_value = shift;

    # Return early if value is undefined
    return 0 unless defined $sanity_value;

    # Lazy-load sanity.txt data on first call (T015-T023)

    if ( !$loaded ) {
        open( my $IN, "<", $sanityfile ) or Carp::croak("Cannot open $sanityfile: $!");
        flock( $IN, Fcntl::LOCK_SH );
        my @data = <$IN>;
        close($IN);
        chomp @data;
        foreach my $line (@data) {
            my ( $name, $value, $def ) = split( /\=/, $line );
            $sanity{$name}        = $value;
            $sanitydefault{$name} = $def;
        }

        # Check IPSET configuration to skip DENY_IP_LIMIT validation if enabled
        my $ipset = ConfigServer::Config->get_config('IPSET');
        if ($ipset) {
            delete $sanity{DENY_IP_LIMIT};
            delete $sanitydefault{DENY_IP_LIMIT};
        }

        $loaded = 1;
    }

    my $insane = 0;

    $sanity_item  =~ s/\s//g;
    $sanity_value =~ s/\s//g;

    if ( defined $sanity{$sanity_item} ) {
        $insane = 1;
        foreach my $check ( split( /\|/, $sanity{$sanity_item} ) ) {
            if ( $check =~ /-/ ) {
                my ( $from, $to ) = split( /\-/, $check );
                if ( ( $sanity_value >= $from ) and ( $sanity_value <= $to ) ) { $insane = 0 }

            }
            else {
                if ( $sanity_value eq $check ) { $insane = 0 }
            }
        }
    }

    # Format acceptable values for display (make a copy to avoid modifying cached data)
    my $acceptable_display = defined $sanity{$sanity_item} ? $sanity{$sanity_item} : undef;
    $acceptable_display =~ s/\|/ or /g if defined $acceptable_display;

    return ( $insane, $acceptable_display, $sanitydefault{$sanity_item} );
}

1;

__END__

=head1 SANITY CHECK FILE FORMAT

The sanity.txt file defines validation rules in the following format:

    ITEM_NAME=acceptable_values=default_value

Where:

=over 4

=item B<ITEM_NAME> - Configuration item identifier (must match csf.conf key)

=item B<acceptable_values> - Validation specification

=over 4

=item * Range: C<min-max> (e.g., C<0-100>)

=item * Discrete: C<val1|val2|val3> (e.g., C<0|1|2>)

=item * Mixed: C<val1|min-max|val2> (e.g., C<0|10-20|99>)

=back

=item B<default_value> - Recommended default (optional, may be omitted)

=back

B<Examples:>

    AT_ALERT=0-3=2                    # Range with default
    CC6_LOOKUPS=0-1                   # Range without default
    CT_LIMIT=0|1-1000=0               # Mixed validation

=head1 SPECIAL CASES

=head2 IPSET Handling

When IPSET is enabled in csf.conf, DENY_IP_LIMIT validation is automatically
skipped. This is because IPSET uses different data structures that don't have
the same limits as traditional iptables rules.

=head2 Undefined Items

Configuration items not defined in sanity.txt will return:

    ($insane, $acceptable, $default) = (0, undef, undef)

This is considered "sane" - the item passes validation when no rule exists.

=head1 DEPENDENCIES

=over 4

=item L<Fcntl> - For file locking (LOCK_SH)

=item L<Carp> - For error reporting

=item L<ConfigServer::Config> - For reading IPSET configuration value

=back

=head1 FILES

=over 4

=item F</usr/local/csf/lib/sanity.txt>

Validation rules file defining acceptable values and defaults for all
configuration items.

=item F</usr/local/csf/etc/csf.conf>

Main CSF configuration file (accessed via ConfigServer::Config for IPSET value).

=back

=head1 SEE ALSO

L<ConfigServer::Config>, L<csf(1)>, L<lfd(1)>

=head1 AUTHOR

See the copyright header at the top of this file for authorship information.

=head1 COPYRIGHT

Copyright (C) 2006-2025 Jonathan Michaelson. This program is free software;
you can redistribute it and/or modify it under the terms of the GNU General
Public License as published by the Free Software Foundation; either version 3
of the License, or (at your option) any later version.

See L<https://www.gnu.org/licenses/> for the full license text.

=cut
