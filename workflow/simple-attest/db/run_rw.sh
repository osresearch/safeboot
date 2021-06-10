#!/bin/bash

exec 1> /msgbus/db-rw
exec 2>&1

. /common.sh

expect_root

TAILWAIT=/safeboot/tail_wait.pl

echo "Running git repo"

(drop_privs /flask_wrapper.sh) &
THEPID=$!
disown %
echo "Backgrounded (pid=$THEPID)"

echo "Waiting for 'die' message on /msgbus/db-rw-ctrl"
$TAILWAIT /msgbus/db-rw-ctrl "die"
echo "Got the 'die' message"
rm /msgbus/db-rw-ctrl
kill $THEPID
echo "Killed the backgrounded task"
