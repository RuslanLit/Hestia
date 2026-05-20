function Invoke-FlutterChecked {
  param(
    [Parameter(Mandatory = $true)]
    [string[]]$Arguments
  )

  $Flutter = (Get-Command "flutter" -ErrorAction Stop).Source
  $CacheDir = Resolve-Path (Join-Path (Split-Path -Parent $Flutter) "cache")
  $LockFile = Join-Path $CacheDir "lockfile"

  try {
    $Stream = [System.IO.File]::Open($LockFile, [System.IO.FileMode]::OpenOrCreate, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::ReadWrite)
    $Stream.Dispose()
  } catch {
    throw "Flutter SDK cache lock is not writable: $LockFile. Stop stale dart/flutter processes or fix permissions, then retry. Original error: $($_.Exception.Message)"
  }

  & $Flutter @Arguments
  if ($LASTEXITCODE -ne 0) {
    throw "flutter $($Arguments -join ' ') failed with exit code $LASTEXITCODE"
  }
}
