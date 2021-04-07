#!/bin/sh

# Copyright - negotiable
copyright ()
{
cat << VERBATUM_COPYRIGHT_HEADER_INCLUDE_NEGOTIABLE
# tls-crypt-v2-verify.sh -- Do simple magic
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
# Verify:
#   metadata version
#   metadata custom group
#   TLS key age
#   Identity (CA Fingerprint)
#   disabled list
#   Client certificate serial number
#     * via certificate revokation list (Default)
#     * via `openssl ca` (Not recommended)
#     * via openssl index.txt (Preferred)
#
VERBATUM_COPYRIGHT_HEADER_INCLUDE_NEGOTIABLE
}

# This is here to catch "print" statements
# Wrapper around printf - clobber print since it's not POSIX anyway
# shellcheck disable=SC1117
print() { "$easytls_printf" "%s\n" "$1"; }

# Exit on error
die ()
{
	[ -n "$help_note" ] && "$easytls_printf" "\n%s\n" "$help_note"
	"$easytls_printf" "\n%s\n" "ERROR: $1"
	"$easytls_printf" "%s\n" "https://github.com/TinCanTech/easy-tls"
	exit "${2:-255}"
}

# Tls-crypt-v2-verify failure, not an error.
fail_and_exit ()
{
	if [ $EASYTLS_VERBOSE ]
	then
		"$easytls_printf" "%s " "$status_msg"
		[ -z "$success_msg" ] || "$easytls_printf" "%s " "$success_msg"
		"$easytls_printf" "%s\n%s\n" "$failure_msg $md_name" "$1"

		"$easytls_printf" "%s\n" \
			"* ==> version       local: $local_easytls"

		"$easytls_printf" "%s\n" \
			"* ==> version      remote: $md_easytls"

		"$easytls_printf" "%s\n" \
			"* ==> custom_group  local: $local_custom_g"

		"$easytls_printf" "%s\n" \
			"* ==> custom_group remote: $md_custom_g"

		"$easytls_printf" "%s\n" \
			"* ==> identity      local: $local_identity"

		"$easytls_printf" "%s\n" \
			"* ==> identity     remote: $md_identity"

		"$easytls_printf" "%s\n" \
			"* ==> X509 serial  remote: $md_serial"

		"$easytls_printf" "%s\n" \
			"* ==> name         remote: $md_name"

		"$easytls_printf" "%s\n" \
			"* ==> TLSK serial  remote: $tlskey_serial"

		"$easytls_printf" "%s\n" \
			"* ==> sub-key      remote: $md_subkey"

		"$easytls_printf" "%s\n" \
			"* ==> date         remote: $md_date"

		[ $2 -eq 1 ] && "$easytls_printf" "%s\n" \
			"* ==> Client serial status: revoked"

		[ $2 -eq 2 ] && "$easytls_printf" "%s\n" \
			"* ==> Client serial status: disabled"

		[ -n "$help_note" ] && "$easytls_printf" "%s\n" "$help_note"

		"$easytls_printf" "%s\n" "https://github.com/TinCanTech/easy-tls"
	else
		"$easytls_printf" "%s %s %s %s\n" "$status_msg" \
			"$success_msg" "$failure_msg" "$md_name"
	fi
	exit "${2:-254}"
} # => fail_and_exit ()

# Help
help_text ()
{
	help_msg='
  easytls-cryptv2-verify.sh

  This script is intended to be used by tls-crypt-v2 client keys
  generated by Easy-TLS.  See: https://github.com/TinCanTech/easy-tls

  Options:
  help|-h|--help      This help text.
  -v|--verbose        Be a lot more verbose at run time (Not Windows).
  -c|--ca=<path>      Path to CA *REQUIRED*
  -g|--custom-group=<GROUP>
                      Verify the client metadata against a custom group.
  -n|--no-hash        Do not verify metadata hash (TLS-key serial number).
  -x|--max-tls-age    TLS Crypt V2 Key allowable age in days (default: 1825).
                      To disable age check use --tls-age=0
  -d|--disable-list   Disable the temporary disabled-list check.
  -s|--pid-file=<FILE>
                      The PID file for the openvpn server instance.
                      (Required only if easytls-cryptv2-client-connect.sh is used)
  -t|--tmp-dir        Temp directory where the hardware address list is written.
                      (Required only if easytls-cryptv2-client-connect.sh is used)
  --v1|--via-crl      Do X509 certificate checks via x509_method 1, CRL check.
  --v2|--via-ca       Do X509 certificate checks via x509_method 2,
                      Use `openssl ca` commands.  NOT RECOMMENDED
  --v3|--via-index    Do X509 certificate checks via x509_method 3,
                      Search openssl index.txt  PREFERRED
                      This method does not require loading the openssl binary.
  -a|--cache-id       Use the saved CA-Identity from EasyTLS.
  -p|--preload-id=<CA-ID>
                      Preload the CA-Identity when calling the script.
                      See EasyTLS command save-id for details of the CA-Identity.
                      See EasyTLS-Howto.txt for an example.

  Exit codes:
  0   - Allow connection, Client key has passed all tests.
  1   - Disallow connection, client key has passed all tests but is REVOKED.
  2   - Disallow connection, TLS key serial number is disabled.
  3   - Disallow connection, TLS key has expired.
  4   - Disallow connection, local/remote Custom Groups do not match.
  5   - Disallow connection, local/remote Identities do not match.
  6   - Disallow connection, invalid metadata_version field.
  9   - BUG Disallow connection, general script failure.
  11  - ERROR Disallow connection, client key has invalid serial number.
  12  - ERROR Disallow connection, missing remote Identity.
  13  - ERROR Disallow connection, missing local Identity. (Unlucky)
  21  - USER ERROR Disallow connection, options error.
  22  - USER ERROR Disallow connection, failed to set --ca <PATH> *REQUIRED*.
  23  - USER ERROR Disallow connection, missing CA certificate.
  24  - USER ERROR Disallow connection, missing CRL file.
  25  - USER ERROR Disallow connection, missing index.txt.
  26  - USER ERROR Disallow connection, missing safessl-easyrsa.cnf.
  27  - USER ERROR Disallow connection, missing EasyTLS disabled list.
  28  - USER ERROR Disallow connection, missing openvpn server metadata_file.
  29  - USER ERROR Disallow connection, Invalid value for --tls-age.
  33  - USER ERROR Disallow connection, missing EasyTLS CA Identity file.
  34  - USER ERROR Disallow connection, Invalid --cache-id and --preload-cache-id
  35  - USER ERROR Disallow connection, missing openvpn server pid_file.
  119 - BUG Disallow connection, missing dependency file.
  121 - BUG Disallow connection, client serial number is not in CA database.
  122 - BUG Disallow connection, failed to verify CRL.
  123 - BUG Disallow connection, failed to verify CA.
  127 - BUG Disallow connection, duplicate serial number in CA database.
  253 - Disallow connection, exit code when --help is called.
  254 - BUG Disallow connection, fail_and_exit exited with default error code.
  255 - BUG Disallow connection, die exited with default error code.
'
	"$easytls_printf" "%s\n" "$help_msg"

	# For secrity, --help must exit with an error
	exit 253
}

# Verify CA
verify_ca ()
{
	"$easytls_openssl" x509 -in "$ca_cert" -noout
}

# Local identity
fn_local_identity ()
{
	"$easytls_openssl" x509 \
		-in "$ca_cert" -noout -${EASYTLS_HASH_ALGO} -fingerprint | \
			sed -e 's/^.*=//g' -e 's/://g'
}

# Verify CRL
verify_crl ()
{
	"$easytls_openssl" crl -in "$crl_pem" -noout
}

# Decode CRL
fn_read_crl ()
{
	"$easytls_openssl" crl -in "$crl_pem" -noout -text
}

# Search CRL for client cert serial number
fn_search_crl ()
{
	"$easytls_printf" "%s\n" "$crl_text" | \
		"$easytls_grep" -c "^[[:blank:]]*Serial Number: ${md_serial}$"
}

# Final check: Search index.txt for Valid client cert serial number
fn_search_index ()
{
	"$easytls_grep" -c \
		"^V.*[[:blank:]]${md_serial}[[:blank:]].*/CN=${md_name}.*$" \
		"$index_txt"
}

# Check metadata client certificate serial number against CRL
serial_status_via_crl ()
{
	client_cert_revoked="$(fn_search_crl)"
	case $client_cert_revoked in
	0)
		# Final check: Is this serial in index.txt and Valid
		case "$(fn_search_index)" in
		0)
		failure_msg="Serial number is not in the CA database:"
		fail_and_exit "SERIAL NUMBER UNKNOWN" 121
		;;
		1)
		client_passed_x509_tests_connection_allowed
		;;
		*)
		die "Duplicate serial numbers: $md_serial" 127
		;;
		esac
	;;
	1)
		client_passed_x509_tests_certificate_revoked
	;;
	*)
		insert_msg="Duplicate serial numbers detected:"
		failure_msg="$insert_msg $md_serial"
		die "Duplicate serial numbers: $md_serial" 127
	;;
	esac
}

# Check metadata client certificate serial number against CA
serial_status_via_ca ()
{
	# This is non-functional until openssl is fixed
	verify_openssl_serial_status

	# Get serial status via CA
	client_cert_serno_status="$(openssl_serial_status)"

	# Format serial status
	client_cert_serno_status="$(capture_serial_status)"
	client_cert_serno_status="${client_cert_serno_status% *}"
	client_cert_serno_status="${client_cert_serno_status##*=}"

	# Considering what has to be done, I don't like this
	case "$client_cert_serno_status" in
	Valid)
		client_passed_x509_tests_connection_allowed
	;;
	Revoked)
		client_passed_x509_tests_certificate_revoked
	;;
	*)
		die "Serial status via CA has broken" 9
	;;
	esac
}

# Use openssl to return certificate serial number status
openssl_serial_status ()
{
	# openssl appears to always exit with error - but here I do not care
	"$easytls_openssl" ca -cert "$ca_cert" -config "$openssl_cnf" \
		-status "$md_serial" 2>&1
}

# Capture serial status
capture_serial_status ()
{
	"$easytls_printf" "%s\n" "$client_cert_serno_status" | \
		"$easytls_grep" '^.*=.*$'
}

# Verify openssl serial status returns ok
verify_openssl_serial_status ()
{
	return 0 # Disable this `return` if you want to test
	# openssl appears to always exit with error - have not solved this
	"$easytls_openssl" ca -cert "$ca_cert" -config "$openssl_cnf" \
		-status "$md_serial" || \
		die "openssl returned an error exit code" 101

# This is why I am not using CA, from `man 1 ca`
: << MAN_OPENSSL_CA
WARNINGS
       The ca command is quirky and at times downright unfriendly.

       The ca utility was originally meant as an example of how to do things
       in a CA. It was not supposed to be used as a full blown CA itself:
       nevertheless some people are using it for this purpose.

       The ca command is effectively a single user command: no locking is
       done on the various files and attempts to run more than one ca command
       on the same database can have unpredictable results.
MAN_OPENSSL_CA
# This script ONLY reads, .:  I am hoping for better than 'unpredictable' ;-)
}

# Check metadata client certificate serial number against index.txt
serial_status_via_pki_index ()
{
	is_valid="$(fn_search_valid_pki_index)"
	is_revoked="$(fn_search_revoked_pki_index)"
	if [ $is_revoked -eq 0 ]
	then
		if [ $is_valid -eq 1 ]
		then
			client_passed_x509_tests_connection_allowed
		else
			# Cert is not known
			insert_msg="Serial number is not in the CA database:"
			failure_msg="$insert_msg $md_serial"
			fail_and_exit "SERIAL NUMBER UNKNOWN" 121
		fi
	else
		client_passed_x509_tests_certificate_revoked
	fi
}

# Final check: Search index.txt for Valid client cert serial number
fn_search_valid_pki_index ()
{
	"$easytls_grep" -c \
	"^V.*[[:blank:]]${md_serial}[[:blank:]].*\/CN=${md_name}.*$" \
		"$index_txt"
}

# Final check: Search index.txt for Revoked client cert serial number
fn_search_revoked_pki_index ()
{
	"$easytls_grep" -c \
	"^R.*[[:blank:]]${md_serial}[[:blank:]].*\/CN=${md_name}.*$" \
		"$index_txt"
}

# This is the long way to connect - X509
client_passed_x509_tests_connection_allowed ()
{
	insert_msg="Client certificate is recognised and Valid:"
	success_msg="$success_msg $insert_msg $md_serial"
	success_msg="$success_msg $md_name"
	absolute_fail=0
}

# This is the only way to fail for Revokation - X509
client_passed_x509_tests_certificate_revoked ()
{
	insert_msg="Client certificate is revoked:"
	failure_msg="$insert_msg $md_serial"
	fail_and_exit "CERTIFICATE REVOKED" 1
}

# This is the best way to connect - TLS only
client_passed_tls_tests_connection_allowed ()
{
	insert_msg="TLS key is recognised and Valid:"
	success_msg="$success_msg $insert_msg $tlskey_serial"
	success_msg="$success_msg $md_name"
	absolute_fail=0
}

# Initialise
init ()
{
	# Fail by design
	absolute_fail=1

	# metadata version
	local_easytls='easytls'
	local_custom_g='EASYTLS'

	# Verify tlskey-serial number by hash of metadata
	VERIFY_hash=1
	EASYTLS_HASH_ALGO="SHA256"

	# Do not accept external settings
	unset use_x509

	# Default temp dir
	EASYTLS_tmp_dir="/tmp"

	# TLS expiry age (days) Default 5 years, 1825 days
	tlskey_max_age=$((365*5))

	# From openvpn server
	openvpn_metadata_file="$metadata_file"

	# Required binaries
	easytls_openssl="openssl"
	easytls_cat="cat"
	easytls_grep="grep"
	easytls_sed="sed"
	easytls_printf="printf"

	# Log message
	status_msg="* Easy-TLS ==>"

	# X509 is disabled by default
	# To enable use command line option:
	# --v1|--via-crl   - client serial revokation via CRL grep (Default)
	# --v2|--via-ca    - client serial revokation via openssl ca command (Broken)
	# --v3|--via-index - client serial revokation via index.txt grep (Preferred)
	x509_method=0

	# Enable disable list by default
	use_disable_list=1
} # => init ()

# Dependancies
deps ()
{
	# CA_dir MUST be set with option: -c|--ca
	[ -d "$CA_dir" ] || die "Path to CA directory is required, see help" 22
	TLS_dir="$CA_dir/easytls/data"

	# CA required files
	ca_cert="$CA_dir/ca.crt"
	ca_identity_file="$TLS_dir/easytls-ca-identity.txt"
	crl_pem="$CA_dir/crl.pem"
	index_txt="$CA_dir/index.txt"
	openssl_cnf="$CA_dir/safessl-easyrsa.cnf"
	disabled_list="$TLS_dir/easytls-disabled-list.txt"
	tlskey_serial_index="$TLS_dir/easytls-key-index.txt"

	# Ensure we have all the necessary files
	help_note="This script requires an EasyRSA generated CA."
	[ -f "$ca_cert" ] || die "Missing CA certificate: $ca_cert" 23

	help_note="This script requires external binaries."
	if ! "$easytls_openssl" version > /dev/null; then
		die "Missing openssl" 119; fi
	if ! "$easytls_cat" --version   > /dev/null; then
		die "Missing cat"     119; fi
	if ! "$easytls_grep" -V         > /dev/null; then
		die "Missing grep"    119; fi
	if ! "$easytls_sed" --version   > /dev/null; then
		die "Missing sed"     119; fi

	if [ $use_cache_id ]
	then
	# This can soon be deprecated
	help_note="This script requires an EasyTLS generated CA identity."
		[ -f "$ca_identity_file" ] || \
			die "Missing CA identity: $ca_identity_file" 33
	fi

	if [ $use_x509 ]
	then
		# Only check these files if using x509
		help_note="This script requires an EasyRSA generated CRL."
		[ -f "$crl_pem" ] || die "Missing CRL: $crl_pem" 24

		help_note="This script requires an EasyRSA generated DB."
		[ -f "$index_txt" ] || die "Missing index.txt: $index_txt" 25

		help_note="This script requires an EasyRSA generated PKI."
		[ -f "$openssl_cnf" ] || die "Missing openssl config: $openssl_cnf" 26
	fi

	help_note="This script requires an EasyTLS generated disabled_list."
	[ -f "$disabled_list" ] || \
		die "Missing disabled list: $disabled_list" 27

	# `metadata_file` must be set by openvpn
	help_note="This script can ONLY be used by a running openvpn server."
	[ -f "$openvpn_metadata_file" ] || \
		die "Missing: openvpn_metadata_file: $openvpn_metadata_file" 28
	unset help_note

	# Get metadata_string
	metadata_string="$(cat "$openvpn_metadata_file")"

	# Populate metadata variables
	metadata_string_to_vars $metadata_string

	# Ensure that TLS expiry age is numeric
	case $tlskey_max_age in
		''|*[!0-9]*) # Invalid value
			# Exit script with error code 29 and disallow the connection
			die "Invalid value for --tls-age: $tlskey_max_age" 29
		;;
		*) # Valid value
		# maximum age in seconds
		tlskey_expire_age_sec=$((tlskey_max_age*60*60*24))
		;;
	esac

	# Check for either --cache-id or --preload-cache-id
	# Do NOT allow both
	[ $use_cache_id ] && [ $preload_cache_id ] && \
		die "Cannot use --cache-id and --preload-cache-id together." 34

	# Check the PID file
	if [ -n "$server_pid_file" ]
	then
		[ -f "$server_pid_file" ] || die "Missing PID file: $server_pid_file" 23
	else
		if [ $EASYTLS_tmp_dir ]
		then
			server_pid_file="${EASYTLS_tmp_dir}/easytls-server.pid"
		else
			[ $EASYTLS_VERBOSE ] && "$easytls_printf" '%s\n' "No pid file."
		fi
	fi
} # => deps ()

# Break metadata_string into variables
metadata_string_to_vars ()
{
	tlskey_serial="${1%%-*}"
	md_seed="${metadata_string#*-}"
	#md_padding="${md_seed%%--*}"
	md_easytls_ver="${1#*--}"
	md_easytls="${md_easytls_ver%-*.*}"

	md_identity="${2%%-*}"
	#md_srv_name="${2##*-}"

	md_serial="$3"
	md_date="$4"
	md_custom_g="$5"
	md_name="$6"
	md_subkey="$7"
	md_opt="$8"
	md_hwadds="$9"
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
	-c|--ca)
		CA_dir="$val"
	;;
	-g|--custom-group)
		local_custom_g="$val"
	;;
	-n|--no-hash)
		empty_ok=1
		unset VERIFY_hash
	;;
	-x|--max-tls-age)
		tlskey_max_age="$val"
	;;
	-d|--disable-list)
		empty_ok=1
		unset use_disable_list
	;;
	-s|--pid-file)
		server_pid_file="$val"
	;;
	-t|--tmp-dir)
		EASYTLS_tmp_dir="$val"
	;;
	--hash)
		EASYTLS_HASH_ALGO="$val"
	;;
	--v1|--via-crl)
		empty_ok=1
		status_msg="* Easy-TLS (crl) ==>"
		use_x509=1
		x509_method=1
	;;
	--v2|--via-ca)
		empty_ok=1
		status_msg="* Easy-TLS (ca) ==>"
		use_x509=1
		x509_method=2
	;;
	--v3|--via-index)
		empty_ok=1
		status_msg="* Easy-TLS (index) ==>"
		use_x509=1
		x509_method=3
	;;
	-a|--cache-id)
		empty_ok=1
		use_cache_id=1
	;;
	-p|--preload-id)
		preload_cache_id="$val"
	;;
	-v|--verbose)
		empty_ok=1
		EASYTLS_VERBOSE=1
	;;
	help|-h|-help|--help)
		empty_ok=1
		help_text
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
deps

# Metadata version

	# metadata_version MUST equal 'easytls'
	case "$md_easytls" in
	"$local_easytls")
		status_msg="$status_msg $md_easytls OK ==>"
	;;
	'')
		failure_msg="metadata version is missing"
		fail_and_exit "METADATA VERSION" 6
	;;
	*)
		failure_msg="metadata version is not recognised: $md_easytls"
		fail_and_exit "METADATA VERSION" 6
	;;
	esac

# Metadata custom_group

	# md_custom_g MUST equal local_custom_g
	case "$md_custom_g" in
	"$local_custom_g")
		status_msg="$status_msg custom_group $md_custom_g OK ==>"
	;;
	'')
		failure_msg="metadata custom_group is missing"
		fail_and_exit "METADATA CUSTOM GROUP" 4
	;;
	*)
		failure_msg="metadata custom_group is not correct: $md_custom_g"
		fail_and_exit "METADATA CUSTOM GROUP" 4
	;;
	esac

# tlskey-serial checks

	if [ $VERIFY_hash ]
	then
		# Verify tlskey-serial is in index
		"$easytls_grep" -q "$tlskey_serial" "$tlskey_serial_index" || {
		failure_msg="TL-key is not recognised"
		fail_and_exit "TLSKEY SERIAL ALIEN" 11
		}

		# HASH metadata sring without the tlskey-serial
		md_hash="$("$easytls_printf" '%s' "$md_seed" | \
			"$easytls_openssl" ${EASYTLS_HASH_ALGO} -r)"
		md_hash="${md_hash%% *}"
		[ "$md_hash" = "$tlskey_serial" ] || {
			failure_msg="TLS-key metadata hash is incorrect"
			fail_and_exit "TLSKEY SERIAL HASH" 11
			}
	fi

# tlskey expired

	# Verify key date and expire by --tls-age
	# Disable check if --tls-age=0 (Default age is 5 years)
	if [ $tlskey_expire_age_sec -gt 0 ]
	then
		# current date
		local_date_sec=$(date +%s)

		# days since key creation
		tlskey_age_sec=$(( local_date_sec - md_date ))
		tlskey_age_day=$(( tlskey_age_sec / (60*60*24) ))

		# Check key_age is less than --tls-age
		[ $tlskey_age_sec -lt $tlskey_expire_age_sec ] || {
			max_age_msg="Max age: $tlskey_max_age days"
			key_age_msg="Key age: $tlskey_age_day days"
			failure_msg="Key expired: $max_age_msg $key_age_msg"
			fail_and_exit "TLSKEY EXPIRED" 3
			}

		# Success message
		success_msg="$success_msg Key age $tlskey_age_day days OK ==>"
	fi

# Disabled list

	# Check serial number is not disabled
	# Use --disable-list to disable this check
	if [ $use_disable_list ]
	then
		# Search the disabled_list for client serial number
		if "$easytls_grep" -q "^${tlskey_serial}[[:blank:]]" "$disabled_list"
		then
			# Client is disabled
			failure_msg="client serial number is disabled: $md_serial"
			fail_and_exit "CLIENT DISABLED" 2
		else
			# Client is not disabled
			success_msg="$success_msg Enabled OK ==>"
		fi
	fi


# Start opptional X509 checks
if [ ! $use_x509 ]
then
	# No X509 required
	client_passed_tls_tests_connection_allowed
else

	# Verify CA cert is valid and/or set the CA identity
	if [ $use_cache_id ]
	then
		local_identity="$(cat "$ca_identity_file")"
	elif [ -n "$preload_cache_id" ]
	then
		local_identity="$preload_cache_id"
	else
		# Verify CA is valid
		verify_ca || die "Bad CA $ca_cert" 123

		# Set Local Identity: CA fingerprint
		local_identity="$(fn_local_identity)"
	fi

	# local_identity is required
	[ -z "$local_identity" ] && {
		failure_msg="Missing: local identity"
		fail_and_exit "LOCAL IDENTITY" 13
		}

	# Check metadata Identity against local Identity
	if [ "$local_identity" = "$md_identity" ]
	then
		insert_msg="identity OK ==>"
		success_msg="$success_msg $insert_msg"
	else
		failure_msg="identity mismatch"
		fail_and_exit "IDENTITY MISMATCH" 5
	fi


	# Verify serial status
	case $x509_method in
	1)
		# Method 1
		# Check metadata client certificate serial number against CRL

		# Verify CRL is valid
		verify_crl || die "Bad CRL: $crl_pem" 122

		# Capture CRL
		crl_text="$(fn_read_crl)"

		# Verify via CRL
		serial_status_via_crl
	;;
	2)
		# Method 2
		# Check metadata client certificate serial number against CA

		# Due to openssl being "what it is", it is not possible to
		# reliably verify the 'openssl ca $cmd'

		# Verify via CA
		serial_status_via_ca
	;;
	3)
		# Method 3
		# Search openssl index.txt for client serial number
		# and return Valid, Revoked or not Known status
		# openssl is never loaded for this check
		serial_status_via_pki_index
	;;
	*)
		die "Unknown method for verify: $x509_method" 9
	;;
	esac

fi # => use_x509 ()

# Save the hardware addresses to temp file
# Need to confirm temp dir location
if [ -f "$server_pid_file" ]
then
	daemon_pid="$(cat "$server_pid_file")"
	client_hw_list="$EASYTLS_tmp_dir/$md_serial.$daemon_pid"
	#[ -f "$client_hw_list" ] && fail_and_exit "File exists: $client_hw_list"
	"$easytls_printf" '%s\n%s\n' "$md_hwadds" "$md_opt" > "$client_hw_list" || \
		die "Failed to write HW file"
	[ $EASYTLS_VERBOSE ] && print "HWADDR-file: $client_hw_list"
else
	# OpenVPN does not give the PID so it must be set via $server_pid_file
	# In this case, assume hardware address verification is not required
	[ $EASYTLS_VERBOSE ] && \
		print "Hardware-address verification is not configured."
fi

# Any failure_msg means fail_and_exit
[ "$failure_msg" ] && fail_and_exit "NEIN" 99

# For DUBUG
[ "$FORCE_ABSOLUTE_FAIL" ] && absolute_fail=1 && \
	failure_msg="FORCE ABSOLUTE FAIL"

# There is only one way out of this...
[ $absolute_fail -eq 0 ] || fail_and_exit "ABSOLUTE FAIL" 9

# All is well
[ $EASYTLS_VERBOSE ] && \
	"$easytls_printf" "%s\n" "<EXOK> $status_msg $success_msg"

exit 0
