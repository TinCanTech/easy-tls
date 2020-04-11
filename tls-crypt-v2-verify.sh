#!/bin/sh

# Verify client certificate serial number against certificate revokation list
# Client certificate srial number comes from client tls-crypt-v2 key metadata

# Exit on error
die ()
{
	echo "$*"
	exit 254
}

# Extract client certificate serial number from client tls-crypt-v2 key metadata
fn_client_cert_serno ()
{
	"$cat_bin" "$metadata_file" | "$awk_bin" '{print $1}'
}

# Check client certificate serial number against certificate revokation list
fn_client_cert_status ()
{
	"$ssl_bin" crl -in "$crl_pem" -noout -text | "$grep_bin" -c $client_cert_serno
}

# Must set full paths for scripts in OpenVPN
case $OS in
	win)
		# Need these .exe's from easyrsa3 installation
		EASYRSA_DIR="c:/program files/openvpn/easyrsa3"
		grep_bin="$EASYRSA_DIR/bin/grep.exe"
		cat_bin="$EASYRSA_DIR/bin/cat.exe"
		awk_bin="$EASYRSA_DIR/bin/awk.exe"
		ssl_bin="$EASYRSA_DIR/bin/openssl.exe"
		crl_pem="$EASYRSA_DIR/pki/crl.pem"
	;;
	*)
		# Standard Linux binaries
		grep_bin="/bin/grep"
		cat_bin="/bin/cat"
		awk_bin="/usr/bin/awk"
		ssl_bin="/usr/bin/openssl"
		crl_pem="./pki/crl.pem"
	;;
esac

# Ensure we have all the necessary binaries
[ -f "$grep_bin" ] || die "Missing: $grep_bin"
[ -f "$cat_bin" ] || die "Missing: $cat_bin"
[ -f "$awk_bin" ] || die "Missing: $awk_bin"
[ -f "$ssl_bin" ] || die "Missing: $ssl_bin"
[ -f "$crl_pem" ] || die "Missing: $crl_pem"
[ -f "$metadata_file" ] || die "Missing: $metadata_file"

# Collect client certificate serial number from tls-crypt-v2 matadata
client_cert_serno="$(fn_client_cert_serno)"

# Check client certificate serial number status against CRL
client_cert_revoked="$(fn_client_cert_status)"

# Return certificate serial number status to openvpn
case $client_cert_revoked in
	0)
		echo " ==> cert is valid"
		return 0
	;;
	1)
		echo " ==> cert is revoked"
		return 1
	;;
	*)
		echo " ==> error occurred"
		return 127
	;;
esac

# Never happens
return 255
