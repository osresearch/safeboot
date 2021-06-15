#!/bin/bash

set -e

TAILWAIT=/safeboot/tail_wait.pl
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

# TODO: this is bogus, doesn't do anything, and will fail if you connect to it.
# Worse still, updates in pxe-server mean that this fails to _start_ even. The
# client side is likewise contenting itself to ping us instead of connecting.
# Also...
# TODO: this crude "daemonize" logic has the standard race-condition, namely
# that we spawn the process but move forward too quickly and something then
# assumes the backgrounded service is ready before it actually is. This could
# probably be fixed by dy doing a tail_wait on our own output to pick up the
# telltale signs from the child process that the service is listening.
./sbin/attest-server ./secrets.yaml &
SERVPID=$!
disown %
echo "$PREF attestation server running (pid=$SERVPID)"

echo "Waiting for 'die' message on /msgbus/server-ro-ctrl"
$TAILWAIT /msgbus/server-ro-ctrl "die"
echo "Got the 'die' message"
rm /msgbus/server-ro-ctrl
kill $SERVPID

echo "$PREF ending"
