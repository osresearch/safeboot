# This is an include-only file. So no shebang header and no execute perms.
#
# This file is copied and modified from the file of the same name in enrollsvc.
# Same idea, it shares routines and definitions between the replicator and the
# server, the former having read-write access to the "state" mount and the
# latter having read-only access.

set -e

if [[ `whoami` == "root" ]]; then
	source /etc/environment.root
fi

echo "Running '$0'" >&2
echo "Settings passed in;" >&2
echo "    SUBMODULES=$SUBMODULES" >&2
echo "           DIR=$DIR" >&2
echo "  STATE_PREFIX=$STATE_PREFIX" >&2
echo "      USERNAME=$USERNAME" >&2

if [[ -z "$USERNAME" || ! -d "/home/$USERNAME" ]]; then
	echo "Error, USERNAME (\"$USERNAME\") is not a valid user" >&2
	exit 1
fi
[[ -z "$STATE_PREFIX" || ! -d "$STATE_PREFIX" ]] &&
	(echo "Error, STATE_PREFIX must point to our volume" >&2 && exit 1) &&
	exit 1

function drop_privs {
	su -c "$1 $2 $3 $4 $5" - $USERNAME
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

for i in $SUBMODULES; do
	if [[ -d /i/$i ]]; then
		export PATH=/i/$i:$PATH
		if [[ -d /i/$i/lib ]]; then
			export LD_LIBRARY_PATH=/i/$i/lib:$LD_LIBRARY_PATH
			if [[ -d /i/$i/lib/python3/dist-packages ]]; then
				export PYTHONPATH=/i/$i/lib/python3/dist-packages:$PYTHONPATH
			fi
		fi
	fi
done
