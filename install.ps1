[CmdletBinding()]
param([switch]$NoShortcuts)
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$InstallDir = Join-Path $env:LOCALAPPDATA 'Programs\AHK-FOR-GOS-BY-SBEZRUK'
$AppExe = Join-Path $InstallDir 'AHK_FOR_GOS.exe'
$TempRoot = Join-Path ([IO.Path]::GetTempPath()) ('AHK-FOR-GOS-' + [guid]::NewGuid().ToString('N'))
$ProjectZipUrl = 'https://github.com/sbezruk180/AHK-FOR-GOS-BY-SBEZRUK/archive/refs/heads/audit-fixes-obs-search-gui-20261009.zip'
try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    $ReleaseDir = Join-Path $PSScriptRoot 'release'
    if (-not (Test-Path (Join-Path $ReleaseDir 'AHK_FOR_GOS.exe'))) {
        New-Item -ItemType Directory -Path $TempRoot -Force | Out-Null
        $Zip = Join-Path $TempRoot 'project.zip'
        Invoke-WebRequest -UseBasicParsing -Uri $ProjectZipUrl -OutFile $Zip
        $Extract = Join-Path $TempRoot 'project'
        Expand-Archive -Path $Zip -DestinationPath $Extract
        $Binary = Get-ChildItem $Extract -Recurse -File -Filter 'AHK_FOR_GOS.exe' | Where-Object { $_.Directory.Name -eq 'release' } | Select-Object -First 1
        if (-not $Binary) { throw 'В архиве нет release\AHK_FOR_GOS.exe.' }
        $ReleaseDir = $Binary.Directory.FullName
    }
    $BinaryPath = Join-Path $ReleaseDir 'AHK_FOR_GOS.exe'
    $HashFile = Join-Path $ReleaseDir 'AHK_FOR_GOS.sha256'
    $Expected = ((Get-Content -LiteralPath $HashFile -Raw).Trim() -split '\s+')[0]
    if ($Expected -notmatch '^[0-9a-fA-F]{64}$' -or (Get-FileHash $BinaryPath -Algorithm SHA256).Hash -ne $Expected) {
        throw 'Контрольная сумма EXE не совпадает с файлом релиза.'
    }
    $Running = Get-Process -Name 'AHK_FOR_GOS' -ErrorAction SilentlyContinue | Where-Object { $_.Path -eq $AppExe }
    if ($Running) { throw 'Закрой запущенный AHK FOR GOS перед обновлением.' }
    New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
    Copy-Item -LiteralPath $BinaryPath -Destination $AppExe -Force
    foreach ($Name in @('AHK_FOR_GOS.sha256','AHK_FOR_GOS.build.json')) {
        if (Test-Path (Join-Path $ReleaseDir $Name)) { Copy-Item (Join-Path $ReleaseDir $Name) $InstallDir -Force }
    }
    $SourceRoot = Split-Path $ReleaseDir -Parent
    foreach ($Name in @('uninstall.cmd','uninstall.ps1')) {
        if (Test-Path (Join-Path $SourceRoot $Name)) { Copy-Item (Join-Path $SourceRoot $Name) $InstallDir -Force }
    }
    if (-not $NoShortcuts) {
        $Wsh = New-Object -ComObject WScript.Shell
        $StartMenu = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\AHK FOR GOS BY SBEZRUK'
        New-Item -ItemType Directory -Path $StartMenu -Force | Out-Null
        foreach ($Folder in @([Environment]::GetFolderPath('Desktop'), $StartMenu)) {
            $Link = $Wsh.CreateShortcut((Join-Path $Folder 'AHK FOR GOS BY SBEZRUK.lnk'))
            $Link.TargetPath = $AppExe
            $Link.WorkingDirectory = $InstallDir
            $Link.Description = 'AHK FOR GOS — самостоятельное приложение'
            $Link.IconLocation = "$AppExe,0"
            $Link.Save()
        }
    }
    Write-Host "Установлено: $AppExe" -ForegroundColor Green
    Write-Host 'Установка AutoHotkey не требуется. Ассоциации .ahk не изменялись.'
    Write-Host 'Существующие INI сохранены; новые данные хранятся в %APPDATA%\AHK FOR GOS.'
} catch {
    Write-Error $_.Exception.Message
    exit 1
} finally {
    if (Test-Path $TempRoot) { Remove-Item $TempRoot -Recurse -Force -ErrorAction SilentlyContinue }
}
