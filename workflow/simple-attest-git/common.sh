# This is an include-only file. So no shebang header and no execute perms.

set -e

echo "Running '$0'" >&2
echo "Settings passed in;" >&2
echo "   REPO_PREFIX=$REPO_PREFIX" >&2
echo "      USERNAME=$USERNAME" >&2

# REPO_PREFIX must be passed in, fail otherwise
if [[ -z "$REPO_PREFIX" || ! -d "$REPO_PREFIX" ]]; then
	echo "Error, REPO_PREFIX (\"$REPO_PREFIX\") is not a valid path" >&2
	exit 1
fi

# Ditto for $USERNAME
if [[ -z "$USERNAME" || ! -d "/home/$USERNAME" ]]; then
	echo "Error, USERNAME (\"$USERNAME\") is not a valid user" >&2
	exit 1
fi

REPO_NAME=attestdb.git
EK_BASENAME=ekpubhash

REPO_PATH=$REPO_PREFIX/$REPO_NAME
EK_PATH=$REPO_PATH/$EK_BASENAME
REPO_LOCKPATH=$REPO_PREFIX/lock-$REPO_NAME

echo "Settings added;" >&2
echo "     REPO_NAME=$REPO_NAME" >&2
echo "   EK_BASENAME=$EK_BASENAME" >&2
echo "     REPO_PATH=$REPO_PATH" >&2
echo "       EK_PATH=$EK_PATH" >&2
echo " REPO_LOCKPATH=$REPO_LOCKPATH" >&2

function drop_privs {
	su --whitelist-environment REPO_PREFIX,USERNAME -c "$1 $2 $3 $4 $5" - $USERNAME
}

function expect_root {
	if [[ `whoami` != "root" ]]; then
		echo "Error, running as \"`whoami`\" rather than \"root\"" >&2
		exit 1
	fi
}

function expect_user {
	if [[ `whoami` != "$USERNAME" ]]; then
		echo "Error, running as \"`whoami`\" rather than \"$USERNAME\"" >&2
		exit 1
	fi
}

function repo_cmd_lock {
	[[ -f $REPO_LOCKPATH ]] && echo "Warning, lockfile contention" >&2
	lockfile -1 -r 5 -l 30 -s 5 $REPO_LOCKPATH
}

function repo_cmd_unlock {
	rm -f $REPO_LOCKPATH
}

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
# and underscores ("_"). 
function check_hostname {
	(echo "$1" | egrep -e "^[0-9a-zA-Z._-]*$" > /dev/null 2>&1) ||
		(echo "Error, malformed hostname" >&2 && exit 1) || exit 1
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
	mkdir -p $EK_PATH/$PLY1/$PLY2
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
