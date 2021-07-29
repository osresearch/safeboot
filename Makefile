VERSION ?= 0.8

GIT_DIRTY := $(shell if git status -s >/dev/null ; then echo dirty ; else echo clean ; fi)
GIT_HASH  := $(shell git rev-parse HEAD)
TOP := $(shell pwd)

BINS += bin/sbsign.safeboot
BINS += bin/sign-efi-sig-list.safeboot
BINS += bin/tpm2-totp
BINS += bin/tpm2

all: $(BINS) update-certs

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
	git submodule update --init --recursive --recommend-shallow efitools

#
# tpm2-tss is the library used by tpm2-tools
#
SUBMODULES += tpm2-tss

libtss2-include = -I$(TOP)/tpm2-tss/include
libtss2-mu = $(TOP)/build/tpm2-tss/src/tss2-mu/.libs/libtss2-mu.a
libtss2-rc = $(TOP)/build/tpm2-tss/src/tss2-rc/.libs/libtss2-rc.a
libtss2-sys = $(TOP)/build/tpm2-tss/src/tss2-sys/.libs/libtss2-sys.a
libtss2-esys = $(TOP)/build/tpm2-tss/src/tss2-esys/.libs/libtss2-esys.a
libtss2-tcti = $(TOP)/build/tpm2-tss/src/tss2-tcti/.libs/libtss2-tctildr.a

tpm2-tss/bootstrap:
	mkdir -p $(dir $@)
	git submodule update --init --recursive --recommend-shallow $(dir $@)
tpm2-tss/configure: tpm2-tss/bootstrap
	cd $(dir $@) ; ./bootstrap
build/tpm2-tss/Makefile: tpm2-tss/configure
	mkdir -p $(dir $@)
	cd $(dir $@) ; ../../tpm2-tss/configure \
		--disable-doxygen-doc \

$(libtss2-esys): build/tpm2-tss/Makefile
	$(MAKE) -C $(dir $<)

#
# tpm2-tools is the head after bundling and ecc support built in
#
SUBMODULES += tpm2-tools

tpm2-tools/bootstrap:
	git submodule update --init --recursive --recommend-shallow $(dir $@)
tpm2-tools/configure: tpm2-tools/bootstrap
	cd $(dir $@) ; ./bootstrap
build/tpm2-tools/Makefile: tpm2-tools/configure $(libtss2-esys)
	mkdir -p $(dir $@)
	cd $(dir $@) ; ../../tpm2-tools/configure \
		TSS2_RC_CFLAGS=$(libtss2-include) \
		TSS2_RC_LIBS="$(libtss2-rc)" \
		TSS2_MU_CFLAGS=$(libtss2-include) \
		TSS2_MU_LIBS="$(libtss2-mu)" \
		TSS2_SYS_CFLAGS=$(libtss2-include) \
		TSS2_SYS_LIBS="$(libtss2-sys)" \
		TSS2_TCTILDR_CFLAGS=$(libtss2-include) \
		TSS2_TCTILDR_LIBS="$(libtss2-tcti)" \
		TSS2_ESYS_3_0_CFLAGS=$(libtss2-include) \
		TSS2_ESYS_3_0_LIBS="$(libtss2-esys) -ldl" \

build/tpm2-tools/tools/tpm2: build/tpm2-tools/Makefile
	$(MAKE) -C $(dir $<)

bin/tpm2: build/tpm2-tools/tools/tpm2
	mkdir -p $(dir $@)
	cp $< $@


#
# tpm2-totp is build from a branch with hostname support
#
SUBMODULES += tpm2-totp
tpm2-totp/bootstrap:
	git submodule update --init --recursive --recommend-shallow tpm2-totp
tpm2-totp/configure: tpm2-totp/bootstrap
	cd $(dir $@) ; ./bootstrap
build/tpm2-totp/Makefile: tpm2-totp/configure $(libtss2-esys)
	mkdir -p $(dir $@)
	cd $(dir $@) && $(TOP)/$< \
		TSS2_MU_CFLAGS=-I../tpm2-tss/include \
		TSS2_MU_LIBS="$(libtss2-mu)" \
		TSS2_TCTILDR_CFLAGS=$(libtss2-include) \
		TSS2_TCTILDR_LIBS="$(libtss2-tcti)" \
		TSS2_TCTI_DEVICE_LIBDIR="$(dir $(libtss2-tcti))" \
		TSS2_ESYS_CFLAGS=$(libtss2-include) \
		TSS2_ESYS_LIBS="$(libtss2-esys) $(libtss2-sys) -lssl -lcrypto -ldl" \

build/tpm2-totp/tpm2-totp: build/tpm2-totp/Makefile
	$(MAKE) -C $(dir $<)
bin/tpm2-totp: build/tpm2-totp/tpm2-totp
	mkdir -p $(dir $@)
	cp $< $@

#
# swtpm and libtpms are used for simulating the qemu tpm2
#
SUBMODULES += libtpms
LIBTPMS_OUTPUT := build/libtpms/src/.libs/libtpms_tpm2.a
libtpms/autogen.sh:
	git submodule update --init --recursive --recommend-shallow $(dir $@)
libtpms/configure: libtpms/autogen.sh
	cd $(dir $@) ; \
	NOCONFIGURE=1 \
	./autogen.sh
build/libtpms/Makefile: libtpms/configure
	mkdir -p $(dir $@)
	cd $(dir $@) ; \
	../../libtpms/configure --with-openssl --with-tpm2
$(LIBTPMS_OUTPUT): build/libtpms/Makefile
	$(MAKE) -C $(dir $<)

SUBMODULES += swtpm
SWTPM=build/swtpm/src/swtpm/swtpm
swtpm/autogen.sh:
	git submodule update --init --recursive --recommend-shallow $(dir $@)
swtpm/configure: swtpm/autogen.sh
	cd $(dir $@) ; \
		NOCONFIGURE=1 \
		./autogen.sh \

build/swtpm/Makefile: swtpm/configure | $(LIBTPMS_OUTPUT)
	mkdir -p $(dir $@)
	cd $(dir $@) ; \
	LIBTPMS_LIBS="-L$(TOP)/build/libtpms/src/.libs -ltpms" \
	LIBTPMS_CFLAGS="-I$(TOP)/libtpms/include" \
	../../swtpm/configure

$(SWTPM): build/swtpm/Makefile
	$(MAKE) -C $(dir $<)


#
# busybox for command line utilities
#
SUBMODULES += busybox
busybox/Makefile:
	git submodule update --init --recursive --recommend-shallow $(dir $@)
busybox/.configured: initramfs/busybox.config busybox/Makefile
	cp $< $(dir $@).config
	$(MAKE) -C $(dir $@) oldconfig
	touch $@
busybox/busybox: busybox/.configured
	$(MAKE) -C $(dir $<)
bin/busybox: busybox/busybox
	mkdir -p $(dir $@)
	cp $(dir $<)/busybox $@

#
# kexec for starting the new kernel
#
SUBMODULES += kexec-tools
kexec-tools/bootstrap:
	git submodule update --init --recursive --recommend-shallow $(dir $@)
kexec-tools/configure: kexec-tools/bootstrap
	cd $(dir $@) ; ./bootstrap
build/kexec-tools/Makefile: kexec-tools/configure
	mkdir -p $(dir $@)
	cd $(dir $@) && $(TOP)/$<
build/kexec-tools/build/sbin/kexec: build/kexec-tools/Makefile
	$(MAKE) -C $(dir $<)
bin/kexec: build/kexec-tools/build/sbin/kexec
	mkdir -p $(dir $@)
	cp $< $@

#
# Linux kernel for the PXE boot image
#
LINUX		:= linux-5.4.117
#LINUX		:= linux-5.10.35
#LINUX		:= linux-5.7.2
LINUX_TAR	:= $(LINUX).tar.xz
LINUX_SIG	:= $(LINUX).tar.sign
LINUX_URL	:= https://cdn.kernel.org/pub/linux/kernel/v5.x/$(LINUX_TAR)

$(LINUX_TAR):
	[ -r $@.tmp ] || wget -O $@.tmp $(LINUX_URL)
	[ -r $(LINUX_SIG) ] || wget -nc $(dir $(LINUX_URL))/$(LINUX_SIG)
	#unxz -cd < $@.tmp | gpg2 --verify $(LINUX_SIG) -
	mv $@.tmp $@

$(LINUX): $(LINUX)/.patched
$(LINUX)/.patched: $(LINUX_TAR)
	tar xf $(LINUX_TAR)
	touch $@

build:
	mkdir -p $@

build/vmlinuz: build/$(LINUX)/.config | build
	$(MAKE) \
		KBUILD_HOST=safeboot \
		KBUILD_BUILD_USER=builder \
		KBUILD_BUILD_TIMESTAMP="$(GIT_HASH)" \
		KBUILD_BUILD_VERSION="$(GIT_DIRTY)" \
		-C $(dir $<)
	cp $(dir $<)/arch/x86/boot/bzImage $@

build/$(LINUX)/.config: initramfs/linux.config | $(LINUX)
	mkdir -p $(dir $@)
	cp $< $@
	$(MAKE) \
		-C $(LINUX) \
		O=$(PWD)/$(dir $@) \
		olddefconfig

linux-menuconfig: build/$(LINUX)/.config
	$(MAKE) -j1 -C $(dir $<) menuconfig savedefconfig
	cp $(dir $<)defconfig initramfs/linux.config

#
# Extra package building requirements
#
requirements: | build
	DEBIAN_FRONTEND=noninteractive \
	apt install -y \
		devscripts \
		debhelper \
		libqrencode-dev \
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
		shellcheck \
		curl \
		libjson-c-dev \
		libcurl4-openssl-dev \
		expect \
		socat \
		libseccomp-dev \
		seccomp \
		gnutls-bin \
		libgnutls28-dev \
		libtasn1-6-dev \
		ncurses-dev \
		qemu-utils \
		qemu-system-x86 \
		gnupg2 \
		flex \
		bison \
		libelf-dev \
		libjson-glib-dev \


# Remove the temporary files and build stuff
clean:
	rm -rf bin $(SUBMODULES) build
	mkdir $(SUBMODULES)
	#git submodule update --init --recursive --recommend-shallow 

# Regenerate the source file
tar: clean
	tar zcvf ../safeboot_$(VERSION).orig.tar.gz \
		--exclude .git \
		--exclude debian \
		.

package: tar
	debuild -uc -us
	cp ../safeboot_$(VERSION)_amd64.deb safeboot-unstable.deb


# Run shellcheck on the scripts
shellcheck:
	for file in \
		sbin/safeboot* \
		sbin/tpm2-attest \
		sbin/tpm2-send \
		sbin/tpm2-recv \
		sbin/tpm2-policy \
		initramfs/*/* \
		tests/test-enroll.sh \
	; do \
		shellcheck $$file functions.sh ; \
	done

# Fetch several of the TPM certs and make them usable
# by the openssl verify tool.
# CAB file from Microsoft has all the TPM certs in DER
# format.  openssl x509 -inform DER -in file.crt -out file.pem
# https://docs.microsoft.com/en-us/windows-server/security/guarded-fabric-shielded-vm/guarded-fabric-install-trusted-tpm-root-certificates
# However, the STM certs in the cab are corrupted? so fetch them
# separately
update-certs:
	#./refresh-certs
	c_rehash certs

# Fake an overlay mount to replace files in /etc/safeboot with these
fake-mount:
	mount --bind `pwd`/safeboot.conf /etc/safeboot/safeboot.conf
	mount --bind `pwd`/functions.sh /etc/safeboot/functions.sh
	mount --bind `pwd`/sbin/safeboot /sbin/safeboot
	mount --bind `pwd`/sbin/safeboot-tpm-unseal /sbin/safeboot-tpm-unseal
	mount --bind `pwd`/sbin/tpm2-attest /sbin/tpm2-attest
	mount --bind `pwd`/initramfs/scripts/safeboot-bootmode /etc/initramfs-tools/scripts/init-top/safeboot-bootmode
fake-unmount:
	mount | awk '/safeboot/ { print $$3 }' | xargs umount


#
# Build a safeboot initrd.cpio
#
build/initrd/gitstatus: initramfs/files.txt bin/busybox bin/tpm2 initramfs/init
	rm -rf "$(dir $@)"
	mkdir -p "$(dir $@)"
	./sbin/populate "$(dir $@)" "$<"
	git status -s > "$@"

-include build/initrd.deps

build/initrd.cpio: build/initrd/gitstatus
	( cd $(dir $<) ; \
		find . -print0 \
		| cpio \
			-0 \
			-o \
			-H newc \
	) \
	| ./sbin/cpio-clean \
		initramfs/dev.cpio \
		- \
	> $@
	sha256sum $@

build/initrd.cpio.xz: build/initrd.cpio
	xz \
		--check=crc32 \
		--lzma2=dict=1MiB \
		--threads 0 \
		< "$<" \
		> "$@.tmp"
	#| dd bs=512 conv=sync status=none > "$@.tmp"
	@if ! cmp --quiet "$@.tmp" "$@" ; then \
		mv "$@.tmp" "$@" ; \
	else \
		echo "$@: unchanged" ; \
		rm "$@.tmp" ; \
	fi
	sha256sum $@

build/initrd.cpio.bz: build/initrd.cpio
	bzip2 -z \
		< "$<" \
	| dd bs=512 conv=sync status=none > "$@.tmp"
	@if ! cmp --quiet "$@.tmp" "$@" ; then \
		mv "$@.tmp" "$@" ; \
	else \
		echo "$@: unchanged" ; \
		rm "$@.tmp" ; \
	fi
	sha256sum $@


build/signing.key: | build
	openssl req \
		-new \
		-x509 \
		-newkey "rsa:2048" \
		-nodes \
		-subj "/CN=safeboot.dev/" \
		-outform "PEM" \
		-keyout "$@" \
		-out "$(basename $@).crt" \
		-days "3650" \
		-sha256 \


BOOTX64=build/boot/EFI/BOOT/BOOTX64.EFI
$(BOOTX64): build/vmlinuz initramfs/cmdline.txt bin/sbsign.safeboot build/signing.key build/initrd.cpio.xz
	mkdir -p "$(dir $@)"
	DIR=. \
	./sbin/safeboot unify-kernel \
		$@.tmp \
		linux=build/vmlinuz \
		initrd=build/initrd.cpio.xz \
		cmdline=initramfs/cmdline.txt \

	./bin/sbsign.safeboot \
		--output "$@" \
		--key build/signing.key \
		--cert build/signing.crt \
		"$@.tmp" # build/vmlinuz

	@-$(RM) $@.tmp
	sha256sum "$@"

build/boot/PK.auth: signing.crt
	mkdir -p $(dir $@)
	-./sbin/safeboot uefi-sign-keys
	cp signing.crt PK.auth KEK.auth db.auth "$(dir $@)"

build/esp.bin: $(BOOTX64) build/boot/PK.auth
	./sbin/mkfat "$@" build/boot

build/hda.bin: build/esp.bin build/luks.bin
	./sbin/mkgpt "$@" $^

build/key.bin: | build
	echo -n "abcd1234" > "$@"

build/luks.bin: build/key.bin
	fallocate -l 512M "$@.tmp"
	cryptsetup \
		-y luksFormat \
		--pbkdf pbkdf2 \
		"$@.tmp" \
		"build/key.bin"
	cryptsetup luksOpen \
		--key-file "build/key.bin" \
		"$@.tmp" \
		test-luks
	#mkfs.ext4 /dev/mapper/test-luks
	cat root.squashfs > /dev/mapper/test-luks
	cryptsetup luksClose test-luks
	mv "$@.tmp" "$@"

TPMDIR=build/vtpm
TPMSTATE=$(TPMDIR)/tpm2-00.permall
TPMSOCK=$(TPMDIR)/sock
TPM_PID=$(TPMDIR)/swtpm.pid

$(TPM_PID): | $(SWTPM)
	mkdir -p "$(TPMDIR)"
	PATH=$(dir $(SWTPM)):$(PATH) \
	$(SWTPM) socket \
		--tpm2 \
		--flags startup-clear \
		--tpmstate dir="$(TPMDIR)" \
		--pid file="$(TPM_PID).tmp" \
		--server type=tcp,port=9998 \
		--ctrl type=tcp,port=9999 \
		&
	sleep 1
	mv $(TPM_PID).tmp $(TPM_PID)


# Setup a new TPM and
$(TPMDIR)/.created: | $(SWTPM)
	mkdir -p "$(TPMDIR)"
	PATH=$(dir $(SWTPM)):$(PATH) \
	$(dir $(SWTPM))/../swtpm_setup/swtpm_setup \
		--tpm2 \
		--createek \
		--display \
		--tpmstate "$(TPMDIR)" \
		--config /dev/null
	touch $@

# Extract the EK from a tpm state; wish swtpm_setup had a way
# to do this instead of requiring this many hoops
$(TPMDIR)/ek.pub: $(TPMDIR)/.created | bin/tpm2 build
	$(MAKE) $(TPM_PID)
	TPM2TOOLS_TCTI=swtpm:host=localhost,port=9998 \
	LD_LIBRARY_PATH=./tpm2-tss/src/tss2-tcti/.libs/ \
	./bin/tpm2 \
		createek \
		-c $(TPMDIR)/ek.ctx \
		-u $@

	kill `cat "$(TPM_PID)"`
	@-$(RM) "$(TPM_PID)"

tpm-shell: | bin/tpm2 $(SWTPM)
	$(MAKE) $(TPM_PID)
	-TPM2TOOLS_TCTI=swtpm:host=localhost,port=9998 \
	LD_LIBRARY_PATH=$(TOP)/build/tpm2-tss/src/tss2-tcti/.libs/ \
	PATH=`pwd`/bin:`pwd`/sbin:$(PATH) \
	bash

	-kill `cat "$(TPM_PID)"`
	@-$(RM) "$(TPM_PID)"


# Register the virtual TPM in the attestation server logs with the
# expected value for the kernel that will be booted

$(TPMDIR)/.ekpub.registered: $(TPMDIR)/ek.pub | bin/tpm2
	./sbin/attest-enroll safeboot-demo < $<
	touch $@

# QEMU tries to boot from the DVD and HD before finally booting from the
# network, so there are attempts to call different boot options and then
# returns from them when they fail.
PCR_CALL_BOOT:=3d6772b4f84ed47595d72a2c4c5ffd15f5bb72c7507fe26f2aaee2c69d5633ba
PCR_SEPARATOR:=df3f619804a92fdb4057192dc43dd748ea778adc52bc498ce80524c014b81119
PCR_RETURNING:=7044f06303e54fa96c3fcd1a0f11047c03d209074470b1fd60460c9f007e28a6

$(TPMDIR)/.bootx64.registered: $(BOOTX64) $(TPMDIR)/.ekpub.registered | ./bin/sbsign.safeboot
	./sbin/attest-verify \
		predictpcr \
		$(TPMDIR)/ek.pub \
		4 \
		$(PCR_CALL_BOOT) \
		$(PCR_SEPARATOR) \
		$(PCR_RETURNING) \
		$(PCR_CALL_BOOT) \
		$(PCR_RETURNING) \
		$(PCR_CALL_BOOT) \
		`./bin/sbsign.safeboot --hash-only $(BOOTX64)`
	touch $@

# uefi firmware from https://packages.debian.org/buster-backports/all/ovmf/download
qemu: build/hda.bin $(TPM_PID) $(TPMSTATE)


	#cp /usr/share/OVMF/OVMF_VARS.fd build

	-qemu-system-x86_64 \
		-M q35,accel=kvm \
		-m 4G \
		-drive if=pflash,format=raw,readonly,file=/usr/share/OVMF/OVMF_CODE.fd \
		-drive if=pflash,format=raw,file=build/OVMF_VARS.fd \
		-serial stdio \
		-netdev user,id=eth0 \
		-device e1000,netdev=eth0 \
		-chardev socket,id=chrtpm,path="$(TPMSOCK)" \
		-tpmdev emulator,id=tpm0,chardev=chrtpm \
		-device tpm-tis,tpmdev=tpm0 \
		-drive "file=$<,format=raw" \
		-boot c \

	stty sane
	-kill `cat $(TPM_PID)`
	@-$(RM) "$(TPM_PID)"

server-hda.bin:
	qemu-img create -f qcow2 $@ 4G
build/OVMF_VARS.fd: | build
	cp /usr/share/OVMF/OVMF_VARS.fd $@

UBUNTU_REPO = https://cloud-images.ubuntu.com/focal/current
ROOTFS = focal-server-cloudimg-amd64.img
ROOTFS_TAR = $(basename $(ROOTFS)).tar.gz
$(ROOTFS_TAR):
	wget -O $(ROOTFS_TAR).tmp $(UBUNTU_REPO)/$(ROOTFS_TAR)
	wget -O $(ROOTFS_TAR).sha256 $(UBUNTU_REPO)/SHA256SUMS
	awk '/$(ROOTFS_TAR)/ { print $$1, $$2".tmp" }' < $(ROOTFS_TAR).sha256 \
	| sha256sum -c
	mv $(ROOTFS_TAR).tmp $(ROOTFS_TAR)

$(ROOTFS): $(ROOTFS_TAR)
	tar xvf $(ROOTFS_TAR) $(ROOTFS)
	touch $(ROOTFS) # force timestamp

initramfs/response/img.hash: $(ROOTFS)
	sha256sum - < $< | tee $@

attest-server: $(ROOTFS) register
	# start the attestation server with the paths
	# to find the local copies for the verification tools
	PATH=./bin:./sbin:$(PATH) DIR=. \
	./sbin/attest-server 8080

register: $(TPMDIR)/.ekpub.registered $(TPMDIR)/.bootx64.registered

qemu-server: \
		server-hda.bin \
		build/OVMF_VARS.fd \
		$(BOOTX64) \
		register \
		| $(SWTPM)

	# start the TPM simulator
	-$(RM) "$(TPMSOCK)"
	$(SWTPM) socket \
		--tpm2 \
		--tpmstate dir="$(TPMDIR)" \
		--pid file="$(TPM_PID)" \
		--ctrl type=unixio,path="$(TPMSOCK)" \
		&

	sleep 1

	-qemu-system-x86_64 \
		-M q35,accel=kvm \
		-m 1G \
		-drive if=pflash,format=raw,readonly,file=/usr/share/OVMF/OVMF_CODE.fd \
		-drive if=pflash,format=raw,file=build/OVMF_VARS.fd \
		-serial stdio \
		-netdev user,id=eth0,tftp=.,bootfile=$(BOOTX64) \
		-device e1000,netdev=eth0 \
		-chardev socket,id=chrtpm,path="$(TPMSOCK)" \
		-tpmdev emulator,id=tpm0,chardev=chrtpm \
		-device tpm-tis,tpmdev=tpm0 \
		-drive "file=$<,format=qcow2" \
		-boot n \

	stty sane
	-kill `cat $(TPM_PID)`
	@-$(RM) "$(TPM_PID)" "$(TPMSOCK)"


