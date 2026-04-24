param(
  [switch]$SkipPubGet
)

$ErrorActionPreference = "Stop"
$Root = Resolve-Path (Join-Path $PSScriptRoot "..\..")
Set-Location $Root
. (Join-Path $PSScriptRoot "common.ps1")

if (-not $IsMacOS) {
  throw "macOS packaging must be run on macOS."
}

$Version = ((Select-String -Path "pubspec.yaml" -Pattern "^version:\s*(.+)$").Matches.Groups[1].Value).Trim()
$SafeVersion = $Version -replace "\+", "_"
$ReleaseDir = Join-Path $Root "releases"
$AppPath = Join-Path $Root "build\macos\Build\Products\Release\hestia.app"
$DmgPath = Join-Path $ReleaseDir "hestia-$SafeVersion-macos-unsigned.dmg"

New-Item -ItemType Directory -Force -Path $ReleaseDir | Out-Null

if (-not $SkipPubGet) {
  Invoke-FlutterChecked @("pub", "get")
}

Invoke-FlutterChecked @("build", "macos", "--release", "--no-pub")

if (-not (Test-Path $AppPath)) {
  throw "macOS app bundle was not found at $AppPath"
}

Write-Warning "This DMG is unsigned and not notarized. Gatekeeper may block it or show a warning."
if (Test-Path $DmgPath) {
  Remove-Item -Force $DmgPath
}
hdiutil create -volname "Hestia" -srcfolder $AppPath -ov -format UDZO $DmgPath

Write-Host "Unsigned macOS DMG ready: $DmgPath"
