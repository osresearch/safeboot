![Linux on a classic Butterfly Thinkpad](images/installation-header.jpg)

# Safe Boot: Booting Linux Safely

## Goals

Safe Boot has four goals to improve the safety of booting Linux
on normal laptops:

* **Booting only code that is authorized by the system owner** (by installing a hardware protected platform key for the kernel and initrd)
* **Streamlining the encrypted disk boot process** (by storing keys in the TPM, and only unsealing them if the firmware and configuration is unmodified)
* **Reducing the attack surface** (by enabling Linux kernel features to enable hardware protection features and to de-priviledge the root account)
* **Protecting the runtime system integrity** (by optionaly booting from a read-only root with dm-verity and signed root hash)

## Why safeboot?

The [slightly more secure Heads firmware](http://osresearch.net)
is a better choice for user freedom since it replaces the proprietary firmware
with open source.  However, Heads and [LinuxBoot](https://linuxboot.org)
only support a limited number of mainboards and systems, while safeboot's
objective is to work with existing commodity hardware and UEFI SecureBoot
mechanisms, as well as relatively stock Linux distributions.

The problem is that configuring all of the pieces for UEFI Secure Boot,
generating keys in hardware tokens, signing kernels, and integrating
LUKS disk encryption with the TPM is very complex.  There are numerous
guides that walk through individual pieces of this process, but most
of them are very fine-grained and require far too many steps to
complete.

End users need a tool that wraps up all of the complexity into the few
operations that they need from day to day: signing new kernels,
decrypting their disks at boot, protecting the system from runtime
attackers, etc. `safeboot` is that tool!

## Links

* [Installation Instructions](install.md)
* [Frequently Asked Questions](faq.md)
* [Source](https://github.com/osresesearch/safeboot)

