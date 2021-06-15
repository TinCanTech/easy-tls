# Easy-TLS Features
Easy-TLS is an Easy-RSA extension utility to help manage:
+ Easy-RSA based x509 security credentials
+ OpenVPN specific TLS keys
+ Verified `Inline` files for use with OpenVPN
+ Concise OpenVPN TLS-Crypt-V2 Client Key Metadata definition
+ X509 Certificate **and matched** Easy-TLS Inline-file Expiry management tools
+ Complete **Inter-active Menus**
# Additional tools
EasyTLS scripts to interogate EasyTLS-CryptV2 metadata:
+ `easytls-cryptv2-verify.sh` - TLS-Crypt-V2 key metadata access policy tool.
+ `easytls-verify.sh` - TLS and X509 level access policy tool.
+ `easytls-client-connect.sh` - Hardware-address access policy tool.

## Installation
Simply copy `easytls` to your `easyrsa` working directory.

For full support, you will also need these scripts for use by your OpenVPN Server:
+ `easytls-cryptv2-verify.sh`<br>
  This script manages EasyTLS Crypt V2 Metadata field access policy rules.

+ `easytls-verify.sh`<br>
  This script is required for EasyTLS Crypt V2 Metadata hardware-address access policy rules.

+ `easytls-cryptv2-client-connect.sh`<br>
  This script manages EasyTLS Crypt V2 Metadata hardware-address access policy rules.

## Environment
`easytls` is intended to work **everywhere** that `openvpn` and `easyrsa` work.
**Except on macOS, where only Openvpn clients are allowed and cannot generate keys.**

## Requirements
+ Easy-RSA Version 3.0.5+
+ OpenVPN Version 2.5.0+

## Support
Please use the issues section here on github. <br>
For live support you can use IRC channel: **libera.chat/#easytls**<br>
Wiki: https://github.com/TinCanTech/easy-tls/wiki<br>
Howto: https://github.com/TinCanTech/easy-tls/blob/master/EasyTLS-Howto-ii.md<br>

# Acknowledgements
Easy-TLS is *written in the style of* and *borrows heavily from* Easy-RSA <br>
See: https://github.com/OpenVPN/easy-rsa <br>
**Note:** <br>
This is intended to facilitate maximum compatibility with Easy-RSA while extending functionality <br>
to include direct support for OpenVPN specific TLS keys and Inline credentials. <br>

Easy-TLS is inspired by **syzzer** <br>
See: https://github.com/OpenVPN/openvpn/blob/master/doc/tls-crypt-v2.txt


