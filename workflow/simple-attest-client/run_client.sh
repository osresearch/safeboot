#!/bin/bash

set -e

PREF=simple-attest-client:
PREF_SERVER=simple-attest-server:
MSGBUS=/msgbus/client
MSGBUS_SERVER=/msgbus/server
TPMSTATE=/tmp/swtpm-state
TPMPORT1=9876
TPMPORT2=9877

[[ -v PATH_EXTRA ]] && export PATH=$PATH_EXTRA:$PATH
cd $DIR

echo "$PREF starting" >> $MSGBUS

# Initialize a software TPM
mkdir -p $TPMSTATE
swtpm_setup --tpm-state $TPMSTATE --tpm2 --createek &>> $MSGBUS
swtpm socket --tpm2 --tpmstate dir=$TPMSTATE \
	--server type=tcp,port=$TPMPORT1 --ctrl type=tcp,port=$TPMPORT2 \
	--flags startup-clear &>> $MSGBUS &
TPMPID=$!
disown %
echo "$PREF TPM running (pid=$TPMPID)" >> $MSGBUS

# Check that the network and the server is there
echo "$PREF waiting for server to advertise" >> $MSGBUS
./tail_wait.pl $MSGBUS_SERVER "$PREF_SERVER starting" >> $MSGBUS
echo "$PREF heard from the server, now ping" >> $MSGBUS
ping -c 1 simple-attest-server &>> $MSGBUS
echo "$PREF ping seems fine" >> $MSGBUS

# Do some stuff that uses the TPM
export TPM2TOOLS_TCTI=swtpm:host=localhost,port=$TPMPORT1
tpm2_pcrread &>> $MSGBUS

# Kill the software TPM
kill $TPMPID
echo "$PREF TPM stopped, done" >> $MSGBUS

# Tell the server to tear down
echo "control: stop server" >> $MSGBUS
