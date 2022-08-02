ifeq ($(PACKAGE_SET),dom0)
RPM_SPEC_FILES := qubes-safeboot.spec
endif

NO_ARCHIVE := 1

VERSION ?= $(file <$(ORIG_SRC)/version)

SOURCES = qubes-safeboot-$(VERSION).tar.gz

SOURCE_COPY_IN := $(SOURCES)

qubes-safeboot-$(VERSION).tar.gz:
	tar --xform='s:$(ORIG_SRC)/qubes:qubes-safeboot-$(VERSION):' -czhf $(CHROOT_DIR)$(DIST_SRC)/qubes-safeboot-$(VERSION).tar.gz $(ORIG_SRC)/qubes

# vim: set ft=make:
