![Linux on a classic Butterfly Thinkpad](images/installation-header.jpg)

# Safe Boot: Booting Linux Safely

Safe Boot has four goals:

* **Booting only code that is authorized by the system owner** (by installing a hardware protected platform key for the kernel and initrd)
* **Streamlining the encrypted disk boot process** (by storing keys in the TPM, and only unsealing them if the firmware and configuration is unmodified)
* **Reducing the attack surface** (by enabling Linux kernel features to enable hardware protection features and to de-priviledge the root account)
* **Protecting the runtime system integrity** (by optionaly booting from a read-only root with dm-verity and signed root hash)

The [slightly more secure Heads firmware](http://osresearch.net)
is a better choice for user freedom since it replaces the proprietary firmware
with open source.  However, Heads and [LinuxBoot](https://linuxboot.org)
only support a limited number of mainboards and systems, while safeboot's
objective is to work with existing commodity hardware and UEFI SecureBoot
mechanisms, as well as relatively stock Linux distributions.

* [Installation instructions](install.md)
* [FAQ](faq.md)

