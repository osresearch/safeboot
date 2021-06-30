# This is an include-only file. So no shebang header and no execute perms.
#
# This file (common.sh) contains definitions required within the git container
# for operating on the repository, e.g. dropping privs to the git user, taking
# and releasing the lockfile, etc. The conventions for the repository's
# directory layout and the file contents are put in a seperate file,
# common_defs.sh, which is included at the end of this file _and actually
# committed to the repo itself_. This is so that the same conventions are
# available at the attestation service side once it has cloned/merged the repo
# contents. I.e. common_defs.sh is replicated to those entities so they can
# operate on the data using the same directory and file assumptions.

set -e

# As explained in mgmt.Dockerfile, we rely on /etc/environment to pass in all
# HCP settings that matter, because priv-sep and sudo compel us not to let
# callers (URL handlers in the flask web app) game the environment of the
# callees (enrollment functions). However, that only gets sourced by non-root
# shells, and we want those settings (and everything in this file) to apply the
# same way when root. We code the Dockerfile to put the same settings in
# another file that we source here when running as root;
if [[ `whoami` == "root" ]]; then
	source /etc/environment.root
fi

echo "Running '$0'" >&2
echo "Settings passed in;" >&2
echo "   DB_PREFIX=$DB_PREFIX" >&2
echo "     DB_USER=$DB_USER" >&2
echo "  FLASK_USER=$FLASK_USER" >&2
echo " DB_IN_SETUP=$DB_IN_SETUP" >&2

# DB_PREFIX must be passed in, fail otherwise
if [[ -z "$DB_PREFIX" || ! -d "$DB_PREFIX" ]]; then
	echo "Error, DB_PREFIX (\"$DB_PREFIX\") is not a valid path" >&2
	exit 1
fi

# Ditto for $DB_USER
if [[ -z "$DB_USER" || ! -d "/home/$DB_USER" ]]; then
	echo "Error, DB_USER (\"$DB_USER\") is not a valid user" >&2
	exit 1
fi

# Ditto for $FLASK_USER
if [[ -z "$FLASK_USER" || ! -d "/home/$FLASK_USER" ]]; then
	echo "Error, FLASK_USER (\"$FLASK_USER\") is not a valid user" >&2
	exit 1
fi

REPO_NAME=enrolldb.git
EK_BASENAME=ekpubhash

REPO_PATH=$DB_PREFIX/$REPO_NAME
EK_PATH=$REPO_PATH/$EK_BASENAME
REPO_LOCKPATH=$DB_PREFIX/lock-$REPO_NAME

echo "Settings added;" >&2
echo "     REPO_NAME=$REPO_NAME" >&2
echo "   EK_BASENAME=$EK_BASENAME" >&2
echo "     REPO_PATH=$REPO_PATH" >&2
echo "       EK_PATH=$EK_PATH" >&2
echo " REPO_LOCKPATH=$REPO_LOCKPATH" >&2

function expect_root {
	if [[ `whoami` != "root" ]]; then
		echo "Error, running as \"`whoami`\" rather than \"root\"" >&2
		exit 1
	fi
}

function expect_db_user {
	if [[ `whoami` != "$DB_USER" ]]; then
		echo "Error, running as \"`whoami`\" rather than \"$DB_USER\"" >&2
		exit 1
	fi
}

function expect_flask_user {
	if [[ `whoami` != "$FLASK_USER" ]]; then
		echo "Error, running as \"`whoami`\" rather than \"$FLASK_USER\"" >&2
		exit 1
	fi
}

function drop_privs_db {
	# The only thing we need to whitelist is DB_IN_SETUP (used by
	# setup_enrolldb.sh to suppress common.h's test for an existing db).
	# As such, we
	# don't have to whitelist anything here either, even though it's not a
	# privilege issue in this case.
	su --whitelist-environment DB_IN_SETUP -c "$1 $2 $3 $4 $5" - $DB_USER
}

function drop_privs_flask {
	su -c "$1 $2 $3 $4 $5" - $FLASK_USER
}

function repo_cmd_lock {
	[[ -f $REPO_LOCKPATH ]] && echo "Warning, lockfile contention" >&2
	lockfile -1 -r 5 -l 30 -s 5 $REPO_LOCKPATH
}

function repo_cmd_unlock {
	rm -f $REPO_LOCKPATH
}

# The remaining functions are in a separate file because they form part of the git
# repo itself. (So that the attestation servers, which clone and use the repo
# in a read-only capacity, always use the same assumptions.) But to avoid
# chicken and eggs, we source the original (in the root directory, put there by
# Dockerfile) rather than the copy put into the repo.

. /common_defs.sh

# Except ... we provide a reverse-lookup (hostname to ekpubhash) in a single
# file that the attestation service itself pays no attention to. We put the
# relevant definitions here (rather than common_defs.h) to emphasize this
# point.
#
# TODO: we could do much better than the following. As the size of the dataset
# grows, the adds and deletes to the reverse-lookup table will dominate, as
# will memory and file-system thrashing (due to the need to copy and filter
# copies of the table inside the critical section). As with elsewhere, we make
# do with a simple but easy-to-validate solution for now, and mark this for a
# smarter implementation when there is enough time and focus to not make a mess
# of it (and once things are running at a scale that can detect bugs).
#
# Each line of this file is a space-separated 2-tuple of;
# - the reversed hostname (per 'rev')
# - the ekpubhash (truncated to 32 characters if appropriate, i.e. to match the
#   name of the per-TPM sub-sub-sub-drectory in the ekpubhash/ directory tree).

# The initially-empty file
HN2EK_BASENAME=hn2ek
HN2EK_PATH=$REPO_PATH/$HN2EK_BASENAME
