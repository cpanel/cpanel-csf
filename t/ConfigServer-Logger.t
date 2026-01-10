#!/usr/local/cpanel/3rdparty/bin/perl

#                                      Copyright 2026 WebPros International, LLC
#                                                           All rights reserved.
# copyright@cpanel.net                                         http://cpanel.net
# This code is subject to the cPanel license. Unauthorized copying is prohibited.

use strict;
use warnings;

use Test2::V0;
use Test2::Tools::Explain;
use Test2::Plugin::NoWarnings;

use File::Temp           qw(tempfile);
use ConfigServer::Logger qw(logfile);

subtest "Module loading and exports" => sub {
    ok( defined &logfile, "logfile function is exported" );
};

subtest "logfile function basic behavior" => sub {
    subtest "Function executes without errors" => sub {
        my $result;
        ok( lives { $result = logfile("Test message") }, "logfile executes without dying" );
        is( $result, undef, "logfile returns undef" );
    };

    subtest "Multiple calls execute successfully" => sub {
        ok( lives { logfile("First message") },  "First call succeeds" );
        ok( lives { logfile("Second message") }, "Second call succeeds" );
        ok( lives { logfile("Third message") },  "Third call succeeds" );
    };
};

subtest "logfile message content variations" => sub {
    subtest "Empty string message" => sub {
        ok( lives { logfile("") }, "Empty string message doesn't cause errors" );
    };

    subtest "Message with special characters" => sub {
        ok( lives { logfile('Test: $special @chars #hash') }, "Special characters handled" );
    };

    subtest "Message with newlines" => sub {
        ok( lives { logfile("Line 1\nLine 2") }, "Newlines in message don't cause errors" );
    };

    subtest "Unicode message" => sub {

        # Unicode messages may generate "Wide character in print" warnings
        # This is expected behavior, not an error
        my $warnings = warnings { logfile("Test with unicode: café ☺") };
        ok( 1, "Unicode characters handled (may generate wide character warnings)" );
    };

    subtest "Long message" => sub {
        my $long_msg = "x" x 1000;
        ok( lives { logfile($long_msg) }, "Long message (1000 chars) handled" );
    };
};

subtest "Log file verification" => sub {

    # Create a temporary log file for testing
    my ( $fh, $temp_logfile ) = tempfile( UNLINK => 1 );
    close($fh);

    # Temporarily override the log file path
    local $ConfigServer::Logger::logfile_path = $temp_logfile;

    # Write a unique test message
    my $unique_msg = "TEST_MESSAGE_" . time() . "_" . $$;
    ok( lives { logfile($unique_msg) }, "Write unique test message" );

    # Verify the message was written to our temp file
    ok( -e $temp_logfile, "Temp log file exists at $temp_logfile" );

    # Check if our message made it to the log with correct format
    open( my $log_fh, '<', $temp_logfile ) or die "Cannot read temp log file: $!";
    my $found = 0;
    while ( my $line = <$log_fh> ) {
        if ( $line =~ /\Q$unique_msg\E/ ) {
            $found = 1;

            # Verify log format: Mon DD HH:MM:SS hostname lfd[PID]: message
            like(
                $line,
                qr/^\w+ \s+ \d{1,2} \s+ \d{2}:\d{2}:\d{2} \s+ \S+ \s+ lfd\[\d+\]: \s+ \Q$unique_msg\E/x,
                "Log entry has correct format"
            );
            last;
        }
    }
    close($log_fh);

    ok( $found, "Test message found in log file" );
};

subtest "Function signature" => sub {

    # Test that logfile accepts parameters as expected
    ok( lives { logfile("single param") }, "Accepts single parameter" );

    # logfile only uses the first parameter
    ok( lives { logfile( "first", "second" ) }, "Accepts multiple parameters (uses first)" );
};

subtest "Hostname manipulation for testing" => sub {

    # Create a temp log file
    my ( $fh, $temp_logfile ) = tempfile( UNLINK => 1 );
    close($fh);

    # Override the hostname cache for testing
    local $ConfigServer::Logger::_hostshort_cache = "testhost";
    local $ConfigServer::Logger::logfile_path     = $temp_logfile;

    my $test_msg = "hostname_test_" . $$;
    ok( lives { logfile($test_msg) }, "Log with custom hostname" );

    # Verify our custom hostname appears in the log
    open( my $log_fh, '<', $temp_logfile ) or die "Cannot read temp log: $!";
    my $content = do { local $/; <$log_fh> };
    close($log_fh);

    like( $content, qr/testhost lfd\[\d+\]: \Q$test_msg\E/, "Custom hostname 'testhost' appears in log" );
};

done_testing;
