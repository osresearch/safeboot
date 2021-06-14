#!/bin/bash

set -e

PREF=simple-attest-swtpm:
MSGBUS=/msgbus/swtpm
TPMSTATE=/tpm
TPMPORT1=9876
TPMPORT2=9877

# Redirect stdout and stderr to our msgbus file
exec 1> $MSGBUS
exec 2>&1

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

echo "$PREF starting"

# Start the software TPM
swtpm socket --tpm2 --tpmstate dir=$TPMSTATE \
	--server type=tcp,bindaddr=0.0.0.0,port=$TPMPORT1 --ctrl type=tcp,bindaddr=0.0.0.0,port=$TPMPORT2 \
	--flags startup-clear &
TPMPID=$!
disown %
echo "$PREF TPM running (pid=$TPMPID)"

# Wait for the command to tear down
echo "Waiting for 'die' message on /msgbus/swtpm-ctrl"
./tail_wait.pl /msgbus/swtpm-ctrl "die"
echo "Got the 'die' message"
rm /msgbus/swtpm-ctrl

# Kill the software TPM
kill $TPMPID
echo "$PREF TPM stopped, done"
