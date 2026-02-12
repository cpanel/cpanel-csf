#!/bin/bash

# Fix buildroot for Debian builds - it should be debian/tmp
# The vars.sh file sets it to /usr/src/packages/BUILD which is wrong
source debian/vars.sh
export buildroot="debian/tmp"

# Now run the actual debify-generated install commands
rm -rf $buildroot
# Create directory structure
install -d -m 0700 $buildroot/etc/csf
install -d -m 0700 $buildroot/var/lib/csf
install -d -m 0700 $buildroot/var/lib/csf/backup
install -d -m 0700 $buildroot/var/lib/csf/Geo
install -d -m 0700 $buildroot/var/lib/csf/ui
install -d -m 0700 $buildroot/var/lib/csf/stats
install -d -m 0700 $buildroot/var/lib/csf/lock
install -d -m 0700 $buildroot/var/lib/csf/zone
install -d -m 0755 $buildroot/usr/local/csf
install -d -m 0755 $buildroot/usr/local/csf/bin
install -d -m 0755 $buildroot/usr/local/csf/lib
install -d -m 0755 $buildroot/usr/local/csf/tpl
install -d -m 0755 $buildroot/usr/local/csf/profiles
# Install main scripts
install -d -m 0755 $buildroot/usr/sbin
install -m 0700 csf.pl $buildroot/usr/sbin/csf
install -m 0700 lfd.pl $buildroot/usr/sbin/lfd
# Install bin files
install -m 0700 bin/csftest.pl $buildroot/usr/local/csf/bin/
install -m 0700 bin/pt_deleted_action.pl $buildroot/usr/local/csf/bin/
install -m 0700 bin/regex.custom.pm $buildroot/usr/local/csf/bin/
install -m 0700 bin/remove_apf_bfd.sh $buildroot/usr/local/csf/bin/
# Install library files (recursively)
cp -a lib/* $buildroot/usr/local/csf/lib/
# Install template files
cp -a tpl/* $buildroot/usr/local/csf/tpl/
# Install config files from etc/ directory (recursively)
cp -a etc/* $buildroot/etc/csf/
# Install profile configurations
cp -a profiles/* $buildroot/usr/local/csf/profiles/
install -m 0600 etc/csf.conf $buildroot/usr/local/csf/profiles/reset_to_defaults.conf
# Install cron jobs
install -d -m 0755 $buildroot/etc/cron.d
install -m 0644 csfcron.sh $buildroot/etc/cron.d/csf-cron
install -m 0644 lfdcron.sh $buildroot/etc/cron.d/lfd-cron
# Install systemd service files
install -d -m 0755 $buildroot/usr/lib/systemd/system
install -m 0644 csf.service $buildroot/usr/lib/systemd/system/
install -m 0644 lfd.service $buildroot/usr/lib/systemd/system/
# Install logrotate config
install -d -m 0755 $buildroot/etc/logrotate.d
install -m 0644 lfd.logrotate $buildroot/etc/logrotate.d/lfd
# Install man page
install -d -m 0755 $buildroot/usr/local/man/man1
install -m 0644 csf.1.txt $buildroot/usr/local/man/man1/csf.1
# Install cPanel integration files
install -d -m 0700 $buildroot/usr/local/cpanel/whostmgr/docroot/cgi/configserver
install -d -m 0700 $buildroot/usr/local/cpanel/whostmgr/docroot/cgi/configserver/csf
install -m 0700 cpanel/csf.cgi $buildroot/usr/local/cpanel/whostmgr/docroot/cgi/configserver/csf.cgi
cp -a csf/ $buildroot/usr/local/cpanel/whostmgr/docroot/cgi/configserver/
install -d -m 0755 $buildroot/usr/local/cpanel/whostmgr/docroot/addon_plugins
install -m 0644 etc/ui/images/csf_small.png $buildroot/usr/local/cpanel/whostmgr/docroot/addon_plugins/
install -d -m 0755 $buildroot/usr/local/cpanel/whostmgr/docroot/themes/x/icons
# Use csf_small.png as referenced in cpanel/csf.conf appconfig icon= setting
install -m 0644 cpanel/csf_small.png $buildroot/usr/local/cpanel/whostmgr/docroot/themes/x/icons/csf_small.png
install -d -m 0755 $buildroot/usr/local/cpanel/whostmgr/docroot/templates
install -m 0644 cpanel/csf.tmpl $buildroot/usr/local/cpanel/whostmgr/docroot/templates/
install -d -m 0755 $buildroot/usr/local/cpanel/Cpanel/Config/ConfigObj/Driver
cp -a cpanel/Driver/* $buildroot/usr/local/cpanel/Cpanel/Config/ConfigObj/Driver/
install -d -m 0755 $buildroot/usr/local/cpanel/bin
install -m 0644 cpanel/csf.conf $buildroot/usr/local/cpanel/bin/csf.conf.appconfig
# Create symlinks in buildroot - these will be tracked as normal files
# Note: Symlink targets must not point within the buildroot.
ln -sf /usr/sbin/csf $buildroot/etc/csf/csf.pl
ln -sf /usr/sbin/lfd $buildroot/etc/csf/lfd.pl
ln -sf /usr/local/csf/bin/csftest.pl $buildroot/etc/csf/csftest.pl
ln -sf /usr/local/csf/bin/pt_deleted_action.pl $buildroot/etc/csf/pt_deleted_action.pl
ln -sf /usr/local/csf/bin/remove_apf_bfd.sh $buildroot/etc/csf/remove_apf_bfd.sh
ln -sf /usr/local/csf/bin/regex.custom.pm $buildroot/etc/csf/regex.custom.pm
ln -sf /usr/local/csf/tpl $buildroot/etc/csf/alerts
