@echo off
setlocal
set "AHK_EXE=%~1"
if not defined AHK_EXE set "AHK_EXE=%LOCALAPPDATA%\Programs\AutoHotkey-AHK-FOR-GOS\v1.1.37.02\AutoHotkeyA32.exe"
if not exist "%AHK_EXE%" (
    echo AutoHotkey 1.1.37.02 ANSI x86 not found.
    echo Pass its full path as the first argument.
    exit /b 2
)
"%AHK_EXE%" /CP1251 "%~dp0AHK_FOR_GOS_BY_SBEZRUK.ahk"
exit /b %errorlevel%
