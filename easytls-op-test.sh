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

Required_file="./easyrsa"
if [ -e "$Required_file" ];
then
	# '-e' lol
	chmod 744 "$Required_file"
else
	echo "Failed to DL $Required_file"
	exit 71
fi

Required_file="./openssl-easyrsa.cnf"
if [ -e "$Required_file" ];
then
	# '-e' lol
	chmod 744 "$Required_file"
else
	echo "Failed to DL $Required_file"
	exit 72
fi

Required_file="./openvpn"
if [ -e "$Required_file" ];
then
	# '-e' lol
	chmod 744 "$Required_file"
else
	echo "Failed to DL $Required_file"
	exit 73
fi

	export SHALLOW=1
	export EASYTLS_OPENVPN="./openvpn"
	printf "%s\n" "EASYTLS_OPENVPN=$EASYTLS_OPENVPN"
	$EASYTLS_OPENVPN --version

	sh easytls-unit-tests.sh
