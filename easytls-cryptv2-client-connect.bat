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
REM Acknowledgement:
REM This utility is "written in the style of" and "borrows heavily from" Easy-RSA
REM
REM Easy-TLS is inspired by syzzer
REM See: https://github.com/OpenVPN/openvpn/blob/master/doc/tls-crypt-v2.txt
REM
REM VERBATUM_COPYRIGHT_HEADER_INCLUDE_NEGOTIABLE

REM Easy-TLS script launcher
REM Automatically set PATH to Easy-RSA program-files
FOR /F "tokens=2*" %%a IN ('REG QUERY "HKEY_LOCAL_MACHINE\SOFTWARE\OpenVPN" /ve') DO set BASE_PATH=%%b
PATH=%BASE_PATH%easy-rsa\bin;%BASE_PATH%bin;%PATH%

REM This MUST CD to your Easy-RSA v3 working application directory
REM Please use 8.3 names without spaces
SET WORK_DIR=/home/tct/git/tct/FULL_TEST
CD %WORK_DIR%

SET LOG=%WORK_DIR%/easytls-cryptv2-client-connect.log
SET SH_EXIT=9

SET VERB=-v
SET HWADDR_REQ=-r
SET TMP_DIR=-t=%WORK_DIR%
REM
REM

ECHO * easytls-cryptv2-client-connect.bat * > %LOG%
REM Run the script
REM Work in progress
sh.exe easytls-cryptv2-client-connect.sh %VERB% %HWADDR_REQ% %TMP_DIR% >> %LOG% 2>&1

REM AOK
IF ERRORLEVEL 0 SET SH_EXIT=0
REM pushed hwaddr does not match
IF ERRORLEVEL 1 SET SH_EXIT=1
REM hwaddr required and not pushed
IF ERRORLEVEL 2 SET SH_EXIT=2
REM hwaddr required and not keyed
IF ERRORLEVEL 3 SET SH_EXIT=3
REM X509 certificate incorrect for this TLS-key
IF ERRORLEVEL 4 SET SH_EXIT=4
REM hwaddr verification has not been configured
IF ERRORLEVEL 5 SET SH_EXIT=5
REM Server PID does not match daemon_pid
IF ERRORLEVEL 6 SET SH_EXIT=6
REM missing value to option
IF ERRORLEVEL 7 SET SH_EXIT=7
REM missing X509 client cert serial. (BUG)
IF ERRORLEVEL 8 SET SH_EXIT=8
REM unexpected failure. (BUG)
IF ERRORLEVEL 9 SET SH_EXIT=9
REM other error
IF ERRORLEVEL 10 SET SH_EXIT=10

ECHO SH_EXIT: %SH_EXIT% >> %LOG%
EXIT /B %SH_EXIT%
