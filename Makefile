VERSION ?= 0.5

BINS += bin/sbsign.safeboot
BINS += bin/sign-efi-sig-list.safeboot
BINS += bin/tpm2-totp

all: $(BINS)

#
# sbsign needs to be built from a patched version to avoid a
# segfault when using the PKCS11 engine to talk to the Yubikey.
#
SUBMODULES += sbsigntools
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
SUBMODULES += efitools
bin/sign-efi-sig-list.safeboot: efitools/Makefile
	$(MAKE) -C $(dir $<) sign-efi-sig-list
	mkdir -p $(dir $@)
	cp $(dir $<)sign-efi-sig-list $@
efitools/Makefile:
	git submodule update --init efitools

#
# tpm2-totp is build from a branch with hostname support
#
SUBMODULES += tpm2-totp
bin/tpm2-totp: tpm2-totp/Makefile
	$(MAKE) -C $(dir $<)
	mkdir -p $(dir $@)
	cp $(dir $<)/tpm2-totp $@
tpm2-totp/Makefile:
	git submodule update --init tpm2-totp
	cd $(dir $@) ; ./bootstrap && ./configure


#
# Extra package building requirements
#
requirements:
	DEBIAN_FRONTEND=noninteractive \
	apt install -y \
		devscripts \
		debhelper \
		tpm2-tools \
		libqrencode-dev \
		libtss2-dev \
		efitools \
		gnu-efi \
		opensc \
		yubico-piv-tool \
		libengine-pkcs11-openssl \
		build-essential \
		binutils-dev \
		git \
		pkg-config \
		automake \
		autoconf \
		autoconf-archive \
		initramfs-tools \
		help2man \
		libssl-dev \
		uuid-dev \


# Remove the temporary files
clean:
	rm -rf bin $(SUBMODULES)
	mkdir $(SUBMODULES)
	git submodule update --init --recursive --recommend-shallow 

# Regenerate the source file
tar: clean
	tar zcvf ../safeboot_$(VERSION).orig.tar.gz \
		--exclude .git \
		--exclude debian \
		.

package: tar
	debuild -uc -us
	cp ../safeboot_$(VERSION)_amd64.deb safeboot-unstable.deb


# Run shellcheck on the main script
check:
	shellcheck sbin/safeboot
	shellcheck sbin/safeboot-tpm-unseal
