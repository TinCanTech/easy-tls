#!/bin/sh

# Copyright - negotiable
copyright ()
{
: << VERBATUM_COPYRIGHT_HEADER_INCLUDE_NEGOTIABLE
# easytls-op-test.sh -- Remote CI unit test launcher
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

dl_ossl3 ()
{
	file="apps/openssl"
	source="TinCanTech/pre-built-openssl-3/master"
	host="https://raw.githubusercontent.com"

	printf '%s\n\n' "* curl -SO ${host}/${source}/${file}"
	curl -SO "${host}/${source}/${file}" || \
		die "Failed to download $file, error: $?"

	OSSL_V3_LIBB="${PWD}/openssl"

	printf '%s\n\n' "* chmod +x openssl"
	chmod +x openssl

	"${OSSL_V3_LIBB}" version || die "openssl version: ${OSSL_V3_LIBB}"
}

env

etls_ut_file_list="easytls
easytls-cryptv2-verify.sh
examples/easytls-cryptv2-verify.vars-example
easytls-client-connect.sh
examples/easytls-client-connect.vars-example
easytls-client-disconnect.sh
examples/easytls-client-disconnect.vars-example
easytls-conntrac.lib
dev/easytls-unit-tests.sh
dev/easytls-metadata.lib
dev/easytls-tctip.lib
dev/easytls-shellcheck.sh
dev/et-tdir1.tar
dev/et-tdir2.tar
dev/et-tdir3.tar"

etls_ut_dir_name='./0 0'

mkdir -p "${etls_ut_dir_name}/dev" "${etls_ut_dir_name}/examples"

for f in ${etls_ut_file_list}; do
	cp -v "./${f}" "${etls_ut_dir_name}/${f}"
done

cd "${etls_ut_dir_name}"

dl_ossl3

CURL_TARGET="https://raw.githubusercontent.com/TinCanTech/easy-rsa/master/easyrsa3/easyrsa"
curl -O "$CURL_TARGET" || exit 77
CURL_TARGET="https://raw.githubusercontent.com/TinCanTech/easy-rsa/master/easyrsa3/openssl-easyrsa.cnf"
curl -O "$CURL_TARGET" || exit 77
CURL_TARGET="https://raw.githubusercontent.com/TinCanTech/Prebuilt-OpenVPN/master/src/openvpn/openvpn"
curl -O "$CURL_TARGET" || exit 77
echo

for f in ./easyrsa ./openssl-easyrsa.cnf ./openvpn
do
	if [ -f "${f}" ];
	then
		chmod 744 "${f}"
	else
		echo "Failed to DL ${f}"
		exit 71
	fi
done

pwd
ls -l

	#export EASYTLS_REMOTE_CI=1
	export SHALLOW=1

	export EASYTLS_OPENVPN="./openvpn"
	printf "%s\n" "EASYTLS_OPENVPN=$EASYTLS_OPENVPN"

	export EASYRSA_OPENSSL="./openssl"
	printf "%s\n" "EASYRSA_OPENSSL=$EASYRSA_OPENSSL"

	$EASYTLS_OPENVPN --version

	sh ./dev/easytls-shellcheck.sh

	sh ./dev/easytls-unit-tests.sh

cd ..
rm -rf "${etls_ut_dir_name}"
