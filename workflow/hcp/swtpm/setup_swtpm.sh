#!/bin/bash

set -e

TPMSTATE=/tpm

for i in $SUBMODULES; do
	if [[ -d /i/$i/bin ]]; then
		export PATH=/i/$i/bin:$PATH
	fi
	if [[ -d /i/$i/lib ]]; then
		export LD_LIBRARY_PATH=/i/$i/lib:$LD_LIBRARY_PATH
		if [[ -d /i/$i/lib/python3/dist-packages ]]; then
			export PYTHONPATH=/i/$i/lib/python3/dist-packages:$PYTHONPATH
		fi
	fi
done

cd $DIR

echo "Setting up a software TPM in $TPMSTATE"

# Initialize a software TPM
swtpm_setup --tpm2 --createek --display --tpmstate $TPMSTATE --config /dev/null
# Temporarily start the TPM on an unusual port (and sleep a second to be sure
# it's alive before we hit it). TODO: Better would be to tail_wait the output.
swtpm socket --tpm2 --tpmstate dir=$TPMSTATE \
	--server type=tcp,bindaddr=127.0.0.1,port=19283 --ctrl type=tcp,bindaddr=127.0.0.1,port=19284 \
	--flags startup-clear &
echo "Started temporary instance of swtpm"
sleep 1
# Now pressure it into creating the EK (and why doesn't "swtpm_setup
# --createek" already do this?)
export TPM2TOOLS_TCTI=swtpm:host=localhost,port=19283
tpm2 createek -c $TPMSTATE/ek.ctx -u $TPMSTATE/ek.pub
echo "Software TPM state created;"
tpm2 print -t TPM2B_PUBLIC $TPMSTATE/ek.pub
