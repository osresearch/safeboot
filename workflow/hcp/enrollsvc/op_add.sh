#!/bin/bash

. /common.sh

expect_user

echo "Starting $0"
echo "  - Param1=$1 (ekpubhash)"
echo "  - Param2=$2 (hostname)"
echo "  - Param3=$3 (hostblob)"

# ekpubhash, and hostname must be non-empty
if [[ -z $1 || -z $2 ]]; then
	echo "Error, missing at least one argument"
	exit 1
fi

check_ekpubhash "$1"

check_hostname "$2"

check_hostblob "$3"

cd $REPO_PATH

ply_path_add "$1"

HNREV=`echo "$2" | rev`

# The following code is the critical section, so surround it with lock/unlock.
repo_cmd_lock || (echo "Error, failed to lock repo" && exit 1) || exit 1
[[ -f "$FPATH" ]] &&
	echo "Error, EK already exists" && itfailed=1
[[ -z "$itfailed" ]] &&
	(echo "$HNREV `basename $FPATH`" | cat - $HN2EK_PATH | sort > $HN2EK_PATH.tmp) || itfailed=1
[[ -z "$itfailed" ]] &&
	(echo "$1" > "$FPATH/ekpubhash" &&
		echo "$2" > "$FPATH/hostname" &&
		echo "$3" > "$FPATH/hostblob" &&
		mv $HN2EK_PATH.tmp $HN2EK_PATH &&
		git add . &&
		git commit -m "map $1 to $2") || itfailed=1
# TODO:
# 1. This exception/error/rollback path (necessarily before releasing the lock)
#    needs an alert valve of some kind. It's implemented to maximise
#    reliability/recovery, by trying to force the clone back to its previous
#    state, but we really ought to tell someone what we know before we
#    deliberately try to erase all trace. E.g. if "git reset" is adding loads
#    of erroneously-deleted files back to the checkout, or if "git clean" is
#    removing loads of erroneously-generated junk out of the checkout, that
#    information might indicate what's going wrong.
# 2. More urgently: if our failure-handling code fails to rollback correctly,
#    we _REALLY_ have to escalate! For now, we simply leave the repo locked,
#    which is not the most effective nor appreciated escalation method.
[[ -z "$itfailed" ]] ||
	(echo "Failure, attempting recovery" &&
		echo "running 'git reset --hard'" && git reset --hard &&
		echo "running 'git clean -f -d -x'" && git clean -f -d -x) ||
	rollbackfailed=1

# If recovery failed, refuse to unlock the repo, forcing an intervention and
# blocking further modifications.
[[ -z "$rollbackfailed" ]] && repo_cmd_unlock

# If it failed, fail
[[ -n "$itfailed" ]] && exit 1

echo "installed at \"$FPATH\""
/bin/true
