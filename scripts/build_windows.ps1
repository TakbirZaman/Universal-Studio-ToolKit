$ErrorActionPreference = 'Stop'
Set-Location (Join-Path $PSScriptRoot '..')
$env:CI = 'true'
$env:FLUTTER_SUPPRESS_ANALYTICS = 'true'
python scripts/notice_provenance.py
if ($LASTEXITCODE -ne 0) { throw 'Dependency notices failed provenance verification' }
python scripts/generate_windows_icon.py
if ($LASTEXITCODE -ne 0) { throw 'Icon generation failed' }
if (!(Test-Path native/windows-x64/pdfium.dll)) { throw 'Stage the audited Windows PDFium DLL first' }
cargo build --manifest-path rust/Cargo.toml --release --locked
if ($LASTEXITCODE -ne 0) { throw 'Rust build failed' }
flutter pub get --enforce-lockfile
if ($LASTEXITCODE -ne 0) { throw 'Dependency resolution failed' }
flutter build windows --release --no-pub
if ($LASTEXITCODE -ne 0) { throw 'Flutter build failed' }
$bundle = 'build/windows/x64/runner/Release'
Copy-Item rust/target/release/studio_core.dll $bundle
Copy-Item native/windows-x64/pdfium.dll $bundle
Copy-Item LICENSE,README.md $bundle
Copy-Item third_party (Join-Path $bundle 'third_party') -Recurse -Force
if ($env:UST_VISION_LIBRARY -or $env:UST_VISION_BUILD_REPORT) {
    if (!$env:UST_VISION_LIBRARY -or !$env:UST_VISION_BUILD_REPORT) { throw 'Supply both the verified scanner library and build report' }
    python scripts/stage_vision_adapter.py --platform windows-x64 --library "$env:UST_VISION_LIBRARY" --report "$env:UST_VISION_BUILD_REPORT" --library-directory $bundle --notices-directory (Join-Path $bundle 'third_party')
    if ($LASTEXITCODE -ne 0) { throw 'Native scanner staging failed' }
    python scripts/verify_packaged_vision.py --platform windows-x64 --package $bundle
    if ($LASTEXITCODE -ne 0) { throw 'Packaged native scanner verification failed' }
}
Copy-Item docs/LIMITATIONS.md (Join-Path $bundle 'KNOWN-LIMITATIONS.md')
& (Join-Path $PSScriptRoot 'stage_windows_runtime.ps1') -Bundle $bundle
New-Item -ItemType Directory -Path dist -Force | Out-Null
Compress-Archive -Path "$bundle/*" -DestinationPath dist/universal-studio-windows-x64.zip -Force
Write-Output 'Bundle created. Clean-system runtime validation is still required.'
