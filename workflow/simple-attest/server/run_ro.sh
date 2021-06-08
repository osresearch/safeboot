#!/bin/bash

set -e

PREF=simple-attest-server-ro:
MSGBUS=/msgbus/server-ro
MSGBUS_CLIENT=/msgbus/client

# Redirect stdout and stderr to our msgbus file
exec 1> $MSGBUS
exec 2>&1

for i in $SUBMODULES; do
	if [[ -d /i/$i ]]; then
		export PATH=/i/$i:$PATH
		if [[ -d /i/$i/lib ]]; then
			export LD_LIBRARY_PATH=/i/$i/lib:$LD_LIBRARY_PATH
			if [[ -d /i/$i/lib/python3/dist-packages ]]; then
				export PYTHONPATH=/i/$i/lib/python3/dist-packages:$PYTHONPATH
			fi
		fi
	fi
done

cd $DIR

echo "$PREF starting"

./sbin/attest-server ./secrets.yaml &
SERVPID=$!
disown %
echo "$PREF attestation server running (pid=$SERVPID)"

echo "$PREF waiting for stop command"
./tail_wait.pl $MSGBUS_CLIENT "control: stop server"
echo "$PREF got stop command!"

kill $SERVPID

echo "$PREF ending"
