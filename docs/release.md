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
flutter build windows --debug
node --check server.js
```

## 3. Release Assets

Typical assets to publish:

- Android APK
- web build archive
- Windows build archive
- optional Linux/macOS archives if built
- backend source snapshot or deployment bundle if needed

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
4. verify checksums if you publish them
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
