#!/bin/sh

#export EASYTLS_UTEST_CURL_TARGET="${EASYTLS_UTEST_CURL_TARGET:-TinCanTech/easytls-unit-tests}"
#curl -O "https://raw.githubusercontent.com/$EASYTLS_UTEST_CURL_TARGET/master/easytls-unit-tests.sh"


CURL_TARGET="https://raw.githubusercontent.com/OpenVPN/easy-rsa/master/easyrsa3/easyrsa"
curl -O "$CURL_TARGET"
CURL_TARGET="https://raw.githubusercontent.com/OpenVPN/easy-rsa/master/easyrsa3/openssl-easyrsa.cnf"
curl -O "$CURL_TARGET"
echo

exit

EXIT_CODE=1
if [ -e "easyrsa" ];
then
	# '-e' lol
	chmod 744 "easyrsa"
	EXIT_CODE=0
	EASYTLS_UTEST_VERB_LEVEL="${EASYTLS_UTEST_VERB_LEVEL:-"-v"}"
	sh easytls-unit-tests.sh "$EASYTLS_UTEST_VERB_LEVEL" || EXIT_CODE=1
	#rm -f "easyrsa" "openssl-easyrsa.cnf"
else
	echo "Failed to DL easyrsa"
fi

exit "$EXIT_CODE"
