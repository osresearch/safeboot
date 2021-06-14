#!/bin/bash

# Parameters;
#   $1 = path to source file
#   $2 = path to destination file
#
# This will copy $1 to $2 iff they do not have the same file content (using
# "cmp"). I.e. timestamps will only get touched if the files are different.
# Neither $1 nor $2 can be a directory!

set -e

function log {
	([[ -v V ]] && echo "$1" >&2) || /bin/true
}

log "cp_if_cmp;"
log "SRC=$1"
log "DST=$2"
(cmp $1 $2 > /dev/null 2>&1 && log "no change") || \
	(cp $1 $2 && V=1 log "updating $2") || \
	(V=1 log "failure" && exit 1)
