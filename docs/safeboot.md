# `/usr/sbin/safeboot` subcommands

## key-init subject

  Generate a new x509 signing key with openssl.
  The subject must be written as:
       /CN=host.example.com/OU=test/O=example.com/


## yubikey-init subject

  Generate a new x509 signing key on an attached Yubikey device
  and set the certificate subject to the provided argument.

  The subject must be written as:
       /CN=host.example.com/OU=test/O=example.com/


## uefi-sign-keys

  Create three signed certificates for the PK, KEK, and db using
  the attached Yubikey and store them in the UEFI SecureBoot configuration.
  You will have to authenticate to the yubikey multiple times during this process.

## uefi-set-keys

  Store the PK, KEK, and db into the UEFI Secure Boot configuration
  variables.  This must be done once during system setup.


## luks-seal [0,2,5,7... 14]

  Generate a new LUKS encryption key for the block devices in /etc/crypttab,
  sealed with the optional comma separated list of TPM PCRs.  PCR 14 will be
  used to indicate a 'postboot' status to prevent the key from being unsealed
  after the initramfs has run.

  If this is the first time the disk has been sealed, /etc/crypttab
  will be updated to include a call to the unsealing script to retrieve
  the keys from the TPM.  You will have to run 'sudo update-initramfs -u'
  to rebuild the initrd.

  Right now only a single crypt disk is supported.

## sign-kernel 'boot-name' parameters...

  Create an EFI boot menu entry for 'boot-name', with the specified
  kernel, initrd and command line bundled into an executable and signed.
  This is the raw command; you might want to use hash-and-sign or
  recovery-sign instead.


## linux-sign [target [parameters...]]

  Generate dm-verity hashes and then sign the Linux with the root hash added
  to the kernel command line.

  If HASH is set in the environment, it will be used instead of recomputing
  the dmverity hashes (which can take some time).
  

## recovery-sign [kernel command line...]

  Sign the Linux kernel and initrd into the recovery target.
  If SIP is enabled the root device will be marked read-only and
  not-fsck'ed.  Use 'safeboot remount' to remount it read-write
  when in recovery mode.

## recovery-reboot

  Configure the next boot for a recovery and reboot the machine.
  

## remount

  Attempt to remount the root filesystem read/write.
  If SIP is enabled this will likely invalidate any hashes
  and require a re-signing of the root filesystem.
  

## sip-init home-size [var-size]

  DANGER! This command can mess up your root filesystem.
  There must be space in the volume group for the new entries
  Create the volume groups for /var and /home,
  adds entries to /etc/fstab for them, and makes /tmp a symlink
  into /var/tmp.

