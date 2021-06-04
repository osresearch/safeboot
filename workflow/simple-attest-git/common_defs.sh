# This is an include-only file. So no shebang header and no execute perms.
# It is common to the git server and to attestation updaters that pull from the
# git server. EK_PATH must point to the 'ekpubhash' directory (in the
# "attestdb.git" repo/clone).

[[ -z "$EK_PATH" || ! -d "$EK_PATH" ]] &&
	(echo "Error, EK_PATH must point to the ekpubhash lookup tree" >&2 && exit 1) &&
	exit 1

# ekpubhash must consist only of lower-case hex, and be at least 16 characters
# long (8 bytes)
function check_ekpubhash {
	(echo "$1" | egrep -e "^[0-9a-f]{16,}$" > /dev/null 2>&1) ||
		(echo "Error, malformed ekpubhash" >&2 && exit 1) || exit 1
}

# the prefix version can be any length (including empty)
function check_ekpubhash_prefix {
	(echo "$1" | egrep -e "^[0-9a-f]*$" > /dev/null 2>&1) ||
		(echo "Error, malformed ekpubhash" >&2 && exit 1) || exit 1
}

# hostname must consist only of alphanumerics, periods ("."), hyphens ("-"),
# and underscores ("_"). TODO: our code actually allows empty hostnames, which
# is why we don't need a distinct "_suffix" version (which certainly _should_
# accept the empty case, because it's a suffix match for a query), but we
# should fix that.
function check_hostname {
	(echo "$1" | egrep -e "^[0-9a-zA-Z._-]*$" > /dev/null 2>&1) ||
		(echo "Error, malformed hostname" >&2 && exit 1) || exit 1
}
function check_hostname_suffix {
	check_hostname $1
}

# hostblob must consist only of lower-case hex, arbitrary length
function check_hostblob {
	(echo "$1" | egrep -e "^[0-9a-f]*$" > /dev/null 2>&1) ||
		(echo "Error, malformed hostblob" >&2 && exit 1) || exit 1
}

# We use a 2-ply directory hierarchy for ekpubhash-indexed files. The
# first ply uses the first 2 hex characters as a directory name, for a split of
# 256. The second ply uses the first 6 characters as a directory name, meaning
# 4 new characters of uniqueness for a further split of 65536, resulting in a
# total split of ~16 million. (Yes, beneath the first ply, all sub-directories
# will have the same first 2 characters.) Beneath the second ply, a JSON file
# will be named using the first 16 characters of the ekpubhash, with fields
# 'ekpubhash', 'hostname', and 'hexblob'.

# Given an ekpubhash ($1), ensure the 1st and 2nd ply directories exist.
# Outputs;
#   PLY1 and PLY2: sub and sub-sub directory names in the ekpubhash tree
#   FNAME: basename for the JSON file
#   FPATH: full path to (and including) FNAME
function ply_path_add {
	PLY1=`echo $1 | cut -c 1,2`
	PLY2=`echo $1 | cut -c 1-6`
	FNAME=`echo $1 | cut -c 1-16`
	FPATH="$EK_PATH/$PLY1/$PLY2/$FNAME"
	mkdir -p "$EK_PATH/$PLY1/$PLY2"
}

# Given an ekpubhash prefix ($1), figure out the wildcard to match on all the
# JSON files.
# Outputs;
#   FPATH: full path with wildcard pattern
function ply_path_get {
	len=${#1}
	if [[ $len -lt 2 ]]; then
		FPATH="$EK_PATH/$1*/*/*"
	else
		PLY1=`echo $1 | cut -c 1,2`
		if [[ $len -lt 6 ]]; then
			FPATH="$EK_PATH/$PLY1/$1*/*"
		else
			PLY2=`echo $1 | cut -c 1-6`
			if [[ $len -lt 16 ]]; then
				FPATH="$EK_PATH/$PLY1/$PLY2/$1*"
			else
				FNAME=`echo $1 | cut -c 1-16`
				FPATH="$EK_PATH/$PLY1/$PLY2/$FNAME"
			fi
		fi
	fi
}
