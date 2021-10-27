#!/bin/sh

# Copyright - negotiable
copyright ()
{
: << VERBATUM_COPYRIGHT_HEADER_INCLUDE_NEGOTIABLE
# easytls-client-connect.sh -- Do simple magic
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

# Help
help_text ()
{
	help_msg="
  easytls-client-connect.sh

  This script is intended to be used by tls-crypt-v2 client keys
  generated by EasyTLS.  See: https://github.com/TinCanTech/easy-tls

  Options:
  help|-h|--help         This help text.
  -v|--verbose           Be a lot more verbose at run time (Not Windows).
  -a|--allow-no-check    If the key has a hardware-address configured
                         and the client did NOT use --push-peer-info
                         then allow the connection.  Otherwise, keys with a
                         hardware-address MUST use --push-peer-info.
  -m|--ignore-mismatch   Ignore tlskey-x509 vs openvpn-x509 mismatch.
  -p|--push-required     Require all clients to use --push-peer-info.
  -c|--crypt-v2-required Require all clients to use a TLS-Crypt-V2 key.
  -k|--key-required      Require all client keys to have a hardware-address.
  -d|--dyn-opts=<FILE>   Path and name of Openvpn client dynamic options file.
  -t|--tmp-dir=<DIR>     Temp directory where server-scripts write data.
                         Default: *nix /tmp/easytls
                                  Windows C:/Windows/Temp/easytls
  -b|--base-dir=<DIR>    Path to OpenVPN base directory. (Windows Only)
                         Default: C:/Progra~1/OpenVPN
  -o|--ovpnbin-dir=<DIR> Path to OpenVPN bin directory. (Windows Only)
                         Default: C:/Progra~1/OpenVPN/bin
  -e|--ersabin-dir=<DIR> Path to Easy-RSA3 bin directory. (Windows Only)
                         Default: C:/Progra~1/Openvpn/easy-rsa/bin

  Exit codes:
  0   - Allow connection, Client hwaddr is correct or not required.
  2   - Disallow connection, pushed hwaddr does not match.
  3   - Disallow connection, hwaddr required and not pushed.
  4   - Disallow connection, hwaddr required and not keyed.
  5   - Disallow connection, Kill client.
  6   - Disallow connection, TLS Auth/Crypt-v1 banned
  7   - Disallow connection, X509 certificate incorrect for this TLS-key.
  8   - Disallow connection, missing X509 client cert serial. (BUG)
  9   - Disallow connection, unexpected failure. (BUG)

  18  - BUG Disallow connection, failed to read c_ext_md_file
  19  - BUG Disallow connection, failed to parse metadata strig

  21  - USER ERROR Disallow connection, options error.

  60  - USER ERROR Disallow connection, missing Temp dir
  61  - USER ERROR Disallow connection, missing Base dir
  62  - USER ERROR Disallow connection, missing Easy-RSA bin dir
  63  - USER ERROR Disallow connection, missing Openvpn bin dir
  64  - USER ERROR Disallow connection, missing openssl.exe
  65  - USER ERROR Disallow connection, missing cat.exe
  66  - USER ERROR Disallow connection, missing date.exe
  67  - USER ERROR Disallow connection, missing grep.exe
  68  - USER ERROR Disallow connection, missing sed.exe
  69  - USER ERROR Disallow connection, missing printf.exe
  70  - USER ERROR Disallow connection, missing rm.exe

  253 - Disallow connection, exit code when --help is called.
  254 - BUG Disallow connection, fail_and_exit() exited with default error code.
  255 - BUG Disallow connection, die() exited with default error code.
"
	print "${help_msg}"

	# For secrity, --help must exit with an error
	exit 253
}

# Wrapper around 'printf' - clobber 'print' since it's not POSIX anyway
# shellcheck disable=SC1117
print () { "${EASYTLS_PRINTF}" "%s\n" "${1}"; }
verbose_print ()
{
	[ "${EASYTLS_VERBOSE}" ] || return 0
	print "${1}"
	print ""
}


# Exit on error
die ()
{
	# TLSKEY connect log
	tlskey_status "FATAL" || update_status "tlskey_status FATAL"

	verbose_print "<ERROR> ${status_msg}"
	[ -z "${help_note}" ] || print "${help_note}"
	[ -z "${failure_msg}" ] || print "${failure_msg}"
	print "ERROR: ${1}"
	[ $EASYTLS_FOR_WINDOWS ] && "${EASYTLS_PRINTF}" "%s\n%s\n" \
		"<ERROR> ${status_msg}" "ERROR: ${1}" > "${EASYTLS_WLOG}"
	#exit "${2:-255}"
	echo 'XXXXX CC - Kill Server XXXXX'
	echo 1 > "${temp_stub}-die"
	if [ $ENABLE_KILL_PPID ]
	then
		if [ $EASYTLS_FOR_WINDOWS ]
		then
			"${EASYTLS_PRINTF}" "%s\n%s\n" \
				"<ERROR> ${status_msg}" "ERROR: ${1}" > "${EASYTLS_WLOG}"
			[ $DISABLE_KILL_PPID ] || taskkill /F /PID ${EASYTLS_srv_pid}
		else
			[ $DISABLE_KILL_PPID ] || kill -15 ${EASYTLS_srv_pid}
		fi
	fi
	exit "${2:-255}"
}

# failure not an error
fail_and_exit ()
{
	delete_metadata_files
	stack_down || die "stack_down - fail_and_exit"

	print "<FAIL> ${status_msg}"
	print "${failure_msg}"
	print "${1}"

	# TLSKEY connect log
	tlskey_status "FAIL" || update_status "tlskey_status FAIL"

	[ $EASYTLS_FOR_WINDOWS ] && "${EASYTLS_PRINTF}" "%s\n%s\n" \
		"<FAIL> ${status_msg}" "${failure_msg}" "${1}" > "${EASYTLS_WLOG}"
	exit "${2:-254}"
} # => fail_and_exit ()

# Delete all metadata files
delete_metadata_files ()
{
	# shellcheck disable=SC2154 # auth_control_file
	"${EASYTLS_RM}" -f \
		"${EASYTLS_KILL_FILE}" \
		"${fixed_md_file}" "${fake_md_file}"

	update_status "temp-files deleted"
}

# Log fatal warnings
warn_die ()
{
	if [ -n "${1}" ]
	then
		fatal_msg="${fatal_msg}
${1}"
	else
		[ -z "${fatal_msg}" ] || die "${fatal_msg}" 21
	fi
}

# Update status message
update_status ()
{
	status_msg="${status_msg} => ${*}"
}

# Remove colons ':' and up-case
format_number ()
{
	"${EASYTLS_PRINTF}" '%s' "${1}" | \
		"${EASYTLS_SED}" -e 's/://g' -e 'y/abcdef/ABCDEF/'
}

# Allow connection
connection_allowed ()
{
	absolute_fail=0
	update_status "connection allowed"
}

# Update conntrac
update_conntrac ()
{
	prog_dir="${0%/*}"
	lib_file="${prog_dir}/easytls-conntrac.lib"
	[ -f "${lib_file}" ] || {
		easytls_url="https://github.com/TinCanTech/easy-tls"
		easytls_wiki="/wiki/download-and-install"
		#easytls_rawurl="https://raw.githubusercontent.com/TinCanTech/easy-tls"
		#easytls_file="/master/easytls-conntrac.lib"
		help_note="See: ${easytls_url}${easytls_wiki}"
		die "Missing ${lib_file}"
		}
	. "${lib_file}"
	unset prog_dir lib_file

	# Absolute start time
	easytls_start_d_file="${EASYTLS_CONN_TRAC}-start-d"
	if [ -f "${easytls_start_d_file}" ]
	then
		easytls_start_d="$("$EASYTLS_CAT" "${easytls_start_d_file}")"
	else
		# shellcheck disable=SC2154
		"${EASYTLS_PRINTF}" '%s' \
			"${daemon_start_time}" > "${easytls_start_d_file}"
		# shellcheck disable=SC2034
		easytls_start_d="$("$EASYTLS_CAT" "${easytls_start_d_file}")"
	fi

	# Begin conntrac_record
	conntrac_record="${UV_TLSKEY_SERIAL:-TLSAC}=${client_serial}"
	conntrac_record="${conntrac_record}==${common_name}"

	# Detect IP Pool exhausted
	# shellcheck disable=SC2154
	if [ -z "${ifconfig_pool_remote_ip}" ]
	then
		# Kill the server
		[ $POOL_EXHAUST_FATAL ] && {
			ENABLE_KILL_PPID=1
			die "IP_POOL_EXHASTED" 101
			}

		# Otherwise, the client will connect but get no IP
		ip_pool_exhausted=1
		conntrac_record="${conntrac_record}==0.0.0.0"
		"${EASYTLS_PRINTF}" '\n%s\n\n' \
			"********* WARNING: IP POOL EXHAUSTED *********"

		# This will kill the client
		[ $POOL_EXHAUST_KILL_CLIENT ] && {
			"${EASYTLS_CAT}" "${EASYTLS_DYN_OPTS_FILE}"
			"${EASYTLS_PRINTF}" '%s\n' "disable"
		} > "${ovpn_dyn_opts_file}"
	else
		conntrac_record="${conntrac_record}==${ifconfig_pool_remote_ip}"
	fi

	# shellcheck disable=SC2154
	conntrac_record="${conntrac_record}++${untrusted_ip}:${untrusted_port}"

	conn_trac_connect "${conntrac_record}" "${EASYTLS_CONN_TRAC}" || {
			case $? in
			6)	# Duplicate TLSKEY
				update_status "conn_trac_connect DUPLICATE_TLSKEY"
				conntrac_dupl=1
			;;
			2)	# Duplicate record, includes VPN-IP 0.0.0.0 (Pool exhausted)
				update_status "conn_trac_connect FAIL"
				conntrac_fail=1
			;;
			1)	# Fatal because these are usage errors
				update_status "conn_trac_connect ERROR"
				conntrac_error=1
			;;
			*)	# Absolutely fatal
				conntrac_unknown=1
			;;
			esac
			}

	# Log failure
	if [ $conntrac_dupl ] || [ $conntrac_fail ] || \
		[ $conntrac_error ] ||[ $conntrac_unknown ]
	then
		{
			[ -f "${EASYTLS_CONN_TRAC}.fail" ] && \
					"${EASYTLS_CAT}" "${EASYTLS_CONN_TRAC}.fail"
				"${EASYTLS_PRINTF}" '%s '  "$(date '+%x %X')"
				[ $conntrac_fail ] && "${EASYTLS_PRINTF}" '%s ' "Pre-Reg"
				[ $conntrac_error ] && "${EASYTLS_PRINTF}" '%s ' "ERROR"
				[ $ip_pool_exhausted ] && "${EASYTLS_PRINTF}" '%s ' "IP-POOL"
				[ $conntrac_dupl ] && "${EASYTLS_PRINTF}" '%s ' "DUPL-TLSK"
				[ $conntrac_unknown ] && "${EASYTLS_PRINTF}" '%s ' "UNKNOWN!"
				"${EASYTLS_PRINTF}" '%s\n' "CON: ${conntrac_record}"
		} > "${EASYTLS_CONN_TRAC}.fail.tmp" || die "connect: conntrac file"
		"${EASYTLS_MV}" "${EASYTLS_CONN_TRAC}.fail.tmp" \
			"${EASYTLS_CONN_TRAC}.fail" || die "connect: conntrac file"

		env_file="${temp_stub}-client-connect.env"
		if [ $EASYTLS_FOR_WINDOWS ]; then
			set > "${env_file}" || die "connect: conntrac env"
		else
			env > "${env_file}" || die "connect: conntrac env"
		fi

		# Absolutely fatal
		[ $conntrac_unknown ] && {
			ENABLE_KILL_PPID=1
			die "CONNTRAC_CONNECT_UNKNOWN" 98
			}

		# # Fatal because these are usage errors
		[ $conntrac_error ] && [ $FATAL_CONN_TRAC ] && {
			ENABLE_KILL_PPID=1
			die "CONNTRAC_CONNECT_ERROR" 99
			}

		# Duplicate record, includes VPN-IP 0.0.0.0 (Pool exhausted)
		[ $conntrac_fail ] && [ $FATAL_CONN_TRAC_2 ] && {
			ENABLE_KILL_PPID=1
			die "CONNTRAC_CONNECT_FAIL_2" 91
			}

		# Duplicate TLS keys
		if [ $conntrac_dupl ]
		then
			[ ! $ENFORCE_UNIQUE_TLSKEY ] || fail_and_exit "Duplicate TLS Key"
			update_status "IGNORE Duplicate TLS Key"
		fi
	fi
	unset env_file conntrac_record conntrac_fail conntrac_error
} # => update_contrac ()

# Stack down
stack_down ()
{
	if [ -f "${fixed_md_file}_1" ]
	then
		unset stack_err
		i=1
		d=$(( i - 1 ))
		"${EASYTLS_MV}" "${fixed_md_file}_1" "${fixed_md_file}" || stack_err=1
		s="-1"

		while :
		do
			i=$(( i + 1 ))
			d=$(( i - 1 ))
			if [ -f "${fixed_md_file}_${i}" ]
			then
				"${EASYTLS_MV}" "${fixed_md_file}_${i}" \
					"${fixed_md_file}_${d}" || stack_err=1
				s="${s}-${i}"
			else
				break
			fi
		done

		update_status "stack-down"
		tlskey_status "^ stack-dn: ${s} >"
		[ ! $stack_err ] || die "STACK_DOWN"
	else
		update_status "stack-clear"
		tlskey_status "^ stack-dn: clear >"
	fi
}

# TLSKEY tracking .. because ..
tlskey_status ()
{
	[ $EASYTLS_TLSKEY_STATUS ] || return 0
	dt="$("${EASYTLS_DATE}")"
	{
		"${EASYTLS_PRINTF}" '%s ' "${dt}"
		"${EASYTLS_PRINTF}" '%s ' "TLSKEY:${UV_TLSKEY_SERIAL:-TLSAC}"
		"${EASYTLS_PRINTF}" '%s\n' "Conn-${1}"
	} >> "${EASYTLS_TK_XLOG}"
}

# Initialise
init ()
{
	# Fail by design
	absolute_fail=1

	# Defaults
	EASYTLS_srv_pid=$PPID

	# Log message
	status_msg="* EasyTLS-client-connect"

	# Identify Windows
	EASYRSA_KSH='@(#)MIRBSD KSH R39-w32-beta14 $Date: 2013/06/28 21:28:57 $'
	[ "${KSH_VERSION}" = "${EASYRSA_KSH}" ] && EASYTLS_FOR_WINDOWS=1

	# Required binaries
	EASYTLS_OPENSSL='openssl'
	EASYTLS_CAT='cat'
	EASYTLS_DATE='date'
	EASYTLS_GREP='grep'
	EASYTLS_MV='mv'
	EASYTLS_SED='sed'
	EASYTLS_PRINTF='printf'
	EASYTLS_RM='rm'

	# Directories and files
	if [ $EASYTLS_FOR_WINDOWS ]
	then
		# Windows
		host_drv="${PATH%%\:*}"
		base_dir="${EASYTLS_base_dir:-${host_drv}:/Progra~1/Openvpn}"
		EASYTLS_ersabin_dir="${EASYTLS_ersabin_dir:-${base_dir}/easy-rsa/bin}"
		EASYTLS_ovpnbin_dir="${EASYTLS_ovpnbin_dir:-${base_dir}/bin}"

		[ -d "${base_dir}" ] || exit 61
		[ -d "${EASYTLS_ersabin_dir}" ] || exit 62
		[ -d "${EASYTLS_ovpnbin_dir}" ] || exit 63
		[ -f "${EASYTLS_ovpnbin_dir}/${EASYTLS_OPENSSL}.exe" ] || exit 64
		[ -f "${EASYTLS_ersabin_dir}/${EASYTLS_CAT}.exe" ] || exit 65
		[ -f "${EASYTLS_ersabin_dir}/${EASYTLS_DATE}.exe" ] || exit 66
		[ -f "${EASYTLS_ersabin_dir}/${EASYTLS_GREP}.exe" ] || exit 67
		[ -f "${EASYTLS_ersabin_dir}/${EASYTLS_MV}.exe" ] || exit 71
		[ -f "${EASYTLS_ersabin_dir}/${EASYTLS_SED}.exe" ] || exit 68
		[ -f "${EASYTLS_ersabin_dir}/${EASYTLS_PRINTF}.exe" ] || exit 69
		[ -f "${EASYTLS_ersabin_dir}/${EASYTLS_RM}.exe" ] || exit 70

		export PATH="${EASYTLS_ersabin_dir};${EASYTLS_ovpnbin_dir};${PATH}"
	fi
} # => init ()

# Dependancies
deps ()
{
	if [ $EASYTLS_FOR_WINDOWS ]
	then
		WIN_TEMP="${host_drv}:/Windows/Temp"
		export EASYTLS_tmp_dir="${EASYTLS_tmp_dir:-${WIN_TEMP}}"
	else
		export EASYTLS_tmp_dir="${EASYTLS_tmp_dir:-/tmp}"
	fi

	# Test temp dir
	[ -d "${EASYTLS_tmp_dir}" ] || exit 60

	# Temp files name stub
	temp_stub="${EASYTLS_tmp_dir}/easytls-${EASYTLS_srv_pid}"

	# Windows log
	EASYTLS_WLOG="${temp_stub}-client-connect.log"
	EASYTLS_TK_XLOG="${temp_stub}-tcv2-ct.x-log"

	# Source metadata lib
	prog_dir="${0%/*}"
	lib_file="${prog_dir}/easytls-metadata.lib"
	[ -f "${lib_file}" ] || die "Missing ${lib_file}"
	. "${lib_file}"
	unset lib_file

	# Conn track
	EASYTLS_CONN_TRAC="${temp_stub}-conn-trac"

	# Kill server file
	[ -f "${temp_stub}-die" ] && echo "Kill Server Signal -> exit CC" && exit 9

	# Kill client file
	EASYTLS_KILL_FILE="${temp_stub}-kill-client"

	# Dynamic opts file
	if [ -f "${EASYTLS_DYN_OPTS_FILE}" ] && [ -n "${ovpn_dyn_opts_file}" ]
	then
		"${EASYTLS_CAT}" "${EASYTLS_DYN_OPTS_FILE}" > "${ovpn_dyn_opts_file}"
		update_status "dyn opts loaded"
	fi
}

#######################################

# Initialise
init

# Options
while [ -n "${1}" ]
do
	# Separate option from value:
	opt="${1%%=*}"
	val="${1#*=}"
	empty_ok="" # Empty values are not allowed unless expected

	case "${opt}" in
	help|-h|--help)
		empty_ok=1
		help_text
	;;
	-l|--vars)
		vars_file="${val}"
	;;
	-v|--verbose)
		empty_ok=1
		EASYTLS_VERBOSE=1
	;;
	-d|--dyn-opts)
		EASYTLS_DYN_OPTS_FILE="${val}"
		[ -f "${EASYTLS_DYN_OPTS_FILE}" ] || \
			warn_die "Easy-TLS dynamic opts file missing"
	;;
	-a|--allow-no-check)
		empty_ok=1
		allow_no_check=1
	;;
	-m|--ignore-mismatch) # tlskey-x509 does not match openvpn-x509
		empty_ok=1
		ignore_x509_mismatch=1
	;;
	-p|--push-hwaddr-required)
		empty_ok=1
		push_hwaddr_required=1
	;;
	-c|--crypt-v2-required)
		empty_ok=1
		crypt_v2_required=1
	;;
	-k|--key-hwaddr-required)
		empty_ok=1
		key_hwaddr_required=1
	;;
	-b|--base-dir)
		EASYTLS_base_dir="${val}"
	;;
	-t|--tmp-dir)
		EASYTLS_tmp_dir="${val}"
	;;
	-o|--openvpn-bin-dir)
		EASYTLS_ovpnbin_dir="${val}"
	;;
	-e|--easyrsa-bin-dir)
		EASYTLS_ersabin_dir="${val}"
	;;
	*)
		empty_ok=1
		if [ -f "${opt}" ]
		then
			# Do not need this in the log but keep it here for reference
			#[ $EASYTLS_VERBOSE ] && echo "Ignoring temp file: $opt"
			ovpn_dyn_opts_file="${opt}"
		else
			[ "${EASYTLS_VERBOSE}" ] && warn_die "Unknown option: ${opt}"
		fi
	;;
	esac

	# fatal error when no value was provided
	if [ ! $empty_ok ] && { [ "${val}" = "${1}" ] || [ -z "${val}" ]; }; then
		warn_die "Missing value to option: ${opt}"
	fi
	shift
done

# Report and die on fatal warnings
warn_die

# Source vars file
if [ -f "${vars_file}" ]
then
	. "${vars_file}" || die "source failed: ${vars_file}"
	update_status "vars loaded"
else
	update_status "No vars loaded"
fi

# Dependencies
deps

# Write env file
[ $WRITE_ENV ] && {
	env_file="${temp_stub}-client-connect.env"
	if [ $EASYTLS_FOR_WINDOWS ]; then
		set > "${env_file}"
	else
		env > "${env_file}"
	fi
	unset env_file
	}


# flush auth-control file
#"${EASYTLS_RM}" -f "${auth_control_file}"

# Update log message
# shellcheck disable=SC2154 # common_name
[ -n "${common_name}" ] || die "Missing common_name"
update_status "CN: ${common_name}"

# Set Client certificate serial number from Openvpn env
# shellcheck disable=SC2154
client_serial="$(format_number "${tls_serial_hex_0}")"

# Verify Client certificate serial number
[ -z "${client_serial}" ] && {
	help_note="Openvpn failed to pass a client serial number"
	die "NO CLIENT SERIAL" 8
	}

# Update connection tracking
if [ $ENABLE_CONN_TRAC ]
then
	update_conntrac || die "update_conntrac FAIL"
	update_status "conn-trac updated"
else
	update_status "conn-trac disabled"
fi

# Check for kill signal
if [ -f "${EASYTLS_KILL_FILE}" ] && \
	"${EASYTLS_GREP}" -q "${client_serial}" "${EASYTLS_KILL_FILE}"
then
	# Kill client
	kill_this_client=1
	update_status "Kill client signal"
fi

# fake file for TLS-AC
generic_md_stub="${temp_stub}-tac-metadata"
client_md_stub="${generic_md_stub}-${client_serial}"
fake_md_file="${client_md_stub}-fake"

# Fixed file for TLS-CV2
if [ -n "${UV_TLSKEY_SERIAL}" ]
then
	fixed_md_file="${temp_stub}-tcv2-metadata-${UV_TLSKEY_SERIAL}"
	update_status "tls key serial: ${UV_TLSKEY_SERIAL}"
else
	update_status "CLIENT FAILED TO PUSH UV_TLSKEY_SERIAL"

		# This is correct behaviour for --tls-auth/crypt v1
		# Create a fake metadata file
		# Add indicator for TLS Auth/Crypt
		# TODO: check for existing file
		"${EASYTLS_PRINTF}" '%s' '=TLSAC= =000000000000=' > \
			"${fake_md_file}" || \
				die "Failed to create fake_md_file"
		update_status "created fake_md_file"
fi

# Verify tcv2_metadata_file
if [ -n "${fixed_md_file}" ] && [ -f "${fixed_md_file}" ]
then
	# Set Client tlskey_serial
	#tls_crypt_v2=1

	# Get client metadata_string
	metadata_string="$("${EASYTLS_CAT}" "${fixed_md_file}")"
	[ -n "${metadata_string}" ] || \
		fail_and_exit "failed to read fixed_md_file" 18
	# Populate client metadata variables
	client_metadata_string_to_vars || die "client_metadata_string_to_vars"
	[ -n "${c_tlskey_serial}" ] || \
		fail_and_exit "failed to set c_tlskey_serial" 19
	unset metadata_string
	update_status "fixed_md_file loaded"

	# shellcheck disable=SC2154
	if [ ${c_md_serial} = ${client_serial} ]
	then
		update_status "metadata -> x509 serial match"
	else
		[ $ignore_x509_mismatch ] || {
			failure_msg="TLS-key is being used by the wrong client certificate"
			fail_and_exit "TLSKEY_X509_SERIAL-OVPN_X509_SERIAL-MISMATCH*1" 6
			}
		update_status "IGNORE metadata -> x509 serial mismatch"
	fi

elif [ -n "${fixed_md_file}" ] && [ ! -f "${fixed_md_file}" ]
then
	# This client pushed an incorrect UV_TLSKEY_SERIAL
	[ ! $ENFORCE_TLSKEY_SERIAL_MATCH ] || {
		failure_msg="PUSHED UV_TLSKEY_SERIAL ${UV_TLSKEY_SERIAL}"
		fail_and_exit "INCORRECT UV_TLSKEY_SERIAL PUSHED"
		}
	update_status "IGNORE incorrect UV_TLSKEY_SERIAL"

elif [ -f "${fake_md_file}" ]
then
	# Require crypt-v2
	[ $crypt_v2_required ] && {
			failure_msg="TLS Auth/Crypt key not allowed"
			fail_and_exit "TLS_CRYPT_V2 ONLY" 6
			}
	update_status "IGNORE TLS-Auth/Crypt-v1 only"
	fixed_md_file="${generic_md_stub}-${client_serial}"
	if [ -f "${fixed_md_file}" ]
	then
		help_note="* Duplicate certificate *"
		die "Exists fixed_md_file"
	else
		"${EASYTLS_MV}" "${fake_md_file}" "${fixed_md_file}" || \
			die "Failed to create fake fixed_md_file"
		update_status "Moved fake_md_file to fixed_md_file"
	fi

	# TLS Auth/Crypt cannot do extended checks so allow_no_check
	#tls_acv1_only=1

else
	die "Unexpected condition"
fi

# Set hwaddr from Openvpn env
# This is not a dep. different clients may not push-peer-info
push_hwaddr="$(format_number "${IV_HWADDR}")"
[ -z "${push_hwaddr}" ] && \
	push_hwaddr_missing=1 && update_status "hwaddr not pushed"
if [ $push_hwaddr_missing ]
then
	# hwaddr is NOT pushed
	[ $push_hwaddr_required ] && {
		failure_msg="Client did not push required hwaddr"
		fail_and_exit "PUSHED HWADDR REQUIRED BUT NOT PUSHED" 3
		}
	# hwaddr not pushed and not required
	update_status "IGNORE hwaddr not required"
fi

# allow_no_check
case $allow_no_check in
1)
	# disable all checks
	update_status "Allow ALL TLS keys"
	connection_allowed
;;
*)
	# Check for TLS Auth/Crypt
	if "${EASYTLS_GREP}" -q '^=TLSAC=[[:blank:]]=' "${fixed_md_file}"
	then
		# TLS Auth/Crypt
		update_status "TLS Auth/Crypt key only"
		[ $push_hwaddr_required ] && [ $push_hwaddr_missing ] && {
			failure_msg="TLS Auth/Crypt no pushed hwaddr"
			fail_and_exit "PUSHED HWADDR REQUIRED BUT NOT PUSHED" 3
			}
		[ $crypt_v2_required ] && {
			failure_msg="TLS Auth/Crypt key not allowed"
			fail_and_exit "TLS_CRYPT_V2 ONLY" 6
			}
		[ $key_hwaddr_required ] && {
			failure_msg="TLS Auth/Crypt key enforce verify hwaddr"
			fail_and_exit "TLS_CRYPT_V2 ONLY " 6
			}
		# TLS Auth/Crypt-v1 allowed here
		connection_allowed
	else
		# TLS-Crypt-V2

		# Set only for NO keyed hwaddr
		# Old field
		if "${EASYTLS_GREP}" -q '[[:blank:]]000000000000$' "${fixed_md_file}"
		then
			key_hwaddr_missing=1
		fi

		# New field
		if "${EASYTLS_GREP}" -q '=000000000000=$' "${fixed_md_file}"
		then
			key_hwaddr_missing=1
		fi

		# Verify hwaddr
		# hwaddr is pushed
		if [ $key_hwaddr_missing ]
		then
			# key does not have a hwaddr
			update_status "Key is not locked to hwaddr"
			[ $key_hwaddr_required ] && {
				failure_msg="Key hwaddr required but missing"
				fail_and_exit "KEYED HWADDR REQUIRED BUT NOT KEYED" 4
				}
			# No keyed hwaddr and TLS-crypt-v2
			connection_allowed
		else
			if "${EASYTLS_GREP}" -q "+${push_hwaddr}+" "${fixed_md_file}"
			then
				# push and MATCH! - Old format
				update_status "hwaddr ${push_hwaddr} pushed and matched"
				connection_allowed

			elif "${EASYTLS_GREP}" -q "=${push_hwaddr}=" "${fixed_md_file}"
			then
				# push and MATCH! - New format
				update_status "hwaddr ${push_hwaddr} pushed and matched"
				connection_allowed

			else
				# push does not match key hwaddr
				# If the x509 is a mismatch then hwaddr almost certainly will be
				if [ $ignore_x509_mismatch ]
				then
					connection_allowed
					update_status "Ignored hwaddr mismatch!"
				else
					failure_msg="hwaddr mismatch - pushed: ${push_hwaddr}"
					fail_and_exit "HWADDR MISMATCH" 2
				fi
			fi
		fi
	fi
esac # allow_no_check

# Any failure_msg means fail_and_exit
[ -n "${failure_msg}" ] && fail_and_exit "NEIN: ${failure_msg}" 9

# For DUBUG
[ "${FORCE_ABSOLUTE_FAIL}" ] && \
	absolute_fail=1 && failure_msg="FORCE_ABSOLUTE_FAIL"

# Collect kill signal
[ $kill_this_client ] && fail_and_exit "KILL_CLIENT_SIGNAL" 5

# There is only one way out of this...
if [ $absolute_fail -eq 0 ]
then
	# Delete all temp files
	delete_metadata_files || die "CON: delete_metadata_files() ?"
	stack_down || die "stack_down - exit"

	# TLSKEY connect log
	tlskey_status "OK" || update_status "tlskey_status FAIL"

	# All is well
	verbose_print "<EXOK> ${status_msg}"
	[ $EASYTLS_FOR_WINDOWS ] && "${EASYTLS_PRINTF}" "%s\n" \
		"${status_msg}" > "${EASYTLS_WLOG}"
	exit 0
fi

# Otherwise
fail_and_exit "ABSOLUTE FAIL" 9
