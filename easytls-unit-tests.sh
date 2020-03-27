#!/bin/sh

fail ()
{
	echo "$@"
	echo WTF
	exit 1
}

# Wrapper around printf - clobber print since it's not POSIX anyway
print() { printf "%s\n" "$*"; }

build_easyrsa ()
{

mkdir x509-types

print "
# X509 extensions added to every signed cert

# This file is included for every cert signed, and by default does nothing.
# It could be used to add values every cert should have, such as a CDP as
# demonstrated in the following example:

#crlDistributionPoints = URI:http://example.net/pki/my_ca.crl
" > x509-types/COMMON

print "
# X509 extensions for a ca

# Note that basicConstraints will be overridden by Easy-RSA when defining a
# CA_PATH_LEN for CA path length limits. You could also do this here
# manually as in the following example in place of the existing line:
#
# basicConstraints = CA:TRUE, pathlen:1

basicConstraints = CA:TRUE
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid:always,issuer:always
keyUsage = cRLSign, keyCertSign
" > x509-types/ca

print "
# X509 extensions for a server

basicConstraints = CA:FALSE
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid,issuer:always
extendedKeyUsage = serverAuth
keyUsage = digitalSignature,keyEncipherment
" > x509-types/server

print "
# X509 extensions for a client

basicConstraints = CA:FALSE
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid,issuer:always
extendedKeyUsage = clientAuth
keyUsage = digitalSignature
" > x509-types/client

}

build_easyrsa

EASYRSA_CMD="./easyrsa"
EASYTLS_CMD="./easytls"

for i in "init-pki" "build-ca nopass" "build-server-full s01 nopass" \
	"build-client-full c01 nopass" "build-client-full c02 nopass" \
	"build-client-full c03 nopass"
do
	"$EASYRSA_CMD" --batch $i || fail "$EASYRSA_CMD --batch $i"
done

for i in "init-tls" "build-tls-auth" "build-tls-crypt" "build-tls-crypt-v2-server s01" "build-tls-crypt-v2-client s01 c01" \
	"inline-status" "inline-base s01" "inline-status" "inline-renew s01" "inline-remove s01" \
	"inline-status" "inline-tls-auth s01 0" "inline-status" "inline-renew s01" "inline-remove s01" \
	"inline-status" "inline-tls-auth c01 1" "inline-status" "inline-renew c01" "inline-remove c01" \
	"inline-status" "inline-tls-crypt s01" "inline-status" "inline-renew s01" "inline-remove s01" \
	"inline-status" "inline-tls-crypt c01" "inline-status" "inline-renew c01" "inline-remove c01" \
	"inline-status" "inline-tls-crypt-v2 s01" "inline-status" "inline-renew s01" "inline-remove s01" \
	"inline-status" "inline-tls-crypt-v2 c01" "inline-status" "inline-renew c01" "inline-remove c01" \
	"inline-status"
do
	echo "============================================================"
	"$EASYTLS_CMD" --batch $i || fail "$EASYTLS_CMD $i"
done

echo "============================================================"
echo "Completed successfully: $(date +%Y/%m/%d--%H:%M:%S)"
echo "============================================================"

exit 0
