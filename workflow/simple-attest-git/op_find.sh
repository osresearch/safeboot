#!/bin/bash

. /common.sh

expect_user

echo "Starting $0" >&2
echo "  - Param1=$1 (hostname_suffix)" >&2

check_hostname_suffix "$1"

cd $REPO_PATH

# The JSON output should look like;
#    {
#        "hostname_suffix": ".dmz.mydomain.foo",
#        "ekpubhashes": [
#            "abbaf00ddeadbeef"
#            ,
#            "abcdef0123456789"
#            ,
#            "ffeeddccbbaa9988"
#        ]
#    }

echo "{"
echo "  \"hostname_suffix\": \"$1\","
echo "  \"ekpubhashes\": ["

# The table is indexed by _reversed_ hostname, so that our hostname_suffix
# search becomes a prefix search on the table.
revsuffix=`echo $1 | rev`

# The reverse lookup table file is replaced atomically by the add/delete logic,
# so when we pipe it into our filter loop below, it will remain unmodified
# throughout the loop, even if the underlying file has been unlinked from the
# file system and replaced by a newer version. I.e. we can avoid locking.

# Filter the lookup table, line by line, through a prefix comparison
(while IFS=" " read -r revhn ekpubhash
do
	if [[ $revhn == $revsuffix* ]]; then
		[[ -n $NEEDCOMMA ]] && echo "    ,"
		echo "    \"$ekpubhash\""
		NEEDCOMMA=1
	fi
done < $HN2EK_PATH) ||
	(echo "Error, the filter loop failed" >&2 && exit 1) || exit 1

echo "  ]"
echo "}"
