[CmdletBinding()]
param(
    [switch]$NoShortcuts
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$ProjectName = 'AHK FOR GOS BY SBEZRUK'
$RepoOwner = 'sbezruk180'
$RepoName = 'AHK-FOR-GOS-BY-SBEZRUK'
$RepoBranch = 'audit-fixes-obs-search-gui-20261009'
$ProjectZipUrl = "https://github.com/$RepoOwner/$RepoName/archive/refs/heads/$RepoBranch.zip"

$AhkVersion = '1.1.37.02'
$AhkZipUrl = "https://github.com/AutoHotkey/AutoHotkey/releases/download/v$AhkVersion/AutoHotkey_$AhkVersion.zip"
$AhkZipSha256 = '6F3663F7CDD25063C8C8728F5D9B07813CED8780522FD1F124BA539E2854215F'

$InstallDir = Join-Path $env:LOCALAPPDATA 'Programs\AHK-FOR-GOS-BY-SBEZRUK'
$RuntimeDir = Join-Path $env:LOCALAPPDATA "Programs\AutoHotkey-AHK-FOR-GOS\v$AhkVersion"
$MainScript = Join-Path $InstallDir 'AHK_FOR_GOS_BY_SBEZRUK.ahk'
$TempRoot = Join-Path ([IO.Path]::GetTempPath()) ('AHK-FOR-GOS-BY-SBEZRUK-' + [guid]::NewGuid().ToString('N'))

function Write-Step([string]$Text) {
    Write-Host "[$ProjectName] $Text" -ForegroundColor Cyan
}

function Download-File([string]$Url, [string]$OutFile) {
    Write-Step "Скачивание: $Url"
    if ($PSVersionTable.PSVersion.Major -lt 6) {
        Invoke-WebRequest -UseBasicParsing -Uri $Url -OutFile $OutFile
    } else {
        Invoke-WebRequest -Uri $Url -OutFile $OutFile
    }
}

function Ensure-Tls12 {
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    } catch {}
}

function Install-AhkRuntime {
    New-Item -ItemType Directory -Force -Path $RuntimeDir | Out-Null
    $zip = Join-Path $TempRoot 'autohotkey.zip'
    $extract = Join-Path $TempRoot 'autohotkey'

    Download-File $AhkZipUrl $zip
    $actualHash = (Get-FileHash -Algorithm SHA256 -Path $zip).Hash.ToUpperInvariant()
    if ($actualHash -ne $AhkZipSha256) {
        throw "SHA-256 AutoHotkey не совпал. Ожидалось $AhkZipSha256, получено $actualHash."
    }
    Write-Step 'SHA-256 AutoHotkey подтверждён.'

    Expand-Archive -Path $zip -DestinationPath $extract -Force
    $sourceA32 = Get-ChildItem -Path $extract -Filter 'AutoHotkeyA32.exe' -File -Recurse | Select-Object -First 1
    if (-not $sourceA32) {
        throw 'В архиве AutoHotkey не найден AutoHotkeyA32.exe.'
    }

    Copy-Item -Path (Join-Path $extract '*') -Destination $RuntimeDir -Recurse -Force
    $installedA32 = Get-ChildItem -Path $RuntimeDir -Filter 'AutoHotkeyA32.exe' -File -Recurse | Select-Object -First 1
    if (-not $installedA32) {
        throw 'После распаковки не найден AutoHotkeyA32.exe.'
    }

    return $installedA32.FullName
}

function Register-AhkAssociation([string]$AhkExe) {
    Write-Step 'Установка AutoHotkey v1 ANSI 32-bit обработчиком .ahk...'

    $classes = 'HKCU:\Software\Classes'
    $extKey = Join-Path $classes '.ahk'
    $progKey = Join-Path $classes 'AutoHotkeyScript.A32.SBezruk'
    $commandKey = Join-Path $progKey 'shell\open\command'
    $iconKey = Join-Path $progKey 'DefaultIcon'

    New-Item -Path $extKey -Force | Out-Null
    Set-Item -Path $extKey -Value 'AutoHotkeyScript.A32.SBezruk'

    New-Item -Path $progKey -Force | Out-Null
    Set-Item -Path $progKey -Value 'AutoHotkey v1 ANSI 32-bit Script'

    New-Item -Path $commandKey -Force | Out-Null
    Set-Item -Path $commandKey -Value ('"{0}" /CP1251 "%1" %*' -f $AhkExe)

    New-Item -Path $iconKey -Force | Out-Null
    Set-Item -Path $iconKey -Value ('"{0}",1' -f $AhkExe)

    $userChoice = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts\.ahk\UserChoice'
    if (Test-Path $userChoice) {
        try {
            Remove-Item -Path $userChoice -Recurse -Force -ErrorAction Stop
        } catch {
            Write-Warning 'Windows не позволил автоматически изменить защищённый UserChoice для .ahk. Ярлык проекта всё равно всегда использует нужный A32 runtime.'
        }
    }

    try {
        Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class ShellNotify {
    [DllImport("shell32.dll")]
    public static extern void SHChangeNotify(uint eventId, uint flags, IntPtr item1, IntPtr item2);
}
'@ -ErrorAction SilentlyContinue
        [ShellNotify]::SHChangeNotify(0x08000000, 0, [IntPtr]::Zero, [IntPtr]::Zero)
    } catch {}
}

function Install-Project {
    $zip = Join-Path $TempRoot 'project.zip'
    $extract = Join-Path $TempRoot 'project'

    Download-File $ProjectZipUrl $zip
    Expand-Archive -Path $zip -DestinationPath $extract -Force

    $main = Get-ChildItem -Path $extract -Filter 'AHK_FOR_GOS_BY_SBEZRUK.ahk' -File -Recurse | Select-Object -First 1
    if (-not $main) {
        throw 'В архиве GitHub не найден AHK_FOR_GOS_BY_SBEZRUK.ahk.'
    }
    $repoRoot = $main.Directory.FullName

    New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
    Copy-Item -Path (Join-Path $repoRoot '*') -Destination $InstallDir -Recurse -Force

    if (-not (Test-Path $MainScript)) {
        throw 'Основной AHK не появился в каталоге установки.'
    }
}

function Create-Shortcut([string]$Path, [string]$AhkExe) {
    $wsh = New-Object -ComObject WScript.Shell
    $shortcut = $wsh.CreateShortcut($Path)
    $shortcut.TargetPath = $AhkExe
    $shortcut.Arguments = ('/CP1251 "{0}"' -f $MainScript)
    $shortcut.WorkingDirectory = $InstallDir
    $shortcut.Description = 'AHK FOR GOS BY SBEZRUK v1.0'
    $shortcut.IconLocation = "$AhkExe,1"
    $shortcut.Save()
}

function Create-Shortcuts([string]$AhkExe) {
    if ($NoShortcuts) { return }

    $desktop = [Environment]::GetFolderPath('Desktop')
    Create-Shortcut (Join-Path $desktop 'AHK FOR GOS BY SBEZRUK.lnk') $AhkExe

    $startMenu = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\AHK FOR GOS BY SBEZRUK'
    New-Item -ItemType Directory -Force -Path $startMenu | Out-Null
    Create-Shortcut (Join-Path $startMenu 'AHK FOR GOS BY SBEZRUK.lnk') $AhkExe

    $uninstallCmd = Join-Path $InstallDir 'uninstall.cmd'
    if (Test-Path $uninstallCmd) {
        $wsh = New-Object -ComObject WScript.Shell
        $shortcut = $wsh.CreateShortcut((Join-Path $startMenu 'Удалить AHK FOR GOS BY SBEZRUK.lnk'))
        $shortcut.TargetPath = $uninstallCmd
        $shortcut.WorkingDirectory = $InstallDir
        $shortcut.Description = 'Удалить AHK FOR GOS BY SBEZRUK'
        $shortcut.Save()
    }
}

try {
    Ensure-Tls12
    New-Item -ItemType Directory -Force -Path $TempRoot | Out-Null

    Write-Host ''
    Write-Host '====================================================' -ForegroundColor DarkCyan
    Write-Host '        AHK FOR GOS BY SBEZRUK - INSTALLER         ' -ForegroundColor Cyan
    Write-Host '                    VERSION 1.0                    ' -ForegroundColor Cyan
    Write-Host '====================================================' -ForegroundColor DarkCyan
    Write-Host ''

    $ahkExe = Install-AhkRuntime
    Register-AhkAssociation $ahkExe
    Install-Project
    Create-Shortcuts $ahkExe

    Write-Host ''
    Write-Host 'Установка завершена.' -ForegroundColor Green
    Write-Host "Скрипт: $MainScript"
    Write-Host "AutoHotkey A32: $ahkExe"
    Write-Host 'Для обновления достаточно снова запустить install.cmd.'
    Write-Host ''
} catch {
    Write-Host ''
    Write-Host ('Ошибка установки: ' + $_.Exception.Message) -ForegroundColor Red
    Write-Host ''
    exit 1
} finally {
    if (Test-Path $TempRoot) {
        Remove-Item -Path $TempRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}
