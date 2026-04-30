param(
  [switch]$SkipPubGet,
  [switch]$PackageExistingBuild,
  [string]$BaseHref = "/app/"
)

$ErrorActionPreference = "Stop"
$Root = Resolve-Path (Join-Path $PSScriptRoot "..\..")
Set-Location $Root
. (Join-Path $PSScriptRoot "common.ps1")

$Version = ((Select-String -Path "pubspec.yaml" -Pattern "^version:\s*(.+)$").Matches.Groups[1].Value).Trim()
$SafeVersion = $Version -replace "\+", "_"
$DistDir = Join-Path $Root "dist"
$ReleaseDir = Join-Path $Root "releases"
$StaticDir = Join-Path $DistDir "web"
$Archive = Join-Path $ReleaseDir "hestia-$SafeVersion-web-static.zip"

New-Item -ItemType Directory -Force -Path $DistDir, $ReleaseDir | Out-Null
if (Test-Path $StaticDir) {
  Remove-Item -Recurse -Force $StaticDir
}

if (-not $PackageExistingBuild) {
  if (-not $SkipPubGet) {
    Invoke-FlutterChecked @("pub", "get")
  }

  Invoke-FlutterChecked @("build", "web", "--release", "--no-pub", "--base-href", $BaseHref)
}

if (-not (Test-Path (Join-Path $Root "build\web\index.html"))) {
  throw "Web build output was not found at build\web. Run without -PackageExistingBuild to create it."
}

Copy-Item -Recurse -Force (Join-Path $Root "build\web") $StaticDir

if (Test-Path $Archive) {
  Remove-Item -Force $Archive
}
Compress-Archive -Path (Join-Path $StaticDir "*") -DestinationPath $Archive

Write-Host "Web static build ready: $StaticDir"
Write-Host "Web release archive ready: $Archive"
