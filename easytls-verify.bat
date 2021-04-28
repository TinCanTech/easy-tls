@echo OFF
REM Easy-TLS script launcher
REM Automatically set PATH to Easy-RSA program-files
FOR /F "tokens=2*" %%a IN ('REG QUERY "HKEY_LOCAL_MACHINE\SOFTWARE\OpenVPN" /ve') DO set BASE_PATH=%%b
PATH=%BASE_PATH%easy-rsa\bin;%BASE_PATH%bin;%PATH%

REM This MUST CD to your Easy-RSA v3 working application directory
REM Please use 8.3 names without spaces
SET WORK_DIR=/home/tct/git/tct/FULL_TEST
CD %WORK_DIR%

SET LOG=%WORK_DIR%/easytls-verify.log
SET SH_EXIT=9

SET DEPTH=%1
SET VERB=-v
SET X509=
SET CA_DIR=/home/tct/git/tct/FULL_TEST/pki
SET PID_FILE=-s=%WORK_DIR%/easytls-server.pid
SET TMP_DIR=-t=%WORK_DIR%

ECHO * easytls-verify.bat * > %LOG%
REM Run the script
REM -c|--ca-path can be absolute or relative to WORK_DIR
sh.exe easytls-verify.sh %VERB% %X509% -c=%CA_DIR% %TMP_DIR% %PID_FILE% %DEPTH% >> %LOG% 2>&1

REM AOK
IF ERRORLEVEL 0 SET SH_EXIT=0
REM X509 certificate unknown
IF ERRORLEVEL 1 SET SH_EXIT=1
REM X509 certificate revoked
IF ERRORLEVEL 2 SET SH_EXIT=2
REM CA PKI dir not defined. (REQUIRED)
IF ERRORLEVEL 3 SET SH_EXIT=3
REM CA cert not found
IF ERRORLEVEL 4 SET SH_EXIT=4
REM index.txt not found
IF ERRORLEVEL 5 SET SH_EXIT=5
REM Server PID file has not been configured
IF ERRORLEVEL 6 SET SH_EXIT=6
REM Server PID does not match daemon_pid
IF ERRORLEVEL 7 SET SH_EXIT=7
REM missing value to option
IF ERRORLEVEL 8 SET SH_EXIT=8
REM other error
IF ERRORLEVEL 9 SET SH_EXIT=9
REM missing X509 client cert serial
IF ERRORLEVEL 11 SET SH_EXIT=11

ECHO SH_EXIT: %SH_EXIT% >> %LOG%
EXIT /B %SH_EXIT%
