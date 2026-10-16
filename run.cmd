@echo off
setlocal
if not "%~1"=="" goto legacy
set "APP_EXE=%~dp0release\AHK_FOR_GOS.exe"
if not exist "%APP_EXE%" set "APP_EXE=%~dp0dist\AHK_FOR_GOS.exe"
if not exist "%APP_EXE%" (
  echo Build with build.ps1 or download release\AHK_FOR_GOS.exe.
  exit /b 2
)
start "" "%APP_EXE%"
exit /b 0
:legacy
"%~1" /CP1251 "%~dp0AHK_FOR_GOS_BY_SBEZRUK.ahk"
exit /b %ERRORLEVEL%
