
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
safeboot yubikey-pubkey cert.pem [cert.crt]
```

Extract the public key certificate in either PEM or DER format.
The `sbsign` tool wants PEM, the `kmodsign` tool wants DER.
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

## luks-seal
Usage:
```
safeboot luks-seal [0,2,5,7... [14]]
```

Generate a new LUKS encryption key for the block devices in `/etc/crypttab`,
sealed with the optional comma separated list of TPM PCRs. During the boot,
PCR 14 will be first extended with the `tpm.mode` kernel command line parameter
(typically `linux` or `recovery`) and then the secret unsealed.  After
an unsealing attempt, the PCR14 will be extended again with `postboot` status
to prevent the key from being unsealed after the initramfs has run.

If this is the first time the disk has been sealed, `/etc/crypttab`
will be updated to include a call to the unsealing script to retrieve
the keys from the TPM.  You will have to run `sudo update-initramfs -u`
to rebuild the initrd.

Right now only a single crypt disk is supported.

## sign-kernel
Usage:
```
safeboot sign-kernel boot-name [extra kernel parameters...]
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

