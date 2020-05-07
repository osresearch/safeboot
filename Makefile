
BINS += bin/sbsign
BINS += bin/sign-efi-sig-list

all: $(BINS)

INITRAMFS=/etc/initramfs-tools

install:
	cp initramfs/scripts/dmverity-root $(INITRAMFS)/scripts/local-bottom/
	cp initramfs/hooks/dmverity-root $(INITRAMFS)/hooks/
	cp initramfs/hooks/tpm-unseal $(INITRAMFS)/hooks/
	cp bin/safeboot-tpm-unseal /usr/local/bin/
	update-initramfs -u

hashes:
	@echo "this will take a while..."
	mount -o ro,remount /
	fsck /
	veritysetup format --debug /dev/vgubuntu/root /dev/vgubuntu/hashes \
		| tee verity.log
sign: verity.log
	./bin/safeboot-signkernel \
		root=/dev/mapper/vgubuntu-root \
		ro \
		verity.hashdev=/dev/mapper/vgubuntu-hashes \
		verity.hash="`awk '/Root hash:/ { print $$3 }' $<`" \


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
		binutils-dev \
		git \
		automake \
		help2man \
		libssl-dev \
		uuid-dev \

