#!/bin/sh

EASYTLS_VERSION="2.8.0"

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
  -V|--version
  -v|--verbose           Be a lot more verbose at run time (Not Windows).
  -w|--work-dir=<DIR>    Path to Easy-TLS scripts and vars for this server.
  -a|--allow-no-check    If the key has a hardware-address configured
                         and the client did NOT use --push-peer-info
                         then allow the connection.  Otherwise, keys with a
                         hardware-address MUST use --push-peer-info.
  -M|--ignore-x509-mismatch
                         Ignore tlskey-x509 vs openvpn-x509 mismatch.
  -m|--ignore-hw-mismatch
                         Ignore tlskey-hwaddr vs openvpn-hwaddr mismatch.
  -p|--push-required     Require all clients to use --push-peer-info.
  -c|--crypt-v2-required Require all clients to use a TLS-Crypt-V2 key.
  -k|--key-required      Require all client keys to have a hardware-address.
  -s|--source-ip-match   Match client source IP to Key metadata.
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

  12  - Disallow connection, source IPaddr does not match.

  18  - BUG Disallow connection, failed to read client_md_file_stack
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
  71  - USER ERROR Disallow connection, missing metadata.lib

  77  - BUG Disallow connection, failed to sources vars file
  160 - BUG Disallow connection, stack error
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
print () { "${EASYTLS_PRINTF}" '%s\n' "${1}"; }
verbose_print ()
{
	[ -n "${EASYTLS_VERBOSE}" ] || return 0
	print "${1}"
	print ''
}
banner ()
{
	[ -n "${EASYTLS_VERBOSE}" ] || return 0
	"${EASYTLS_PRINTF}" '\n%s\n\n' "${1}"
}

# Set the Easy-TLS version
easytls_version ()
{
	verbose_print
	print "Easy-TLS version: ${EASYTLS_VERSION}"
	verbose_print
} # => easytls_version ()

# Exit on error
die ()
{
	# TLSKEY connect log
	tlskey_status "FATAL" || update_status "tlskey_status FATAL"

	easytls_version
	verbose_print "<ERROR> ${status_msg}"
	[ -z "${help_note}" ] || print "${help_note}"
	[ -z "${failure_msg}" ] || print "${failure_msg}"
	print "ERROR: ${1}"
	[ -n "${EASYTLS_FOR_WINDOWS}" ] && "${EASYTLS_PRINTF}" "%s\n%s\n" \
		"<ERROR> ${status_msg}" "ERROR: ${1}" > "${EASYTLS_WLOG}"
	#exit "${2:-255}"
	if [ $ENABLE_KILL_SERVER ]; then
		echo 1 > "${temp_stub}-die"
		echo 'XXXXX CC XXXXX KILL SERVER'
		if [ -n "${EASYTLS_FOR_WINDOWS}" ]; then
			"${EASYTLS_PRINTF}" "%s\n%s\n" \
				"<ERROR> ${status_msg}" "ERROR: ${1}" > "${EASYTLS_WLOG}"
			taskkill /F /PID ${EASYTLS_srv_pid}
		else
			kill -15 ${EASYTLS_srv_pid}
		fi
	fi
	exit "${2:-255}"
} # => die ()

# failure not an error
fail_and_exit ()
{
	delete_metadata_files

	# stack_down does not errot to fail_and_exit, no need to remove lock
	#stack_down || die "stack_down - fail_and_exit"
	# Unlock
	#release_lock "${easytls_lock_stub}-stack.d" || \
	#		die "release_lock:stack FAIL" 99
	#update_status "stack-lock-released"

	print "<FAIL> ${status_msg}"
	print "${failure_msg}"
	print "${1} ${2}"

	# TLSKEY connect log
	tlskey_status "!*! FAIL" || update_status "tlskey_status FAIL"

	[ -n "${EASYTLS_FOR_WINDOWS}" ] && "${EASYTLS_PRINTF}" "%s\n%s\n" \
		"<FAIL> ${status_msg}" "${failure_msg}" "${1} ${2}" > "${EASYTLS_WLOG}"
	exit "${2:-254}"
} # => fail_and_exit ()

# Delete all metadata files
delete_metadata_files ()
{
	# shellcheck disable=SC2154 # auth_control_file
	"${EASYTLS_RM}" -f "${EASYTLS_KILL_FILE}"

	# stack_down takes care of "${client_md_file_stack}"

	update_status "temp-files deleted"
} # => delete_metadata_files ()

# Log fatal warnings
warn_die ()
{
	if [ -n "${1}" ]; then
		fatal_msg="${fatal_msg}
${1}"
	else
		[ -z "${fatal_msg}" ] || die "${fatal_msg}" 21
	fi
} # => warn_die ()

# Update status message
update_status ()
{
	status_msg="${status_msg} => ${*}"
} # => update_status ()

# Remove colons ':' and up-case
format_number ()
{
	"${EASYTLS_PRINTF}" '%s' "${1}" | \
		"${EASYTLS_SED}" -e 's/://g' -e 'y/abcdef/ABCDEF/'
} # => format_number ()

#=# 9273398a-5284-4c1f-aec5-d597ceb1d085

# Verbose message
verbose_easytls_tctip_lib ()
{
	[ -n "${EASYTLS_SILENT}" ] && return 0
	[ -n "${EASYTLS_TCTIP_LIB_VERBOSE}" ] || return 0
	"${EASYTLS_PRINTF}" '%s\n' "${1}"
} # => verbose_easytls_tctip_lib ()

# Front end validate IP address
validate_ip_address ()
{
	[ "${1}" = "${1%%.*}" ] || ipv4=1
	[ "${1}" = "${1%%:*}" ] || ipv6=1
	[ -n "${ipv4}${ipv6}" ] || return 1
	[ -n "${ipv4}" ] && [ -n "${ipv6}" ] && \
		easytls_verbose "Unsupported <:Port>" && return 1
	[ -n "${ipv4}" ] && validate_ip4_data "$@" && valid4=1
	[ -n "${ipv6}" ] && validate_ip6_data "$@" && valid6=1
	[ -n "${valid4}" ] && [ -n "${valid6}" ] && return 1
	[ -n "${valid4}" ] || [ -n "${valid6}" ] || return 1
} # => validate_ip_address ()

# Exit with error
invalid_address ()
{
	case "${1}" in
	1) print "easytls invalid" ;;
	10) print "excess input" ;;
	11) print "illegal format" ;;
	12) print "illegal mask" ;;
	13) print "mask range" ;;
	14) print "leading zero" ;;
	15) print "class range" ;;
	16) print "class count" ;;
	17) print "cidr mask" ;;
	18) print "input error" ;;
	19) print "ip2dec error" ;;
	20)
		print "ip6/mask-length mismatch"
		print "ip6/mask correct example: 1:22:333:4444:5::/80"
	;;
	*) print "undocumented ${1} ?" ;;
	esac
} # => invalid_address ()

# IPv4 address to decimal
ip2dec ()
{
	case "${1}" in
		*[!1234567890.]* | .* | *. | *..* ) return 1 ;;
		*.*.*.* ) : ;; #OK
		* ) return 1 ;;
	esac

	temp_ip_addr="${1}"
	a="${temp_ip_addr%%.*}"; temp_ip_addr="${temp_ip_addr#*.}"
	b="${temp_ip_addr%%.*}"; temp_ip_addr="${temp_ip_addr#*.}"
	c="${temp_ip_addr%%.*}"; temp_ip_addr="${temp_ip_addr#*.}"
	d="${temp_ip_addr%%.*}"

	for i in "${a}" "${b}" "${c}" "${d}"; do
		[ "${#i}" -eq 1 ] && continue
		[ -z "${i%%0*}" ] && return 1
		{ [ 0 -gt "${i}" ] || [ "${i}" -gt 255 ]; } && return 1
	done
	ip4_dec="$(( (a << 24) + (b << 16) + (c << 8) + d ))" || return 1
	unset -v temp_ip_addr a b c d
} # => ip2dec ()

# IPv4 CIDR mask length to decimal
cidrmask2dec ()
{
	mask_dec=0
	imsk_dec=0
	count=32 # or 128 - If possible..
	power=1
	while [ "${count}" -gt 0 ]; do
		count="$(( count - 1 ))"
		if [ "${1}" -gt "${count}" ]; then
			# mask
			mask_dec="$(( mask_dec + power ))"
		else
			# inverse
			imsk_dec="$(( imsk_dec + power ))"
		fi
		power="$(( power * 2 ))"
	done
	unset -v count power
} # => cidrmask2dec ()

# EXPAND IPv6
expand_ip6_address ()
{
	[ -z "${2}" ] || return 10
	in_ip_addr="${1}"
	shift

	in_valid_hextets="${in_ip_addr%/*}"
	in_valid_mask_len="${in_ip_addr##*/}"
	unset -v in_ip_addr

	# mask length
	case "${in_valid_mask_len}" in
	"${in_valid_hextets}" | '' ) in_valid_mask_len=128 ;;
	[!1234567890] | 0* ) return 11 ;;
	* ) : # OK
	esac
	if [ 0 -gt "${in_valid_mask_len}" ] || [ "${in_valid_mask_len}" -gt 128 ]
	then
		return 11
	fi

	# ADDRESS 6
	temp_valid_hextets="${in_valid_hextets}"

	# expand leading colon
	[ "${temp_valid_hextets}" = "${temp_valid_hextets#:}" ] || \
		lead_colon=1
	[ -z "${lead_colon}" ] || temp_valid_hextets="0${temp_valid_hextets}"

	# Count valid compressed hextets
	count_valid_hextets=0
	while [ -n "${temp_valid_hextets}" ]; do
		count_valid_hextets="$(( count_valid_hextets + 1 ))"
		[ "${temp_valid_hextets}" = "${temp_valid_hextets#*:}" ] && \
			temp_valid_hextets="${temp_valid_hextets}:"
		temp_valid_hextets="${temp_valid_hextets#*:}"
		temp_valid_hextets="${temp_valid_hextets#:}"
	done
	verbose_easytls_tctip_lib "count_valid_hextets: ${count_valid_hextets}"

	# expand double colon
	temp_valid_hextets="${in_valid_hextets}"
	expa_valid_hextets="${in_valid_hextets}"
	if [ "${count_valid_hextets}" -lt 8 ]; then
		hi_part="${temp_valid_hextets%::*}"
		lo_part="${temp_valid_hextets#*::}"
		missing_zeros="$(( 8 - count_valid_hextets ))"
		while [ "${missing_zeros}" -gt 0 ]; do
			hi_part="${hi_part}:0"
			missing_zeros="$(( missing_zeros - 1 ))"
		done
		unset -v missing_zeros
		expa_valid_hextets="${hi_part}:${lo_part}"
		# Re-expand leading colon
		[ -z "${lead_colon}" ] || expa_valid_hextets="0${expa_valid_hextets}"
	fi
	# Save the orangutan
	unset -v lead_colon lo_part hi_part count_valid_hextets
	verbose_easytls_tctip_lib "expa_valid_hextets: ${expa_valid_hextets}"

	temp_valid_hextets="${expa_valid_hextets}"
	hex_count=8
	unset -v full_valid_hextets delim
	# Expand compressed zeros
	while [ "${hex_count}" -gt 0 ]; do
		hextet="${temp_valid_hextets%%:*}"
		while [ "${#hextet}" -lt 4 ]; do
			hextet="0${hextet}"
		done
		full_valid_hextets="${full_valid_hextets}${delim}${hextet}"
		delim=':'
		temp_valid_hextets="${temp_valid_hextets#*:}"
		hex_count="$(( hex_count - 1 ))"
	done
	# Save "The violence inherent in the system"
	unset -v hex_count delim
	verbose_easytls_tctip_lib "full_valid_hextets: ${full_valid_hextets}"

	# Split IP at mask_len
	[ "$(( in_valid_mask_len % 4 ))" -eq 0 ] || \
		die "in_valid_mask_len % 4: ${in_valid_mask_len}"
	hex_mask="$(( in_valid_mask_len / 4 ))"

	temp_valid_hextets="${full_valid_hextets}"
	while [ "${hex_mask}" -gt 0 ]; do
		delete_mask="${temp_valid_hextets#?}"
		verbose_easytls_tctip_lib "delete_mask: ${delete_mask}"
		hex_char="${temp_valid_hextets%"${delete_mask}"}"
		verbose_easytls_tctip_lib "hex_char: ${hex_char}"
		temp_valid_hextets="${temp_valid_hextets#?}"
		verbose_easytls_tctip_lib "temp_valid_hextets: ${temp_valid_hextets}"
		full_subnet_addr6="${full_subnet_addr6}${hex_char}"
		verbose_easytls_tctip_lib "full_subnet_addr6: ${full_subnet_addr6}"
		[ "${hex_char}" = ':' ] || hex_mask="$(( hex_mask - 1 ))"
		verbose_easytls_tctip_lib "*** hex_mask: ${hex_mask}"
	done
	# Save the polar ice-caps
	unset -v hex_char hex_mask delete_mask

	# The remainder should equal zero
	while [ -n "${temp_valid_hextets}" ]; do
		hextet="${temp_valid_hextets%%:*}"
		if [ -z "${hextet}" ]; then
			temp_valid_hextets="${temp_valid_hextets#*:}"
			hextet="${temp_valid_hextets%%:*}"
		fi

		[ "${temp_valid_hextets}" = "${temp_valid_hextets#*:}" ] && \
			temp_valid_hextets="${temp_valid_hextets}:"
		temp_valid_hextets="${temp_valid_hextets#*:}"

		# shellcheck disable=SC2249 # (info): default *) case
		case "${hextet}" in
			*[!0:]* ) return 20 ;;
		esac
	done
	verbose_easytls_tctip_lib "full_valid_hextets: ${full_valid_hextets}"
	verbose_easytls_tctip_lib "full_subnet_addr6: ${full_subnet_addr6}"
	verbose_easytls_tctip_lib "temp_valid_hextets: ${temp_valid_hextets}"
	# Save the trees
	unset -v hextet temp_valid_hextets
	# Return full_valid_hextets full_subnet_addr6
} # => expand_ip6_address ()

#=# b66633f8-3746-436a-901f-29638199b187

# Allow connection
connection_allowed ()
{
	absolute_fail=0
	update_status "connection allowed"
} # => connection_allowed ()

# Update conntrac
update_conntrac ()
{
	# Source tctip lib
	lib_file="${EASYTLS_WORK_DIR}/easytls-conntrac.lib"
	[ -f "${lib_file}" ] || \
		lib_file="${EASYTLS_WORK_DIR}/dev/easytls-conntrac.lib"
	# shellcheck source=./easytls-conntrac.lib
	if [ -f "${lib_file}" ]; then
		. "${lib_file}" || die "Source failed: ${lib_file}" 77
		unset lib_file
	else
		die "Missing file: ${lib_file}" 77
	fi

	prog_dir="${0%/*}"
	lib_file="${prog_dir}/easytls-conntrac.lib"
	[ -f "${lib_file}" ] || {
		easytls_url="https://github.com/TinCanTech/easy-tls"
		easytls_wiki="/wiki/download-and-install"
		#easytls_rawurl="https://raw.githubusercontent.com/TinCanTech/easy-tls"
		#easytls_file="/master/easytls-conntrac.lib"
		help_note="See: ${easytls_url}${easytls_wiki}"
		die "Missing ${lib_file}" 159
		}
	# shellcheck source=./easytls-conntrac.lib
	. "${lib_file}"
	unset -v prog_dir lib_file

	# Absolute start time
	easytls_start_d_file="${EASYTLS_CONN_TRAC}-start-d"
	if [ ! -f "${easytls_start_d_file}" ]; then
		# shellcheck disable=SC2154
		"${EASYTLS_PRINTF}" '%s' \
			"${daemon_start_time}" > "${easytls_start_d_file}"
	fi
	# shellcheck disable=SC2034
	easytls_start_d="$("$EASYTLS_CAT" "${easytls_start_d_file}")"

	# Begin conntrac_record
	conntrac_record="${UV_TLSKEY_SERIAL:-TLSAC}=${client_serial}"
	conntrac_record="${conntrac_record}==${common_name}"

	# Detect IP Pool exhausted
	# shellcheck disable=SC2154
	if [ -z "${ifconfig_pool_remote_ip}" ]; then
		# Kill the server
		[ $POOL_EXHAUST_FATAL ] && {
			ENABLE_KILL_SERVER=1
			die "IP_POOL_EXHASTED" 101
			}

		# Otherwise, the client will connect but get no IP
		ip_pool_exhausted=1
		conntrac_record="${conntrac_record}==0.0.0.0"
		banner "********* WARNING: IP POOL EXHAUSTED *********"

		# This will kill the client
		[ $POOL_EXHAUST_KILL_CLIENT ] && {
			"${EASYTLS_CAT}" "${EASYTLS_DYN_OPTS_FILE}"
			"${EASYTLS_PRINTF}" '%s\n' "disable"
			} > "${ovpn_dyn_opts_file}"
	else
		conntrac_record="${conntrac_record}==${ifconfig_pool_remote_ip}"
	fi

	# shellcheck disable=SC2154
	[ -z "${peer_id}" ] || conntrac_record="${conntrac_record}==${peer_id}"

	# shellcheck disable=SC2154
	conntrac_record="${conntrac_record}==${time_ascii}"
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
			9)	# Absolutely fatal
				ENABLE_KILL_SERVER=1
				die "CONNTRAC_CONNECT_CT_LOCK_9" 96
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
		if [ $ENABLE_CONNTRAC_FAIL_LOG ]; then
			{
			[ -f "${EASYTLS_CONN_TRAC}.fail" ] && \
					"${EASYTLS_CAT}" "${EASYTLS_CONN_TRAC}.fail"
				"${EASYTLS_PRINTF}" '%s '  "$("${EASYTLS_DATE}" '+%x %X')"
				[ $conntrac_fail ] && "${EASYTLS_PRINTF}" '%s ' "Pre-Reg"
				[ $conntrac_error ] && "${EASYTLS_PRINTF}" '%s ' "ERROR"
				[ $ip_pool_exhausted ] && "${EASYTLS_PRINTF}" '%s ' "IP-POOL"
				[ $conntrac_dupl ] && "${EASYTLS_PRINTF}" '%s ' "DUPL-TLSK"
				[ $conntrac_unknown ] && "${EASYTLS_PRINTF}" '%s ' "UNKNOWN!"
				"${EASYTLS_PRINTF}" '%s\n' "CON: ${conntrac_record}"
			} > "${EASYTLS_CONN_TRAC}.fail.tmp" || die "conn: conntrac file" 156
			"${EASYTLS_MV}" "${EASYTLS_CONN_TRAC}.fail.tmp" \
				"${EASYTLS_CONN_TRAC}.fail" || die "conn: conntrac file" 157
		fi # ENABLE_CONNTRAC_FAIL_LOG

		# Absolutely fatal
		[ $conntrac_unknown ] && {
			ENABLE_KILL_SERVER=1
			die "CONNTRAC_CONNECT_UNKNOWN" 98
			}

		# # Fatal because these are usage errors
		[ $conntrac_error ] && [ $FATAL_CONN_TRAC ] && {
			ENABLE_KILL_SERVER=1
			die "CONNTRAC_CONNECT_ERROR" 99
			}

		# Duplicate record, includes VPN-IP 0.0.0.0 (Pool exhausted)
		[ $conntrac_fail ] && [ $FATAL_CONN_TRAC_2 ] && {
			ENABLE_KILL_SERVER=1
			die "CONNTRAC_CONNECT_FAIL_2" 91
			}

		# Duplicate TLS keys
		if [ $conntrac_dupl ]; then
			[ ! $ENFORCE_UNIQUE_TLSKEY ] || fail_and_exit "Duplicate TLS Key"
			update_status "IGNORE Duplicate TLS Key"
		fi
	fi
	unset -v env_file conntrac_record conntrac_fail conntrac_error
} # => update_contrac ()

# Stack down
stack_down ()
{
	[ $stack_completed ] && die "STACK_DOWN CAN ONLY RUN ONCE" 161
	stack_completed=1

	#[ $ENABLE_STACK ] || return 0

	# file exists or the client pushed an incorrect UV_TLSKEY_SERIAL
	[ -f "${client_md_file_stack}" ] || return 0

	# Lock
	acquire_lock "${easytls_lock_stub}-stack.d" || \
			die "acquire_lock:stack FAIL" 99
	update_status "stack-lock-acquired"

	unset -v stack_err
	i=0
	s=''

	# Full Stack DOWN
	while :
	do
		i=$(( i + 1 ))
		if [ -f "${client_md_file_stack}_${i}" ]; then
			[ ${i} -eq 1 ] || s="${s}."
		else
			if [ ${i} -eq 1 ]; then
				# There are no stacked files so delete the original
				[ -f "${client_md_file_stack}" ] || die "***" 163
				"${EASYTLS_RM}" "${client_md_file_stack}" || stack_err=1
				update_status "stack-down: clear"
				tlskey_status "  | =  stack: clear -"
			else
				# Delete the last file found
				p=$(( i - 1 ))
				[ -f "${client_md_file_stack}_${p}" ] || die "_i***" 164
				"${EASYTLS_RM}" "${client_md_file_stack}_${p}" || stack_err=1
				update_status "stack-down: ${p}"
				tlskey_status "  | <= stack:- ${s}${p} -"
			fi
			break
		fi
	done

	# Unlock
	release_lock "${easytls_lock_stub}-stack.d" || \
		die "release_lock:stack FAIL" 99
	update_status "stack-lock-released"

	[ ! $stack_err ] || die "STACK_DOWN_FULL_ERROR" 160
} # => stack_down ()

# TLSKEY tracking .. because ..
tlskey_status ()
{
	# >> may fail on easytls/github/actions/wtest - No TERM
	[ $EASYTLS_TLSKEY_STATUS ] || return 0
	{
		# shellcheck disable=SC2154
		"${EASYTLS_PRINTF}" '%s %s %s %s\n' "${local_date_ascii}" \
			"${UV_TLSKEY_SERIAL:-TLSAC}" "CONN:${1}" \
			"${common_name} ${UV_REAL_NAME}"
	} >> "${EASYTLS_TK_XLOG}"
} # => tlskey_status ()

# Retry pause
retry_pause ()
{
	if [ -n "${EASYTLS_FOR_WINDOWS}" ]; then
		ping -n 1 127.0.0.1
	else
		sleep 1
	fi
} # => retry_pause ()

# Simple lock dir
acquire_lock ()
{
	[ -n "${1}" ] || return 1
	unset lock_acquired
	lock_attempt="${LOCK_TIMEOUT}"
	set -o noclobber
	while [ ${lock_attempt} -gt 0 ]; do
		[ ${lock_attempt} -eq "${LOCK_TIMEOUT}" ] || retry_pause
		lock_attempt=$(( lock_attempt - 1 ))
		"${EASYTLS_MKDIR}" "${1}" || continue
		lock_acquired=1
		break
	done
	set +o noclobber
	[ $lock_acquired ] || return 1
} # => acquire_lock ()

# Release lock
release_lock ()
{
	[ -d "${1}" ] || return 0
	"${EASYTLS_RM}" -r "${1}"
} # => release_lock ()

# Break metadata_string into variables
# shellcheck disable=SC2034
metadata_string_to_vars ()
{
	MD_TLSKEY_SERIAL="${1%%-*}" || return 1

	seed="${*}" || return 1
	MD_SEED="${seed#*-}" || return 1
	unset -v seed

	#md_padding="${md_seed%%--*}" || return 1
	md_easytls_ver="${1#*--}" || return 1
	MD_EASYTLS="${md_easytls_ver%-*}" || return 1
	unset -v md_easytls_ver

	MD_IDENTITY="${2%%-*}" || return 1
	#md_srv_name="${2##*-}" || return 1
	MD_x509_SERIAL="${3}" || return 1
	MD_DATE="${4}" || return 1
	MD_CUSTOM_G="${5}" || return 1
	MD_NAME="${6}" || return 1
	MD_SUBKEY="${7}" || return 1
	MD_OPT="${8}" || return 1
	MD_FILTERS="${9}" || return 1
} # => metadata_string_to_vars ()

# Initialise
init ()
{
	# Fail by design
	absolute_fail=1

	# Defaults
	if [ -z "${EASYTLS_UNIT_TEST}" ]; then
		EASYTLS_srv_pid=$PPID
	else
		EASYTLS_srv_pid=999
	fi

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
	EASYTLS_MKDIR='mkdir'
	EASYTLS_MV='mv'
	EASYTLS_SED='sed'
	EASYTLS_PRINTF='printf'
	EASYTLS_RM='rm'

	# Directories and files
	if [ -n "${EASYTLS_FOR_WINDOWS}" ]; then
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
		[ -f "${EASYTLS_ersabin_dir}/${EASYTLS_MKDIR}.exe" ] || exit 72
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
	# Source vars file
	prog_dir="${0%/*}"
	EASYTLS_WORK_DIR="${EASYTLS_WORK_DIR:-${prog_dir}}"
	default_vars="${EASYTLS_WORK_DIR}/easytls-client-connect.vars"
	EASYTLS_VARS_FILE="${EASYTLS_VARS_FILE:-${default_vars}}"
	if [ -f "${EASYTLS_VARS_FILE}" ]; then
		# .vars-example is correct for shellcheck
		# shellcheck source=./easytls-client-connect.vars-example
		. "${EASYTLS_VARS_FILE}" || die "Source failed: ${EASYTLS_VARS_FILE}" 77
		update_status "vars loaded"
	else
		[ $EASYTLS_REQUIRE_VARS ] && die "Missing file: ${EASYTLS_VARS_FILE}" 77
	fi

	# Source metadata lib
	lib_file="${EASYTLS_WORK_DIR}/easytls-metadata.lib"
	[ -f "${lib_file}" ] || \
		lib_file="${EASYTLS_WORK_DIR}/dev/easytls-metadata.lib"
	# shellcheck source=./dev/easytls-metadata.lib
	if [ -f "${lib_file}" ]; then
		. "${lib_file}" || die "source failed: ${lib_file}" 77
	fi

	# Source tctip lib
	lib_file="${EASYTLS_WORK_DIR}/easytls-tctip.lib"
	[ -f "${lib_file}" ] || \
		lib_file="${EASYTLS_WORK_DIR}/dev/easytls-tctip.lib"
	# shellcheck source=./dev/easytls-tctip.lib
	if [ -f "${lib_file}" ]; then
		. "${lib_file}" || die "source failed: ${lib_file}" 77
	fi
	unset -v default_vars EASYTLS_VARS_FILE EASYTLS_REQUIRE_VARS prog_dir lib_file

	if [ -n "${EASYTLS_FOR_WINDOWS}" ]; then
		WIN_TEMP="${host_drv}:/Windows/Temp"
		export EASYTLS_tmp_dir="${EASYTLS_tmp_dir:-${WIN_TEMP}}"
	else
		export EASYTLS_tmp_dir="${EASYTLS_tmp_dir:-/tmp}"
	fi

	# Test temp dir
	[ -d "${EASYTLS_tmp_dir}" ] || exit 60

	# Temp files name stub
	temp_stub="${EASYTLS_tmp_dir}/easytls-${EASYTLS_srv_pid}"

	# Lock dir
	easytls_lock_stub="${temp_stub}-lock"
	LOCK_TIMEOUT="${LOCK_TIMEOUT:-30}"

	# Need the date/time ..
	full_date="$("${EASYTLS_DATE}" '+%s %Y/%m/%d-%H:%M:%S')"
	local_date_ascii="${full_date##* }"
	#local_date_sec="${full_date%% *}"

	# Windows log
	EASYTLS_WLOG="${temp_stub}-client-connect.log"
	EASYTLS_TK_XLOG="${temp_stub}-tcv2-ct.x-log"

	# Conn track
	EASYTLS_CONN_TRAC="${temp_stub}-conn-trac"

	# Kill server file
	[ -f "${temp_stub}-die" ] && echo "Kill Server Signal -> exit CC" && exit 9

	# Kill client file
	EASYTLS_KILL_FILE="${temp_stub}-kill-client"

	# Dynamic opts file
	if [ -f "${EASYTLS_DYN_OPTS_FILE}" ] && [ -n "${ovpn_dyn_opts_file}" ]; then
		"${EASYTLS_CAT}" "${EASYTLS_DYN_OPTS_FILE}" > "${ovpn_dyn_opts_file}"
		update_status "dyn opts loaded"
	fi

}

#######################################

# Initialise
init

# Options
while [ -n "${1}" ]; do
	# Separate option from value:
	opt="${1%%=*}"
	val="${1#*=}"
	empty_ok="" # Empty values are not allowed unless expected

	case "${opt}" in
	help|-h|--help)
		empty_ok=1
		help_text
	;;
	-V|--version)
			easytls_version
			exit 9
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
		ENABLE_NO_CHECK=1
	;;
	-m|--ignore-hw-mismatch) # tlskey-hwaddr does not match openvpn-hwaddr
		empty_ok=1
		IGNORE_HWADDR_MISMATCH=1
	;;
	-M|--ignore-x509-mismatch) # tlskey-x509 does not match openvpn-x509
		empty_ok=1
		IGNORE_X509_MISMATCH=1
	;;
	-p|--push-hwaddr-required)
		empty_ok=1
		ENFORCE_PUSH_HWADDR=1
	;;
	-c|--crypt-v2-required)
		empty_ok=1
		ENFORCE_CRYPT_V2=1
	;;
	-k|--key-hwaddr-required)
		empty_ok=1
		ENFORCE_KEY_HWADDR=1
	;;
	-i|--client-ip-match)
		empty_ok=1
		PEER_IP_MATCH=1
	;;
	-w|--work-dir)
		EASYTLS_WORK_DIR="${val}"
	;;
	-s|--source-vars)
		empty_ok=1
		EASYTLS_REQUIRE_VARS=1
		case "${val}" in
			-s|--source-vars)
				unset EASYTLS_VARS_FILE ;;
			*)
				EASYTLS_VARS_FILE="${val}" ;;
		esac
	;;
	-t|--tmp-dir)
		EASYTLS_tmp_dir="${val}"
	;;
	-b|--base-dir)
		EASYTLS_base_dir="${val}"
	;;
	-o|--openvpn-bin-dir)
		EASYTLS_ovpnbin_dir="${val}"
	;;
	-e|--easyrsa-bin-dir)
		EASYTLS_ersabin_dir="${val}"
	;;
	*)
		empty_ok=1
		if [ -f "${opt}" ]; then
			# Do not need this in the log but keep it here for reference
			#[ -n "${EASYTLS_VERBOSE}" ] && echo "Ignoring temp file: $opt"
			ovpn_dyn_opts_file="${opt}"
		else
			[ -n "${EASYTLS_VERBOSE}" ] && warn_die "Unknown option: ${opt}"
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

# Dependencies
deps

# Write env file
if [ -n "${WRITE_ENV}" ]; then
	env_file="${temp_stub}-client-connect.env"
	if [ -n "${EASYTLS_FOR_WINDOWS}" ]; then
		set > "${env_file}"
	else
		env > "${env_file}"
	fi
	unset -v env_file WRITE_ENV
fi

# Update log message
# shellcheck disable=SC2154 # common_name
[ -n "${common_name}" ] || die "Missing common_name" 150
update_status "CN: ${common_name}"

# Set Client certificate serial number from Openvpn env
# shellcheck disable=SC2154
client_serial="$(format_number "${tls_serial_hex_0}")"

# Verify Client certificate serial number
[ -n "${client_serial}" ] || die "Missing client_serial" 8

# conntrac connect
if [ $ENABLE_CONN_TRAC ]; then
	update_conntrac || die "update_conntrac FAIL" 170
else
	#update_status "conn-trac disabled"
	:
fi

# Check for kill signal
if [ -f "${EASYTLS_KILL_FILE}" ] && \
	"${EASYTLS_GREP}" -q "${client_serial}" "${EASYTLS_KILL_FILE}"
then
	# Kill client
	kill_this_client=1
	update_status "Kill client signal"
fi

# Cannot verify UV_TLSKEY_SERIAL yet

# Fixed file for TLS-CV2
if [ -n "${UV_TLSKEY_SERIAL}" ]; then
	client_md_file_stack="${temp_stub}-tcv2-metadata-${UV_TLSKEY_SERIAL}"
	update_status "tls key serial: ${UV_TLSKEY_SERIAL}"

	if [ -f "${client_md_file_stack}" ]; then
		# Get client metadata_string
		metadata_string="$("${EASYTLS_CAT}" "${client_md_file_stack}")"
		[ -n "${metadata_string}" ] || \
			fail_and_exit "failed to read client_md_file_stack" 18

		# Populate client metadata variables
		metadata_string_to_vars $metadata_string || \
			die "client_metadata_string_to_vars" 151
		[ -n "${MD_TLSKEY_SERIAL}" ] || \
			fail_and_exit "failed to set MD_TLSKEY_SERIAL" 19
		unset -v metadata_string
		update_status "client_md_file_stack loaded"

		# shellcheck disable=SC2154
		if [ "${MD_x509_SERIAL}" = "${client_serial}" ]; then
			update_status "metadata -> x509 serial match"

		elif [ "${MD_x509_SERIAL}" = '00000000000000000000000000000000' ]; then
			# Client could still push a fake UV_TLSKEY_SERIAL
			# is only vulnerable if many clients use the same GROUP key
			# client must still have valid X509 keys and certs
			update_status "metadata -> GROUP key"
		else
			# Client pushed UV_TLSKEY_SERIAL which does not match X509
			# Should NOT be allowed - Client has copied another key
			[ $IGNORE_X509_MISMATCH ] || {
				failure_msg="TLS-key is being used by the wrong client certificate"
				fail_and_exit "TLSKEY_X509_SERIAL-OVPN_X509_SERIAL-MISMATCH*1" 6
				}
			update_status "IGNORE metadata -> x509 serial mismatch"
		fi

	else
		# Client pushed an incorrect UV_TLSKEY_SERIAL
		# Should NOT be allowed - Client has copied another UV_TLSKEY_SERIAL only
		[ ! $ENFORCE_TLSKEY_SERIAL_MATCH ] || {
			failure_msg="PUSHED UV_TLSKEY_SERIAL ${UV_TLSKEY_SERIAL}"
			fail_and_exit "INCORRECT UV_TLSKEY_SERIAL PUSHED"
			}
		update_status "IGNORE incorrect UV_TLSKEY_SERIAL"
	fi
	# Clear one stack now - client_md_file_stack is no longer required
	stack_down || die "stack_down FAIL" 165
else
	# This is correct behaviour for --tls-auth/crypt v1
	update_status "CLIENT FAILED TO PUSH UV_TLSKEY_SERIAL"
	no_uv_tlskey_serial=1
	# Require crypt-v2
	[ $ENFORCE_CRYPT_V2 ] && {
			failure_msg="TLS Auth/Crypt key not allowed"
			fail_and_exit "TLS_CRYPT_V2 ONLY" 6
			}
	update_status "IGNORE TLS-Auth/Crypt-v1 only"
fi

# Set hwaddr from Openvpn env
# This is not a dep. different clients may not push-peer-info
push_hwaddr="$(format_number "${IV_HWADDR}")"
[ -z "${push_hwaddr}" ] && push_hwaddr_missing=1 && \
	update_status "hwaddr not pushed"

# This test being here allows to force all clients to use push-peer-info
# May need the same for IP addresses
if [ $push_hwaddr_missing ]; then
	# hwaddr is NOT pushed
	[ $ENFORCE_PUSH_HWADDR ] && {
		failure_msg="Client did not push required hwaddr"
		fail_and_exit "PUSHED HWADDR REQUIRED BUT NOT PUSHED" 3
		}
	# hwaddr not pushed and not required
	update_status "IGNORE hwaddr not required"
fi

# ENABLE_NO_CHECK
if [ $ENABLE_NO_CHECK ]; then
	# disable all checks
	update_status "Allow ALL TLS keys"
	connection_allowed
else
	# Check for TLS Auth/Crypt
	if [ $no_uv_tlskey_serial ]; then
		# TLS Auth/Crypt
		update_status "TLS Auth/Crypt key only"
		[ $ENFORCE_PUSH_HWADDR ] && [ $push_hwaddr_missing ] && {
			failure_msg="TLS Auth/Crypt no pushed hwaddr"
			fail_and_exit "PUSHED HWADDR REQUIRED BUT NOT PUSHED" 3
			}
		[ $ENFORCE_CRYPT_V2 ] && {
			failure_msg="TLS Auth/Crypt key not allowed"
			fail_and_exit "TLS_CRYPT_V2 ONLY" 6
			}
		[ $ENFORCE_KEY_HWADDR ] && {
			failure_msg="TLS Auth/Crypt key enforce verify hwaddr"
			fail_and_exit "TLS_CRYPT_V2 ONLY " 6
			}
		# TLS Auth/Crypt-v1 allowed here
		connection_allowed
	else
		# TLS-Crypt-V2

		# Set only for NO keyed hwaddr
		# shellcheck disable=SC2154
		if [ "${MD_FILTERS}" = '=000000000000=' ] || \
			[ "${MD_FILTERS}" = '+000000000000+' ]
		then
			key_hwaddr_missing=1
		fi

		# IP address check
		if [ $PEER_IP_MATCH ]; then
			# First: Check metadata for IP addresses
			# If no IP in metadata then cannot perform test, so ignore

			# Extract and sort 4/6 IP addresses from metadata
			unset found_ipv6 key_ip6_list found_ipv4 key_ip4_list source_match \
					delim4 delim6
			key_ip_list="${MD_FILTERS%=}"
			until [ -z "${key_ip_list}" ]; do
				# hw_addr = the last hwaddr in the list
				key_ip_addr="${key_ip_list##*=}"
				# Drop the last hwaddr
				key_ip_list="${key_ip_list%=*}"

				# IPv6 key list
				if [ "${key_ip_addr}" = "${key_ip_addr##*:}" ]; then
					# Not IPv6 Ignore
					:
				else
					found_ipv6=1
					key_ip6_list="${key_ip6_list}${delim6}${key_ip_addr}"
					delim6=' '
				fi

				# IPv4 key list
				if [ "${key_ip_addr}" = "${key_ip_addr##*.}" ]; then
					# Not IPv4 Ignore
					:
				else
					found_ipv4=1
					key_ip4_list="${key_ip4_list}${delim4}${key_ip_addr}"
					delim4=' '
				fi
			done
			unset delim4 delim6

			# shellcheck disable=SC2154
			if [ $found_ipv6 ] && [ -n "${trusted_ip6}" ]; then
				unset peer_ip6_match_ok
				# Test
				peer_ip6_addr="${trusted_ip6}/128"
				until [ -z "${key_ip6_list}" ]; do
					key_ip_addr="${key_ip6_list% *}"
					key_ip6_addr="${key_ip_addr%%/*}"

					# bits is no longer saved to key for IPv6
					#key_ip6_bits="${key_ip_addr##*/}"

					expand_ip6_address "${peer_ip6_addr}"
					exp_peer_ip6_addr="${full_valid_hextets}"

					case "${exp_peer_ip6_addr}" in
					"${key_ip6_addr}"* ) peer_ip_match_ok=1 ;;
					* ) unset peer_ip_match_ok ;;
					esac
					# Save Pandas
					unset key_ip_addr key_ip6_addr key_ip6_bits \
						exp_peer_ip6_addr

					# Discard lead hextet
					key_ip6_list="${key_ip6_list#* }"
					[ "${key_ip6_list}" = "${key_ip6_list#* }" ] && \
						key_ip6_list="${key_ip6_list##*}"
				done
				unset key_ip6_list peer_ip6_addr

			else
				# Ignore
				:
			fi

			# shellcheck disable=SC2154
			if [ $found_ipv4 ] && [ -n "${trusted_ip}" ]; then
				# Set IP addr from Openvpn env
				peer_ip4_addr="${trusted_ip}"
				# Test
				ip2dec "${peer_ip4_addr}"
				peer_ip4_addr_dec=${ip4_dec}
				unset ip4_dec peer_ip4_match_ok
				until [ -z "${key_ip4_list}" ]; do
					key_ip_addr="${key_ip4_list% *}"
					key_ip4_addr="${key_ip_addr%%/*}"
					ip2dec "${key_ip4_addr}"
					key_ip4_addr_dec=${ip4_dec}

					key_ip4_bits="${key_ip_addr##*/}"
					cidrmask2dec "${key_ip4_bits}"
					key_ip4_mask_dec="${mask_dec}"
					#key_ip4_imsk_dec="${imsk_dec}"
					unset mask_dec imsk_dec ip4_dec

					# Binary
					key_and4_mask_dec=$(( key_ip4_addr_dec & key_ip4_mask_dec ))
					peer_and4_mask_dec=$(( peer_ip4_addr_dec & key_ip4_mask_dec ))
					if [ ${key_and4_mask_dec} -eq ${peer_and4_mask_dec} ]
					then
						# v4 Match!
						peer_ip_match_ok=1
					fi
					# Save the rain forest
					unset key_ip_addr key_ip4_addr key_ip4_addr_dec key_ip4_bits \
						key_ip4_mask_dec key_and4_mask_dec peer_and4_mask_dec

					# Decapitate
					key_ip4_list="${key_ip4_list#* }"
					[ "${key_ip4_list}" = "${key_ip4_list#* }" ] && \
						key_ip4_list="${key_ip4_list##*}"
				done
			else
				# Ignore
				:
			fi

			if [ $found_ipv6 ] || [ $found_ipv4 ]; then
				# matadata has an address and this test is enabled so ..
				[ $peer_ip_match_ok ] || fail_and_exit "SOURCE_IP_MISMATCH!" 12
				update_status "IP Matched!"
			else
				# No IP-addr found in metadata then key not locked to IP
				update_status "No Key IPaddr IGNORED!"
				#no_key_ip_addr=1
			fi
			# Save the deep blue sea
			unset found_ipv6 found_ipv4 source_match key_ip_list key_ip_addr
		fi

		# Verify hwaddr
		# hwaddr is pushed
		if [ $key_hwaddr_missing ]; then
			# key does not have a hwaddr
			update_status "Key is not locked to hwaddr"
			[ $ENFORCE_KEY_HWADDR ] && {
				failure_msg="Key hwaddr required but missing"
				fail_and_exit "KEYED HWADDR REQUIRED BUT NOT KEYED" 4
				}
			# No keyed hwaddr and TLS-crypt-v2
			connection_allowed
		else
			#[ -f "${client_md_file_stack}" ] || \
			#		die "CC Missing client_md_file_stack"

			hw_list="${MD_FILTERS%=}"
			until [ -z "${hw_list}" ]; do
				# hw_addr = the last hwaddr in the list
				hw_addr="${hw_list##*=}"
				# Drop the last hwaddr
				hw_list="${hw_list%=*}"

				if [ "${push_hwaddr}" = "${hw_addr}" ]; then
					# push and MATCH!
					push_and_match=1
					break
				fi
			done

			if [ $push_and_match ]; then
				update_status "hwaddr ${push_hwaddr} pushed and matched"
				connection_allowed
			else
				# push does not match key hwaddr
				if [ $IGNORE_HWADDR_MISMATCH ]; then
					connection_allowed
					update_status "IGNORE hwaddr mismatch!"
				else
					failure_msg="hwaddr mismatch - pushed: ${push_hwaddr}"
					fail_and_exit "HWADDR MISMATCH" 2
				fi
			fi
		fi
	fi
fi # ENABLE_NO_CHECK

# Any failure_msg means fail_and_exit
[ -n "${failure_msg}" ] && fail_and_exit "NEIN: ${failure_msg}" 9

# For DUBUG
[ "${FORCE_ABSOLUTE_FAIL}" ] && \
	absolute_fail=1 && failure_msg="FORCE_ABSOLUTE_FAIL"

# Collect kill signal
[ $kill_this_client ] && fail_and_exit "KILL_CLIENT_SIGNAL" 5

# There is only one way out of this...
if [ "${absolute_fail}" -eq 0 ]; then
	# Delete all temp files
	delete_metadata_files || die "CON: delete_metadata_files() ?" 155

	# TLSKEY connect log
	tlskey_status " >>++> C-OK" || update_status "tlskey_status FAIL"

	# All is well
	verbose_print "${local_date_ascii} <EXOK> ${status_msg}"
	[ -n "${EASYTLS_FOR_WINDOWS}" ] && "${EASYTLS_PRINTF}" "%s\n" \
		"${status_msg}" > "${EASYTLS_WLOG}"
	exit 0
fi

# Otherwise
fail_and_exit "ABSOLUTE FAIL" 9
