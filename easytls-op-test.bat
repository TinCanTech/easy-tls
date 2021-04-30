@echo OFF

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

SET PATH=%PATH%;.\
SET HOME=%PATH%
SET ENV=/disable-env
SET EASYTLS_REMOTE_CI=1
SET EASYTLS_WINDOWS=1
SET SHALLOW=1
sh.exe easytls-unit-tests.sh
