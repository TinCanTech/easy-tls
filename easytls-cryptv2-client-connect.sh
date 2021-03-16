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
  -t|--tmp-dir=<path> Temporary directory to load the client hardware list from.
  -r|--required       Require client to use --push-peer-info

  Exit codes:
  0   - Allow connection, Client hwaddr is correct or not required.
  1   - Disallow connection, pushed hwaddr does not match.
  2   - Disallow connection, pushed hwaddr missing (not pushed).
  3   - Disallow connection, X509 certificate incorrect for this TLS-key.
  4   - Disallow connection, hwaddr verification has not been configured.
  5   - Disallow connection, Server PID does not match daemon_pid.
  6   - Disallow connection, missing X509 client cert serial. (BUG)
  7   - Disallow connection, missing value to option.
  8   - Disallow connection, unexpected failure. (BUG)
  9   - Disallow connection, Absolute Fail. (BUG)

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
	if [ $CLICON_VERBOSE ]
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

# Get the client hardware address from env
get_ovpn_client_hwaddr ()
{
	printf '%s' "$IV_HWADDR" | sed -e 's/://g' -e 'y/abcdef/ABCDEF/'
}

# Allow connection
connection_allowed ()
{
	rm -f "$client_hwaddr_file"
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
	easytls_msg="* EasyTLS-cryptv2-client-connect"
}

# Dependancies
deps ()
{
	# Set default Server PID file if not set by command line
	[ $EASYTLS_server_pid_file ] || \
		EASYTLS_server_pid_file="${EASYTLS_tmp_dir}/easytls-server.pid"

	# Verify Server PID file - daemon_pid is from Openvpn env
	if [ -f "$EASYTLS_server_pid_file" ]
	then
		EASYTLS_server_pid="$(cat $EASYTLS_server_pid_file)"
		# PID file MUST match daemon PID
		[ "$EASYTLS_server_pid" = "$daemon_pid" ] || \
			fail_and_exit "SERVER PID MISMATCH" 5
	else
		# The Server is not configured for easytls-cryptv2-client-connect.sh
		fail_and_exit "SERVER PID FILE NOT CONFIGURED" 4
	fi

	# Set Client certificate serial number from Openvpn env
	client_serial="$(get_ovpn_client_serial)"

	# Verify Client certificate serial number
	[ -n "$client_serial" ] || die "NO CLIENT SERIAL" 6

	# Set hwaddr file name
	client_hwaddr_file="$EASYTLS_tmp_dir/$client_serial.$daemon_pid"

	# Verify the hwaddr file
	if [ -f "$client_hwaddr_file" ]
	then
		# Client cert serial matches
		easytls_msg="${easytls_msg} ==> X509 serial matched"
	else
		# cert serial does not match
		fail_and_exit "CLIENT X509 SERIAL MISMATCH" 3
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
		CLICON_VERBOSE=1
	;;
	-t|--tmp-dir)
		EASYTLS_tmp_dir="$val"
	;;
	-s|--pid-file)
		EASYTLS_server_pid_file="$val"
	;;
	-r|--required)
		empty_ok=1
		EASYTLS_hwaddr_required=1
	;;
	*)
		empty_ok=1
		if [ -f "$1" ]
		then
			print "Ignoring temp file: $1"
		else
			print "Ignoring unknown option: $1"
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

# Set hwaddr from Openvpn env
# This is not a dep. different clients may not push-peer-info
push_hwaddr="$(get_ovpn_client_hwaddr)"

# Verify hwaddr
if grep -q '000000000000' "$client_hwaddr_file"
then
	# hwaddr NOT keyed
	success_msg="==> Key is not locked to hwaddr"
	connection_allowed
else
	# Otherwise, this key has a hwaddr
	if [ -z "$push_hwaddr" ]
	then
		# hwaddr NOT pushed
		[ $EASYTLS_hwaddr_required ] && \
			fail_and_exit "HWADDR REQUIRED BUT NOT PUSHED" 2

		# hwaddr NOT required
		success_msg="==> hwaddr not pushed and not required"
		connection_allowed
	else
		# hwaddr pushed
		if grep -q "$push_hwaddr" "$client_hwaddr_file"
		then
			# MATCH!
			success_msg="==> hwaddr pushed and matched!"
			connection_allowed
		else
			# push does not match key hwaddr
			fail_and_exit "HWADDR MISMATCH" 1
		fi
	fi
fi

# Any failure_msg means fail_and_exit
[ -n "$failure_msg" ] && fail_and_exit "NEIN: $failure_msg" 8

# For DUBUG
[ "$FORCE_ABSOLUTE_FAIL" ] && absolute_fail=1 && \
	failure_msg="FORCE_ABSOLUTE_FAIL"

# There is only one way out of this...
[ $absolute_fail -eq 0 ] || fail_and_exit "ABSOLUTE FAIL" 9

# All is well
[ $CLICON_VERBOSE ] && \
	printf "%s\n" "<EXOK> $easytls_msg $success_msg"

exit 0
