[![CI](https://github.com/TinCanTech/easy-tls/actions/workflows/blank.yml/badge.svg)](https://github.com/TinCanTech/easy-tls/actions/workflows/blank.yml)
# Easy-TLS

## Standard Features
Easy-TLS is an Easy-RSA extension utility to help manage:
+ Easy-RSA based x509 security credentials
+ OpenVPN specific TLS keys
+ Verified **`Inline`** files for use with OpenVPN
+ Concise OpenVPN TLS-Crypt-V2 Client Key Metadata definition
+ X509 Certificate **and matched** Easy-TLS Inline-file Expiry management tools
+ Substantial **Inter-active Menus**

## Additional Features
Easy-TLS also supports No-CA mode, which does not require an Easy-RSA CA:
+ Use Easy-TLS to build **self-signed** X509 Certificates and keys.

### Installation
Download: [**`easytls`**](https://github.com/TinCanTech/easy-tls/blob/master/easytls) and [**`easytls-openssl.cnf`**](https://github.com/TinCanTech/easy-tls/blob/master/easytls-openssl.cnf) to your `easyrsa3` working directory.

For full support, you will also need these scripts for use by your OpenVPN Server:
+ [**`easytls-cryptv2-verify.sh (1)`**](https://github.com/TinCanTech/easy-tls/blob/master/easytls-cryptv2-verify.sh) - **Can be used stand-alone**<br>
  Used by Openvpn-Server to enforce TLS-Crypt-V2 `metadata` access policy rules.<br>

+ [**`easytls-client-connect.sh (2)`**](https://github.com/TinCanTech/easy-tls/blob/master/easytls-client-connect.sh) - **Requires script `(1)(3)`**<br>
  Used by Openvpn-Server to enforce `TLS-Key-type` and `address-filter` access policy rules.<br>

+ [**`easytls-client-disconnect.sh (3)`**](https://github.com/TinCanTech/easy-tls/blob/master/easytls-client-disconnect.sh) - **Requires script `(1)(2)`**<br>
  This Disconnect script is **required by** the Connect script.

+ [**`easytls-conntrac.lib`**](https://github.com/TinCanTech/easy-tls/blob/master/easytls-conntrac.lib) - **Requires script `(1)(2)(3)`**<br>
  Connection tracking plug-in, required for connection tracking.

### Environment
**`easytls`** is intended to work **everywhere** that **`openvpn`** and **`easyrsa`** work.

### Requirements
+ Easy-RSA Version 3.0.6+
+ OpenVPN Version 2.5.0+

### Support
Please use the issues section here on github.<br>
For live support you can use IRC channel: **libera.chat/#easytls**<br>
Wiki: https://github.com/TinCanTech/easy-tls/wiki<br>
Howto: https://github.com/TinCanTech/easy-tls/blob/master/EasyTLS-Howto-ii.md<br>

## Acknowledgements
Easy-TLS is *written in the style of* and *borrows heavily from* Easy-RSA<br>
See: https://github.com/OpenVPN/easy-rsa<br>
**Note:**<br>
This is intended to facilitate maximum compatibility with Easy-RSA while extending functionality<br>
to include direct support for OpenVPN specific TLS keys and Inline credentials.<br>

### Easy-TLS is inspired by **syzzer**<br>
See: https://github.com/OpenVPN/openvpn/blob/master/doc/tls-crypt-v2.txt<br>

