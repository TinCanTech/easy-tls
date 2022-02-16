#!/bin/sh

shellcheck_bin='shellcheck'
[ -f '../shellcheck' ] && shellcheck_bin='../shellcheck'
#[ -f "${shellcheck_bin}" ] || {
#	echo "shellcheck binary not found"
#	exit 1
#	}

#"${shellcheck_bin}" --version || { echo 'croak!' && exit 1; }

SHELLCHECK_FIXED_OPTS="--shell=sh -x"
unset raw
# shell-o check-o doesn't have -v
case "${1}" in
	-v)
		shift "$#"
		SHELLCHECK_OPTS="${SHELLCHECK_FIXED_OPTS}"
	;;
	-vv)
		shift "$#"
		SHELLCHECK_OPTS="${SHELLCHECK_FIXED_OPTS} -o all"
	;;
	-vvv)
		shift "$#"
		SHELLCHECK_OPTS="-x -o all"
	;;
	-r)
		shift
		raw=1
	;;
	'')
		shift "$#"
		SHELLCHECK_OPTS="${SHELLCHECK_FIXED_OPTS} -S warning"
	;;
	*)
		SHELLCHECK_OPTS="${SHELLCHECK_FIXED_OPTS} $*"
		shift "$#"
	;;
esac

# || [ $EASYTLS_VERBOSE ]


# Permanently silence
# SC2016 (info):
#   Expressions don't expand in single quotes, use double quotes for that
# eg. "${EASYTLS_AWK}" '{print $2}'
# seen as a likely error but this information is not needed
#
# SC2086 (info): Removed
#   Double quote to prevent globbing and word splitting.
# eg '[ $log_line ] ] || bar' (the extra ']' is not seen if log_line is not quoted)
# Double quote everything or get hoisted! I will fix this..
PERMA_FROST="-e 2016"
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
#[ -z "${FROST_BITE}" ] || SHELLCHECK_OPTS="${SHELLCHECK_OPTS} ${FROST_BITE}"

# Append command line, use -i not -o
[ -z "$*" ] || SHELLCHECK_OPTS="${SHELLCHECK_OPTS} $*"

# Mode: shellcheck 'raw'
[ -z "${raw}" ] || SHELLCHECK_OPTS="${SHELLCHECK_FIXED_OPTS} $*"

# Final export
export SHELLCHECK_OPTS

log_line='========================================================================'

printf '\n%s\n%s\n' "$log_line" '*** shellcheck easytls'
"${shellcheck_bin}" ./easytls || \
	sc_easytls=1

printf '\n%s\n%s\n' "$log_line" '*** shellcheck easytls-cryptv2-verify.sh'
"${shellcheck_bin}" ./easytls-cryptv2-verify.sh || \
	sc_easytls_cryptv2_verify=1

printf '\n%s\n%s\n' "$log_line" '*** shellcheck easytls-cryptv2-verify.vars-example'
"${shellcheck_bin}" --shell=sh ./examples/easytls-cryptv2-verify.vars-example || \
	sc_easytls_cryptv2_verify_vars=1

printf '\n%s\n%s\n' "$log_line" '*** shellcheck easytls-client-connect.sh'
"${shellcheck_bin}" ./easytls-client-connect.sh || \
	sc_easytls_client_connect=1

printf '\n%s\n%s\n' "$log_line" '*** shellcheck easytls-client-connect.vars-example'
"${shellcheck_bin}" --shell=sh ./examples/easytls-client-connect.vars-example || \
	sc_easytls_client_connect_vars=1

printf '\n%s\n%s\n' "$log_line" '*** shellcheck easytls-client-disconnect.sh'
"${shellcheck_bin}" ./easytls-client-disconnect.sh || \
	sc_easytls_client_disconnect=1

printf '\n%s\n%s\n' "$log_line" '*** shellcheck easytls-client-disconnect.vars-example'
"${shellcheck_bin}" --shell=sh ./examples/easytls-client-disconnect.vars-example || \
	sc_easytls_client_disconnect_vars=1

printf '\n%s\n%s\n' "$log_line" '*** shellcheck easytls-metadata.lib'
"${shellcheck_bin}" ./dev/easytls-metadata.lib || \
	sc_easytls_metadata=1

printf '\n%s\n%s\n' "$log_line" '*** shellcheck easytls-tctip.lib'
"${shellcheck_bin}" ./dev/easytls-tctip.lib || \
	sc_easytls_tctip=1

printf '\n%s\n%s\n' "$log_line" '*** shellcheck easytls-conntrac.lib'
"${shellcheck_bin}" ./easytls-conntrac.lib || \
	sc_easytls_conntrac=1

printf '\n%s\n%s\n' "$log_line" '*** shellcheck easytls-unit-tests.sh'
"${shellcheck_bin}" ./dev/easytls-unit-tests.sh || \
	sc_easytls_unit_tests=1

printf '\n%s\n%s\n' "$log_line" '*** shellcheck easytls-shellcheck.sh'
"${shellcheck_bin}" ./dev/easytls-shellcheck.sh || \
	sc_easytls_shellcheck=1

printf '\n%s\n' "$log_line"
exit_status=$(( 	sc_easytls + \
					sc_easytls_cryptv2_verify + \
					sc_easytls_client_connect + \
					sc_easytls_client_disconnect + \
					sc_easytls_cryptv2_verify_vars + \
					sc_easytls_client_connect_vars + \
					sc_easytls_client_disconnect_vars + \
					sc_easytls_metadata + \
					sc_easytls_tctip + \
					sc_easytls_conntrac + \
					sc_easytls_unit_tests + \
					sc_easytls_shellcheck \
			 ))

# easytls version
./easytls version || { echo 'croak!' && exit 1; }

# exit status
[ "${exit_status}" -eq 0 ] || printf ' %s\n\n' \
	"***ERROR*** Easy-TLS Shellcheck exit status: $exit_status (of 12)"

# options
printf '%s\n\n' "SHELLCHECK_OPTS: ${SHELLCHECK_OPTS:-===[ No Options ]===}"

# version
unset SHELLCHECK_OPTS # or get more errors
"${shellcheck_bin}" --version || { echo 'vroak!' && exit 1; }

# raw
if [ -n "${raw}" ] && [ "${exit_status}" -ne 0 ]; then
	printf "\n* raw mode * Expect weird stuff and ERRORS\n\n"
fi
