$ErrorActionPreference = 'Stop'
Set-Location (Join-Path $PSScriptRoot '..')
$env:CI = 'true'
$env:FLUTTER_SUPPRESS_ANALYTICS = 'true'
cargo build --manifest-path rust/Cargo.toml --release --locked
if ($LASTEXITCODE -ne 0) { throw 'Rust build failed' }
flutter pub get --enforce-lockfile
if ($LASTEXITCODE -ne 0) { throw 'Dependency resolution failed' }
flutter build windows --release --no-pub
if ($LASTEXITCODE -ne 0) { throw 'Flutter build failed' }
$bundle = 'build/windows/x64/runner/Release'
Copy-Item rust/target/release/studio_core.dll $bundle
Copy-Item third_party (Join-Path $bundle 'third_party') -Recurse -Force
Copy-Item docs/LIMITATIONS.md (Join-Path $bundle 'KNOWN-LIMITATIONS.md')
New-Item -ItemType Directory -Path dist -Force | Out-Null
Compress-Archive -Path "$bundle/*" -DestinationPath dist/universal-studio-windows-x64.zip -Force
Write-Output 'Bundle created. Clean-system runtime validation is still required.'
