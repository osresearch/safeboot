#!/bin/bash

exec 1> /msgbus/db-ro
exec 2>&1

. /common.sh

expect_root

TAILWAIT=/safeboot/tail_wait.pl

echo "Running git daemon"
echo "  - prefix: $DB_PREFIX"

# TODO: consider these choices. E.g. "--verbose"?
(drop_privs /usr/lib/git-core/git-daemon \
	--reuseaddr --verbose \
	--listen=0.0.0.0 \
	--base-path=$DB_PREFIX \
	$REPO_PATH) &
THEPID=$!
disown %
echo "Backgrounded (pid=$THEPID)"

echo "Waiting for 'die' message on /msgbus/ro.git-ctrl"
$TAILWAIT /msgbus/db-ro-ctrl "die"
echo "Got the 'die' message"
rm /msgbus/db-ro-ctrl
kill $THEPID
echo "Killed the git-daemon process"
