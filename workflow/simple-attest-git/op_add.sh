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

JSON_STRING=$( jq -n \
                  --arg ekpubhash "$1" \
                  --arg hostname "$2" \
                  --arg hostblob "$3" \
                  '{ekpubhash: $ekpubhash, hostname: $hostname, hostblob: $hostblob}' )
HNREV=`echo "$2" | rev`

# The following code is the critical section, so surround it with lock/unlock.
$repo_cmd_lock || (echo "Error, failed to lock repo" && exit 1) || exit 1
[[ -f "$FPATH" ]] &&
	echo "Error, EK already exists" && itfailed=1
[[ -z "$itfailed" ]] &&
	(echo "$HNREV $FNAME" | cat - $HN2EK_PATH | sort > $HN2EK_PATH.tmp) || itfailed=1
[[ -z "$itfailed" ]] &&
	(echo "$JSON_STRING" > "$FPATH" &&
		mv $HN2EK_PATH.tmp $HN2EK_PATH &&
		git add . &&
		git commit -m "map $1 to $2") || itfailed=1
# TODO: This exception/error path before releasing the lock needs an alert
# valve of some kind. It's implemented to maximise reliability/recovery, by
# trying to force the clone back to its previous state, but someone really
# ought to know it's happening. E.g. if "git reset" is adding loads of
# erroneously-deleted files back to the checkout, or if "git clean" is removing
# loads of erroneously-generated junk files, that might indicate what's going
# wrong.
[[ -z "$itfailed" ]] || (echo "Failure, attempting recovery" &&
	echo "running 'git reset --hard'" && git reset --hard &&
	echo "running 'git clean -f -d -x'" && git clean -f -d -x)
$repo_cmd_unlock
echo "installed at \"$FPATH\""

# If it failed, fail
[[ -n "$itfailed" ]] && exit 1
/bin/true
