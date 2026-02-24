# ConfigServer Security & Firewall (CSF) for cPanel
# RPM spec file

%define release_prefix 1
%define csf_version 16.04

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
install -d -m 0755 %{buildroot}/usr/local/csf/docs
install -d -m 0755 %{buildroot}/usr/local/csf/data
install -d -m 0755 %{buildroot}/usr/local/csf/messenger
install -d -m 0755 %{buildroot}/usr/local/csf/cron

# Install main scripts
install -d -m 0755 %{buildroot}/usr/sbin
install -m 0700 csf.pl %{buildroot}/usr/sbin/csf
install -m 0700 lfd.pl %{buildroot}/usr/sbin/lfd

# Install bin files
install -m 0700 bin/csftest.pl %{buildroot}/usr/local/csf/bin/
install -m 0700 bin/pt_deleted_action.pl %{buildroot}/usr/local/csf/bin/
install -m 0700 bin/regex.custom.pm %{buildroot}/usr/local/csf/bin/
install -m 0700 bin/remove_apf_bfd.sh %{buildroot}/usr/local/csf/bin/
install -m 0700 bin/auto.pl %{buildroot}/usr/local/csf/bin/

# Install library files (recursively)
cp -a lib/* %{buildroot}/usr/local/csf/lib/

# Install template files
cp -a tpl/* %{buildroot}/usr/local/csf/tpl/

# Install documentation files to /usr/local/csf/docs
install -m 0644 LICENSE.txt %{buildroot}/usr/local/csf/docs/license.txt
install -m 0644 etc/changelog.txt %{buildroot}/usr/local/csf/docs/
install -m 0644 etc/readme.txt %{buildroot}/usr/local/csf/docs/
install -m 0644 etc/version.txt %{buildroot}/usr/local/csf/docs/

# Install data files to /usr/local/csf/data
install -m 0644 etc/cpanel.allow %{buildroot}/usr/local/csf/data/
install -m 0644 etc/cpanel.comodo.allow %{buildroot}/usr/local/csf/data/
install -m 0644 etc/cpanel.comodo.ignore %{buildroot}/usr/local/csf/data/
install -m 0644 etc/cpanel.ignore %{buildroot}/usr/local/csf/data/
install -m 0644 etc/csf.cloudflare %{buildroot}/usr/local/csf/data/

# Install messenger templates to /usr/local/csf/messenger
cp -a etc/messenger/* %{buildroot}/usr/local/csf/messenger/

# Install config files from etc/ directory (recursively)
cp -a etc/* %{buildroot}/etc/csf/

# Install profile configurations
cp -a profiles/* %{buildroot}/usr/local/csf/profiles/
install -m 0600 etc/csf.conf %{buildroot}/usr/local/csf/profiles/reset_to_defaults.conf

# Install cron jobs to /usr/local/csf/cron
install -m 0644 csfcron.sh %{buildroot}/usr/local/csf/cron/csf-cron
install -m 0644 lfdcron.sh %{buildroot}/usr/local/csf/cron/lfd-cron

# Create /etc/cron.d directory for symlinks
install -d -m 0755 %{buildroot}/etc/cron.d

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

install -d -m 0755 %{buildroot}/usr/local/cpanel/Cpanel/Config/ConfigObj/Driver
cp -a cpanel/Driver/* %{buildroot}/usr/local/cpanel/Cpanel/Config/ConfigObj/Driver/

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

# Create symlinks for documentation files
ln -sf /usr/local/csf/docs/changelog.txt %{buildroot}/etc/csf/changelog.txt
ln -sf /usr/local/csf/docs/license.txt %{buildroot}/etc/csf/license.txt
ln -sf /usr/local/csf/docs/readme.txt %{buildroot}/etc/csf/readme.txt
ln -sf /usr/local/csf/docs/version.txt %{buildroot}/etc/csf/version.txt

# Create symlinks for data files
ln -sf /usr/local/csf/data/cpanel.allow %{buildroot}/etc/csf/cpanel.allow
ln -sf /usr/local/csf/data/cpanel.comodo.allow %{buildroot}/etc/csf/cpanel.comodo.allow
ln -sf /usr/local/csf/data/cpanel.comodo.ignore %{buildroot}/etc/csf/cpanel.comodo.ignore
ln -sf /usr/local/csf/data/cpanel.ignore %{buildroot}/etc/csf/cpanel.ignore
ln -sf /usr/local/csf/data/csf.cloudflare %{buildroot}/etc/csf/csf.cloudflare

# Create symlink for messenger directory
ln -sf /usr/local/csf/messenger %{buildroot}/etc/csf/messenger

# Create symlinks for cron jobs
ln -sf /usr/local/csf/cron/csf-cron %{buildroot}/etc/cron.d/csf-cron
ln -sf /usr/local/csf/cron/lfd-cron %{buildroot}/etc/cron.d/lfd-cron

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
/usr/local/csf/bin/auto.pl
/usr/local/csf/lib/*
/usr/local/csf/profiles/*

%config(noreplace) /usr/local/csf/bin/pt_deleted_action.pl
%config(noreplace) /usr/local/csf/bin/regex.custom.pm

# Templates in /usr/local/csf/tpl are 
%config /usr/local/csf/tpl/*.txt

# Documentation files (shipped to /usr/local/csf/docs, symlinked to /etc/csf)
/usr/local/csf/docs/changelog.txt
/usr/local/csf/docs/license.txt
/usr/local/csf/docs/readme.txt
/usr/local/csf/docs/version.txt

# Data files (shipped to /usr/local/csf/data, symlinked to /etc/csf)
/usr/local/csf/data/cpanel.allow
/usr/local/csf/data/cpanel.comodo.allow
/usr/local/csf/data/cpanel.comodo.ignore
/usr/local/csf/data/cpanel.ignore
/usr/local/csf/data/csf.cloudflare

# Messenger templates (shipped to /usr/local/csf/messenger, symlinked to /etc/csf)
/usr/local/csf/messenger/*

# Cron jobs (shipped to /usr/local/csf/cron, symlinked to /etc/cron.d)
/usr/local/csf/cron/csf-cron
/usr/local/csf/cron/lfd-cron

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

# Symlinks to documentation files (actual files in /usr/local/csf/docs)
/etc/csf/changelog.txt
/etc/csf/license.txt
/etc/csf/readme.txt
/etc/csf/version.txt

# Symlinks to data files (actual files in /usr/local/csf/data)
/etc/csf/cpanel.allow
/etc/csf/cpanel.comodo.allow
/etc/csf/cpanel.comodo.ignore
/etc/csf/cpanel.ignore
/etc/csf/csf.cloudflare

# Symlink to messenger directory (actual files in /usr/local/csf/messenger)
/etc/csf/messenger

# Symlinks to executables and templates
/etc/csf/csf.pl
/etc/csf/lfd.pl
/etc/csf/csftest.pl
/etc/csf/pt_deleted_action.pl
/etc/csf/remove_apf_bfd.sh
/etc/csf/regex.custom.pm
/etc/csf/alerts

/var/lib/csf

# Symlinks to cron jobs (actual files in /usr/local/csf/cron)
/etc/cron.d/csf-cron
/etc/cron.d/lfd-cron

/usr/lib/systemd/system/csf.service
/usr/lib/systemd/system/lfd.service

# Logrotate configuration
%config(noreplace) /etc/logrotate.d/lfd
/usr/local/man/man1/csf.1
/usr/local/cpanel/whostmgr/docroot/cgi/configserver/*
/usr/local/cpanel/whostmgr/docroot/addon_plugins/csf_small.png
/usr/local/cpanel/whostmgr/docroot/themes/x/icons/csf_small.png
/usr/local/cpanel/whostmgr/docroot/templates/csf.tmpl
/usr/local/cpanel/Cpanel/Config/ConfigObj/Driver/*
/usr/local/cpanel/bin/csf.conf.appconfig

%changelog
* Mon Feb 24 2026 Travis Holloway <travis.holloway@webpros.com> - 16.04-1
- Relocate non-configuration files from /etc/ to /usr/local/csf/ to comply
  with Ubuntu packaging policies while maintaining backward compatibility
  via symlinks

* Tue Feb 24 2026 Tim Mullin <tim.mullin@webpros.com> - 16.03-1
- Fixed bug in parsing upper-case time-out duration values

* Mon Feb 23 2026 Travis Holloway <travis.holloway@webpros.com> - 16.02-1
- Update regex to handle log changes to /var/log/secure on A10

* Fri Feb 20 2026 Travis Holloway <travis.holloway@webpros.com> - 16.01-1
- Update link in x-arf template

* Wed Feb 05 2026 Thomas "Andy" Baugh <andy.baugh@webpros.com> - 16.00-1
- Initial RPM packaging of CSF for cPanel OBS build system
- Converted from install.sh to RPM spec file
- Modernized entire codebase: switched to cPstrict, added function signatures,
  enforced perltidy standards, addressed perlcritic warnings
- Removed support for non-cPanel platforms (DirectAdmin, Plesk, VestaCP, CWP,
  InterWorx, CyberPanel, Webmin)
- Added comprehensive test suite with 100+ test files using Test2 framework
- Fixed security vulnerabilities: XSS in web UI modules, proper HTML encoding
  throughout
- Fixed numerous uninitialized variable warnings and potential runtime issues
- Removed AUTO_UPDATES functionality (package-managed updates only)
- Replaced custom implementations with cPanel libraries where available
  (Cpanel::Encoder::Tiny, Cpanel::JSON::XS)
- Added CI/CD workflows for automated building and testing
- Improved sandbox development environment for easier local testing
- Refactored core modules for better testability and maintainability
- Added POD documentation to all public module interfaces
- Fixed IPv6 handling, timeout validation, and iptables guard conditions
- Updated regex patterns to handle AlmaLinux 10 log format changes
- Removed deprecated Perl 4 syntax and bareword filehandles throughout
- Cleaned up code structure: moved modules to lib/, removed duplicate files
