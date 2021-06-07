#!/bin/bash

exec 1> /msgbus/updater
exec 2>&1

. /common.sh

expect_root

TAILWAIT=/safeboot/tail_wait.pl

echo "Running updater"

(drop_privs /updater_loop.sh) &
THEPID=$!
disown %
echo "Backgrounded (pid=$THEPID)"

echo "Waiting for 'die' message on /msgbus/updater-ctrl"
$TAILWAIT /msgbus/updater-ctrl "die"
echo "Got the 'die' message"
rm /msgbus/updater-ctrl
kill $THEPID
echo "Killed the backgrounded task"
