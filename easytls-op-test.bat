@echo OFF

if %PROCESSOR_ARCHITECTURE% == x86 (
    curl -LO https://github.com/OpenVPN/easy-rsa/releases/download/v3.0.8/EasyRSA-3.0.8-win32.zip
    7z e EasyRSA-3.0.8-win32.zip
) ELSE (
    curl -LO https://github.com/OpenVPN/easy-rsa/releases/download/v3.0.8/EasyRSA-3.0.8-win64.zip
    7z e EasyRSA-3.0.8-win64.zip
    curl -LO https://github.com/TinCanTech/Prebuilt-Openvpn/blob/master/wovpn/wovpn64b.zip
    7z e wovpn64b.zip
)

curl -LO https://raw.githubusercontent.com/TinCanTech/easyrsa-plus/master/easyrsa3/easyrsa

SET SHALLOW=1
sh.exe easytls-unit-tests.sh
