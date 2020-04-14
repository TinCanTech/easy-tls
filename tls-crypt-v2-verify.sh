#!/bin/sh

# Verify CA fingerprint
# Verify client certificate serial number against certificate revokation list

# Exit on error
die ()
{
	printf "\n%s\n\n" "ERROR: $*"
	printf "%s\n" "https://github.com/TinCanTech/easy-tls"
	# Code 253= your problem
	exit "${2:-254}"
}

# Tls-crypt-v2-verify failure, not an error.
Fail_and_exit ()
{
	## shellcheck disable=SC2086
	if [ $TLS_CRYPT_V2_VERIFY_VERBOSE ]
	then
		printf "%s%s%s\n%s\n" "$tls_crypt_v2_verify_msg" "$success_msg" "$failure_msg" "$1"
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
fn_file_ca_fingerprint ()
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

# Must set full paths for scripts in OpenVPN
case $OS in
	win)
		# Need these .exe's from easyrsa3 installation
		EASYRSA_DIR="c:/program files/openvpn/easyrsa3"
		grep_bin="$EASYRSA_DIR/bin/grep.exe"
		sed_bin="$EASYRSA_DIR/bin/sed.exe"
		cat_bin="$EASYRSA_DIR/bin/cat.exe"
		awk_bin="$EASYRSA_DIR/bin/awk.exe"
		ssl_bin="$EASYRSA_DIR/bin/openssl.exe"
		ca_cert="$EASYRSA_DIR/pki/ca.crt"
		crl_pem="$EASYRSA_DIR/pki/crl.pem"
	;;
	*)
		# Standard Linux binaries
		grep_bin="/bin/grep"
		sed_bin="/bin/sed"
		cat_bin="/bin/cat"
		awk_bin="/usr/bin/awk"
		ssl_bin="/usr/bin/openssl"
		ca_cert="../pki/ca.crt"
		crl_pem="../pki/crl.pem"
	;;
esac

# From openvpn server
openvpn_metadata_file="$metadata_file"

# Ensure we have all the necessary files
[ -f "$grep_bin" ] || die "Missing: $grep_bin" 10
[ -f "$cat_bin" ] || die "Missing: $cat_bin" 10
[ -f "$awk_bin" ] || die "Missing: $awk_bin" 10
[ -f "$ssl_bin" ] || die "Missing: $ssl_bin" 10
[ -f "$ca_cert" ] || die "Missing: $ca_cert" 10
[ -f "$crl_pem" ] || die "Missing: $crl_pem" 10
[ -f "$openvpn_metadata_file" ] || die "Missing: $openvpn_metadata_file" 10

# Log message
tls_crypt_v2_verify_msg="* TLS-crypt-v2-verify ==>"
success_msg=""
failure_msg=""

# Options
case "$1" in
	# Silent running, except on ALL errors and failure to verify
	-v|--verbose)	TLS_CRYPT_V2_VERIFY_VERBOSE=1 ;;
	"")		: ;;
	*)		die "Unknown option: $1" 253 ;;
esac
# shift

# CA Fingerprint

	# Verify CA
	verify_ca

	# Capture CA fingerprint
	# Format to one contiguous string (Same as encoded metadata)
	local_ca_fingerprint="$(fn_file_ca_fingerprint|"$sed_bin" "s/\ /\_/g")"

	# file_ca_fingerprint is required
	[ -z "$local_ca_fingerprint" ] && die "Missing: local CA fingerprint" 2

	# Collect CA fingerprint from tls-crypt-v2 matadata
	metadata_ca_fingerprint="$(fn_metadata_ca_fingerprint)"

	# file_ca_fingerprint is required
	[ -z "$metadata_ca_fingerprint" ] && die "Missing: remote CA fingerprint" 2

# Check metadata CA fingerprint against local CA fingerprint
if [ "$local_ca_fingerprint" = "$metadata_ca_fingerprint" ]
then
	success_msg="$success_msg CA Fingerprint OK ==>"
else
	failure_msg="$failure_msg CA Fingerprint mismatch"
	printf "%s\n" "* ==> CA Fingerprint  local: $local_ca_fingerprint"
	printf "%s\n" "* ==> CA Fingerprint remote: $metadata_ca_fingerprint"
	Fail_and_exit "FP_MISMATCH" 2
fi

# Client certificate serial number

	# Verify CRL
	verify_crl

	# Capture CRL
	crl_text="$(fn_read_crl)"

	# Collect client certificate serial number from tls-crypt-v2 metadata
	# Drop the 'serial=' part
	metadata_client_cert_serno="$(fn_metadata_client_cert_serno|"$sed_bin" "s/^.*=//g")"

	# Client serial number is required
	[ -z "$metadata_client_cert_serno" ] && die "Missing: client certificate serial number" 1

# Check metadata client certificate serial number against CRL
client_cert_revoked="$(printf "%s\n" "$crl_text" | "$grep_bin" -c $metadata_client_cert_serno)"

case $client_cert_revoked in
	0)
		success_msg="$success_msg Client certificate is valid: $metadata_client_cert_serno"
	;;
	1)
		failure_msg="$failure_msg Client certificate is revoked: $metadata_client_cert_serno"
		Fail_and_exit "REVOKED" 1
	;;
	*)
		failure_msg="$failure_msg ==> unknown error occurred: $metadata_client_cert_serno"
		Fail_and_exit "UNKNOWN" 127
	;;
esac

[ -z "$failure_msg" ] || fail_and_exit "$failure_msg" 9
[ $TLS_CRYPT_V2_VERIFY_VERBOSE ] && printf "%s%s\n" "$tls_crypt_v2_verify_msg" "$success_msg"

exit 0
