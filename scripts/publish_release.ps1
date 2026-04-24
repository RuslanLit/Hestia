param(
  [Parameter(Mandatory = $true, Position = 0)]
  [string]$Tag
)

$ErrorActionPreference = "Stop"

$Gh = Get-Command "gh" -ErrorAction SilentlyContinue
if (-not $Gh) {
  throw "GitHub CLI 'gh' was not found. Install it and run: gh auth login"
}

$Root = Resolve-Path (Join-Path $PSScriptRoot "..")
Set-Location $Root

$ReleaseId = $Tag -replace "^v", ""
$Version = ($ReleaseId -split "_")[0]

$Assets = @(
  "releases/hestia-$ReleaseId-android.apk",
  "releases/hestia-$ReleaseId-windows-setup.exe",
  "releases/hestia-$ReleaseId-windows-portable.zip",
  "releases/hestia-$ReleaseId-web-static.zip",
  "releases/hestia-$ReleaseId-backend.zip",
  "releases/hestia-$ReleaseId-landing.zip",
  "releases/$Version-checksums.txt",
  "releases/latest.json"
)

$Missing = @($Assets | Where-Object { -not (Test-Path -LiteralPath $_ -PathType Leaf) })
if ($Missing.Count -gt 0) {
  $Missing | ForEach-Object { Write-Error "Missing asset: $_" }
  throw "Required release assets are missing."
}

$NotesFile = "RELEASE_NOTES_$ReleaseId.md"
if (-not (Test-Path -LiteralPath $NotesFile -PathType Leaf)) {
  throw "Missing release notes: $NotesFile"
}

& $Gh.Source release view $Tag *> $null
if ($LASTEXITCODE -eq 0) {
  Write-Host "GitHub release already exists: $Tag"
} else {
  Write-Host "Creating GitHub release: $Tag"
  & $Gh.Source release create $Tag --title "Hestia $Tag" --notes-file $NotesFile
  if ($LASTEXITCODE -ne 0) {
    throw "gh release create failed with exit code $LASTEXITCODE"
  }
}

Write-Host "Uploading release assets..."
& $Gh.Source release upload $Tag @Assets --clobber
if ($LASTEXITCODE -ne 0) {
  throw "gh release upload failed with exit code $LASTEXITCODE"
}

Write-Host "Done. Release page:"
& $Gh.Source release view $Tag --web
