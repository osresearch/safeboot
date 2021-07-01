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

export TPM2TOOLS_TCTI=swtpm:host=$TPMHOST,port=$TPMPORT1

# Bypass some stuff unless explicitly enabled
if [[ -n "$CLIENT_EXTRA_STEPS" ]]; then

	# Check that the network and the server is there
	echo "$PREF waiting for server to advertise"
	./tail_wait.pl $MSGBUS_SERVER "$PREF_SERVER attestation server running"
	echo "$PREF heard from the server"

	# Check that the swtpm is alive
	echo "$PREF waiting for swtpm$HOSTIDX to advertise"
	./tail_wait.pl $MSGBUS_SWTPM "$PREF_SWTPM TPM running"
	echo "$PREF heard from the swtpm"

	# Ping the attestation server
	ping -c 1 $SERVER
	echo "$PREF ping seems fine"

	# Exercise the swtpm a bit
	tpm2_pcrread
fi

# Now keep trying to get a successful attestation. It may take a few seconds
# for our TPM enrollment to propagate to the attestation server, so it's normal
# for this to fail a couple of times before succeeding.
counter=0
while true
do
	echo "Trying an attestation..."
	unset itfailed
	./sbin/tpm2-attest attest http://$SERVER:8080 > secrets || itfailed=1
	if [[ -z "$itfailed" ]]; then
		echo "Success!"
		break
	fi
	((counter++)) || true
	echo "Failure #$counter"
	if [[ $counter -gt 10 ]]; then
		echo "Giving up"
		exit 1
	fi
	echo "Sleeping 5 seconds before retrying"
	sleep 5
done

echo "Extracting the attestation output;"
tar xvf secrets || (echo "Hmmm, tar reports some kind of error." &&
	echo "Copying to safeboot/sbin for inspection" &&
	cp secrets ./sbin)

echo "$PREF ending"
