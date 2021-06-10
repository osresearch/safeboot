#!/bin/bash

exec 1> /msgbus/server-rw
exec 2>&1

. /common.sh

expect_root

TAILWAIT=/safeboot/tail_wait.pl

echo "Running updater"

(drop_privs /updater_loop.sh) &
THEPID=$!
disown %
echo "Backgrounded (pid=$THEPID)"

echo "Waiting for 'die' message on /msgbus/server-rw-ctrl"
$TAILWAIT /msgbus/server-rw-ctrl "die"
echo "Got the 'die' message"
rm /msgbus/server-rw-ctrl
kill $THEPID
echo "Killed the backgrounded task"
