#!/bin/sh

fail ()
{
	echo "$@"
	exit 1
}

expected_errors ()
{
	[ $1 -eq 99 ] && exit 99
	total_expected_errors=$((total_expected_errors + 1))
	[ $SHALLOW ] && return 0
	printf '%s ' "PRESS ENTER TO CONTINUE"
	read input
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

echo '===[  Easy-TLS Unit Tests ]==='

build_easyrsa

EASYRSA_CMD="./easyrsa"
EASYRSA_OPTS="--batch"

EASYTLS_CMD="./easytls"
EASYTLS_OPTS="--verbose --batch --no-auto-check"

TLSCV2V_CMD="./easytls-cryptv2-verify.sh"
TLSCV2V_OPTS="-v"

WORK_DIR="$(pwd)"


if [ $OS ]
then
	export OPENVPN_CMD="./openvpn.exe"
else
	if [ -f ./openvpn ]
	then
		export OPENVPN_CMD=./openvpn
	else
		export OPENVPN_CMD=/usr/sbin/openvpn
	fi
fi
[ -f "$OPENVPN_CMD" ] || fail "Cannot find: $OPENVPN_CMD"

export EASYRSA_CERT_RENEW=1000

total_expected_errors=0

for loops in 1 2 3
do

	PKI_DIR="${WORK_DIR}/et-tdir${loops}"
	ETLS_DIR="${PKI_DIR}/easytls"
	DBUG_DIR="${ETLS_DIR}/metadata"
	export EASYRSA="$WORK_DIR"
	export EASYRSA_PKI="$PKI_DIR"
	print "EASYRSA_PKI: $EASYRSA_PKI"

	# Build vars, used by all remaining loops
	#[ $loops -eq 2 ] && exit 99
	[ $loops -eq 2 ] && build_vars
	#[ $loops -eq 3 ] && exit 99
	[ $loops -eq 3 ] && {
		export EASYRSA_RAND_SN="yes"
		EASYTLS_OPTS="--verbose --batch --no-auto-check"
		TLSCV2V_OPTS="-v --hash=SHA1"
		}

	export EASYRSA_REQ_CN="easytls"
	# Setup EasyRSA
	print "ls -l"
	ls -l
	"$EASYRSA_CMD" $EASYRSA_OPTS init-pki
	print "ls -l $EASYRSA_PKI"
	ls -l "$EASYRSA_PKI"
	for i in "build-ca nopass" \
		"build-server-full s01 nopass" \
		"build-server-full s02 nopass" \
		"build-client-full c01 nopass" \
		"build-client-full c02 nopass" \
		"build-client-full c03 nopass" "revoke c03" \
		"build-client-full c05 nopass" \
		"build-client-full c06 nopass" \
		"build-client-full c07-nomd nopass" \
		"build-client-full c08 nopass" \
		"build-client-full c09 nopass" \
		"build-client-full c10 nopass" \
		"build-client-full cw01 nopass" \
		"--keysize=64 gen-dh" \
		## EOL
	do
		print "============================================================"
		print "$EASYRSA_CMD $EASYRSA_OPTS $i"
		"$EASYRSA_CMD" $EASYRSA_OPTS $i || fail "Unit test error 1: $EASYRSA_CMD $EASYRSA_OPTS $i"
	done

	#rm "$PKI_DIR/private/ca.key" || Die "fk"

	# Test EasyTLS
	for i in "init-tls" "config"\
		"build-tls-auth" "build-tls-crypt" \
		"build-tls-crypt-v2-server s01" \
		"--inline --custom-group=tincantech build-tls-crypt-v2-server s02" \
		"build-tls-crypt-v2-client s01 c01" \
		"--custom-group=tincantech build-tls-crypt-v2-client s01 c02" \
		"--custom-group=tincantech build-tls-crypt-v2-client s01 c05" \
		"--custom-group=tincantech build-tls-crypt-v2-client s01 c06" \
		"--custom-group=tincantech build-tls-crypt-v2-client s01 c08" \
		"--custom-group=tincantech \
			build-tls-crypt-v2-client s01 c09 ef1234567890 1234567890fe" \
		"--custom-group=tincantech --sub-key-name=bob \
			build-tls-crypt-v2-client s01 c09 ef1234567890 1234567890fe" \
		"--inline --custom-group=tincantech --sub-key-name=office \
			build-tls-crypt-v2-client s01 c10 abcdefabcdef 123456543210" \
		"--custom-group=tincantech inline-tls-auth s01 0 add-dh" \
		"remove-inline s01" \
		"--custom-group=tincantech inline-tls-auth c01 1" \
		"remove-inline c01" \
		"--custom-group=tincantech inline-tls-crypt s01 add-dh" \
		"remove-inline s01" \
		"--custom-group=tincantech inline-tls-crypt c01" \
		"remove-inline c01" \
		"--custom-group=tincantech inline-tls-crypt-v2 s01 add-dh" \
		"inline-tls-crypt-v2 c01" \
		"--custom-group=tincantech inline-tls-crypt-v2 c02 nokey" \
		"--custom-group=tincantech inline-tls-crypt-v2 c05" \
		"disable c05" \
		"enable c05" \
		"--custom-group=tincantech inline-tls-crypt-v2 c06" \
		"--custom-group=tincantech inline-tls-crypt-v2 c08" \
		"--custom-group=tincantech inline-tls-crypt-v2 c09 add-hw" \
		"--custom-group=tincantech --sub-key-name=bob inline-tls-crypt-v2 c09 add-hw" \
		"--custom-group=tincantech --sub-key-name=eve \
			build-tls-crypt-v2-client s01 c10 ef1234567890 1234567890fe" \
		"--custom-group=tincantech --sub-key-name=eve \
			inline-tls-crypt-v2 c10 add-hw" \
		"--custom-group=tincantech --sub-key-name=eve remove-inline c10" \
		"--custom-group=tincantech --sub-key-name=eve remove-tlskey c10" \
		"cert-expire" \
		"inline-expire" \
		#"inline-index-rebuild" \
		## EOL
	do
		test_cmd="$i"
		[ $loops -eq 2 ] && [ "$test_cmd" = "init-tls" ] && \
			EASYTLS_OPTS="--verbose --batch --no-auto-check -y"
		[ $loops -eq 3 ] && [ "$test_cmd" = "init-tls" ] && {
			test_cmd="$test_cmd SHA1"
			EASYTLS_OPTS="--verbose --batch --no-auto-check"
			}
		print "============================================================"
		echo "==> $EASYTLS_CMD $EASYTLS_OPTS $test_cmd"

		# EasyOut
		#[ "$test_cmd" = "Planned break" ] && [ $loops -eq 2 ] && fail "Planned break"
		#[ "$test_cmd" = "Planned break" ] && echo "Planned break" && continue

		#if [ "$test_cmd" = "remove-inline s01" ]
		#then
		#	cat "${ETLS_DIR}/s01.inline"
		#fi

		"$EASYTLS_CMD" $EASYTLS_OPTS $test_cmd || \
		fail "Unit test error 2: $EASYTLS_CMD $EASYTLS_OPTS $test_cmd"

	done

	# Create some certs out of order - These are intended to break EasyTLS
	# Renew c08, which completely breaks EasyTLS
	for i in "$EASYRSA_CMD $EASYRSA_OPTS build-client-full c04 nopass" \
		"$EASYTLS_CMD $EASYTLS_OPTS build-tls-crypt-v2-client s01 c04" \
		"$EASYTLS_CMD $EASYTLS_OPTS inline-tls-crypt-v2 c04" \
		"$EASYRSA_CMD $EASYRSA_OPTS revoke c04" \
		"$EASYRSA_CMD $EASYRSA_OPTS gen-crl" \
		"$EASYRSA_CMD $EASYRSA_OPTS revoke c06" \
		"$EASYRSA_CMD $EASYRSA_OPTS gen-crl" \
		"$EASYTLS_CMD $EASYTLS_OPTS status" \
		"$EASYTLS_CMD $EASYTLS_OPTS cert-expire" \
		"$EASYTLS_CMD $EASYTLS_OPTS status" \
		"$EASYRSA_CMD $EASYRSA_OPTS renew c08 nopass" \
		"$EASYTLS_CMD $EASYTLS_OPTS status" \
		## EOL
	do
		print "============================================================"
		print "$i"
		$i || fail "Unit test error 3: $i"
	done

	print "============================================================"
	print "Build a default openvpn tls-crypt-v2 client key with no metadata"
	"$OPENVPN_CMD" --tls-crypt-v2 "$ETLS_DIR/s01-tls-crypt-v2.key" \
		--genkey tls-crypt-v2-client "$ETLS_DIR/c07-nomd-tls-crypt-v2.key" || \
		fail "Unit test error 61: Probably the wrong directory.."

	# Easy-TLS no longer allows for keys created outside of easytls
	# Build a default openvpn tls-crypt-v2 client debug file with no metadata
	# TODO: get in the right place
	#printf "%s" "" > "$DBUG_DIR/c07-nomd-tls-crypt-v2.metadata"
	# Inline c07
	#"$EASYTLS_CMD" $EASYTLS_OPTS inline-tls-crypt-v2 c07-nomd || \
	#	fail "Unit test error 62: inline-tls-crypt-v2 c07-nomd"

	# Build a node for Windblows test
	print "============================================================"
	print "Build a Windblows tls-crypt-v2 client key with metadata"
	"$EASYTLS_CMD" $EASYTLS_OPTS \
		--custom-group=tincantech build-tls-crypt-v2-client s01 cw01 \
		 08-00-27-10-B8-D0 08:00:27:10:B8:D0 || \
		fail "Unit test error 62: build-tls-crypt-v2-client s01 cw01"

	print "============================================================"
	print "Build a Windblows inline file with metadata and hw-addr"
	"$EASYTLS_CMD" $EASYTLS_OPTS \
		--custom-group=tincantech inline-tls-crypt-v2 cw01 || \
		fail "Unit test error 62: inline-tls-crypt-v2 cw01"

	# Test tls-crypt-v2-verify.sh
	for c in "c01" "c05" "c06" "c07-nomd" "c09"
	do
		print "============================================================"
		  echo metadata_file="$DBUG_DIR/${c}-tls-crypt-v2.metadata"
		export metadata_file="$DBUG_DIR/${c}-tls-crypt-v2.metadata"

		print "------------------------------------------------------------"
		echo "$TLSCV2V_CMD" $TLSCV2V_OPTS -c="$PKI_DIR"
		     "$TLSCV2V_CMD" $TLSCV2V_OPTS -c="$PKI_DIR"
		exit_code=$?
		echo "exit: $exit_code"
		[ $exit_code -eq 0 ] || expected_errors $exit_code

		print "------------------------------------------------------------"
		echo "$TLSCV2V_CMD" $TLSCV2V_OPTS -c="$PKI_DIR" -g=tincantech
		     "$TLSCV2V_CMD" $TLSCV2V_OPTS -c="$PKI_DIR" -g=tincantech
		exit_code=$?
		echo "exit: $exit_code"
		[ $exit_code -eq 0 ] || expected_errors $exit_code

		print "------------------------------------------------------------"
		echo "$TLSCV2V_CMD" $TLSCV2V_OPTS -c="$PKI_DIR" -g=tincantech --disable-list
		     "$TLSCV2V_CMD" $TLSCV2V_OPTS -c="$PKI_DIR" -g=tincantech --disable-list
		exit_code=$?
		echo "exit: $exit_code"
		[ $exit_code -eq 0 ] || expected_errors $exit_code

		print "------------------------------------------------------------"
		echo "$TLSCV2V_CMD" $TLSCV2V_OPTS -c="$PKI_DIR" -g=tincantech --via-ca
		     "$TLSCV2V_CMD" $TLSCV2V_OPTS -c="$PKI_DIR" -g=tincantech --via-ca
		exit_code=$?
		echo "exit: $exit_code"
		[ $exit_code -eq 0 ] || expected_errors $exit_code

		print "------------------------------------------------------------"
		echo "$TLSCV2V_CMD" $TLSCV2V_OPTS -c="$PKI_DIR" -g=tincantech --via-index
		     "$TLSCV2V_CMD" $TLSCV2V_OPTS -c="$PKI_DIR" -g=tincantech --via-index
		exit_code=$?
		echo "exit: $exit_code"
		[ $exit_code -eq 0 ] || expected_errors $exit_code

		print "------------------------------------------------------------"
		echo "$TLSCV2V_CMD" $TLSCV2V_OPTS -c="$PKI_DIR" -g=tincantech --via-index --cache-id
		     "$TLSCV2V_CMD" $TLSCV2V_OPTS -c="$PKI_DIR" -g=tincantech --via-index --cache-id
		exit_code=$?
		echo "exit: $exit_code"
		[ $exit_code -eq 0 ] || expected_errors $exit_code

		print "------------------------------------------------------------"
		plcid="$(cat "$PKI_DIR/easytls/data/easytls-ca-identity.txt")"
		echo "$TLSCV2V_CMD" $TLSCV2V_OPTS -c="$PKI_DIR" -g=tincantech --via-index --preload-id="$plcid"
		     "$TLSCV2V_CMD" $TLSCV2V_OPTS -c="$PKI_DIR" -g=tincantech --via-index --preload-id="$plcid"
		exit_code=$?
		echo "exit: $exit_code"
		[ $exit_code -eq 0 ] || expected_errors $exit_code

		print "------------------------------------------------------------"
		echo "$EASYTLS_CMD" $EASYTLS_OPTS disable "$c"
		     "$EASYTLS_CMD" $EASYTLS_OPTS disable "$c"
		exit_code=$?
		echo "exit: $exit_code"
		[ $exit_code -eq 0 ] || expected_errors $exit_code

		print "------------------------------------------------------------"
		echo "$TLSCV2V_CMD" $TLSCV2V_OPTS -c="$PKI_DIR"
		     "$TLSCV2V_CMD" $TLSCV2V_OPTS -c="$PKI_DIR"
		exit_code=$?
		echo "exit: $exit_code"
		[ $exit_code -eq 0 ] || expected_errors $exit_code

		print "------------------------------------------------------------"
		echo "$TLSCV2V_CMD" $TLSCV2V_OPTS -c="$PKI_DIR" -g=tincantech
		     "$TLSCV2V_CMD" $TLSCV2V_OPTS -c="$PKI_DIR" -g=tincantech
		exit_code=$?
		echo "exit: $exit_code"
		[ $exit_code -eq 0 ] || expected_errors $exit_code

		print "------------------------------------------------------------"
		echo "$TLSCV2V_CMD" $TLSCV2V_OPTS -c="$PKI_DIR" -g=tincantech --disable-list
		     "$TLSCV2V_CMD" $TLSCV2V_OPTS -c="$PKI_DIR" -g=tincantech --disable-list
		exit_code=$?
		echo "exit: $exit_code"
		[ $exit_code -eq 0 ] || expected_errors $exit_code

		print "------------------------------------------------------------"
		echo "$TLSCV2V_CMD" $TLSCV2V_OPTS -c="$PKI_DIR" -g=tincantech --via-ca
		     "$TLSCV2V_CMD" $TLSCV2V_OPTS -c="$PKI_DIR" -g=tincantech --via-ca
		exit_code=$?
		echo "exit: $exit_code"
		[ $exit_code -eq 0 ] || expected_errors $exit_code

		print "------------------------------------------------------------"
		echo "$TLSCV2V_CMD" $TLSCV2V_OPTS -c="$PKI_DIR" -g=tincantech --via-index
		     "$TLSCV2V_CMD" $TLSCV2V_OPTS -c="$PKI_DIR" -g=tincantech --via-index
		exit_code=$?
		echo "exit: $exit_code"
		[ $exit_code -eq 0 ] || expected_errors $exit_code

		print "------------------------------------------------------------"
		echo "$TLSCV2V_CMD" $TLSCV2V_OPTS -c="$PKI_DIR" -g=tincantech --via-index --cache-id
		     "$TLSCV2V_CMD" $TLSCV2V_OPTS -c="$PKI_DIR" -g=tincantech --via-index --cache-id
		exit_code=$?
		echo "exit: $exit_code"
		[ $exit_code -eq 0 ] || expected_errors $exit_code

		print "------------------------------------------------------------"
		plcid="$(cat "$PKI_DIR/easytls/data/easytls-ca-identity.txt")"
		echo "$TLSCV2V_CMD" $TLSCV2V_OPTS -c="$PKI_DIR" -g=tincantech --via-index --preload-id="$plcid"
		     "$TLSCV2V_CMD" $TLSCV2V_OPTS -c="$PKI_DIR" -g=tincantech --via-index --preload-id="$plcid"
		exit_code=$?
		echo "exit: $exit_code"
		[ $exit_code -eq 0 ] || expected_errors $exit_code

		echo
	done

		print "============================================================"
		  echo metadata_file="$DBUG_DIR/c09-bob-tls-crypt-v2.metadata"
		export metadata_file="$DBUG_DIR/c09-bob-tls-crypt-v2.metadata"

		print "------------------------------------------------------------"
		echo "$TLSCV2V_CMD" $TLSCV2V_OPTS -c="$PKI_DIR" -g=tincantech --via-index --cache-id
		     "$TLSCV2V_CMD" $TLSCV2V_OPTS -c="$PKI_DIR" -g=tincantech --via-index --cache-id
		exit_code=$?
		echo "exit: $exit_code"
		[ $exit_code -eq 0 ] || expected_errors $exit_code

		print "------------------------------------------------------------"
		echo "$EASYTLS_CMD" --sub-key-name=bob $EASYTLS_OPTS disable "$c"
		     "$EASYTLS_CMD" --sub-key-name=bob $EASYTLS_OPTS disable "$c"
		exit_code=$?
		echo "exit: $exit_code"
		[ $exit_code -eq 0 ] || expected_errors $exit_code

		print "------------------------------------------------------------"
		echo "$TLSCV2V_CMD" $TLSCV2V_OPTS -c="$PKI_DIR" -g=tincantech --via-index --cache-id
		     "$TLSCV2V_CMD" $TLSCV2V_OPTS -c="$PKI_DIR" -g=tincantech --via-index --cache-id
		exit_code=$?
		echo "exit: $exit_code"
		[ $exit_code -eq 0 ] || expected_errors $exit_code

	print "============================================================"
	print "$EASYTLS_CMD $EASYTLS_OPTS status"
	"$EASYTLS_CMD" $EASYTLS_OPTS status || \
		fail "Unit test error 63: status"
	print "============================================================"

	print "============================================================"
	print "$EASYTLS_CMD $EASYTLS_OPTS inline-index-rebuild"
	"$EASYTLS_CMD" $EASYTLS_OPTS inline-index-rebuild || \
		fail "Unit test error 64: inline-index-rebuild"
	print "============================================================"

	print "total_expected_errors: $total_expected_errors"

done # => loops

# Now test a cross-polinated TCV2 key
printf '\n\n\n'
print "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
printf '\n\n\n%s\n\n\n' "Now test a cross-polinated TCV2 key"


###  NOTE: Hard coded directory

### EVERY TEST IS EXPECTED TO FAIL

DBUG_DIR="$WORK_DIR/et-tdir1/easytls/metadata"

	# Test tls-crypt-v2-verify.sh
	for c in "c01" "c05" "c06" "c07-nomd" "c09"
	do
		print "============================================================"
		  echo metadata_file="$DBUG_DIR/${c}-tls-crypt-v2.metadata"
		export metadata_file="$DBUG_DIR/${c}-tls-crypt-v2.metadata"

		print "------------------------------------------------------------"
		echo "$TLSCV2V_CMD" $TLSCV2V_OPTS -c="$PKI_DIR"
		     "$TLSCV2V_CMD" $TLSCV2V_OPTS -c="$PKI_DIR"
		exit_code=$?
		echo "exit: $exit_code"
		[ $exit_code -eq 0 ] && expected_errors $exit_code

		print "------------------------------------------------------------"
		echo "$TLSCV2V_CMD" $TLSCV2V_OPTS -c="$PKI_DIR" -g=tincantech
		     "$TLSCV2V_CMD" $TLSCV2V_OPTS -c="$PKI_DIR" -g=tincantech
		exit_code=$?
		echo "exit: $exit_code"
		[ $exit_code -eq 0 ] && expected_errors $exit_code

		print "------------------------------------------------------------"
		echo "$TLSCV2V_CMD" $TLSCV2V_OPTS -c="$PKI_DIR" -g=tincantech --disable-list
		     "$TLSCV2V_CMD" $TLSCV2V_OPTS -c="$PKI_DIR" -g=tincantech --disable-list
		exit_code=$?
		echo "exit: $exit_code"
		[ $exit_code -eq 0 ] && expected_errors $exit_code

		print "------------------------------------------------------------"
		echo "$TLSCV2V_CMD" $TLSCV2V_OPTS -c="$PKI_DIR" -g=tincantech --via-ca
		     "$TLSCV2V_CMD" $TLSCV2V_OPTS -c="$PKI_DIR" -g=tincantech --via-ca
		exit_code=$?
		echo "exit: $exit_code"
		[ $exit_code -eq 0 ] && expected_errors $exit_code

		print "------------------------------------------------------------"
		echo "$TLSCV2V_CMD" $TLSCV2V_OPTS -c="$PKI_DIR" -g=tincantech --via-index
		     "$TLSCV2V_CMD" $TLSCV2V_OPTS -c="$PKI_DIR" -g=tincantech --via-index
		exit_code=$?
		echo "exit: $exit_code"
		[ $exit_code -eq 0 ] && expected_errors $exit_code

		print "------------------------------------------------------------"
		echo "$TLSCV2V_CMD" $TLSCV2V_OPTS -c="$PKI_DIR" -g=tincantech --via-index --cache-id
		     "$TLSCV2V_CMD" $TLSCV2V_OPTS -c="$PKI_DIR" -g=tincantech --via-index --cache-id
		exit_code=$?
		echo "exit: $exit_code"
		[ $exit_code -eq 0 ] && expected_errors $exit_code

		print "------------------------------------------------------------"
		plcid="$(cat "$PKI_DIR/easytls/data/easytls-ca-identity.txt")"
		echo "$TLSCV2V_CMD" $TLSCV2V_OPTS -c="$PKI_DIR" -g=tincantech --via-index --preload-id="$plcid"
		     "$TLSCV2V_CMD" $TLSCV2V_OPTS -c="$PKI_DIR" -g=tincantech --via-index --preload-id="$plcid"
		exit_code=$?
		echo "exit: $exit_code"
		[ $exit_code -eq 0 ] && expected_errors $exit_code

		print "------------------------------------------------------------"
		echo "$EASYTLS_CMD" --batch disable "$c"
		     "$EASYTLS_CMD" --batch disable "$c"
		exit_code=$?
		echo "exit: $exit_code"
		[ $exit_code -eq 0 ] && expected_errors $exit_code

		print "------------------------------------------------------------"
		echo "$TLSCV2V_CMD" $TLSCV2V_OPTS -c="$PKI_DIR"
		     "$TLSCV2V_CMD" $TLSCV2V_OPTS -c="$PKI_DIR"
		exit_code=$?
		echo "exit: $exit_code"
		[ $exit_code -eq 0 ] && expected_errors $exit_code

		print "------------------------------------------------------------"
		echo "$TLSCV2V_CMD" $TLSCV2V_OPTS -c="$PKI_DIR" -g=tincantech
		     "$TLSCV2V_CMD" $TLSCV2V_OPTS -c="$PKI_DIR" -g=tincantech
		exit_code=$?
		echo "exit: $exit_code"
		[ $exit_code -eq 0 ] && expected_errors $exit_code

		print "------------------------------------------------------------"
		echo "$TLSCV2V_CMD" $TLSCV2V_OPTS -c="$PKI_DIR" -g=tincantech --disable-list
		     "$TLSCV2V_CMD" $TLSCV2V_OPTS -c="$PKI_DIR" -g=tincantech --disable-list
		exit_code=$?
		echo "exit: $exit_code"
		[ $exit_code -eq 0 ] && expected_errors $exit_code

		print "------------------------------------------------------------"
		echo "$TLSCV2V_CMD" $TLSCV2V_OPTS -c="$PKI_DIR" -g=tincantech --via-ca
		     "$TLSCV2V_CMD" $TLSCV2V_OPTS -c="$PKI_DIR" -g=tincantech --via-ca
		exit_code=$?
		echo "exit: $exit_code"
		[ $exit_code -eq 0 ] && expected_errors $exit_code

		print "------------------------------------------------------------"
		echo "$TLSCV2V_CMD" $TLSCV2V_OPTS -c="$PKI_DIR" -g=tincantech --via-index
		     "$TLSCV2V_CMD" $TLSCV2V_OPTS -c="$PKI_DIR" -g=tincantech --via-index
		exit_code=$?
		echo "exit: $exit_code"
		[ $exit_code -eq 0 ] && expected_errors $exit_code

		print "------------------------------------------------------------"
		echo "$TLSCV2V_CMD" $TLSCV2V_OPTS -c="$PKI_DIR" -g=tincantech --via-index --cache-id
		     "$TLSCV2V_CMD" $TLSCV2V_OPTS -c="$PKI_DIR" -g=tincantech --via-index --cache-id
		exit_code=$?
		echo "exit: $exit_code"
		[ $exit_code -eq 0 ] && expected_errors $exit_code

		print "------------------------------------------------------------"
		plcid="$(cat "$PKI_DIR/easytls/data/easytls-ca-identity.txt")"
		echo "$TLSCV2V_CMD" $TLSCV2V_OPTS -c="$PKI_DIR" -g=tincantech --via-index --preload-id="$plcid"
		     "$TLSCV2V_CMD" $TLSCV2V_OPTS -c="$PKI_DIR" -g=tincantech --via-index --preload-id="$plcid"
		exit_code=$?
		echo "exit: $exit_code"
		[ $exit_code -eq 0 ] && expected_errors $exit_code

		print "------------------------------------------------------------"
		plcid="$(cat "$PKI_DIR/easytls/data/easytls-ca-identity.txt")"
		echo "$TLSCV2V_CMD" $TLSCV2V_OPTS -c="$PKI_DIR" -g=tincantech --via-index --cache-id --preload-id="$plcid"
		     "$TLSCV2V_CMD" $TLSCV2V_OPTS -c="$PKI_DIR" -g=tincantech --via-index --cache-id --preload-id="$plcid"
		exit_code=$?
		echo "exit: $exit_code"
		[ $exit_code -eq 0 ] && expected_errors $exit_code

		echo
	done

	EASYTLS_OPTS="--verbose --batch"
	print "============================================================"
	print "$EASYTLS_CMD $EASYTLS_OPTS status"
	"$EASYTLS_CMD" $EASYTLS_OPTS status || \
		fail "Unit test error 65: status"
	print "============================================================"



	# This last rebuild over writes the backup from prior to making+revoke c04+c06
	rm "$WORK_DIR/et-tdir3/easytls/data/easytls-inline-index.txt.backup"
	rm "$WORK_DIR/et-tdir3/easytls/data/easytls-inline-index.hash.backup"
	print "============================================================"
	print "$EASYTLS_CMD $EASYTLS_OPTS inline-index-rebuild"
	"$EASYTLS_CMD" $EASYTLS_OPTS inline-index-rebuild || \
		fail "Unit test error 4: $EASYTLS_CMD $EASYTLS_OPTS $UNITTEST_SECURE inline-index-rebuild"

	print "------------------------------------------------------------"
	print "$EASYTLS_CMD $EASYTLS_OPTS cert-expire (also test auto-check)"
	"$EASYTLS_CMD" $EASYTLS_OPTS cert-expire || \
		fail "Unit test error 66: cert-expire"

	print "------------------------------------------------------------"
	print "$EASYTLS_CMD $EASYTLS_OPTS inline-expire (also test auto-check)"
	"$EASYTLS_CMD" $EASYTLS_OPTS inline-expire || \
		fail "Unit test error 67: inline-expire"

	print "------------------------------------------------------------"
	print "$EASYTLS_CMD $EASYTLS_OPTS --sub-key-name=office remove-inline c10"
	"$EASYTLS_CMD" $EASYTLS_OPTS --sub-key-name=office remove-inline c10 || \
		fail "Unit test error 68: remove-inline"

	print "------------------------------------------------------------"
	print "$EASYTLS_CMD $EASYTLS_OPTS --sub-key-name=office remove-tlskey c10"
	"$EASYTLS_CMD" $EASYTLS_OPTS --sub-key-name=office remove-tlskey c10 || \
		fail "Unit test error 68: remove-tlskey"

	print "------------------------------------------------------------"
	print "$EASYTLS_CMD $EASYTLS_OPTS help"
	"$EASYTLS_CMD" $EASYTLS_OPTS help || \
		fail "Unit test error 68: help"

	print "------------------------------------------------------------"
	print "$EASYTLS_CMD $EASYTLS_OPTS help options"
	"$EASYTLS_CMD" $EASYTLS_OPTS help options || \
		fail "Unit test error 69: help"

	print "------------------------------------------------------------"
	print "$EASYTLS_CMD $EASYTLS_OPTS help build-tls-crypt-v2-client"
	"$EASYTLS_CMD" $EASYTLS_OPTS help build-tls-crypt-v2-client || \
		fail "Unit test error 70: help"

	print "------------------------------------------------------------"
	print "$EASYTLS_CMD $EASYTLS_OPTS help import-key"
	"$EASYTLS_CMD" $EASYTLS_OPTS help import-key || \
		fail "Unit test error 70: help"

	print "------------------------------------------------------------"
	print "$EASYTLS_CMD $EASYTLS_OPTS help abb"
	"$EASYTLS_CMD" $EASYTLS_OPTS help abb || \
		fail "Unit test error 70: help"

	print "------------------------------------------------------------"
	print "$EASYTLS_CMD $EASYTLS_OPTS help config"
	"$EASYTLS_CMD" $EASYTLS_OPTS help config || \
		fail "Unit test error 70: help"

	print "------------------------------------------------------------"
	print "$EASYTLS_CMD $EASYTLS_OPTS config"
	"$EASYTLS_CMD" $EASYTLS_OPTS config || \
		fail "Unit test error 70: help"

	print "------------------------------------------------------------"
	TEST_CMD="disabled-list-rehash"
	print "$EASYTLS_CMD $EASYTLS_OPTS $TEST_CMD"
	"$EASYTLS_CMD" $EASYTLS_OPTS $TEST_CMD || \
		fail "Unit test error 72: $TEST_CMD"

	print "------------------------------------------------------------"
	print "$EASYTLS_CMD $EASYTLS_OPTS version"
	"$EASYTLS_CMD" $EASYTLS_OPTS version || \
		fail "Unit test error 71: version"

echo "============================================================"
echo "total_expected_errors=$total_expected_errors (Expected 165 Verified)"
echo "Completed successfully: $(date +%Y/%m/%d--%H:%M:%S)"
echo "============================================================"
echo
[ $total_expected_errors -eq 165 ] || {
	echo "Expected ERROR count incorrect!"
	exit 9
	}
exit 0
