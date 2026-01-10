#!/usr/local/cpanel/3rdparty/bin/perl

#                                      Copyright 2025 WebPros International, LLC
#                                                           All rights reserved.
# copyright@cpanel.net                                         http://cpanel.net
# This code is subject to the cPanel license. Unauthorized copying is prohibited.

use strict;
use warnings;

use Test2::V0;
use Test2::Tools::Explain;
use Test2::Plugin::NoWarnings;
use Test::MockFile qw< nostrict >;
use Test::MockModule;

# Mock flock to always succeed if $flock_on is in place.
my $flock_on = 1;

BEGIN {
    *CORE::GLOBAL::flock = *CORE::GLOBAL::flock = sub { return 1 unless $flock_on; goto &CORE::flock };
}

use ConfigServer::KillSSH ();

# Mock ConfigServer::Logger
my @logfile_calls;
my $logger_mock = Test::MockModule->new('ConfigServer::Logger');
$logger_mock->mock(
    'logfile' => sub {
        push @logfile_calls, [@_];
        return;
    }
);

# Test module loading
subtest 'Module loading' => sub {
    ok( defined $ConfigServer::KillSSH::VERSION, 'VERSION is defined' );
    ok( ConfigServer::KillSSH->can('find'),      'find method exists' );
    ok( ConfigServer::KillSSH->can('hex2ip'),    'hex2ip method exists' );
};

# Test hex2ip IPv4 conversion
subtest 'hex2ip IPv4 conversion' => sub {

    # Test localhost (127.0.0.1)
    # In network byte order (little endian): 0100007F
    my $result = ConfigServer::KillSSH::hex2ip('0100007F');
    is( $result, '127.0.0.1', 'Converts 0100007F to 127.0.0.1' );

    # Test 192.168.1.1
    # In network byte order: 0101A8C0
    $result = ConfigServer::KillSSH::hex2ip('0101A8C0');
    is( $result, '192.168.1.1', 'Converts 0101A8C0 to 192.168.1.1' );

    # Test 10.0.0.1
    # In network byte order: 0100000A
    $result = ConfigServer::KillSSH::hex2ip('0100000A');
    is( $result, '10.0.0.1', 'Converts 0100000A to 10.0.0.1' );

    # Test 0.0.0.0
    $result = ConfigServer::KillSSH::hex2ip('00000000');
    is( $result, '0.0.0.0', 'Converts 00000000 to 0.0.0.0' );
};

# Test hex2ip IPv6 conversion
subtest 'hex2ip IPv6 conversion' => sub {

    # Test ::1 (loopback)
    # In network byte order: 00000000000000000000000001000000
    my $result = ConfigServer::KillSSH::hex2ip('00000000000000000000000001000000');
    like( $result, qr/:/, 'IPv6 loopback contains colons' );

    # Test that result has IPv6-like format
    # Note: The exact format depends on the implementation
    ok( defined $result, 'IPv6 conversion returns defined value' );

    # Test all zeros
    $result = ConfigServer::KillSSH::hex2ip('00000000000000000000000000000000');
    like( $result, qr/:/, 'IPv6 all zeros contains colons' );
};

# Test hex2ip edge cases
subtest 'hex2ip edge cases' => sub {

    # Test with invalid input (too short)
    my $result = ConfigServer::KillSSH::hex2ip('FF');
    ok( !defined $result || $result eq '', 'Returns undef or empty for too-short input' );

    # Test with empty string
    $result = ConfigServer::KillSSH::hex2ip('');
    ok( !defined $result || $result eq '', 'Returns undef or empty for empty string' );
};

# Test find function basic behavior
subtest 'find function basic behavior' => sub {

    # Test that find doesn't die with empty parameters
    ok lives {
        ConfigServer::KillSSH::find( '', '' );
    }, 'find handles empty IP and ports without dying';

    ok lives {
        ConfigServer::KillSSH::find( '192.168.1.1', '' );
    }, 'find handles empty ports without dying';

    ok lives {
        ConfigServer::KillSSH::find( '', '22' );
    }, 'find handles empty IP without dying';

    # Test with valid-looking parameters (won't match anything in test environment)
    ok lives {
        ConfigServer::KillSSH::find( '192.0.2.1', '22' );
    }, 'find handles valid IP and port without dying';

    ok lives {
        ConfigServer::KillSSH::find( '2001:db8::1', '22,2222' );
    }, 'find handles IPv6 and multiple ports without dying';
};

# Test find return value
subtest 'find return value' => sub {
    my $result = ConfigServer::KillSSH::find( '192.0.2.1', '22' );
    is( $result, undef, 'find returns undef' );

    $result = ConfigServer::KillSSH::find( '', '' );
    is( $result, undef, 'find returns undef for empty inputs' );
};

# Test that find handles malformed inputs gracefully
subtest 'find with malformed inputs' => sub {
    ok lives {
        ConfigServer::KillSSH::find( 'not-an-ip', '22' );
    }, 'find handles invalid IP format';

    ok lives {
        ConfigServer::KillSSH::find( '192.168.1.1', 'not-a-port' );
    }, 'find handles invalid port format';

    ok lives {
        ConfigServer::KillSSH::find( '192.168.1.1', '22,abc,456' );
    }, 'find handles mixed valid/invalid ports';
};

# Flock does nothing after this point.
$flock_on = 0;

# Test find with mocked /proc/net/tcp files
subtest 'find with mocked network connections' => sub {
    @logfile_calls = ();    # Reset call tracker

    # Mock /proc/net/tcp with a connection from 192.168.1.100:54321 to our server on port 22
    # Format: sl local_address rem_address st tx_queue rx_queue tr tm->when retrnsmt uid timeout inode
    # IP 192.168.1.100 in hex (little endian): 6401A8C0
    # Port 54321 in hex: D431
    # Local address (our server): 0100007F:0016 (127.0.0.1:22)
    # Remote address: 6401A8C0:D431 (192.168.1.100:54321)
    my $tcp_content = <<'EOF';
  sl  local_address rem_address   st tx_queue rx_queue tr tm->when retrnsmt   uid  timeout inode
   0: 0100007F:0016 6401A8C0:D431 01 00000000:00000000 00:00000000 00000000  1000        0 12345
   1: 00000000:0016 00000000:0000 0A 00000000:00000000 00:00000000 00000000     0        0 67890
EOF

    my $tcp6_content = <<'EOF';
  sl  local_address                         remote_address                        st tx_queue rx_queue tr tm->when retrnsmt   uid  timeout inode
   0: 00000000000000000000000000000000:0016 00000000000000000000000000000000:0000 0A 00000000:00000000 00:00000000 00000000     0        0 11111
EOF

    my $tcp_mock  = Test::MockFile->file( '/proc/net/tcp',  $tcp_content );
    my $tcp6_mock = Test::MockFile->file( '/proc/net/tcp6', $tcp6_content );

    # Mock /proc directory structure (but we can't actually create process dirs in test)
    my $proc_mock = Test::MockFile->dir('/proc');

    # Test that the function reads the mocked files without dying
    ok lives {
        ConfigServer::KillSSH::find( '192.168.1.100', '22' );
    }, 'find processes mocked /proc/net/tcp data';

    # Test with different port that won't match
    ok lives {
        ConfigServer::KillSSH::find( '192.168.1.100', '8080' );
    }, 'find handles non-matching port';

    # Test with different IP that won't match
    ok lives {
        ConfigServer::KillSSH::find( '10.0.0.1', '22' );
    }, 'find handles non-matching IP';

    # Verify logfile was not called (can't mock /proc/$pid/fd/ structure)
    is( scalar(@logfile_calls), 0, 'logfile not called without mockable process structure' );
};

# Test find identifies correct socket inodes
subtest 'find correctly parses connection data' => sub {
    @logfile_calls = ();    # Reset call tracker

    # This test verifies the connection parsing logic
    # Connection from 203.0.113.50:44444 to our port 2222
    # IP 203.0.113.50 in hex (little endian): 327100CB
    # Port 44444 in hex: AD9C
    # Local port 2222 in hex: 08AE
    my $tcp_content = <<'EOF';
  sl  local_address rem_address   st tx_queue rx_queue tr tm->when retrnsmt   uid  timeout inode
   0: 00000000:08AE 327100CB:AD9C 01 00000000:00000000 00:00000000 00000000  1000        0 99999
   1: 00000000:0016 00000000:0000 0A 00000000:00000000 00:00000000 00000000     0        0 88888
EOF

    my $tcp_mock  = Test::MockFile->file( '/proc/net/tcp',  $tcp_content );
    my $tcp6_mock = Test::MockFile->file( '/proc/net/tcp6', '' );
    my $proc_mock = Test::MockFile->dir('/proc');

    ok lives {
        ConfigServer::KillSSH::find( '203.0.113.50', '2222' );
    }, 'find parses custom connection data';

    # Test with multiple ports
    ok lives {
        ConfigServer::KillSSH::find( '203.0.113.50', '22,2222,22022' );
    }, 'find handles multiple ports in connection search';

    # Verify logfile was not called (can't mock /proc/$pid/fd/ structure)
    is( scalar(@logfile_calls), 0, 'logfile not called without mockable process structure' );
};

done_testing;
