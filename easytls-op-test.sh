#!/bin/sh

# Copyright - negotiable
copyright ()
{
: << VERBATUM_COPYRIGHT_HEADER_INCLUDE_NEGOTIABLE
# easytls-cryptv2-client-connect.sh -- Do simple magic
#
# Copyright (C) 2020 Richard Bonhomme (Friday 13th of March 2020)
# https://github.com/TinCanTech/easy-tls
# tincantech@protonmail.com
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

env

CURL_TARGET="https://raw.githubusercontent.com/OpenVPN/easy-rsa/master/easyrsa3/easyrsa"
curl -O "$CURL_TARGET" || exit 77
CURL_TARGET="https://raw.githubusercontent.com/OpenVPN/easy-rsa/master/easyrsa3/openssl-easyrsa.cnf"
curl -O "$CURL_TARGET" || exit 77
CURL_TARGET="https://raw.githubusercontent.com/TinCanTech/Prebuilt-OpenVPN/master/src/openvpn/openvpn"
curl -O "$CURL_TARGET" || exit 77
echo

for f in ./easyrsa ./openssl-easyrsa.cnf ./openvpn
do
	if [ -e "${f}" ];
	then
		# '-e' lol
		chmod 744 "${f}"
	else
		echo "Failed to DL ${f}"
		exit 71
	fi
done

	export SHALLOW=1
	export EASYTLS_OPENVPN="./openvpn"
	printf "%s\n" "EASYTLS_OPENVPN=$EASYTLS_OPENVPN"
	$EASYTLS_OPENVPN --version

	sh easytls-shellcheck.sh

	sh easytls-unit-tests.sh
