#!/bin/sh

# Copyright - negotiable
# VERBATUM_COPYRIGHT_HEADER_INCLUDE_NEGOTIABLE
# easytls-unit-tests.sh
#
# Copyright (C) 2020 Richard Bonhomme (Friday 13th of March 2020)
# https://github.com/TinCanTech/easy-tls
# tincantech@protonmail.com
# All Rights reserved.
#
# This code is released under version 2 of the GNU GPL
# See LICENSE of this project for full licensing details.
#
# VERBATUM_COPYRIGHT_HEADER_INCLUDE_NEGOTIABLE

usage ()
{
	print "Usage:

  -b, --build-data   To build test data .tar files.
                     This will also run the full test
                     and build new PKIs from scratch.
                     TBD
"
}


# Tools Version
tools_version() {
	print "
OpenSSL command: ${OPENSSL_CMD}"
	${INVOKE_OPTS} "${OPENSSL_CMD}" version || \
		fail "${INVOKE_OPTS} ${OPENSSL_CMD} version ($exit_code)"

	print "
EasyRSA command: ${EASYRSA_CMD}"
	${INVOKE_OPTS} "${EASYRSA_CMD}" version || \
		fail "${INVOKE_OPTS} ${EASYRSA_CMD} version ($exit_code)"

	print "
EasyTLS command: ${EASYTLS_CMD}"
	${INVOKE_OPTS} "${EASYTLS_CMD}" -V || \
		fail "${INVOKE_OPTS} ${EASYTLS_CMD} -V ($exit_code)"

	print "
EasyTLS-cryptv2-verify command: ${TLSCV2V_CMD}"
	${INVOKE_OPTS} "${TLSCV2V_CMD}" -V || exit_code=$?
	[ $exit_code -eq 9 ] || \
		fail "${INVOKE_OPTS} ${TLSCV2V_CMD} -V ($exit_code)"

	print "
EasyTLS-client-connect command: ${CLICON_CMD}"
	${INVOKE_OPTS} "${CLICON_CMD}" -V || exit_code=$?
	[ $exit_code -eq 9 ] || \
		fail "${INVOKE_OPTS} ${CLICON_CMD} -V ($exit_code)"

	print "
EasyTLS-client-disconnect command: ${CLIDIS_CMD}"
	${INVOKE_OPTS} "${CLIDIS_CMD}" -V || exit_code=$?
	[ $exit_code -eq 9 ] || \
		fail "${INVOKE_OPTS} ${CLIDIS_CMD} -V ($exit_code)"
}

fail ()
{
	print "$@"
	[ "${EASYTLS_FOR_WINDOWS}" ] && cd ..
	exit 1
}

expected_errors ()
{
	[ "$1" -eq 99 ] && exit 99
	subtot_expected_errors="$((subtot_expected_errors + 1))"
	warn "** subtot_expected_errors $subtot_expected_errors"
	total_expected_errors="$((total_expected_errors + 1))"
	[ -n "$SHALLOW" ] && return 0
	printf '%s ' "PRESS ENTER TO CONTINUE"
	read input
}

# copy md to test file
test_md_file ()
{
	:
}

finish_trap ()
{
	:
}

finish_ok ()
{
	[ -z "${EASYTLS_KEEP}" ] || return 0
	[ -d "${EASYTLS_tmp_dir}" ]		&& rm -rf "${EASYTLS_tmp_dir}"
	[ -d "${WORK_DIR}/noca" ]		&& rm -rf "${WORK_DIR}/noca"
	[ -d "${WORK_DIR}/et-tdir1" ]	&& rm -rf "${WORK_DIR}/et-tdir1"
	[ -d "${WORK_DIR}/et-tdir2" ]	&& rm -rf "${WORK_DIR}/et-tdir2"
	[ -d "${WORK_DIR}/et-tdir3" ]	&& rm -rf "${WORK_DIR}/et-tdir3"

	return 0

	#rm -f "${WORK_DIR}/easytls-cryptv2-verify.vars"
	#if [ -f "${WORK_DIR}/unit-test-tmp/easytls-cryptv2-verify.vars" ]; then
	#	mv	"${WORK_DIR}/unit-test-tmp/easytls-cryptv2-verify.vars" \
	#		"${WORK_DIR}/easytls-cryptv2-verify.vars" || \
	#			die "move vars file"
	#fi
}

test_server_scripts ()
{
	# easytls-cryptv2-verify.sh
	print "${INVOKE_OPTS}" \
		"${TLSCV2V_CMD}" "${TLSCV2V_OPTS}" "-s=${TLSCV2V_VARS}" \
		"-c=${PKI_DIR}" "${TEST_OPTS}"

	${INVOKE_OPTS} "${TLSCV2V_CMD}" ${TLSCV2V_OPTS} "-s=${TLSCV2V_VARS}" \
		"-c=${PKI_DIR}" ${TEST_OPTS} || expected_errors $?

	# easytls-client-connect.sh
	print "${INVOKE_OPTS}" \
		"${CLICON_CMD}" "${CLICON_OPTS}" "-s=${CLICON_VARS}"

	${INVOKE_OPTS} "${CLICON_CMD}" ${CLICON_OPTS} "-s=${CLICON_VARS}" || \
		expected_errors $?

	# easytls-client-disconnect.sh
	print "${INVOKE_OPTS}" \
		"${CLIDIS_CMD}" "${CLIDIS_OPTS}" "-s=${CLIDIS_VARS}"

	${INVOKE_OPTS} 	"${CLIDIS_CMD}" ${CLIDIS_OPTS} "-s=${CLIDIS_VARS}" || \
		expected_errors $?

	clean_up
}

clean_up ()
{
	# remove tmp dir
	[ -n "${EASYTLS_tmp_dir}" ] && [ "${EASYTLS_tmp_dir}" != "/" ] && \
		rm -rf "${EASYTLS_tmp_dir}"/*
	# make tmp dir
	mkdir -p "${WORK_DIR}/unit-test-tmp" || \
		fail "Cannot create: ${WORK_DIR}/unit-test-tmp"
	# Build vars file
	build_easytls_vars || fail "Cannot create vars files"
}

# Wrapper around printf - clobber print since it's not POSIX anyway
print() { [ -n "$EASYTLS_QUIET" ] || printf "%s\n" "$*"; }
warn() { printf "%s\n" "$*"; }

build_test_pki ()
{
		# safessl-easyrsa.cnfmust be in PKI for easytls-cryptv2-verify.sh
		if [ "$EASYTLS_FOR_WINDOWS" ]; then
			"$EASYRSA_CMD" $EASYRSA_OPTS make-safe-ssl
		else
			"$EASYRSA_CMD" $EASYRSA_OPTS write safe-cnf "$PKI_DIR/safessl-easyrsa.cnf" # ./et-tdir${loops}
		fi
		print "==>> safessl-easyrsa.cnf created in $PKI_DIR"

		for i in \
		"--req-cn='easytls-unit-test' build-ca nopass" \
		"build-server-full s01 nopass" \
		"build-server-full s02 nopass" \
		"build-server-full s-auth nopass" \
		"build-server-full s-crypt nopass" \
		"build-client-full c-auth nopass" \
		"build-client-full c-crypt nopass" \
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
		"show-ca" \
		"show-cert s01" \
		"show-cert c01" \
		"--keysize=512 gen-dh" \
		## EOL
	do
		print "============================================================"
		print "$EASYRSA_CMD $EASYRSA_OPTS $i"
		"$EASYRSA_CMD" $EASYRSA_OPTS $i || \
			fail "Unit test error 1: $EASYRSA_CMD $EASYRSA_OPTS $i"
	done
}


build_easyrsa ()
{

mkdir -p x509-types

printf '%s' "
# X509 extensions added to every signed cert

# This file is included for every cert signed, and by default does nothing.
# It could be used to add values every cert should have, such as a CDP as
# demonstrated in the following example:

#crlDistributionPoints = URI:http://example.net/pki/my_ca.crl
" > x509-types/COMMON

printf '%s' "
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

printf '%s' "
# X509 extensions for a server

basicConstraints = CA:FALSE
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid,issuer:always
extendedKeyUsage = serverAuth
keyUsage = digitalSignature,keyEncipherment
" > x509-types/server

printf '%s' "
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
		printf '%s\n' ' set_var EASYRSA_RAND_SN "no"'
		printf '%s\n' ' set_var EASYRSA_DN "org"'
		printf '%s\n' '# Unsupported characters:'
		printf '%s\n' '# `'
		printf '%s\n' '# $'
		printf '%s\n' '# "'
		printf '%s\n' "# '"
		printf '%s\n' '# #'
		printf '%s\n' '# & (Win)'
		printf '%s\n' ' set_var EASYRSA_REQ_COUNTRY   "00"'
		printf '%s\n' ' set_var EASYRSA_REQ_PROVINCE  "test"'
		printf '%s\n' ' set_var EASYRSA_REQ_CITY      "TEST ,./<>  ?;:@~  []!%^  *()-=  _+| (23) TEST"'
		printf '%s\n' ' set_var EASYRSA_REQ_ORG       "example.org"'
		printf '%s\n' ' set_var EASYRSA_REQ_EMAIL     "me@example.net"'
		printf '%s\n' ' set_var EASYRSA_REQ_OU        "TEST esc \\\\{ \\\\} \\\\£ \\\\¬ (4) TEST"'
	} > "$EASYTLS_VARS"
} # => build_vars ()

build_easytls_vars ()
{
	{	printf '%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n' \
			"# Easy-TLS crypt-v2 unit-test-tmp vars file" \
			"#EASYTLS_VERBOSE=1" \
			"#CA_DIR='/etc/openvpn/easyrsa/pki'" \
			"#EASYTLS_NO_CA=1" \
			"#LOCAL_CUSTOM_G='EASYTLS'" \
			"#LOCAL_CUSTOM_G='EASYTLS TEST'" \
			"#ENABLE_MULTI_CUSTOM_G=1" \
			"#TLSKEY_MAX_AGE=1825" \
			"#ENABLE_TLSKEY_HASH=1" \
			"#EASYTLS_tmp_dir='/tmp'" \
			# EOL

	} > "${TLSCV2V_VARS}"

	{	printf '%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n' \
			"# Easy-TLS client-connect unit-test-tmp vars file" \
			"#EASYTLS_VERBOSE=1" \
			"#IGNORE_X509_MISMATCH=1" \
			"#IGNORE_HWADDR_MISMATCH=1" \
			"#ENFORCE_UNIQUE_TLSKEY=1" \
			"#ENFORCE_TLSKEY_SERIAL_MATCH=1" \
			"#ENFORCE_PUSH_HWADDR=1" \
			"#ENFORCE_CRYPT_V2=1" \
			"#ENFORCE_KEY_HWADDR=1" \
			"#PEER_IP_MATCH=1" \
			"#EASYTLS_DYN_OPTS_FILE=/etc/openvpn/server/easytls-dyn-opts" \
			"#ENABLE_CONN_TRAC=1 # Also requires easytls-client-disconnect.sh" \
			"#VERBOSE_CONN_TRAC=1" \
			"#ENABLE_CONN_TRAC_STATS=1" \
			"#EASYTLS_TLSKEY_STATUS=1" \
			"#EASYTLS_tmp_dir=/tmp" \
			# EOL

	} > "${CLICON_VARS}"

	{	printf '%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n' \
			"# Easy-TLS client-disconnect unit-test-tmp vars file" \
			"#EASYTLS_VERBOSE=1" \
			"#ENABLE_CONN_TRAC=1 # Also requires easytls-client-disconnect.sh" \
			"#VERBOSE_CONN_TRAC=1" \
			"#ENABLE_CONN_TRAC_STATS=1" \
			"#EASYTLS_TLSKEY_STATUS=1" \
			"#ENABLE_STALE_LOG=1" \
			"#EASYTLS_tmp_dir=/tmp" \
			# EOL

	} > "${CLIDIS_VARS}"
	print "* vars rebuilt"
}



#######################################################

print '||'
print '||===[  Easy-TLS Unit Tests ]==='
print '||'

WORK_DIR="$(pwd)"
print '||'
print "||===[  WORK_DIR: $WORK_DIR ]==="
print '||'

start_time="$(date +%s)"

	# Register finish() on EXIT
	trap "finish_trap" EXIT
	# When SIGHUP, SIGINT, SIGQUIT, SIGABRT and SIGTERM,
	# explicitly exit to signal EXIT (non-bash shells)
	trap "exit 1" 1
	trap "exit 2" 2
	trap "exit 3" 3
	trap "exit 6" 6
	trap "exit 14" 15

export EASYTLS_UNIT_TEST=1
#export EASYTLS_QUIET=1

WORK_DIR="$(pwd)"
UTMP_DIR="${WORK_DIR}/unit-test-tmp"
rm -rf "${UTMP_DIR}"

EASYRSA_CMD="${EASYRSA_CMD:-./easyrsa}"
EASYRSA_OPTS="--batch"

EASYTLS_CMD="./easytls"
EASYTLS_OPTS="-v --batch"

TLSCV2V_CMD="./easytls-cryptv2-verify.sh"
TLSCV2V_VARS="${UTMP_DIR}/easytls-cryptv2-verify.vars"
TLSCV2V_OPTS="-v"

CLICON_CMD="./easytls-client-connect.sh"
CLICON_VARS="${UTMP_DIR}/easytls-client-connect.vars"
CLICON_OPTS="-v -m"

CLIDIS_CMD="./easytls-client-disconnect.sh"
CLIDIS_VARS="${UTMP_DIR}/easytls-client-disconnect.vars"
CLIDIS_OPTS="-v"

LIB_MD="./dev/easytls-metadata.lib"
[ -f "${LIB_MD}" ] || { print "Missing ${LIB_MD}"; exit 9; }
. "${LIB_MD}"

LIB_CT="./easytls-conntrac.lib"
[ -f "${LIB_CT}" ] || { print "Missing ${LIB_CT}"; exit 9; }
. "${LIB_CT}"

LIB_IP="./dev/easytls-tctip.lib"
[ -f "${LIB_IP}" ] || { print "Missing ${LIB_IP}"; exit 9; }
. "${LIB_IP}"

# create vars files
clean_up

export ENABLE_TLSKEY_HASH=1

# Identify Windows
EASYRSA_KSH='@(#)MIRBSD KSH R39-w32-beta14 $Date: 2013/06/28 21:28:57 $'
[ "${KSH_VERSION}" = "${EASYRSA_KSH}" ] && EASYTLS_FOR_WINDOWS=1

if [ -n "$EASYTLS_FOR_WINDOWS" ]
then
	export EASYTLS_OPENVPN="openvpn"
	export OPENVPN_CMD="./openvpn.exe"

	export EASYRSA_OPENSSL="openssl"
	export OPENSSL_CMD="./openssl.exe"

	#OPENVPN_BIN_DIR="${ProgramFiles}/Openvpn/bin"
	#if [ -d "${OPENVPN_BIN_DIR}" ]; then
	#	OPENVPN_CMD="${OPENVPN_BIN_DIR}/openvpn.exe"
	#	[ -f "${OPENVPN_CMD}" ] || \
	#		print "unit-test - OPENVPN_CMD: ${OPENVPN_CMD}"
	#	OPENSSL_CMD="${OPENVPN_BIN_DIR}/openssl.exe"
	#	[ -f "${OPENSSL_CMD}" ] || \
	#		print "unit-test - OPENSSL_CMD: ${OPENSSL_CMD}"
	#else
	#	export OPENVPN_CMD=./openvpn.exe
	#fi

	export PATH="./;${PATH}"

	WIN_TEMP="$(printf "%s\n" "${TEMP}" | sed -e 's,\\,/,g')"
	[ -z "$EASYTLS_tmp_dir" ] && \
		export EASYTLS_tmp_dir="${WIN_TEMP}/easytls-unit-tests"
	mkdir -p "$EASYTLS_tmp_dir"
else
	export EASYTLS_tmp_dir="${WORK_DIR}/unit-test-tmp"
	mkdir -p "$EASYTLS_tmp_dir"
	if [ -f ./openvpn ]
	then
		export EASYTLS_OPENVPN=./openvpn
		export OPENVPN_CMD=./openvpn
	else
		export EASYTLS_OPENVPN=openvpn
		export OPENVPN_CMD=openvpn
	fi

	export EASYRSA_OPENSSL="openssl"
	export OPENSSL_CMD="openssl"

fi

# Invoke with user opts: eg. EASYTLS_SILENT=1
INVOKE_OPTS=""

# Version info
tools_version

# Test help
print "TEST: All --help"

${INVOKE_OPTS} "${EASYTLS_CMD}" ${EASYTLS_OPTS} --help || \
	fail "${INVOKE_OPTS} ${EASYTLS_CMD} ${EASYTLS_OPTS} --help ($?)"

${INVOKE_OPTS} "${TLSCV2V_CMD}" ${TLSCV2V_OPTS} "${TLSCV2V_VARS}" --help || \
		exit_code=$?
	[ $exit_code -eq 253 ] || \
		fail "${INVOKE_OPTS} ${TLSCV2V_CMD} ${TLSCV2V_OPTS} ${TLSCV2V_VARS} --help
	 ($exit_code)"

${INVOKE_OPTS} "${CLICON_CMD}" ${CLICON_OPTS} "${CLICON_VARS}" --help || \
		exit_code=$?
	[ $exit_code -eq 253 ] || \
		fail "${INVOKE_OPTS} ${CLICON_CMD} ${CLICON_OPTS} ${CLICON_VARS} --help
	 ($exit_code)"

${INVOKE_OPTS} "${CLIDIS_CMD}" ${CLIDIS_OPTS} "${CLIDIS_VARS}" --help || \
		exit_code=$?
	[ $exit_code -eq 253 ] || \
		fail "${INVOKE_OPTS} ${CLIDIS_CMD} ${CLIDIS_OPTS} ${CLIDIS_VARS} --help
	 ($exit_code)"

# No-CA test
PKI_DIR="${WORK_DIR}/noca"
export EASYRSA="$WORK_DIR"
export EASYRSA_PKI="$PKI_DIR"
hwaddr1="00:15:5d:c9:6e:01"
hwaddr2="00:80:ea:06:fe:fc"
ip4addr="10.1.101.0/24"
ip6addr="12fc:1918::10:01:101:0/112"

print "============================================================"
print "No-CA mode:"
print "ls -l"
[ -n "$EASYTLS_SILENT" ] || ls -l

print "--------------------"
[ -d "${EASYRSA_PKI}" ] && rm -rf "${EASYRSA_PKI}"
#print "$EASYRSA_CMD ${EASYRSA_OPTS} init-pki"
#"$EASYRSA_CMD" ${EASYRSA_OPTS} init-pki || fail "No-CA test: init-pki"

for cmd in \
	"init no-ca" "cf cg easytls-unit-test" \
	"sss s01" "ssc c01" "ssc c02" \
	"bta" "ita s01 0" "-r=s01 ita c01 1" "-r=s01 ita c02 1" \
	"sss s02" "ssc c03" "ssc c04" \
	"btc" "itc s02" "-r=s02 itc c03" "-r=s02 itc c04" \
	"sss s03" "ssc c05" "ssc c06" \
	"btcv2s s03" \
	"btcv2c s03 c05" \
	"-k=hw btcv2c s03 c05 ${hwaddr1} ${hwaddr2} ${ip4addr} ${ip6addr}" \
	"btcv2c s03 c06" \
	"-k=hw btcv2c s03 c06 ${hwaddr1} ${hwaddr2} ${ip4addr} ${ip6addr}" \
	"itcv2 s03" \
	"-r=s03 itcv2 c05" "-r=s03 -k=hw itcv2 c05 no-md" \
	"-r=s03 itcv2 c06" "-r=s03 -k=hw itcv2 c06 add-hw" \
	"-k=hw rmd c06 serial" \
	"bc2gs tct-gs" "ic2gs s01 tct-gs" \
	"bc2gc s03 family" \
	"bc2gc s03 friends ${hwaddr1} ${hwaddr2} ${ip4addr} ${ip6addr}" \
	"ic2gc c06 friends" \
	"status" "version"
do
	[ "${cmd}" = 99 ] && exit 99
	print "--------------------"
	print "${INVOKE_OPTS} $EASYTLS_CMD ${EASYTLS_OPTS} ${cmd}"
	${INVOKE_OPTS} "$EASYTLS_CMD" ${EASYTLS_OPTS} ${cmd} || \
		fail "No-CA test: ${cmd}"

	#print "MASTER HASH:"
	#cat noca/easytls/data/easytls-faster.hash
	#print
done
print "============================================================"


noca_end_time="$(date +%s)"
noca_run_mins="$(( (noca_end_time - start_time) / 60 ))"
noca_run_secs="$(( (noca_end_time - start_time) - ( noca_run_mins * 60 ) ))"
print "No-CA Duration: $noca_run_mins minutes $noca_run_secs seconds"
print "Zero errors"
[ -n "$NOCA_ONLY" ] && exit 0

export EASYRSA_CERT_RENEW=1000

#build_easyrsa

total_expected_errors=0
subtot_1=0
sknown_1=38
subtot_2=0
sknown_2=38
subtot_3=0
sknown_3=38
subtot_expected_errors=0
sknown_expected_errors=62
known_expected_errors=$(( sknown_1 + sknown_2 + sknown_3 + sknown_expected_errors ))
special_errors=0

QUIT_LOOP=${QUIT_LOOP:-0}

for loops in 1 2 3
do
	eval loop_${loops}_start_time="$(date +%s)"

	subtot_expected_errors=0
	PKI_DIR="${WORK_DIR}/et-tdir${loops}"
	ETLS_DIR="${PKI_DIR}/easytls"
	DBUG_DIR="${ETLS_DIR}/metadata"
	export EASYRSA="$WORK_DIR"
	export EASYRSA_PKI="$PKI_DIR"
	EASYTLS_VARS="$PKI_DIR/vars"
	EASYTLS_OPTS="-v --batch"
	EASYTLS_OPTS="${EASYTLS_OPTS} -p=et-tdir${loops}"


#[ $loops -eq 1 ] && continue
#[ $loops -eq 2 ] && continue


	# github Windows runner takes too long, so just test once
	if [ $loops -eq 2 ] && [ $EASYTLS_REMOTE_CI ] && [ $EASYTLS_FOR_WINDOWS ]
	then
		print "Total verified expected errors = $sknown_1"
		print "total_expected_errors = $total_expected_errors"
		[ $total_expected_errors -eq $sknown_1 ] || {
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

	# Speed up first run for all
	if [ $loops -eq 1 ] && [ $EASYTLS_REMOTE_CI ]; then
		# disable auto-check ~60% time saving (13m to 5m)
		EASYTLS_OPTS="${EASYTLS_OPTS} -n"
		# disable file-hash ~60% time saving (13m to 5m)
		EASYTLS_OPTS="${EASYTLS_OPTS} -y"
		print "


* >>>>> FILE-HASH DISABLED / AUTO-CHECK DISABLED <<<<< *

EASYTLS_OPTS: ${EASYTLS_OPTS}

"
	fi

	# Enable file-hash - auto-check is VERY expensive
	if [ $loops -eq 2 ] && [ $EASYTLS_REMOTE_CI ]; then
		EASYTLS_OPTS="${EASYTLS_OPTS} -n"
		print "


* >>>>> FILE-HASH ENABLED / AUTO-CHECK DISABLED <<<<< *

EASYTLS_OPTS: ${EASYTLS_OPTS}

"
	fi

	# Switch to SHA1 - Full hash & check
	if [ $loops -eq 3 ]; then
		TLSCV2V_OPTS="${TLSCV2V_OPTS} --hash=SHA1"
		EASYTLS_OPTS="${EASYTLS_OPTS% -n}"
		print "


* >>>>> FILE-HASH ENABLED / AUTO-CHECK ENABLED <<<<< *

EASYTLS_OPTS: ${EASYTLS_OPTS}

"
	fi

	#export EASYRSA_REQ_CN="easytls-unit-test"

	# Setup EasyRSA
	print "*** EASYRSA_PKI: $EASYRSA_PKI"
	print "ls -l"
	[ $EASYTLS_SILENT ] || ls -l

	print "*** $EASYRSA_CMD $EASYRSA_OPTS init-pki"
	"$EASYRSA_CMD" $EASYRSA_OPTS init-pki

	# Build EASYTLS_VARS - Random serial NO
	[ $loops -eq 1 ] && build_vars && 	print " *** $build_vars"


	print "*** ls -l $EASYRSA_PKI"
	[ $EASYTLS_SILENT ] || ls -l "$EASYRSA_PKI"




if [ -n "${EASYTLS_BUILD_TEST_DATA}" ]; then
	
		# old
		build_test_pki || fail "build_test_pki"

		# # Fake it
		[ -z "${EASYTLS_BUILD_TEST_DATA}" ] || \
			tar -cf "input-et-tdir${loops}.tar" "et-tdir${loops}"/*

elif [ -n "${EASYTLS_REMOTE_CI}" ]; then

	# new
	print "*** COPY PKI: et-tdir${loops}"
	rm -rf "${WORK_DIR}/et-tdir${loops}"
	mkdir -p "${WORK_DIR}/et-tdir${loops}"

	# Update safessl-easyrsa.cnf
	print "*** Update safessl-easyrsa.cnf - easyrsa init-pki"
	"${EASYRSA_CMD}" --pki-dir="${WORK_DIR}/et-tdir${loops}" --batch init-pki || fail "init-pki"

	if "${EASYRSA_CMD}" --pki-dir="${WORK_DIR}/et-tdir${loops}" --batch make-safe-ssl
	then
		: # ok
	else
		"${EASYRSA_CMD}" --pki-dir="${WORK_DIR}/et-tdir${loops}" \
			--batch write safe-cnf "./et-tdir${loops}/safessl-easyrsa.cnf" || \
				fail "write safe-cnf"
	fi

	cp -vf "${WORK_DIR}/et-tdir${loops}/safessl-easyrsa.cnf" ./safessl-easyrsa.cnf || \
		fail "(1) cp ${WORK_DIR}/et-tdir${loops}/safessl-easyrsa.cnf ./safessl-easyrsa.cnf"

	# Remove the temp PKI - Only require safessl-easyrsa.cnf
	rm -rf "${WORK_DIR}/et-tdir${loops}"

	# portability [expletive deleted]
	if [ $EASYTLS_FOR_WINDOWS ]
	then
		7z x "${WORK_DIR}/dev/et-tdir${loops}.tar" || fail "extract PKI (7z)"
	else
		tar vxf "${WORK_DIR}/dev/et-tdir${loops}.tar" || fail "extract PKI (tar)"
	fi

	# Update safessl-easyrsa.cnf - because mktemp
	rm -f "${WORK_DIR}/et-tdir${loops}/safessl-easyrsa.cnf"
	cp -vf ./safessl-easyrsa.cnf "${WORK_DIR}/et-tdir${loops}/safessl-easyrsa.cnf" || \
		fail "(2) cp ./safessl-easyrsa.cnf ${WORK_DIR}/et-tdir${loops}/safessl-easyrsa.cnf"

else

	# old
	build_test_pki || fail "build_test_pki"

fi

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
		"-g=tincantech btcv2c s01 c09 \
			${hwaddr1} ${hwaddr2} ${ip4addr} ${ip6addr}" \
		"-g=tincantech -k=bob btcv2c s01 c09 \
			${hwaddr1} ${hwaddr2} ${ip4addr} ${ip6addr}" \
		"--inline -g=tincantech -k=office btcv2c s01 c10 \
			${hwaddr1} ${hwaddr2} ${ip4addr} ${ip6addr}" \
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
		"-g=tincantech inline-tls-crypt-v2 c06" \
		"-g=tincantech inline-tls-crypt-v2 c08" \
		"-g=tincantech inline-tls-crypt-v2 c09 add-hw" \
		"-g=tincantech --sub-key-name=bob inline-tls-crypt-v2 c09 add-hw" \
		"-g=tincantech --sub-key-name=bob rmd c09" \
		"-g=tincantech -k=eve btcv2c s01 c10 \
			${hwaddr1} ${hwaddr2} ${ip4addr} ${ip6addr}" \
		"-g=tincantech -k=eve inline-tls-crypt-v2 c10 add-hw" \
		"-g=tincantech --sub-key-name=eve remove-inline c10" \
		"-g=tincantech --sub-key-name=eve remove-tlskey c10" \
		"cert-expire" \
		"inline-expire" \
		"bc2gs tct-gs" "ic2gs s01 tct-gs" \
		"bc2gc s01 family" \
		"bc2gc s01 friends ${hwaddr1} ${hwaddr2} ${ip4addr} ${ip6addr}" \
		"ic2gc c01 family" "ic2gc c01 friends" "ic2gc c02 friends" \
		"rgil c01 family" "rgk family" \
		"ita s-auth" "itc s-crypt" "ita c-auth" "itc c-crypt" \
		"rehash"
		#"inline-index-rebuild" \
		## EOL
	do
		test_cmd="$i"
		[ $loops -eq 1 ] && [ "$test_cmd" = "cf ac off" ] && continue

		#[ $loops -eq 2 ] && [ "$test_cmd" = "init-tls" ] && \
		#

		[ $loops -eq 3 ] && [ "$test_cmd" = "init-tls" ] && {
			test_cmd="$test_cmd SHA1"
			}

		[ $loops -eq 3 ] && [ "$test_cmd" = "rehash" ] && {
			test_cmd="$test_cmd SHA1 40"
			}

		print "============================================================"
		print "${INVOKE_OPTS} $EASYTLS_CMD $EASYTLS_OPTS $test_cmd"

		# EasyOut
		#[ "$test_cmd" = "Planned break" ] && [ $loops -eq 2 ] && fail "Planned break"
		#[ "$test_cmd" = "Planned break" ] && print "Planned break" && continue

		#if [ "$test_cmd" = "remove-inline s01" ]
		#then
		#	cat "${ETLS_DIR}/s01.inline"
		#fi

		${INVOKE_OPTS} "$EASYTLS_CMD" $EASYTLS_OPTS $test_cmd || \
			fail "Unit test error 2: $EASYTLS_CMD $EASYTLS_OPTS $test_cmd"

	done

	# Test for bad filter-addresses
	print "============================================================"
	print "${INVOKE_OPTS} $EASYTLS_CMD $EASYTLS_OPTS bc2gc s01 broken o0:11:22:33:44:55"
	${INVOKE_OPTS} "$EASYTLS_CMD" $EASYTLS_OPTS bc2gc \
		s01 broken o0:11:22:33:44:55 || expected_errors $?

	print "============================================================"
	print "${INVOKE_OPTS} $EASYTLS_CMD $EASYTLS_OPTS bc2gc s01 broken 1.2.3.4/24"
	${INVOKE_OPTS} "$EASYTLS_CMD" $EASYTLS_OPTS bc2gc \
		s01 broken 1.2.3.4/24 || expected_errors $?

	print "============================================================"
	print "${INVOKE_OPTS} $EASYTLS_CMD $EASYTLS_OPTS bc2gc s01 broken 2000::2:1/64"
	${INVOKE_OPTS} "$EASYTLS_CMD" $EASYTLS_OPTS bc2gc \
		s01 broken 2000::2:1/64 || expected_errors $?

	# Create some certs out of order - These are intended to break EasyTLS
	# Renew c08, which completely breaks EasyTLS

	# This fails in WINDOWS because openssl does not find the name ..
	#	"$EASYRSA_CMD $EASYRSA_OPTS revoke c06" \
	# Works ok with Linux

	for i in "$EASYRSA_CMD $EASYRSA_OPTS build-client-full c04 nopass" \
		"${INVOKE_OPTS} $EASYTLS_CMD $EASYTLS_OPTS build-tls-crypt-v2-client s01 c04" \
		"${INVOKE_OPTS} $EASYTLS_CMD $EASYTLS_OPTS inline-tls-crypt-v2 c04" \
		"$EASYRSA_CMD $EASYRSA_OPTS revoke c04" \
		"$EASYRSA_CMD $EASYRSA_OPTS gen-crl" \
		"${INVOKE_OPTS} $EASYTLS_CMD $EASYTLS_OPTS status" \
		"${INVOKE_OPTS} $EASYTLS_CMD $EASYTLS_OPTS cert-expire" \
		"${INVOKE_OPTS} $EASYTLS_CMD $EASYTLS_OPTS status" \

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
	${INVOKE_OPTS} "$EASYTLS_CMD" $EASYTLS_OPTS \
		--custom-group=tincantech build-tls-crypt-v2-client s01 cw01 \
		 08-00-27-10-B8-D0 08:00:27:10:B8:D0 || \
			fail "Unit test error 62: build-tls-crypt-v2-client s01 cw01"

	print "============================================================"
	print "Build a Windblows inline file with metadata and hw-addr"
	${INVOKE_OPTS} "$EASYTLS_CMD" $EASYTLS_OPTS \
		--custom-group=tincantech inline-tls-crypt-v2 cw01 || \
			fail "Unit test error 62: inline-tls-crypt-v2 cw01"

	# Test tls-crypt-v2-verify.sh

	# Unset errexit for all easytls-cryptv2-verify.sh
	# because errors are expected and accounted for manually
	#set +e


#[ $loops -eq 3 ] && echo "exit 99" && exit 99


	clean_up
	for c in "c01" "c05" "c06" "c09"
	do

		print "============================================================"
		print "real_metadata_file=$DBUG_DIR/${c}-tls-crypt-v2.metadata"
		export real_metadata_file="$DBUG_DIR/${c}-tls-crypt-v2.metadata"
		export metadata_file="$DBUG_DIR/test-tls-crypt-v2.metadata"

		metadata_string="$(cat "${real_metadata_file}")"
		metadata_string_to_vars ${metadata_string} || fail "metadata_string_to_vars"
		real_client_serial=${MD_x509_SERIAL}
		real_UV_TLSKEY_SERIAL=${MD_TLSKEY_SERIAL}
		export UV_TLSKEY_SERIAL=${real_UV_TLSKEY_SERIAL}
		export common_name=${c}
		export ifconfig_pool_remote_ip=1.2.3.4
		export tls_serial_hex_0=${real_client_serial}

		print "------------------------------------------------------------"
		cp "${real_metadata_file}" "${metadata_file}"
		unset TEST_OPTS
		test_server_scripts

		print "------------------------------------------------------------"
		cp "${real_metadata_file}" "${metadata_file}"
		TEST_OPTS="-g=tincantech"
		test_server_scripts

		print "------------------------------------------------------------"
		cp "${real_metadata_file}" "${metadata_file}"
		TEST_OPTS="-g=tincantech -d"
		test_server_scripts

		print "------------------------------------------------------------"
		cp "${real_metadata_file}" "${metadata_file}"
		TEST_OPTS="-g=tincantech --via-ca"
		test_server_scripts

		print "------------------------------------------------------------"
		cp "${real_metadata_file}" "${metadata_file}"
		TEST_OPTS="-g=tincantech --via-index"
		test_server_scripts

		print "------------------------------------------------------------"
		cp "${real_metadata_file}" "${metadata_file}"
		TEST_OPTS="-g=tincantech --via-index --cache-id"
		test_server_scripts

		print "------------------------------------------------------------"
		cp "${real_metadata_file}" "${metadata_file}"
		plcid="$(cat "$PKI_DIR/easytls/data/easytls-ca-identity.txt")"
		TEST_OPTS="-g=tincantech --via-index --preload-id=${plcid}"
		test_server_scripts

		print "------------------------------------------------------------"
		print "${INVOKE_OPTS} $EASYTLS_CMD $EASYTLS_OPTS disable $c"
		${INVOKE_OPTS} "$EASYTLS_CMD" $EASYTLS_OPTS disable "$c" || \
			fail "${INVOKE_OPTS} $EASYTLS_CMD $EASYTLS_OPTS disable $c"

		print "------------------------------------------------------------"
		cp "${real_metadata_file}" "${metadata_file}"
		TEST_OPTS=""
		test_server_scripts

		print "------------------------------------------------------------"
		cp "${real_metadata_file}" "${metadata_file}"
		TEST_OPTS="-g=tincantech"
		test_server_scripts

		print "------------------------------------------------------------"
		cp "${real_metadata_file}" "${metadata_file}"
		TEST_OPTS="-g=tincantech -d"
		test_server_scripts

		print "------------------------------------------------------------"
		cp "${real_metadata_file}" "${metadata_file}"
		TEST_OPTS="-g=tincantech --via-ca"
		test_server_scripts

		print "------------------------------------------------------------"
		cp "${real_metadata_file}" "${metadata_file}"
		TEST_OPTS="-g=tincantech --via-index"
		test_server_scripts

		print "------------------------------------------------------------"
		cp "${real_metadata_file}" "${metadata_file}"
		TEST_OPTS="-g=tincantech --via-index --cache-id"
		test_server_scripts

		print "------------------------------------------------------------"
		cp "${real_metadata_file}" "${metadata_file}"
		plcid="$(cat "$PKI_DIR/easytls/data/easytls-ca-identity.txt")"
		TEST_OPTS="-g=tincantech --via-index --preload-id=${plcid}"
		test_server_scripts

		print


#[ $loops -eq 3 ] && echo "exit 99" && exit 99


	done


	print "============================================================"
	print "real_metadata_file=$DBUG_DIR/${c}-tls-crypt-v2.metadata"
	export real_metadata_file="$DBUG_DIR/c09-bob-tls-crypt-v2.metadata"
	export metadata_file="$DBUG_DIR/test-tls-crypt-v2.metadata"

	metadata_string="$(cat "${real_metadata_file}")"
	metadata_string_to_vars ${metadata_string} || \
		fail "metadata_string_to_vars"

	real_client_serial=${MD_x509_SERIAL}
	real_UV_TLSKEY_SERIAL=${MD_TLSKEY_SERIAL}
	export UV_TLSKEY_SERIAL=${real_UV_TLSKEY_SERIAL}
	export common_name=${c}
	export ifconfig_pool_remote_ip=1.2.3.4
	export tls_serial_hex_0=${real_client_serial}

	print "------------------------------------------------------------"
	cp "${real_metadata_file}" "${metadata_file}"
	TEST_OPTS="-g=tincantech --via-index --cache-id"
	test_server_scripts

	print "------------------------------------------------------------"
	print "${INVOKE_OPTS} $EASYTLS_CMD -k=bob $EASYTLS_OPTS disable $c"
	${INVOKE_OPTS} "$EASYTLS_CMD" -k=bob $EASYTLS_OPTS disable "$c" || \
		fail "${INVOKE_OPTS} $EASYTLS_CMD --k=bob $EASYTLS_OPTS disable $c"

	print "------------------------------------------------------------"
	cp "${real_metadata_file}" "${metadata_file}"
	TEST_OPTS="-g=tincantech --via-index --cache-id"
	test_server_scripts

	print "============================================================"
	print "${INVOKE_OPTS} $EASYTLS_CMD $EASYTLS_OPTS status"
	${INVOKE_OPTS} "$EASYTLS_CMD" $EASYTLS_OPTS status || \
		fail "Unit test error 63: status"
	print "============================================================"

	print "============================================================"
	print "${INVOKE_OPTS} $EASYTLS_CMD $EASYTLS_OPTS inline-index-rebuild"
	${INVOKE_OPTS} "$EASYTLS_CMD" $EASYTLS_OPTS inline-index-rebuild || \
		fail "Unit test error 64: inline-index-rebuild"
	print "============================================================"

	print "


++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
	print "subtot_expected_errors: $subtot_expected_errors"
	print "total_expected_errors: $total_expected_errors"
	print "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++


"

	eval subtot_${loops}=${subtot_expected_errors}
	subtot_expected_errors=0

	eval loop_${loops}_end_time="$(date +%s)"
	# shellcheck disable=SC1072,SC1073,1009
	eval loop_${loops}_run_mins="$(( (loop_${loops}_end_time - loop_${loops}_start_time) / 60 ))"
	eval loop_${loops}_run_secs="$(( (loop_${loops}_end_time - loop_${loops}_start_time) - ( loop_${loops}_run_mins * 60 ) ))"

	[ $loops -eq $QUIT_LOOP ] && exit 0

done # => loops

# Now test a cross-polinated TCV2 key
final_start_time="$(date +%s)"
print "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++


"
print "


		Now test a cross-polinated TCV2 key


"


###  NOTE: Hard coded directory

### EVERY TEST IS EXPECTED TO FAIL

	# Unset errexit for all easytls-cryptv2-verify.sh
	# because errors are expected and accounted for manually
	#set +e

DBUG_DIR="$WORK_DIR/et-tdir1/easytls/metadata"

	# Test tls-crypt-v2-verify.sh
	export metadata_file="$DBUG_DIR/test-tls-crypt-v2.metadata"
	for c in "c01" "c05" "c06" "c09"
	do
		rm "${metadata_file}"
		print "============================================================"
		print "real_metadata_file=$DBUG_DIR/${c}-tls-crypt-v2.metadata"
		export real_metadata_file="$DBUG_DIR/${c}-tls-crypt-v2.metadata"

		print "------------------------------------------------------------"
		cp "${real_metadata_file}" "${metadata_file}"
		TEST_OPTS=""
		test_server_scripts

		print "------------------------------------------------------------"
		cp "${real_metadata_file}" "${metadata_file}"
		TEST_OPTS="-g=tincantech"
		test_server_scripts

		print "------------------------------------------------------------"
		cp "${real_metadata_file}" "${metadata_file}"
		TEST_OPTS="-g=tincantech -d"
		test_server_scripts

		print "------------------------------------------------------------"
		cp "${real_metadata_file}" "${metadata_file}"
		TEST_OPTS="-g=tincantech --via-ca"
		test_server_scripts

		print "------------------------------------------------------------"
		cp "${real_metadata_file}" "${metadata_file}"
		TEST_OPTS="-g=tincantech --via-index"
		test_server_scripts

		print "------------------------------------------------------------"
		cp "${real_metadata_file}" "${metadata_file}"
		TEST_OPTS="-g=tincantech --via-index --cache-id"
		test_server_scripts

		print "------------------------------------------------------------"
		cp "${real_metadata_file}" "${metadata_file}"
		plcid="$(cat "$PKI_DIR/easytls/data/easytls-ca-identity.txt")"
		TEST_OPTS="-g=tincantech --via-index --preload-id=${plcid}"
		test_server_scripts

		print "------------------------------------------------------------"
		print "${INVOKE_OPTS} $EASYTLS_CMD" --batch disable "$c"
		${INVOKE_OPTS} "$EASYTLS_CMD" --batch disable "$c" || {
			expected_errors $?
			special_errors="$(( special_errors + 1 ))"
			}

		print "------------------------------------------------------------"
		cp "${real_metadata_file}" "${metadata_file}"
		TEST_OPTS=""
		test_server_scripts

		print "------------------------------------------------------------"
		cp "${real_metadata_file}" "${metadata_file}"
		TEST_OPTS="-g=tincantech"
		test_server_scripts

		print "------------------------------------------------------------"
		cp "${real_metadata_file}" "${metadata_file}"
		TEST_OPTS="-g=tincantech -d"
		test_server_scripts

		print "------------------------------------------------------------"
		cp "${real_metadata_file}" "${metadata_file}"
		TEST_OPTS="-g=tincantech --via-ca"
		test_server_scripts

		print "------------------------------------------------------------"
		cp "${real_metadata_file}" "${metadata_file}"
		TEST_OPTS="-g=tincantech --via-index"
		test_server_scripts

		print "------------------------------------------------------------"
		cp "${real_metadata_file}" "${metadata_file}"
		TEST_OPTS="-g=tincantech --via-index --cache-id"
		test_server_scripts

		print "------------------------------------------------------------"
		cp "${real_metadata_file}" "${metadata_file}"
		plcid="$(cat "$PKI_DIR/easytls/data/easytls-ca-identity.txt")"
		TEST_OPTS="-g=tincantech --via-index --preload-id=${plcid}"
		test_server_scripts

		print "------------------------------------------------------------"
		cp "${real_metadata_file}" "${metadata_file}"
		plcid="$(cat "$PKI_DIR/easytls/data/easytls-ca-identity.txt")"
		TEST_OPTS="-g=tincantech --via-index --cache-id --preload-id=${plcid}"
		test_server_scripts

		print
	done

	# Re-enable file-hashing and auto-check
	# Use error code 64 because inline-index-rebuild is disabled
	print "============================================================"
	print "${INVOKE_OPTS} $EASYTLS_CMD $EASYTLS_OPTS cf ac on"
	${INVOKE_OPTS} "$EASYTLS_CMD" $EASYTLS_OPTS cf ac on || \
		fail "Unit test error 64: cf ac on"
	print "============================================================"

	print "============================================================"
	print "${INVOKE_OPTS} $EASYTLS_CMD $EASYTLS_OPTS status"
	${INVOKE_OPTS} "$EASYTLS_CMD" $EASYTLS_OPTS status || \
		fail "Unit test error 65: status"
	print "============================================================"

	# This last rebuild over writes the backup from prior to making+revoke c04+c06
	#rm "$WORK_DIR/et-tdir3/easytls/data/easytls-inline-index.txt.backup"
	#rm "$WORK_DIR/et-tdir3/easytls/data/easytls-inline-index.hash.backup"
	print "============================================================"
	print "${INVOKE_OPTS} $EASYTLS_CMD $EASYTLS_OPTS inline-index-rebuild"
	${INVOKE_OPTS} "$EASYTLS_CMD" $EASYTLS_OPTS inline-index-rebuild || \
		fail "Unit test error 4: $EASYTLS_CMD $EASYTLS_OPTS $UNITTEST_SECURE inline-index-rebuild"

	print "------------------------------------------------------------"
	print "${INVOKE_OPTS} $EASYTLS_CMD $EASYTLS_OPTS cert-expire (also test auto-check)"
	${INVOKE_OPTS} "$EASYTLS_CMD" $EASYTLS_OPTS cert-expire || \
		fail "Unit test error 66: cert-expire"

	print "------------------------------------------------------------"
	print "${INVOKE_OPTS} $EASYTLS_CMD $EASYTLS_OPTS inline-expire (also test auto-check)"
	${INVOKE_OPTS} "$EASYTLS_CMD" $EASYTLS_OPTS inline-expire || \
		fail "Unit test error 67: inline-expire"

	print "------------------------------------------------------------"
	print "${INVOKE_OPTS} $EASYTLS_CMD $EASYTLS_OPTS -k=office remove-inline c10"
	${INVOKE_OPTS} "$EASYTLS_CMD" $EASYTLS_OPTS -k=office remove-inline c10 || \
		fail "Unit test error 68: remove-inline"

	print "------------------------------------------------------------"
	print "${INVOKE_OPTS} $EASYTLS_CMD $EASYTLS_OPTS --k=office remove-tlskey c10"
	${INVOKE_OPTS} "$EASYTLS_CMD" $EASYTLS_OPTS -k=office remove-tlskey c10 || \
		fail "Unit test error 68: remove-tlskey"

	print "------------------------------------------------------------"
	print "${INVOKE_OPTS} $EASYTLS_CMD $EASYTLS_OPTS help"
	${INVOKE_OPTS} "$EASYTLS_CMD" $EASYTLS_OPTS help || \
		fail "Unit test error 68: help"

	print "------------------------------------------------------------"
	print "${INVOKE_OPTS} $EASYTLS_CMD $EASYTLS_OPTS help options"
	${INVOKE_OPTS} "$EASYTLS_CMD" $EASYTLS_OPTS help options || \
		fail "Unit test error 69: help options"

	print "------------------------------------------------------------"
	print "${INVOKE_OPTS} $EASYTLS_CMD $EASYTLS_OPTS help build-tls-crypt-v2-client"
	${INVOKE_OPTS} "$EASYTLS_CMD" $EASYTLS_OPTS help build-tls-crypt-v2-client || \
		fail "Unit test error 70: help build-tls-crypt-v2-client"

	print "------------------------------------------------------------"
	print "${INVOKE_OPTS} $EASYTLS_CMD $EASYTLS_OPTS help import-key"
	${INVOKE_OPTS} "$EASYTLS_CMD" $EASYTLS_OPTS help import-key || \
		fail "Unit test error 70: help import-key"

	print "------------------------------------------------------------"
	print "${INVOKE_OPTS} $EASYTLS_CMD $EASYTLS_OPTS help abb"
	${INVOKE_OPTS} "$EASYTLS_CMD" $EASYTLS_OPTS help abb || \
		fail "Unit test error 70: help abb"

	print "------------------------------------------------------------"
	print "${INVOKE_OPTS} $EASYTLS_CMD $EASYTLS_OPTS help config"
	${INVOKE_OPTS} "$EASYTLS_CMD" $EASYTLS_OPTS help config || \
		fail "Unit test error 70: help config"

	print "------------------------------------------------------------"
	print "${INVOKE_OPTS} $EASYTLS_CMD $EASYTLS_OPTS config"
	${INVOKE_OPTS} "$EASYTLS_CMD" $EASYTLS_OPTS config || \
		fail "Unit test error 70: config"

	#print "------------------------------------------------------------"
	#TEST_CMD="disabled-list-rehash"
	#print "$EASYTLS_CMD $EASYTLS_OPTS $TEST_CMD"
	#"$EASYTLS_CMD" $EASYTLS_OPTS $TEST_CMD || \
	#	fail "Unit test error 72: $TEST_CMD"

	print "------------------------------------------------------------"
	print "${INVOKE_OPTS} $EASYTLS_CMD $EASYTLS_OPTS v4ip 1.2.3.4/24"
	${INVOKE_OPTS} "$EASYTLS_CMD" $EASYTLS_OPTS v4ip 1.2.3.4/24 || \
		expected_errors $?

	print "------------------------------------------------------------"
	print "${INVOKE_OPTS} $EASYTLS_CMD $EASYTLS_OPTS x4ip 1.2.3.4/24"
	${INVOKE_OPTS} "$EASYTLS_CMD" $EASYTLS_OPTS x4ip 1.2.3.4/24 || \
		expected_errors $?

	print "------------------------------------------------------------"
	print "${INVOKE_OPTS} $EASYTLS_CMD $EASYTLS_OPTS x4ip 1.2.3.0/24"
	${INVOKE_OPTS} "$EASYTLS_CMD" $EASYTLS_OPTS x4ip 1.2.3.0/24 || \
		expected_errors $?

	print "------------------------------------------------------------"
	print "${INVOKE_OPTS} $EASYTLS_CMD $EASYTLS_OPTS v6ip 2000::1:2:3:4/64"
	${INVOKE_OPTS} "$EASYTLS_CMD" $EASYTLS_OPTS v6ip 2000::1:2:3:4/64 || \
		expected_errors $?

	print "------------------------------------------------------------"
	print "${INVOKE_OPTS} $EASYTLS_CMD $EASYTLS_OPTS x6ip 2000::1:2:3:4/64"
	${INVOKE_OPTS} "$EASYTLS_CMD" $EASYTLS_OPTS x6ip 2000::1:2:3:4/64 || \
		expected_errors $?

	print "------------------------------------------------------------"
	print "${INVOKE_OPTS} $EASYTLS_CMD $EASYTLS_OPTS x6ip 2000:1:2:3::/64"
	${INVOKE_OPTS} "$EASYTLS_CMD" $EASYTLS_OPTS x6ip 2000:1:2:3::/64 || \
		expected_errors $?

	print "------------------------------------------------------------"
	#print "$EASYTLS_CMD $EASYTLS_OPTS version"
	#"$EASYTLS_CMD" $EASYTLS_OPTS version || \
	#	fail "Unit test error 71: version"

# Version info
tools_version

# Stats
unset EASYTLS_QUIET
final_end_time="$(date +%s)"
final_run_mins="$(( (final_end_time - final_start_time) / 60 ))"
final_run_secs="$(( (final_end_time - final_start_time) - ( final_run_mins * 60 ) ))"

subtot_expected_errors="$(( subtot_expected_errors - special_errors ))"
total_expected_errors="$(( total_expected_errors - special_errors ))"

print "============================================================"
print "Clean up"
clean_up

print "============================================================"
print "subtot_1 $subtot_1 (Expected $sknown_1 Verified)"
print "subtot_2 $subtot_2 (Expected $sknown_2 Verified)"
print "subtot_3 $subtot_3 (Expected $sknown_3 Verified)"
print "Last part cross-polinated: $subtot_expected_errors (Expected $sknown_expected_errors Verified)"

print "total_expected_errors: $total_expected_errors (Expected $known_expected_errors Verified)"
print "special_errors: $special_errors"
print "Completed successfully: $(date +%Y/%m/%d--%H:%M:%S)"
print "============================================================"

print "No-CA Duration: $noca_run_mins minutes $noca_run_secs seconds"
print "loop1 Duration: $loop_1_run_mins minutes $loop_1_run_secs seconds"
print "loop2 Duration: $loop_2_run_mins minutes $loop_2_run_secs seconds"
print "loop3 Duration: $loop_3_run_mins minutes $loop_3_run_secs seconds"
print "Final Duration: $final_run_mins minutes $final_run_secs seconds"

end_time="$(date +%s)"
run_mins="$(( (end_time - start_time) / 60 ))"
run_secs="$(( (end_time - start_time) - ( run_mins * 60 ) ))"
print "Total Duration: $run_mins minutes $run_secs seconds"

print
[ "$total_expected_errors" -eq "$known_expected_errors" ] || {
	print "Expected ERROR count incorrect!"
	exit 9
	}

finish_ok || exit 99
exit 0
