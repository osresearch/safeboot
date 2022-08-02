#!/bin/bash

check() {
    which tpm2  >/dev/null 2>&1 || return 1
}


#depends() {
#}


install() {
    # Get Safeboot variables
    local DIR=/etc/safeboot
    [ -f "$dracutsysrootdir"$DIR/safeboot.conf ] && . "$dracutsysrootdir"$DIR/safeboot.conf || :
    [ -f "$dracutsysrootdir"$DIR/local.conf ] && . "$dracutsysrootdir"$DIR/local.conf || :

    inst_script "$moddir"/qubes-safeboot-unseal /sbin/qubes-safeboot-unseal
    inst_simple "$dracutsysrootdir"$DIR/safeboot.conf $DIR/safeboot.conf
    inst_simple "$dracutsysrootdir"$DIR/local.conf $DIR/local.conf
    inst_simple "$dracutsysrootdir"${CERT/.pem/.pub} ${CERT/.pem/.pub}
    inst_simple "$dracutsysrootdir"/usr/lib/safeboot/functions.sh $DIR/functions.sh

    inst $systemdsystemunitdir/cryptsetup-pre.target

    dracut_install \
	cat \
	cut \
	chmod \
	chattr \
	mount \
	pidof \
        sha256sum \
        tail \
	time \
	touch \
        tpm2 \
        umount \
        xxd

    inst_libdir_file "libtss2-tcti-device.so*"

    dracut_install \
        $systemdsystemunitdir/qubes-safeboot-unseal.service \
        $systemdsystemunitdir/initrd.target.wants/qubes-safeboot-unseal.service 
}
