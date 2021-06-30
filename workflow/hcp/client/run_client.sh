#!/bin/bash

set -e

PREF=hcp-client$HOSTIDX:
PREF_SERVER=hcp-attestsvc-hcp:
PREF_SWTPM=hcp-swtpm$HOSTIDX:
SERVER=hcp-attestsvc-hcp
MSGBUS=/msgbus/client$HOSTIDX
MSGBUS_SERVER=/msgbus/attestsvc-hcp
MSGBUS_SWTPM=/msgbus/swtpm$HOSTIDX
TPMHOST=hcp-swtpm$HOSTIDX
TPMPORT1=9876

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

# Check that the network and the server is there
echo "$PREF waiting for server to advertise"
./tail_wait.pl $MSGBUS_SERVER "$PREF_SERVER attestation server running"
echo "$PREF heard from the server"

# Likewise verify that the swtpm is alive
echo "$PREF waiting for swtpm$HOSTIDX to advertise"
./tail_wait.pl $MSGBUS_SWTPM "$PREF_SWTPM TPM running"
echo "$PREF heard from the swtpm"

# As we haven't yet plugged in the real attestation protocol, replace it with a
# single client-to-server ping!
ping -c 1 $SERVER
echo "$PREF ping seems fine"

# Do some stuff that uses the TPM
export TPM2TOOLS_TCTI=swtpm:host=$TPMHOST,port=$TPMPORT1
tpm2_pcrread

# Now try an actual attestation...
echo "Trying an attestation..."
./sbin/tpm2-attest attest http://$SERVER:8080 > foobar
echo "Result looks like this;"
tar xvf foobar

echo "$PREF ending"
