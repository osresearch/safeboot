# Safer Boot

Safer Boot has three goals:
* Self-signed platform key for kernel and initrd, stored in a yubikey
* TPM protected disk encryption keys
* Optionally read-only root with dm-verity (and signed root hash)

Unlike the [slightly more secure Heads firmware](http://osresearch.net),
Safer Boot is trying to work with existing commodity hardware and UEFI
SecureBoot mechanisms, as well as relatively stock Ubuntu installations.

## Setup phase
This is done once when the system is being setup to use Safer Boot mode.
Note that the hardware token and key signing portions can be done offline
on a separate disconnected machine and then signed keys copied to the machine.

* Generate signing key in hardware token
* Store public certificate in UEFI platform key (`PK`), key-exchange key (`KEK`) and database (`db`)
* Add UEFI boot menu item for safer boot kernel
* Configure UEFI setup for safer operation
* Create a random disk encryption key, seal it into the TPM
* Add `initramfs` hooks to unseal key from TPM during boot

## Root filesystem update phase
* Remount `/` read-write
* Perform updates
* Remount `/` read-only
* Compute block hashes and root hash
* Add root hash to command line
* Sign kernel/initramfs/commandline

## Kernel and initramfs update phase
* Re-generate `/boot/initrd` and `/boot/vmlinuz`
* Merge the kernel, initrd and command line into a single EFI executable
* Use the hardware token to sign that executable
* Copy the signed image to the EFI boot partition

## UEFI firmware update
If there are any updates to the UEFI firmware, such as changing the
`Setup` variable, then the TPM sealed keys will no longer be accessible
and the recovery key will be necessary to re-seal the drive.

The assumption is that there is no TPM2 resource manager running,
either at runtime or in the initrd, so it is possible for the tools
to directly talk to the TPM2.

-----
This guide was written using Ubuntu 20.04 and `tpm2-tools` 4.1.1.
Unfortunately there has been churn in the names of the tools and
the command line options, so it does not work on 18.04.
All of the commands are run as `root`.

The `cryptdisk-seal` program will securely generate a random key
for encrypting the disk and add it to the LUKS key slot 1; the
normal installer uses key slot 0 for the manually entered key,
which will be left as a recovery key in case there is a TPM failure.
In order to add the new key, you will have to enter the existing
recovery key (set during initial install).

The random key will also be sealed into the TPM as a persistent object
using the current value of the important PCRs.

In order for the `initrd` to be able to unseal and decrypt the key,
it is necessary to also install a "hook" into the initramfs generation
routine.

TODO: Extend a PCR so that the key can not be unsealed again after boot.



Other helpful links:
* https://robertou.com/tpm2-sealed-luks-encryption-keys.html which uses a less standard TPM toolkit
* https://threat.tevora.com/secure-boot-tpm-2/ which is out of date on the tpm2 command line options
* https://github.com/timchen119/tpm2-initramfs-tool which stores the pass phrase in the TPM, rather than a separate key


Meaning for UEFI is defined in
[Microsoft's "`OSPlatformValidation_UEFI`" registry key](https://getadmx.com/?Category=MDOP&Policy=Microsoft.Policies.BitLockerManagement::PlatformValidation_UEFI_Name). By default Bitlocker uses 0, 2, 4, 8, 9, 10, 11.

* PCR 0: Core System Firmware executable code
* PCR 1: Core System Firmware data
* PCR 2: ROM Code (was Extended or pluggable executable code?)
* PCR 3: Extended or pluggable firmware data
* PCR 4: MBR Code (was Boot Manager?)
* PCR 5: GPT / Partition Table
* PCR 6: Resume from S4 and S5 Power State Events
* PCR 7: Secure Boot State
* PCR 8: NTFS Boot Secure (was Initialized to 0 with no Extends (reserved for future use)?)
* PCR 9: NTFS Boot Block (was Initialized to 0 with no Extends (reserved for future use)?)
* PCR 10: NTFS Boot Manager (was Initialized to 0 with no Extends (reserved for future use)?)
* PCR 11: BitLocker Access Control
* PCR 12: Data events and highly volatile events
* PCR 13: Boot Module Details
* PCR 14: Boot Authorities
* PCR 15-23: Reserved for future use

Install the tools on the running system:
```
apt install \
	tpm2-tools \
	tpm2-abrmd \
	efitools \
	gnu-efi \
	opensc \
	yubico-piv-tool \
	libengine-pkcs11-openssl \
	build-essential \
	git \
	autotools \
	binutils-dev \
	libssl-dev \
	uuid-dev \
	help2man \
```



```
yubico-piv-tool -s 9c -a generate -o pubkey.pem # will take a while and overwrite any existing private keys
yubico-piv-tool -s 9c -a verify-pin -a selfsign-certificate -S '/OU=test/O=example.com/' -i pubkey.pem -o cert.pem
yubico-piv-tool -s 9c -a import-certificate -i cert.pem
openssl x509 -outform der -in cert.pem -out cert.crt
openssl x509 -in cert.pem -text -noout # display the contents of the PEM file
```

To retrieve the cert later:
```
yubico-piv-tool -s 9c -a read-certificate -o cert.pem
```

----

Ubuntu 20.04 installation:
* "Try it", then 
* "Advanced" - "LVM encrypt"
* Install as normal, then 
* Then reduce the volume before rebooting:
```
sudo e2fsck -f /dev/vgubuntu/root
sudo resize2fs /dev/vgubuntu/root 32G
sudo lvreduce -L 32G /dev/vgubuntu/root
sudo lvcreate -L 80G home vgubuntu
```

* "Something else"
** sda1: EFI system partition
** sda2: /boot (ext4)
** sda3: encrypted partition (have to click back?)
** create partition table
** / -- 64 GB
** /var - 16 GB
** swap -- 16 GB
** /home -- the rest
* and this is broken in 20.04... trying via preseed

https://www.chucknemeth.com/linux/distribution/debian/debian-9-preseed-uefi-encrypted-lvm


efitools from source for `-e` engine support: https://git.kernel.org/pub/scm/linux/kernel/git/jejb/efitools.git

sbsign from source for yubikey support: https://github.com/osresearch/sbsigntools

yubikey setup for PK (and KEK, and DB)

reboot into uefi setup, configure bios for security:
* admin password
* thunderbolt, etc
* take ownership of TPM
* tamper detection
* secure boot - clear keys

reboot into linux

build linux kernel and initrd image
* tpm keys
* hook initramfs creation
* merge, sign and install into /boot
```
sudo efibootmgr  --create --disk /dev/sda --part 1 --label linux --loader '\EFI\linux\linux.efi'
```

build recovery USB
* sign kernel and initramfs

install secureboot keys
* sign pk update with key
```
cert-to-efi-sig-list -g `uuidgen` /boot/cert.pem cert.esl
sign-efi-sig-list -e pkcs11 -k 'pkcs11:' -c /boot/cert.pem PK cert.esl PK.auth
sign-efi-sig-list -e pkcs11 -k 'pkcs11:' -c /boot/cert.pem KEK cert.esl KEK.auth
sign-efi-sig-list -e pkcs11 -k 'pkcs11:' -c /boot/cert.pem db cert.esl db.auth
```
* install platform keys, kek and db, replacing the lenovo and microsoft ones (must be in this order; once PK is set the others will not be changed)
```
efi-updatevar -f db.auth  db
efi-updatevar -f KEK.auth  KEK
efi-updatevar -f PK.auth  PK
```

* for corporate deployment: install signed setup variable?

reboot
* boot order
* test usb 

other things to do:
* read-only root
* dm-verity
* separate /home
* turn off automatic filesystem mounting

kernel and initrd update process:
* run update-initram-fs
* run merging tools
* run signing tool
* needs the security token

disk re-keying:
* necessary if firmware setup variables change
* should not be required for kernel updates


