param(
  [switch]$SkipPubGet
)

$ErrorActionPreference = "Stop"
$Root = Resolve-Path (Join-Path $PSScriptRoot "..\..")
Set-Location $Root
. (Join-Path $PSScriptRoot "common.ps1")

if (-not $IsLinux) {
  throw "Linux packaging must be run on Linux."
}

$Version = ((Select-String -Path "pubspec.yaml" -Pattern "^version:\s*(.+)$").Matches.Groups[1].Value).Trim()
$DebVersion = ($Version -split "\+")[0]
$SafeVersion = $Version -replace "\+", "_"
$DistDir = Join-Path $Root "dist"
$ReleaseDir = Join-Path $Root "releases"
$BundleDir = Join-Path $Root "build\linux\x64\release\bundle"
$TarPath = Join-Path $ReleaseDir "hestia-$SafeVersion-linux-x64.tar.gz"
$DebRoot = Join-Path $DistDir "hestia-deb"
$DebPath = Join-Path $ReleaseDir "hestia-$SafeVersion-linux-amd64.deb"
$AppDir = Join-Path $DistDir "Hestia.AppDir"
$AppImagePath = Join-Path $ReleaseDir "hestia-$SafeVersion-linux-x64.AppImage"

New-Item -ItemType Directory -Force -Path $DistDir, $ReleaseDir | Out-Null

if (-not $SkipPubGet) {
  Invoke-FlutterChecked @("pub", "get")
}

Invoke-FlutterChecked @("build", "linux", "--release", "--no-pub")

if (-not (Test-Path (Join-Path $BundleDir "hestia"))) {
  throw "Linux build output was not found at $BundleDir"
}

if (Test-Path $TarPath) {
  Remove-Item -Force $TarPath
}
tar -czf $TarPath -C $BundleDir .
Write-Host "Linux portable archive ready: $TarPath"

if (Get-Command "dpkg-deb" -ErrorAction SilentlyContinue) {
  if (Test-Path $DebRoot) {
    Remove-Item -Recurse -Force $DebRoot
  }
  New-Item -ItemType Directory -Force -Path `
    (Join-Path $DebRoot "DEBIAN"), `
    (Join-Path $DebRoot "usr\lib\hestia"), `
    (Join-Path $DebRoot "usr\bin"), `
    (Join-Path $DebRoot "usr\share\applications"), `
    (Join-Path $DebRoot "usr\share\icons\hicolor\256x256\apps") | Out-Null

  Copy-Item -Recurse -Force (Join-Path $BundleDir "*") (Join-Path $DebRoot "usr\lib\hestia")
  Copy-Item -Force (Join-Path $Root "assets\logo\logo.png") (Join-Path $DebRoot "usr\share\icons\hicolor\256x256\apps\hestia.png")

  Set-Content -Path (Join-Path $DebRoot "usr\bin\hestia") -Value "#!/bin/sh`nexec /usr/lib/hestia/hestia ""`$@""" -Encoding ASCII
  chmod 755 (Join-Path $DebRoot "usr\bin\hestia")

  Set-Content -Path (Join-Path $DebRoot "usr\share\applications\hestia.desktop") -Value "[Desktop Entry]`nName=Hestia`nExec=hestia`nIcon=hestia`nType=Application`nCategories=Network;Chat;InstantMessaging;" -Encoding UTF8
  Set-Content -Path (Join-Path $DebRoot "DEBIAN\control") -Value "Package: hestia`nVersion: $DebVersion`nSection: net`nPriority: optional`nArchitecture: amd64`nMaintainer: Hestia Project`nDescription: Hestia Flutter messenger client" -Encoding ASCII

  if (Test-Path $DebPath) {
    Remove-Item -Force $DebPath
  }
  dpkg-deb --build $DebRoot $DebPath
  Write-Host "Linux deb package ready: $DebPath"
} else {
  Write-Warning "dpkg-deb was not found. Install dpkg-dev on Debian/Ubuntu-like systems to produce a .deb package."
}

if (Get-Command "appimagetool" -ErrorAction SilentlyContinue) {
  if (Test-Path $AppDir) {
    Remove-Item -Recurse -Force $AppDir
  }
  New-Item -ItemType Directory -Force -Path `
    (Join-Path $AppDir "usr\bin"), `
    (Join-Path $AppDir "usr\share\applications"), `
    (Join-Path $AppDir "usr\share\icons\hicolor\256x256\apps") | Out-Null

  Copy-Item -Recurse -Force (Join-Path $BundleDir "*") (Join-Path $AppDir "usr\bin")
  Copy-Item -Force (Join-Path $Root "assets\logo\logo.png") (Join-Path $AppDir "hestia.png")
  Copy-Item -Force (Join-Path $Root "assets\logo\logo.png") (Join-Path $AppDir "usr\share\icons\hicolor\256x256\apps\hestia.png")
  Set-Content -Path (Join-Path $AppDir "AppRun") -Value "#!/bin/sh`nHERE=`$(dirname `$(readlink -f ""`$0""))`nexec ""`$HERE/usr/bin/hestia"" ""`$@""" -Encoding ASCII
  chmod 755 (Join-Path $AppDir "AppRun")
  Set-Content -Path (Join-Path $AppDir "hestia.desktop") -Value "[Desktop Entry]`nName=Hestia`nExec=hestia`nIcon=hestia`nType=Application`nCategories=Network;Chat;InstantMessaging;" -Encoding UTF8

  appimagetool $AppDir $AppImagePath
  Write-Host "Linux AppImage ready: $AppImagePath"
} else {
  Write-Warning "appimagetool was not found. Install appimagetool to produce an AppImage."
}
