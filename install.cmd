@echo off
setlocal
chcp 65001 >nul
set "LOCAL_PS=%~dp0install.ps1"
set "TEMP_PS=%TEMP%\AHK-FOR-GOS-BY-SBEZRUK-install.ps1"

if exist "%LOCAL_PS%" goto run_local

echo [AHK FOR GOS BY SBEZRUK] install.ps1 not found next to install.cmd. Downloading from GitHub...
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$ProgressPreference='SilentlyContinue'; [Net.ServicePointManager]::SecurityProtocol=[Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -UseBasicParsing 'https://raw.githubusercontent.com/sbezruk180/AHK-FOR-GOS-BY-SBEZRUK/audit-fixes-obs-search-gui-20261009/install.ps1' -OutFile '%TEMP_PS%'"
if errorlevel 1 exit /b 1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%TEMP_PS%"
set "RC=%ERRORLEVEL%"
del /q "%TEMP_PS%" >nul 2>&1
goto finish

:run_local
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%LOCAL_PS%"
set "RC=%ERRORLEVEL%"

:finish
if not "%RC%"=="0" (
  echo.
  echo Installation failed. Error code: %RC%
  pause
)
exit /b %RC%
