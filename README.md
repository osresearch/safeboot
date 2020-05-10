# Safe Boot: Booting Linux Safely

Safe Boot has four goals:
* Booting only code that is authorized by the system owner (by installing a hardware protected platform key for the kernel and initrd)
* Streamlining the encrypted disk boot process (by storing keys in the TPM, and only unsealing them if the firmware and configuration is unmodified)
* Protecting the runtime system integrity (by optionally enabling a read-only root with dm-verity and signed root hash)
* Making it harder for an adversary to exfiltrate data (by enabling Linux kernel features to de-priviledge the root account)

The [slightly more secure Heads firmware](http://osresearch.net)
is a better choice for user freedom since it replaces the proprietary firmware
with open source, while Safe Boot's objective is to work with existing
commodity hardware and UEFI SecureBoot mechanisms, as well as relatively
stock Linux distributions.

For more details, see [the docs directory](docs/index.md)

-----

## Building debian package

```
sudo apt -y install \
	devscripts \
	tpm2-tools \
	efitools \
	gnu-efi \
	opensc \
	yubico-piv-tool \
	libengine-pkcs11-openssl \
	build-essential \
	binutils-dev \
	git \
	automake \
	help2man \
	libssl-dev \
	uuid-dev
mkdir debian ; cd debian
git clone https://github.com/osresearch/safeboot
make -C safeboot package
```
