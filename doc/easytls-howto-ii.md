# EasyTLS-Howto (By wiscii)

## Installation and usage instructions:

### Installation

* Download [**`easytls`**](https://github.com/TinCanTech/easy-tls/blob/master/easytls) to your EasyRSA3 working directory.<br>
  `easytls` requires access to your PKI to verify and create keys.<br>
  It is not necessary to have a separate directory for `easytls`<br>

* Download [**`easytls-openssl.cnf`**](https://github.com/TinCanTech/easy-tls/blob/master/easytls-openssl.cnf)<br>
  Required by `easytls` to build self-signed certificates in No-CA mode.<br>

* Download [**`easytls-cryptv2-verify.sh`**](https://github.com/TinCanTech/easy-tls/blob/master/easytls-cryptv2-verify.sh)<br>
  Requires access to the files created by `easytls`.<br>

* Download [**`easytls-metadata.lib`**](https://github.com/TinCanTech/easy-tls/blob/master/easytls-metadata.lib)<br>
  Required by `easytls-cryptv2-verify.sh` and `easytls-client-connect.sh`.<br>

* Download [**`easytls-conntrac.lib`**](https://github.com/TinCanTech/easy-tls/blob/master/easytls-conntrac.lib)<br>
  Required by `easytls-client-connect.sh` and `easytls-client-disconnect.sh`.<br>

* Download [**`easytls-client-connect.sh`**](https://github.com/TinCanTech/easy-tls/blob/master/easytls-client-connect.sh)<br>
  Requires access to temporary files created by `easytls-cryptv2-verify.sh`. (Client hardware address list)<br>

* Download [**`easytls-client-disconnect.sh`**](https://github.com/TinCanTech/easy-tls/blob/master/easytls-client-disconnect.sh)<br>
  Requires access to temporary files created by `easytls-client-connect.sh`. (conntrac list)<br>

### Getting Started
* **Please use the help:**
  ```
  ./easytls help            - General help
  ./easytls help <command>  - Command help
  ./easytls help options    - Command --options
  ./easytls help abb        - Command abbreviations
  ./easytls help config     - Configuration help
  ```
* **Use inter-active menus:**
  ```
  ./easytls build     - Build keys
  ./easytls inline    - Create Inline files
  ./easytls remove    - Remove Inline files and keys
  ./easytls script    - Configure server side scripts
  ```
  These inter-active menus will take you through all the options for building TLS keys<br>
  and inlining all the required files for a credentials only OpenVPN inline configuration file.<br>

### EasyTLS Usage - Normal X509 mode

First, you must have your EasyRSA-3 PKI fully setup, which includes CA, Server and Client certificates.<br>
* **Initialise:**
  ```
  ./easytls init-tls <hash algorithm>
  ```
  Default hash is SHA256 but Easy-TLS allows for use of SHA1<br>
  Easy-TLS optional use of SHA1 is not considered to be a security risk.<br>
  <br>
  This will also create your CA-Identity file and `ca.id` configuration record.<br>
  <br>
* **Status:**
  ```
  ./easytls status
  ```
* **Check your configuration:**
  ```
  ./easytls config
  ```
  This is a good time to set your `custom.group`.<br>
  You can use the `custom.group` option to save your Custom group, or use<br>
  `--custom-group=XYZ` on the command line for all the commands which need it.<br>
  <br>
* **Build keys and inline files**<br>
  Use the inter-active menus above.

### EasyTLS Usage - No-CA mode

No-CA mode means you do not require Easy-RSA to build your PKI.<br>
* **Initialise:**
  ```
  ./easytls init-tls no-ca
  ```
  You can now create Server and Client Self-signed certificates and keys.<br>
  <br>
* **Use interactive menus:**
  ```
  ./easytls self-sign     - Build self-signed server/client certificates
  ```
  Build your required certificates.<br>
  <br>
  Next, use the previous inter-active menus in the same way as before.<br>

### Howto resolve issues with Invalid .inline files:

  If you receive a message informing you that you have "Revoked certs" or<br>
  "Renewed certs" then simply use './easytls inline-remove <filename-base>'<br>
  This will delete the offending Inline file and keep the EasyTLS index up-to-date.<br>
  Invalid files are caused by x509 certificates which have been revoked.<br>
  The Inline file is of no further value once the certificate has been revoked.<br>


