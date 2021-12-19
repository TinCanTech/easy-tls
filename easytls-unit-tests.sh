#!/bin/sh

EASYTLS_VERSION="2.7.0"

# Copyright - negotiable
copyright ()
{
: << VERBATUM_COPYRIGHT_HEADER_INCLUDE_NEGOTIABLE
# easytls-cryptv2-client-connect.sh -- Do simple magic
#
# Copyright (C) 2020 Richard Bonhomme (Friday 13th of March 2020)
# https://github.com/TinCanTech/easy-tls
# tincantech@protonmail.com
# All Rights reserved.
#
# This code is released under version 2 of the GNU GPL
# See LICENSE of this project for full licensing details.
#
# Acknowledgement:
# syzzer: https://github.com/OpenVPN/openvpn/blob/master/doc/tls-crypt-v2.txt
#
# Lock client connections to specific client devices.
#
VERBATUM_COPYRIGHT_HEADER_INCLUDE_NEGOTIABLE
}

fail ()
{
	echo "$@"
	exit 1
}

expected_errors ()
{
	[ $1 -eq 99 ] && exit 99
	subtot_expected_errors=$((subtot_expected_errors + 1))
	echo "** subtot_expected_errors $subtot_expected_errors"
	total_expected_errors=$((total_expected_errors + 1))
	[ $SHALLOW ] && return 0
	printf '%s ' "PRESS ENTER TO CONTINUE"
	read input
}

clean_up ()
{
	[ -n "${EASYTLS_tmp_dir}" ] && [ "${EASYTLS_tmp_dir}" != "/" ] && \
		rm -rfv "${EASYTLS_tmp_dir}"/*
}
# Wrapper around printf - clobber print since it's not POSIX anyway
print() { printf "%s\n" "$*"; }

build_easyrsa ()
{

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
	} > "$EASYTLS_VARS"
} # => build_vars ()

echo '===[  Easy-TLS Unit Tests ]==='

start_time="$(date +%s)"

export DISABLE_KILL_PPID=1

WORK_DIR="$(pwd)"
#mkdir -p "${WORK_DIR}/unit-test" || fail "Cannot create: ${WORK_DIR}/unit-test"

EASYRSA_CMD="./easyrsa"
EASYRSA_OPTS="--batch"

EASYTLS_CMD="./easytls"
EASYTLS_OPTS="--verbose --batch"

TLSCV2V_CMD="./easytls-cryptv2-verify.sh"
TLSCV2V_OPTS="-v"

TLSVERIFY_CMD="./easytls-verify.sh"
TLSVERIFY_OPTS="-v"

CLICON_CMD="./easytls-client-connect.sh"
CLICON_OPTS="-v"

export ENABLE_TLSKEY_HASH=1

# Identify Windows
EASYRSA_KSH='@(#)MIRBSD KSH R39-w32-beta14 $Date: 2013/06/28 21:28:57 $'
[ "${KSH_VERSION}" = "${EASYRSA_KSH}" ] && EASYTLS_FOR_WINDOWS=1

if [ "$EASYTLS_FOR_WINDOWS" ]
then
	export OPENVPN_CMD="./openvpn.exe"
	WIN_TEMP="$(printf "%s\n" "${TEMP}" | sed -e 's,\\,/,g')"
	[ -z "$EASYTLS_tmp_dir" ] && export EASYTLS_tmp_dir="${WIN_TEMP}/easytls-unit-tests"
	mkdir -p "$EASYTLS_tmp_dir"
else
	export EASYTLS_tmp_dir="${WORK_DIR}/unit-test-tmp"
	mkdir -p "$EASYTLS_tmp_dir"
	if [ -f ./openvpn ]
	then
		export OPENVPN_CMD=./openvpn
	else
		export OPENVPN_CMD=/usr/sbin/openvpn
	fi
fi
[ -f "$OPENVPN_CMD" ] || fail "Cannot find: $OPENVPN_CMD"

# Test help
"${EASYTLS_CMD}" --help || fail "${EASYTLS_CMD} ${EASYTLS_OPTS} --help ($?)"
"${TLSCV2V_CMD}" --help || exit_code=$?
[ $exit_code -eq 253 ] || fail "${TLSCV2V_CMD} ${TLSCV2V_OPTS} --help ($?)"
#'"${TLSVERIFY_CMD}" --help || exit_code=$?
#[ $exit_code -eq 253 ] || fail "${TLSVERIFY_CMD} ${TLSVERIFY_OPTS} --help ($?)"
"${CLICON_CMD}" --help || exit_code=$?
[ $exit_code -eq 253 ] || fail "${CLICON_CMD} ${CLICON_OPTS} --help ($?)"

# No-CA test
PKI_DIR="${WORK_DIR}/noca"
export EASYRSA="$WORK_DIR"
export EASYRSA_PKI="$PKI_DIR"
hwaddr1="00:15:5d:c9:6e:01"
hwaddr2="00:80:ea:06:fe:fc"
ip4addr="10.1.101.0/24"
ip6addr="12fc:1918::10:01:101:0/112"

echo "============================================================"
echo "No-CA mode:"
print "ls -l"
ls -l

echo "--------------------"
[ -d "${EASYRSA_PKI}" ] && rm -rf "${EASYRSA_PKI}"
#print "$EASYRSA_CMD ${EASYRSA_OPTS} init-pki"
#"$EASYRSA_CMD" ${EASYRSA_OPTS} init-pki || fail "No-CA test: init-pki"

for cmd in "init no-ca" "cf cg easytls-unit-test" \
			"sss s01" "ssc c01" "ssc c02" \
			"bta" "ita s01 0" "-r=s01 ita c01 1" "-r=s01 ita c02 1" \
			"sss s02" "ssc c03" "ssc c04" \
			"btc" "itc s02" "-r=s02 itc c03" "-r=s02 itc c04" \
			"sss s03" "ssc c05" "ssc c06" \
			"btcv2s s03" \
			"btcv2c s03 c05" "-k=hw btcv2c s03 c05 ${hwaddr1} ${hwaddr2} ${ip4addr} ${ip6addr}" \
			"btcv2c s03 c06" "-k=hw btcv2c s03 c06 ${hwaddr1} ${hwaddr2} ${ip4addr} ${ip6addr}" \
			"itcv2 s03" \
			"-r=s03 itcv2 c05" "-r=s03 -k=hw itcv2 c05 no-md" \
			"-r=s03 itcv2 c06" "-r=s03 -k=hw itcv2 c06 add-hw" \
			"-k=hw rmd c06 serial" "status" \
			"bc2gc s03 family" "bc2gc s03 friends ${hwaddr1} ${hwaddr2} ${ip4addr} ${ip6addr}" \
			"ic2gc c06 friends"
do
	[ "${cmd}" = 99 ] && exit 99
	echo "--------------------"
	print "$EASYTLS_CMD ${EASYTLS_OPTS} ${cmd}"
	"$EASYTLS_CMD" ${EASYTLS_OPTS} ${cmd} || fail "No-CA test: ${cmd}"
done
echo "============================================================"

[ $NOCA_ONLY ] && exit 0
noca_end_time="$(date +%s)"
noca_run_mins="$(( (noca_end_time - start_time) / 60 ))"
noca_run_secs="$(( (noca_end_time - start_time) - ( noca_run_mins * 60 ) ))"
print "No-CA Duration: $noca_run_mins minutes $noca_run_secs seconds"
#rm -rf "$PKI_DIR"

export EASYRSA_CERT_RENEW=1000

build_easyrsa

total_expected_errors=0
subtot_1=0
subtot_2=0
subtot_3=0

QUIT_LOOP=${QUIT_LOOP:-0}

for loops in 1 2 3
do
	eval loop_${loops}_start_time="$(date +%s)"
	# Set errexit for all easytls
	#set -e

	subtot_expected_errors=0
	PKI_DIR="${WORK_DIR}/et-tdir${loops}"
	ETLS_DIR="${PKI_DIR}/easytls"
	DBUG_DIR="${ETLS_DIR}/metadata"
	export EASYRSA="$WORK_DIR"
	export EASYRSA_PKI="$PKI_DIR"
	EASYTLS_VARS="$PKI_DIR/vars"

	# github Windows runner takes too long, so just test once
	if [ $loops -eq 2 ] && [ $EASYTLS_FOR_WINDOWS ]
	then
		print "Total verified expected errors = 57"
		print "total_expected_errors = $total_expected_errors"
		[ $total_expected_errors -eq 57 ] || {
			end_time="$(date +%s)"
			run_mins="$(( (end_time - start_time) / 60 ))"
			run_secs="$(( (end_time - start_time) - ( run_mins * 60 ) ))"
			print "Duration: $run_mins minutes $run_secs seconds"
			print "***** EXPECTED ERROR COUNT INCORRECT *****"
			exit 1
			}
		[ $EASYTLS_REMOTE_CI ] && {
			end_time="$(date +%s)"
			run_mins="$(( (end_time - start_time) / 60 ))"
			run_secs="$(( (end_time - start_time) - ( run_mins * 60 ) ))"
			print "Duration: $run_mins minutes $run_secs seconds"
			exit 0
			}
	fi

	[ $loops -eq 2 ] && [ $EASYTLS_REMOTE_CI ] && {
		EASYTLS_OPTS="${EASYTLS_OPTS} -y"
		printf "\n\n\n%s\n\n\n" "* >>>>> FILE-HASH-DISABLED MODE <<<<< *"
		}

	# Switch to SHA1
	[ $loops -eq 3 ] && TLSCV2V_OPTS="-v --hash=SHA1"

	export EASYRSA_REQ_CN="easytls"
	# Setup EasyRSA
	print "EASYRSA_PKI: $EASYRSA_PKI"
	print "ls -l"
	ls -l
	"$EASYRSA_CMD" $EASYRSA_OPTS init-pki

	# Build EASYTLS_VARS - Random serial NO
	[ $loops -eq 2 ] && build_vars

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

	# Test EasyTLS
	for i in "init-tls" "cf ac off" "config"\
		"build-tls-auth" "build-tls-crypt" \
		"build-tls-crypt-v2-server s01" \
		"--inline --custom-group=tincantech build-tls-crypt-v2-server s02" \
		"build-tls-crypt-v2-client s01 c01" \
		"--custom-group=tincantech build-tls-crypt-v2-client s01 c02" \
		"--custom-group=tincantech build-tls-crypt-v2-client s01 c05" \
		"--custom-group=tincantech build-tls-crypt-v2-client s01 c06" \
		"--custom-group=tincantech build-tls-crypt-v2-client s01 c08" \
		"--custom-group=tincantech \
			build-tls-crypt-v2-client s01 c09 ${hwaddr1} ${hwaddr2} ${ip4addr} ${ip6addr}" \
		"--custom-group=tincantech --sub-key-name=bob \
			build-tls-crypt-v2-client s01 c09 ${hwaddr1} ${hwaddr2} ${ip4addr} ${ip6addr}" \
		"--inline --custom-group=tincantech --sub-key-name=office \
			build-tls-crypt-v2-client s01 c10 ${hwaddr1} ${hwaddr2} ${ip4addr} ${ip6addr}" \
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
		"--custom-group=tincantech inline-tls-crypt-v2 c02 no-key" \
		"--custom-group=tincantech inline-tls-crypt-v2 c05" \
		"disable c05" \
		"enable c05" \
		"--custom-group=tincantech inline-tls-crypt-v2 c06" \
		"--custom-group=tincantech inline-tls-crypt-v2 c08" \
		"--custom-group=tincantech inline-tls-crypt-v2 c09 add-hw" \
		"--custom-group=tincantech --sub-key-name=bob inline-tls-crypt-v2 c09 add-hw" \
		"--custom-group=tincantech --sub-key-name=bob rmd c09" \
		"--custom-group=tincantech --sub-key-name=eve \
			build-tls-crypt-v2-client s01 c10 ${hwaddr1} ${hwaddr2} ${ip4addr} ${ip6addr}" \
		"--custom-group=tincantech --sub-key-name=eve \
			inline-tls-crypt-v2 c10 add-hw" \
		"--custom-group=tincantech --sub-key-name=eve remove-inline c10" \
		"--custom-group=tincantech --sub-key-name=eve remove-tlskey c10" \
		"cert-expire" \
		"inline-expire" \
		"bc2gc s01 family" "bc2gc s01 friends ${hwaddr1} ${hwaddr2} ${ip4addr} ${ip6addr}" \
		"ic2gc c01 family" "ic2gc c01 friends" "ic2gc c02 friends" "rehash"
		#"inline-index-rebuild" \
		## EOL
	do
		test_cmd="$i"
		[ $loops -eq 1 ] && [ "$test_cmd" = "cf ac off" ] && continue
		#[ $loops -eq 2 ] && [ "$test_cmd" = "init-tls" ] && \
		#	EASYTLS_OPTS="--verbose --batch --no-auto-check" ### "-y"
		[ $loops -eq 3 ] && [ "$test_cmd" = "init-tls" ] && {
			test_cmd="$test_cmd SHA1"
		#	EASYTLS_OPTS="--verbose --batch"
			}
		[ $loops -eq 3 ] && [ "$test_cmd" = "rehash" ] && {
			test_cmd="$test_cmd SHA1 40"
		#	EASYTLS_OPTS="--verbose --batch"
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

	# Test for bad filter-addresses
	print "============================================================"
	echo "==> $EASYTLS_CMD $EASYTLS_OPTS bc2gc s01 broken o0:11:22:33:44:55"
	"$EASYTLS_CMD" $EASYTLS_OPTS bc2gc s01 broken o0:11:22:33:44:55 || expected_errors $?
	print "============================================================"
	echo "==> $EASYTLS_CMD $EASYTLS_OPTS bc2gc s01 broken 1.2.3.4/24"
	"$EASYTLS_CMD" $EASYTLS_OPTS bc2gc s01 broken 1.2.3.4/24 || expected_errors $?
	print "============================================================"
	echo "==> $EASYTLS_CMD $EASYTLS_OPTS bc2gc s01 broken 2000::2:1/64"
	"$EASYTLS_CMD" $EASYTLS_OPTS bc2gc s01 broken 2000::2:1/64 || expected_errors $?

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

	# Unset errexit for all easytls-cryptv2-verify.sh
	# because errors are expected and accounted for manually
	#set +e

	for c in "c01" "c05" "c06" "c07-nomd" "c09"
	do
		print "============================================================"
		  echo metadata_file="$DBUG_DIR/${c}-tls-crypt-v2.metadata"
		export metadata_file="$DBUG_DIR/${c}-tls-crypt-v2.metadata"

		print "------------------------------------------------------------"
		echo "$TLSCV2V_CMD" $TLSCV2V_OPTS -c="$PKI_DIR"
		     "$TLSCV2V_CMD" $TLSCV2V_OPTS -c="$PKI_DIR" || expected_errors $?
		clean_up

		print "------------------------------------------------------------"
		echo "$TLSCV2V_CMD" $TLSCV2V_OPTS -c="$PKI_DIR" -g=tincantech
		     "$TLSCV2V_CMD" $TLSCV2V_OPTS -c="$PKI_DIR" -g=tincantech || expected_errors $?
		clean_up

		print "------------------------------------------------------------"
		echo "$TLSCV2V_CMD" $TLSCV2V_OPTS -c="$PKI_DIR" -g=tincantech --disable-list
		     "$TLSCV2V_CMD" $TLSCV2V_OPTS -c="$PKI_DIR" -g=tincantech --disable-list || expected_errors $?
		clean_up

		print "------------------------------------------------------------"
		echo "$TLSCV2V_CMD" $TLSCV2V_OPTS -c="$PKI_DIR" -g=tincantech --via-ca
		     "$TLSCV2V_CMD" $TLSCV2V_OPTS -c="$PKI_DIR" -g=tincantech --via-ca || expected_errors $?
		clean_up

		print "------------------------------------------------------------"
		echo "$TLSCV2V_CMD" $TLSCV2V_OPTS -c="$PKI_DIR" -g=tincantech --via-index
		     "$TLSCV2V_CMD" $TLSCV2V_OPTS -c="$PKI_DIR" -g=tincantech --via-index || expected_errors $?
		clean_up

		print "------------------------------------------------------------"
		echo "$TLSCV2V_CMD" $TLSCV2V_OPTS -c="$PKI_DIR" -g=tincantech --via-index --cache-id
		     "$TLSCV2V_CMD" $TLSCV2V_OPTS -c="$PKI_DIR" -g=tincantech --via-index --cache-id || expected_errors $?
		clean_up

		print "------------------------------------------------------------"
		plcid="$(cat "$PKI_DIR/easytls/data/easytls-ca-identity.txt")"
		echo "$TLSCV2V_CMD" $TLSCV2V_OPTS -c="$PKI_DIR" -g=tincantech --via-index --preload-id="$plcid"
		     "$TLSCV2V_CMD" $TLSCV2V_OPTS -c="$PKI_DIR" -g=tincantech --via-index --preload-id="$plcid" || expected_errors $?
		clean_up

	# Set errexit for all easytls
	#set -e

		print "------------------------------------------------------------"
		echo "$EASYTLS_CMD" $EASYTLS_OPTS disable "$c"
		     "$EASYTLS_CMD" $EASYTLS_OPTS disable "$c" || expected_errors $?

	# Unset errexit for all easytls-cryptv2-verify.sh
	# because errors are expected and accounted for manually
	#set +e

		print "------------------------------------------------------------"
		echo "$TLSCV2V_CMD" $TLSCV2V_OPTS -c="$PKI_DIR"
		     "$TLSCV2V_CMD" $TLSCV2V_OPTS -c="$PKI_DIR" || expected_errors $?
		clean_up

		print "------------------------------------------------------------"
		echo "$TLSCV2V_CMD" $TLSCV2V_OPTS -c="$PKI_DIR" -g=tincantech
		     "$TLSCV2V_CMD" $TLSCV2V_OPTS -c="$PKI_DIR" -g=tincantech || expected_errors $?
		clean_up

		print "------------------------------------------------------------"
		echo "$TLSCV2V_CMD" $TLSCV2V_OPTS -c="$PKI_DIR" -g=tincantech --disable-list
		     "$TLSCV2V_CMD" $TLSCV2V_OPTS -c="$PKI_DIR" -g=tincantech --disable-list || expected_errors $?
		clean_up

		print "------------------------------------------------------------"
		echo "$TLSCV2V_CMD" $TLSCV2V_OPTS -c="$PKI_DIR" -g=tincantech --via-ca
		     "$TLSCV2V_CMD" $TLSCV2V_OPTS -c="$PKI_DIR" -g=tincantech --via-ca || expected_errors $?
		clean_up

		print "------------------------------------------------------------"
		echo "$TLSCV2V_CMD" $TLSCV2V_OPTS -c="$PKI_DIR" -g=tincantech --via-index
		     "$TLSCV2V_CMD" $TLSCV2V_OPTS -c="$PKI_DIR" -g=tincantech --via-index || expected_errors $?
		clean_up

		print "------------------------------------------------------------"
		echo "$TLSCV2V_CMD" $TLSCV2V_OPTS -c="$PKI_DIR" -g=tincantech --via-index --cache-id
		     "$TLSCV2V_CMD" $TLSCV2V_OPTS -c="$PKI_DIR" -g=tincantech --via-index --cache-id || expected_errors $?
		clean_up

		print "------------------------------------------------------------"
		plcid="$(cat "$PKI_DIR/easytls/data/easytls-ca-identity.txt")"
		echo "$TLSCV2V_CMD" $TLSCV2V_OPTS -c="$PKI_DIR" -g=tincantech --via-index --preload-id="$plcid"
		     "$TLSCV2V_CMD" $TLSCV2V_OPTS -c="$PKI_DIR" -g=tincantech --via-index --preload-id="$plcid" || expected_errors $?
		clean_up

		echo
	done

		print "============================================================"
		  echo metadata_file="$DBUG_DIR/c09-bob-tls-crypt-v2.metadata"
		export metadata_file="$DBUG_DIR/c09-bob-tls-crypt-v2.metadata"

		print "------------------------------------------------------------"
		echo "$TLSCV2V_CMD" $TLSCV2V_OPTS -c="$PKI_DIR" -g=tincantech --via-index --cache-id
		     "$TLSCV2V_CMD" $TLSCV2V_OPTS -c="$PKI_DIR" -g=tincantech --via-index --cache-id || expected_errors $?
		clean_up

	# Set errexit for all easytls
	#set -e

		print "------------------------------------------------------------"
		echo "$EASYTLS_CMD" --sub-key-name=bob $EASYTLS_OPTS disable "$c"
		     "$EASYTLS_CMD" --sub-key-name=bob $EASYTLS_OPTS disable "$c"

	# Unset errexit for all easytls-cryptv2-verify.sh
	# because errors are expected and accounted for manually
	#set +e

		print "------------------------------------------------------------"
		echo "$TLSCV2V_CMD" $TLSCV2V_OPTS -c="$PKI_DIR" -g=tincantech --via-index --cache-id
		     "$TLSCV2V_CMD" $TLSCV2V_OPTS -c="$PKI_DIR" -g=tincantech --via-index --cache-id || expected_errors $?
		clean_up

	# Set errexit for all easytls
	#set -e

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

	printf '\n\n\n'
	print "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
	print "subtot_expected_errors: $subtot_expected_errors"
	print "total_expected_errors: $total_expected_errors"
	print "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
	printf '\n\n\n'

	eval subtot_${loops}=${subtot_expected_errors}
	subtot_expected_errors=0

	eval loop_${loops}_end_time="$(date +%s)"
	eval loop_${loops}_run_mins="$(( (loop_${loops}_end_time - loop_${loops}_start_time) / 60 ))"
	eval loop_${loops}_run_secs="$(( (loop_${loops}_end_time - loop_${loops}_start_time) - ( loop_${loops}_run_mins * 60 ) ))"

	[ $loops -eq $QUIT_LOOP ] && exit 0

done # => loops

# Now test a cross-polinated TCV2 key
final_start_time="$(date +%s)"
printf '\n\n\n'
print "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
printf '\n\n\n%s\n\n\n' "Now test a cross-polinated TCV2 key"


###  NOTE: Hard coded directory

### EVERY TEST IS EXPECTED TO FAIL

	# Unset errexit for all easytls-cryptv2-verify.sh
	# because errors are expected and accounted for manually
	#set +e

DBUG_DIR="$WORK_DIR/et-tdir1/easytls/metadata"

	# Test tls-crypt-v2-verify.sh
	for c in "c01" "c05" "c06" "c07-nomd" "c09"
	do
		print "============================================================"
		  echo metadata_file="$DBUG_DIR/${c}-tls-crypt-v2.metadata"
		export metadata_file="$DBUG_DIR/${c}-tls-crypt-v2.metadata"

		print "------------------------------------------------------------"
		echo "$TLSCV2V_CMD" $TLSCV2V_OPTS -c="$PKI_DIR"
		     "$TLSCV2V_CMD" $TLSCV2V_OPTS -c="$PKI_DIR" || expected_errors $?
		clean_up

		print "------------------------------------------------------------"
		echo "$TLSCV2V_CMD" $TLSCV2V_OPTS -c="$PKI_DIR" -g=tincantech
		     "$TLSCV2V_CMD" $TLSCV2V_OPTS -c="$PKI_DIR" -g=tincantech || expected_errors $?
		clean_up

		print "------------------------------------------------------------"
		echo "$TLSCV2V_CMD" $TLSCV2V_OPTS -c="$PKI_DIR" -g=tincantech --disable-list
		     "$TLSCV2V_CMD" $TLSCV2V_OPTS -c="$PKI_DIR" -g=tincantech --disable-list || expected_errors $?
		clean_up

		print "------------------------------------------------------------"
		echo "$TLSCV2V_CMD" $TLSCV2V_OPTS -c="$PKI_DIR" -g=tincantech --via-ca
		     "$TLSCV2V_CMD" $TLSCV2V_OPTS -c="$PKI_DIR" -g=tincantech --via-ca || expected_errors $?
		clean_up

		print "------------------------------------------------------------"
		echo "$TLSCV2V_CMD" $TLSCV2V_OPTS -c="$PKI_DIR" -g=tincantech --via-index
		     "$TLSCV2V_CMD" $TLSCV2V_OPTS -c="$PKI_DIR" -g=tincantech --via-index || expected_errors $?
		clean_up

		print "------------------------------------------------------------"
		echo "$TLSCV2V_CMD" $TLSCV2V_OPTS -c="$PKI_DIR" -g=tincantech --via-index --cache-id
		     "$TLSCV2V_CMD" $TLSCV2V_OPTS -c="$PKI_DIR" -g=tincantech --via-index --cache-id || expected_errors $?
		clean_up

		print "------------------------------------------------------------"
		plcid="$(cat "$PKI_DIR/easytls/data/easytls-ca-identity.txt")"
		echo "$TLSCV2V_CMD" $TLSCV2V_OPTS -c="$PKI_DIR" -g=tincantech --via-index --preload-id="$plcid"
		     "$TLSCV2V_CMD" $TLSCV2V_OPTS -c="$PKI_DIR" -g=tincantech --via-index --preload-id="$plcid" || expected_errors $?
		clean_up

		print "------------------------------------------------------------"
		echo "$EASYTLS_CMD" --batch disable "$c"
		     "$EASYTLS_CMD" --batch disable "$c" || expected_errors $?

		print "------------------------------------------------------------"
		echo "$TLSCV2V_CMD" $TLSCV2V_OPTS -c="$PKI_DIR"
		     "$TLSCV2V_CMD" $TLSCV2V_OPTS -c="$PKI_DIR" || expected_errors $?
		clean_up

		print "------------------------------------------------------------"
		echo "$TLSCV2V_CMD" $TLSCV2V_OPTS -c="$PKI_DIR" -g=tincantech
		     "$TLSCV2V_CMD" $TLSCV2V_OPTS -c="$PKI_DIR" -g=tincantech || expected_errors $?
		clean_up

		print "------------------------------------------------------------"
		echo "$TLSCV2V_CMD" $TLSCV2V_OPTS -c="$PKI_DIR" -g=tincantech --disable-list
		     "$TLSCV2V_CMD" $TLSCV2V_OPTS -c="$PKI_DIR" -g=tincantech --disable-list || expected_errors $?
		clean_up

		print "------------------------------------------------------------"
		echo "$TLSCV2V_CMD" $TLSCV2V_OPTS -c="$PKI_DIR" -g=tincantech --via-ca
		     "$TLSCV2V_CMD" $TLSCV2V_OPTS -c="$PKI_DIR" -g=tincantech --via-ca || expected_errors $?
		clean_up

		print "------------------------------------------------------------"
		echo "$TLSCV2V_CMD" $TLSCV2V_OPTS -c="$PKI_DIR" -g=tincantech --via-index
		     "$TLSCV2V_CMD" $TLSCV2V_OPTS -c="$PKI_DIR" -g=tincantech --via-index || expected_errors $?
		clean_up

		print "------------------------------------------------------------"
		echo "$TLSCV2V_CMD" $TLSCV2V_OPTS -c="$PKI_DIR" -g=tincantech --via-index --cache-id
		     "$TLSCV2V_CMD" $TLSCV2V_OPTS -c="$PKI_DIR" -g=tincantech --via-index --cache-id || expected_errors $?
		clean_up

		print "------------------------------------------------------------"
		plcid="$(cat "$PKI_DIR/easytls/data/easytls-ca-identity.txt")"
		echo "$TLSCV2V_CMD" $TLSCV2V_OPTS -c="$PKI_DIR" -g=tincantech --via-index --preload-id="$plcid"
		     "$TLSCV2V_CMD" $TLSCV2V_OPTS -c="$PKI_DIR" -g=tincantech --via-index --preload-id="$plcid" || expected_errors $?
		clean_up

		print "------------------------------------------------------------"
		plcid="$(cat "$PKI_DIR/easytls/data/easytls-ca-identity.txt")"
		echo "$TLSCV2V_CMD" $TLSCV2V_OPTS -c="$PKI_DIR" -g=tincantech --via-index --cache-id --preload-id="$plcid"
		     "$TLSCV2V_CMD" $TLSCV2V_OPTS -c="$PKI_DIR" -g=tincantech --via-index --cache-id --preload-id="$plcid" || expected_errors $?
		clean_up

		echo
	done

	# Set errexit for all easytls
	#set -e

	# Re-enable file-hashing and auto-check
	# Use error code 64 because inline-index-rebuild is disabled
	print "============================================================"
	print "$EASYTLS_CMD $EASYTLS_OPTS cf ac on"
	"$EASYTLS_CMD" $EASYTLS_OPTS cf ac on || \
		fail "Unit test error 64: cf ac on"
	print "============================================================"

	print "============================================================"
	print "$EASYTLS_CMD $EASYTLS_OPTS status"
	"$EASYTLS_CMD" $EASYTLS_OPTS status || \
		fail "Unit test error 65: status"
	print "============================================================"



	# This last rebuild over writes the backup from prior to making+revoke c04+c06
	#rm "$WORK_DIR/et-tdir3/easytls/data/easytls-inline-index.txt.backup"
	#rm "$WORK_DIR/et-tdir3/easytls/data/easytls-inline-index.hash.backup"
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

	#print "------------------------------------------------------------"
	#TEST_CMD="disabled-list-rehash"
	#print "$EASYTLS_CMD $EASYTLS_OPTS $TEST_CMD"
	#"$EASYTLS_CMD" $EASYTLS_OPTS $TEST_CMD || \
	#	fail "Unit test error 72: $TEST_CMD"

	print "------------------------------------------------------------"
	print "$EASYTLS_CMD $EASYTLS_OPTS v4ip 1.2.3.0/24"
	"$EASYTLS_CMD" $EASYTLS_OPTS v4ip 1.2.3.0/24 || \
		fail "Unit test error 71: v4ip 1.2.3.0/24"

	print "------------------------------------------------------------"
	print "$EASYTLS_CMD $EASYTLS_OPTS x4ip 1.2.3.0/24"
	"$EASYTLS_CMD" $EASYTLS_OPTS x4ip 1.2.3.0/24 || \
		fail "Unit test error 71: x4ip 1.2.3.0/24"

	print "------------------------------------------------------------"
	print "$EASYTLS_CMD $EASYTLS_OPTS v6ip 2000::1:2:3:4/64"
	"$EASYTLS_CMD" $EASYTLS_OPTS v6ip 2000::1:2:3:4/64 || \
		fail "Unit test error 71: v6ip 2000::1:2:3:4/64"

	print "------------------------------------------------------------"
	print "$EASYTLS_CMD $EASYTLS_OPTS x6ip 2000:1:2:3:4::/80"
	"$EASYTLS_CMD" $EASYTLS_OPTS x6ip 2000:1:2:3:4::/80 || \
		fail "Unit test error 71: x6ip 2000:1:2:3:4::/80"

	print "------------------------------------------------------------"
	print "$EASYTLS_CMD $EASYTLS_OPTS version"
	"$EASYTLS_CMD" $EASYTLS_OPTS version || \
		fail "Unit test error 71: version"

final_end_time="$(date +%s)"
final_run_mins="$(( (final_end_time - final_start_time) / 60 ))"
final_run_secs="$(( (final_end_time - final_start_time) - ( final_run_mins * 60 ) ))"

echo "============================================================"
echo "Clean up"
clean_up

echo "============================================================"
echo "subtot_1 $subtot_1 (Expected 57 Verified)"
echo "subtot_2 $subtot_2 (Expected 57 Verified)"
echo "subtot_3 $subtot_3 (Expected 57 Verified)"
echo "Last part cross-polinated: $subtot_expected_errors (Expected 77 Verified)"

echo "total_expected_errors=$total_expected_errors (Expected 248 Verified)"
echo "Completed successfully: $(date +%Y/%m/%d--%H:%M:%S)"
echo "============================================================"

print "No-CA Duration: $noca_run_mins minutes $noca_run_secs seconds"
print "loop1 Duration: $loop_1_run_mins minutes $loop_1_run_secs seconds"
print "loop2 Duration: $loop_2_run_mins minutes $loop_2_run_secs seconds"
print "loop3 Duration: $loop_3_run_mins minutes $loop_3_run_secs seconds"
print "Final Duration: $final_run_mins minutes $final_run_secs seconds"

end_time="$(date +%s)"
run_mins="$(( (end_time - start_time) / 60 ))"
run_secs="$(( (end_time - start_time) - ( run_mins * 60 ) ))"
print "Total Duration: $run_mins minutes $run_secs seconds"

echo
[ $total_expected_errors -eq 248 ] || {
	echo "Expected ERROR count incorrect!"
	exit 9
	}
exit 0
