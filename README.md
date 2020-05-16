# Easy-TLS
An Easy-RSA extension utility to help manage:
+ Easy-RSA based x509 security credentials
+ OpenVPN specific TLS keys
+ Verified `Inline` files for use with OpenVPN
+ `tls-crypt-v2-verify.sh` - Fully compatible with EasyTLS generated keys and inline files.

## Installation
Simply copy `easytls` to your `easyrsa` working directory.

## Environment
`easytls` is intended to work **everywhere** that `easyrsa` works.

## Support
Please use the issues section here on github. <br>
For live support you can use IRC channel: **Freenode/#easytls**

## Acknowledgements
This utility is *written in the style of* and *borrows heavily from* Easy-RSA <br>
See: https://github.com/OpenVPN/easy-rsa <br>
Note: This is intended to facilitate maximum compatibility with Easy-RSA while extending functionality to include direct support for OpenVPN specific TLS keys and Inline credentials.

## Credits
See: https://github.com/TinCanTech/easy-tls/blob/master/CREDITS.md

### Easy-TLS requirements
+ Easy-RSA Version 3.0.5 (Or https://github.com/TinCanTech/easyrsa-plus)
+ OpenVPN Version 2.4.8 (Partial support) (Full support: `git/master`)
