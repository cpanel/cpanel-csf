# ConfigServer Security & Firewall (CSF) for cPanel
# RPM spec file

%define release_prefix 1
%define csf_version 16.00

Name:           cpanel-csf
Version:        %{csf_version}
Release:        %{release_prefix}%{?dist}.cpanel
Summary:        ConfigServer Security & Firewall for cPanel
License:        GPLv3+
Group:          System Environment/Daemons
URL:            https://github.com/waytotheweb/scripts
Vendor:         ConfigServer Services
BuildRoot:      %{_tmppath}/%{name}-%{version}-%{release}-root
BuildArch:      noarch

Source0:        cpanel-csf-%{version}.tar.gz
Source1:        pkg.preinst
Source2:        pkg.postinst
Source3:        pkg.prerm
Source4:        pkg.postrm

# Requires from install.sh os.pl checks and runtime dependencies
Requires:       cpanel-perl
Requires:       iptables
Requires:       ipset
Requires(post): systemd
Requires(preun): systemd
Requires(postun): systemd

AutoReqProv: no

%description
ConfigServer Security & Firewall (CSF) is a Stateful Packet Inspection (SPI)
firewall, Login/Intrusion Detection and Security application for Linux servers.
This package is specifically integrated with cPanel & WHM.

CSF includes Login Failure Daemon (lfd) which scans log files for login attempts
against your server that continually fail within a short period of time.

%prep
%setup -q -n cpanel-csf-%{version}

%build
# No build required - all scripts

%install
rm -rf %{buildroot}

# Create directory structure
install -d -m 0700 %{buildroot}/etc/csf
install -d -m 0700 %{buildroot}/var/lib/csf
install -d -m 0700 %{buildroot}/var/lib/csf/backup
install -d -m 0700 %{buildroot}/var/lib/csf/Geo
install -d -m 0700 %{buildroot}/var/lib/csf/stats
install -d -m 0700 %{buildroot}/var/lib/csf/lock
install -d -m 0700 %{buildroot}/var/lib/csf/zone
install -d -m 0755 %{buildroot}/usr/local/csf
install -d -m 0755 %{buildroot}/usr/local/csf/bin
install -d -m 0755 %{buildroot}/usr/local/csf/lib
install -d -m 0755 %{buildroot}/usr/local/csf/tpl
install -d -m 0755 %{buildroot}/usr/local/csf/profiles

# Install main scripts
install -d -m 0755 %{buildroot}/usr/sbin
install -m 0700 csf.pl %{buildroot}/usr/sbin/csf
install -m 0700 lfd.pl %{buildroot}/usr/sbin/lfd

# Install bin files
install -m 0700 bin/csftest.pl %{buildroot}/usr/local/csf/bin/
install -m 0700 bin/pt_deleted_action.pl %{buildroot}/usr/local/csf/bin/
install -m 0700 bin/regex.custom.pm %{buildroot}/usr/local/csf/bin/
install -m 0700 bin/remove_apf_bfd.sh %{buildroot}/usr/local/csf/bin/

# Install library files (recursively)
cp -a lib/* %{buildroot}/usr/local/csf/lib/

# Install template files
cp -a tpl/* %{buildroot}/usr/local/csf/tpl/

# Add the license file
cp LICENSE.txt %{buildroot}/etc/csf/license.txt

# Install config files from etc/ directory (recursively)
cp -a etc/* %{buildroot}/etc/csf/

# Install profile configurations
cp -a profiles/* %{buildroot}/usr/local/csf/profiles/
install -m 0600 etc/csf.conf %{buildroot}/usr/local/csf/profiles/reset_to_defaults.conf

# Install cron jobs
install -d -m 0755 %{buildroot}/etc/cron.d
install -m 0644 csfcron.sh %{buildroot}/etc/cron.d/csf-cron
install -m 0644 lfdcron.sh %{buildroot}/etc/cron.d/lfd-cron

# Install systemd service files
install -d -m 0755 %{buildroot}/usr/lib/systemd/system
install -m 0644 csf.service %{buildroot}/usr/lib/systemd/system/
install -m 0644 lfd.service %{buildroot}/usr/lib/systemd/system/

# Install logrotate config
install -d -m 0755 %{buildroot}/etc/logrotate.d
install -m 0644 lfd.logrotate %{buildroot}/etc/logrotate.d/lfd

# Install man page
install -d -m 0755 %{buildroot}/usr/local/man/man1
install -m 0644 csf.1.txt %{buildroot}/usr/local/man/man1/csf.1

# Install cPanel integration files
install -d -m 0700 %{buildroot}/usr/local/cpanel/whostmgr/docroot/cgi/configserver
install -d -m 0700 %{buildroot}/usr/local/cpanel/whostmgr/docroot/cgi/configserver/csf
install -m 0700 cpanel/csf.cgi %{buildroot}/usr/local/cpanel/whostmgr/docroot/cgi/configserver/csf.cgi
cp -a csf/ %{buildroot}/usr/local/cpanel/whostmgr/docroot/cgi/configserver/

install -d -m 0755 %{buildroot}/usr/local/cpanel/whostmgr/docroot/addon_plugins
install -m 0644 cpanel/csf_small.png %{buildroot}/usr/local/cpanel/whostmgr/docroot/addon_plugins/

install -d -m 0755 %{buildroot}/usr/local/cpanel/whostmgr/docroot/themes/x/icons
# Use csf_small.png as referenced in cpanel/csf.conf appconfig icon= setting
install -m 0644 cpanel/csf_small.png %{buildroot}/usr/local/cpanel/whostmgr/docroot/themes/x/icons/csf_small.png

install -d -m 0755 %{buildroot}/usr/local/cpanel/whostmgr/docroot/templates
install -m 0644 cpanel/csf.tmpl %{buildroot}/usr/local/cpanel/whostmgr/docroot/templates/

install -d -m 0755 %{buildroot}/usr/local/cpanel/bin
install -m 0644 cpanel/csf.conf %{buildroot}/usr/local/cpanel/bin/csf.conf.appconfig

# Create symlinks in buildroot - these will be tracked as normal files
# Note: Symlink targets must not point within the buildroot.
ln -sf /usr/sbin/csf %{buildroot}/etc/csf/csf.pl
ln -sf /usr/sbin/lfd %{buildroot}/etc/csf/lfd.pl
ln -sf /usr/local/csf/bin/csftest.pl %{buildroot}/etc/csf/csftest.pl
ln -sf /usr/local/csf/bin/pt_deleted_action.pl %{buildroot}/etc/csf/pt_deleted_action.pl
ln -sf /usr/local/csf/bin/remove_apf_bfd.sh %{buildroot}/etc/csf/remove_apf_bfd.sh
ln -sf /usr/local/csf/bin/regex.custom.pm %{buildroot}/etc/csf/regex.custom.pm
ln -sf /usr/local/csf/tpl %{buildroot}/etc/csf/alerts

# END INSTALL -- DO NOT REMOVE THIS LINE, SEE debify/debify_mongler.pl

%clean
rm -rf %{buildroot}

%pre
%include %{SOURCE1}

%post
%include %{SOURCE2}

%preun
%include %{SOURCE3}

%postun
%include %{SOURCE4}

%files
%defattr(-,root,root,-)
/usr/sbin/csf
/usr/sbin/lfd
# Bin files - most are code, some are user-customizable
/usr/local/csf/bin/csftest.pl
/usr/local/csf/bin/remove_apf_bfd.sh
/usr/local/csf/lib/*
/usr/local/csf/profiles/*

# 
%config(noreplace) /usr/local/csf/bin/pt_deleted_action.pl
%config(noreplace) /usr/local/csf/bin/regex.custom.pm

# Templates in /usr/local/csf/tpl are 
%config /usr/local/csf/tpl/*.txt

# Config files - actual user-modifiable configuration
%config(noreplace) /etc/csf/csf.allow
%config(noreplace) /etc/csf/csf.blocklists
%config(noreplace) /etc/csf/csf.conf
%config(noreplace) /etc/csf/csf.deny
%config(noreplace) /etc/csf/csf.dirwatch
%config(noreplace) /etc/csf/csf.dyndns
%config(noreplace) /etc/csf/csf.fignore
%config(noreplace) /etc/csf/csf.ignore
%config(noreplace) /etc/csf/csf.logfiles
%config(noreplace) /etc/csf/csf.logignore
%config(noreplace) /etc/csf/csf.mignore
%config(noreplace) /etc/csf/csf.pignore
%config(noreplace) /etc/csf/csf.rblconf
%config(noreplace) /etc/csf/csf.redirect
%config(noreplace) /etc/csf/csf.resellers
%config(noreplace) /etc/csf/csf.rignore
%config(noreplace) /etc/csf/csf.signore
%config(noreplace) /etc/csf/csf.sips
%config(noreplace) /etc/csf/csf.smtpauth
%config(noreplace) /etc/csf/csf.suignore
%config(noreplace) /etc/csf/csf.syslogs
%config(noreplace) /etc/csf/csf.syslogusers
%config(noreplace) /etc/csf/csf.uidignore

# Documentation and metadata files (not config)
/etc/csf/changelog.txt
/etc/csf/license.txt
/etc/csf/readme.txt
/etc/csf/version.txt
# Config-ish but with no reason for modification
/etc/csf/cpanel.allow
/etc/csf/cpanel.comodo.allow
/etc/csf/cpanel.comodo.ignore
/etc/csf/cpanel.ignore
/etc/csf/csf.cloudflare
# Template files for messenger feature (blocked IP pages)
/etc/csf/messenger/*
# Symlinks owned by the package
/etc/csf/csf.pl
/etc/csf/lfd.pl
/etc/csf/csftest.pl
/etc/csf/pt_deleted_action.pl
/etc/csf/remove_apf_bfd.sh
/etc/csf/regex.custom.pm
/etc/csf/alerts
/var/lib/csf
/etc/cron.d/csf-cron
/etc/cron.d/lfd-cron
/usr/lib/systemd/system/csf.service
/usr/lib/systemd/system/lfd.service
/etc/logrotate.d/lfd
/usr/local/man/man1/csf.1
/usr/local/cpanel/whostmgr/docroot/cgi/configserver/*
/usr/local/cpanel/whostmgr/docroot/addon_plugins/csf_small.png
/usr/local/cpanel/whostmgr/docroot/themes/x/icons/csf_small.png
/usr/local/cpanel/whostmgr/docroot/templates/csf.tmpl
/usr/local/cpanel/bin/csf.conf.appconfig

%changelog
* Wed Feb 05 2025 Thomas "Andy" Baugh <andy.baugh@webpros.com> - 16.00-1
- Initial RPM packaging of CSF for cPanel OBS build system
- Converted from install.sh to RPM spec file
