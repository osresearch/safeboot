# This is an include-only file. So no shebang header and no execute perms.
#
# This file is copied and modified from the file of the same name in
# simple-attest-git. Same idea, it shares routines and definitions between the
# updater and the server, the former having read-write access to the "state"
# mount and the latter having read-only access.

set -e

echo "Running '$0'" >&2
echo "Settings passed in;" >&2
echo "      USERNAME=$USERNAME" >&2
echo "  STATE_PREFIX=$STATE_PREFIX" >&2
echo "   REMOTE_REPO=$REMOTE_REPO" >&2
echo "  UPDATE_TIMER=$UPDATE_TIMER" >&2

if [[ -z "$USERNAME" || ! -d "/home/$USERNAME" ]]; then
	echo "Error, USERNAME (\"$USERNAME\") is not a valid user" >&2
	exit 1
fi
[[ -z "$STATE_PREFIX" || ! -d "$STATE_PREFIX" ]] &&
	(echo "Error, STATE_PREFIX must point to our volume" >&2 && exit 1) &&
	exit 1
[[ -z "$REMOTE_REPO" ]] &&
	(echo "Error, REMOTE_REPO must be set for cloning" >&2 && exit 1) &&
	exit 1
[[ -z "$UPDATE_TIMER" ]] &&
	(echo "Error, UPDATE_TIMER must be set" >&2 && exit 1) &&
	exit 1

function drop_privs {
	su --whitelist-environment USERNAME,STATE_PREFIX,REMOTE_REPO,UPDATE_TIMER -c "$1 $2 $3 $4 $5" - $USERNAME
}

function expect_root {
	if [[ `whoami` != "root" ]]; then
		echo "Error, running as \"`whoami`\" rather than \"root\"" >&2
		exit 1
	fi
}

function expect_user {
	if [[ `whoami` != "$USERNAME" ]]; then
		echo "Error, running as \"`whoami`\" rather than \"$USERNAME\"" >&2
		exit 1
	fi
}

# TBD: it's possible to do much better than the current implementation, both in
# terms of replicating more immediately when orchestation changes come in
# (notification/signal), as well as allowing long/slow attestations to take all
# the time they need rather than depending on our "immutability period" (by
# unlinking). But that require more work and is easier to mess up if it's not
# thought out carefully. For now, this basic A/B tick-tock thing should be
# fine.

# OK, so here's how the updater works, which implies how the attestation server
# needs to work too. 
# * The updater manages state in a volume mounted at $STATE_PREFIX, which is
#   also mounted (at the same path) in the corresponding attestation service
#   instance(s).
#   - The volume is mounted read-write for the updater.
#   - The volume is mounted read-only for the attestation service instance(s).
# * Inside $STATE_PREFIX, there are;
#   - Two clones of the remote 'attestdb.git' repository, called "A" and "B".
#   - Two symlinks, called "current" and "next", one of which points to
#     "A" and the other points to "B".
# * The updater performs a task in a loop, observing a pause between each
#   iteration. That pause provides a lower bound that works like an
#   "immutability period". (But we call it $UPDATE_TIMER, to save typing.)
# * For each iteration of the updater's task;
#   - it follow the "next" link into the clone it points to,
#   - it fetches and merge updates from the remote repository,
#   - it then inverts the "current" and "next" symlinks.
#   - then sleeps for (at least) the immutability period.
# * When an attestation service thread follows the "current" symlink into one
#   of the two clones, typically as it starts processing an attestation request
#   from a host/client, the clone is guaranteed to have no data modifications
#   for up to that immutability period.
# * The attestation service thread can traverse the "current" link anew,
#   as/when it is OK for modifications to "appear", at which point the
#   immutability guarantee also starts anew. This would typically occur when
#   processing a new attestation request.
# * This period needs to be chosen long enough that any attestation request
#   taking that long should have already timed-out/failed/retried, but short
#   enough to provide an acceptable upper-bound on the delay between
#   orchestration changes replicating and taking effect in attestation service
#   instances.

cd $STATE_PREFIX
