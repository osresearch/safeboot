#!/bin/bash

TAILWAIT=/safeboot/tail_wait.pl
PREF=hcp-attestsvc-hcp:
MSGBUS=/msgbus/attestsvc-hcp
MSGBUS_CLIENT=/msgbus/client

# Redirect stdout and stderr to our msgbus file
exec 1> $MSGBUS
exec 2>&1

. /common.sh

expect_root

echo "$PREF starting"

# TODO: this crude "daemonize" logic has the standard race-condition, namely
# that we spawn the process but move forward too quickly and something then
# assumes the backgrounded service is ready before it actually is. This could
# probably be fixed by dy doing a tail_wait on our own output to pick up the
# telltale signs from the child process that the service is listening.
(drop_privs /wrapper-attest-server.sh) &
SERVPID=$!
disown %
echo "$PREF attestation server running (pid=$SERVPID)"

echo "Waiting for 'die' message on /msgbus/attestsvc-hcp-ctrl"
$TAILWAIT /msgbus/attestsvc-hcp-ctrl "die"
echo "Got the 'die' message"
rm /msgbus/attestsvc-hcp-ctrl
kill $SERVPID

echo "$PREF ending"
