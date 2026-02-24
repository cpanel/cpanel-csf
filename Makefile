# OBS Build System Integration
OBS_PROJECT := cpanel-plugins
OBS_PACKAGE := cpanel-csf
DISABLE_BUILD := repository=CentOS_6.5_standard
PERL_FILES := $(shell git ls-files --exclude 'debify' | grep -E '.pm$$|.pl$$')

# Export OBS_PROJECT so debify can find the RPM to query for file lists
export OBS_PROJECT

-include $(EATOOLS_BUILD_DIR)obs.mk

.PHONY: sandbox test man install tarball clean-tarball bump-version bump-changelog

ULC=/usr/local/cpanel
VERSION := $(shell cat etc/version.txt 2>/dev/null || echo "16.00")
sandbox:
	mkdir -p /usr/local/csf
	ln -sfn $(CURDIR)/lib /usr/local/csf/lib
	ln -sfn $(CURDIR)/bin /usr/local/csf/bin
	if [ ! -d /etc/csf ] || [ -L /etc/csf ]; then ln -sfn $(CURDIR)/etc /etc/csf; fi
	ln -sfn $(CURDIR)/csf.pl /usr/sbin/csf
	ln -sfn $(CURDIR)/lfd.pl /usr/sbin/lfd
	mkdir -p /var/lib/csf/backup /var/lib/csf/Geo /var/lib/csf/lock /var/lib/csf/stats /var/lib/csf/zone
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
	rm -rf BUILD/

clean-tarball:
	rm -f SOURCES/cpanel-csf-*.tar.gz

NEW_VERSION := $(shell awk '{print $$1 + 0.01}' etc/version.txt)
bump-version:
	@echo $(NEW_VERSION) > etc/version.txt
	@sed -i 's/^%define csf_version.*/%define csf_version $(NEW_VERSION)/' SPECS/cpanel-csf.spec
	@echo "Version is now $(NEW_VERSION). Please commit your changes."

TEMP_FILE         := $(shell mktemp)
GIT_USER          := $(shell git config user.name)
GIT_EMAIL         := $(shell git config user.email)
LAST_COMMIT       := $(shell git log --format='%H' -- etc/version.txt | head -n1)
DATE              := $(shell date '+%a %b %d %Y')
bump-changelog: bump-version
	@echo "Harvesting changelog entries since $(LAST_COMMIT)..."
	echo "* $(DATE) $(GIT_USER) <$(GIT_EMAIL)> - $(NEW_VERSION)-1" > $(TEMP_FILE)
	git log $(LAST_COMMIT)..HEAD --format='%B' | devtools/extract-changelog >> $(TEMP_FILE)
	sed -i "/^%changelog$$/r $(TEMP_FILE)" SPECS/cpanel-csf.spec
	rm -f $(TEMP_FILE)
	@echo "Changelog entry added for version $(NEW_VERSION)"
	git add etc/version.txt SPECS/cpanel-csf.spec
	git commit -m "Bump version to $(NEW_VERSION)" -m "Changelog:"

# Generate tarball for OBS/RPM build
tarball: clean
	@echo "Creating tarball for version $(VERSION)..."
	@sed -i 's/^use cPstrict;/use cPstrict;\nno warnings;/g' $(PERL_FILES)
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
		LICENSE.txt \
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
	@git checkout $(PERL_FILES)

pre-debify:
	debify/debify_mongler.pl

# Ensure tarball is created before local or obs builds
local: tarball pre-debify
obs: tarball pre-debify

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

