#!/bin/bash

export DB_IN_SETUP=1

. /common.sh

expect_root

drop_privs_db /init_repo.sh
