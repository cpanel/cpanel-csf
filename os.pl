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
## no critic (RequireUseWarnings, ProhibitExplicitReturnUndef, ProhibitMixedBooleanOperators, RequireBriefOpen)
use strict;
use lib '/usr/local/csf/lib';
use Fcntl qw(:DEFAULT :flock);

umask(0177);


if (-l "/var/run" and readlink("/var/run") eq "../run" and -d "/run") {
	sysopen (my $LFD, "lfd.service", O_RDWR);
	my @data = <$LFD>;
	seek ($LFD, 0, 0);
	truncate ($LFD, 0);
	foreach my $line (@data) {
		if ($line =~ /^PIDFile=/) {
			print $LFD "PIDFile=/run/lfd.pid\n";
		} else {
			print $LFD $line;
		}
	}
	close ($LFD);
}

my $return = 0;
my @modules = ("Fcntl","File::Find","File::Path","IPC::Open3","Net::SMTP","POSIX","Socket","Math::BigInt");
foreach my $module (@modules) {
#	print STDERR "Checking for $module\n";
	local $SIG{__DIE__} = undef;
	eval ("use $module"); ##no critic
	if ($@) {
		print STDERR "\n".$@;
		$return = 1;
	}
}

if (-e "/usr/sbin/iptables-nft") {
	print STDERR "Configuration modified to use iptables-nft\n";
	system("update-alternatives", "--set", "iptables", "/usr/sbin/iptables-nft");
	if (-e "/usr/sbin/ip6tables-nft") {
		print STDERR "Configuration modified to use ip6tables-nft\n";
		system("update-alternatives", "--set", "ip6tables", "/usr/sbin/ip6tables-nft");
	}
}

if (-e "/etc/redhat-release") {
	print STDERR "Using configuration defaults\n";
}
elsif (-e "/etc/debian_version") {
	die("CSF for cPanel is not yet supported on ubuntu.")
}
else {print STDERR "Using configuration defaults\n"}

print $return;
exit;
