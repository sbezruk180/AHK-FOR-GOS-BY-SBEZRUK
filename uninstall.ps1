[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$InstallDir = Join-Path $env:LOCALAPPDATA 'Programs\AHK-FOR-GOS-BY-SBEZRUK'
$DesktopShortcut = Join-Path ([Environment]::GetFolderPath('Desktop')) 'AHK FOR GOS BY SBEZRUK.lnk'
$StartMenuDir = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\AHK FOR GOS BY SBEZRUK'

try {
    if (Test-Path $DesktopShortcut) { Remove-Item $DesktopShortcut -Force }
    if (Test-Path $StartMenuDir) { Remove-Item $StartMenuDir -Recurse -Force }

    Set-Location $env:TEMP
    if (Test-Path $InstallDir) { Remove-Item $InstallDir -Recurse -Force }

    Write-Host 'AHK FOR GOS BY SBEZRUK удалён.' -ForegroundColor Green
    Write-Host 'AutoHotkey v1.1.37.02 оставлен установленным намеренно.'
} catch {
    Write-Host ('Ошибка удаления: ' + $_.Exception.Message) -ForegroundColor Red
    exit 1
}
