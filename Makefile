.PHONY: sandbox test man install

ULC=/usr/local/cpanel
sandbox:
	mkdir -p /usr/local/csf
	ln -sfn $(CURDIR)/lib /usr/local/csf/lib
	if [ ! -d /etc/csf ] || [ -L /etc/csf ]; then ln -sfn $(CURDIR)/etc /etc/csf; fi
	mkdir -p /usr/local/man/man1
	ln -sfn $(CURDIR)/csf.1.txt /usr/local/man/man1/csf.1
	mkdir -p $(ULC)/whostmgr/cgi/configserver/csf
	test -e $(ULC)/whostmgr/cgi/configserver/csf.cgi && rm -f $(ULC)/whostmgr/cgi/configserver/csf.cgi; /bin/true
	ln -s $(CURDIR)/cpanel/csf.cgi $(ULC)/whostmgr/cgi/configserver/csf.cgi
	test -e $(ULC)/whostmgr/docroot/templates/csf.tmpl && rm -f $(ULC)/whostmgr/docroot/templates/csf.tmpl; /bin/true
	ln -s $(CURDIR)/cpanel/csf.tmpl $(ULC)/whostmgr/docroot/templates/csf.tmpl
	$(ULC)/bin/register_appconfig cpanel/csf.conf
	test -e $(ULC)/whostmgr/cgi/configserver/csf/configserver.css && rm -f $(ULC)/whostmgr/cgi/configserver/csf/configserver.css; /bin/true
	ln -s $(CURDIR)/csf/configserver.css $(ULC)/whostmgr/cgi/configserver/csf/configserver.css

clean:
	rm -rf csf.tar.gz

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
		install.sh \
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
		csf.sh \
		csget.pl \
		auto.pl
	@echo "Created csf.tar.gz"
