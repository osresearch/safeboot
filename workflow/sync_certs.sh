#!/bin/bash

# Parameters;
#   $1 = path to source (host) certificates
#   $2 = path to destination (docker context area) for certificates
#
# Similar to cp_if_cmp.sh, except now both $1 and $2 must be directories, not
# files.

set -e

cp_if_cmp=./workflow/cp_if_cmp.sh

function log {
	([[ -v V ]] && echo "$1" >&2) || /bin/true
}

log "sync_certs;"
log "SRC=$1"
log "DST=$2"

files=`find -L $1 -type f`

for i in $files; do
	b=`basename $i`
	$cp_if_cmp "$i" "$2/$b"
done
