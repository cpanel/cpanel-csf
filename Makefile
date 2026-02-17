# OBS Build System Integration
OBS_PROJECT := cpanel-plugins
OBS_PACKAGE := cpanel-csf
DISABLE_BUILD := repository=CentOS_6.5_standard

# Export OBS_PROJECT so debify can find the RPM to query for file lists
export OBS_PROJECT

-include $(EATOOLS_BUILD_DIR)obs.mk

.PHONY: sandbox test man install tarball clean-tarball

ULC=/usr/local/cpanel
VERSION := $(shell cat etc/version.txt 2>/dev/null || echo "16.00")
sandbox:
	mkdir -p /usr/local/csf
	ln -sfn $(CURDIR)/lib /usr/local/csf/lib
	if [ ! -d /etc/csf ] || [ -L /etc/csf ]; then ln -sfn $(CURDIR)/etc /etc/csf; fi
	mkdir -p /usr/local/man/man1
	ln -sfn $(CURDIR)/csf.1.txt /usr/local/man/man1/csf.1
	mkdir -p $(ULC)/whostmgr/cgi/configserver/csf
	test -e $(ULC)/whostmgr/cgi/configserver/csf.cgi && rm -f $(ULC)/whostmgr/cgi/configserver/csf.cgi; /bin/true
	ln -sfn $(CURDIR)/cpanel/csf.cgi $(ULC)/whostmgr/cgi/configserver/csf.cgi
	test -e $(ULC)/whostmgr/docroot/templates/csf.tmpl && rm -f $(ULC)/whostmgr/docroot/templates/csf.tmpl; /bin/true
	ln -sfn $(CURDIR)/cpanel/csf.tmpl $(ULC)/whostmgr/docroot/templates/csf.tmpl
	$(ULC)/bin/register_appconfig cpanel/csf.conf
	test -e $(ULC)/whostmgr/cgi/configserver/csf/configserver.css && rm -f $(ULC)/whostmgr/cgi/configserver/csf/configserver.css; /bin/true
	ln -sfn $(CURDIR)/csf/configserver.css $(ULC)/whostmgr/cgi/configserver/csf/configserver.css
	test -e $(ULC)/whostmgr/docroot/libraries/jquery-ui && rm -f $(ULC)/whostmgr/docroot/libraries/jquery-ui; /bin/true
	ln -sfn $(ULC)/3rdparty/share/jquery-ui $(ULC)/whostmgr/docroot/libraries/jquery-ui
	test -e $(ULC)/whostmgr/docroot/themes/x/icons/csf_small.png && rm -f $(ULC)/whostmgr/docroot/themes/x/icons/csf_small.png; /bin/true
	ln -sfn $(CURDIR)/cpanel/csf_small.png $(ULC)/whostmgr/docroot/themes/x/icons/csf_small.png
	test -e $(ULC)/whostmgr/cgi/configserver/csf/csf_small.png && rm -f $(ULC)/whostmgr/cgi/configserver/csf/csf_small.png; /bin/true
	ln -sfn $(CURDIR)/cpanel/csf_small.png $(ULC)/whostmgr/cgi/configserver/csf/csf_small.png

clean: clean-tarball
	rm -rf csf.tar.gz

clean-tarball:
	rm -f SOURCES/cpanel-csf-*.tar.gz

# Generate tarball for OBS/RPM build
tarball: clean-tarball
	@echo "Creating tarball for version $(VERSION)..."
	@mkdir -p SOURCES
	@tar -czf SOURCES/cpanel-csf-$(VERSION).tar.gz \
		--transform 's,^,cpanel-csf-$(VERSION)/,' \
		--exclude='.git*' \
		--exclude='SPECS' \
		--exclude='SOURCES' \
		--exclude='OBS.*' \
		--exclude='*.tar.gz' \
		--exclude='tmp' \
		--exclude='cover_db' \
		--exclude='debify' \
		etc/ \
		tpl/ \
		bin/ \
		lib/ \
		csf.pl \
		lfd.pl \
		csfcron.sh \
		lfdcron.sh \
		migratedata.sh \
		profiles/ \
		csf.1.txt \
		lfd.logrotate \
		cpanel/ \
		csf/ \
		lfd.service \
		csf.service \
		lfd.sh \
		csf.sh \
		os.pl
	@echo "Created SOURCES/cpanel-csf-$(VERSION).tar.gz"

# Ensure tarball is created before local or obs builds
local: tarball
obs: tarball

test:
	yath test -j8 t/*.t

man: lib/csf.help

lib/csf.help: all
	man csf | col -b > lib/csf.help
	@if ! git diff --quiet lib/csf.help; then \
		echo "ERROR: lib/csf.help has changes after regeneration. Commit the updated file."; \
		git diff lib/csf.help; \
		exit 1; \
	fi

install: lib/csf.help
	@# Increment version by 0.01
	@awk '{print $$1 + 0.01}' etc/version.txt > etc/version.txt.new
	@mv etc/version.txt.new etc/version.txt
	@echo "Version updated to $$(cat etc/version.txt)"
	@# Create tarball with files needed by install.sh
	tar -czf csf.tar.gz \
		os.pl \
		etc/ \
		tpl/ \
		bin/ \
		lib/ \
		csf.pl \
		lfd.pl \
		csfcron.sh \
		lfdcron.sh \
		migratedata.sh \
		profiles/ \
		csf.1.txt \
		lfd.logrotate \
		cpanel/ \
		csf/ \
		lfd.service \
		csf.service \
		lfd.sh \
		csf.sh
	@echo "Created csf.tar.gz"
