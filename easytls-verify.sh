#!/bin/sh

# Copyright - negotiable
copyright ()
{
cat << VERBATUM_COPYRIGHT_HEADER_INCLUDE_NEGOTIABLE
# easytls-cryptv2-client-connect.sh -- Do simple magic
#
# Copyright (C) 2020 Richard Bonhomme (Friday 13th of March 2020)
# https://github.com/TinCanTech/easy-tls
# tincanteksup@gmail.com
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
	help_msg='
  easytls-cryptv2-client-connect.sh

  This script is intended to be used by tls-crypt-v2 client keys
  generated by EasyTLS.  See: https://github.com/TinCanTech/easy-tls

  Options:
  help|-h|--help      This help text.
  -v|--verbose        Be a lot more verbose at run time (Not Windows).
  -c|--ca=<path>      Path to CA *REQUIRED*
  -t|--tmp-dir=<path> Temporary directory to load the client hardware list from.
  -s|--pid-file=<FILE>
                      The PID file for the openvpn server instance.

  Exit codes:
  0   - Allow connection, Client hwaddr is correct or not required.
  1   - Disallow connection, Client cert not recognised.
  2   - Disallow connection, CA PKI dir not defined. (REQUIRED)
  3   - Disallow connection, CA cert not found.
  4   - Disallow connection, index.txt not found.
  5   - Disallow connection, Server PID file has not been configured.
  6   - Disallow connection, Server PID does not match daemon_pid.
  7   - Disallow connection, missing value to option.
  8   - Disallow connection, missing X509 client cert serial. (BUG)
  9   - Disallow connection, unexpected failure. (BUG)

  253 - Disallow connection, exit code when --help is called.
  254 - BUG Disallow connection, fail_and_exit() exited with default error code.
  255 - BUG Disallow connection, die() exited with default error code.
'
	printf "%s\n" "$help_msg"

	# For secrity, --help must exit with an error
	exit 253
}

# Wrapper around printf - clobber print since it's not POSIX anyway
# shellcheck disable=SC1117
print() { printf "%s\n" "$1"; }

# Exit on error
die ()
{
	rm -f "$client_hwaddr_file"
	[ -n "$help_note" ] && printf "\n%s\n" "$help_note"
	printf "\n%s\n" "ERROR: $1"
	printf "%s\n" "https://github.com/TinCanTech/easy-tls"
	exit "${2:-255}"
}

# easytls-cryptv2-client-connect failure, not an error.
fail_and_exit ()
{
	rm -f "$client_hwaddr_file"
	if [ $EASYTLS_VERBOSE ]
	then
		printf "%s " "$easytls_msg"
		[ -z "$success_msg" ] || printf "%s\n" "$success_msg"
		printf "%s\n%s\n" "$failure_msg $common_name" "$1"

		printf "%s\n" "https://github.com/TinCanTech/easy-tls"
	else
		printf "%s %s %s %s\n" "$easytls_msg" "$success_msg" "$failure_msg" "$1"
	fi
	exit "${2:-254}"
} # => fail_and_exit ()

# Get the client certificate serial number from env
get_ovpn_client_serial ()
{
	printf '%s' "$tls_serial_hex_0" | sed -e 's/://g' -e 'y/abcdef/ABCDEF/'
}

# Allow connection
connection_allowed ()
{
	absolute_fail=0
}

# Initialise
init ()
{
	# Fail by design
	absolute_fail=1

	# Defaults
	EASYTLS_tmp_dir="/tmp"

	# Log message
	easytls_msg="* EasyTLS-verify"
}

# Dependancies
deps ()
{
	# CA_dir MUST be set with option: -c|--ca
	[ -d "$CA_dir" ] || die "Path to CA directory is required, see help" 2

	# CA required files
	ca_cert="$CA_dir/ca.crt"
	index_txt="$CA_dir/index.txt"

	# Ensure we have all the necessary files
	help_note="This script requires an EasyRSA generated CA."
	[ -f "$ca_cert" ] || die "Missing CA certificate: $ca_cert" 3
	help_note="This script requires an EasyRSA generated DB."
	[ -f "$index_txt" ] || die "Missing index.txt: $index_txt" 4


	# Set default Server PID file if not set by command line
	[ $EASYTLS_server_pid_file ] || \
		EASYTLS_server_pid_file="${EASYTLS_tmp_dir}/easytls-server.pid"

	# Verify Server PID file - daemon_pid is from Openvpn env
	if [ -f "$EASYTLS_server_pid_file" ]
	then
		EASYTLS_server_pid="$(cat $EASYTLS_server_pid_file)"
		# PID file MUST match daemon PID
		[ "$EASYTLS_server_pid" = "$daemon_pid" ] || \
			fail_and_exit "SERVER PID MISMATCH" 6
	else
		# The Server is not configured for easytls-cryptv2-client-connect.sh
		fail_and_exit "SERVER PID FILE NOT CONFIGURED" 5
	fi
}

#######################################

# Initialise
init

# Options
while [ -n "$1" ]
do
	# Separate option from value:
	opt="${1%%=*}"
	val="${1#*=}"
	empty_ok="" # Empty values are not allowed unless expected

	case "$opt" in
	help|-h|-help|--help)
		empty_ok=1
		help_text
	;;
	-v|--verbose)
		empty_ok=1
		EASYTLS_VERBOSE=1
	;;
	-c|--ca)
		CA_dir="$val"
	;;
	-t|--tmp-dir)
		EASYTLS_tmp_dir="$val"
	;;
	-s|--pid-file)
		EASYTLS_server_pid_file="$val"
	;;
	0)
		empty_ok=1
		cert_depth="0"
	;;
	1)
		# DISABLE CA verify
		[ $EASYTLS_VERBOSE ] && \
			printf '%s\n' '>< >< >< DISABLE CA CERTIFICATE VERIFY >< >< ><'
		exit 0
	;;
	*)
		empty_ok=1
		if [ -f "$opt" ]
		then
			[ $EASYTLS_VERBOSE ] && print "Ignoring temp file: $opt"
		else
			[ $EASYTLS_VERBOSE ] && print "Ignoring unknown option: $opt"
		fi
	;;
	esac

	# fatal error when no value was provided
	if [ ! $empty_ok ] && { [ "$val" = "$1" ] || [ -z "$val" ]; }; then
		die "Missing value to option: $opt" 7
	fi
	shift
done

# Dependencies
deps


# TLS verify checks

	# Set Client certificate serial number from Openvpn env
	client_serial="$(get_ovpn_client_serial)"

	# Verify Client certificate serial number
	[ -n "$client_serial" ] || die "MISSING CLIENT CERTIFICATE SERIAL" 8

	# There will never be a hardware file because
	# --tls-crypt-v2-verify is not triggered for this client
	# --tls-crypt-v2, --tls-auth and --tls-crypt
	# are mutually exclusive in client mode
	# Set hwaddr file name
	client_hwaddr_file="${EASYTLS_tmp_dir}/${client_serial}.${daemon_pid}"

	# Check cert serial is known by index.txt
	if grep -q "$client_serial" "$index_txt"
	then
		success_msg=" ==> Valid Client cert serial"
		connection_allowed
		# Create a simple hwaddr file for client-connect
		# This implies that the client is not bound to a hwaddr
		printf '%s' '000000000000' > "$client_hwaddr_file"
	else
		# Cert serial not found in PKI index.txt
		fail_and_exit "ALIEN CLIENT CERTIFICATE SERIAL" 1
	fi

# Any failure_msg means fail_and_exit
[ -n "$failure_msg" ] && fail_and_exit "NEIN: $failure_msg" 9

# For DUBUG
[ "$FORCE_ABSOLUTE_FAIL" ] && \
	absolute_fail=1 && failure_msg="FORCE_ABSOLUTE_FAIL"

# There is only one way out of this...
[ $absolute_fail -eq 0 ] || fail_and_exit "ABSOLUTE FAIL" 9

# All is well
[ $EASYTLS_VERBOSE ] && \
	printf "%s\n" "<EXOK> $easytls_msg $success_msg"

exit 0
