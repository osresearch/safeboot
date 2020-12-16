
# Safe Boot subcommands

Usage: `safeboot subcommand [options...]`


## key-init
Usage:
```
safeboot key-init "subject"
```

Generate a new x509 signing key with openssl, writing storing
the public key in `/etc/safeboot/cert.pem` and the password
protected private key in `/etc/safeboot/signing.key`.
This is not as secure as storing it in a hardware token,
although if the key is moved to an external device and the
`$KEY` variable in `/etc/safeboot/local.conf` updated to point
to it, then it will prevent a software-only attack.

The subject must be written as a "distinguished name":
```
       /CN=host.example.com/OU=test/O=example.com/
```

## yubikey-init
Usage:
```
safeboot yubikey-init "subject"
```

Generate a new x509 signing key on an attached Yubikey device
and set the certificate subject to the provided argument.
The public key certificate will be written to `/etc/safeboot/cert.pem`
and will also be used for the UEFI SecureBoot variables.

Due to a limitation in the OpenSSL PKCS11 engine, you have to enter
the password multiple times (once for the engine, and then once for
the signature).

The subject must be written as a "distinguished name":
```
       /CN=host.example.com/OU=test/O=example.com/
```

## yubikey-pubkey
Usage:
```
safeboot yubikey-pubkey cert.pem
```

Extract the public key certificate in PEM, DER and PUB format.
The `sbsign` tool wants PEM, the `kmodsign` tool wants DER,
the `tpm2-tools` wants a raw public key.
The best part about standards...

## uefi-sign-keys
Usage:
```
safeboot uefi-sign-keys
```

Create three signed certificates for the PK, KEK, and db using
the attached Yubikey or x509 key stored in `/etc/safeboot/signing.key`
and store them in the UEFI SecureBoot configuration.  You should
have run `safeboot yubikey-init` or `safeboot key-init` to have
already generated the keys.

Due to an issue with the OpenSSL PKCS11 engine, you will have to authenticate
to the Yubikey multiple times during this process.

## uefi-set-keys
Usage:
```
safeboot uefi-set-keys
```

Store the PK, KEK, and db into the UEFI Secure Boot configuration
variables.  This must be done once during system setup or if a new
key is generated.  The `uefi-sign-key` subcommand attempts to do
this automatically.

## pcrs-sign
Usage:
safeboot pcrs-sign [prevent-rollback] [path-to-unified-kernel]

Generate a signature for the PCRs that can be used to unseal the LUKS key
according to the policy created by `safeboot luks-seal`.  The PCRs used
are specified in the `/etc/safeboot/safeboot.conf` or `local.conf` files, and
must match the values that were configured during `luks-seal`.

If the prevent-rollback argument is `prevent-rollback`, the TPM version counter
will be incremented, which will invalidate all previous PCR signatures and prevent
the older unified kernel images from being able to unseal the PCR data.

The signature is persisted in a UEFI NVRAM variable, defined in `safeboot.conf`.

## luks-seal
Usage:
```
safeboot luks-seal
```

This will generate a new LUKS encryption key for the block device in
`/etc/crypttab` and requires an existing recovery key to install the
new key slot.  You will also be prompted for an unlock PIN, which will
be required on the next normal boot in place of the recovery code.

If this is the first time the disk has been sealed, `/etc/crypttab`
will be updated to include a call to the unsealing script to retrieve
the keys from the TPM, and a counter will be created to prevent rollbacks.

After sealing the secret, the initrd will be rebuild, the kernel signed,
and the new predicted PCRs signed.  Any previous sealed data will be
invalidated since the version counter will be incremented.

Right now only a single crypt disk is supported.


## unify-kernel
Usage:
```
safeboot unify-kernel linux.efi kernel=path-to-kernel initrd=path-to-initrd ...
```

Creates a unified kernel image with the named sections and files
(typically `kernel`, `initrd`, `cmdline`, and `osrel`) bundled into
an EFI executable.

This is the raw command; you might want to use `safeboot linux-sign` or
`safeboot recovery-sign` instead to add the EFI boot manager entry.

## sign-kernel
Usage:
```
safeboot sign-kernel linux.efi [linux.signed.efi]
```

Sign a unified EFI executable with the safeboot keys.  If no destination
is specified it will be the same name as the input kernel with `.signed.efi`
added.

This is the raw command; you might want to use `safeboot linux-sign` or
`safeboot recovery-sign` instead to add the EFI boot manager entry.

## install-kernel
Usage:
```
safeboot install-kernel boot-name [extra kernel parameters...]
```

Create an EFI boot menu entry for `boot-name`, with the specified
kernel, initrd and command line bundled into an executable and signed.
This command requires the Yubikey or x509 password to be able to sign
the merged EFI executable.

This is the raw command; you might want to use `safeboot linux-sign` or
`safeboot recovery-sign` instead.

## linux-sign
Usage:
```
safeboot linux-sign [target-name [parameters...]]
```

Generate dm-verity hashes and then sign the Linux with the root hash added
to the kernel command line.  The default target for the EFI boot manager is
`linux`.  You will need the Yubikey or x509 password to sign the new hashes
and kernel.

If the environment variable `$HASH` is set to the hash value, or if
the `$HASHFILE` variable points to the previous dmverity log (typically
`/boot/efi/EFI/linux/verity.log`), then the precomputed value will be used
instead of recomputing the dmverity hashes (which can take some time).
If the hashes are out-of-date, this might render the `linux` target
unbootable and require a recovery reboot to re-hash the root filesystem.

## recovery-sign
Usage:
```
safeboot recovery-sign [kernel command line...]
```

Sign the Linux kernel and initrd into the EFI boot manager
`recovery` entry.  Typically this only needs to be done once
and after validating that the system can boot with it, you
should not have to re-run this command.

You will need the Yubikey or x509 password as well as root
accesss to perform this action.

If SIP is enabled the root device will be marked read-only
for the reboot and fscked will not been run on boot.

Use `safeboot remount` to remount `/` as read-write when
in recovery mode, and then `safeboot remount ro` to restore
it to read-only mode before signing the hashes.

## recovery-reboot
Usage:
```
safeboot recovery-reboot
```

Configure the EFI boot manager so that the `BootNext` is the recovery
target and reboot the machine.  This command requires root access to
update the EFI variables and will also require the disk encryption
recovery key since the TPM will not unseal the disk automatically for
recovery mode.

**NOTE!** This will reboot the machine!

## bootnext
Usage:
```
safeboot bootnext Setup
```

Configure the EFI boot manager `BootNext` variable to select an
alternate boot menu item.  This command requires root access to
update the EFI variables.

## remount
Usage:
```
safeboot remount [ro]
```

Attempt to remount the root filesystem read/write or read-only.
If SIP is enabled this will likely invalidate any hashes
and require a re-signing of the root filesystem.

If `ro` is specified, then the file system will be re-mounted read-only
If there are processes blocking the remount, they will be listed.

## sip-init
Usage:
```
safeboot sip-init [home-size-in-GB [var-size]]
```

**DANGER!** This command can mess up your root filesystem.
There must be space in the volume group for the new entries
It will create the volume groups for `/var` and `/home`,
add entries to `/etc/fstab` for them with secure mount parameters,
and makes `/tmp` a symlink into `/var/tmp`.

## unlock
Usage:
```
safeboot unlock
```

This is a recovery shell command to scan the `/etc/crypttab` for devices
and call `cryptsetup luksOpen` on each of them, and then scan the LVM groups
for volumes.  After it succeeds you can call `safeboot mount` to mount
the root filesystem (read-only) on `/root`.

## mount-all
Usage:
```
safeboot mount-all
```

This is a recovery shell command to attempt to mount the root disk read-only
on `/root`, as well as the `/boot` and `/boot/efi` if they exist in
`/root/etc/fstab`.

