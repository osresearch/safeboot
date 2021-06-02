#!/bin/bash

. /common.sh

exec 1> /msgbus/git
exec 2>&1

expect_root

TAILWAIT=/safeboot/tail_wait.pl

echo "Running git repo"

(drop_privs /flask_wrapper.sh) &
THEPID=$!
disown %
echo "Backgrounded (pid=$THEPID)"

echo "Waiting for 'die' message on /msgbus/git-ctrl"
$TAILWAIT /msgbus/git-ctrl "die"
echo "Got the 'die' message"
rm /msgbus/git-ctrl
kill $THEPID
echo "Killed the backgrounded task"
