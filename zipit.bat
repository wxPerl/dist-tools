@echo off

set DIR=c:\Developement\wxWindows\main\wxWindows-2.4
set RET=c:\Developement\wxPerl\dist-tools
set ZIPFILE=c:\Developement\wxPerl\data\wxWindows-2.4.1b2.zip

cd %DIR%

find ( -name 'CVS' -prune ) -o -type f -print | zip -9r %ZIPFILE% -@ -

cd %RET%
