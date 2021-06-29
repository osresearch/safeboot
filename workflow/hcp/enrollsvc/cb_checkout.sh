#!/bin/bash

# Safeboot's "attest-enroll" script makes some default assumptions that we'd
# rather side-step. We use the CHECKOUT and COMMIT hooks to override the
# relevant handling. This file is the CHECKOUT hook, and is expected to print
# to stdout the path that the enrolled output should be generated to.
#
# In our context, it is the op_add.sh script that invokes attest-enroll, and
# it sets EPHEMERAL_ENROLL to the path we should use. So this script simply
# echos that path to stdout, and attest-enroll runs with that.
#
# Invocation;
#   $CHECKOUT "$ekhash" "$hostname" "$DBDIR" "$CONF"
# Stdout is assumed to be the directory where enrollment will occur.

[[ -z "$EPHEMERAL_ENROLL" ]] && exit 1
echo "$EPHEMERAL_ENROLL"
