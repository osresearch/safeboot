#!/bin/bash
#
# turn off "expressions don't expand in single quotes"
# and "can't follow non-constant sources"
# shellcheck disable=SC2016 disable=SC1090 disable=SC1091
export LC_ALL=C

die_msg=""
die() { echo "${PROG:+${PROG}: }$die_msg""$*" >&2 ; exit 1 ; }
warn() { echo "$@" >&2 ; }
error() { echo "$@" >&2 ; return 1 ; }
info() { ((${VERBOSE:-0})) && echo "$@" >&2 ; return 0 ; }
debug() { ((${VERBOSE:-0}>1)) && echo "$@" >&2 ; return 0 ; }


########################################
#
# Temporary directory in $TMP.
# It will be removed when the script exits.
#
# mount_tmp can be used to create a tempfs filesystem
# so that the secrets do not ever touch a real disk.
#
########################################

TMP=
TMP_MOUNT=n
cleanup() {
	if [[ $TMP_MOUNT = "y" ]]; then
		warn "$TMP: Unmounting"
		umount "$TMP" || die "DANGER: umount $TMP failed. Secrets might be exposed."
	fi
	[[ -n $TMP ]] && rm -rf "$TMP"
}

trap cleanup EXIT
TMP=$(mktemp -d)

mount_tmp() {
	mount -t tmpfs none "$TMP" || die "Unable to mount temp directory"
	chmod 700 "$TMP"
	TMP_MOUNT=y
}


########################################
#
# Hex to raw binary and back.
# These all read from stdin and write to stdout
#
########################################

hex2bin() { xxd -p -r ; }
bin2hex() { xxd -p ; }
sha256() { sha256sum - | cut -d' ' -f1 ; }

########################################
#
# TPM2 helpers
#
########################################

PCR_DEFAULT=0000000000000000000000000000000000000000000000000000000000000000

TPM2="$(command -v tpm2 || true)"
[[ -z $TPM2 ]] && warn "tpm2 program not found! things will probably break"
[[ $TPM2 = tpm2 ]] && TPM2="command tpm2"

# if the TPM2 resource manager is running, talk to it.
# otherwise use a direct connection to the TPM
if ! pidof tpm2-abrmd > /dev/null ; then
	if [[ ! -v TPM2TOOLS_TCTI ]]; then
		true
	elif [[ -b /dev/tpmrm0 || -c /dev/tpmrm0 || -p /dev/tpmrm0 ]]; then
		export TPM2TOOLS_TCTI="device:/dev/tpmrm0"
	fi
fi

tpm2() {
	if ((${VERBOSE:-0} > 2)); then
		# shellcheck disable=SC2086
		/usr/bin/time -f '%E %C' ${TPM2#command } "$@"
	else
		$TPM2 "$@"
	fi
}

#
# Compute the extended value of a PCR register
# Expects an ASCII hex digest for the initial value,
# and a binary data on stdin to be hashed.
#
# Can be chained:
# tpm2_trial_extend $(tpm2_trial_extend 0 < measure1) < measure2
#
tpm2_trial_extend() {
	initial="$1"
	if [ "0" = "$initial" ]; then
		initial="$PCR_DEFAULT"
	fi

	newhash="$(sha256)"
	printf "%s" "$initial$newhash" | hex2bin | sha256
}

#
# Extend a PCR with a value from stdin
#
tpm2_extend() {
	pcr="$1"
	newhash="$(sha256)"
	tpm2 pcrextend "$pcr:sha256=$newhash"
}


tpm2_flushall() {
	tpm2 flushcontext \
		--transient-object \
	|| die "tpm2_flushcontext: unable to flush transient handles"

	tpm2 flushcontext \
		--loaded-session \
	|| die "tpm2_flushcontext: unable to flush sessions"

	tpm2 flushcontext \
		--saved-session \
	|| die "tpm2_flushcontext: unable to flush saved session"
}

# Don't flush saved sessions.
tpm2_flushsome() {
	tpm2 flushcontext \
		--transient-object \
	|| die "tpm2_flushcontext: unable to flush transient handles"

	tpm2 flushcontext \
		--loaded-session \
	|| die "tpm2_flushcontext: unable to flush sessions"
}

# Create the TPM policy for sealing/unsealing the disk encryption key
# If an optional argument is provided, use that for the PCR data
# If an second optional argument is provided, use that for the version counter file
# If the environment TPM_SESSION_TYPE is set, that will be passed into
# the createauthsession (usually only needed for unsealing)
tpm2_create_policy()
{
	local PCR_FILE="$1"
	local VERSION

	if (($# > 1)); then
		VERSION="$2"
		warn "Using TPM counter $VERSION"
	else
		VERSION="0123456789abcdef"
		warn "Using placeholder TPM counter version"
	fi

	tpm2_flushall

	tpm2 loadexternal \
		--key-algorithm rsa \
		--hierarchy o \
		--public "${CERT/.pem/.pub}" \
		--key-context "$TMP/key.ctx" \
		--name "$TMP/key.name" \
		>> /tmp/tpm.log \
	|| die "Unable to load platform public key into TPM"

	tpm2 startauthsession \
		${TPM_SESSION_TYPE:+ --"${TPM_SESSION_TYPE}-session" } \
		--session "$TMP/session.ctx" \
		>> /tmp/tpm.log \
	|| die "Unable to start TPM auth session"

	tpm2 policypcr \
		--session "$TMP/session.ctx" \
		--pcr-list "sha256:$PCRS,$BOOTMODE_PCR" \
		${PCR_FILE:+ --pcr "$PCR_FILE" } \
		--policy "$TMP/pcr.policy" \
		>> /tmp/tpm.log \
	|| die "Unable to create PCR policy"

	if [[ $SEAL_PIN = 1 ]]; then
		# Add an Auth Value policy, which will require the PIN for unsealing
		tpm2 policyauthvalue \
			--session "$TMP/session.ctx" \
			--policy "$TMP/pcr.policy" \
			>> /tmp/tpm.log \
		|| die "Unable to create auth value policy"
	fi

	printf "%s" "$VERSION" | hex2bin | \
	tpm2 policynv \
		--session "$TMP/session.ctx" \
		"$TPM_NV_VERSION" eq \
		--input "-" \
		--policy "$TMP/pcr.policy" \
		>> /tmp/tpm.log \
	|| die "Unable to create version policy"

	if [[ -n $TPM_POLICY_SIG ]]; then
		tpm2 verifysignature \
			--hash-algorithm sha256 \
			--scheme rsassa \
			--key-context "$TMP/key.ctx" \
			--message "$TMP/pcr.policy" \
			--signature "$TPM_POLICY_SIG" \
			--ticket "$TMP/pcr.policy.tkt" \
			>> /tmp/tpm.log \
		|| die "Unable to verify PCR signature"
	fi

	tpm2 policyauthorize \
		--session "$TMP/session.ctx" \
		--name "$TMP/key.name" \
		--input "$TMP/pcr.policy" \
		--policy "$TMP/signed.policy" \
		${TPM_POLICY_SIG:+ --ticket "$TMP/pcr.policy.tkt" } \
		>> /tmp/tpm.log \
	|| die "Unable to create authorized policy"
}


########################################
#
# EFI boot manager and variable functions
#
########################################

EFIVARDIR="/sys/firmware/efi/efivars"

efivar_setup() {
	if [[ -z ${1:-} ]]; then
		die "efivar: variable name required"
	fi
	if ! mount | grep -q "$EFIVARDIR" ; then
		mount -t efivarfs none "$EFIVARDIR" \
		|| die "$EFIVARDIR: unable to mount"
	fi

	var="$EFIVARDIR/$1"
}

efivar_write() {
	efivar_setup "${1:-}"
	chattr -i "$var"

	echo "07 00 00 00" | hex2bin > "$TMP/efivar.bin"
	cat - >> "$TMP/efivar.bin"
	#xxd -g1 "$TMP/efivar.bin"

	warn "$var: writing new value"
	cat "$TMP/efivar.bin" > "$var"
}

efivar_read() {
	efivar_setup "${1:-}"
	tail -c +5 < "$var"
}

efiboot_entry() {
	TARGET=${1:-recovery}

	# output looks like "Boot0001* linux" or "Boot0015  recovery"
	efibootmgr \
	| awk "/^Boot[0-9A-F]+. ${TARGET}\$/ { print substr(\$1,5,4) }"
}

efi_bootnext()
{
	TARGET="$1"

	# Find the recovery entry in the efibootmgr
	entry=$(efiboot_entry "${TARGET}")
	if [[ -z $entry ]]; then
		die "${TARGET} boot entry not in efibootmgr?"
	fi

	warn "${TARGET}: boot mode $entry"
	efibootmgr --bootnext "$entry" \
		|| die "Boot$entry: unable to set bootnext"
}


########################################
#
# Filesystem mounting / unmounting functions
#
########################################

mount_by_uuid() {
	partition="$1"
	fstab="${2:-/etc/fstab}"
	dev="$(awk "/^[^#]/ { if (\$2 == \"$partition\") print \$1 }" "$fstab" )"

	if [[ -z $dev ]]; then
		warn "$partition: Not found in $fstab"
		return 0
	fi

	case "$dev" in
		UUID=*)
			mount "/dev/disk/by-uuid/${dev#UUID=}" "$partition"
			;;
		/dev/*)
			mount "$dev" "$partition"
			;;
		*)
			die "$partition: unknown dev $dev"
			;;
	esac
}

# Convert a bare RSA public key (2048 bits) in PEM format to TPM2B_PUBLIC
# format.
#
# We don't yet have a good tool for this conversion.  See
# https://github.com/tpm2-software/tpm2-tools/issues/2779
#
# So this is a hack.

pem2tpm2bpublic() {
	local pemfile ekpolicy
	local attrs

	if [[ $1 = *.pem ]]; then
		pemfile=$1
	else
		cp "$1" "${1}.pem"
		pemfile=${1}.pem
	fi

	# This is the policy on the EKs produced by swtpm.  It may be different
	# on other TPMs.
	ekpolicy=${3:-837197674484b3f81a90cc8d46a5d724fd52d76e06520b64f2a1da1b331469aa}

	attrs='fixedtpm|fixedparent|sensitivedataorigin|adminwithpolicy|restricted|decrypt'

	tpm2 flushcontext --transient-object
	tpm2 flushcontext --loaded-session

	# Try loading the EK using a feature in newer tpm2-tools.
	#
	# The hash of the resulting EKpub will match IFF we have the right
	# ${ekpolicy}.
	echo "$ekpolicy" | hex2bin > "${pemfile}.policy"
	if tpm2 loadexternal				\
		--key-alg rsa2048:aes128cfb		\
		--policy "${pemfile}.policy"		\
		--attributes "$attrs"			\
		--hierarchy n				\
		--public "$pemfile"			\
		--key-context "${1}.ctx"		\
	   && tpm2 readpublic				\
			--output="$2"			\
			--object-context="${1}.ctx"; then
		rm "${pemfile}.policy"
		return 0
	fi

	# This is the TPM2B_PUBLIC of some random 2048 RSA EKpub.
	#
	# We'll overwrite the 2048 bit RSA key at the end with the key from the
	# PEM.
	xxd -p -r > "$2" <<EOF
013a0001000b000300b20020837197674484b3f81a90cc8d46a5d724fd52
d76e06520b64f2a1da1b331469aa00060080004300100800000000000100
d5c9e6201735bf4e3b6a4355f67aee0fbe8a22b5ee446693a33d15a6d05a
4c411ed4f61d013c1fe96fdd8dd44862522c5f51a304b346d7f081421f4c
d0cbec55f8ec57ab632bf023e584388be2b957512fa3df6bff3a51e92201
95e38ad3f837f6941582ee968d9a936e29240f1a7018a81e39d8e38e8826
f761160c9aed97800b2cd8ebe0eaa6eef3716232be0efe29f7a1f84256b3
2fc6c3803201edcf8d0ce33e4e1fe22a61cdd05752beaee094c1ca4ff981
25e20c200802da94771760bf7e481518fb438a9f98a5ed9286cc014836ca
bab6d2b19200d7fd105d69c74528ea37d1b8f17964c93695ecead0bbfd14
27e6bc2f7ee8bbb94638266e05f953a1
EOF
	tpm2 flushcontext --transient-object
	tpm2 flushcontext --loaded-session
	# Load the public key with the wrong attributes (see
	# https://github.com/tpm2-software/tpm2-tools/issues/2779)
	tpm2 loadexternal		\
		--key-alg rsa		\
		--attributes 'decrypt'	\
		--hierarchy n		\
		--public "$pemfile"	\
		--key-context "${1}.ctx"
	# Get the modulus of the loaded public key and overwrite the one from
	# the TPM2B_PUBLIC hard-coded above:
	tpm2 readpublic --object-context "${1}.ctx"		\
	| grep '^rsa:'						\
	| cut -d\  -f2						\
	| xxd -p -r						\
	| dd of="$2" seek=$((316 - 256)) bs=1 count=256 2>/dev/null
}

_rand() {
	if ${USE_TPM2_RAND:-true}; then
		tpm2 getrandom "${1:-32}" 2>/dev/null || openssl rand "${1:-32}"
	elif ${USE_OPENSSL_RAND:-true}; then
		openssl rand "${1:-32}" 2>/dev/null || tpm2 getrandom "${1:-32}"
	elif [[ -c /dev/urandom ]]; then
		dd if=/dev/urandom bs="${1:-32}" count=1 2>/dev/null
	else
		tpm2 getrandom "${1:-32}" 2>/dev/null || openssl rand "${1:-32}"
	fi
}

# Authenticated encryption: confounded AES-256-CBC with HMAC-SHA-256.
#
# Confounded means that a block of entropy is prefixed to the plaintext.
# Kerberos does something similar, but with ciphertext stealing mode (CTS)
# instead of CBC (CTS is based on CBC).  The use of a confounder means we can
# use a zero IV, and that we don't need xxd(1) on the decrypt side, possibly
# making it easier to use aead_decrypt in initramfs.
#
# This construction is safe to use with the same key repeatedly, though that is
# not the intent in Safeboot.dev.
#
# OpenSSL really should have a command to do something like this.
#
# $1 may be a regular file, a socket, a pipe, /dev/stdin;
# $2 must be a regular file (seekable);
# $3 may be a regular file, a socket, a pipe, /dev/stdout.
aead_encrypt() {
	local plaintext_file="$1"
	local key_file="$2"
	local ciphertext_file="$3"
	local mackey

	mackey=$(sha256 < "$key_file")

	(_rand 16; cat "$plaintext_file") \
	| openssl enc -aes-256-cbc					\
		      -e						\
		      -nosalt						\
		      -kfile "$key_file"				\
		      -iv 00000000000000000000000000000000 2>/dev/null	\
	|
	(tee >(openssl dgst -mac HMAC			\
			     -macopt hexkey:"$mackey"	\
			     -binary) ) > "$ciphertext_file"
}

# Authenticated decryption counterpart to aead_encrypt.
#
# OpenSSL really should have a command to do something like this.
#
# $1 and $2 must be regular files (seekable);
# $3 may be a regular file or a socket or tty or device.
#
# (Making it so $1 can be not-seekable is a pain.  It'd be a lot easier if this
# was written in Rust, C, or Python.)
aead_decrypt() {
	local ciphertext_file="$1"
	local key_file="$2"
	local plaintext_file="$3"
	local mackey sz

	mackey=$(sha256 < "$key_file")
	sz=$(stat -c '%s' "$ciphertext_file")

	# We add 16 bytes of confounder and 32 bytes of HMAC; OpenSSL will add
	# some padding
	((sz >= 48)) || error "ciphertext file too short" || return 1

	# Extract the MAC, compute the MAC as it should be, compare the two
	# (this complex cmp invocation means we don't need temp files, so no
	# cleanup either)
	if cmp <(dd if="$ciphertext_file"				\
		    iflag=skip_bytes					\
		    skip=$((sz - 32))					\
		    bs=32						\
		    count=1 2>/dev/null)				\
	       <(dd if="$ciphertext_file"				\
		    bs=$((sz - 32))					\
		    count=1 2>/dev/null					\
		 | openssl dgst -mac HMAC				\
				-macopt hexkey:"$mackey"		\
				-binary); then
		dd if="$ciphertext_file"				\
		   bs=$((sz - 32))					\
		   count=1 2>/dev/null					\
		| openssl enc -aes-256-cbc				\
			      -d					\
			      -nosalt					\
			      -kfile "$key_file"			\
			      -iv 00000000000000000000000000000000	\
			      2>/dev/null				\
		| dd iflag=skip_bytes					\
		     skip=16						\
		     of="$plaintext_file" 2>/dev/null
	else
		die "MAC does not match"
	fi
}

indent() {
	local depth=$((${depth:-0} + 1))

	while ((depth > 0)); do printf '    '; ((depth--)); done
}

# subexp_length POLICY...
#
# Returns the number of arguments making up a policy expression.  The caller
# will presumably shift those into an array and exec that sub-policy.
#
# See {exec_policy} for details on {POLICY}.
subexp_length() {
	local -n nv="$1"
	local i depth=0 startswithparen=false
	shift

	nv=0
	for i in "$@"; do
		((++nv))
		if [[ $i = '(' ]]; then
			((nv == 1)) && startswithparen=true
			((++depth))
		elif [[ $i = ')' ]]; then
			((depth--)) || true
			if ((depth == 0)) && $startswithparen; then
				return 0;
			fi
		fi
		((depth < 0)) && die "Missing open parenthesis in policy expression: $*"
		((depth == 0)) && [[ $i = ';' ]] && return 0
	done
	((depth == 0)) || die "Missing close parenthesis in policy expression: $*"
	return 0;
}

# exec_policy SESSIONCTX POLICYDAT [ALTERNATIVES] POLICY...
#
# Starts a policy session {SESSIONCTX} and executes the given {POLICY} in that
# session, leaving the final policyDigest for the {POLICY} in {POLICYDAT}.
#
# {SESSIONCTX} is the name of a saved session context file.
#
# {POLICYDAT} is the name of a file into which to write the POLICY's digest.
#
# {ALTERNATIVES} is zero, one, or more integers 0 through 9 that are indices of
# policy alternations in the {POLICY} that are to be executed.
#
# {POLICY} starts with an optional command-code and is followed by
# {tpm2 policy*} command-lines as arguments, w/o any {--session}|{-c} or
# {--policy|-L} arguments.  Multiple policy commands may be given, separated by
# {';'}.
#
#	[TPM2_CC_*] tpm2 policy* ... ';' tpm2 policy* ... ';' ...
#
# {tpm2 policyor} command-lines are special: the alternatives must be given as
# separate arguments, either as a {POLICY} in parenthesis, or as policy
# digests:
#
#	exec_policy sess pol tpm2 policyor '(' POLICY0 ')' '(' POLICY1 ')' ...
#	exec_policy sess pol tpm2 policyor $digest0 $digest1 ...
#	exec_policy sess pol tpm2 policyor '(' POLICY0 ')' $digest1...
#
# Do not specify a command-code if the {POLICY} includes any {tpm2 policyor}
# commands.
#
# The output of this function is the digest of the {POLICYDAT} as it stands at
# the end of {POLICY} execution.
#
# Simple policy example (no alternation):
#
#	exec_policy sp p TPM2_CC_ActivateCredential ';'		\
#	    tpm2 policysecret --object-context endorsement
#
# Complex example (alternation):
#
#	# Compute digest of a policy that allows signing and decryption to
#	# applications with access to the endorsement hierarchy:
#	exec_policy sp p						\
#	    tpm2 policyor						\
#		'(' tpm2 policycommandcode TPM2_CC_Sign ')'		\
#		'(' tpm2 policycommandcode TPM2_CC_RSA_Decrypt ')' ';'	\
#		tpm2 policysecret --object-context endorsement
#
#	# Execute the same policy to sign:
#	exec_policy 1 sp p						\
#	    tpm2 policyor						\
#		'(' tpm2 policycommandcode TPM2_CC_Sign ')'		\
#		'(' tpm2 policycommandcode TPM2_CC_RSA_Decrypt ')' ';'	\
#		tpm2 policysecret --object-context endorsement
#
#	# Execute the same policy to decrypt:
#	exec_policy 1 sp p						\
#	    tpm2 policyor						\
#		'(' tpm2 policycommandcode TPM2_CC_Sign ')'		\
#		'(' tpm2 policycommandcode TPM2_CC_RSA_Decrypt ')' ';'	\
#		tpm2 policysecret --object-context endorsement
exec_policy() {
	local -a alternatives rm_policies
	local depth=0 session policy
	local trial=true

	session=$1
	policy=$2
	shift 2

	# Use a dynamic variable to keep track of alternatives.
	rm_policies=()
	alternatives=()
	while (($# > 0)) && [[ $1 = @([0-9]) ]]; do
		alternatives+=("$1")
		shift
	done

	debug "$(indent)Running (in trial session): exec_policy_helper $*"
	tpm2_flushsome
	tpm2 startauthsession --session "$session"
	exec_policy_helper "$@"

	debug "$(indent)Running (in policy session): exec_policy_helper $*"
	tpm2_flushsome
	tpm2 startauthsession --session "$session"	\
		--policy-session
	trial=false
	exec_policy_helper "$@"

	rm -f "${rm_policies[@]}"
}

# make_policyDigest SESSIONCTX POLICYDAT [ALTERNATIVES] POLICY...
#
# Compute the policyDigest of a given {POLICY} by executing it in a trial
# session, {SESSIONCTX}.  The policyDigest will be placed in {POLICYDAT}
# (binary) and will be output on stdout (hex-encoded).
#
# See {exec_policy} for details on {POLICY}.
make_policyDigest() {
	local -a alternatives rm_policies
	local depth=0 session policy
	local trial=true

	session=$1
	policy=$2
	shift 2

	(($# > 0)) && [[ $1 = [0-9]* ]] &&	\
	warn "Ignoring alternation alternatives to take when computing policyDigest"
	while (($# > 0)) && [[ $1 = [0-9]* ]]; do
		shift
	done

	rm -f "$policy"
	rm_policies=()
	alternatives=()
	debug "$(indent)Running (in trial session): exec_policy_helper $*"
	tpm2_flushsome
	tpm2 startauthsession --session "$session"
	exec_policy_helper "$@"
	rm -f "${rm_policies[@]}"
}

# exec_policy_helper POLICY...
exec_policy_helper() {
	local command_code=''
	local add_commandcode=true
	local has_policy=false
	local subexp_length
	local -a cmd

	(($# == 0)) && return 0

	if [[ -z $1 || $1 = TPM2_CC_* ]]; then
		command_code=$1
		shift
	fi
	while (($# > 0)); do
		cmd=()
		subexp_length=0
		has_policy=true
		subexp_length subexp_length "$@"

		[[ "${*:$subexp_length:1}" = ';' ]] && ((subexp_length--))
		if ((subexp_length > 0)) && [[ $1 = tpm2_* ]]; then
			if [[ $1 = tpm2_policyor ]]; then
				cmd=(exec_policyOR_helper)
			else
				cmd=("$1" --session "$session"
					  --policy "$policy")
			fi
			((subexp_length--)) || true
			shift
		elif ((subexp_length > 1)) && [[ $1 = tpm2 ]]; then
			if [[ $2 = policyor ]]; then
				cmd=(exec_policyOR_helper)
			else
				cmd=("$1" "$2" --session "$session"
					       --policy "$policy")
			fi
			((subexp_length -= 2)) || true
			shift 2
		fi

		# Build ONE tpm2 policy* command-line (or exec_policyOR_helper)
		cmd+=("${@:1:$subexp_length}")
		shift "$subexp_length"
		if [[ ${cmd[0]} = exec_policyOR_helper ]]; then
			add_commandcode=false
		fi
		(($# > 0)) && [[ $1 = ';' ]] && shift

		# Run the policy command in the temp dir.  It -or the last command- must
		# leave a file there named 'policy'.
		info "$(indent)Running: (AND) ${cmd[*]}"
		"${cmd[@]}" 1>&2					\
		|| die "unable to execute policy command: ${cmd[*]}"
		[[ ${cmd[0]} = tpm2 ]] && ((${#cmd[@]} == 1))		\
		&& die "Policy is incomplete"
		[[ ${cmd[0]} = tpm2 && ${cmd[1]} = policycommandcode ]]	\
		&& add_commandcode=false
		[[ ${cmd[0]} = tpm2_policycommandcode ]]		\
		&& add_commandcode=false
	done
	if $has_policy && $add_commandcode && [[ -n $command_code ]]; then
		info "$(indent)Running: (AND) tpm2 policycommandcode --session $session --policy $policy $command_code"
		tpm2 policycommandcode			\
			--session "$session"	\
			--policy "$policy"	\
			"$command_code" 1>&2		\
		|| die "unable to execute policy command: tpm2 policycommandcode $command_code"
	fi
	xxd -p -c 100 "$policy"
}

exec_policyOR_helper() {
	local npolicies=0
	local subexp_length alt doit=false
	local altsession='' altpolicy=''
	local -a policyDigests
	local -a policies
	local -a cmd

	# The alternative to take, if any
	alt=${alternatives[$depth]:-"-1"}
	policyDigests=()
	policies=()
	cmd=()

	$trial || ((alt >= 0))	\
	|| die "Missing alternatives at expression depth $depth"

	while (($# > 0)); do
		if [[ $1 = ';' ]]; then
			break
		fi
		subexp_length=0
		altsession="${session}-${depth}-${npolicies}"
		altpolicy="${policy}-${depth}-${npolicies}"
		policies+=("$altpolicy")
		((++depth))
		if [[ $1 = '(' ]]; then
			if ! $trial && ((alt == npolicies)); then
				# Execute this sub-policy in the main, policy
				# session
				altsession=$session
				debug "$(indent)Using policy session $altsession"
				doit=true
			elif ! $trial && [[ -f $altpolicy ]]; then
				debug "$(indent)Using previously computed policyDigest for sub-expression"
				doit=false
			else
				# Execute this sub-policy in a trial session
				debug "$(indent)Starting trial session $altsession"
				debug "$(indent)-- trial=$trial altpolicy=$altpolicy"
				tpm2 startauthsession --session "$altsession"
				doit=true
			fi
			# Count the number of arguments for this
			# sub-expression.  (Includes the two parens.)
			subexp_length subexp_length "$@"
			shift # open paren
			((subexp_length -= 2)) || true # open and close parens

			# Build command-line
			cmd=(exec_policy_helper "${@:1:$subexp_length}")
			shift "$subexp_length"
			shift # close paren

			if $doit; then
				# Run it (changing the $session and $policy seen by the
				# command-line)
				debug "$(indent)Running: (OR) ${cmd[*]}"
				session="$altsession"	\
				policy="$altpolicy"	\
				"${cmd[@]}"
			fi

			# Cleanup
			if $trial || ((alt != npolicies)); then
				# Reduce our burden on the TPM by flushing this
				# trial session
				[[ -f $altsession ]] && tpm2 flushcontext "$altsession"
				rm -f "$altsession"
			fi
		elif [[ ${#1} == 64 && $1 = +([0-9a-fA-F]) ]]; then
			# Alternative given as SHA-256 digest
			echo "$1" | xxd -p -r > "${policy}-${depth}-$npolicies"
			shift
		elif [[ -f $1 ]] && (($(stat -c %s "$1") == 32)); then
			# Alternative given as policy SHA-256 digest (binary) file
			cp "$1" "${policy}-${depth}-$npolicies"
			shift
		else
			die "Invalid policyor alternative"
		fi
		policyDigests+=("$(xxd -p -c 100 "$altpolicy")")
		((++npolicies))
		((depth--))
	done
	IFS=",$IFS"
	set -- "${policies[*]}"
	IFS="${IFS#,}"
	info "$(indent)ORing: ${policyDigests[*]}"
	info "$(indent)Running: tpm2 policyor --session $session --policy $policy sha256:$1"
	tpm2 policyor --session "$session"	\
		      --policy  "$policy"	\
		      sha256:"$1"

	# We leave these around so that we can first compute the
	# policies in trial sessions then use a single policy session to
	# evaluate the taken alternatives:
	rm_policies+=("${policies[@]}")
}

# A well-known private key just for the TPM2_MakeCredential()-based encryption
# of secrets to TPMs.  It was generated with:
#  openssl genpkey -genparam					\
#                  -algorithm EC				\
#                  -out ecp.pem					\
#                  -pkeyopt ec_paramgen_curve:secp384r1		\
#                  -pkeyopt ec_param_enc:named_curve
#  openssl genpkey -paramfile ecp.pem
#
#  This key is NEVER used for signing or key exchange (therefore also not for
#  encryption).  It is only ever used for constructing activation objects whose
#  cryptographic names will be bound by TPM2_MakeCredential() into its outputs.
wkpriv() {
	cat <<"EOF"
-----BEGIN PRIVATE KEY-----
MIG2AgEAMBAGByqGSM49AgEGBSuBBAAiBIGeMIGbAgEBBDAlMnCWue7CfXjNLibH
PTJrsOLUcoxqU3FLWYEWMI+HuPnzcwwl7SkKN6cpf4H3oQihZANiAAQ1pw6D5QVw
vymljYVDyrUriOet8zPB/9tq9XJ7A54qsVkaVufAuEJ6GIvD4xUZ27manMosJADS
aW2TLJkwxecRh2eTwPtSx2U32M2/yHeuWRV/0juiIozefPsTAlHAi3E=
-----END PRIVATE KEY-----
EOF
}
