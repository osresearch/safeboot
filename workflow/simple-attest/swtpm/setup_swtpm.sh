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
swtpm_setup --tpm-state $TPMSTATE --tpm2 --createek
echo "Software TPM state created"
