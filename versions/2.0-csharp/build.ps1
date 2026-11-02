$ErrorActionPreference = 'Stop'
$project = Join-Path $PSScriptRoot 'src/Gos.Windows/Gos.Windows.csproj'
$output = Join-Path $PSScriptRoot 'out/win-x86'
dotnet publish $project -c Release -r win-x86 --self-contained true -p:PublishSingleFile=true -p:IncludeNativeLibrariesForSelfExtract=true -p:EnableCompressionInSingleFile=true -p:DebugType=None -p:TargetLatestRuntimePatch=true -o $output
if ($LASTEXITCODE) { throw 'dotnet publish failed' }
$exe = Join-Path $output 'Gos.exe'
$hash = (Get-FileHash $exe -Algorithm SHA256).Hash.ToLowerInvariant()
Set-Content -Path (Join-Path $output 'SHA256SUMS.txt') -Value "$hash  Gos.exe" -Encoding utf8
Write-Output "Ready: $exe"
