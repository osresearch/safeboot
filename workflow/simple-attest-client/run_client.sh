#!/bin/bash

set -e

PREF=simple-attest-client:
PREF_SERVER=simple-attest-server:
MSGBUS=/msgbus/client
MSGBUS_SERVER=/msgbus/server
TPMSTATE=/tmp/swtpm-state
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

# Initialize a software TPM
mkdir -p $TPMSTATE
swtpm_setup --tpm-state $TPMSTATE --tpm2 --createek
swtpm socket --tpm2 --tpmstate dir=$TPMSTATE \
	--server type=tcp,port=$TPMPORT1 --ctrl type=tcp,port=$TPMPORT2 \
	--flags startup-clear &
TPMPID=$!
disown %
echo "$PREF TPM running (pid=$TPMPID)"

# Check that the network and the server is there
echo "$PREF waiting for server to advertise"
./tail_wait.pl $MSGBUS_SERVER "$PREF_SERVER starting"
echo "$PREF heard from the server, now ping"
ping -c 1 simple-attest-server
echo "$PREF ping seems fine"

# Do some stuff that uses the TPM
export TPM2TOOLS_TCTI=swtpm:host=localhost,port=$TPMPORT1
tpm2_pcrread

# Kill the software TPM
kill $TPMPID
echo "$PREF TPM stopped, done"

# Tell the server to tear down
echo "control: stop server"
