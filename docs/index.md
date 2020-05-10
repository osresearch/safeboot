# Safe Boot: Booting Linux Safely

Safe Boot has four goals:
* Booting only code that is authorized by the system owner (by installing a hardware protected platform key for the kernel and initrd)
* Streamlining the encrypted disk boot process (by storing keys in the TPM, and only unsealing them if the firmware and configuration is unmodified)
* Making it harder for an adversary to exfiltrate data (by enabling Linux kernel features to de-priviledge the root account)
* Protecting the runtime system integrity (by optionally enabling a read-only root with dm-verity and signed root hash)

The [slightly more secure Heads firmware](http://osresearch.net)
is a better choice for user freedom since it replaces the proprietary firmware
with open source, while Safe Boot's objective is to work with existing
commodity hardware and UEFI SecureBoot mechanisms, as well as relatively
stock Linux distributions.

* [Installation instructions](install.md)
* [FAQ](faq.md)

