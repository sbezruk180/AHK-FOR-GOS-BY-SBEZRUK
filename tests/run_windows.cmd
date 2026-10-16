@echo off
setlocal
set "APP_EXE=%~1"
if not defined APP_EXE set "APP_EXE=%~dp0..\release\AHK_FOR_GOS.exe"
if not exist "%APP_EXE%" set "APP_EXE=%~dp0..\dist\AHK_FOR_GOS.exe"
if not exist "%APP_EXE%" (
  echo Build with build.ps1 or download the standalone EXE first.
  exit /b 2
)
for %%I in ("%APP_EXE%") do if /I "%%~nI"=="AutoHotkeyA32" goto source
set "TEST_DATA=%TEMP%\AHK-GOS-audit-%RANDOM%-%RANDOM%"
"%APP_EXE%" --data-dir "%TEST_DATA%" --audit-selftest
set "RC=%ERRORLEVEL%"
if exist "%TEST_DATA%\audit_selftest_report.txt" type "%TEST_DATA%\audit_selftest_report.txt"
echo Report: %TEST_DATA%\audit_selftest_report.txt
exit /b %RC%
:source
"%APP_EXE%" /ErrorStdOut /CP1251 "%~dp0..\AHK_FOR_GOS_BY_SBEZRUK.ahk" --audit-selftest
exit /b %ERRORLEVEL%
