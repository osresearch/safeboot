#!/bin/bash

. /common.sh

expect_user

if [[ -d A || -d B || -h current || -h next || -h thirdwheel ]]; then
	echo "Error, updater state half-baked?"
	exit 1
fi

echo "First-time initialization of $STATE_PREFIX. Two clones and two symlinks."
cd $STATE_PREFIX
git clone $REMOTE_REPO A
git clone $REMOTE_REPO B
ln -s A current
ln -s B next
