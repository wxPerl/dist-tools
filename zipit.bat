@echo off

set DIR=c:\Developement\wxWindows\main\wxWindows-2.4
set RET=c:\Developement\wxPerl\dist
set ZIPFILE=c:\Developement\wxPerl\data\wxWindows-2.3.4-snap.zip

cd %DIR%

rem zip -9r %ZIPFILE% art contrib lib include\wx src\common src\generic src\msw src\html src\jpeg src\tiff src\zlib src\png src\regex src\gtk src\unix src\mak* src\*.in config* *.in install* *.m4 misc/*afm*

find ( -name 'CVS' -prune ) -o -type f -print | zip -9r %ZIPFILE% -@ -

cd %RET%

rem find \( -name 'CVS' -prune \) -o -type f -print | zip /devel/wxPerl/data/wxWindows-2.3.4-snap.zip -@ -