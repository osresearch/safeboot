
BINS += bin/sbsign
BINS += bin/sign-efi-sig-list

all: $(BINS)

#
# sbsign needs to be built from a patched version to avoid a
# segfault when using the PKCS11 engine to talk to the Yubikey.
#
bin/sbsign: sbsigntools/Makefile
	$(MAKE) -C $(dir $<)
	cp $(dir $<)src/sbsign $@
sbsigntools/Makefile: sbsigntools/autogen.sh
	cd $(dir $@) ; ./autogen.sh && ./configure
sbsigntools/autogen.sh:
	git submodule update --init sbsigntools

#
# sign-efi-sig-list needs to be built from source to have support for
# the PKCS11 engine to talk to the Yubikey.
#
bin/sign-efi-sig-list: efitools/Makefile
	$(MAKE) -C $(dir $<) $(notdir $@)
	cp $(dir $<)$(notdir $@) $@
efitools/Makefile:
	git submodule update --init efitools


#
# Extra package requirements
#
requirements:
	apt install -y \
		tpm2-tools \
		efitools \
		gnu-efi \
		opensc \
		yubico-piv-tool \
		libengine-pkcs11-openssl \
		build-essential \
		git \
		autotools \
		help2man \

