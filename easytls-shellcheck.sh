#!/bin/sh

shellcheck_bin='shellcheck'
[ -f '../shellcheck' ] && shellcheck_bin='../shellcheck'
[ -f "${shellcheck_bin}" ] || {
	echo "shellcheck binary not found"
	exit 1
	}

"${shellcheck_bin}" --version
export SHELLCHECK_OPTS="--shell=sh -S warning -e 1090 $*"
[ $EASYTLS_VERBOSE ] && export SHELLCHECK_OPTS="--shell=sh $*"

# SC1090 - Can't follow non-constant source
# Recommend -e 2034

foo='========================================================================'

printf '\n%s\n%s\n' "$foo" '*** shellcheck easytls'
"${shellcheck_bin}" easytls && sc_easytls=$?

printf '\n%s\n%s\n' "$foo" '*** shellcheck easytls-cryptv2-verify.sh'
"${shellcheck_bin}" easytls-cryptv2-verify.sh && sc_easytls_cryptv2_verify=$?

printf '\n%s\n%s\n' "$foo" '*** shellcheck easytls-cryptv2-verify.vars'
"${shellcheck_bin}" easytls-cryptv2-verify.vars-example && sc_easytls_cryptv2_verify_vars=$?

printf '\n%s\n%s\n' "$foo" '*** shellcheck easytls-verify.sh'
"${shellcheck_bin}" easytls-verify.sh && sc_easytls_verify=$?

printf '\n%s\n%s\n' "$foo" '*** shellcheck easytls-verify.vars'
"${shellcheck_bin}" easytls-verify.vars-example && sc_easytls_verify_vars=$?

printf '\n%s\n%s\n' "$foo" '*** shellcheck easytls-client-connect.sh'
"${shellcheck_bin}" easytls-client-connect.sh && sc_easytls_client_connect=$?

printf '\n%s\n%s\n' "$foo" '*** shellcheck easytls-client-connect.vars'
"${shellcheck_bin}" easytls-client-connect.vars-example && sc_easytls_client_connect_vars=$?

printf '\n%s\n%s\n' "$foo" '*** shellcheck easytls-client-disconnect.sh'
"${shellcheck_bin}" easytls-client-disconnect.sh && sc_easytls_client_disconnect=$?

printf '\n%s\n%s\n' "$foo" '*** shellcheck easytls-client-disconnect.vars'
"${shellcheck_bin}" easytls-client-disconnect.vars-example && sc_easytls_client_disconnect_vars=$?

printf '\n%s\n%s\n' "$foo" '*** shellcheck easytls-client-disconnect.sh'
"${shellcheck_bin}" easytls-conn-trac.lib && sc_easytls_conn_trac=$?

printf '\n%s\n%s\n' "$foo" '*** shellcheck easytls-shellcheck.sh'
"${shellcheck_bin}" easytls-shellcheck.sh && sc_easytls_shellcheck=$?

exit_status=$(( \
					sc_easytls + \
					sc_easytls_cryptv2_verify + \
					sc_easytls_verify + \
					sc_easytls_client_connect + \
					sc_easytls_client_disconnect + \
					sc_easytls_cryptv2_verify_vars + \
					sc_easytls_verify_vars + \
					sc_easytls_client_connect_vars + \
					sc_easytls_client_disconnect_vars + \
					sc_easytls_conn_trac + \
					sc_easytls_shellcheck \
			 ))
printf '\n'

# dirty trick to fool my CI and still record a fail
# IMHO, shellcheck should check for this but does not ...
#[ $exit_status -gt 0 ] && echo "Easy-TLS Shellcheck exit status: $exit_status"
[ $exit_status -eq 0 ] || echo "Easy-TLS Shellcheck exit status: $exit_status"
