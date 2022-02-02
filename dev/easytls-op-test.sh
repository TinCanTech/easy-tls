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

env

etls_ut_file_list="easytls
easytls-cryptv2-verify.sh
easytls-cryptv2-verify.vars-example
easytls-client-connect.sh
easytls-client-connect.vars-example
easytls-client-disconnect.sh
easytls-client-disconnect.vars-example
easytls-conntrac.lib
dev/easytls-unit-tests.sh
dev/easytls-metadata.lib
dev/easytls-tctip.lib
dev/easytls-shellcheck.sh"

etls_ut_dir_name='./0 0'

mkdir -p "${etls_ut_dir_name}/dev"

for f in ${etls_ut_file_list}; do
	cp -v "./${f}" "${etls_ut_dir_name}/${f}"
done

cd "${etls_ut_dir_name}"

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

	export SHALLOW=1
	export EASYTLS_OPENVPN="./openvpn"
	printf "%s\n" "EASYTLS_OPENVPN=$EASYTLS_OPENVPN"
	$EASYTLS_OPENVPN --version

	sh ./dev/easytls-shellcheck.sh

	sh ./dev/easytls-unit-tests.sh
