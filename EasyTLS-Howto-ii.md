# EasyTLS-Howto (By wiscii)

## Installation and usage instructions:

### Installation

* Download [easytls](https://github.com/TinCanTech/easy-tls/blob/master/easytls) to your EasyRSA3 working directory.<br>
 `easytls` requires access to your PKI to verify and create keys.<br>
 `easytls` only needs access to your `private/ca.key` to generate your CA fingerprint.<br>
 It is not necessary to have a separate directory for `easytls`<br>

* Download [easytls-cryptv2-verify.sh](https://github.com/TinCanTech/easy-tls/blob/master/easytls-cryptv2-verify.sh)<br>
  Requires access to the files created by `easytls`.<br>

* Download [easytls-cryptv2-client-connect.sh](https://github.com/TinCanTech/easy-tls/blob/master/easytls-cryptv2-client-connect.sh)<br>
  Requires access to temporary files created by `easytls-cryptv2-verify.sh`. (Client hardware address list)<br>

### EasyTLS Usage

First, you must have your EasyRSA-3 PKI fully setup, which includes CA, Server and Client certificates.<br>
(EasyRSA-3 has a simple `upgrade` command which can attempt an upgrade on your current PKI)

**EasyTLS command examples**

Please use the help: `./easytls help` | `./easytls help <command>` | `./easytls help options`

* Initialise: `./easytls init-tls`
* Status: `./easytls status`<br>
  Use `help` now.
* Create a TLS-Crypt-V2 Server key: <br>
  `./easytls build-tls-crypt-v2-server <server_filename_base>` <br>
  Your `server` could be called `server01` for example.<br>
  This key is a mandatory requirement before creating a TLS-Crypt-V2 client key.<br>
  There are no user options for this command.<br>
* Create a TLS-Crypt-V2 Client key: <br>
  `./easytls build-tls-crypt-v2-client <server_filename_base> <client_filename_base> <CUSTOM-GROUP>` <br>
  Your `client` could be called `client-09` for example.<br>
  Your `<CUSTOM-GROUP>` is limited to a single contiguous word.<br>
* Create a TLS-Crypt-V2 Client key with hardware _lockdown_: <br>
  `./easytls --hw-addr=1234567890ab --hw-addr=abcdef123456 build-tls-crypt-v2-client <server_filename_base> <client_filename_base> <CUSTOM-GROUP>` <br>
  `--hw-addr=` requires the MAC address of the client machine as hexadecimal only characters. (Eth/Wifi/yw) <br>
* Create an `.inline` file: <br>
  `./easytls inline-tls-crypt-v2 <filename_base> [ cmd-opts ]` <br>
  Your `filename` could be called `client-09` for example. (As above) <br>
  `[ cmd-opts ]` here consist of `nokey` (When you do not have the private key for this node) and `add-dh` (For server files only) <br>
* Status: `./easytls status`<br>
  Use `help` now.

**Use easytls-cryptv2-verify.sh**

Use this in your OpenVPN server config: <br>
` tls-crypt-v2-verify './easytls-cryptv2-verify.sh -c=./pki1 -v -g=tincantech --verify-via-index -x=24 --cache-id -t=/tmp --pid-file=/tmp/easytls-srv.pid'
 writepid /tmp/easytls-srv.pid'` <br>

Change `tincantech` to your own Custom-Group.<br>

**Use easytls-cryptv2-client-connect.sh**

Use this in your OpenVPN server config: <br>
`client-connect './easytls-cryptv2-client-connect.sh -v -t=/tmp -r'` <br>

If it does not work then try without `-r`. <br>

If you have successfully got this far then you can move your `private/ca.key` to a safe place. <br>
