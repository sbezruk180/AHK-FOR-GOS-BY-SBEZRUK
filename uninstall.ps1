[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$InstallDir = Join-Path $env:LOCALAPPDATA 'Programs\AHK-FOR-GOS-BY-SBEZRUK'
$AppExe = Join-Path $InstallDir 'AHK_FOR_GOS.exe'
try {
    if (Get-Process -Name 'AHK_FOR_GOS' -ErrorAction SilentlyContinue | Where-Object { $_.Path -eq $AppExe }) {
        throw 'Закрой AHK FOR GOS перед удалением.'
    }
    $Desktop = Join-Path ([Environment]::GetFolderPath('Desktop')) 'AHK FOR GOS BY SBEZRUK.lnk'
    $StartMenu = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\AHK FOR GOS BY SBEZRUK'
    if (Test-Path $Desktop) { Remove-Item $Desktop -Force }
    if (Test-Path $StartMenu) { Remove-Item $StartMenu -Recurse -Force }
    Set-Location $env:TEMP
    foreach ($Name in @('AHK_FOR_GOS.exe','AHK_FOR_GOS.sha256','AHK_FOR_GOS.build.json')) {
        $Path = Join-Path $InstallDir $Name
        if (Test-Path $Path) { Remove-Item $Path -Force }
    }
    Write-Host 'Приложение удалено. INI, логи и папка %APPDATA%\AHK FOR GOS сохранены.' -ForegroundColor Green
    Write-Host 'Другие установки AutoHotkey и ассоциации файлов не изменялись.'
} catch {
    Write-Error $_.Exception.Message
    exit 1
}
