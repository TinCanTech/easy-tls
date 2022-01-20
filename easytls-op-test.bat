@echo OFF
REM VERBATUM_COPYRIGHT_HEADER_INCLUDE_NEGOTIABLE
REM Easy-TLS -- A Shell-based Easy-RSA extension utility to help manage
REM               * OpenVPN specific TLS keys
REM               * Easy-RSA based x509 security credentials
REM               * Verified 'inline' combined OpenVPN node packages
REM
REM Copyright (C) 2020 Richard Bonhomme (Friday 13th of March 2020)
REM https://github.com/TinCanTech/easy-tls
REM tincantech@protonmail.com
REM All Rights reserved.
REM
REM This code is released under version 2 of the GNU GPL
REM See LICENSE of this project for full licensing details.
REM
REM VERBATUM_COPYRIGHT_HEADER_INCLUDE_NEGOTIABLE

set

mkdir "0 0"
cd "0 0"
copy ..

if %PROCESSOR_ARCHITECTURE% == x86 (
    curl -LO https://github.com/OpenVPN/easy-rsa/releases/download/v3.0.8/EasyRSA-3.0.8-win32.zip
    7z e -aoa EasyRSA-3.0.8-win32.zip
    REM ping -n 10 127.0.0.1
    curl -LO https://github.com/TinCanTech/Prebuilt-Openvpn/raw/master/wovpn/wovpn32b.zip
    7z e -aoa wovpn32b.zip
) ELSE (
    curl -LO https://github.com/OpenVPN/easy-rsa/releases/download/v3.0.8/EasyRSA-3.0.8-win64.zip
    7z e -aoa EasyRSA-3.0.8-win64.zip
    REM ping -n 10 127.0.0.1
    curl -LO https://github.com/TinCanTech/Prebuilt-Openvpn/raw/master/wovpn/wovpn64b.zip
    7z e -aoa wovpn64b.zip
)

curl -LO https://raw.githubusercontent.com/TinCanTech/easyrsa-plus/master/easyrsa3/easyrsa

cd
dir

SET PATH=%PATH%;.\
SET HOME=%PATH%
SET ENV=/disable-env
REM SET EASYTLS_REMOTE_CI=1
SET SHALLOW=1
SET EASYTLS_base_dir=.
SET EASYTLS_tmp_dir=./easytls-unit-tests
SET EASYTLS_ersabin_dir=.
SET EASYTLS_ovpnbin_dir=.

sh.exe easytls-unit-tests.sh

REM AOK
IF ERRORLEVEL 0 SET SH_EXIT=0
REM X509 certificate revoked
IF ERRORLEVEL 1 SET SH_EXIT=1

ECHO * Verified expected errors: 42

ECHO SH_EXIT: %SH_EXIT%
EXIT /B %SH_EXIT%
