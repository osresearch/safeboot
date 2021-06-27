#!/bin/bash

exec 1> /msgbus/attestsvc-repl
exec 2>&1

. /common.sh

expect_root

TAILWAIT=/safeboot/tail_wait.pl

echo "Running updater"

# TODO: this crude "daemonize" logic has the standard race-condition, namely
# that we spawn the process but move forward too quickly and something then
# assumes the backgrounded service is ready before it actually is. This could
# probably be fixed by dy doing a tail_wait on our own output to pick up the
# telltale signs from the child process that the service is listening.
(drop_privs /updater_loop.sh) &
THEPID=$!
disown %
echo "Backgrounded (pid=$THEPID)"

echo "Waiting for 'die' message on /msgbus/attestsvc-repl-ctrl"
$TAILWAIT /msgbus/attestsvc-repl-ctrl "die"
echo "Got the 'die' message"
rm /msgbus/attestsvc-repl-ctrl
kill $THEPID
echo "Killed the backgrounded task"
