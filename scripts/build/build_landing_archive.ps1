param()

$ErrorActionPreference = "Stop"
$Root = Resolve-Path (Join-Path $PSScriptRoot "..\..")
Set-Location $Root

$Version = ((Select-String -Path "pubspec.yaml" -Pattern "^version:\s*(.+)$").Matches.Groups[1].Value).Trim()
$SafeVersion = $Version -replace "\+", "_"
$DistDir = Join-Path $Root "dist"
$ReleaseDir = Join-Path $Root "releases"
$PackageDir = Join-Path $DistDir "landing"
$Archive = Join-Path $ReleaseDir "hestia-$SafeVersion-landing.zip"
$SourceDir = Join-Path $Root "Landing_Hestia"

New-Item -ItemType Directory -Force -Path $DistDir, $ReleaseDir | Out-Null
if (-not (Test-Path (Join-Path $SourceDir "index.html"))) {
  throw "Landing source was not found at $SourceDir"
}
if (Test-Path $PackageDir) {
  Remove-Item -Recurse -Force $PackageDir
}

Copy-Item -Recurse -Force $SourceDir $PackageDir

if (Test-Path $Archive) {
  Remove-Item -Force $Archive
}
Compress-Archive -Path (Join-Path $PackageDir "*") -DestinationPath $Archive

Write-Host "Landing archive ready: $Archive"
