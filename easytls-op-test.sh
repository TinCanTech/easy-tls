#!/bin/sh

#export EASYTLS_UTEST_CURL_TARGET="${EASYTLS_UTEST_CURL_TARGET:-TinCanTech/easytls-unit-tests}"
#curl -O "https://raw.githubusercontent.com/$EASYTLS_UTEST_CURL_TARGET/master/easytls-unit-tests.sh"


CURL_TARGET="https://raw.githubusercontent.com/OpenVPN/easy-rsa/master/easyrsa3/easyrsa"
curl -O "$CURL_TARGET" || exit 77
CURL_TARGET="https://raw.githubusercontent.com/OpenVPN/easy-rsa/master/easyrsa3/openssl-easyrsa.cnf"
curl -O "$CURL_TARGET" || exit 77
CURL_TARGET="https://raw.githubusercontent.com/TinCanTech/Prebuilt-OpenVPN/master/src/openvpn/openvpn"
curl -O "$CURL_TARGET" || exit 77
echo

EXIT_CODE=1

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

	export EASYTLS_TRAVIS_CI=1
	export SHALLOW=1
	export Skip_wiscii_hash=1
	export EASYTLS_OPENVPN="./openvpn"
	printf "%s\n" "EASYTLS_OPENVPN=$EASYTLS_OPENVPN"
	$EASYTLS_OPENVPN --version

	time sh easytls-unit-tests.sh
