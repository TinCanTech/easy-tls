@echo OFF
rem Automatically set PATH to openssl.exe
FOR /F "tokens=2*" %%a IN ('REG QUERY "HKEY_LOCAL_MACHINE\SOFTWARE\OpenVPN" /ve') DO set BASE_PATH=%%b
PATH=%BASE_PATH%easy-rsa\bin;%BASE_PATH%bin;%PATH%

REM This MUST CD to your Easy-RSA v3 working application directory
REM Please use 8.3 names without spaces
CD C:\progra~1\openvpn\easy-rsa

SET SH_EXIT=0
SET WORK_DIR=%CD%
SET LOG_FILE=%WORK_DIR%\easytls-cryptv2-client-connect.log
ECHO * easytls-cryptv2-client-connect.bat * > %LOG_FILE%
SET >> %LOG_FILE%
REM Run the script
REM Work in progress
sh.exe easytls-cryptv2-client-connect.sh -v -r >> %LOG_FILE% 2>&1
REM HWADDR not allowed
IF ERRORLEVEL 1 SET SH_EXIT=1
REM HWADDR missing or invalid
IF ERRORLEVEL 2 SET SH_EXIT=2
REM X509 cert serial mismatch
IF ERRORLEVEL 3 SET SH_EXIT=3
REM other error
IF ERRORLEVEL 4 SET SH_EXIT=4

ECHO SH_EXIT: %SH_EXIT% >> %LOG_FILE%
EXIT /B %SH_EXIT%
