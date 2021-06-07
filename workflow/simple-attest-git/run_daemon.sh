#!/bin/bash

exec 1> /msgbus/ro.git
exec 2>&1

. /common.sh

expect_root

TAILWAIT=/safeboot/tail_wait.pl

echo "Running git daemon"
echo "  - prefix: $REPO_PREFIX"

# TODO: consider these choices. E.g. "--verbose"?
(drop_privs /usr/lib/git-core/git-daemon \
	--reuseaddr --verbose \
	--listen=0.0.0.0 \
	--base-path=$REPO_PREFIX \
	$REPO_PATH) &
THEPID=$!
disown %
echo "Backgrounded (pid=$THEPID)"

echo "Waiting for 'die' message on /msgbus/ro.git-ctrl"
$TAILWAIT /msgbus/ro.git-ctrl "die"
echo "Got the 'die' message"
rm /msgbus/ro.git-ctrl
kill $THEPID
echo "Killed the git-daemon process"
