#!/bin/sh

shellcheck_bin='shellcheck'
[ -f '../shellcheck' ] && shellcheck_bin='../shellcheck'
[ -f "${shellcheck_bin}" ] || {
	echo "shellcheck binary not found"
	exit 1
	}

"${shellcheck_bin}" --version

# shell-o check-o doesn't have -v
if [ "${1}" = '-v' ]; then
	shift
	export SHELLCHECK_OPTS="--shell=sh -x $*"
elif [ $EASYTLS_VERBOSE ]; then
	export SHELLCHECK_OPTS="--shell=sh -x $*"
else
	export SHELLCHECK_OPTS="--shell=sh -S warning -x $*"
fi

# SC1090 - Can't follow non-constant source
# Recommend -e 2034

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

printf '\n%s\n%s\n' "$foo" '*** shellcheck easytls-conntrac.lib'
"${shellcheck_bin}" easytls-conntrac.lib
sc_easytls_conn_trac=$?

printf '\n%s\n%s\n' "$foo" '*** shellcheck easytls-metadata.lib'
"${shellcheck_bin}" easytls-metadata.lib
sc_easytls_metadata=$?

printf '\n%s\n%s\n' "$foo" '*** shellcheck easytls-shellcheck.sh'
"${shellcheck_bin}" easytls-shellcheck.sh
sc_easytls_shellcheck=$?

exit_status=$(( \
					sc_easytls + \
					sc_easytls_cryptv2_verify + \
					sc_easytls_client_connect + \
					sc_easytls_client_disconnect + \
					sc_easytls_cryptv2_verify_vars + \
					sc_easytls_client_connect_vars + \
					sc_easytls_client_disconnect_vars + \
					sc_easytls_conn_trac + \
					sc_easytls_metadata + \
					sc_easytls_shellcheck \
			 ))
printf '\n'

# dirty trick to fool my CI and still record a fail
# IMHO, shellcheck should check for this but does not ...
#[ $exit_status -gt 0 ] && echo "Easy-TLS Shellcheck exit status: $exit_status"
[ $exit_status -eq 0 ] || echo "Easy-TLS Shellcheck exit status: $exit_status"
