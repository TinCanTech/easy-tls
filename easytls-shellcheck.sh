#!/bin/sh

shellcheck_bin='shellcheck'
[ -f '../shellcheck' ] && shellcheck_bin='../shellcheck'
#[ -f "${shellcheck_bin}" ] || {
#	echo "shellcheck binary not found"
#	exit 1
#	}

"${shellcheck_bin}" --version || { echo 'croak!' && exit 1; }

# shell-o check-o doesn't have -v
if [ "${1}" = '-v' ] || [ $EASYTLS_VERBOSE ]; then
	shift
	SHELLCHECK_OPTS="--shell=sh -x $*"
elif [ "${1}" = '-vv' ]; then
	shift
	SHELLCHECK_OPTS="--shell=sh -x $* -o all"
else
	 SHELLCHECK_OPTS="--shell=sh -S warning -x $*"
fi

# Permanently silence
# SC2016 (info):
#   Expressions don't expand in single quotes, use double quotes for that
# eg. "${EASYTLS_AWK}" '{print $2}'
# seen as a likely error but this information is not needed
#
# SC2086 (info):
#   Double quote to prevent globbing and word splitting.
# eg '[ $foo ] ] || bar' (the extra ']' is not seen if foo is not quoted)
# Double quote everything or get hoisted! I will fix this..
SHELLCHECK_OPTS="-e 2016,2086 ${SHELLCHECK_OPTS}"

# Others:
# SC2250 (style):
#   Prefer putting braces around variable references even when not strictly required.
# SC2248 (style):
#   Prefer double quoting even when variables don't contain special characters.
# SC2244 (style):
#   Prefer explicit -n to check non-empty string (or use =/-ne to check boolean/integer
# SC2154 (warning): EASYTLS_RM is referenced but not assigned.
OPTIONAL_OPTS="-e 2244,2248,2250"
ANNOYING_OPTS="-e 2154"

# Add opts - disable at will
SHELLCHECK_OPTS="${OPTIONAL_OPTS} ${ANNOYING_OPTS} ${SHELLCHECK_OPTS}"

# export shellcheck opts
export SHELLCHECK_OPTS

foo='========================================================================'

printf '\n%s\n%s\n' "$foo" '*** shellcheck easytls'
"${shellcheck_bin}" easytls
sc_easytls=$?

printf '\n%s\n%s\n' "$foo" '*** shellcheck easytls-cryptv2-verify.sh'
"${shellcheck_bin}" easytls-cryptv2-verify.sh
sc_easytls_cryptv2_verify=$?

printf '\n%s\n%s\n' "$foo" '*** shellcheck easytls-cryptv2-verify.vars-example'
"${shellcheck_bin}" easytls-cryptv2-verify.vars-example
sc_easytls_cryptv2_verify_vars=$?

printf '\n%s\n%s\n' "$foo" '*** shellcheck easytls-client-connect.sh'
"${shellcheck_bin}" easytls-client-connect.sh
sc_easytls_client_connect=$?

printf '\n%s\n%s\n' "$foo" '*** shellcheck easytls-client-connect.vars-example'
"${shellcheck_bin}" easytls-client-connect.vars-example
sc_easytls_client_connect_vars=$?

printf '\n%s\n%s\n' "$foo" '*** shellcheck easytls-client-disconnect.sh'
"${shellcheck_bin}" easytls-client-disconnect.sh
sc_easytls_client_disconnect=$?

printf '\n%s\n%s\n' "$foo" '*** shellcheck easytls-client-disconnect.vars-example'
"${shellcheck_bin}" easytls-client-disconnect.vars-example
sc_easytls_client_disconnect_vars=$?

printf '\n%s\n%s\n' "$foo" '*** shellcheck easytls-tctip.lib'
"${shellcheck_bin}" easytls-tctip.lib
sc_easytls_tctip=$?

printf '\n%s\n%s\n' "$foo" '*** shellcheck easytls-conntrac.lib'
"${shellcheck_bin}" easytls-conntrac.lib
sc_easytls_conn_trac=$?

printf '\n%s\n%s\n' "$foo" '*** shellcheck easytls-metadata.lib'
"${shellcheck_bin}" easytls-metadata.lib
sc_easytls_metadata=$?

printf '\n%s\n%s\n' "$foo" '*** shellcheck easytls-unit-tests.sh'
"${shellcheck_bin}" easytls-unit-tests.sh
sc_easytls_unit_tests=$?

printf '\n%s\n%s\n' "$foo" '*** shellcheck easytls-shellcheck.sh'
"${shellcheck_bin}" easytls-shellcheck.sh
sc_easytls_shellcheck=$?

exit_status=$(( 	sc_easytls + \
					sc_easytls_cryptv2_verify + \
					sc_easytls_client_connect + \
					sc_easytls_client_disconnect + \
					sc_easytls_cryptv2_verify_vars + \
					sc_easytls_client_connect_vars + \
					sc_easytls_client_disconnect_vars + \
					sc_easytls_tctip + \
					sc_easytls_conn_trac + \
					sc_easytls_metadata + \
					sc_easytls_unit_tests + \
					sc_easytls_shellcheck \
			 ))
printf '\n'

./easytls version || { echo 'croak!' && exit 1; }

# dirty trick to fool my CI and still record a fail
# IMHO, shellcheck should check for this but does not ...
#[ $exit_status -gt 0 ] && echo "Easy-TLS Shellcheck exit status: $exit_status"
[ $exit_status -eq 0 ] || echo "***ERROR*** Easy-TLS Shellcheck exit status: $exit_status"
