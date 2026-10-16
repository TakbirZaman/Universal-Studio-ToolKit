param([Parameter(Mandatory=$true)][string]$Bundle)
$ErrorActionPreference = 'Stop'
# Only the installed Visual Studio redistributable directory is eligible.
# Never copy system DLLs, debug_nonredist, or arbitrary PATH entries.
$vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio/Installer/vswhere.exe'
$install = & $vswhere -latest -products '*' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
if (!$install) { throw 'A licensed Visual Studio C++ installation is required to stage its redistributable runtime.' }
$version = (Get-Content (Join-Path $install 'VC/Auxiliary/Build/Microsoft.VCRedistVersion.default.txt') -Raw).Trim()
$runtime = Join-Path $install "VC/Redist/MSVC/$version/x64/Microsoft.VC143.CRT"
foreach ($name in @('msvcp140.dll','vcruntime140.dll','vcruntime140_1.dll')) {
    if (!(Test-Path (Join-Path $runtime $name))) { throw "Required redistributable runtime missing: $name" }
}
$records = @()
foreach ($file in Get-ChildItem $runtime -Filter '*.dll' -File) {
    Copy-Item $file.FullName (Join-Path $Bundle $file.Name) -Force
    $hash = (Get-FileHash $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
    $records += [pscustomobject]@{ filename=$file.Name; sha256=$hash; version=$file.VersionInfo.FileVersion }
}
$notice = Join-Path $Bundle 'third_party'
New-Item -ItemType Directory -Path $notice -Force | Out-Null
$records | ConvertTo-Json | Set-Content (Join-Path $notice 'microsoft-runtime-provenance.json')
