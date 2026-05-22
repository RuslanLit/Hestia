param(
  [switch]$SkipPubGet,
  [string]$BaseHref = "/app/"
)

$ErrorActionPreference = "Stop"
$Root = Resolve-Path (Join-Path $PSScriptRoot "..\..")
Set-Location $Root
. (Join-Path $PSScriptRoot "common.ps1")

if (-not $SkipPubGet) {
  Invoke-FlutterChecked @("pub", "get")
}

Invoke-FlutterChecked @("build", "web", "--release", "--no-pub", "--base-href", $BaseHref)
Write-Host "Flutter web build ready: build\web"
