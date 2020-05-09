# segfault when using the PKCS11 engine to talk to the Yubikey.

BINS += bin/sbsign.safeboot
BINS += bin/sign-efi-sig-list.safeboot

all: $(BINS)

#
# sbsign needs to be built from a patched version to avoid a
# segfault when using the PKCS11 engine to talk to the Yubikey.
#
bin/sbsign.safeboot: sbsigntools/Makefile
	$(MAKE) -C $(dir $<)
	mkdir -p $(dir $@)
	cp $(dir $<)src/sbsign $@
sbsigntools/Makefile: sbsigntools/autogen.sh
	cd $(dir $@) ; ./autogen.sh && ./configure
sbsigntools/autogen.sh:
	git submodule update --init --recursive --recommend-shallow sbsigntools

#
# sign-efi-sig-list needs to be built from source to have support for
# the PKCS11 engine to talk to the Yubikey.
#
bin/sign-efi-sig-list.safeboot: efitools/Makefile
	$(MAKE) -C $(dir $<) sign-efi-sig-list
	mkdir -p $(dir $@)
	cp $(dir $<)sign-efi-sig-list $@
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
		binutils-dev \
		git \
		automake \
		help2man \
		libssl-dev \
		uuid-dev \


# Remove the temporary files
clean:
	rm -rf bin efitools sbsigntools
	mkdir efitools sbsigntools
	git submodule update --init --recursive --recommend-shallow 

# Regenerate the source file
tar: clean
	tar zcvf ../safeboot_0.1.orig.tar.gz \
		--exclude .git\* \
		--exclude debian \
		.

package: tar
	debuild -uc -us
