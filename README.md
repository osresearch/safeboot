
# Safe Boot: Booting Linux Safely

Safe Boot has four goals to improve the safety of booting Linux
on normal laptops:

* **Booting only code that is authorized by the system owner** (by installing a hardware protected platform key for the kernel and initrd)
* **Streamlining the encrypted disk boot process** (by storing keys in the TPM, and only unsealing them if the firmware and configuration is unmodified)
* **Reducing the attack surface** (by enabling Linux kernel features to enable hardware protection features and to de-priviledge the root account)
* **Protecting the runtime system integrity** (by optionaly booting from a read-only root with dm-verity and signed root hash)

The [slightly more secure Heads firmware](http://osresearch.net)
(built with [coreboot](https://coreboot.org))
is a better choice for user freedom since it replaces the proprietary firmware
with open source, while Safe Boot's objective is to work with existing
commodity hardware and UEFI SecureBoot mechanisms, as well as relatively
stock Linux distributions.

For more details, see [the docs directory](docs/index.md), which is
processed with [mkdocs-material](https://squidfunk.github.io/mkdocs-material/)
to produce the <https://safeboot.dev/> website.

-----

## Building debian package

```
mkdir debian ; cd debian
git clone https://github.com/osresearch/safeboot
cd safeboot
sudo make requirements
make package
```

[![Build Debian package on ubuntu 20.04](https://github.com/osresearch/safeboot/workflows/Build%20Debian%20package%20on%20ubuntu%2020.04/badge.svg)](https://github.com/osresearch/safeboot/actions?query=workflow%3A%22Build+Debian+package+on+ubuntu+20.04%22)

[![Publish mkdocs via GitHub Pages](https://github.com/osresearch/safeboot/workflows/Publish%20mkdocs%20via%20GitHub%20Pages/badge.svg)](https://github.com/osresearch/safeboot/actions?query=workflow%3A%22Publish+mkdocs+via+GitHub+Pages%22)

## Contributing to `safeboot`

Please create [issues on github](https://github.com/osresearch/safeboot/issues)
if you run into problems and pull requests to solve problems or add
features are welcome!
Please review the [contributors guidelines](CONTRIBUTORS.md) and
[code of conduct](CODE_OF_CONDUCT.md) for more details on contributing.
