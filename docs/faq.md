# Frequently Asked Questions

## What is the threat model?
![Your threat model is not my threat model, but your threat model is ok](https://live.staticflickr.com/5575/31437292510_99ffd0dd11_b.jpg)

`safeboot` intends to protect the integrity of the boot process and
runtime integrity of the system against adversaries with external physical
access to the device, as well as limited internal physical access.

* Reprogramming the code in SPI flash is detected by Intel Bootguard's verification of the IBB during boot
* Writing new platform keys in the SPI flash is detected by measurement of the UEFI configuration into the TPM
* TPM tampering on the LPC bus is not necessarily detectable by this system; an adversary with unlimited internal physical access can also probe sealed secrets
(TODO: add TPM PIN for high assurance users)
* fTPM tampering is out of scope since the ME is the root of all trust in the system
* Booting from an unauthorized external device is prevented since only PK signed executables will be loaded.
* Adversaries with physical write access to the disk can't change the kernel or initrd on the drive since the signature is checked when they are loaded into RAM.
* Adversaries with write access to the root filesystem can't change any of the lockdown configuration since their modifications will be detectable by the dmverity hashes.  They can't recompute the hashes since the root is signed by the PK.
* Run time access to the disk encryption key is prevented by the Linux kernel keyring mechanism, even against an adversary with root access.
* The Linux lockdown patches in Confidentiality mode prevent a user with root access from loading new kernel modules, modifying the disk image, or poking at raw memory.
* The default kernel parameter turns on the IOMMU which should protect
against attacks like Thunderspy as well as some classes of malicious devices
on the Thunderbolt port or internal Mini-PCIe ports.
* TODO: prevent external media access, network reconfig, approved list of modules, unapproved modules, etc.

## How does `safeboot` compare to coreboot?

[coreboot](https://coreboot.org) is entirely free software and can
provide far better control of the boot process, although it is not supported
on as many modern platforms as UEFI SecureBoot.  If you have a machine
that supports both coreboot and Bootguard, then you're probably better off
running it instead.  Once coreboot or UEFI hand off to the Linux kernel,
the TPM unsealing of the disk encryption key, the dmverity protections
on the root filesystem and the lockdown patches work the same.

## Does `safeboot` work with AMD cpus?

It has only been tested on the Intel systems with Bootguard.
The UEFI platform keys and the rest of the lock down *should*
work with AMD, although AMD's hardware secured boot process hasn't
been reviewed as extensively as Intel's ME and Bootguard.

## Why does the TPM unsealing fail often?
![TPM with wires soldered to the pins](images/tpm.jpg)

It's super fragile right now.  Need to reconsider which PCRs are included
and what they mean.  Suggestions welcome!

## How do I write to the root filesystem?
With SIP enabled it is not possible to modify the root filesystem.
You must reboot into recovery mode with `safeboot recovery-reboot`
and decrypt the disk with the recovery password.  Once decrypted,
you can run `safeboot remount` to unlock the raw device and remount
it `rw`.  After making modifications, it is necessary to sign
the new root hashes with `safeboot linux-sign`.

## What happens if I lose the signing key?
The best solution is to authenticate with the supervisor password
to the UEFI Setup, re-enter SecureBoot setup mode and clear the key
database, then boot into recovery mode.

You can then re-run `safeboot yubikey-init` or `safeboot key-init`
and `safeboot uefi-sign-keys` to repopulate the database, and
`safeboot recovery-sign` as well as `safeboot linux-sign` to re-sign
the two kernel images, boot into the linux image and re-seal the LUKS
key into the TPM with `safeboot luks-seal`.

## Is it possible to reset the UEFI or BIOS password?
On modern Thinkpads the UEFI password is in the EC, not in the
SPI flash.  You need a Bootguard bypass to get into Setup in that
case; perhaps someone has some zerodays that will give them access...

## Does it work on the Thinkpad 701c?
![Butterfly keyboard animation](https://farm1.staticflickr.com/793/39371776450_a8b0cd4184_o_d.gif)

Unfortunately the wonderful [butterfly keyboard Thinkpad](https://trmm.net/Butterfly)
predates UEFI by a few years, so it does not have a very secure
boot process.  The X1 Carbon is a much nicer replacement.
