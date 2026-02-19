#!/usr/local/cpanel/3rdparty/bin/perl
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

use cPstrict;
use IPC::Open3;

umask(0177);

our ( $return, $fatal, $error );

$fatal = 0;
$error = 0;

my @modules = (
    {
        name    => 'ip_tables/iptable_filter',
        command => "/sbin/iptables -I OUTPUT -p tcp --dport 9999 -j ACCEPT",
        fatal   => "Required for csf to function",
    },
    {
        name    => 'ipt_LOG',
        command => "/sbin/iptables -I OUTPUT -p tcp --dport 9999 -j LOG",
        fatal   => "Required for csf to function",
    },
    {
        name    => 'ipt_multiport/xt_multiport',
        command => "/sbin/iptables -I OUTPUT -p tcp -m multiport --dports 9998,9999 -j LOG",
        fatal   => "Required for csf to function",
    },
    {
        name    => 'ipt_REJECT',
        command => "/sbin/iptables -I OUTPUT -p tcp --dport 9999 -j REJECT",
        fatal   => "Required for csf to function",
    },
    {
        name    => 'ipt_state/xt_state',
        command => "/sbin/iptables -I OUTPUT -p tcp --dport 9999 -m state --state NEW -j LOG",
        fatal   => "Required for csf to function",
    },
    {
        name    => 'ipt_limit/xt_limit',
        command => "/sbin/iptables -I OUTPUT -p tcp --dport 9999 -m limit --limit 30/m --limit-burst 5 -j LOG",
        fatal   => "Required for csf to function",
    },
    {
        name    => 'ipt_recent',
        command => "/sbin/iptables -I OUTPUT -p tcp --dport 9999 -m recent --set",
        error   => "Required for PORTFLOOD and PORTKNOCKING features",
    },
    {
        name    => 'xt_connlimit',
        command => "/sbin/iptables -I INPUT -p tcp --dport 9999 -m connlimit --connlimit-above 100 -j REJECT --reject-with tcp-reset",
        error   => "Required for CONNLIMIT feature",
    },
    {
        name    => 'ipt_owner/xt_owner',
        command => "/sbin/iptables -I OUTPUT -p tcp --dport 9999 -m owner --uid-owner 0 -j LOG",
        error   => "Required for SMTP_BLOCK and UID/GID blocking features",
    },
    {
        name    => 'iptable_nat/ipt_REDIRECT',
        command => "/sbin/iptables -t nat -I OUTPUT -p tcp --dport 9999 -j REDIRECT --to-ports 9900",
        error   => "Required for MESSENGER feature",
    },
    {
        name    => 'iptable_nat/ipt_DNAT',
        command => "/sbin/iptables -t nat -I PREROUTING -p tcp --dport 9999 -j DNAT --to-destination 192.168.254.1",
        error   => "Required for csf.redirect feature",
    }
);

foreach my $module (@modules) {
    print "Testing $module->{name}...";
    $return = testiptables( $module->{command} );
    if ( $return && $return ne "" ) {
        if ( $module->{fatal} ) {
            $fatal++;
            print "FAILED [FATAL Error: $return] - $module->{fatal}\n";
        }
        else {
            $error++;
            print "FAILED [Error: $return] - $module->{error}\n";
        }
    }
    else {
        print "OK\n";

        # Cleanup the test rule
        my $cleanup_command = $module->{command};
        $cleanup_command =~ s/-I /-D /;    # Change -I to -D for cleanup
        testiptables($cleanup_command);
    }
}

if    ($fatal) { print "\nRESULT: csf will not function on this server due to FATAL errors from missing modules [$fatal]\n" }
elsif ($error) { print "\nRESULT: csf will function on this server but some features will not work due to some missing iptables modules [$error]\n" }
else           { print "\nRESULT: csf should function on this server\n" }

sub testiptables {
    my $command = shift;
    my ( $childin, $childout );
    my $cmdpid = open3( $childin, $childout, $childout, $command );
    my @ipdata = <$childout>;
    waitpid( $cmdpid, 0 );
    chomp @ipdata;
    return $ipdata[0];
}

sub loadmodule {
    my $module = shift;
    my @output;

    eval {
        local $SIG{__DIE__} = undef;
        local $SIG{'ALRM'}  = sub { die };
        alarm(5);
        my ( $childin, $childout );
        my $pid = open3( $childin, $childout, $childout, "modprobe $module" );
        @output = <$childout>;
        waitpid( $pid, 0 );
        alarm(0);
    };
    alarm(0);

    return @output;
}
