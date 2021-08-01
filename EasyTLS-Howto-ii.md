# EasyTLS-Howto (By wiscii)

## Installation and usage instructions:

### Installation

* Download [easytls](https://github.com/TinCanTech/easy-tls/blob/master/easytls) to your EasyRSA3 working directory.<br>
 `easytls` requires access to your PKI to verify and create keys.<br>
 It is not necessary to have a separate directory for `easytls`<br>

* Download [easytls-openssl.cnf](https://github.com/TinCanTech/easy-tls/blob/master/easytls-openssl.cnf)<br>

* Download [easytls-cryptv2-verify.sh](https://github.com/TinCanTech/easy-tls/blob/master/easytls-cryptv2-verify.sh)<br>
  Requires access to the files created by `easytls`.<br>

* Download [easytls-verify.sh](https://github.com/TinCanTech/easy-tls/blob/master/easytls-verify.sh)<br>
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
  This will also create your CA-Identity file and `ca.id` configuration record.<br>
  <br>
* Status:
  ```
  ./easytls status
  ```
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


### Howto resolve issues with Invalid .inline files:

  If you receive a message informing you that you have "Revoked certs" or<br>
  "Renewed certs" then simply use './easytls inline-remove <filename-base>'<br>
  This will delete the offending Inline file and keep the EasyTLS index up-to-date.<br>
  Invalid files are caused by x509 certificates which have been revoked.<br>
  The Inline file is of no further value once the certificate has been revoked.<br>


### Howto resolve issues with the EasyTLS inline-index:

  In the unlikely event that something does go wrong with the EasyTLS Inline Index
  then simply use './easytls inline-index-rebuild'
  EasyTLS will attempt to rebuild your index.  (Please report issues on github)

