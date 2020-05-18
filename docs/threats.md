# safeboot threat model

![Your threat model is not my threat model, but your threat model is ok](https://live.staticflickr.com/5575/31437292510_99ffd0dd11_b.jpg)

`safeboot` intends to protect the integrity of the boot process and
runtime integrity of the system against adversaries with external physical
access to the device, as well as limited internal physical access.
The assumption is that the attacker can get code execution on the device
as the user and as root, but does not have access to the signing keys or
the disk encryption key.  The goal is to prevent the attacker from exfiltrating
data from the device or making persistent changes to the system configuration.


## Protections

The protections that are applied by the `/usr/sbin/safeboot` script and
setup instructions include:

### Firmware

* Enabling UEFI Secure Boot, Supervisor password, Tamper Switches, etc
* Generating a signing key in a hardware token
* Installing the signing key as the UEFI Secure Boot Platform Key (`PK`)
* Removing OEM and Microsoft keys from the UEFI Secure Boot key database ('db')
* Signing the kernel, initrd and command line with the hardware key

### Booting
* LUKS block device encryption on `/`, `/home`, `/var` and swap.
* TPM Sealing the disk encryption key with the UEFI firmware and configuration values
* If unsealing fails, attesting to the firmware state with TOTP
* Storing the unsealed key in a kernel keyring and logging 
* Enabling `intel_iommu=on` and `efi=disable_early_pci_dma` to eliminate some hardware attacks

### Runtime
* Enabling `lockdown=confidentiality` mode to prevent root from accessing keyrings or memory
* Mounting the root filesystem read-only and marking the block device read-only
* Enabling dmverity hash checking on the root filesystem ("SIP" mode)
* Mounting `/tmp`, `/home` and `/var` with `nosuid,nodev`
* Removing Canonical's module signing key
* Adding `usb-storage` and other external media to the kernel module deny list

### Todo
* TODO: VPN config
* TODO: Prevent network reconfiguration
* TODO: Device VM separation
* TODO: Separate `/home` encryption
* TODO: TPM pin requirement
* TODO: TPM counter for rollback protection
* TODO: Multiparty signatures for higher assurance

The behaviour of things like the tamper switches and supervisor password
are as observed on the Lenovo X1 firmware (and some were fixed after
reporting vulnerabilities to Lenovo); other devices may vary and have
less secure behaviour.

## Atacks

These changes protect against many local physical and software attacks.

### Physical hardware attacks

A local attacker with physical access to the device can open the device to gain
access to the drive, the SPI flash on the mainboard, the Management Engine and CPU chipset,
the discrete TPM device, the RAM chips, PCIe buses (such as m.2 slots), etc.

* Opening the case to modify the flash or modify devices will trip the case tamper
switch and prevent the device from booting until the firmware supervisor password
is entered.  This detects several classes of "evil maid" attacks that require
physical access.

* Removing the disk to attempt to rewrite it or image it for offline
attacks will trigger both the case tamper switch and the disk tamper
switch.  The firmware supervisor password is required to reboot, which
will allow the user or administrator to detect that the device has been
compromised.

* On Lenovo's recent firmware, the supervisor password is not stored
in the SPI flash, but in the EC, and changing it requires the EC to
validate the change. This prevents a local attacker from modifying
the NVRAM variabels in the SPI flash to bypass the supervisor checks.
However, the EC is an open field of security research.

* On Lenovo's recent firmware, the tamper switch state is stored in the EC,
rather than the RTC RAM.  This makes it more difficult to bypass the
tamper switches since an EC or Bootguard attack is necessary.

* Exploits against the ME are unlikely to be detectable, although they require a
level of expertise to pull off and do not provide persistence.  A local attacker
could use this to bypass Bootguard and other TPM provided protections.  If they also
know the TPM PIN and `/home` encryption password, they can exfiltrate data, but
are unlikely to be able to gain persistence without the attack device in place
due to the signed dmverity hashes.

* Changing the firmware in the SPI flash *should* be detected by Intel Bootguard's
verification of the IBB during boot up and result in the device not booting.
There are public TOCTOU attacks against Bootguard, so a local attacker can bypass
the measured root of trust to boot their unsigned firmware and kernel.
As with the ME attacks, if the TPM PIN and `/home` encryption key are known then
data can be exfiltrated, but this does not provide persistence.

* Writing new platform keys in the SPI flash will result in a TPM unsealing failure
since the UEFI secure boot configuration is part of the measured state included in
the TPM PCRs.

* An attack that presents a fake recovery key input dialog can be detected
by the `tpm2-totp` tool. The TPM2 will only generate the 30-second,
6-digit authentication code if the PCRs match the expected value
and the administrator can verify it against their authenticator app.
With TPM2, the HMAC is computed in the TPM itself, so the secret is never
accessible to the operating system.

* TPM tampering on the LPC bus is not necessarily detectable by this system;
an adversary with unlimited internal physical access can also probe sealed secrets.
If a TPM PIN is used then the secrets might be brute-forcable, but would require
much longer internal access.

* fTPM tampering is out of scope since the ME is the root of all trust in the system
An adversary with code execution on the ME is able to bypass all of the other
protections.

### Physical software attacks

* Modifying the unencrypted kernel or initrd on `/boot` or attempting to pass in
unapproved kernel command line parameters is prevented by the
UEFI Secure Boot signature checks.  The firmware will not hand control of the system
to an unsigned EFI executable, which in this case is the entire kernel, initrd, and
command line.  This prevents both physical rewriting the disk in another machine,
as well as if an attacker escallates to root and remounts `/boot` as read-write.

* The boot order NVRAM variable could be modified by an attacker with access to the
SPI flash or if they have escallated to root.  However, booting from an
external device still requires an EFI executable signed by the PK/KEK/db, so
only approved images can be booted.

* Adversaries might try to gain persistence or weaken security by gaining
write access to the unencrypted `/boot` partition and changing the kernel images.
This requires either a root escalation or a tamper switch bypass,
but the firmware will deny them peristence by refusing to boot from
the modified image since the signature is checked when they are loaded
into RAM at boot.  There should not be any runtime TOCTOU since the DRAM has
been initialized and there is space to store the entire image prior to
validating the signature.

* Adversaries might try to gain persistence by gaining write access to the
encrypted and dmverity protected `/` filesystem, which requires a
kernel escalation since dmverity prohibits writes to the protected block device,
or a tamper switch bypass in addition to possession of the TPM disk unsealing keys.
However, even with write access, the adversary can not gain persistence since
the signed kernel command line and signed initrd enable dmverity hash checking,
which will detect any modifications to `/`.  They would also need access to the
signing keys to be able to produce a new valid root hash.

* An adversary might try to gain run time access to the disk encryption key.
The PCRs are extended with the booted state so that the TPM will no longer unseal
it after the initrd, and root is prevented from reading the key from the Linux kernel
keyring, so a kernel escallation is required to gain access to it.
TODO: qubes style separate VM for disk and user?

* Some of the ports on the device, such as Thunderbolt and PCIe, have the ability to
DMA in and out of main memory, which would allow a local attacker to connect
a device that reads secrets out of unencrypted memory.
The safeboot kernel commandline parameter configuration turns on the Intel IOMMU
by default, as well as turns off PCIe bus-mastering, both of which should protect
against attacks like Thunderspy as well as some classes of malicious devices
on the Thunderbolt port or internal Mini-PCIe ports.

### Software attacks

* An adversary with root access might try a runtime escalation into the
kernel by loading a custom module with a backdoor, or they might try to
exfiltrate data by loading the `usb-storage` module to mount a removable
disk, or they might `kexec` into an untrusted kernel.  The safeboot
kernel is configured to only load modules or `kexec` files signed with
the hardware protected key, and the default Canonical key is removed so
that only approved modules can be loaded.

* Another root to kernel escalation is by directly poking at kernel memory
in `/dev/mem`.  The Linux Lockdown patches [are turned on by UEFI Secure Boot mode](https://mjg59.dreamwidth.org/50577.html),
although safeboot goes to the next step and [switches to Confidentiality mode](https://mjg59.dreamwidth.org/55105.html),
which prevent all raw memory accesses from user space.  An additional
escalation is required to turn off lockdown.  TODO: ensure that the
magic sysctl isn't allowed to do it.

* An attacker might try to escalate to root by somehow creating device files or
mounting filesystems with SUID binaries.  The `/etc/fstab` entries for `/home`
and `/var` are configured to not allow such executables.

### Todo

* TODO: rollback attacks; how to use TPM counters to prevent them

* TODO: Document rebuilding the kernel

* TODO: configure allow/deny lists to clean up the module directories.

* TODO: Prevent network reconfiguration that bypasses mandatory VPN.

* TODO: SELinux config

* TODO: qubes/secureview separation

* TODO: /home encryption

* TODO: TPM PIN

* TODO: tpm-totp
