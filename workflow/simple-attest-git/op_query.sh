#!/bin/bash

# NB: this query logic is transformed into delete logic by the presence of
# QUERY_PLEASE_ALSO_DELETE.

. /common.sh

expect_user

echo "Starting $0" >&2
echo "  - Param1=$1 (ekpubhash)" >&2

check_ekpubhash_prefix "$1"

cd $REPO_PATH

ply_path_get "$1"

# The JSON output should look like;
#    {
#        "entries": [
#            {
#                "ekpubhash": "abbaf00ddeadbeef"
#                "hostname": "host-at.some_domain.com"
#                "hostblob": "01234fedc"
#            }
#            ,
#            {
#                "ekpubhash": "0123456789abcdef"
#                "hostname": "whatever.wherever.foo"
#                "hostblob": "439872493827498327492837498217"
#            }
#        ]
#    }
# Now the entries are already stored as files that contain the
# curly-brace-encapsulated 3-tuples, so we only need to take care of the
# "entries" array (with the "[" and "]" and comma-separation of array entries)
# as well as the outer "{" and "}".
echo "{ \"entries\": ["

# The following code is the critical section, so surround it with lock/unlock
repo_cmd_lock || (echo "Error, failed to lock repo" >&2 && exit 1) || exit 1

(
FILE_LIST=`ls $FPATH 2> /dev/null`
for i in $FILE_LIST; do
	[[ -n $NEEDCOMMA ]] && echo ","
	cat $i
	NEEDCOMMA=1
	[[ -z $QUERY_PLEASE_ALSO_DELETE ]] || git rm $i >&2
done
[[ -z $QUERY_PLEASE_ALSO_DELETE ]] || git commit -m "delete $1" >&2
) || itfailed=1

repo_cmd_unlock

echo -n "]}"

# If it failed, fail
[[ -n "$itfailed" ]] && exit 1
/bin/true
