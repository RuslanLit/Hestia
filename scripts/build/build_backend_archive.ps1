param()

$ErrorActionPreference = "Stop"
$Root = Resolve-Path (Join-Path $PSScriptRoot "..\..")
Set-Location $Root

$Version = ((Select-String -Path "pubspec.yaml" -Pattern "^version:\s*(.+)$").Matches.Groups[1].Value).Trim()
$SafeVersion = $Version -replace "\+", "_"
$DistDir = Join-Path $Root "dist"
$ReleaseDir = Join-Path $Root "releases"
$PackageDir = Join-Path $DistDir "hestia-backend"
$Archive = Join-Path $ReleaseDir "hestia-$SafeVersion-backend.zip"

New-Item -ItemType Directory -Force -Path $DistDir, $ReleaseDir | Out-Null
if (Test-Path $PackageDir) {
  Remove-Item -Recurse -Force $PackageDir
}
New-Item -ItemType Directory -Force -Path $PackageDir | Out-Null

$RequiredFiles = @("server.js", "package.json", "package-lock.json", ".env.example")
foreach ($File in $RequiredFiles) {
  if (-not (Test-Path (Join-Path $Root $File))) {
    throw "Required backend file is missing: $File"
  }
  Copy-Item -Force (Join-Path $Root $File) (Join-Path $PackageDir $File)
}

node --check (Join-Path $PackageDir "server.js")

if (Test-Path $Archive) {
  Remove-Item -Force $Archive
}
Compress-Archive -Path (Join-Path $PackageDir "*") -DestinationPath $Archive

Write-Host "Backend archive ready: $Archive"
