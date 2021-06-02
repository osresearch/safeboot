#!/bin/bash

. /common.sh

expect_user

mkdir $REPO_PATH
cd $REPO_PATH
git init
mkdir $EK_BASENAME
touch $EK_BASENAME/do_not_remove
git add .
git commit -m "Initial commit"
git log
