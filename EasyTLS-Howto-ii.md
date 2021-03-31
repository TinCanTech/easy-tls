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
<br>
Please use the help:<br>
  `./easytls help` - General help.<br>
  `./easytls help <command>` - Command help.<br>
  `./easytls help options` - Command --options.<br>
  `./easytls help abb` - Command abbreviations.<br>
  `./easytls help config` - Configuration help.<br>
  <br>
* Initialise:
  ```
  ./easytls init-tls <hash algorithm>
  ```
  Default hash is SHA256 but Easy-TLS allows for use of SHA1<br>
  Easy-TLS optional use of SHA1 is not considered to be a security risk.<br>
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
  You can use the `custom.group` option to save your Custom group, or use<br>
  `--custom-group=XYZ` on the command line for all the commands which need it.<br>
  <br>
* Use interactive menus:
  ```
  ./easytls build     - Build keys
  ./easytls inline    - Create Inline files
  ./easytls remove    - Remove Inline files and keys
  ./easytls script    - Configure server side scripts
  ```
  These inter-active menus will take you through all the options for building TLS keys<br>
  and inlining all the required files for a credentials only OpenVPN inline configuration file.<br>
  <br>
  All commands are then shown before the command is completed by the script.

