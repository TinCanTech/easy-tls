#!/bin/sh

shellcheck_bin='shellcheck'
[ -f '../shellcheck' ] && shellcheck_bin='../shellcheck'
#[ -f "${shellcheck_bin}" ] || {
#	echo "shellcheck binary not found"
#	exit 1
#	}

#"${shellcheck_bin}" --version || { echo 'croak!' && exit 1; }

SHELLCHECK_OPTS="--shell=sh -x"
unset raw
# shell-o check-o doesn't have -v
case "${1}" in
	-v)
		shift
		[ -z "$*" ] || SHELLCHECK_OPTS="${SHELLCHECK_OPTS} $*"
		shift $#
		# Add to FROST_BITE
		# SC2154 (warning): EASYTLS_RM is referenced but not assigned.
		#FROST_BITE="-o 2154"
	;;
	-vv)
		shift
		SHELLCHECK_OPTS="${SHELLCHECK_OPTS} -o all"
		[ -z "$*" ] || SHELLCHECK_OPTS="${SHELLCHECK_OPTS} $*"
		shift $#
	;;
	-r)
		shift $#
		raw=1
	;;
	'')
		SHELLCHECK_OPTS="${SHELLCHECK_OPTS} -S warning"
	;;
	*)
		SHELLCHECK_OPTS="${SHELLCHECK_OPTS} -S warning"
		[ -z "$*" ] || SHELLCHECK_OPTS="${SHELLCHECK_OPTS} $*"
		shift $#
	;;
esac

# || [ $EASYTLS_VERBOSE ]


# Permanently silence
# SC2016 (info):
#   Expressions don't expand in single quotes, use double quotes for that
# eg. "${EASYTLS_AWK}" '{print $2}'
# seen as a likely error but this information is not needed
#
# SC2086 (info):
#   Double quote to prevent globbing and word splitting.
# eg '[ $log_line ] ] || bar' (the extra ']' is not seen if log_line is not quoted)
# Double quote everything or get hoisted! I will fix this..
PERMA_FROST="-e 2016,2086"
[ -z "${PERMA_FROST}" ] || SHELLCHECK_OPTS="${SHELLCHECK_OPTS} ${PERMA_FROST}"

# Others:
# SC2250 (style):
#   Prefer putting braces around variable references even when not strictly required.
# SC2248 (style):
#   Prefer double quoting even when variables don't contain special characters.
# SC2244 (style):
#   Prefer explicit -n to check non-empty string (or use =/-ne to check boolean/integer
OPTION_FROST="-e 2244,2248,2250"
[ -z "${OPTION_FROST}" ] || SHELLCHECK_OPTS="${SHELLCHECK_OPTS} ${OPTION_FROST}"

# Disable at will
[ -z "${FROST_BITE}" ] || SHELLCHECK_OPTS="${SHELLCHECK_OPTS} ${FROST_BITE}"

# export shellcheck opts
[ -z "${raw}" ] || unset SHELLCHECK_OPTS
export SHELLCHECK_OPTS
#printf '\n%s\n\n' "SHELLCHECK_OPTS: ${SHELLCHECK_OPTS}"

log_line='========================================================================'

printf '\n%s\n%s\n' "$log_line" '*** shellcheck easytls'
"${shellcheck_bin}" easytls || \
	sc_easytls=1

printf '\n%s\n%s\n' "$log_line" '*** shellcheck easytls-cryptv2-verify.sh'
"${shellcheck_bin}" easytls-cryptv2-verify.sh || \
	sc_easytls_cryptv2_verify=1

printf '\n%s\n%s\n' "$log_line" '*** shellcheck easytls-cryptv2-verify.vars-example'
"${shellcheck_bin}" --shell=sh easytls-cryptv2-verify.vars-example || \
	sc_easytls_cryptv2_verify_vars=1

printf '\n%s\n%s\n' "$log_line" '*** shellcheck easytls-client-connect.sh'
"${shellcheck_bin}" easytls-client-connect.sh || \
	sc_easytls_client_connect=1

printf '\n%s\n%s\n' "$log_line" '*** shellcheck easytls-client-connect.vars-example'
"${shellcheck_bin}" --shell=sh easytls-client-connect.vars-example || \
	sc_easytls_client_connect_vars=1

printf '\n%s\n%s\n' "$log_line" '*** shellcheck easytls-client-disconnect.sh'
"${shellcheck_bin}" easytls-client-disconnect.sh || \
	sc_easytls_client_disconnect=1

printf '\n%s\n%s\n' "$log_line" '*** shellcheck easytls-client-disconnect.vars-example'
"${shellcheck_bin}" --shell=sh easytls-client-disconnect.vars-example || \
	sc_easytls_client_disconnect_vars=1

printf '\n%s\n%s\n' "$log_line" '*** shellcheck easytls-tctip.lib'
"${shellcheck_bin}" easytls-tctip.lib || \
	sc_easytls_tctip=1

printf '\n%s\n%s\n' "$log_line" '*** shellcheck easytls-conntrac.lib'
"${shellcheck_bin}" easytls-conntrac.lib || \
	sc_easytls_conntrac=1

printf '\n%s\n%s\n' "$log_line" '*** shellcheck easytls-metadata.lib'
"${shellcheck_bin}" easytls-metadata.lib || \
	sc_easytls_metadata=1

printf '\n%s\n%s\n' "$log_line" '*** shellcheck easytls-unit-tests.sh'
"${shellcheck_bin}" easytls-unit-tests.sh || \
	sc_easytls_unit_tests=1

printf '\n%s\n%s\n' "$log_line" '*** shellcheck easytls-shellcheck.sh'
"${shellcheck_bin}" easytls-shellcheck.sh || \
	sc_easytls_shellcheck=1

printf '\n%s\n' "$log_line"
exit_status=$(( 	sc_easytls + \
					sc_easytls_cryptv2_verify + \
					sc_easytls_client_connect + \
					sc_easytls_client_disconnect + \
					sc_easytls_cryptv2_verify_vars + \
					sc_easytls_client_connect_vars + \
					sc_easytls_client_disconnect_vars + \
					sc_easytls_tctip + \
					sc_easytls_conntrac + \
					sc_easytls_metadata + \
					sc_easytls_unit_tests + \
					sc_easytls_shellcheck \
			 ))

./easytls version || { echo 'croak!' && exit 1; }
"${shellcheck_bin}" --version || { echo 'croak!' && exit 1; }
printf '\n%s\n\n' "SHELLCHECK_OPTS: ${SHELLCHECK_OPTS}"

# dirty trick to log_linel my CI and still record a fail
# IMHO, shellcheck should check for this but does not ...
#[ $exit_status -gt 0 ] && echo "Easy-TLS Shellcheck exit status: $exit_status"
[ $exit_status -eq 0 ] || printf '%s\n\n' "***ERROR*** Easy-TLS Shellcheck exit status: $exit_status (of 12)"
