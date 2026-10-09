@echo off
setlocal
set "AHK_EXE=%~1"
if not defined AHK_EXE set "AHK_EXE=%LOCALAPPDATA%\Programs\AutoHotkey-AHK-FOR-GOS\v1.1.37.02\AutoHotkeyA32.exe"
if not exist "%AHK_EXE%" (
    echo AutoHotkey 1.1.37.02 ANSI x86 not found.
    exit /b 2
)
set "AUDIT_LIB=%TEMP%\ahk-audit-libraries-%RANDOM%-%RANDOM%.txt"
"%AHK_EXE%" /ErrorStdOut /CP1251 /iLib "%AUDIT_LIB%" "%~dp0..\AHK_FOR_GOS_BY_SBEZRUK.ahk"
if errorlevel 1 exit /b 1
if exist "%AUDIT_LIB%" del "%AUDIT_LIB%"
if exist "%~dp0..\audit_selftest_report.txt" del "%~dp0..\audit_selftest_report.txt"
"%AHK_EXE%" /f /ErrorStdOut /CP1251 "%~dp0..\AHK_FOR_GOS_BY_SBEZRUK.ahk" --audit-selftest
set "AUDIT_EXIT=%errorlevel%"
if not exist "%~dp0..\audit_selftest_report.txt" exit /b 1
echo Regression exit code: %AUDIT_EXIT%
echo Report: %~dp0..\audit_selftest_report.txt
exit /b %AUDIT_EXIT%
