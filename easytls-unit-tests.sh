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
EASYRSA_OPTS="--batch"

EASYTLS_CMD="./easytls"
EASYTLS_OPTS="--verbose --batch --disable-auto-check"

OPENVPN_CMD="./openvpn"
TLSCV2V_CMD="./tls-crypt-v2-verify.sh"
TLSCV2V_OPTS="--verbose"
WORK_DIR="$(pwd)"


export EASYTLS_OPENVPN=./openvpn
export EASYRSA_CERT_RENEW=10000

total_expected_errors=0

for loops in 1 2 3
do

	PKI_DIR="${WORK_DIR}/pki${loops}"
	ETLS_DIR="$WORK_DIR/pki${loops}/easytls"
	DBUG_DIR="$WORK_DIR/pki${loops}/easytls"
	export EASYRSA_PKI="$PKI_DIR"

	# Build vars, used by all remaining loops
	[ $loops -eq 2 ] && build_vars

	# Setup EasyRSA
	for i in "init-pki" "build-ca nopass" \
		"build-server-full s01 nopass" \
		"build-client-full c01 nopass" \
		"build-client-full c02 nopass" \
		"build-client-full c03 nopass" "revoke c03" \
		"build-client-full c05 nopass" \
		"build-client-full c06 nopass" \
		"build-client-full c07 nopass" \
		"build-client-full c08 nopass" \
		"--keysize=64 gen-dh" \
		## EOL
	do
		print "============================================================"
		"$EASYRSA_CMD" $EASYRSA_OPTS $i || fail "Unit test error 1: $EASYRSA_CMD $EASYRSA_OPTS $i"
	done

	# Test EasyTLS
	for i in "init-tls" "build-tls-auth" "build-tls-crypt" \
		"save-id" \
		"build-tls-crypt-v2-server s01" \
		"build-tls-crypt-v2-client s01 c01" \
		"build-tls-crypt-v2-client s01 c02 TLS crypt v2 meta data c01" \
		"--custom-group=tincantech build-tls-crypt-v2-client s01 c05" \
		"--custom-group=tincantech build-tls-crypt-v2-client s01 c06" \
		"--custom-group=tincantech build-tls-crypt-v2-client s01 c08" \
		"inline-base s01 add-dh" "status" "inline-renew s01 add-dh" "status" \
		"inline-remove s01" "status" \
		"inline-tls-auth s01 0 add-dh" "status" "inline-renew s01 add-dh" "status" \
		"inline-remove s01" "status" \
		"inline-tls-auth c01 1" "status" "inline-renew c01" "status" \
		"inline-remove c01" "status" \
		"inline-tls-auth c01" "status" "inline-renew c01" "status" \
		"inline-remove c01" "status" \
		"inline-tls-crypt s01 add-dh" "status" "inline-renew s01 add-dh" "status" \
		"inline-remove s01" "status" \
		"inline-tls-crypt c01" "status" "inline-renew c01" "status" \
		"inline-remove c01" "status" \
		"inline-tls-crypt-v2 s01 add-dh" "status" \
		"inline-renew s01 add-dh" "inline-show s01" "status" \
		"inline-tls-crypt-v2 c01" "status" \
		"inline-renew c01" "inline-show c01" "status" \
		"inline-tls-crypt-v2 c02 nokey" "status" \
		"inline-renew c02 nokey" "inline-show c02" "status" \
		"inline-tls-crypt-v2 c05" "status" "disable c05" \
		"enable c05" \
		"inline-tls-crypt-v2 c06" "status" \
		"inline-tls-crypt-v2 c08" "status" \
		"cert-expire" \
		"inline-expire" \
		#"inline-index-rebuild" \
		## EOL
	do
		print "============================================================"
		echo "==> $EASYTLS_CMD $EASYTLS_OPTS $i"

		# EasyOut
		[ "$i" = "Planned break" ] && fail "Planned break"

		if [ "$i" = "status" ]
		then
			echo "Skipped status"
		else
			"$EASYTLS_CMD" $EASYTLS_OPTS $i || fail "Unit test error 2: $EASYTLS_CMD $EASYTLS_OPTS $i"
		fi
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
		--genkey tls-crypt-v2-client "$ETLS_DIR/c07-tls-crypt-v2.key" || \
		fail "Unit test error 61: Probably the wrong directory.."

	# Build a default openvpn tls-crypt-v2 client debug file with no metadata
	# TODO: get in the right place
	printf "%s" "" > "$DBUG_DIR/tls-crypt-v2-c07.mdd"
	# Inline c07
	"$EASYTLS_CMD" $EASYTLS_OPTS inline-tls-crypt-v2 c07 || \
		fail "Unit test error 62: inline-tls-crypt-v2 c07"

	# Test tls-crypt-v2-verify.sh
	for c in "c01" "c05" "c06" "c07"
	do
		print "============================================================"
		  echo metadata_file="$DBUG_DIR/tls-crypt-v2-${c}.mdd"
		export metadata_file="$DBUG_DIR/tls-crypt-v2-${c}.mdd"

		print "------------------------------------------------------------"
		echo "$TLSCV2V_CMD" $TLSCV2V_OPTS -c="$PKI_DIR" -g=tincantech
		     "$TLSCV2V_CMD" $TLSCV2V_OPTS -c="$PKI_DIR" -g=tincantech
		exit_code=$?
		[ $exit_code -eq 0 ] || total_expected_errors=$((total_expected_errors + 1))
		echo "exit: $exit_code"

		print "------------------------------------------------------------"
		echo "$TLSCV2V_CMD" $TLSCV2V_OPTS -c="$PKI_DIR" -g=tincantech --hex-check
		     "$TLSCV2V_CMD" $TLSCV2V_OPTS -c="$PKI_DIR" -g=tincantech --hex-check
		exit_code=$?
		[ $exit_code -eq 0 ] || total_expected_errors=$((total_expected_errors + 1))
		echo "exit: $exit_code"

		print "------------------------------------------------------------"
		echo "$TLSCV2V_CMD" $TLSCV2V_OPTS -c="$PKI_DIR" -g=tincantech --disable-list
		     "$TLSCV2V_CMD" $TLSCV2V_OPTS -c="$PKI_DIR" -g=tincantech --disable-list
		exit_code=$?
		[ $exit_code -eq 0 ] || total_expected_errors=$((total_expected_errors + 1))
		echo "exit: $exit_code"

		print "------------------------------------------------------------"
		echo "$TLSCV2V_CMD" $TLSCV2V_OPTS -c="$PKI_DIR" -g=tincantech --verify-via-ca
		     "$TLSCV2V_CMD" $TLSCV2V_OPTS -c="$PKI_DIR" -g=tincantech --verify-via-ca
		exit_code=$?
		[ $exit_code -eq 0 ] || total_expected_errors=$((total_expected_errors + 1))
		echo "exit: $exit_code"

		print "------------------------------------------------------------"
		echo "$TLSCV2V_CMD" $TLSCV2V_OPTS -c="$PKI_DIR" -g=tincantech --verify-via-index
		     "$TLSCV2V_CMD" $TLSCV2V_OPTS -c="$PKI_DIR" -g=tincantech --verify-via-index
		exit_code=$?
		[ $exit_code -eq 0 ] || total_expected_errors=$((total_expected_errors + 1))
		echo "exit: $exit_code"

		print "------------------------------------------------------------"
		echo "$TLSCV2V_CMD" $TLSCV2V_OPTS -c="$PKI_DIR" -g=tincantech --verify-via-index --cache-id
		     "$TLSCV2V_CMD" $TLSCV2V_OPTS -c="$PKI_DIR" -g=tincantech --verify-via-index --cache-id
		exit_code=$?
		[ $exit_code -eq 0 ] || total_expected_errors=$((total_expected_errors + 1))
		echo "exit: $exit_code"

		print "------------------------------------------------------------"
		plcid="$(cat "$PKI_DIR/easytls/easytls-ca-identity.txt")"
		echo "$TLSCV2V_CMD" $TLSCV2V_OPTS -c="$PKI_DIR" -g=tincantech --verify-via-index --preload-cache-id="$plcid"
		     "$TLSCV2V_CMD" $TLSCV2V_OPTS -c="$PKI_DIR" -g=tincantech --verify-via-index --preload-cache-id="$plcid"
		exit_code=$?
		[ $exit_code -eq 0 ] || total_expected_errors=$((total_expected_errors + 1))
		echo "exit: $exit_code"

		print "------------------------------------------------------------"
		echo "$EASYTLS_CMD" $EASYTLS_OPTS disable "$c"
		     "$EASYTLS_CMD" $EASYTLS_OPTS disable "$c"
		exit_code=$?
		[ $exit_code -eq 0 ] || total_expected_errors=$((total_expected_errors + 1))
		echo "exit: $exit_code"

		print "------------------------------------------------------------"
		echo "$TLSCV2V_CMD" $TLSCV2V_OPTS -c="$PKI_DIR" -g=tincantech
		     "$TLSCV2V_CMD" $TLSCV2V_OPTS -c="$PKI_DIR" -g=tincantech
		exit_code=$?
		[ $exit_code -eq 0 ] || total_expected_errors=$((total_expected_errors + 1))
		echo "exit: $exit_code"

		print "------------------------------------------------------------"
		echo "$TLSCV2V_CMD" $TLSCV2V_OPTS -c="$PKI_DIR" -g=tincantech --hex-check
		     "$TLSCV2V_CMD" $TLSCV2V_OPTS -c="$PKI_DIR" -g=tincantech --hex-check
		exit_code=$?
		[ $exit_code -eq 0 ] || total_expected_errors=$((total_expected_errors + 1))
		echo "exit: $exit_code"

		print "------------------------------------------------------------"
		echo "$TLSCV2V_CMD" $TLSCV2V_OPTS -c="$PKI_DIR" -g=tincantech --disable-list
		     "$TLSCV2V_CMD" $TLSCV2V_OPTS -c="$PKI_DIR" -g=tincantech --disable-list
		exit_code=$?
		[ $exit_code -eq 0 ] || total_expected_errors=$((total_expected_errors + 1))
		echo "exit: $exit_code"

		print "------------------------------------------------------------"
		echo "$TLSCV2V_CMD" $TLSCV2V_OPTS -c="$PKI_DIR" -g=tincantech --verify-via-ca
		     "$TLSCV2V_CMD" $TLSCV2V_OPTS -c="$PKI_DIR" -g=tincantech --verify-via-ca
		exit_code=$?
		[ $exit_code -eq 0 ] || total_expected_errors=$((total_expected_errors + 1))
		echo "exit: $exit_code"

		print "------------------------------------------------------------"
		echo "$TLSCV2V_CMD" $TLSCV2V_OPTS -c="$PKI_DIR" -g=tincantech --verify-via-index
		     "$TLSCV2V_CMD" $TLSCV2V_OPTS -c="$PKI_DIR" -g=tincantech --verify-via-index
		exit_code=$?
		[ $exit_code -eq 0 ] || total_expected_errors=$((total_expected_errors + 1))
		echo "exit: $exit_code"

		print "------------------------------------------------------------"
		echo "$TLSCV2V_CMD" $TLSCV2V_OPTS -c="$PKI_DIR" -g=tincantech --verify-via-index --cache-id
		     "$TLSCV2V_CMD" $TLSCV2V_OPTS -c="$PKI_DIR" -g=tincantech --verify-via-index --cache-id
		exit_code=$?
		[ $exit_code -eq 0 ] || total_expected_errors=$((total_expected_errors + 1))
		echo "exit: $exit_code"

		print "------------------------------------------------------------"
		plcid="$(cat "$PKI_DIR/easytls/easytls-ca-identity.txt")"
		echo "$TLSCV2V_CMD" $TLSCV2V_OPTS -c="$PKI_DIR" -g=tincantech --verify-via-index --preload-cache-id="$plcid"
		     "$TLSCV2V_CMD" $TLSCV2V_OPTS -c="$PKI_DIR" -g=tincantech --verify-via-index --preload-cache-id="$plcid"
		exit_code=$?
		[ $exit_code -eq 0 ] || total_expected_errors=$((total_expected_errors + 1))
		echo "exit: $exit_code"

		echo
	done
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

done # => loops

# Now test a cross-polinated TCV2 key
printf '\n\n\n'
print "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
printf '\n\n\n%s\n\n\n' "Now test a cross-polinated TCV2 key"
DBUG_DIR="$WORK_DIR/pki1/easytls"

	# Test tls-crypt-v2-verify.sh
	for c in "c01" "c05" "c06" "c07"
	do
		print "============================================================"
		  echo metadata_file="$DBUG_DIR/tls-crypt-v2-${c}.mdd"
		export metadata_file="$DBUG_DIR/tls-crypt-v2-${c}.mdd"

		print "------------------------------------------------------------"
		echo "$TLSCV2V_CMD" $TLSCV2V_OPTS -c="$PKI_DIR" -g=tincantech
		     "$TLSCV2V_CMD" $TLSCV2V_OPTS -c="$PKI_DIR" -g=tincantech
		exit_code=$?
		[ $exit_code -eq 0 ] || total_expected_errors=$((total_expected_errors + 1))
		echo "exit: $exit_code"

		print "------------------------------------------------------------"
		echo "$TLSCV2V_CMD" $TLSCV2V_OPTS -c="$PKI_DIR" -g=tincantech --hex-check
		     "$TLSCV2V_CMD" $TLSCV2V_OPTS -c="$PKI_DIR" -g=tincantech --hex-check
		exit_code=$?
		[ $exit_code -eq 0 ] || total_expected_errors=$((total_expected_errors + 1))
		echo "exit: $exit_code"

		print "------------------------------------------------------------"
		echo "$TLSCV2V_CMD" $TLSCV2V_OPTS -c="$PKI_DIR" -g=tincantech --disable-list
		     "$TLSCV2V_CMD" $TLSCV2V_OPTS -c="$PKI_DIR" -g=tincantech --disable-list
		exit_code=$?
		[ $exit_code -eq 0 ] || total_expected_errors=$((total_expected_errors + 1))
		echo "exit: $exit_code"

		print "------------------------------------------------------------"
		echo "$TLSCV2V_CMD" $TLSCV2V_OPTS -c="$PKI_DIR" -g=tincantech --verify-via-ca
		     "$TLSCV2V_CMD" $TLSCV2V_OPTS -c="$PKI_DIR" -g=tincantech --verify-via-ca
		exit_code=$?
		[ $exit_code -eq 0 ] || total_expected_errors=$((total_expected_errors + 1))
		echo "exit: $exit_code"

		print "------------------------------------------------------------"
		echo "$TLSCV2V_CMD" $TLSCV2V_OPTS -c="$PKI_DIR" -g=tincantech --verify-via-index
		     "$TLSCV2V_CMD" $TLSCV2V_OPTS -c="$PKI_DIR" -g=tincantech --verify-via-index
		exit_code=$?
		[ $exit_code -eq 0 ] || total_expected_errors=$((total_expected_errors + 1))
		echo "exit: $exit_code"

		print "------------------------------------------------------------"
		echo "$TLSCV2V_CMD" $TLSCV2V_OPTS -c="$PKI_DIR" -g=tincantech --verify-via-index --cache-id
		     "$TLSCV2V_CMD" $TLSCV2V_OPTS -c="$PKI_DIR" -g=tincantech --verify-via-index --cache-id
		exit_code=$?
		[ $exit_code -eq 0 ] || total_expected_errors=$((total_expected_errors + 1))
		echo "exit: $exit_code"

		print "------------------------------------------------------------"
		plcid="$(cat "$PKI_DIR/easytls/easytls-ca-identity.txt")"
		echo "$TLSCV2V_CMD" $TLSCV2V_OPTS -c="$PKI_DIR" -g=tincantech --verify-via-index --preload-cache-id="$plcid"
		     "$TLSCV2V_CMD" $TLSCV2V_OPTS -c="$PKI_DIR" -g=tincantech --verify-via-index --preload-cache-id="$plcid"
		exit_code=$?
		[ $exit_code -eq 0 ] || total_expected_errors=$((total_expected_errors + 1))
		echo "exit: $exit_code"

		print "------------------------------------------------------------"
		echo "$EASYTLS_CMD" --batch disable "$c"
		     "$EASYTLS_CMD" --batch disable "$c"
		exit_code=$?
		[ $exit_code -eq 0 ] || total_expected_errors=$((total_expected_errors + 1))
		echo "exit: $exit_code"

		print "------------------------------------------------------------"
		echo "$TLSCV2V_CMD" $TLSCV2V_OPTS -c="$PKI_DIR" -g=tincantech
		     "$TLSCV2V_CMD" $TLSCV2V_OPTS -c="$PKI_DIR" -g=tincantech
		exit_code=$?
		[ $exit_code -eq 0 ] || total_expected_errors=$((total_expected_errors + 1))
		echo "exit: $exit_code"

		print "------------------------------------------------------------"
		echo "$TLSCV2V_CMD" $TLSCV2V_OPTS -c="$PKI_DIR" -g=tincantech --hex-check
		     "$TLSCV2V_CMD" $TLSCV2V_OPTS -c="$PKI_DIR" -g=tincantech --hex-check
		exit_code=$?
		[ $exit_code -eq 0 ] || total_expected_errors=$((total_expected_errors + 1))
		echo "exit: $exit_code"

		print "------------------------------------------------------------"
		echo "$TLSCV2V_CMD" $TLSCV2V_OPTS -c="$PKI_DIR" -g=tincantech --disable-list
		     "$TLSCV2V_CMD" $TLSCV2V_OPTS -c="$PKI_DIR" -g=tincantech --disable-list
		exit_code=$?
		[ $exit_code -eq 0 ] || total_expected_errors=$((total_expected_errors + 1))
		echo "exit: $exit_code"

		print "------------------------------------------------------------"
		echo "$TLSCV2V_CMD" $TLSCV2V_OPTS -c="$PKI_DIR" -g=tincantech --verify-via-ca
		     "$TLSCV2V_CMD" $TLSCV2V_OPTS -c="$PKI_DIR" -g=tincantech --verify-via-ca
		exit_code=$?
		[ $exit_code -eq 0 ] || total_expected_errors=$((total_expected_errors + 1))
		echo "exit: $exit_code"

		print "------------------------------------------------------------"
		echo "$TLSCV2V_CMD" $TLSCV2V_OPTS -c="$PKI_DIR" -g=tincantech --verify-via-index
		     "$TLSCV2V_CMD" $TLSCV2V_OPTS -c="$PKI_DIR" -g=tincantech --verify-via-index
		exit_code=$?
		[ $exit_code -eq 0 ] || total_expected_errors=$((total_expected_errors + 1))
		echo "exit: $exit_code"

		print "------------------------------------------------------------"
		echo "$TLSCV2V_CMD" $TLSCV2V_OPTS -c="$PKI_DIR" -g=tincantech --verify-via-index --cache-id
		     "$TLSCV2V_CMD" $TLSCV2V_OPTS -c="$PKI_DIR" -g=tincantech --verify-via-index --cache-id
		exit_code=$?
		[ $exit_code -eq 0 ] || total_expected_errors=$((total_expected_errors + 1))
		echo "exit: $exit_code"

		print "------------------------------------------------------------"
		plcid="$(cat "$PKI_DIR/easytls/easytls-ca-identity.txt")"
		echo "$TLSCV2V_CMD" $TLSCV2V_OPTS -c="$PKI_DIR" -g=tincantech --verify-via-index --preload-cache-id="$plcid"
		     "$TLSCV2V_CMD" $TLSCV2V_OPTS -c="$PKI_DIR" -g=tincantech --verify-via-index --preload-cache-id="$plcid"
		exit_code=$?
		[ $exit_code -eq 0 ] || total_expected_errors=$((total_expected_errors + 1))
		echo "exit: $exit_code"

		print "------------------------------------------------------------"
		plcid="$(cat "$PKI_DIR/easytls/easytls-ca-identity.txt")"
		echo "$TLSCV2V_CMD" $TLSCV2V_OPTS -c="$PKI_DIR" -g=tincantech --verify-via-index --cache-id --preload-cache-id="$plcid"
		     "$TLSCV2V_CMD" $TLSCV2V_OPTS -c="$PKI_DIR" -g=tincantech --verify-via-index --cache-id --preload-cache-id="$plcid"
		exit_code=$?
		[ $exit_code -eq 0 ] || total_expected_errors=$((total_expected_errors + 1))
		echo "exit: $exit_code"

		echo
	done

	EASYTLS_OPTS="--verbose --batch"
	print "============================================================"
	print "$EASYTLS_CMD $EASYTLS_OPTS status"
	"$EASYTLS_CMD" $EASYTLS_OPTS status || \
		fail "Unit test error 65: status"
	print "============================================================"

	# This last rebuild over writes the backup from prior to making+revoke c04+c06
	#rm "$WORK_DIR/pki2/easytls/easytls-inline-index.txt.backup"
	#print "============================================================"
	#print "$EASYTLS_CMD $EASYTLS_OPTS inline-index-rebuild"
	#"$EASYTLS_CMD" $EASYTLS_OPTS inline-index-rebuild || \
	#	fail "Unit test error 4: $EASYTLS_CMD $EASYTLS_OPTS $UNITTEST_SECURE inline-index-rebuild"

	print "------------------------------------------------------------"
	print "$EASYTLS_CMD $EASYTLS_OPTS cert-expire (also test auto-check)"
	"$EASYTLS_CMD" $EASYTLS_OPTS cert-expire || \
		fail "Unit test error 66: cert-expire"

	print "------------------------------------------------------------"
	print "$EASYTLS_CMD $EASYTLS_OPTS inline-expire (also test auto-check)"
	"$EASYTLS_CMD" $EASYTLS_OPTS inline-expire || \
		fail "Unit test error 67: inline-expire"

	print "------------------------------------------------------------"
	print "$EASYTLS_CMD $EASYTLS_OPTS help"
	"$EASYTLS_CMD" $EASYTLS_OPTS help || \
		fail "Unit test error 68: help"

	print "------------------------------------------------------------"
	print "$EASYTLS_CMD $EASYTLS_OPTS help options"
	"$EASYTLS_CMD" $EASYTLS_OPTS help options || \
		fail "Unit test error 69: help"

	print "------------------------------------------------------------"
	print "$EASYTLS_CMD $EASYTLS_OPTS help import-key"
	"$EASYTLS_CMD" $EASYTLS_OPTS help import-key || \
		fail "Unit test error 70: help"

	print "------------------------------------------------------------"
	print "$EASYTLS_CMD $EASYTLS_OPTS version"
	"$EASYTLS_CMD" $EASYTLS_OPTS version || \
		fail "Unit test error 71: version"

	print "------------------------------------------------------------"
	TEST_CMD="disabled-list-rehash"
	print "$EASYTLS_CMD $EASYTLS_OPTS $TEST_CMD"
	"$EASYTLS_CMD" $EASYTLS_OPTS $TEST_CMD || \
		fail "Unit test error 72: $TEST_CMD"

echo "============================================================"
echo "total_expected_errors=$total_expected_errors (Expected 208 Verified)"
echo "Completed successfully: $(date +%Y/%m/%d--%H:%M:%S)"
echo "============================================================"
echo
exit 0
