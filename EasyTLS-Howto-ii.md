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

Please use the help:<br>
  `./easytls help` - General help.<br>
  `./easytls help <command>` - Command help.<br>
  `./easytls help options` - Command --options.<br>
  `./easytls help abb` - Command abbreviations.<br>
  `./easytls help config` - Configuration help.<br>
  <br>
* Initialise:
  ```
  ./easytls init-tls
  ```
  <br>
* Status:
  ```
  ./easytls status
  ```
  Use `help` now.<br>
  <br>
* Create your CA-Identity file:
  ```
  ./easytls save-id
  ```
  (This is your formatted CA fingerprint)<br>
  <br>
  If you have successfully got this far then you can move your `private/ca.key` to a safe place. <br>
  <br>
* Check your configuration:
  ```
  ./easytls config
  ```
  This is a good time to set your `custom.group`.<br>
  You can use the `custom.group` option to save your Custom group, or<br>
  Use `--custom-group=XYZ` on the command line for all the commands which need it.<br>
  <br>
* Create a TLS-Crypt-V2 Server key:
  ```
  ./easytls build-tls-crypt-v2-server <server_filename_base>
  ```
  Your `server` could be called `server01` for example.<br>
  This key is a mandatory requirement before creating a TLS-Crypt-V2 client key.<br>
  There are no user options for this command.<br>
  <br>
* Create a TLS-Crypt-V2 Client key:
  ```
  ./easytls --custom-group=<CUSTOM-GROUP> build-tls-crypt-v2-client <server_filename_base> <client_filename_base>
  ```
  Your `client` could be called `client-09` for example.<br>
  Your `<CUSTOM-GROUP>` is limited to a single contiguous word. eg: `tincantech`<br>
  <br>
* Create a TLS-Crypt-V2 Client key with hardware _lockdown_:
  ```
  ./easytls --custom-group=<CUSTOM-GROUP> build-tls-crypt-v2-client <server_filename_base> <client_filename_base> 12-34-56-78-90-ab ab:cd:ef:12:34:56
  ```
  Append the MAC addresses of the client machine as hexadecimal only characters. eg: 12-34-56-78-90-ab (Eth/Wifi/yw) <br>
  <br>
  This option can be specified for any number of MACs upto the maximum line length or key metadata limit.<br>
  <br>
* Create an `.inline` file:
  ```
  ./easytls inline-tls-crypt-v2 <filename_base> [ cmd-opts ]
  ```
  Your `filename` could be called `client-09` for example. (As above) <br>
  `[ cmd-opts ]` here consist of `nokey` (When you do not have the x509 private key for this node)<br>
  and `add-dh` (For server files only) <br>
  <br>
* Create another TLS-Crypt-V2 Client key for the same client:
  ```
  ./easytls --sub-key-name=TEST --custom-group=<CUSTOM-GROUP> build-tls-crypt-v2-client <server_filename_base> <client_filename_base>
  ```
  Your `--sub-key-name` could be `HOME` or `Key02` for example.<br>
  Your `client` could be called `client-09` for example.<br>
  Your `<CUSTOM-GROUP>` is limited to a single contiguous word. eg: `tincantech`<br>
  <br>
* Create another `.inline` file for the same client using the secondary key:
  ```
  ./easytls --sub-key-name=TEST inline-tls-crypt-v2 <filename_base> [ cmd-opts ]
  ```
  Your `--sub-key-name` could be `HOME` or `Key02` for example.<br>
  Your `filename` could be called `client-09` for example. (As above) <br>
  `[ cmd-opts ]` here consist of `nokey` (When you do not have the x509 private key for this node)<br>
  and `add-dh` (For server files only) <br>
  <br>
* Create a TLS-Crypt-V2 Server or Client key and Inline file in one pass:
  ```
  ./easytls --inline build-tls-crypt-v2-client <server_filename_base> <client_filename_base>
  ```
  The `--inline` option only works for generating TLS-Crypt-V2 server and client keys and only excepts<br>
  default values for `inline-tls-crypt-v2`. You cannot specify `nokey`, `add-dh`, `no-md` or `add-hw`.<br>
  <br>
* Status:
  ```
  ./easytls status
  ```
  Use `help` now.<br>
  <br>

### Use easytls-cryptv2-verify.sh

* Use this in your OpenVPN server config: <br>
  ```
  tls-crypt-v2-verify './easytls-cryptv2-verify.sh -c=./pki1 -v -g=tincantech --verify-via-index -x=24 --cache-id -t=/tmp --pid-file=/tmp/easytls-srv.pid'

  writepid /tmp/easytls-srv.pid
  ```
  Change `tincantech` to your own Custom-Group.<br>
  <br>

### Use easytls-cryptv2-client-connect.sh

* Use this in your OpenVPN server config: <br>
  ```
  client-connect './easytls-cryptv2-client-connect.sh -v -t=/tmp -r'
  ```
  If it does not work then try without `-r`. <br>


