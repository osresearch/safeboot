#!/bin/bash

set -e

PREF=simple-attest-server:
MSGBUS=/msgbus/server
MSGBUS_CLIENT=/msgbus/client

[[ -v PATH_EXTRA ]] && export PATH=$PATH_EXTRA:$PATH
cd $DIR

echo "$PREF starting" >> $MSGBUS

./sbin/attest-server ./secrets.yaml >> $MSGBUS &
SERVPID=$!
disown %
echo "$PREF attestation server running (pid=$SERVPID)" >> $MSGBUS

echo "$PREF waiting for stop command" >> $MSGBUS
./tail_wait.pl $MSGBUS_CLIENT "control: stop server"
echo "$PREF got stop command!" >> $MSGBUS

kill $SERVPID

echo "$PREF ending" >> $MSGBUS
