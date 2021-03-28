@echo OFF
REM Easy-TLS script launcher
REM Automatically set PATH to Easy-RSA program-files
FOR /F "tokens=2*" %%a IN ('REG QUERY "HKEY_LOCAL_MACHINE\SOFTWARE\OpenVPN" /ve') DO set BASE_PATH=%%b
PATH=%BASE_PATH%easy-rsa\bin;%BASE_PATH%bin;%PATH%

REM This MUST CD to your Easy-RSA v3 working application directory
REM Please use 8.3 names without spaces
SET WORK_DIR=/home/tct/git/tct/FULL_TEST
CD %WORK_DIR%

SET LOG=%WORK_DIR%/easytls-cryptv2-verify.log
SET SH_EXIT=9

SET VERB=-v
SET CA_DIR=/home/tct/git/tct/FULL_TEST/pki
SET CUST_GRP=-g=tincantech
SET PID_FILE=-s=%WORK_DIR%/easytls-server.pid
SET TMP_DIR=-t=%WORK_DIR%

ECHO * easytls-cryptv2-verify.bat * > %LOG%
REM Run the script
REM -c|--ca-path can be absolute or relative to WORK_DIR
sh.exe easytls-cryptv2-verify.sh %VERB% -c=%CA_DIR% %CUST_GRP% %TMP_DIR% %PID_FILE% >> %LOG% 2>&1

REM AOK
IF ERRORLEVEL 0 SET SH_EXIT=0
REM X509 certificate revoked
IF ERRORLEVEL 1 SET SH_EXIT=1
REM Disbaled TLS key
IF ERRORLEVEL 2 SET SH_EXIT=2
REM Expired key
IF ERRORLEVEL 3 SET SH_EXIT=3
REM Custom Group mismatch
IF ERRORLEVEL 4 SET SH_EXIT=4
REM CA-ID mismatch
IF ERRORLEVEL 5 SET SH_EXIT=5
REM Not EasyTLS
IF ERRORLEVEL 6 SET SH_EXIT=6
REM other error
IF ERRORLEVEL 9 SET SH_EXIT=9

ECHO SH_EXIT: %SH_EXIT% >> %LOG%
EXIT /B %SH_EXIT%
