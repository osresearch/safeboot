This guide was written using Ubuntu 20.04 and `tpm2-tools` 4.1.1.
All of the commands are run as `root`.

The `cryptdisk-seal` program will securely generate a random key
for encrypting the disk and add it to the LUKS key slot 1; the
normal installer uses key slot 0 for the manually entered key,
which will be left as a recovery key in case there is a TPM failure.
In order to add the new key, you will have to enter the existing
recovery key (set during initial install).

The random key will also be sealed into the TPM as a persistent object
using the current value of the important PCRs.

In order for the 


Other helpful links:
* https://robertou.com/tpm2-sealed-luks-encryption-keys.html which uses a less standard TPM toolkit
* https://threat.tevora.com/secure-boot-tpm-2/ which is out of date on the tpm2 command line options


Meaning for UEFI is defined in
[Microsoft's "`OSPlatformValidation_UEFI`" registry key](https://getadmx.com/?Category=MDOP&Policy=Microsoft.Policies.BitLockerManagement::PlatformValidation_UEFI_Name). By default Bitlocker uses 0, 2, 4, 8, 9, 10, 11.

* PCR 0: Core System Firmware executable code
* PCR 1: Core System Firmware data
* PCR 2: ROM Code (was Extended or pluggable executable code?)
* PCR 3: Extended or pluggable firmware data
* PCR 4: MBR Code (was Boot Manager?)
* PCR 5: GPT / Partition Table
* PCR 6: Resume from S4 and S5 Power State Events
* PCR 7: Secure Boot State
* PCR 8: NTFS Boot Secure (was Initialized to 0 with no Extends (reserved for future use)?)
* PCR 9: NTFS Boot Block (was Initialized to 0 with no Extends (reserved for future use)?)
* PCR 10: NTFS Boot Manager (was Initialized to 0 with no Extends (reserved for future use)?)
* PCR 11: BitLocker Access Control
* PCR 12: Data events and highly volatile events
* PCR 13: Boot Module Details
* PCR 14: Boot Authorities
* PCR 15-23: Reserved for future use

Install the tools on the running system:
```
apt install tpm2-tools tpm2-abrmd
```


