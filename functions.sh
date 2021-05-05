#!/bin/sh
# Note that this is parsed with /bin/sh, not bash, so that
# it can work with some of the initramfs scripts.
#
# turn off "expressions don't expand in single quotes"
# and "can't follow non-constant sources"
# shellcheck disable=SC2016 disable=SC1090 disable=SC1091
export LC_ALL=C

die_msg=""
die() { echo "$die_msg""$*" >&2 ; exit 1 ; }
warn() { echo "$@" >&2 ; }
debug() { [ "$VERBOSE" = 1 ] && echo "$@" >&2 ; }


########################################
#
# Temporary directory in $TMP.
# It will be removed when the script exits.
#
# mount_tmp can be used to create a tempfs filesystem
# so that the secrets do not ever touch a real disk.
#
########################################

TMP=$(mktemp -d)
TMP_MOUNT=n
cleanup() {
	if [ "$TMP_MOUNT" = "y" ]; then
		warn "$TMP: Unmounting"
		umount "$TMP" || die "DANGER: umount $TMP failed. Secrets might be exposed."
	fi
	rm -rf "$TMP"
}

trap cleanup EXIT

mount_tmp() {
	mount -t tmpfs none "$TMP" \
	|| die "Unable to mount temp directory"

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
if [ -z "$TPM2" ]; then
	warn "tpm2 program not found! things will probably break"
fi

# if the TPM2 resource manager is running, talk to it.
# otherwise use a direct connection to the TPM
if ! pidof tpm2-abrmd > /dev/null ; then
	[[ -v TPM2TOOLS_TCTI ]] || export TPM2TOOLS_TCTI="device:/dev/tpmrm0"
fi


tpm2() {
	if [ "$VERBOSE" = 1 ]; then
		/usr/bin/time -f '%E %C' "$TPM2" "$@"
	else
		"$TPM2" "$@"
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

# Create the TPM policy for sealing/unsealing the disk encryption key
# If an optional argument is provided, use that for the PCR data
# If an second optional argument is provided, use that for the version counter file
# If the environment TPM_SESSION_TYPE is set, that will be passed into
# the createauthsession (usually only needed for unsealing)
tpm2_create_policy()
{
	PCR_FILE="$1"
	if [ -n "$2" ]; then
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

	if [ "$SEAL_PIN" = "1" ]; then
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

	if [ -n "$TPM_POLICY_SIG" ]; then
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
	if [ -z "$1" ]; then
		die "efivar: variable name required"
	fi
	if ! mount | grep -q "$EFIVARDIR" ; then
		mount -t efivarfs none "$EFIVARDIR" \
		|| die "$EFIVARDIR: unable to mount"
	fi

	var="$EFIVARDIR/$1"
}

efivar_write() {
	efivar_setup "$1"
	chattr -i "$var"

	echo "07 00 00 00" | hex2bin > "$TMP/efivar.bin"
	cat - >> "$TMP/efivar.bin"
	#xxd -g1 "$TMP/efivar.bin"

	warn "$var: writing new value"
	cat "$TMP/efivar.bin" > "$var"
}

efivar_read() {
	efivar_setup "$1"
	cat "$var" | tail -c +5
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
	if [ -z "$entry" ]; then
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

	if [ -z "$dev" ]; then
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

