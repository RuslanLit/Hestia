param(
  [switch]$SkipPubGet,
  [switch]$Universal
)

$ErrorActionPreference = "Stop"
$Root = Resolve-Path (Join-Path $PSScriptRoot "..\..")
Set-Location $Root
. (Join-Path $PSScriptRoot "common.ps1")

$VersionRaw = ((Select-String -Path "pubspec.yaml" -Pattern "^version:\s*(.+)$").Matches.Groups[1].Value).Trim()
$VersionName = ($VersionRaw -split "\+")[0]
$SafeVersion = $VersionName -replace "[^0-9A-Za-z._-]", "_"
$ReleaseDir = Join-Path $Root "releases"
New-Item -ItemType Directory -Force -Path $ReleaseDir | Out-Null

if (-not $SkipPubGet) {
  Invoke-FlutterChecked @("pub", "get")
}

$BuildArgs = @("build", "apk", "--release", "--no-pub")
if (-not $Universal) {
  $BuildArgs += "--split-per-abi"
}

Invoke-FlutterChecked $BuildArgs

if ($Universal) {
  $SourceApk = Join-Path $Root "build\app\outputs\flutter-apk\app-release.apk"
  if (-not (Test-Path $SourceApk)) {
    throw "Android APK was not found at $SourceApk"
  }

  $OutputApk = Join-Path $ReleaseDir "hestia-$SafeVersion-android-universal.apk"
  Copy-Item -Force $SourceApk $OutputApk
  Write-Host "Android universal APK ready: $OutputApk"
  return
}

$AbiOutputs = @(
  @{ Abi = "armeabi-v7a"; Source = "app-armeabi-v7a-release.apk" },
  @{ Abi = "arm64-v8a"; Source = "app-arm64-v8a-release.apk" },
  @{ Abi = "x86_64"; Source = "app-x86_64-release.apk" }
)

foreach ($Output in $AbiOutputs) {
  $SourceApk = Join-Path $Root "build\app\outputs\flutter-apk\$($Output.Source)"
  if (-not (Test-Path $SourceApk)) {
    throw "Android split APK was not found at $SourceApk"
  }

  $OutputApk = Join-Path $ReleaseDir "hestia-$SafeVersion-android-$($Output.Abi).apk"
  Copy-Item -Force $SourceApk $OutputApk
  $SizeMb = [math]::Round((Get-Item $OutputApk).Length / 1MB, 2)
  Write-Host "Android $($Output.Abi) APK ready: $OutputApk ($SizeMb MB)"
}
