#!/bin/sh

# Copyright - negotiable
copyright ()
{
: << VERBATUM_COPYRIGHT_HEADER_INCLUDE_NEGOTIABLE
# easytls-client-disconnect.sh -- Do simple magic
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
  easytls-client-disconnect.sh

  This script is intended to be used by tls-crypt-v2 client keys
  generated by EasyTLS.  See: https://github.com/TinCanTech/easy-tls

  Options:
  help|-h|--help         This help text.
  -v|--verbose           Be a lot more verbose at run time (Not Windows).

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
	verbose_print "<ERROR> ${status_msg}"
	[ -z "${help_note}" ] || print "${help_note}"
	[ -z "${failure_msg}" ] || print "${failure_msg}"
	print "ERROR: ${1}"
	[ $EASYTLS_FOR_WINDOWS ] && "${EASYTLS_PRINTF}" "%s\n%s\n" \
		"<ERROR> ${status_msg}" "ERROR: ${1}" > "${EASYTLS_WLOG}"
	#exit "${2:-255}"
	echo 'XXXXX CD - Kill Server XXXXX'
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
	#delete_metadata_files
	print "<FAIL> ${status_msg}"
	print "${failure_msg}"
	print "${1}"

	# TLSKEY connect log
	tlskey_status "FAIL" || update_status "tlskey_status FAIL"

	[ $EASYTLS_FOR_WINDOWS ] && "${EASYTLS_PRINTF}" "%s\n%s\n" \
		"<FAIL> ${status_msg}" "${failure_msg}" "${1}" > "${EASYTLS_WLOG}"
	exit "${2:-254}"
} # => fail_and_exit ()

# Delete all metadata files - Currently UNUSED
delete_metadata_files ()
{
	"${EASYTLS_RM}" -f \
		"${EASYTLS_KILL_FILE}"

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
disconnect_accepted ()
{
	absolute_fail=0
	update_status "disconnect completed"
}

# Update conntrac
update_conntrac ()
{
	# Source conn-trac lib
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
	unset lib_file

	# Update connection tracking
	conntrac_record="${UV_TLSKEY_SERIAL:-TLSAC}"
	conntrac_record="${conntrac_record}=${client_serial}"
	# If common_name is not set then this is bug 160-2
	# Use username, which is still set, when common_name is lost
	# Set the username alternative first
	# shellcheck disable=SC2154
	conntrac_alt_rec="${conntrac_record}==${username}"
	conntrac_alt2_rec="${conntrac_record}==${X509_0_CN}"
	# shellcheck disable=SC2154
	conntrac_record="${conntrac_record}==${common_name}"

	# shellcheck disable=SC2154
	if [ -z "${ifconfig_pool_remote_ip}" ]
	then
		[ $FATAL_CON_TRAC ] && fail_and_exit "IP_POOL_EXHASTED" 101
		ip_pool_exhausted=1
		conntrac_record="${conntrac_record}==0.0.0.0"
		conntrac_alt_rec="${conntrac_alt_rec}==0.0.0.0"
		conntrac_alt2_rec="${conntrac_alt2_rec}==0.0.0.0"
	else
		conntrac_record="${conntrac_record}==${ifconfig_pool_remote_ip}"
		conntrac_alt_rec="${conntrac_alt_rec}==${ifconfig_pool_remote_ip}"
		conntrac_alt2_rec="${conntrac_alt2_rec}==${ifconfig_pool_remote_ip}"
	fi

	# shellcheck disable=SC2154
	conntrac_record="${conntrac_record}++${untrusted_ip}:${untrusted_port}"
	conntrac_alt_rec="${conntrac_alt_rec}++${untrusted_ip}:${untrusted_port}"
	conntrac_alt2_rec="${conntrac_alt2_rec}++${untrusted_ip}:${untrusted_port}"

	# Disconnect common_name
	conn_trac_disconnect "${conntrac_record}" "${EASYTLS_CONN_TRAC}" || {
		case $? in
		3)	# Missing conntrac file - Can happen if IP Pool exhausted
			[ $ip_pool_exhausted ] || {
				ENABLE_KILL_PPID=1
				die "CONNTRAC_DISCONNECT_FILE_MISSING" 97
				}
			# Ignore this error because it is expected
			update_status "IGNORE missing ct file due to IP POOL EXHAUSTED"
		;;
		2)	# Not fatal because errors are expected #160
			update_status "conn_trac_disconnect FAIL"
			conntrac_fail=1
			log_env=1
		;;
		1)	# Fatal because these are usage errors
			[ $FATAL_CONN_TRAC ] && {
				ENABLE_KILL_PPID=1
				die "CONNTRAC_DISCONNECT_FILE_ERROR" 99
				}
			update_status "conn_trac_disconnect ERROR"
			conntrac_error=1
			log_env=1
		;;
		*)	# Absolutely fatal
			ENABLE_KILL_PPID=1
			die "CONNTRAC_DISCONNECT_UNKNOWN" 98
		;;
		esac
		}

	# If the first failed for number two then try again ..
	if [ $conntrac_fail ]
	then
		# Disconnect username
		conn_trac_disconnect "${conntrac_alt_rec}" "${EASYTLS_CONN_TRAC}" || {
			case $? in
			2)	# fatal later - because errors could happen #160
				update_status "conn_trac_disconnect A-FAIL"
				conntrac_alt_fail=1
				log_env=1
			;;
			1)	# Fatal because these are usage errors
				[ $FATAL_CONN_TRAC ] && {
					ENABLE_KILL_PPID=1
					die "CONNTRAC_DISCONNECT_ALT_FILE_ERROR" 99
					}
				update_status "conn_trac_disconnect A-ERROR"
				conntrac_alt_error=1
				log_env=1
			;;
			*)	# Absolutely fatal
				ENABLE_KILL_PPID=1
				die "CONNTRAC_DISCONNECT_UNKNOWN" 98
			;;
			esac
			}
	fi

	# Log failure
	if [ $conntrac_fail ] || [ $conntrac_error ]
	then
		{
			[ -f "${EASYTLS_CONN_TRAC}.fail" ] && \
				"${EASYTLS_CAT}" "${EASYTLS_CONN_TRAC}.fail"
			"${EASYTLS_PRINTF}" '%s '  "$(date '+%x %X')"
			[ $conntrac_fail ] && "${EASYTLS_PRINTF}" '%s ' "NFound"
			[ $conntrac_error ] && "${EASYTLS_PRINTF}" '%s ' "ERROR"
			[ $ip_pool_exhausted ] && "${EASYTLS_PRINTF}" '%s ' "IP-POOL"
			"${EASYTLS_PRINTF}" '%s\n' "DIS: ${conntrac_record}"
		} > "${EASYTLS_CONN_TRAC}.fail.tmp" || die "disconnect: conntrac file"
		"${EASYTLS_MV}" "${EASYTLS_CONN_TRAC}.fail.tmp" \
			"${EASYTLS_CONN_TRAC}.fail" || die "disconnect: conntrac file"
	fi

	if [ $conntrac_alt_fail ] || [ $conntrac_alt_error ]
	then
		{
			[ -f "${EASYTLS_CONN_TRAC}.fail" ] && \
				"${EASYTLS_CAT}" "${EASYTLS_CONN_TRAC}.fail"
			"${EASYTLS_PRINTF}" '%s '  "$(date '+%x %X')"
			[ $conntrac_alt_fail ] && "${EASYTLS_PRINTF}" '%s ' "A-NFound"
			[ $conntrac_alt_error ] && "${EASYTLS_PRINTF}" '%	s ' "A-ERROR"
			[ $ip_pool_exhausted ] && "${EASYTLS_PRINTF}" '%s ' "IP-POOL"
			"${EASYTLS_PRINTF}" '%s\n' "DIS: ${conntrac_alt_rec}"
		} > "${EASYTLS_CONN_TRAC}.fail.tmp" || die "disconnect: conntrac file"
		"${EASYTLS_MV}" "${EASYTLS_CONN_TRAC}.fail.tmp" \
			"${EASYTLS_CONN_TRAC}.fail" || die "disconnect: conntrac file"
	fi

	# Capture env
	if [ $log_env ]
	then
		env_file="${temp_stub}-client-disconnect.env"
		if [ $EASYTLS_FOR_WINDOWS ]; then
			set > "${env_file}" || die "disconnect: env"
		else
			env > "${env_file}" || die "disconnect: env"
		fi
		unset env_file
	fi

	# This error is currently absolutely fatal
	# If IP pool exhausted then ignore conntrac_alt_fail
	[ ! $ip_pool_exhausted ] && [ $conntrac_alt_fail ] && {
		ENABLE_KILL_PPID=1
		die "disconnect: conntrac_alt_fail"
		}

	# OpenVPN Bug #160
	if [ $conntrac_fail ]
	then
		if [ $ip_pool_exhausted ]
		then
			# Ignored
			update_status "IP_POOL_EXHAUSTED IGNORED"
		else
			# Recovered from fail - Add your plugin
			:
			#update_status "disconnect: recovered"
		fi
	else
		# conntrac worked - Add your plugin
		:
		#update_status "disconnect: succeeded"
	fi
	unset \
		conntrac_fail conntrac_alt_fail \
		conntrac_error conntrac_alt_error \
		ip_pool_exhausted log_env
} # => update_conntrac ()

# TLSKEY tracking .. because ..
tlskey_status ()
{
	[ $EASYTLS_TLSKEY_STATUS ] || return 0
	dt="$("${EASYTLS_DATE}")"
	{
		"${EASYTLS_PRINTF}" '%s ' "${dt}"
		"${EASYTLS_PRINTF}" '%s ' "TLSKEY:${UV_TLSKEY_SERIAL:-TLSAC}"
		"${EASYTLS_PRINTF}" '%s\n' "DISCONNECTED-${1}"
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
	status_msg="* EasyTLS-client-disconnect"

	# Identify Windows
	EASYRSA_KSH='@(#)MIRBSD KSH R39-w32-beta14 $Date: 2013/06/28 21:28:57 $'
	[ "${KSH_VERSION}" = "${EASYRSA_KSH}" ] && EASYTLS_FOR_WINDOWS=1

	# Required binaries
	EASYTLS_OPENSSL='openssl'
	EASYTLS_AWK='awk'
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
		[ -f "${EASYTLS_ersabin_dir}/${EASYTLS_AWK}.exe" ] || exit 65
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
	EASYTLS_WLOG="${temp_stub}-client-disconnect.log"
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
	[ -f "${temp_stub}-die" ] && echo "Kill Server Signal -> exit CD" && exit 9

	# Kill client file
	EASYTLS_KILL_FILE="${temp_stub}-kill-client"
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
	-l)
		vars_file="${val}"
	;;
	-v|--verbose)
		empty_ok=1
		EASYTLS_VERBOSE=1
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
			:
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
	env_file="${temp_stub}-client-disconnect.env"
	if [ $EASYTLS_FOR_WINDOWS ]; then
		set > "${env_file}"
	else
		env > "${env_file}"
	fi
	unset env_file
	}

# Update log message
# shellcheck disable=SC2154 # common_name
update_status "CN: ${common_name}"

# Set Client certificate serial number from Openvpn env
# shellcheck disable=SC2154
client_serial="$(format_number "${tls_serial_hex_0}")"

# Verify Client certificate serial number
[ -z "${client_serial}" ] && {
	help_note="Openvpn failed to pass a client serial number"
	die "NO CLIENT SERIAL" 8
	}

# Any failure_msg means fail_and_exit
[ -n "${failure_msg}" ] && fail_and_exit "NEIN: ${failure_msg}" 9

# For DUBUG
[ "${FORCE_ABSOLUTE_FAIL}" ] && \
	absolute_fail=1 && failure_msg="FORCE_ABSOLUTE_FAIL"

# conntrac
if [ $ENABLE_CONN_TRAC ]
then
	update_conntrac || die "update_conntrac"
	update_status "conn-trac updated"
else
	update_status "conn-trac disabled"
fi

# disconnect can not fail ..
disconnect_accepted

# There is only one way out of this...
if [ $absolute_fail -eq 0 ]
then
	# Delete all temp files
	#delete_metadata_files

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
