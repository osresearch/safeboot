#!/bin/bash

set -e

PREF=hcp-swtpm$HOSTIDX:
MSGBUS=/msgbus/swtpm$HOSTIDX
MSGBUSCTRL=/msgbus/swtpm${HOSTIDX}-ctrl
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
# TODO: this crude "daemonize" logic has the standard race-condition, namely
# that we spawn the process but move forward too quickly and something then
# assumes the backgrounded service is ready before it actually is. This could
# probably be fixed by dy doing a tail_wait on our own output to pick up the
# telltale signs from the child process that the service is listening.
swtpm socket --tpm2 --tpmstate dir=$TPMSTATE \
	--server type=tcp,bindaddr=0.0.0.0,port=$TPMPORT1 --ctrl type=tcp,bindaddr=0.0.0.0,port=$TPMPORT2 \
	--flags startup-clear &
TPMPID=$!
disown %
echo "$PREF TPM running (pid=$TPMPID)"

# Wait for the command to tear down
echo "Waiting for 'die' message on $MSGBUSCTRL"
./tail_wait.pl $MSGBUSCTRL "die"
echo "Got the 'die' message"
rm $MSGBUSCTRL

# Kill the software TPM
kill $TPMPID
echo "$PREF TPM stopped, done"
