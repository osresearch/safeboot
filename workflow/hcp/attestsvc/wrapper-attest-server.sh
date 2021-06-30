#!/bin/bash

. /common.sh

expect_user

cd $DIR

# Steer attest-server (and attest-verify) towards our source of truth
export SAFEBOOT_DB_DIR="$STATE_PREFIX/current"

./sbin/attest-server 8080
