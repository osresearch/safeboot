#!/bin/bash

. /common.sh

expect_user

mkdir $REPO_PATH
cd $REPO_PATH
git init
touch git-daemon-export-ok
touch $HN2EK_PATH
mkdir $EK_BASENAME
touch $EK_BASENAME/do_not_remove
cp /common_defs.sh .
git add .
git commit -m "Initial commit"
git log
