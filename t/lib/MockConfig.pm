package MockConfig;

use strict;
use warnings;

use Test2::V0;

# Prevent ConfigServer::Config from being loaded by setting $INC
# This tells Perl the module is already loaded, avoiding actual file load
BEGIN {
    $INC{'ConfigServer/Config.pm'} = __FILE__;

    # Stub the ConfigServer::Config package so we can mock it
    package ConfigServer::Config;
    our $VERSION = 1.00;

    # IPv4 and IPv6 regex patterns (copied from ConfigServer::Config)
    my $ipv4reg = qr/(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)/;
    my $ipv6reg =
      qr/((([0-9A-Fa-f]{1,4}:){7}([0-9A-Fa-f]{1,4}|:))|(([0-9A-Fa-f]{1,4}:){6}(:[0-9A-Fa-f]{1,4}|((25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)(\.(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)){3})|:))|(([0-9A-Fa-f]{1,4}:){5}(((:[0-9A-Fa-f]{1,4}){1,2})|:((25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)(\.(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)){3})|:))|(([0-9A-Fa-f]{1,4}:){4}(((:[0-9A-Fa-f]{1,4}){1,3})|((:[0-9A-Fa-f]{1,4})?:((25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)(\.(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)){3}))|:))|(([0-9A-Fa-f]{1,4}:){3}(((:[0-9A-Fa-f]{1,4}){1,4})|((:[0-9A-Fa-f]{1,4}){0,2}:((25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)(\.(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)){3}))|:))|(([0-9A-Fa-f]{1,4}:){2}(((:[0-9A-Fa-f]{1,4}){1,5})|((:[0-9A-Fa-f]{1,4}){0,3}:((25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)(\.(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)){3}))|:))|(([0-9A-Fa-f]{1,4}:){1}(((:[0-9A-Fa-f]{1,4}){1,6})|((:[0-9A-Fa-f]{1,4}){0,4}:((25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)(\.(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)){3}))|:))|(:(((:[0-9A-Fa-f]{1,4}){1,7})|((:[0-9A-Fa-f]{1,4}){0,5}:((25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)(\.(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)){3}))|:)))(%.+)?/;

    # Define stub methods that will be overridden by mock
    sub loadconfig    { }
    sub get_config    { }
    sub config        { }
    sub resetconfig   { }
    sub ipv4reg       { return $ipv4reg; }
    sub ipv6reg       { return $ipv6reg; }
    sub configsetting { }

    package MockConfig;
}

# Storage for mock configuration
our %config;
our $_mock;

sub set_config {
    my %new_config = @_;
    %config = %new_config;
    return;
}

sub clear_config {
    %config = ();
    return;
}

sub get_mock_config {
    return %config;
}

# Automatically set up mocking when module is loaded
sub import {
    my $class = shift;

    # Get the caller's package
    my $caller = caller;

    # Export our functions to the caller
    no strict 'refs';
    *{"${caller}::set_config"}      = \&set_config;
    *{"${caller}::clear_config"}    = \&clear_config;
    *{"${caller}::get_mock_config"} = \&get_mock_config;

    # Set up the mock for ConfigServer::Config
    $_mock = mock 'ConfigServer::Config' => (
        override => [
            loadconfig => sub {
                my $class = shift;
                my $self  = {};
                bless $self, $class;
                $self->{warning} = '';
                return $self;
            },
            get_config => sub {
                my ( $class, $key ) = @_;

                # If no key provided, return entire hash
                return %config unless defined $key;
                return $config{$key};
            },
            config => sub {
                return %config;
            },
            resetconfig => sub {
                %config = ();
                return;
            },
        ],
    );
}

1;

__END__

=head1 NAME

MockConfig - Test mock for ConfigServer::Config

=head1 SYNOPSIS

    use Test2::V0;
    use MockConfig;

    # Set mock configuration values
    set_config(
        IPTABLES   => '/sbin/iptables',
        IPV6       => 1,
        LF_LOOKUPS => 1,
    );

    # Now calls to ConfigServer::Config will use mock data
    my $config = ConfigServer::Config->loadconfig();
    is( $config->{warning}, '', 'no warnings in mock' );

    my $ipv6 = ConfigServer::Config->get_config('IPV6');
    is( $ipv6, 1, 'mock config returns set value' );

    # Clear mock configuration
    clear_config();

=head1 DESCRIPTION

This module provides a test mock for L<ConfigServer::Config> that allows
tests to set configuration values without requiring actual config files
or system access.

When imported, this module automatically mocks the ConfigServer::Config
package to intercept C<loadconfig()>, C<get_config()>, and C<config()>
calls, returning test data instead of loading from C</etc/csf/csf.conf>.

=head1 FUNCTIONS

=head2 set_config

    set_config(
        IPTABLES => '/sbin/iptables',
        IPV6     => 1,
    );

Sets the mock configuration values that will be returned by
C<ConfigServer::Config->get_config()> and C<config()>.

Takes a hash of configuration key-value pairs.

=head2 clear_config

    clear_config();

Clears all mock configuration values, resetting the mock config hash
to empty.

=head2 get_mock_config

    my %config = get_mock_config();

Returns the current mock configuration hash. Useful for debugging tests.

=head1 MOCKED METHODS

When MockConfig is loaded, the following ConfigServer::Config methods
are mocked:

=over 4

=item * C<loadconfig()> - Returns blessed hash with empty warning

=item * C<get_config($key)> - Returns value from mock config hash

=item * C<config()> - Returns entire mock config hash

=item * C<resetconfig()> - Clears mock config (same as clear_config)

=back

=head1 EXAMPLE

    use Test2::V0;
    use MockConfig;
    use ConfigServer::LookUpIP qw(iplookup);

    subtest 'test with LF_LOOKUPS disabled' => sub {
        set_config(
            LF_LOOKUPS  => 0,
            CC_LOOKUPS  => 0,
            CC6_LOOKUPS => 0,
        );

        my $result = iplookup('8.8.8.8');
        is( $result, '8.8.8.8', 'returns bare IP' );

        clear_config();
    };

=head1 SEE ALSO

L<ConfigServer::Config>, L<Test2::Tools::Mock>

=cut
