#!/bin/bash

exec 1> /msgbus/enrollsvc-mgmt
exec 2>&1

. /common.sh

expect_root

TAILWAIT=/safeboot/tail_wait.pl

echo "Running 'enrollsvc-mgmt' service"

# TODO: this crude "daemonize" logic has the standard race-condition, namely
# that we spawn the process but move forward too quickly and something then
# assumes the backgrounded service is ready before it actually is. This could
# probably be fixed by dy doing a tail_wait on our own output to pick up the
# telltale signs from the child process that the service is listening.
(drop_privs_flask /flask_wrapper.sh) &
THEPID=$!
disown %
echo "Backgrounded (pid=$THEPID)"

echo "Waiting for 'die' message on /msgbus/enrollsvc-mgmt-ctrl"
$TAILWAIT /msgbus/enrollsvc-mgmt-ctrl "die"
echo "Got the 'die' message"
rm /msgbus/enrollsvc-mgmt-ctrl
kill $THEPID
echo "Killed the backgrounded task"
