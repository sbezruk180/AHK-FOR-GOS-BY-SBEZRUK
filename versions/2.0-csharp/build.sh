#!/usr/bin/env sh
set -eu
cd "$(dirname "$0")"
dotnet run --project tests/Gos.Tests -c Release
dotnet publish src/Gos.Windows/Gos.Windows.csproj -c Release -r win-x86 --self-contained true -p:PublishSingleFile=true -p:IncludeNativeLibrariesForSelfExtract=true -p:EnableCompressionInSingleFile=true -p:DebugType=None -p:TargetLatestRuntimePatch=true -o out/win-x86
(cd out/win-x86 && sha256sum Gos.exe > SHA256SUMS.txt)
