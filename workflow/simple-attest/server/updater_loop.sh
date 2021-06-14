#!/bin/bash

. /common.sh

expect_user

BACKOFF_TIMER=$(($UPDATE_TIMER * 5))

function datetime_log {
	d=`date +"%Y%m%d-%H%M%S"`
	echo "$d: $1"
}

# By discipline and convention, we do all our bash with "-e", so make sure to
# sponge up any errors that aren't bugs or irrecoverable conditions.
#
# In particular, this service is supposed to handle transient replication
# errors, most likely when the db we're replicating from (or the network)
# vanishes for a while, so we can't let bash abort the script due to an error
# in git-fetch or git-merge.
#
# On the other hand if something like "cd $STATE_PREFIX", "cd next", or
# "datetime_log" fails, then the appropriate thing _is_ for bash to kill the
# script and attract the attention of someone to come and look at the
# unexpected state we're in, so leave such things in naive form and bash will
# do the error checking for us. (Rationale: in such cases, trying to recover or
# even endure just adds complexity - and new ways for things to go wrong - and
# is more likely to "bury the lede" when someone sifts through the wreckage
# later trying to figure out what happened.)
while /bin/true; do
	cd $STATE_PREFIX
	cd next
	datetime_log "updating"
	if (git fetch origin && git merge origin/main); then
		cd $STATE_PREFIX
		cp -P current thirdwheel
		cp -T -P next current
		mv -T thirdwheel next
		datetime_log "sleeping for $UPDATE_TIMER seconds"
		sleep $UPDATE_TIMER
	else
		# TODO: we should alert that the fetch/merge failed. Such
		# failures would (likely) point to a problem with the db we're
		# replicating from, meaning the same failures are likely being
		# reported by other instances that replicate from the same db.
		# "We" can't provide much information about the db, beyond
		# signaling the existence of an issue, so keep it concise.
		# TODO: on the other hand, if the transient error handling and
		# recovery steps below fail for any reason, that is a different
		# matter entirely, and it means an operator needs to look at
		# this node, irrespective of whether our troubles were caused
		# by a db failure. I.e. we need error-handling around our
		# error-handling, to raise a different kind of alert.
		datetime_log "Transient error. Trying to revert from incomplete update."
		git reset --hard
		git clean -f -d -x
		datetime_log "sleeping for $BACKOFF_TIMER seconds"
		sleep $BACKOFF_TIMER
	fi
done
