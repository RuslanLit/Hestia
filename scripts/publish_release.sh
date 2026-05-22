#!/usr/bin/env bash
set -euo pipefail

TAG="${1:-}"
if [[ -z "$TAG" ]]; then
  echo "Usage: $0 <tag>"
  echo "Example: $0 v0.6.20"
  exit 64
fi

if ! command -v gh >/dev/null 2>&1; then
  echo "GitHub CLI 'gh' was not found. Install it and run: gh auth login" >&2
  exit 69
fi

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

RELEASE_ID="${TAG#v}"
VERSION="${RELEASE_ID%%_*}"

ASSETS=(
  "releases/hestia-${RELEASE_ID}-android-arm64-v8a.apk"
  "releases/hestia-${RELEASE_ID}-android-armeabi-v7a.apk"
  "releases/hestia-${RELEASE_ID}-android-x86_64.apk"
  "releases/${VERSION}-checksums.txt"
  "releases/latest.json"
)

echo "Publishing Android-first release assets for ${TAG}"

missing=0
for asset in "${ASSETS[@]}"; do
  if [[ ! -f "$asset" ]]; then
    echo "Missing asset: $asset" >&2
    missing=1
  fi
done
if [[ "$missing" -ne 0 ]]; then
  exit 66
fi

NOTES_FILE="RELEASE_NOTES_${RELEASE_ID}.md"
if [[ ! -f "$NOTES_FILE" ]]; then
  echo "Missing release notes: $NOTES_FILE" >&2
  exit 66
fi

if gh release view "$TAG" >/dev/null 2>&1; then
  echo "GitHub release already exists: $TAG"
else
  echo "Creating GitHub release: $TAG"
  gh release create "$TAG" --title "Hestia $TAG" --notes-file "$NOTES_FILE"
fi

echo "Uploading release assets..."
gh release upload "$TAG" "${ASSETS[@]}" --clobber

echo "Done. Release page:"
gh release view "$TAG" --web
