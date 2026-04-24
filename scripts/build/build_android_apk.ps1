param(
  [switch]$SkipPubGet
)

$ErrorActionPreference = "Stop"
$Root = Resolve-Path (Join-Path $PSScriptRoot "..\..")
Set-Location $Root
. (Join-Path $PSScriptRoot "common.ps1")

$Version = ((Select-String -Path "pubspec.yaml" -Pattern "^version:\s*(.+)$").Matches.Groups[1].Value).Trim()
$SafeVersion = $Version -replace "\+", "_"
$ReleaseDir = Join-Path $Root "releases"
New-Item -ItemType Directory -Force -Path $ReleaseDir | Out-Null

if (-not $SkipPubGet) {
  Invoke-FlutterChecked @("pub", "get")
}

Invoke-FlutterChecked @("build", "apk", "--release", "--no-pub")

$SourceApk = Join-Path $Root "build\app\outputs\flutter-apk\app-release.apk"
if (-not (Test-Path $SourceApk)) {
  throw "Android APK was not found at $SourceApk"
}

$OutputApk = Join-Path $ReleaseDir "hestia-$SafeVersion-android.apk"
Copy-Item -Force $SourceApk $OutputApk
Write-Host "Android APK ready: $OutputApk"
