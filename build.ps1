param([string]$Runtime = "", [string]$Output = "")
$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot
$Python = Get-Command py -ErrorAction SilentlyContinue
$PythonArgs = @("-3")
if (-not $Python) { $Python = Get-Command python -ErrorAction SilentlyContinue; $PythonArgs = @() }
if (-not $Python) { throw "Install Python 3.10+ for building. Running the resulting EXE needs no Python or AutoHotkey." }
$BuildArgs = @("tools/build_exe.py")
if ($Runtime) { $BuildArgs += @("--runtime", $Runtime) }
if ($Output) { $BuildArgs += @("--output", $Output) }
& $Python.Source @PythonArgs @BuildArgs
if ($LASTEXITCODE -ne 0) { throw "Build failed with exit code $LASTEXITCODE" }
