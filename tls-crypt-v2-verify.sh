#!/bin/sh

# Verify CA fingerprint
# Verify client certificate serial number against certificate revokation list

# This is here to catch "print" statements
# Wrapper around printf - clobber print since it's not POSIX anyway
# shellcheck disable=SC1117
print() { printf "%s\n" "$1"; }

# Exit on error
die ()
{
	printf "\n%s\n" "ERROR: $1"
	printf "%s\n" "https://github.com/TinCanTech/easy-tls"
	exit "${2:-254}"
}

# Tls-crypt-v2-verify failure, not an error.
fail_and_exit ()
{
	## shellcheck disable=SC2086
	if [ $TLS_CRYPT_V2_VERIFY_VERBOSE ]
	then
		printf "%s%s%s\n%s\n" "$tls_crypt_v2_verify_msg" "$success_msg" "$failure_msg" "$1"
		printf "%s\n" "* ==> CA Fingerprint  local: $local_ca_fingerprint"
		printf "%s\n" "* ==> CA Fingerprint remote: $metadata_ca_fingerprint"
		printf "%s\n" "* ==> Client serial  remote: $metadata_client_cert_serno"
		[ $2 -eq 1 ] && printf "%s\n" "* ==> Client serial status: revoked"
	else
		printf "%s%s%s\n" "$tls_crypt_v2_verify_msg" "$success_msg" "$failure_msg"
	fi
	exit "${2:-1}"
}

# Verify CA
verify_ca ()
{
	"$ssl_bin" x509 -in "$ca_cert" -noout || die "Bad CA $ca_cert" 11
}

# CA File fingerprint
fn_local_ca_fingerprint ()
{
	"$ssl_bin" x509 -in "$ca_cert" -noout -fingerprint
}

# Extract CA fingerprint from client tls-crypt-v2 key metadata
fn_metadata_ca_fingerprint ()
{
	"$awk_bin" '{print $1}' "$openvpn_metadata_file"
}

# Extract client certificate serial number from client tls-crypt-v2 key metadata
fn_metadata_client_cert_serno ()
{
	"$awk_bin" '{print $2}' "$openvpn_metadata_file"
}

# Verify CRL
verify_crl ()
{
	"$ssl_bin" crl -in "$crl_pem" -noout || die "Bad CRL: $crl_pem" 12
}

# Decode CRL
fn_read_crl ()
{
	"$ssl_bin" crl -in "$crl_pem" -noout -text
}

# Search CRL for client cert serial number
search_crl ()
{
	printf "%s\n" "$crl_text" | "$grep_bin" -c "$metadata_client_cert_serno"
}

# Final check index.txt
search_index ()
{
	"$grep_bin" -c "$metadata_client_cert_serno" "$index_txt"
}

# Check metadata client certificate serial number against CRL
serial_status_via_crl ()
{
client_cert_revoked="$(search_crl)"
case $client_cert_revoked in
	0)
		[ "$(search_index)" -eq 1 ] || fail_and_exit "Client certificate is not in the CA index database" 11
		success_msg="$success_msg Client certificate is valid and not revoked: $metadata_client_cert_serno"
	;;
	1)
		failure_msg="$failure_msg Client certificate is revoked: $metadata_client_cert_serno"
		fail_and_exit "REVOKED" 1
	;;
	*)
		failure_msg="$failure_msg ==> unknown error occurred: $metadata_client_cert_serno"
		die "Certificate number is invalid: $metadata_client_cert_serno" 127
	;;
esac
}

# Check metadata client certificate serial number against CA
serial_status_via_ca ()
{
	# This does not return openssl output to variable
	# If you have a fix please make an issue and/or PR
	client_cert_serno_status="$(openssl_serial_status)"
	printf "%s\n" "client_cert_serno_status: $client_cert_serno_status"
	client_cert_serno_status="${client_cert_serno_status##*=}"
	case "$client_cert_serno_status" in
		Valid)		die "IMPOSSIBLE" 101 ;; # Valid ?
		Revoked)	die "REVOKED" 1 ;;
		*)		die "Serial status via CA [test_method 2] is broken" 9 ;;
	esac
}

# Use openssl to return certificate serial number status
openssl_serial_status ()
{
	"$EASYTLS_OPENSSL" ca -cert "$ca_cert" -config "$openssl_cnf" -status "$metadata_client_cert_serno"
}

# Verify openssl serial status returns ok
verify_openssl_serial_status ()
{
	return 0
	"$EASYTLS_OPENSSL" ca -cert "$ca_cert" -config "$openssl_cnf" -status "$metadata_client_cert_serno" || \
		die "openssl failed to return a useful exit code"
	# Cannot defend an error here because openssl always returns 1
	# || die "openssl failed to get serial status"

# I presume they don't want people to use it so they broke it
: << MAN_OPENSSL_CA
WARNINGS
       The ca command is quirky and at times downright unfriendly.

       The ca utility was originally meant as an example of how to do things in a CA. It was not supposed to be used as a full blown CA itself:
       nevertheless some people are using it for this purpose.

       The ca command is effectively a single user command: no locking is done on the various files and attempts to run more than one ca command
       on the same database can have unpredictable results.
MAN_OPENSSL_CA
}

# Must set full paths for scripts in OpenVPN
case $OS in
	Windows_NT)
		# Need these .exe's from easyrsa3 installation
		EASYRSA_DIR="c:/program files/openvpn/easyrsa3"
		grep_bin="$EASYRSA_DIR/bin/grep.exe"
		sed_bin="$EASYRSA_DIR/bin/sed.exe"
		cat_bin="$EASYRSA_DIR/bin/cat.exe"
		awk_bin="$EASYRSA_DIR/bin/awk.exe"
		printf_bin="$EASYRSA_DIR/bin/printf.exe"
		ssl_bin="$EASYRSA_DIR/bin/openssl.exe"
		ca_cert="$EASYRSA_DIR/pki/ca.crt"
		crl_pem="$EASYRSA_DIR/pki/crl.pem"
		index_txt="$EASYRSA_DIR/pki/index.txt"
		openssl_cnf="../pki/safessl-easyrsa.cnf"
		EASYTLS_OPENSSL="openssl"
	;;
	*)
		# Standard Linux binaries
		grep_bin="/bin/grep"
		sed_bin="/bin/sed"
		cat_bin="/bin/cat"
		awk_bin="/usr/bin/awk"
		printf_bin="/usr/bin/printf"
		ssl_bin="/usr/bin/openssl"
		ca_cert="../pki/ca.crt"
		crl_pem="../pki/crl.pem"
		index_txt="../pki/index.txt"
		openssl_cnf="../pki/safessl-easyrsa.cnf"
		EASYTLS_OPENSSL="openssl"
	;;
esac

# From openvpn server
openvpn_metadata_file="$metadata_file"

# Ensure we have all the necessary files
[ -f "$grep_bin" ] || die "Missing: $grep_bin" 10
[ -f "$sed_bin" ] || die "Missing: $sed_bin" 10
[ -f "$cat_bin" ] || die "Missing: $cat_bin" 10
[ -f "$awk_bin" ] || die "Missing: $awk_bin" 10
[ -f "$printf_bin" ] || die "Missing: $printf_bin" 10
[ -f "$ssl_bin" ] || die "Missing: $ssl_bin" 10
[ -f "$ca_cert" ] || die "Missing: $ca_cert" 10
[ -f "$crl_pem" ] || die "Missing: $crl_pem" 10
[ -f "$index_txt" ] || die "Missing: $index_txt" 10
#[ -f "$openssl_cnf" ] || die "Missing: $openssl_cnf" 10
[ -f "$openvpn_metadata_file" ] || die "Missing: $openvpn_metadata_file" 10

# Log message
tls_crypt_v2_verify_msg="* TLS-crypt-v2-verify ==>"
success_msg=""
failure_msg=""

# Default test_method
test_method=1

# Options
while [ -n "$1" ]
do
	case "$1" in
		# Silent running, except on ALL errors and failure to verify
		-1|-m1|--method-1)	test_method=1 ;;
		-2|-m2|--method-2)	test_method=2 ;;
		-v|--verbose)		TLS_CRYPT_V2_VERIFY_VERBOSE=1 ;;
		*)			die "Unknown option: $1" 253 ;;
	esac
	shift
done


# CA Fingerprint

	# Verify CA
	verify_ca

	# Capture CA fingerprint
	# Format to one contiguous string (Same as encoded metadata)
	local_ca_fingerprint="$(fn_local_ca_fingerprint|"$sed_bin" "s/\ /\_/g")"

	# local_ca_fingerprint is required
	[ -z "$local_ca_fingerprint" ] && fail_and_exit "Missing: local CA fingerprint" 3

	# Collect CA fingerprint from tls-crypt-v2 metadata
	metadata_ca_fingerprint="$(fn_metadata_ca_fingerprint)"

	# metadata_ca_fingerprint is required
	[ -z "$metadata_ca_fingerprint" ] && fail_and_exit "Missing: remote CA fingerprint" 3

# Check metadata CA fingerprint against local CA fingerprint
if [ "$local_ca_fingerprint" = "$metadata_ca_fingerprint" ]
then
	success_msg="$success_msg CA Fingerprint OK ==>"
else
	failure_msg="$failure_msg CA Fingerprint mismatch"
	fail_and_exit "FP_MISMATCH" 3
fi


# Client certificate serial number

	# Verify CRL
	verify_crl

	# Capture CRL
	crl_text="$(fn_read_crl)"

	# Collect client certificate serial number from tls-crypt-v2 metadata
	# Drop the 'serial=' part
	metadata_client_cert_serno="$(fn_metadata_client_cert_serno|"$sed_bin" "s/^.*=//g")"

	# Client serial number requirements
	[ -z "$metadata_client_cert_serno" ] && fail_and_exit "Missing: client certificate serial number" 2
	# May not be suitable for non-random serial numbers
	serial_length=${#metadata_client_cert_serno}
	[ $serial_length -eq 32 ] || fail_and_exit "Invalid serial number length" 2
	# Hex only accepted
	serial_chars="$(printf '%s' "$metadata_client_cert_serno" | grep -c '[^0123456789ABCDEF]')"
	[ $serial_chars -eq 0 ] || fail_and_exit "Invalid serial number" 2

# Verify serial status by method 1 or 2
case $test_method in
	1)
		# Method 1
		# Check metadata client certificate serial number against CRL
		serial_status_via_crl
	;;
	2)
		# Method 2
		# Check metadata client certificate serial number against CA

		# Due to openssl being "what it is", it is not possible to reliably
		# verify the 'openssl ca $cmd'
		#verify_openssl_serial_status
		serial_status_via_ca
	;;
	*)
		die "Unknown method for verify: $test_method" 9
	;;
esac

[ -z "$failure_msg" ] || fail_and_exit "$failure_msg" 9
[ $TLS_CRYPT_V2_VERIFY_VERBOSE ] && printf "%s%s\n" "$tls_crypt_v2_verify_msg" "$success_msg"

exit 0
