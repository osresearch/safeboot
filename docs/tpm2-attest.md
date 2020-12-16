
# tpm2-attest subcommands

Usage: `tpm2-attest subcommand [options...]`

For more information see: <https://safeboot.dev/attestation/>


## quote
Usage:
```
tpm2-attest quote [nonce [pcrs,...]] > quote.tgz
scp quote.tgz ...
```
After contacting the remote attestation server to receive the
nonce, the machine will generate the endorsement key,
endorsement cert, a one-time attestation key, and a signed quote
for the PCRs using that nonce.

This will result in two output files, `quote.tgz` to be sent to
the remote side, and `ak.ctx` that is to remain on this machine
for decrypting the return result from the remote attestation server.

## attest
Usage:
```
tpm2-attest attest http://server/ [nonce [pcrs,...]] > secret.txt
```
This will generate a quote for the nonce (or the current time if
none is specified) and for the PCRs listed in the `$QUOTE_PCRS`
environment variable.  It will then send the quote to a simple
attestation server, which will validate the quote and reply with
a sealed message that can only be decrypted by this TPM on this
boot.

No validation of the attestation server is done.

## verify
Usage:
```
tpm2-attest verify quote.tgz [nonce [ca-path]]
```

This will validate that the quote was signed with the attestation key
with the provided nonce, and verify that the endorsement key from a valid
TPM.  It outputs, but does not validate the event log; use
`tpm2-attest eventlog-verify` once the known PCRs are available, or use a more 
complex validation scheme.

If the `nonce` is not specified, the one in the quote file will be used,
although this opens up the possibility of a replay attack.  The QUOTE_MAX_AGE
can be used to ensure that the quote is fresh.

If the `ca-path` is not specified, the system one will be used.

The output on stdout is yaml formatted with the sha256 hash of the DER format
EK certificate, the validated quote PCRs, and the unvalidated eventlog PCRs.

## eventlog
Usage:
```
tpm2-attest eventlog [eventlog.bin]
```

This will read and parse the TPM2 eventlog. If no file is specified,
the default Linux one will be parsed.  If `-` is specified, the eventlog
will be read from stdin.


## eventlog-verify
Usage:
```
tpm2-attest eventlog-verify quote.tgz [good-pcrs.txt]
```

This will verify that the PCRs included in the quote match the
TPM event log, and if `good-prcs.txt` are passed in that they
match those as well.


## ek-verify
Usage:
```
tpm2-attest ek-verify quote.tgz ca-path
```

This will validate that the endorsement key came from a valid TPM.

The TPM endorsement key is signed by the manufacturer OEM key, which is
in turn signed by a trusted root CA.  Before trusting an attestation it is
necessary to validate this chain of signatures to ensure that it came
from a legitimate TPM, otherwise an attacker could send a quote that
has a fake key and decrypt the message in software.

The `ca-path` should contain a file named `roots.pem` with the trusted
root keys and have the hash symlinks created by `c_rehash`.

stdout is the sha256 hash of the DER format EK certificate.

## quote-verify
Usage:
```
tpm2-attest quote-verify quote.tgz [nonce]
```

This command checks that the quote includes the given nonce and
was signed by the public attestation key (AK) in the quote file.
This also check the attributes of the AK to ensure that it has
the correct bits set (`fixedtpm`, `stclear`, etc).
NOTE: This does not verify that the AK came from a valid TPM.
See `tpm2-attest verify` for the full validation.

If the `nonce` is not specified on the command line, the one in the
quote file will be used.  Note that this is a potential for a replay
attack -- the remote attestation server should keep track of which
nonce it used for this quote so that it can verify that the quote
is actually live.

stdout is the yaml formatted `tpm2 checkquote`, which can be used to
validate the eventlog PCRs.

## seal
Usage:
```
echo secret | tpm2-attest seal quote.tgz > cipher.bin
```

After a attested quote has been validated, an encrypted reply is sent to
the machine with a sealed secret, encrypted with that machines
endorsment key (`ek.crt`), with the name of the attestation key
used to sign the quote.  The TPM will not decrypt the sealed
message unless the attestation key was one that it generated.

The `cipher.bin` file should be sent back to the device being attested;
it can then run `tpm2-attest unseal ak.ctx < cipher.bin > secret.txt`
to extract the sealed secret.

## unseal
Usage:
```
cat cipher.bin | tpm2-attest unseal ak.ctx  > secret.txt
```

When the remote attestation has been successful, the remote machine will
reply with an encrypted blob that is only unsealable by this TPM
if and only if the EK matches and the AK is one that it generated.

## verify-and-seal
Usage:
```
tpm2-attest verify-and-seal quote.tgz [nonce [pcrs]] < secret.txt > cipher.bin
```

If the `nonce` is not specified on the command line, the one in the
quote file will be used.  Note that this is a potential for a replay
attack -- the remote attestation server should keep track of which
nonce it used for this quote so that it can verify that the quote
is actually live.

## ek-sign
Usage:
```
tpm2-attest ek-sign < ek.pem > ek.crt [/CN=device-name/]
```

Some TPMs do not include manufacturer signed endorsement key
certificates, so it is necessary to extract the EK and sign it
with a trusted key.  This will produce `ek.crt`, signed with
the safeboot key.  The signing operation can be done out-of-band
on a different machine.

For Google Cloud ShieldedVM machines see:
https://cloud.google.com/security/shielded-cloud/retrieving-endorsement-key

Usually the EK public components can be extracted from the TPM, signed,
and the resulting signed `ek.crt` can be stored back into the TPM nvram.
Note that this will erase an existing OEM cert if you have one!

```
# on the device
tpm2-attest ek-crt > ek.pem
# on the server
tpm2-attest ek-sign < ek.pem > ek.crt /CN=device/OU=example.org/
# on the device again
tpm2-attest ek-crt ek.crt
```

## ek-crt
Usage:
```
tpm2-attest ek-crt > ek.pem  # Export the TPM EK in PEM format (not cert)
```
or
```
tpm2-attest ek-crt ek.crt  # Import a signed cert for the EK in DER format
```

Export the TPM RSA endorsement key for signing by a CA or import a signed
endorsement key certificate into the TPM NVRAM at the well-known handle.
See `tpm2-attest ek-sign` for more details.

