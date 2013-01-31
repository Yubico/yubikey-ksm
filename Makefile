# Written by Simon Josefsson <simon@josefsson.org>.
# Copyright (c) 2009-2012 Yubico AB
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are
# met:
#
#   * Redistributions of source code must retain the above copyright
#     notice, this list of conditions and the following disclaimer.
#
#   * Redistributions in binary form must reproduce the above
#     copyright notice, this list of conditions and the following
#     disclaimer in the documentation and/or other materials provided
#     with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
# "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
# LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
# A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
# OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
# SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
# LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
# DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
# THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

VERSION = 1.10
PACKAGE = yubikey-ksm
CODE = .htaccess Makefile NEWS ykksm-config.php ykksm-db.sql	\
	ykksm-decrypt.php ykksm-export ykksm-gen-keys	\
	ykksm-import ykksm-utils.php ykksm-checksum
DOCS = doc/DecryptionProtocol.wiki doc/DesignGoals.wiki		\
	doc/GenerateKeys.wiki doc/GenerateKSMKey.wiki		\
	doc/ImportKeysToKSM.wiki doc/Installation.wiki		\
	doc/KeyProvisioningFormat.wiki doc/ServerHardening.wiki	\
	doc/SyncMonitor.wiki
MANS = ykksm-checksum.1 ykksm-export.1 ykksm-gen-keys.1		\
	ykksm-import.1

all:
	@echo "Try 'make install' or 'make symlink'."
	@echo "Docs: https://github.com/Yubico/$(PROJECT)/wiki/Installation"
	@exit 1

# Installation rules.

etcprefix = /etc/yubico/ksm
binprefix = /usr/bin
phpprefix = /usr/share/yubikey-ksm
docprefix = /usr/share/doc/yubikey-ksm
wwwgroup = www-data

install: $(MANS)
	install -D --mode 640 .htaccess $(DESTDIR)$(phpprefix)/.htaccess
	install -D --mode 640 ykksm-decrypt.php $(DESTDIR)$(phpprefix)/ykksm-decrypt.php
	install -D --mode 640 ykksm-utils.php $(DESTDIR)$(phpprefix)/ykksm-utils.php
	install -D ykksm-gen-keys $(DESTDIR)$(binprefix)/ykksm-gen-keys
	install -D ykksm-import $(DESTDIR)$(binprefix)/ykksm-import
	install -D ykksm-export $(DESTDIR)$(binprefix)/ykksm-export
	install -D ykksm-checksum $(DESTDIR)$(binprefix)/ykksm-checksum
	install -D --backup --mode 640 --group $(wwwgroup) ykksm-config.php $(DESTDIR)$(etcprefix)/ykksm-config.php
	install -D ykksm-gen-keys.1 $(DESTDIR)$(manprefix)/ykksm-gen-keys.1
	install -D ykksm-import.1 $(DESTDIR)$(manprefix)/ykksm-import.1
	install -D ykksm-export.1 $(DESTDIR)$(manprefix)/ykksm-export.1
	install -D ykksm-checksum.1 $(DESTDIR)$(manprefix)/ykksm-checksum.1
	install -D ykksm-db.sql $(DESTDIR)$(docprefix)/ykksm-db.sql
	install -D Makefile $(DESTDIR)$(docprefix)/ykksm.mk
	install -D $(DOCS) $(DESTDIR)$(docprefix)/

wwwprefix = /var/www/wsapi

symlink:
	install -d $(wwwprefix)
	ln -sf $(phpprefix)/.htaccess $(wwwprefix)/.htaccess
	ln -sf $(phpprefix)/ykksm-decrypt.php $(wwwprefix)/decrypt.php

# Maintainer rules.

PROJECT = $(PACKAGE)

$(PACKAGE)-$(VERSION).tgz: $(FILES) $(MANS)
	mkdir $(PACKAGE)-$(VERSION) $(PACKAGE)-$(VERSION)/doc
	cp $(CODE) $(PACKAGE)-$(VERSION)/
	cp $(MANS) $(PACKAGE)-$(VERSION)/
	cp $(DOCS) $(PACKAGE)-$(VERSION)/doc/
	git2cl > $(PACKAGE)-$(VERSION)/ChangeLog
	tar cfz $(PACKAGE)-$(VERSION).tgz $(PACKAGE)-$(VERSION)
	rm -rf $(PACKAGE)-$(VERSION)

dist: $(PACKAGE)-$(VERSION).tgz

distclean: clean
	rm -f *.1

clean:
	rm -f *~
	rm -rf $(PACKAGE)-$(VERSION)

NAME_ykksm-checksum = 'Print checksum of important database fields.  Useful for quickly determining whether several KSMs are in sync.'
NAME_ykksm-export = 'Tool to export keys to the YKKSM-KEYPROV format.'
NAME_ykksm-gen-keys = 'Tool to generate keys on the YKKSM-KEYPROV format.'
NAME_ykksm-import = 'Tool to import key data on the YKKSM-KEYPROV format.'

%.1: %
	help2man -N --name=$(NAME_$*) --version-string=1 ./$* > $@

man: $(MANS)

release: dist
	@if test -z "$(KEYID)"; then \
		echo "Try this instead:"; \
		echo "  make release KEYID=[PGPKEYID]"; \
		echo "For example:"; \
		echo "  make release KEYID=2117364A"; \
		exit 1; \
	fi
	@head -1 NEWS | grep -q "Version $(VERSION) (released `date -I`)" || \
                (echo 'error: You need to update date/version in NEWS'; exit 1)
	gpg --detach-sign --default-key $(KEYID) $(PACKAGE)-$(VERSION).tgz
	gpg --verify $(PACKAGE)-$(VERSION).tgz.sig

	git tag -u $(KEYID) -m "$(PACKAGE)-$(VERSION)" $(PACKAGE)-$(VERSION)
	git push
	git push --tags

	git add $(PACKAGE)-$(VERSION).tgz
	git add $(PACKAGE)-$(VERSION).tgz.sig
	git stash
	git checkout gh-pages
	git stash pop
	git mv $(PACKAGE)-$(VERSION).tgz releases/
	git mv $(PACKAGE)-$(VERSION).tgz.sig releases/
	x=$$(ls -1v releases/*.tgz | awk -F\- '{print $$3}' | sed 's/.tgz//' | paste -sd ',' - | sed 's/,/, /g' | sed 's/\([0-9.]\{1,\}\)/"\1"/g');sed -i -e "2s/\[.*\]/[$$x]/" releases.html
	git add releases.html
	git commit -m "Added tarball for release $(VERSION)"
	git push
	git checkout master
