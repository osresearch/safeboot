ifeq ($(PACKAGE_SET),dom0)
RPM_SPEC_FILES := qubes-safeboot.spec
ifeq ($(DIST_DOM0), fc32)
RPM_SPEC_FILES += efitools.spec
endif
endif

NO_ARCHIVE := 1

VERSION ?= $(file <$(ORIG_SRC)/version)
EFITOOLS_VERSION = 1.9.2

EFITOOLS = efitools-$(EFITOOLS_VERSION).tar.gz

SOURCES = qubes-safeboot-$(VERSION).tar.gz \
	$(EFITOOLS)

SOURCE_COPY_IN := $(SOURCES)

qubes-safeboot-$(VERSION).tar.gz:
	tar --xform='s:$(ORIG_SRC)/qubes:qubes-safeboot-$(VERSION):' -czhf $(CHROOT_DIR)$(DIST_SRC)/qubes-safeboot-$(VERSION).tar.gz $(ORIG_SRC)/qubes

$(EFITOOLS):
	tar --xform='s:$(ORIG_SRC)/efitools:efitools-$(EFITOOLS_VERSION):' -czf $(CHROOT_DIR)$(DIST_SRC)/$(EFITOOLS) $(ORIG_SRC)/efitools

# vim: set ft=make:
