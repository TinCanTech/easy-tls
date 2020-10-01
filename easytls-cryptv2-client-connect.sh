#!/bin/sh

# Get client certificate serial number from env
get_client_serial_number ()
{
	printf '%s' "$tls_serial_hex_0" | sed 's/://g'
}

# Get client hardware address from env
get_client_hw_addr ()
{
	printf '%s' "$IV_HWADDR" | sed 's/://g'
}

# Initialise
init ()
{
	# Fail by design
	absolute_fail=1

	# metadata version
	local_version="easytls"

	# From openvpn server
	openvpn_metadata_file="$metadata_file"
	client_serial="$(get_client_serial_number)"
	client_hwaddr="$(get_client_hw_addr)"

	# Log message
	easytls_cryptv2_cc_msg="* EasyTLS-cryptv2-client-connect ==>"
}

# Dependancies
deps ()
{
	# CA_DIR MUST be set with option: -c|--ca
	[ -d "$CA_DIR" ] || die "Path to CA directory is required, see help" 22

	# Required files
	ca_cert="$CA_DIR/ca.crt"
	allowed_hwaddr_file="$CA_DIR/easytls/$client_serial.hwl"

	#ca_identity_file="$CA_DIR/easytls/easytls-ca-identity.txt"
	#crl_pem="$CA_DIR/crl.pem"
	#index_txt="$CA_DIR/index.txt"
	#openssl_cnf="$CA_DIR/safessl-easyrsa.cnf"
	#disabled_list="$CA_DIR/easytls/easytls-disabled-list.txt"

	# Ensure we have all the necessary files
	help_note="This script requires an EasyRSA generated CA."
	[ -f "$ca_cert" ] || die "Missing CA certificate: $ca_cert" 23

	# `metadata_file` must be set by openvpn
	help_note="This script can ONLY be used by a running openvpn server."
	[ -f "$allowed_hwaddr_file" ] || \
		die "Missing: allowed_hwaddr_file: $allowed_hwaddr_file" 28
	unset help_note

	# Get metadata_string
	# Load binary: cat +1
	metadata_string="$(metadata_file_to_metadata_string)"

	# Populate metadata variables
	metadata_string_to_vars $metadata_string

	# Ensure that TLS expiry age is numeric
	# https://stackoverflow.com/a/3951175
	case $TLS_CRYPT_V2_VERIFY_TLS_AGE in
	''|*[!0-9]*)
	# Exit script with error code 29 and disallow the connection
	die "Invalid value for --tls-age: $TLS_CRYPT_V2_VERIFY_TLS_AGE" 29
	;;
	*)
	# maximum age in seconds
	tls_key_expire_age_seconds=$((TLS_CRYPT_V2_VERIFY_TLS_AGE*60*60*24))
	;;
	esac

	# Check for either --cache-id or --preload-cache-id
	# Do NOT allow both
	[ $use_cache_id ] && [ $preload_cache_id ] && \
		die "Cannot use --cache-id and --preload-cache-id together." 34
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
		TLS_CRYPT_V2_VERIFY_VERBOSE=1
	;;
	-c|--ca)
		CA_DIR="$val"
	;;
	-t|--tls-age)
		TLS_CRYPT_V2_VERIFY_TLS_AGE="$val"
	;;
	--verify-via-ca)
		empty_ok=1
		tls_crypt_v2_verify_msg="* TLS-crypt-v2-verify (ca) ==>"
		test_method=2
	;;
	--verify-via-index)
		empty_ok=1
		tls_crypt_v2_verify_msg="* TLS-crypt-v2-verify (index) ==>"
		test_method=3
	;;
	-g|--custom-group)
		TLS_CRYPT_V2_VERIFY_CG="$val"
	;;
	--cache-id)
		empty_ok=1
		use_cache_id=1
	;;
	--preload-cache-id)
		preload_cache_id="$val"
	;;
	--hex-check)
		empty_ok=1
		enable_serial_Hex_check=1
	;;
	--disable-list)
		empty_ok=1
		unset use_disable_list
	;;
	*)
		die "Unknown option: $1" 253
	;;
	esac

	# fatal error when no value was provided
	if [ ! $empty_ok ] && { [ "$val" = "$1" ] || [ -z "$val" ]; }; then
		die "Missing value to option: $opt" 21
	fi

	shift
done


# Dependancies
# Load binary: cat +1 (cat metadata_file)
deps


