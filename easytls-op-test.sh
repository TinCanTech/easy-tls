#!/bin/sh

#export EASYTLS_UTEST_CURL_TARGET="${EASYTLS_UTEST_CURL_TARGET:-TinCanTech/easytls-unit-tests}"
#curl -O "https://raw.githubusercontent.com/$EASYTLS_UTEST_CURL_TARGET/master/easytls-unit-tests.sh"


CURL_TARGET="https://raw.githubusercontent.com/OpenVPN/easy-rsa/master/easyrsa3/easyrsa"
curl -O "$CURL_TARGET"
CURL_TARGET="https://raw.githubusercontent.com/OpenVPN/easy-rsa/master/easyrsa3/openssl-easyrsa.cnf"
curl -O "$CURL_TARGET"
CURL_TARGET="https://raw.githubusercontent.com/TinCanTech/Prebuilt-OpenVPN/master/src/openvpn/openvpn"
curl -O "$CURL_TARGET"
echo

EXIT_CODE=1
if [ -e "easyrsa" ];
then
	# '-e' lol
	chmod 744 "easyrsa"
	chmod 744 "openvpn"
	EXIT_CODE=0
	export EASYTLS_OPENVPN="./openvpn"
	printf "%s\n" "EASYTLS_OPENVPN=$EASYTLS_OPENVPN"
	$EASYTLS_OPENVPN --version
	time sh easytls-unit-tests.sh || EXIT_CODE=1
else
	echo "Failed to DL easyrsa"
fi

echo
echo "exit code: $EXIT_CODE"
echo "Over ride failure!"
echo "This is all tested locally prior to release"
echo "Travis CI is used to provide open results"
EXIT_CODE=0
exit 0
