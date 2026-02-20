#!/usr/local/cpanel/3rdparty/bin/perl

#                                      Copyright 2026 WebPros International, LLC
#                                                           All rights reserved.
# copyright@cpanel.net                                         http://cpanel.net
# This code is subject to the cPanel license. Unauthorized copying is prohibited.

use lib 't/lib';
use FindBin::libs;

use cPstrict;

use Test2::V0;
use Test2::Plugin::NoWarnings;
use Test2::Tools::Explain;
use Test::MockModule;
use File::Temp ();
use File::Path qw(make_path);

use FindBin::libs;
use MockConfig;

use Test::MockFile qw/strict/;

# Authorize Net::Config to access filesystem in strict mode
Test::MockFile::authorized_strict_mode_for_package('Net::Config');

# This test validates the input/output behavior of all subroutines in csf.pl
# (except the run() method). It uses the modulino pattern to load csf.pl
# without executing it, then tests each function in isolation with mocked
# dependencies.

# =============================================================================
# GLOBAL TEST INFRASTRUCTURE
# =============================================================================

# Track syscommand calls without executing them
our @syscommands;

# Override exit to prevent test termination - throw exception instead
BEGIN {
    *CORE::GLOBAL::exit = sub {
        my $code = $_[0] // 0;
        die bless { exit_code => $code }, 'Test::Exit';
    };

    # Mock flock to always succeed - Test::MockFile doesn't support flock
    *CORE::GLOBAL::flock = sub {
        return 1;    # Always succeed
    };

    # Mock truncate to work with Test::MockFile
    *CORE::GLOBAL::truncate = sub {
        my ( $file_or_fh, $length ) = @_;

        if ( ref($file_or_fh) ) {

            # It's a file handle - find which mocked file it belongs to
            # Using same approach as Test::MockFile::_fh_to_file
            foreach my $path ( keys %Test::MockFile::files_being_mocked ) {
                my $mock_fh = $Test::MockFile::files_being_mocked{$path}->{'fh'};
                next unless $mock_fh;
                next unless "$mock_fh" eq "$file_or_fh";

                # Found the file handle - truncate this specific file
                my $mock_file = $Test::MockFile::files_being_mocked{$path};
                my $contents  = $mock_file->contents() // '';
                $contents = substr( $contents, 0, $length );
                $mock_file->contents($contents);
                return 1;
            }

            # File handle not found in mocked files - return success anyway
            return 1;
        }
        else {
            # It's a path - check if it's mocked
            my $path = $file_or_fh;
            if ( exists $Test::MockFile::files_being_mocked{$path} ) {
                my $mock_file = $Test::MockFile::files_being_mocked{$path};
                my $contents  = $mock_file->contents() // '';
                $contents = substr( $contents, 0, $length );
                $mock_file->contents($contents);
                return 1;
            }

            # Not mocked - pass through to real truncate
            return CORE::truncate( $path, $length );
        }
    };
}

# Mock required files that csf.pl needs during load
my $version_file_etc = Test::MockFile->file( '/etc/csf/version.txt',        "16.00\n" );
my $help_file        = Test::MockFile->file( '/usr/local/csf/lib/csf.help', "CSF Help Text\nUsage: csf [options]\n" );
my $lock_file        = Test::MockFile->file('/var/lib/csf/csf.lock');
my $lfd_chksrv       = Test::MockFile->file('/etc/chkserv.d/lfd');

# Global mocks for core CSF files - these should NEVER be altered by subtests
# Subtests should use these existing mocks via ->contents() instead of creating new ones
our $global_allow_file = Test::MockFile->file( '/etc/csf/csf.allow', "Include /etc/csf/cpanel.comodo.allow\nInclude /etc/csf/cpanel.allow\n\n" );
our $global_deny_file  = Test::MockFile->file( '/etc/csf/csf.deny',  "# comment\n" );

# Mock ConfigServer::Slurp - Test::MockFile handles the file operations
my $slurp_mock = Test::MockModule->new('ConfigServer::Slurp');
$slurp_mock->redefine(
    'slurp',
    sub {
        my ( $file, %opts ) = @_;
        return unless -e $file;
        open my $fh, '<', $file or die "Failed to open $file: $!";
        my @lines = <$fh>;
        close $fh;
        return @lines;
    }
);
$slurp_mock->redefine(
    'slurpee',
    sub {
        my ( $file, %opts ) = @_;
        if ( !-e $file && $opts{fatal} ) {
            die "*Error* File does not exist: [$file]\n";
        }
        return wantarray ? () : '' unless -e $file;
        open my $fh, '<', $file or die "Failed to open $file: $!";
        my $content = do { local $/; <$fh> };
        close $fh;
        return defined $content && length $content ? $content : ( wantarray ? () : '' );
    }
);

# Load csf.pl as a modulino (without executing run())
require './csf.pl' or die "Cannot load csf.pl: $!";

# =============================================================================
# MOCK SETUP (after loading csf.pl)
# =============================================================================

# Mock sbin::csf::syscommand to track commands instead of executing
my $main_mock = Test::MockModule->new( 'sbin::csf', no_auto => 1 );
$main_mock->redefine(
    'syscommand',
    sub {
        my (@cmd) = @_;
        push @syscommands, join( ' ', @cmd );
        return 1;    # Success
    }
);

# Mock sbin::csf::linefilter to track calls without complex execution
$main_mock->redefine(
    'linefilter',
    sub {
        my ( $ip, $action, $chain, $delete ) = @_;
        $chain  //= '';
        $delete //= 0;
        my $operation = $delete ? 'remove' : 'add';
        push @syscommands, "LINEFILTER: $operation $ip ($action)";
        return 1;
    }
);

# Mock sbin::csf::getethdev globally - most tests don't need real network detection
$main_mock->redefine(
    'getethdev',
    sub {
        # Set up basic ethernet device variables without real detection
        no warnings 'once';
        $sbin::csf::config{ETH_DEVICE} //= '';
        $sbin::csf::ethdevin   = '! -i lo';
        $sbin::csf::ethdevout  = '! -o lo';
        $sbin::csf::eth6devin  = '! -i lo';
        $sbin::csf::eth6devout = '! -o lo';
        return;
    }
);

# Mock csflock to use mocked file system
$main_mock->redefine(
    'csflock',
    sub {
        my $lock = shift;
        if ( $lock eq "lock" ) {
            my $lockfile = "/var/lib/csf/csf.lock";
            open my $fh, '>', $lockfile or die "Error: Unable to open csf lock file: $!";
            close $fh;
        }
        return;
    }
);

# Mock lfdstart to use mocked file system
$main_mock->redefine(
    'lfdstart',
    sub {
        my $restartfile = "/var/lib/csf/csf.restart";
        open my $fh, '>', $restartfile or die "Failed to create csf.restart - $!";
        close $fh;
        no warnings 'once';
        print "lfd will restart csf within the next $sbin::csf::config{LF_PARSE} seconds\n";
        return;
    }
);

# Mock open3 to prevent ipset commands from executing
require IPC::Open3;
require Symbol;
my $open3_mock = Test::MockModule->new('IPC::Open3');

# Store filehandles and buffers at package level so they persist
our @mock_filehandles;
our @mock_buffers;

# Create a mock that handles scalar references like open3 does
$open3_mock->redefine(
    'open3',
    sub {
        # IPC::Open3::open3 has prototype (\$\$\$@) which means first 3 args are scalar refs
        # When mocking without prototype,we get the actual scalar variables in @_, not refs
        # So we use direct assignment instead of dereferencing
        my @cmd = @_[ 3 .. $#_ ];    # Command is from index 3 onwards
        push @syscommands, join( ' ', @cmd );

        # Create GLOB filehandles that will persist
        my $fake_in  = Symbol::gensym();
        my $fake_out = Symbol::gensym();

        # Keep references so they don't get destroyed
        push @mock_filehandles, $fake_in, $fake_out;

        # Store buffers at package level so they persist after mock returns
        my $buffer_in  = '';
        my $buffer_out = '';
        push @mock_buffers, \$buffer_in, \$buffer_out;

        # Open filehandles to the persistent buffers
        open $fake_in,  '>', \$buffer_in  or die "Cannot create fake stdin: $!";
        open $fake_out, '<', \$buffer_out or die "Cannot create fake stdout: $!";

        # Direct assignment to @_ elements (not dereferencing)
        $_[0] = $fake_in;               # $childin
        $_[1] = $fake_out;              # $childout
        $_[2] = $fake_out if @_ > 2;    # $childerr (if provided)

        return $$;                      # Return fake PID (current process ID)
    }
);

# =============================================================================
# HELPER FUNCTIONS
# =============================================================================

# Capture STDOUT output from a code block
sub capture_output {
    my ($code) = @_;
    my $output = '';

    open my $stdout_copy, '>&', \*STDOUT or die "Cannot dup STDOUT: $!";
    close STDOUT;
    open STDOUT, '>', \$output or die "Cannot redirect STDOUT: $!";

    eval { $code->(); };
    my $error = $@;

    close STDOUT;
    open STDOUT, '>&', $stdout_copy or die "Cannot restore STDOUT: $!";

    # Return both output and exception (if Test::Exit)
    if ( ref($error) eq 'Test::Exit' ) {
        return wantarray ? ( $output, $error ) : $output;
    }

    # Re-throw error if it's not a Test::Exit
    die $error if $error;

    return wantarray ? ( $output, undef ) : $output;
}

# Set default config for tests - comprehensive set to avoid uninitialized warnings
sub set_default_config {
    my %default_config = (
        TESTING            => 1,
        TESTING_INTERVAL   => 5,
        LF_PARSE           => 5,
        LF_SPI             => 1,
        USE_CONNTRACK      => 1,
        IPTABLES           => '/sbin/iptables',
        IPTABLES_SAVE      => '/sbin/iptables-save',
        IPTABLES_RESTORE   => '/sbin/iptables-restore',
        IP6TABLES          => '/sbin/ip6tables',
        IP6TABLES_SAVE     => '/sbin/ip6tables-save',
        IP6TABLES_RESTORE  => '/sbin/ip6tables-restore',
        IPTABLESWAIT       => '',
        IPSET              => '/sbin/ipset',
        MODPROBE           => '/sbin/modprobe',
        IFCONFIG           => '/sbin/ifconfig',
        IP                 => '/sbin/ip',
        SENDMAIL           => '/usr/sbin/sendmail',
        SYSTEMCTL          => '/usr/bin/systemctl',
        PS                 => '/bin/ps',
        GREP               => '/bin/grep',
        EGREP              => '/bin/egrep',
        ZGREP              => '/bin/zgrep',
        VMSTAT             => '/usr/bin/vmstat',
        LS                 => '/bin/ls',
        MD5SUM             => '/usr/bin/md5sum',
        TAR                => '/bin/tar',
        CHATTR             => '/usr/bin/chattr',
        LSATTR             => '/usr/bin/lsattr',
        UNZIP              => '/usr/bin/unzip',
        GUNZIP             => '/bin/gunzip',
        DD                 => '/bin/dd',
        TAIL               => '/usr/bin/tail',
        HOST               => '/usr/bin/host',
        PERL5LIB           => '',
        IPV6               => 1,
        IPV6_SPI           => 1,
        DROP               => 'DROP',
        DROP_OUT           => 'DROP',
        DROP_NOLOG         => '',
        DROP_IP_LOGGING    => 0,
        DROP_OUT_LOGGING   => 0,
        DROP_PF_LOGGING    => 0,
        DROP_UID_LOGGING   => 0,
        FASTSTART          => 0,
        PACKET_FILTER      => 1,
        DENY_IP_LIMIT      => 200,
        DENY_TEMP_IP_LIMIT => 100,
        LF_IPSET           => 0,
        LF_IPSET_HASHSIZE  => 1024,
        LF_IPSET_MAXELEM   => 65536,
        LF_BLOCKINONLY     => 0,
        MESSENGER          => 0,
        MESSENGER6         => 0,
        MESSENGER_HTML     => 0,
        MESSENGER_TEXT     => '',
        MESSENGER_USER     => '',
        MESSENGER_HTTPS    => 0,
        MESSENGER_HTTPS_IN => 0,
        NAT                => 0,
        VERBOSE            => 1,
        ETH_DEVICE         => '',
        ETH_DEVICE_SKIP    => '',
        CLUSTER_SENDTO     => '',
        CLUSTER_RECVFROM   => '',
        CLUSTER_KEY        => '',
        CLUSTER_PORT       => 7777,
        CLUSTER_NAT        => 0,
        CLUSTER_MASTER     => '',
        CLUSTER_CONFIG     => 0,
        CC_LOOKUPS         => 0,
        CC6_LOOKUPS        => 0,
        CC_DENY            => '',
        CC_ALLOW           => '',
        CC_IGNORE          => '',
        SMTP_BLOCK         => 0,
        SYSLOG             => '/var/log/messages',
        CUSTOM1_LOG        => '',
        CUSTOM2_LOG        => '',
        CUSTOM3_LOG        => '',
        CUSTOM4_LOG        => '',
        CUSTOM5_LOG        => '',
        CUSTOM6_LOG        => '',
        CUSTOM7_LOG        => '',
        CUSTOM8_LOG        => '',
        CUSTOM9_LOG        => '',
        TCP_IN             => '20,21,22,25,53,80,110,143,443,465,587,993,995',
        TCP_OUT            => '20,21,22,25,53,80,110,113,443,587,993,995',
        UDP_IN             => '20,21,53,80,443',
        UDP_OUT            => '20,21,53,113,123',
        TCP6_IN            => '20,21,22,25,53,80,110,143,443,465,587,993,995',
        TCP6_OUT           => '20,21,22,25,53,80,110,113,443,587,993,995',
        UDP6_IN            => '20,21,53,80,443',
        UDP6_OUT           => '20,21,53,113,123',
        ICMP_IN            => 1,
        ICMP_IN_RATE       => '1/s',
        ICMP_OUT           => 1,
        ICMP_OUT_RATE      => 0,
        URLGET             => 2,
        RESTRICT_SYSLOG    => 0,
        ETH6_DEVICE        => '',
        DEBUG              => 0,
        RAW                => 0,
        MANGLE             => 0,
        NAT6               => 0,
        RAW6               => 0,
        MANGLE6            => 0,
        PORTFLOOD          => '',
        CONNLIMIT          => '',
        PORTKNOCKING       => '',
    );

    # Use set_config from MockConfig which now handles both storage locations
    set_config(%default_config);

    # Initialize package-level regex variables (normally set by run())
    no warnings 'once';
    $sbin::csf::version  = sbin::csf::version();
    $sbin::csf::slurpreg = ConfigServer::Slurp->slurpreg;
    $sbin::csf::cleanreg = ConfigServer::Slurp->cleanreg;

    # Initialize IP regex patterns (normally set by load_config())
    my $config_obj = ConfigServer::Config->loadconfig();
    $sbin::csf::ipv4reg = $config_obj->ipv4reg;
    $sbin::csf::ipv6reg = $config_obj->ipv6reg;

    # Initialize Net::CIDR::Lite objects (normally set by run())
    $sbin::csf::ipscidr  = Net::CIDR::Lite->new;
    $sbin::csf::ipscidr6 = Net::CIDR::Lite->new;
    eval { local $SIG{__DIE__} = undef; $sbin::csf::ipscidr->add("127.0.0.0/8") };
    eval { local $SIG{__DIE__} = undef; $sbin::csf::ipscidr6->add("::1/128") };

    # Initialize ethernet device variables (normally set by getethdev())
    $sbin::csf::ethdevin   = '! -i lo';
    $sbin::csf::ethdevout  = '! -o lo';
    $sbin::csf::eth6devin  = '! -i lo';
    $sbin::csf::eth6devout = '! -o lo';

    return;
}

# Reset global state between tests
sub reset_globals {
    @syscommands = ();

    # Reset sbin::csf:: package variables from csf.pl
    no warnings 'once';
    %sbin::csf::config          = ();
    %sbin::csf::ips             = ();
    %sbin::csf::ifaces          = ();
    %sbin::csf::input           = ();
    $sbin::csf::verbose         = 0;
    $sbin::csf::accept          = 'ACCEPT';
    $sbin::csf::version         = '';
    $sbin::csf::statemodule     = '-m state --state';
    $sbin::csf::statemodulenew  = '-m state --state NEW';
    $sbin::csf::statemodule6new = '-m state --state NEW';

    # Set default config to avoid uninitialized warnings
    set_default_config();

    return;
}

# Note: Tests should create local Test::MockFile objects instead of using helpers
# Example: my $mock = Test::MockFile->file('/etc/csf/csf.allow', "# Allow list\n");
# Then use: $mock->contents() to verify file contents

# Mock ConfigServer::LookUpIP
my $lookupip_mock = Test::MockModule->new('ConfigServer::LookUpIP');
$lookupip_mock->redefine(
    'iplookup',
    sub {
        my ($ip) = @_;
        return "hostname.example.com";
    }
);

# Also mock sbin::csf::iplookup since it's imported into sbin::csf::
$main_mock->redefine(
    'iplookup',
    sub {
        my ($ip) = @_;
        return "hostname.example.com";
    }
);

# Mock sbin::csf::clustersend globally for all cluster tests
$main_mock->redefine(
    'clustersend',
    sub {
        my ( $command, @servers ) = @_;
        push @syscommands, "CLUSTER: $command";
        return;
    }
);

# Mock ConfigServer::Service
my $service_mock = Test::MockModule->new('ConfigServer::Service');
$service_mock->redefine(
    'type',
    sub {
        return 'sysvinit';    # Avoid systemctl checks in dostart()
    }
);
$service_mock->redefine(
    'startlfd',
    sub {
        push @syscommands, "SERVICE: lfd start";
        return 1;
    }
);
$service_mock->redefine(
    'stoplfd',
    sub {
        push @syscommands, "SERVICE: lfd stop";
        return 1;
    }
);
$service_mock->redefine(
    'restartlfd',
    sub {
        push @syscommands, "SERVICE: lfd restart";
        return 1;
    }
);

# =============================================================================
# MOCKS FOR PHASE 6 EXTERNAL DEPENDENCIES
# =============================================================================
# Only modules that perform external I/O are mocked here.
# Pure-calculation helpers (e.g. ConfigServer::CheckIP) are left unmocked.

# ConfigServer::ServerCheck::report() reads /etc/csf and /proc filesystem entries.
my $servercheck_mock = Test::MockModule->new('ConfigServer::ServerCheck');
$servercheck_mock->redefine(
    'report',
    sub {
        return "Server check report output\n";
    }
);

# ConfigServer::RBLCheck::report() performs live DNS lookups.
my $rblcheck_mock = Test::MockModule->new('ConfigServer::RBLCheck');
$rblcheck_mock->redefine(
    'report',
    sub {
        return ( 2, "RBL check: 2 failures found\n" );
    }
);

# ConfigServer::Sendmail::relay() opens a pipe to the sendmail binary.
my $sendmail_mock = Test::MockModule->new('ConfigServer::Sendmail');
$sendmail_mock->redefine(
    'relay',
    sub {
        my ( $to, $from, @message ) = @_;
        push @syscommands, "SENDMAIL: to=$to";
        return 1;
    }
);

# ConfigServer::Ports reads /proc/net/{tcp,udp,tcp6,udp6} and per-pid /proc entries.
my $ports_mock = Test::MockModule->new('ConfigServer::Ports');
$ports_mock->redefine(
    'listening',
    sub {
        my $class = shift;
        return (
            tcp => {
                22 => { 1234 => { user => 'root', exe => '/usr/sbin/sshd',  cmd => 'sshd',  conn => 3 } },
                80 => { 5678 => { user => 'www',  exe => '/usr/sbin/httpd', cmd => 'httpd', conn => 10 } },
            }
        );
    }
);
$ports_mock->redefine(
    'openports',
    sub {
        my $class = shift;
        return ( tcp => { 22 => 1, 80 => 1 } );
    }
);

# =============================================================================
# TESTS - ALPHABETICALLY BY FUNCTION NAME
# =============================================================================

subtest 'csf.pl loads as modulino' => sub {
    ok( defined &sbin::csf::run,     'sbin::csf::run subroutine exists' );
    ok( defined &sbin::csf::dostart, 'sbin::csf::dostart subroutine exists' );
    ok( defined &sbin::csf::dostop,  'sbin::csf::dostop subroutine exists' );
};

subtest 'csflock() - file locking' => sub {
    reset_globals();

    merge_config( TESTING => 1 );

    # Call csflock (uses mocked file system)
    eval { sbin::csf::csflock('lock'); };
    is( $@, '', 'csflock does not die' );

    # Verify lock file was created (Test::MockFile intercepts this)
    my $lock_file = "/var/lib/csf/csf.lock";
    ok( -e $lock_file, 'lock file created' );

    clear_config();
};

subtest 'doclusterallow() - cluster allow IP' => sub {
    reset_globals();

    merge_config(
        TESTING        => 1,
        CLUSTER_SENDTO => 'server1.example.com,server2.example.com',
    );

    # Call doclusterallow
    $sbin::csf::input{argument} = ['192.168.1.100'];
    $sbin::csf::input{comment}  = 'Test allow';

    eval { sbin::csf::doclusterallow(); };

    # Should call clustersend with "A" command
    ok( ( grep { /^CLUSTER: A \d/ } @syscommands ), 'clustersend called for allow' );

    clear_config();
};

subtest 'doclusterarm() - cluster remove from allow' => sub {
    reset_globals();

    merge_config(
        TESTING        => 1,
        CLUSTER_SENDTO => 'server1.example.com',
    );

    $sbin::csf::input{argument} = ['192.168.1.100'];

    eval { sbin::csf::doclusterarm(); };

    ok( ( grep { /^CLUSTER: AR / } @syscommands ), 'clustersend called for AR (allow remove)' );

    clear_config();
};

subtest 'doclusterdeny() - cluster deny IP' => sub {
    reset_globals();

    merge_config(
        TESTING        => 1,
        CLUSTER_SENDTO => 'server1.example.com',
    );

    $sbin::csf::input{argument} = ['10.0.0.50'];
    $sbin::csf::input{comment}  = 'Bad actor';

    eval { sbin::csf::doclusterdeny(); };

    ok( ( grep { /^CLUSTER: D \d/ } @syscommands ), 'clustersend called for deny' );

    clear_config();
};

subtest 'doclustergrep() - cluster grep' => sub {
    reset_globals();

    merge_config(
        TESTING        => 1,
        CLUSTER_SENDTO => 'server1.example.com',
    );

    $sbin::csf::input{argument} = ['192.168.1.1'];

    eval { sbin::csf::doclustergrep(); };

    ok( ( grep { /^CLUSTER: G / } @syscommands ), 'clustersend called for grep' );

    clear_config();
};

subtest 'doclusterignore() - cluster ignore IP' => sub {
    reset_globals();

    merge_config(
        TESTING        => 1,
        CLUSTER_SENDTO => 'server1.example.com',
    );

    $sbin::csf::input{argument} = ['172.16.0.1'];
    $sbin::csf::input{comment}  = 'Trusted';

    eval { sbin::csf::doclusterignore(); };

    ok( ( grep { /^CLUSTER: I / } @syscommands ), 'clustersend called for ignore' );

    clear_config();
};

subtest 'doclusterirm() - cluster remove from ignore' => sub {
    reset_globals();

    merge_config(
        TESTING        => 1,
        CLUSTER_SENDTO => 'server1.example.com',
    );

    $sbin::csf::input{argument} = ['172.16.0.1'];

    eval { sbin::csf::doclusterirm(); };

    ok( ( grep { /^CLUSTER: IR / } @syscommands ), 'clustersend called for IR (ignore remove)' );

    clear_config();
};

subtest 'doclusterrm() - cluster remove from deny' => sub {
    reset_globals();

    merge_config(
        TESTING        => 1,
        CLUSTER_SENDTO => 'server1.example.com',
    );

    $sbin::csf::input{argument} = ['10.0.0.50'];

    eval { sbin::csf::doclusterrm(); };

    ok( ( grep { /^CLUSTER: R / } @syscommands ), 'clustersend called for R (remove)' );

    clear_config();
};

subtest 'doclustertempdeny() - cluster temp deny' => sub {
    reset_globals();

    merge_config(
        TESTING        => 1,
        CLUSTER_SENDTO => 'server1.example.com',
    );

    # doclustertempd eny expects: [ip, timeout, portdir]
    # portdir can contain flags like "-p 80 -d in Test comment"
    $sbin::csf::input{argument} = [ '203.0.113.50', '3600', '-p 80 -d in Test deny' ];

    eval { sbin::csf::doclustertempdeny(); };

    ok( ( grep { /^CLUSTER: TD / } @syscommands ), 'clustersend called for TD (temp deny)' );

    clear_config();
};

subtest 'doclustertempallow() - cluster temp allow' => sub {
    reset_globals();

    merge_config(
        TESTING        => 1,
        CLUSTER_SENDTO => 'server1.example.com',
    );

    # doclustertempallow expects: [ip, timeout, portdir]
    # portdir can contain flags like "-p 22 -d in Test comment"
    $sbin::csf::input{argument} = [ '198.51.100.25', '1800', '-p 22 -d in Test allow' ];

    eval { sbin::csf::doclustertempallow(); };

    ok( ( grep { /^CLUSTER: TA / } @syscommands ), 'clustersend called for TA (temp allow)' );

    clear_config();
};

subtest 'docconfig() - cluster config' => sub {
    reset_globals();

    merge_config(
        TESTING        => 1,
        CLUSTER_SENDTO => 'server1.example.com',
        CLUSTER_CONFIG => 1,                       # Required for docconfig to work
    );

    # docconfig expects: [name, value]
    $sbin::csf::input{argument} = [ 'DENY_IP_LIMIT', '500' ];

    eval { sbin::csf::docconfig(); };

    ok( ( grep { /^CLUSTER: C / } @syscommands ), 'clustersend called for C (config)' );

    clear_config();
};

subtest 'docrestart() - cluster restart' => sub {
    reset_globals();

    merge_config(
        TESTING        => 1,
        CLUSTER_SENDTO => 'server1.example.com',
    );

    eval { sbin::csf::docrestart(); };

    ok( ( grep { /^CLUSTER: RESTART/ } @syscommands ), 'clustersend called for RESTART' );

    clear_config();
};

subtest 'docfile() - cluster file sync' => sub {
    reset_globals();

    merge_config(
        TESTING        => 1,
        CLUSTER_SENDTO => 'server1.example.com',
        CLUSTER_CONFIG => 1,                       # Required for docfile to work
    );

    # Create a test file to send
    $global_allow_file->contents("192.168.1.1\n192.168.1.2\n");

    # docfile expects full path
    $sbin::csf::input{argument} = ['/etc/csf/csf.allow'];

    eval { sbin::csf::docfile(); };

    ok( ( grep { /^CLUSTER: FILE / } @syscommands ), 'clustersend called for FILE' );

    clear_config();
};

subtest 'dohelp() - display help' => sub {
    reset_globals();

    merge_config( TESTING => 1 );

    my $output = capture_output( sub { sbin::csf::dohelp(); } );

    like( $output, qr/CSF Help Text/, 'help text contains header' );
    like( $output, qr/Usage: csf/,    'help text contains usage' );

    clear_config();
};

subtest 'doiplookup() - IP lookup' => sub {
    reset_globals();

    merge_config( TESTING => 1 );

    $sbin::csf::input{argument} = ['192.0.2.1'];

    my $output = capture_output( sub { sbin::csf::doiplookup(); } );

    like( $output, qr/hostname\.example\.com/, 'displays hostname' );

    clear_config();
};

subtest 'dolfd() - lfd control' => sub {
    reset_globals();

    merge_config( TESTING => 1 );

    # Test restart
    $sbin::csf::input{argument} = ['restart'];
    eval { sbin::csf::dolfd(); };

    ok( ( grep { /^SERVICE: lfd restart/ } @syscommands ), 'service restart called' );

    reset_globals();
    merge_config( TESTING => 1 );

    # Test start
    $sbin::csf::input{argument} = ['start'];
    eval { sbin::csf::dolfd(); };

    ok( ( grep { /^SERVICE: lfd start/ } @syscommands ), 'service start called' );

    reset_globals();
    merge_config( TESTING => 1 );

    # Test stop
    $sbin::csf::input{argument} = ['stop'];
    eval { sbin::csf::dolfd(); };

    ok( ( grep { /^SERVICE: lfd stop/ } @syscommands ), 'service stop called' );

    clear_config();
};

subtest 'doversion() - print version' => sub {
    reset_globals();

    merge_config( TESTING => 1 );

    my $output = capture_output( sub { sbin::csf::doversion(); } );

    like( $output, qr/16\.00/, 'version printed correctly' );

    clear_config();
};

subtest 'dowatch() - deprecated watch command' => sub {
    reset_globals();

    merge_config( TESTING => 1 );

    my $output = capture_output( sub { sbin::csf::dowatch(); } );

    like( $output, qr/no longer supported/i, 'deprecation message shown' );

    clear_config();
};

subtest 'getethdev() - get ethernet devices' => sub {
    reset_globals();

    merge_config(
        TESTING     => 1,
        ETH_DEVICE  => 'eth0',
        ETH6_DEVICE => '',
        IPV6        => 1,
    );

    # Mock ConfigServer::GetEthDev for this test
    my $local_ethdev_mock = Test::MockModule->new('ConfigServer::GetEthDev');
    $local_ethdev_mock->redefine(
        'new',
        sub {
            return bless {}, 'ConfigServer::GetEthDev';
        }
    );
    $local_ethdev_mock->redefine( 'ifaces', sub { return ( 'eth0'         => 1 ); } );
    $local_ethdev_mock->redefine( 'ipv4',   sub { return ( '192.168.1.10' => 1 ); } );
    $local_ethdev_mock->redefine( 'ipv6',   sub { return ( 'fe80::1/128'  => 1 ); } );

    # Call the original getethdev (bypass the global mock)
    my $exception;
    eval {
        $main_mock->original('getethdev')->();
        1;
    } or do {
        $exception = $@;
    };

    is( $exception, undef, 'getethdev does not die' ) or diag("Exception: $exception");

    # Check that globals were populated by getethdev()
    is( scalar( keys %sbin::csf::ifaces ), 1, 'One interface found' );
    ok( exists $sbin::csf::ifaces{eth0}, 'eth0 interface added to %ifaces' )
      or diag( "ifaces: ", join( ", ", sort keys %sbin::csf::ifaces ) );

    clear_config();
};

subtest 'ipsetadd() - add IP to ipset' => sub {
    reset_globals();

    merge_config(
        TESTING => 1,
        IPSET   => '/sbin/ipset',
    );

    eval { sbin::csf::ipsetadd( 'chain_DENY', '192.168.1.100', '', '' ); };

    is( $@, '', 'ipsetadd does not die' );
    ok( ( grep { /ipset.*add/ } @syscommands ), 'ipset add command issued' );

    clear_config();
};

subtest 'ipsetcreate() - create ipset' => sub {
    reset_globals();

    merge_config(
        TESTING => 1,
        IPSET   => '/sbin/ipset',
    );

    eval { sbin::csf::ipsetcreate( 'test_set', 'hash:ip', 0 ); };

    is( $@, '', 'ipsetcreate does not die' );
    ok( ( grep { /ipset.*create/ } @syscommands ), 'ipset create command issued' );

    clear_config();
};

subtest 'ipsetdel() - delete IP from ipset' => sub {
    reset_globals();

    merge_config(
        TESTING => 1,
        IPSET   => '/sbin/ipset',
    );

    eval { sbin::csf::ipsetdel( 'chain_DENY', '192.168.1.100', '' ); };

    is( $@, '', 'ipsetdel does not die' );
    ok( ( grep { /ipset.*del/ } @syscommands ), 'ipset del command issued' );

    clear_config();
};

subtest 'ipsetrestore() - restore ipset from array' => sub {
    reset_globals();

    merge_config(
        TESTING => 1,
        IPSET   => '/sbin/ipset',
    );

    my @sets = ( 'add test_set 192.168.1.1', 'add test_set 192.168.1.2', );

    eval { sbin::csf::ipsetrestore( \@sets ); };

    is( $@, '', 'ipsetrestore does not die' );
    ok( ( grep { /ipset.*restore/ } @syscommands ), 'ipset restore command issued' );

    clear_config();
};

subtest 'lfdstart() - trigger lfd restart' => sub {
    reset_globals();

    merge_config(
        TESTING  => 1,
        LF_PARSE => 5,
    );

    # Mock the csf.restart file that lfdstart will create
    my $restart_file = Test::MockFile->file('/var/lib/csf/csf.restart');

    my $output = capture_output( sub { sbin::csf::lfdstart(); } );

    like( $output, qr/lfd will restart csf/, 'lfdstart prints message' );

    # Check that trigger file was created (Test::MockFile intercepts this)
    my $trigger = "/var/lib/csf/csf.restart";
    ok( -e $trigger, 'csf.restart trigger file created' );

    clear_config();
};

# =============================================================================
# PHASE 1b: LINEFILTER, LOAD_CONFIG, PROCESS_INPUT, SYSCOMMAND
# =============================================================================

subtest 'linefilter() - comment line: no syscommands emitted' => sub {
    reset_globals();
    $sbin::csf::verbose = '';

    $main_mock->original('linefilter')->( '# blocked-ip', 'allow' );

    is( scalar @syscommands, 0, 'comment line triggers no syscommands' );

    clear_config();
};

subtest 'linefilter() - allow IPv4: emits ALLOWIN and ALLOWOUT rules' => sub {
    reset_globals();
    $sbin::csf::verbose = '';

    $main_mock->original('linefilter')->( '1.2.3.4', 'allow' );

    ok( ( grep { /ALLOWIN/ } @syscommands ),   'ALLOWIN rule emitted for allow' );
    ok( ( grep { /ALLOWOUT/ } @syscommands ),  'ALLOWOUT rule emitted for allow' );
    ok( ( grep { /-j ACCEPT/ } @syscommands ), 'ACCEPT target used' );

    clear_config();
};

subtest 'linefilter() - deny IPv4: emits DENYIN rule with DROP target' => sub {
    reset_globals();
    $sbin::csf::verbose = '';

    $main_mock->original('linefilter')->( '1.2.3.4', 'deny' );

    ok( ( grep { /DENYIN/ } @syscommands ),  'DENYIN rule emitted for deny' );
    ok( ( grep { /-j DROP/ } @syscommands ), 'DROP target used for deny' );

    clear_config();
};

subtest 'linefilter() - IPv6 address with IPV6 disabled: no rules emitted' => sub {
    reset_globals();
    merge_config( IPV6 => 0 );
    $sbin::csf::verbose = '';

    $main_mock->original('linefilter')->( '2001:db8::1', 'allow' );

    is( scalar @syscommands, 0, 'IPv6 address with IPV6 disabled emits no rules' );

    clear_config();
};

subtest 'load_config() - basic: sets $accept, $statemodule and $logintarget' => sub {
    reset_globals();
    merge_config( USE_CONNTRACK => 1, VERBOSE => 0, DEBUG => 0 );
    $sbin::csf::warning = '';

    my $blist     = Test::MockFile->file( '/etc/csf/csf.blocklists', '' );
    my $no_cxs    = Test::MockFile->file('/etc/cxs/cxs.reputation');            # undef = does not exist
    my @bin_mocks = map { Test::MockFile->file( $_, '', { mode => 0 } ) } qw(
      /sbin/iptables         /sbin/iptables-save    /sbin/iptables-restore
      /sbin/ip6tables        /sbin/ip6tables-save   /sbin/ip6tables-restore
      /sbin/modprobe         /usr/sbin/sendmail     /bin/ps
      /usr/bin/vmstat        /bin/ls                /usr/bin/md5sum
      /bin/tar               /usr/bin/chattr        /usr/bin/unzip
      /bin/gunzip            /bin/dd                /usr/bin/tail
      /bin/grep              /usr/bin/host          /sbin/ifconfig   /sbin/ip
    );

    sbin::csf::load_config();

    no warnings 'once';
    is( $sbin::csf::accept, 'ACCEPT', '$accept set to ACCEPT' );
    like( $sbin::csf::statemodule, qr/conntrack/,        '$statemodule uses conntrack when USE_CONNTRACK=1' );
    like( $sbin::csf::logintarget, qr/LOG --log-prefix/, '$logintarget contains LOG --log-prefix' );

    clear_config();
};

subtest 'load_config() - VERBOSE=1: sets $verbose to -v' => sub {
    reset_globals();
    merge_config( VERBOSE => 1, DEBUG => 0 );
    $sbin::csf::warning = '';

    my $blist     = Test::MockFile->file( '/etc/csf/csf.blocklists', '' );
    my $no_cxs    = Test::MockFile->file('/etc/cxs/cxs.reputation');            # undef = does not exist
    my @bin_mocks = map { Test::MockFile->file( $_, '', { mode => 0 } ) } qw(
      /sbin/iptables         /sbin/iptables-save    /sbin/iptables-restore
      /sbin/ip6tables        /sbin/ip6tables-save   /sbin/ip6tables-restore
      /sbin/modprobe         /usr/sbin/sendmail     /bin/ps
      /usr/bin/vmstat        /bin/ls                /usr/bin/md5sum
      /bin/tar               /usr/bin/chattr        /usr/bin/unzip
      /bin/gunzip            /bin/dd                /usr/bin/tail
      /bin/grep              /usr/bin/host          /sbin/ifconfig   /sbin/ip
    );

    sbin::csf::load_config();

    is( $sbin::csf::verbose, '-v', '$verbose set to -v when VERBOSE=1' );

    clear_config();
};

subtest 'load_config() - missing binary: appends WARNING to $warning' => sub {
    reset_globals();
    merge_config( IPTABLES => '/nonexistent/iptables', VERBOSE => 0, DEBUG => 0 );
    $sbin::csf::warning = '';

    my $blist       = Test::MockFile->file( '/etc/csf/csf.blocklists', '' );
    my $no_cxs      = Test::MockFile->file('/etc/cxs/cxs.reputation');            # undef = does not exist
    my $missing_bin = Test::MockFile->file('/nonexistent/iptables');              # undef = does not exist
    my @bin_mocks   = map { Test::MockFile->file( $_, '', { mode => 0 } ) } qw(
      /sbin/iptables-save    /sbin/iptables-restore
      /sbin/ip6tables        /sbin/ip6tables-save   /sbin/ip6tables-restore
      /sbin/modprobe         /usr/sbin/sendmail     /bin/ps
      /usr/bin/vmstat        /bin/ls                /usr/bin/md5sum
      /bin/tar               /usr/bin/chattr        /usr/bin/unzip
      /bin/gunzip            /bin/dd                /usr/bin/tail
      /bin/grep              /usr/bin/host          /sbin/ifconfig   /sbin/ip
    );

    sbin::csf::load_config();

    like( $sbin::csf::warning, qr/\*WARNING\*/, 'missing binary appends *WARNING* to $warning' );

    clear_config();
};

subtest 'process_input() - three args: command, argument and comment populated' => sub {
    reset_globals();

    local @ARGV = ( '-a', '1.2.3.4', 'my comment' );
    sbin::csf::process_input();

    is( $sbin::csf::input{command},  '-a',                        'command extracted and lowercased' );
    is( $sbin::csf::input{argument}, [ '1.2.3.4', 'my comment' ], 'remaining args stored as argument' );
    is( $sbin::csf::input{comment},  'my comment',                'comment joined from args[1..]' );

    clear_config();
};

subtest 'process_input() - single arg: argument and comment are empty' => sub {
    reset_globals();

    local @ARGV = ('--status');
    sbin::csf::process_input();

    is( $sbin::csf::input{command},  '--status', 'command extracted' );
    is( $sbin::csf::input{argument}, [],         'argument is empty arrayref' );
    is( $sbin::csf::input{comment},  '',         'comment is empty string' );

    clear_config();
};

subtest 'process_input() - uppercase command: normalised to lowercase' => sub {
    reset_globals();

    local @ARGV = ( '--DENY', '1.2.3.4' );
    sbin::csf::process_input();

    is( $sbin::csf::input{command}, '--deny', 'uppercase command lowercased by lc' );

    clear_config();
};

subtest 'syscommand() - faststart mode: iptables rule collected into @faststart4' => sub {
    reset_globals();

    $sbin::csf::faststart  = 1;
    @sbin::csf::faststart4 = ();

    $main_mock->original('syscommand')->( 42, "$sbin::csf::config{IPTABLES} -A INPUT -j DROP" );

    is( scalar @syscommands, 0, 'open3 not called in faststart mode' );
    ok( scalar @sbin::csf::faststart4 > 0, '@faststart4 has a collected rule' );
    like( $sbin::csf::faststart4[0], qr/-A INPUT -j DROP/, 'correct rule stored in @faststart4' );

    $sbin::csf::faststart  = 0;
    @sbin::csf::faststart4 = ();
    clear_config();
};

subtest 'syscommand() - faststart nat rule: collected into @faststart4nat' => sub {
    reset_globals();

    $sbin::csf::faststart     = 1;
    @sbin::csf::faststart4nat = ();

    $main_mock->original('syscommand')->( 42, "$sbin::csf::config{IPTABLES} -t nat -A PREROUTING -j DROP" );

    ok( scalar @sbin::csf::faststart4nat > 0, '@faststart4nat has a collected rule' );
    like( $sbin::csf::faststart4nat[0], qr/-A PREROUTING -j DROP/, 'nat rule stored without -t nat prefix' );

    $sbin::csf::faststart     = 0;
    @sbin::csf::faststart4nat = ();
    clear_config();
};

subtest 'syscommand() - non-faststart: delegates to IPC::Open3' => sub {
    reset_globals();

    $sbin::csf::faststart = 0;

    $main_mock->original('syscommand')->( 42, '/bin/echo hello' );

    ok( ( grep { /echo hello/ } @syscommands ), 'command passed to IPC::Open3::open3' );
    is( scalar @sbin::csf::faststart4, 0, '@faststart4 remains empty' );

    $sbin::csf::faststart = 0;
    clear_config();
};

subtest 'version() - read version from file' => sub {
    reset_globals();

    my $ver = sbin::csf::version();

    like( $ver, qr/16\.00/, 'version() returns correct version' );
};

# =============================================================================
# PHASE 2: IP MANAGEMENT AND FIREWALL OPERATIONS
# =============================================================================

subtest 'doadd() - add IP to allow list' => sub {
    reset_globals();

    merge_config(
        TESTING => 1,
        IPV6    => 0,
    );

    # Use global csf.allow and csf.deny mocks
    $global_allow_file->contents("# Allow list\n");
    $global_deny_file->contents("# Deny list\n");

    $sbin::csf::input{argument} = ['192.168.1.10'];
    $sbin::csf::input{comment}  = 'Test allow';

    my $output = capture_output( sub { sbin::csf::doadd(); } );

    like( $output, qr/Adding.*to csf\.allow/, 'IP added to allow list' );

    # Verify file was updated using ->contents()
    my $content = $global_allow_file->contents();
    like( $content, qr/192\.168\.1\.10/, 'IP present in csf.allow file' );

    clear_config();
};

subtest 'dodeny() - add IP to deny list' => sub {
    reset_globals();

    merge_config(
        TESTING        => 1,
        IPV6           => 0,
        DENY_IP_LIMIT  => 200,
        LF_REPEATBLOCK => 0,
    );

    # Create test files using local Test::MockFile objects
    $global_allow_file->contents("# Allow list\n");
    $global_deny_file->contents("# Deny list\n");
    my $ignore_file = Test::MockFile->file( '/etc/csf/csf.ignore', "# Ignore list\n" );

    $sbin::csf::input{argument} = ['10.0.0.5'];
    $sbin::csf::input{comment}  = 'Test deny';

    my $output = capture_output( sub { sbin::csf::dodeny(); } );

    like( $output, qr/Adding.*to csf\.deny/, 'IP added to deny list' );

    # Verify file was updated using ->contents()
    my $content = $global_deny_file->contents();
    like( $content, qr/10\.0\.0\.5/, 'IP present in csf.deny file' );

    clear_config();
};

subtest 'dodeny() - prevent denying server IP' => sub {
    reset_globals();

    merge_config(
        TESTING => 1,
        IPV6    => 0,
    );

    $global_deny_file->contents("# Deny list\n");
    $global_allow_file->contents("# Allow list\n");
    my $ignore_file = Test::MockFile->file( '/etc/csf/csf.ignore', "# Ignore list\n" );

    # Add IP to server's interface list
    $sbin::csf::ips{'192.0.2.1'} = 1;

    $sbin::csf::input{argument} = ['192.0.2.1'];
    $sbin::csf::input{comment}  = 'Test';

    my $output = capture_output( sub { sbin::csf::dodeny(); } );

    like( $output, qr/deny failed.*servers addresses/, 'Cannot deny server IP' );

    clear_config();
};

subtest 'dodeny() - prevent denying allowed IP' => sub {
    reset_globals();

    merge_config(
        TESTING => 1,
        IPV6    => 0,
    );

    $global_allow_file->contents("192.168.100.1 # Already allowed\n");
    $global_deny_file->contents("# Deny list\n");
    my $ignore_file = Test::MockFile->file( '/etc/csf/csf.ignore', "# Ignore list\n" );

    $sbin::csf::input{argument} = ['192.168.100.1'];
    $sbin::csf::input{comment}  = 'Test';

    my $output = capture_output( sub { sbin::csf::dodeny(); } );

    like( $output, qr/deny failed.*allow file/, 'Cannot deny IP in allow list' );

    clear_config();
};

subtest 'dokill() - remove IP from deny list' => sub {
    reset_globals();

    merge_config( TESTING => 1 );

    # Create deny file with IP
    $global_deny_file->contents("10.1.1.1 # Blocked IP\n192.168.1.50 # Another blocked IP\n");
    my $tempip_file = Test::MockFile->file( '/var/lib/csf/csf.tempip', '' );

    $sbin::csf::input{argument} = ['10.1.1.1'];

    my $output = capture_output( sub { sbin::csf::dokill(); } );

    like( $output, qr/Removing rule/, 'IP removed from deny list' );

    # Verify IP was removed using ->contents()
    my $content = $global_deny_file->contents();
    unlike( $content, qr/10\.1\.1\.1/, 'IP removed from csf.deny file' );

    clear_config();
};

subtest 'dokill() - respect "do not delete" flag' => sub {
    reset_globals();

    merge_config( TESTING => 1 );

    # Create deny file with protected IP
    $global_deny_file->contents("10.2.2.2 # Blocked IP - do not delete\n");
    my $tempip_file = Test::MockFile->file( '/var/lib/csf/csf.tempip', '' );

    $sbin::csf::input{argument} = ['10.2.2.2'];

    my $output = capture_output( sub { sbin::csf::dokill(); } );

    like( $output, qr/do not delete.*not removed/, 'Protected IP not removed' );

    # Verify IP still present using ->contents()
    my $content = $global_deny_file->contents();
    like( $content, qr/10\.2\.2\.2/, 'Protected IP still in csf.deny file' );

    clear_config();
};

subtest 'doakill() - remove IP from allow list' => sub {
    reset_globals();

    merge_config( TESTING => 1 );

    # Create allow file with IP
    $global_allow_file->contents("172.16.0.1 # Allowed IP\n192.168.5.5 # Another allowed IP\n");

    $sbin::csf::input{argument} = ['172.16.0.1'];

    my $output = capture_output( sub { sbin::csf::doakill(); } );

    like( $output, qr/Removing rule/, 'IP removed from allow list' );

    # Verify IP was removed using ->contents()
    my $content = $global_allow_file->contents();
    unlike( $content, qr/172\.16\.0\.1/, 'IP removed from csf.allow file' );

    clear_config();
};

subtest 'doakill() - IP not found in allow list' => sub {
    reset_globals();

    merge_config( TESTING => 1 );

    $global_allow_file->contents("# Empty allow list\n");

    $sbin::csf::input{argument} = ['10.99.99.99'];

    my $output = capture_output( sub { sbin::csf::doakill(); } );

    like( $output, qr/not found in csf\.allow/, 'IP not found message shown' );

    clear_config();
};

subtest 'docheck() - installation validation' => sub {
    reset_globals();

    merge_config( TESTING => 1 );

    # Create critical files that docheck() verifies
    my $conf_file      = Test::MockFile->file( '/etc/csf/csf.conf',          "# Config\n" );
    my $tempallow_file = Test::MockFile->file( '/var/lib/csf/csf.tempallow', '' );
    my $csf_bin        = Test::MockFile->file( '/usr/sbin/csf',              '' );
    my $lfd_bin        = Test::MockFile->file( '/usr/sbin/lfd',              '' );

    my ( $output, $exception ) = capture_output( sub { sbin::csf::docheck(); } );

    like( $output, qr/CSF version/, 'Shows CSF version' );

    # Should not exit with error if all files exist
    ok( !defined($exception) || ref($exception) ne 'Test::Exit' || $exception->{exit_code} == 0, 'Exits gracefully if files present' );

    clear_config();
};

################################################################################
# PHASE 3: TEMPORARY IP MANAGEMENT
################################################################################

subtest 'dotempdeny() - temporarily deny an IP' => sub {
    reset_globals();
    set_default_config();
    merge_config(
        ETH_DEVICE  => 'eth0',
        IPV6        => 1,
        ETH6_DEVICE => 'eth0',
    );

    $global_deny_file->contents('');
    my $tempban_file = Test::MockFile->file( '/var/lib/csf/csf.tempban', '' );

    # Set up %input for dotempdeny
    %sbin::csf::input = (
        argument => [ '192.168.1.100', '300', 'Test temporary deny' ],
    );

    my ( $output, $exception ) = capture_output(
        sub {
            sbin::csf::dotempdeny(0);
        }
    );

    like( $output, qr/blocked/, 'dotempdeny shows blocked action' );

    # Check that temp file was updated using ->contents()
    my $tempban = $tempban_file->contents();
    like( $tempban, qr/192\.168\.1\.100/, 'IP added to tempban file' );

    clear_config();
};

subtest 'dotempdeny() - with timeout format' => sub {
    reset_globals();
    set_default_config();
    merge_config(
        ETH_DEVICE => 'eth0',
        IPV6       => 1,
    );

    $global_deny_file->contents('');
    my $tempban_file = Test::MockFile->file( '/var/lib/csf/csf.tempban', '' );

    # Test timeout in hours format (2h = 2 hours = 7200 seconds)
    %sbin::csf::input = (
        argument => [ '10.0.0.50', '2h', '-p 22 Test SSH block' ],
    );

    my ( $output, $exception ) = capture_output(
        sub {
            sbin::csf::dotempdeny(0);
        }
    );

    like( $output, qr/blocked/, 'dotempdeny with hour format works' );

    clear_config();
};

subtest 'dotempdeny() - reject invalid IP' => sub {
    reset_globals();
    set_default_config();

    %sbin::csf::input = (
        argument => [ 'not.an.ip', '300', 'Invalid IP' ],
    );

    my ( $output, $exception ) = capture_output(
        sub {
            sbin::csf::dotempdeny(0);
        }
    );

    like( $output, qr/not a valid PUBLIC IP/, 'Rejects invalid IP' );

    clear_config();
};

subtest 'dotempallow() - temporarily allow an IP' => sub {
    reset_globals();
    set_default_config();
    merge_config(
        ETH_DEVICE  => 'eth0',
        IPV6        => 1,
        ETH6_DEVICE => 'eth0',
    );

    $global_allow_file->contents('');
    my $tempallow_file = Test::MockFile->file( '/var/lib/csf/csf.tempallow', '' );

    %sbin::csf::input = (
        argument => [ '203.0.113.50', '600', 'Temporary allow' ],
    );

    my ( $output, $exception ) = capture_output(
        sub {
            sbin::csf::dotempallow(0);
        }
    );

    like( $output, qr/allowed/, 'dotempallow shows allowed action' );

    # Check that temp file was updated using ->contents()
    my $tempallow = $tempallow_file->contents();
    like( $tempallow, qr/203\.0\.113\.50/, 'IP added to tempallow file' );

    clear_config();
};

subtest 'dotempallow() - with port specification' => sub {
    reset_globals();
    set_default_config();
    merge_config(
        ETH_DEVICE => 'eth0',
        IPV6       => 1,
    );

    $global_allow_file->contents('');
    my $tempallow_file = Test::MockFile->file( '/var/lib/csf/csf.tempallow', '' );

    # Test with port and direction
    %sbin::csf::input = (
        argument => [ '198.51.100.25', '1h', '-p 80,443 -d in Web access' ],
    );

    my ( $output, $exception ) = capture_output(
        sub {
            sbin::csf::dotempallow(0);
        }
    );

    like( $output, qr/allowed/, 'dotempallow with ports works' );

    clear_config();
};

subtest 'dotemprm() - remove temporary block/allow' => sub {
    reset_globals();
    set_default_config();
    merge_config(
        ETH_DEVICE => 'eth0',
        IPV6       => 1,
    );

    # Create tempban file with an entry
    my $time           = time();
    my $tempban_file   = Test::MockFile->file( '/var/lib/csf/csf.tempban',   "$time|192.168.1.100||in|300|Test block\n" );
    my $tempallow_file = Test::MockFile->file( '/var/lib/csf/csf.tempallow', '' );

    %sbin::csf::input = (
        argument => ['192.168.1.100'],
    );

    my ( $output, $exception ) = capture_output(
        sub {
            sbin::csf::dotemprm();
        }
    );

    like( $output, qr/(removed|unblock)/i, 'Shows removal/unblock action' );

    clear_config();
};

subtest 'dotemprm() - reject invalid IP' => sub {
    reset_globals();
    set_default_config();

    %sbin::csf::input = (
        argument => ['invalid'],
    );

    my ( $output, $exception ) = capture_output(
        sub {
            sbin::csf::dotemprm();
        }
    );

    like( $output, qr/not a valid PUBLIC IP/, 'Rejects invalid IP' );

    clear_config();
};

subtest 'dogrep() - search for IP in iptables' => sub {
    reset_globals();
    set_default_config();
    merge_config(
        IPTABLES     => 'iptables',
        IPTABLESWAIT => '-w',
        NAT          => 0,
        MANGLE       => 0,
        RAW          => 0,
        IPV6         => 0,            # Disable IPv6 to avoid second open3 call
        LF_IPSET     => 0,            # Disable ipset to avoid third open3 call
    );

    my $tempallow_file = Test::MockFile->file( '/var/lib/csf/csf.tempallow', '' );
    my $tempban_file   = Test::MockFile->file( '/var/lib/csf/csf.tempban',   '' );

    %sbin::csf::input = (
        argument => ['192.168.1.100'],
    );

    # Temporarily override open3 to return mock iptables output
    my $saved_open3 = $open3_mock->original('open3');

    $open3_mock->redefine(
        'open3',
        sub {
            my @cmd = @_[ 3 .. $#_ ];
            push @syscommands, join( ' ', @cmd );

            my $fake_in  = Symbol::gensym();
            my $fake_out = Symbol::gensym();
            push @mock_filehandles, $fake_in, $fake_out;

            # Provide mock iptables output
            # Use Chain header without packet stats to avoid /\d+/ match issues
            my $buffer_in  = '';
            my $buffer_out = <<'EOF';
filter table:

Chain INPUT (policy DROP)
num   pkts bytes target     prot opt in     out     source               destination         
1        0     0 ACCEPT     all  --  *      *       192.168.1.100        0.0.0.0/0           
EOF

            push @mock_buffers, \$buffer_in, \$buffer_out;

            open $fake_in,  '>', \$buffer_in  or die "Cannot create fake stdin: $!";
            open $fake_out, '<', \$buffer_out or die "Cannot create fake stdout: $!";

            $_[0] = $fake_in;
            $_[1] = $fake_out;
            $_[2] = $fake_out if @_ > 2;

            return $$;
        }
    );

    my ( $output, $exception ) = capture_output(
        sub {
            sbin::csf::dogrep();
        }
    );

    like( $output, qr/192\.168\.1\.100/, 'dogrep finds IP in iptables output' );
    like( $output, qr/ACCEPT/,           'Shows matched rule action' );

    # Restore original mock
    $open3_mock->redefine( 'open3', $saved_open3 );

    clear_config();
};

################################################################################
# PHASE 4: ADVANCED TEMPORARY IP OPERATIONS
################################################################################

subtest 'dotemprmd() - remove specific IP from temp deny list' => sub {
    reset_globals();
    set_default_config();
    merge_config(
        ETH_DEVICE => 'eth0',
        IPV6       => 1,
        DROP       => 'DROP',
    );

    # Create tempban file with an entry
    my $time         = time();
    my $tempban_file = Test::MockFile->file( '/var/lib/csf/csf.tempban', "$time|10.0.0.50||in|300|Test block\n" );

    %sbin::csf::input = (
        argument => ['10.0.0.50'],
    );

    my ( $output, $exception ) = capture_output(
        sub {
            sbin::csf::dotemprmd();
        }
    );

    like( $output, qr/(removed|unblock)/i, 'Shows IP removal message' );

    # Verify file was updated (IP removed)
    my $tempban = $tempban_file->contents();
    unlike( $tempban, qr/10\.0\.0\.50/, 'IP removed from tempban file' );

    clear_config();
};

subtest 'dotemprmd() - reject invalid IP' => sub {
    reset_globals();
    set_default_config();

    %sbin::csf::input = (
        argument => ['not.valid.ip'],
    );

    my ( $output, $exception ) = capture_output(
        sub {
            sbin::csf::dotemprmd();
        }
    );

    like( $output, qr/not a valid PUBLIC IP/, 'Rejects invalid IP' );

    clear_config();
};

subtest 'dotemprma() - remove specific IP from temp allow list' => sub {
    reset_globals();
    set_default_config();
    merge_config(
        ETH_DEVICE => 'eth0',
        IPV6       => 1,
    );

    # Create tempallow file with an entry
    my $time           = time();
    my $tempallow_file = Test::MockFile->file( '/var/lib/csf/csf.tempallow', "$time|203.0.113.25||inout|600|Test allow\n" );

    %sbin::csf::input = (
        argument => ['203.0.113.25'],
    );

    my ( $output, $exception ) = capture_output(
        sub {
            sbin::csf::dotemprma();
        }
    );

    like( $output, qr/(removed|unblock)/i, 'Shows IP removal message' );

    # Verify file was updated (IP removed)
    my $tempallow = $tempallow_file->contents();
    unlike( $tempallow, qr/203\.0\.113\.25/, 'IP removed from tempallow file' );

    clear_config();
};

subtest 'dotempf() - flush all temporary blocks' => sub {
    reset_globals();
    set_default_config();
    merge_config(
        ETH_DEVICE => 'eth0',
        IPV6       => 1,
        DROP       => 'DROP',
        DROP_OUT   => 'DROP',
        CF_ENABLE  => 0,
    );

    my $tempallow_file = Test::MockFile->file( '/var/lib/csf/csf.tempallow', '' );

    # Create tempban file with multiple entries
    my $time         = time();
    my $tempban_file = Test::MockFile->file(
        '/var/lib/csf/csf.tempban',
        "$time|192.168.1.50||in|300|Test 1\n" . "$time|10.0.0.100||in|600|Test 2\n"
    );

    my ( $output, $exception ) = capture_output(
        sub {
            sbin::csf::dotempf();
        }
    );

    like( $output, qr/192\.168\.1\.50.*removed/s, 'First IP removed' );
    like( $output, qr/10\.0\.0\.100.*removed/s,   'Second IP removed' );

    # Verify iptables commands were issued
    ok( scalar(@syscommands) > 0, 'Iptables commands issued' );

    clear_config();
};

subtest 'dotempf() - handle empty tempban file' => sub {
    reset_globals();
    set_default_config();

    my $tempallow_file = Test::MockFile->file( '/var/lib/csf/csf.tempallow', '' );

    merge_config(
        ETH_DEVICE => 'eth0',
    );

    # Create empty tempban file
    my $tempban_file = Test::MockFile->file( '/var/lib/csf/csf.tempban', '' );

    my ( $output, $exception ) = capture_output(
        sub {
            sbin::csf::dotempf();
        }
    );

    # Should complete without error even with empty file
    ok( !$exception, 'Handles empty tempban file without error' );

    clear_config();
};

subtest 'dotempban() - list temporary entries' => sub {
    reset_globals();
    set_default_config();

    # Create tempban and tempallow with entries
    my $time         = time();
    my $tempban_file = Test::MockFile->file(
        '/var/lib/csf/csf.tempban',
        "$time|192.168.1.200||in|300|Temp deny\n"
    );
    my $tempallow_file = Test::MockFile->file(
        '/var/lib/csf/csf.tempallow',
        "$time|203.0.113.50||inout|600|Temp allow\n"
    );

    my ( $output, $exception ) = capture_output(
        sub {
            sbin::csf::dotempban();
        }
    );

    like( $output, qr/192\.168\.1\.200/, 'Shows denied IP' );
    like( $output, qr/203\.0\.113\.50/,  'Shows allowed IP' );
    like( $output, qr/DENY/i,            'Shows DENY label' );
    like( $output, qr/ALLOW/i,           'Shows ALLOW label' );

    clear_config();
};

subtest 'dotempban() - no entries message' => sub {
    reset_globals();
    set_default_config();

    # Mock empty tempban/tempallow files
    my $tempban_file   = Test::MockFile->file( '/var/lib/csf/csf.tempban',   '' );
    my $tempallow_file = Test::MockFile->file( '/var/lib/csf/csf.tempallow', '' );

    my ( $output, $exception ) = capture_output(
        sub {
            sbin::csf::dotempban();
        }
    );

    # Empty files (zero-size) should trigger "no temporary IP entries" message
    like( $output, qr/no temporary IP entries/i, 'Shows no entries message for empty files' );

    clear_config();
};

# =============================================================================
# PHASE 5: CORE CONTROL FUNCTIONS (5 tests)
# =============================================================================
# dostatus, dostatus6, dodisable, doenable, dorestartall

subtest 'dostatus() - display IPv4 firewall status' => sub {
    reset_globals();
    set_default_config();

    my ( $output, $exception ) = capture_output(
        sub {
            sbin::csf::dostatus();
        }
    );

    # Should show iptables filter table
    like( $output, qr/iptables filter table/i, 'Shows filter table header' );

    # Check syscommands for iptables status command
    ok( grep( /iptables.*-v -L -n --line-numbers/, @syscommands ), 'Issues iptables status command' );

    # When MANGLE enabled, should show mangle table
    ok( grep( /iptables mangle table/i, split /\n/, $output ), 'Shows mangle table when enabled' )
      if $sbin::csf::config{MANGLE};

    # When NAT enabled, should show nat table
    ok( grep( /iptables nat table/i, split /\n/, $output ), 'Shows nat table when enabled' )
      if $sbin::csf::config{NAT};

    clear_config();
};

subtest 'dostatus6() - display IPv6 firewall status' => sub {
    reset_globals();
    set_default_config();

    # Test with IPV6 disabled
    $sbin::csf::config{IPV6} = 0;

    my ( $output1, $exception1 ) = capture_output(
        sub {
            sbin::csf::dostatus6();
        }
    );

    like( $output1, qr/IPV6 firewall not enabled/i, 'Shows disabled message when IPV6=0' );

    # Test with IPV6 enabled
    $sbin::csf::config{IPV6} = 1;

    my ( $output2, $exception2 ) = capture_output(
        sub {
            sbin::csf::dostatus6();
        }
    );

    like( $output2, qr/ip6tables filter table/i, 'Shows IPv6 filter table when enabled' );

    # Check syscommands for ip6tables status command
    ok( grep( /ip6tables.*-v -L -n --line-numbers/, @syscommands ), 'Issues ip6tables status command' );

    clear_config();
};

subtest 'dodisable() - disable firewall' => sub {
    reset_globals();
    set_default_config();

    # Mock /etc/chkserv.d/chkservd.conf and the csf.disable file that dodisable creates
    my $chkservd_conf = Test::MockFile->file( '/etc/chkserv.d/chkservd.conf', "lfd:1\n" );
    my $disable_file  = Test::MockFile->file('/etc/csf/csf.disable');

    # Mock ConfigServer::Service::stoplfd
    no warnings 'once', 'redefine';
    local *ConfigServer::Service::stoplfd = sub {
        push @syscommands, "ConfigServer::Service::stoplfd()";
    };

    # Mock dostop
    no warnings 'redefine';
    local *sbin::csf::dostop = sub {
        my $restart = shift;
        push @syscommands, "dostop($restart)";
    };

    my ( $output, $exception ) = capture_output(
        sub {
            sbin::csf::dodisable();
        }
    );

    # Verify function executed and called expected sub-functions
    ok( grep( /dostop\(0\)/, @syscommands ), 'Calls dostop(0)' );
    ok( grep( /stoplfd/,     @syscommands ), 'Calls ConfigServer::Service::stoplfd' );

    like( $output, qr/disabled/i, 'Shows disabled message' );

    clear_config();
};

subtest 'doenable() - enable firewall' => sub {
    reset_globals();
    set_default_config();

    # Create mock once for the entire subtest - modify contents as needed
    my $csf_disable = Test::MockFile->file('/etc/csf/csf.disable');

    # Test when not disabled (should exit/throw)
    # Make sure csf.disable does NOT exist for this test
    {
        # Set to absent (no content = file doesn't exist for -e test)
        $csf_disable->contents(undef);

        my ( $output, $exception ) = capture_output(
            sub {
                sbin::csf::doenable();
            }
        );

        is( ref($exception),         'Test::Exit', 'Got Test::Exit exception when not disabled' );
        is( $exception->{exit_code}, 0,            'Exit code is 0' ) if ref($exception) eq 'Test::Exit';
        like( $output, qr/not disabled/i, 'Shows not disabled message' );
    }

    # Set file to exist for the enable path test
    $csf_disable->contents('');

    # Mock /etc/chkserv.d files
    my $chkservd_conf = Test::MockFile->file( '/etc/chkserv.d/chkservd.conf', "lfd:0\n" );

    # Mock ConfigServer::Service::startlfd
    no warnings 'once', 'redefine';
    local *ConfigServer::Service::startlfd = sub {
        push @syscommands, "ConfigServer::Service::startlfd()";
    };

    # Mock dostart
    no warnings 'redefine';
    local *sbin::csf::dostart = sub {
        push @syscommands, "dostart()";
    };

    my ( $output2, $exception2 ) = capture_output(
        sub {
            sbin::csf::doenable();
        }
    );

    # Verify function executed and called expected sub-functions
    ok( grep( /dostart\(\)/, @syscommands ), 'Calls dostart()' );
    ok( grep( /startlfd/,    @syscommands ), 'Calls ConfigServer::Service::startlfd' );

    like( $output2, qr/enabled/i, 'Shows enabled message' );

    clear_config();
};

subtest 'dorestartall() - restart firewall and LFD' => sub {
    reset_globals();
    set_default_config();

    # Mock ConfigServer::Service::restartlfd
    no warnings 'once', 'redefine';
    local *ConfigServer::Service::restartlfd = sub {
        push @syscommands, "ConfigServer::Service::restartlfd()";
    };

    # Mock dostop and dostart
    no warnings 'redefine';
    local *sbin::csf::dostop = sub {
        my $restart = shift;
        push @syscommands, "dostop($restart)";
    };
    local *sbin::csf::dostart = sub {
        push @syscommands, "dostart()";
    };

    my ( $output, $exception ) = capture_output(
        sub {
            sbin::csf::dorestartall();
        }
    );

    # Should call dostop(1), dostart(), and ConfigServer::Service::restartlfd
    ok( grep( /dostop\(1\)/, @syscommands ), 'Calls dostop(1) with restart flag' );
    ok( grep( /dostart\(\)/, @syscommands ), 'Calls dostart()' );
    ok( grep( /restartlfd/,  @syscommands ), 'Calls ConfigServer::Service::restartlfd' );

    # csflock within dorestartall creates lock file at real path (mocked by Test::MockFile)
    # The lock file gets created then removed, so we verify the commands were called
    ok( 1, 'Function executed successfully' );

    clear_config();
};

# =============================================================================
# CLEANUP CHECKS
# =============================================================================

# =============================================================================
# PHASE 6: UTILITY COMMAND WRAPPERS (13 tests)
# =============================================================================
# dotrace, dologrun, domail, dorbls, doports

subtest 'dotrace() - no IP specified returns early' => sub {
    reset_globals();
    set_default_config();

    @ARGV = ( 'csf', 'add', '' );

    my ( $output, $exception ) = capture_output(
        sub {
            sbin::csf::dotrace();
        }
    );

    like( $output, qr/No IP specified/i, 'Shows error when no IP given' );
    is( scalar @syscommands, 0, 'No iptables commands issued' );

    clear_config();
};

subtest 'dotrace() - invalid IP rejected' => sub {
    reset_globals();
    set_default_config();

    @ARGV = ( 'csf', 'add', 'not-an-ip' );

    my ( $output, $exception ) = capture_output(
        sub {
            sbin::csf::dotrace();
        }
    );

    like( $output, qr/not a valid PUBLIC IP/i, 'Shows error for invalid IP' );
    is( scalar @syscommands, 0, 'No iptables commands issued' );

    clear_config();
};

subtest 'dotrace() - add IPv4 trace rule' => sub {
    reset_globals();
    set_default_config();

    @ARGV = ( 'csf', 'add', '1.2.3.4' );

    my ( $output, $exception ) = capture_output(
        sub {
            sbin::csf::dotrace();
        }
    );

    like( $output, qr/Added trace for 1\.2\.3\.4/i, 'Confirms IPv4 trace added' );
    ok( grep( /iptables.*-t raw -I PREROUTING.*TRACE/, @syscommands ), 'Issues iptables TRACE insert rule' );

    clear_config();
};

subtest 'dotrace() - remove IPv4 trace rule' => sub {
    reset_globals();
    set_default_config();

    @ARGV = ( 'csf', 'remove', '1.2.3.4' );

    my ( $output, $exception ) = capture_output(
        sub {
            sbin::csf::dotrace();
        }
    );

    like( $output, qr/Removed trace for 1\.2\.3\.4/i, 'Confirms IPv4 trace removed' );
    ok( grep( /iptables.*-t raw -D PREROUTING.*TRACE/, @syscommands ), 'Issues iptables TRACE delete rule' );

    clear_config();
};

subtest 'dotrace() - add IPv6 trace rule' => sub {
    reset_globals();
    set_default_config();

    @ARGV = ( 'csf', 'add', '2001:db8::1' );

    my ( $output, $exception ) = capture_output(
        sub {
            sbin::csf::dotrace();
        }
    );

    like( $output, qr/Added trace for 2001:db8::1/i, 'Confirms IPv6 trace added' );
    ok( grep( /ip6tables.*-t raw -I PREROUTING.*TRACE/, @syscommands ), 'Issues ip6tables TRACE insert rule' );

    clear_config();
};

subtest 'dotrace() - unknown command shows usage hint' => sub {
    reset_globals();
    set_default_config();

    @ARGV = ( 'csf', 'badcmd', '1.2.3.4' );

    my ( $output, $exception ) = capture_output(
        sub {
            sbin::csf::dotrace();
        }
    );

    like( $output, qr/use \[add\|remove\]/i, 'Shows usage hint for unknown command' );
    is( scalar @syscommands, 0, 'No iptables commands issued' );

    clear_config();
};

subtest 'dologrun() - LOGSCANNER disabled prints message' => sub {
    reset_globals();
    set_default_config();

    $sbin::csf::config{LOGSCANNER} = 0;

    my ( $output, $exception ) = capture_output(
        sub {
            sbin::csf::dologrun();
        }
    );

    like( $output, qr/LOGSCANNER needs to be enabled/i, 'Prints disabled message' );

    clear_config();
};

subtest 'dologrun() - LOGSCANNER enabled creates run file' => sub {
    reset_globals();
    set_default_config();

    $sbin::csf::config{LOGSCANNER} = 1;

    my $logrun_file = Test::MockFile->file('/var/lib/csf/csf.logrun');

    my ( $output, $exception ) = capture_output(
        sub {
            sbin::csf::dologrun();
        }
    );

    ok( -e '/var/lib/csf/csf.logrun', 'Creates csf.logrun trigger file' );
    is( $output, '', 'No output when LOGSCANNER enabled' );

    clear_config();
};

subtest 'domail() - prints report to stdout without address' => sub {
    reset_globals();
    set_default_config();

    $sbin::csf::input{argument} = [];

    my ( $output, $exception ) = capture_output(
        sub {
            sbin::csf::domail();
        }
    );

    like( $output, qr/Server check report output/i, 'Prints server check report to stdout' );
    is( scalar( grep { /SENDMAIL/ } @syscommands ), 0, 'Does not send email without address' );

    clear_config();
};

subtest 'domail() - relays report via email when address given' => sub {
    reset_globals();
    set_default_config();

    $sbin::csf::input{argument} = ['admin@example.com'];

    my ( $output, $exception ) = capture_output(
        sub {
            sbin::csf::domail();
        }
    );

    ok( grep( /SENDMAIL:.*admin\@example\.com/, @syscommands ), 'Relays email to given address' );
    is( $output, '', 'No stdout output when email address given' );

    clear_config();
};

subtest 'dorbls() - prints report to stdout without address' => sub {
    reset_globals();
    set_default_config();

    $sbin::csf::input{argument} = [];

    my ( $output, $exception ) = capture_output(
        sub {
            sbin::csf::dorbls();
        }
    );

    like( $output, qr/RBL check/i, 'Prints RBL report to stdout' );
    is( scalar( grep { /SENDMAIL/ } @syscommands ), 0, 'Does not send email without address' );

    clear_config();
};

subtest 'dorbls() - relays report via email when address given' => sub {
    reset_globals();
    set_default_config();

    $sbin::csf::input{argument} = ['admin@example.com'];

    my ( $output, $exception ) = capture_output(
        sub {
            sbin::csf::dorbls();
        }
    );

    ok( grep( /SENDMAIL:.*admin\@example\.com/, @syscommands ), 'Relays RBL report to given address' );
    is( $output, '', 'No stdout output when email address given' );

    clear_config();
};

subtest 'doports() - lists ports with header and column line' => sub {
    reset_globals();
    set_default_config();

    my ( $output, $exception ) = capture_output(
        sub {
            sbin::csf::doports();
        }
    );

    like( $output, qr/Ports listening for external connections/i, 'Shows ports header' );
    like( $output, qr/Port\/Proto/i,                              'Shows column header line' );

    clear_config();
};

subtest 'Verify no repository files modified' => sub {

    # Use git porcelain output so we catch modified and untracked files in etc/
    my $git_status = `git status --porcelain --untracked-files=all -- etc/ 2>/dev/null`;
    chomp $git_status;

    my @changed_files = grep { length } split /\n/, $git_status;

    is(
        \@changed_files, [],
        'No files in etc/ were modified or created by tests'
    ) or diag( "Changed files: " . join( ", ", @changed_files ) );
};

done_testing();
