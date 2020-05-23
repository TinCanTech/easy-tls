#!/bin/sh

fail ()
{
	echo "$@"
	exit 1
}

# Wrapper around printf - clobber print since it's not POSIX anyway
print() { printf "%s\n" "$*"; }

build_easyrsa ()
{

rm -f vars

mkdir -p x509-types

print "
# X509 extensions added to every signed cert

# This file is included for every cert signed, and by default does nothing.
# It could be used to add values every cert should have, such as a CDP as
# demonstrated in the following example:

#crlDistributionPoints = URI:http://example.net/pki/my_ca.crl
" > x509-types/COMMON

print "
# X509 extensions for a ca

# Note that basicConstraints will be overridden by Easy-RSA when defining a
# CA_PATH_LEN for CA path length limits. You could also do this here
# manually as in the following example in place of the existing line:
#
# basicConstraints = CA:TRUE, pathlen:1

basicConstraints = CA:TRUE
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid:always,issuer:always
keyUsage = cRLSign, keyCertSign
" > x509-types/ca

print "
# X509 extensions for a server

basicConstraints = CA:FALSE
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid,issuer:always
extendedKeyUsage = serverAuth
keyUsage = digitalSignature,keyEncipherment
" > x509-types/server

print "
# X509 extensions for a client

basicConstraints = CA:FALSE
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid,issuer:always
extendedKeyUsage = clientAuth
keyUsage = digitalSignature
" > x509-types/client
} # => build_easyrsa ()

# Create vars
build_vars ()
{
	{
	# openssl did not break this stuff diliberately, "of course".
	# NEVER use '/CN=' in these fields
		print ' set_var EASYRSA_RAND_SN "no"'
		print ' set_var EASYRSA_DN "org"'
		print '# Unsupported characters:'
		print '# `'
		print '# $'
		print '# "'
		print "# '"
		print '# #'
		print '# & (Win)'
		print ' set_var EASYRSA_REQ_COUNTRY   "00"'
		print ' set_var EASYRSA_REQ_PROVINCE  "test"'
		print ' set_var EASYRSA_REQ_CITY      "TEST ,./<>  ?;:@~  []!%^  *()-=  _+| (23) TEST"'
		print ' set_var EASYRSA_REQ_ORG       "example.org"'
		print ' set_var EASYRSA_REQ_EMAIL     "me@example.net"'
		print ' set_var EASYRSA_REQ_OU        "TEST esc \{ \} \£ \¬ (4) TEST"'
	} > vars
} # => build_vars ()

build_easyrsa

export EASYTLS_TRAVIS_CI=1

EASYRSA_CMD="./easyrsa"
EASYTLS_CMD="./easytls"
OPENVPN_CMD="./openvpn"
TLSCV2V_CMD="./tls-crypt-v2-verify.sh"
WORK_DIR="$(pwd)"
PKI_DIR="$WORK_DIR/pki"
DBUG_DIR="$WORK_DIR/pki/easytls"
LOOP_PKI=""

for loops in 1 2
do

	for i in "init-pki" "build-ca nopass" \
		"build-server-full s01 nopass" \
		"build-client-full c01 nopass" \
		"build-client-full c02 nopass" \
		"build-client-full c03 nopass" "revoke c03" \
		"build-client-full c05 nopass" \
		"build-client-full c06 nopass" \
		"build-client-full c07 nopass" \
		"--keysize=64 gen-dh" \
		## EOL
	do
		print "============================================================"
		"$EASYRSA_CMD" --batch $ERSA_LOOP_PKI $i || fail "err1: $EASYRSA_CMD --batch $ERSA_LOOP_PKI $i"
	done

	# This may be becoming unwieldy
	for i in "init-tls" "build-tls-auth" "build-tls-crypt" \
		"build-tls-crypt-v2-server s01" \
		"build-tls-crypt-v2-client s01 c01" \
		"build-tls-crypt-v2-client s01 c02 TLS crypt v2 meta data c01" \
		"--custom-group=tincantech build-tls-crypt-v2-client s01 c05" \
		"--custom-group=tincantech build-tls-crypt-v2-client s01 c06" \
		"inline-base s01 add-dh" "inline-status" "inline-renew s01 add-dh" "inline-status" "inline-remove s01" "inline-status" \
		"inline-tls-auth s01 0 add-dh" "inline-status" "inline-renew s01 add-dh" "inline-status" "inline-remove s01" "inline-status" \
		"inline-tls-auth c01 1" "inline-status" "inline-renew c01" "inline-status" "inline-remove c01" "inline-status" \
		"inline-tls-auth c01" "inline-status" "inline-renew c01" "inline-status" "inline-remove c01" "inline-status" \
		"inline-tls-crypt s01 add-dh" "inline-status" "inline-renew s01 add-dh" "inline-status" "inline-remove s01" "inline-status" \
		"inline-tls-crypt c01" "inline-status" "inline-renew c01" "inline-status" "inline-remove c01" "inline-status" \
		"inline-tls-crypt-v2 s01 add-dh" "inline-status" "inline-renew s01 add-dh" "inline-show s01" "inline-status" \
		"inline-tls-crypt-v2 c01" "inline-status" "inline-renew c01" "inline-show c01" "inline-status" \
		"inline-tls-crypt-v2 c02 nokey" "inline-status" "inline-renew c02 nokey" "inline-show c02" "inline-status" \
		"inline-tls-crypt-v2 c05" "inline-status" \
		"inline-tls-crypt-v2 c06" "inline-status" \
		"inline-index-rebuild" \
		## EOL
	do
		print "============================================================"
		echo "==> $EASYTLS_CMD $ETLS_LOOP_PKI --batch $i"
		"$EASYTLS_CMD" --batch $ETLS_LOOP_PKI $i || fail "err2: $EASYTLS_CMD --batch $ETLS_LOOP_PKI $i"
	done

	for i in "$EASYRSA_CMD --batch $ERSA_LOOP_PKI build-client-full c04 nopass" \
		"$EASYTLS_CMD --batch $ETLS_LOOP_PKI build-tls-crypt-v2-client s01 c04" \
		"$EASYTLS_CMD --batch $ETLS_LOOP_PKI inline-tls-crypt-v2 c04" \
		"$EASYRSA_CMD --batch $ERSA_LOOP_PKI revoke c04" "$EASYRSA_CMD --batch $ERSA_LOOP_PKI gen-crl" \
		"$EASYRSA_CMD --batch $ERSA_LOOP_PKI revoke c06" "$EASYRSA_CMD --batch $ERSA_LOOP_PKI gen-crl" \
		"$EASYTLS_CMD $ETLS_LOOP_PKI inline-status" "$EASYTLS_CMD $ETLS_LOOP_PKI cert-expire"
	do
		$i
	done

	print "============================================================"
	# Build a default openvpn tls-crypt-v2 client key with no metadata
	"$OPENVPN_CMD" --tls-crypt-v2 "$DBUG_DIR/s01-tls-crypt-v2.key" \
	--genkey tls-crypt-v2-client "$DBUG_DIR/c07-tls-crypt-v2.key"
	# Build a default openvpn tls-crypt-v2 client debug file with no metadata
	printf "%s" "" > "$DBUG_DIR/tls-crypt-v2-c07.mdd"
	"$EASYTLS_CMD" --batch inline-tls-crypt-v2 c07

	# Test tls-crypt-v2-verify.sh
	for c in "c01" "c05" "c06" "c07"
	do
		print "============================================================"
		echo metadata_file="$DBUG_DIR/tls-crypt-v2-${c}.mdd"
		export metadata_file="$DBUG_DIR/tls-crypt-v2-${c}.mdd"

		print "------------------------------------------------------------"
		echo "$TLSCV2V_CMD" -c="$PKI_DIR" -v -g=tincantech
		"$TLSCV2V_CMD" -c="$PKI_DIR" -v -g=tincantech
		echo "exit: $?"

		print "------------------------------------------------------------"
		echo "$TLSCV2V_CMD" -c="$PKI_DIR" -v -g=tincantech --verify-via-ca
		"$TLSCV2V_CMD" -c="$PKI_DIR" -v -g=tincantech --verify-via-ca
		echo "exit: $?"

		print "------------------------------------------------------------"
		echo "$EASYTLS_CMD" --batch disable "$c"
		"$EASYTLS_CMD" --batch disable "$c"
		echo "exit: $?"

		print "------------------------------------------------------------"
		echo "$TLSCV2V_CMD" -c="$PKI_DIR" -v -g=tincantech
		"$TLSCV2V_CMD" -c="$PKI_DIR" -v -g=tincantech
		echo "exit: $?"

		print "------------------------------------------------------------"
		echo "$TLSCV2V_CMD" -c="$PKI_DIR" -v -g=tincantech --verify-via-ca
		"$TLSCV2V_CMD" -c="$PKI_DIR" -v -g=tincantech --verify-via-ca
		echo "exit: $?"
		echo
	done
	print "============================================================"


	# Build env for next loop
	build_vars

	# Good old directory structure mallarky
	export EASYRSA_PKI="$WORK_DIR/pki2"
	PKI_DIR="$WORK_DIR/pki2"
	DBUG_DIR="$WORK_DIR/pki2/easytls"

	ETLS_LOOP_PKI="--pki-dir=$WORK_DIR/pki2"

done # => loops

# Now test a cross-polinated TCV2 key
DBUG_DIR="$WORK_DIR/pki/easytls"

	# Test tls-crypt-v2-verify.sh
	for c in "c01" "c05" "c06" "c07"
	do
		print "============================================================"
		echo metadata_file="$DBUG_DIR/tls-crypt-v2-${c}.mdd"
		export metadata_file="$DBUG_DIR/tls-crypt-v2-${c}.mdd"

		print "------------------------------------------------------------"
		echo "$TLSCV2V_CMD" -c="$PKI_DIR" -v -g=tincantech
		"$TLSCV2V_CMD" -c="$PKI_DIR" -v -g=tincantech
		echo "exit: $?"

		print "------------------------------------------------------------"
		echo "$TLSCV2V_CMD" -c="$PKI_DIR" -v -g=tincantech --verify-via-ca
		"$TLSCV2V_CMD" -c="$PKI_DIR" -v -g=tincantech --verify-via-ca
		echo "exit: $?"

		print "------------------------------------------------------------"
		echo "$EASYTLS_CMD" --batch disable "$c"
		"$EASYTLS_CMD" --batch disable "$c"
		echo "exit: $?"

		print "------------------------------------------------------------"
		echo "$TLSCV2V_CMD" -c="$PKI_DIR" -v -g=tincantech
		"$TLSCV2V_CMD" -c="$PKI_DIR" -v -g=tincantech
		echo "exit: $?"

		print "------------------------------------------------------------"
		echo "$TLSCV2V_CMD" -c="$PKI_DIR" -v -g=tincantech --verify-via-ca
		"$TLSCV2V_CMD" -c="$PKI_DIR" -v -g=tincantech --verify-via-ca
		echo "exit: $?"
		echo
	done

echo "============================================================"
echo "Completed successfully: $(date +%Y/%m/%d--%H:%M:%S)"
echo "============================================================"

exit 0
