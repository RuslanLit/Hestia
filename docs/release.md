# Release Process

This document describes a practical release flow for Hestia without changing application logic.

## 1. Prepare the Version

Update versions in the relevant files:

- `pubspec.yaml`
- `package.json`
- landing release metadata if used for download pages

Suggested versioning:

- client and repo release tag: `vX.Y.Z`
- backend package version aligned where practical

## 2. Pre-Release Checklist

Before creating a release:

1. Run static checks.
2. Build the client targets you plan to publish.
3. Confirm no secrets or local data files are staged.
4. Confirm release links and landing metadata are correct.

Recommended commands:

```powershell
flutter pub get
flutter analyze
flutter build web
flutter build apk --debug
flutter build apk --release --split-per-abi
node --check server.js
```

## 3. Release Assets

Typical assets to publish:

- Android split APKs:
  - `hestia-<version>-android-arm64-v8a.apk`
  - `hestia-<version>-android-armeabi-v7a.apk`
  - `hestia-<version>-android-x86_64.apk`
- checksum file
- `latest.json` update manifest

For GitHub direct downloads, recommend `arm64-v8a` to most users, keep
`armeabi-v7a` for older 32-bit Android devices, and keep `x86_64` for emulator
or uncommon Intel/ChromeOS-style Android devices. A universal APK is useful as
an internal fallback, but it is much larger because it contains native libraries
for every ABI in one file.

The landing page should link directly to APK assets, not to the GitHub Release
page:

```text
https://github.com/RuslanLit/Hestia/releases/download/<tag>/hestia-<version>-android-arm64-v8a.apk
https://github.com/RuslanLit/Hestia/releases/download/<tag>/hestia-<version>-android-armeabi-v7a.apk
https://github.com/RuslanLit/Hestia/releases/download/<tag>/hestia-<version>-android-x86_64.apk
```

An Android App Bundle can be added for store distribution after signing is
configured, but it should not replace direct APK assets on GitHub.

Web, Windows, Linux, macOS, and iOS are planned but are not current public
release assets.

Do not publish:

- `.env`
- service account JSON
- signing keys
- local `data.json`
- local blob directories

## 4. Git Tagging

Suggested flow:

```powershell
git tag vX.Y.Z
git push origin vX.Y.Z
```

## 5. GitHub Release

For a GitHub release:

1. Create a new release from tag `vX.Y.Z`
2. Add release notes
3. Upload release assets
4. Verify download links used by the landing page
5. Verify `https://hestiachat.site/releases/latest.json`

Suggested release note sections:

- Added
- Changed
- Fixed
- Security
- Upgrade notes

## 6. Landing / Download Page Update

If release assets change:

1. update release metadata used by the landing site
2. verify platform download URLs
3. verify release notes URL
4. keep developer-only assets such as checksums off the public download UI
5. verify the update manifest at `https://hestiachat.site/releases/latest.json`

## 7. Manual Validation

Before announcing a release, manually verify:

- login and registration
- message sending
- offline delivery
- file attachment flow
- call setup
- localization
- landing downloads

## 8. Secret Hygiene

Before any public release:

- rotate test secrets if they were ever used locally
- confirm `.gitignore` is working
- inspect staged files with `git status`
- inspect tracked files with `git ls-files`

## 9. Recommended Future Improvements

Useful follow-up improvements for a production-grade release process:

- CI checks for Flutter analyze and backend syntax
- signed release builds
- checksum generation
- automated release notes
- reproducible backend deployment guide
