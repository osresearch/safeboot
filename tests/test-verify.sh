#!/bin/bash
# Verify that the quote verification works
set -e -o pipefail
export LC_ALL=C

die() { echo "$@" >&2 ; exit 1 ; }
warn() { echo "$@" >&2 ; }

DIR="`dirname $0`"
export PATH="$DIR/../sbin:$DIR/../bin:$PATH"

warn "----- Good test -----"
tpm2-attest verify \
	"$DIR/quote-t490.tar" \
	"$DIR/pcrs-t490.txt" \
	abcdef \
	"$DIR/../certs" \
> /tmp/attest-good.log \
|| die "attestion verification failed"


warn "--- Wrong nonce (should fail)"
tpm2-attest verify \
	"$DIR/quote-t490.tar" \
	"$DIR/pcrs-t490.txt" \
	12345678 \
	"$DIR/../certs" \
> /tmp/attest-fail.log \
&& die "wrong nonce: attestion verification should have failed"

warn "--- Wrong PCRs (should fail)"
sed -e 's/0xC/0xD/' < "$DIR/pcrs-t490.txt" > /tmp/bad-pcrs.txt
tpm2-attest verify \
	"$DIR/quote-t490.tar" \
	"/tmp/bad-pcrs.txt" \
	abcdef \
	"$DIR/../certs" \
>> /tmp/attest-fail.log \
&& die "wrong PCRs: attestion verification should have failed"

warn "--- Missing PCR (should fail)"
( cat "$DIR/pcrs-t490.txt" ; echo "    5 : 0xC28F2726BA0A11B9FBA161419FF95BE3DA6CA9ADDC286D5FA1E1E9EC0B79DC35" ) > /tmp/bad-pcrs.txt
tpm2-attest verify \
	"$DIR/quote-t490.tar" \
	"/tmp/bad-pcrs.txt" \
	abcdef \
	"$DIR/../certs" \
>> /tmp/attest-fail.log \
&& die "missing PCR: attestion verification should have failed"

