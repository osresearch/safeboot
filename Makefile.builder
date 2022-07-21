ifeq ($(PACKAGE_SET),dom0)
RPM_SPEC_FILES := qubes-safeboot.spec
ifeq ($(DIST_DOM0), fc32)
RPM_SPEC_FILES += sbsigntools.spec efitools.spec tpm2-tss.spec tpm2-tools.spec
endif
endif

NO_ARCHIVE := 1

VERSION ?= $(file <$(ORIG_SRC)/version)

EFITOOLS_VERSION = 1.9.2
SBSIGNTOOLS_VERSION = 0.9.4
TPM2_TSS_VERSION = 3.1.0
TPM2_TOOLS_VERSION = 5.1.1

EFITOOLS = efitools-$(EFITOOLS_VERSION).tar.gz
SBSIGNTOOLS = sbsigntools-$(SBSIGNTOOLS_VERSION).tar.gz
TPM2_TSS = tpm2-tss-$(TPM2_TSS_VERSION).tar.gz
TPM2_TOOLS = tpm2-tools-$(TPM2_TOOLS_VERSION).tar.gz

SOURCES = qubes-safeboot-$(VERSION).tar.gz \
	$(SBSIGNTOOLS) \
	$(TPM2_TSS) \
	$(TPM2_TOOLS) \
	$(EFITOOLS)

SOURCE_COPY_IN := $(SOURCES)

qubes-safeboot-$(VERSION).tar.gz:
	tar --xform='s:$(ORIG_SRC)/qubes:qubes-safeboot-$(VERSION):' -czhf $(CHROOT_DIR)$(DIST_SRC)/qubes-safeboot-$(VERSION).tar.gz $(ORIG_SRC)/qubes

$(EFITOOLS):
	tar --xform='s:$(ORIG_SRC)/efitools:efitools-$(EFITOOLS_VERSION):' -czf $(CHROOT_DIR)$(DIST_SRC)/$(EFITOOLS) $(ORIG_SRC)/efitools

$(SBSIGNTOOLS):
	tar --xform='s:$(ORIG_SRC)/sbsigntools:sbsigntools-$(SBSIGNTOOLS_VERSION):' -czf $(CHROOT_DIR)$(DIST_SRC)/$(SBSIGNTOOLS) $(ORIG_SRC)/sbsigntools

$(TPM2_TSS):
	tar --xform='s:$(ORIG_SRC)/tpm2-tss:tpm2-tss-$(TPM2_TSS_VERSION):' -czf $(CHROOT_DIR)$(DIST_SRC)/$(TPM2_TSS) $(ORIG_SRC)/tpm2-tss

$(TPM2_TOOLS):
	tar --xform='s:$(ORIG_SRC)/tpm2-tools:tpm2-tools-$(TPM2_TOOLS_VERSION):' -czf $(CHROOT_DIR)$(DIST_SRC)/$(TPM2_TOOLS) $(ORIG_SRC)/tpm2-tools

# vim: set ft=make:
