$ErrorActionPreference = 'Stop'
# Probe the packaged libraries, never developer test overrides.
foreach ($name in @('UST_CORE_LIBRARY','UST_PDFIUM_LIBRARY','UST_OCR_TESSDATA','UST_VISION_LIBRARY')) {
    Remove-Item "Env:$name" -ErrorAction SilentlyContinue
}
$bundle = (Resolve-Path 'build/windows/x64/runner/Release').Path
$process = Start-Process (Join-Path $bundle 'universal_studio_toolkit.exe') -WorkingDirectory $bundle -PassThru
try {
    Start-Sleep -Seconds 8
    $process.Refresh()
    if ($process.HasExited) { throw "Application exited during startup with code $($process.ExitCode)" }
    if ($process.MainWindowHandle -eq 0) { throw 'Application did not create a top-level window' }
    [pscustomobject]@{ startup_survived_seconds=8; window_created=$true; clean_system_verified=$false; interactive_workflow_verified=$false } | ConvertTo-Json | Set-Content 'dist/windows-startup-smoke.json'
} finally {
    $process.Refresh()
    if (!$process.HasExited) { $process.Kill(); $process.WaitForExit() }
    $process.Dispose()
}
