param(
    [Parameter(Mandatory=$true)][Alias('OutputDirectory')][string]$Output,
    [string]$Runtime = ''
)
$ErrorActionPreference = 'Stop'
$outputPath = [IO.Path]::GetFullPath($Output)
New-Item -ItemType Directory -Force $outputPath | Out-Null
$scratch = Join-Path ([IO.Path]::GetTempPath()) ('gos-usability-visual-' + [guid]::NewGuid().ToString('N'))
python (Join-Path $PSScriptRoot 'build_gui_review_fixture.py') --output $scratch
if ($LASTEXITCODE) { throw 'Visual fixture generation failed' }
$runtimeDescription = 'Explicit runtime override; see phase.log for actual ABI/codepage.'
if (!$Runtime) {
    $hostFolder = Join-Path $scratch 'host'
    $provenanceFile = Join-Path $outputPath 'runtime-provenance.json'
    $Runtime = & python -c 'import sys,json; from pathlib import Path; sys.path.insert(0,sys.argv[1]); from deep_audit import prepare; host,exe,runtime,provenance=prepare(Path(sys.argv[2])); Path(sys.argv[3]).write_text(json.dumps(provenance,indent=2)); print(host)' $PSScriptRoot $hostFolder $provenanceFile
    if ($LASTEXITCODE -or !$Runtime) { throw 'Localized ANSI x86 visual host preparation failed' }
    $Runtime = ([string]$Runtime).Trim()
    $runtimeDescription = 'Pinned ANSI x86 visual test host; test-only activeCodePage=ru-RU manifest; shipping binary unchanged.'
}
$Runtime = (Resolve-Path $Runtime).Path
Add-Type -AssemblyName System.Drawing
Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class GosUsabilityWindow {
    [StructLayout(LayoutKind.Sequential)] public struct Rect { public int Left,Top,Right,Bottom; }
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hwnd, out Rect rect);
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr hwnd, out uint pid);
    [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr hwnd, IntPtr dc, uint flags);
}
'@
$report = Join-Path $outputPath 'visual-report.txt'
$runtimeDescription | Set-Content $report
'Production GUI builders with disposable data; not a game/OBS test.' | Add-Content $report
$process = $null
try {
    $script = Join-Path $scratch 'gui_review.ahk'
    $data = Join-Path $scratch 'data'
    $process = Start-Process $Runtime -ArgumentList @('/ErrorStdOut', ('"' + $script + '"'), '--ui-preview', '--data-dir', ('"' + $data + '"')) -PassThru -RedirectStandardOutput (Join-Path $outputPath 'visual-console.txt') -RedirectStandardError (Join-Path $outputPath 'visual-errors.txt')
    $phaseLog = Join-Path $scratch 'phase.log'
    foreach ($phase in @('profile','automation','blocks')) {
        [IO.File]::WriteAllText((Join-Path $scratch 'phase.txt'), $phase, [Text.UTF8Encoding]::new($false))
        $deadline = [DateTime]::UtcNow.AddSeconds(35)
        $log = ''
        do {
            Start-Sleep -Milliseconds 150
            if (Test-Path $phaseLog) { $log = Get-Content $phaseLog -Raw }
            if ($log -match 'ERROR ') { throw $log }
            $process.Refresh()
            if ($process.HasExited) { throw "Visual process exited: $($process.ExitCode)" }
        } until ($log -match ("PASS " + $phase + "(?:\r?\n|$)") -or [DateTime]::UtcNow -gt $deadline)
        if ($log -notmatch ("PASS " + $phase + "(?:\r?\n|$)")) { throw "Visual phase timeout: $phase" }
        $match = [regex]::Match($log, "WINDOW $phase (0x[0-9a-fA-F]+|[0-9]+)")
        if (!$match.Success) { throw "Missing owned window: $phase" }
        $windowId = $match.Groups[1].Value
        $windowValue = if ($windowId.StartsWith('0x')) { [Convert]::ToInt64($windowId.Substring(2),16) } else { [long]$windowId }
        $window = [IntPtr]::new($windowValue)
        [uint32]$owner = 0
        [GosUsabilityWindow]::GetWindowThreadProcessId($window, [ref]$owner) | Out-Null
        if ($owner -ne $process.Id) { throw 'Refusing to capture a window outside the fixture process' }
        Start-Sleep -Milliseconds 350
        $rect = [GosUsabilityWindow+Rect]::new()
        if (![GosUsabilityWindow]::GetWindowRect($window, [ref]$rect)) { throw "Cannot read bounds: $phase" }
        $bitmap = [Drawing.Bitmap]::new(($rect.Right-$rect.Left), ($rect.Bottom-$rect.Top))
        $graphics = [Drawing.Graphics]::FromImage($bitmap)
        $dc = $graphics.GetHdc()
        try {
            if (![GosUsabilityWindow]::PrintWindow($window,$dc,2)) { throw "PrintWindow failed: $phase" }
        } finally { $graphics.ReleaseHdc($dc); $graphics.Dispose() }
        try { $bitmap.Save((Join-Path $outputPath ($phase+'.png')), [Drawing.Imaging.ImageFormat]::Png) }
        finally { $bitmap.Dispose() }
        "PASS | $phase | $($rect.Right-$rect.Left)x$($rect.Bottom-$rect.Top)" | Add-Content $report
    }
    [IO.File]::WriteAllText((Join-Path $scratch 'phase.txt'), 'exit', [Text.UTF8Encoding]::new($false))
    if (!$process.WaitForExit(10000)) { throw 'Visual fixture did not exit' }
    if ($process.ExitCode) { throw "Visual fixture exit code $($process.ExitCode)" }
    'PASS | owned process exited' | Add-Content $report
} catch {
    ('FAIL | '+$_.Exception.Message) | Add-Content $report
    throw
} finally {
    if ($process) {
        $process.Refresh()
        if (!$process.HasExited) { $process.Kill(); $process.WaitForExit() }
        $process.Dispose()
    }
    $logPath = Join-Path $scratch 'phase.log'
    if (Test-Path $logPath) { Copy-Item $logPath (Join-Path $outputPath 'phase.log') }
}
