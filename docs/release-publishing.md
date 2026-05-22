# Publishing Hestia GitHub Releases

Generated release binaries stay out of git. Files under `releases/` are ignored and should be uploaded as GitHub Release assets.

## 1. Authenticate GitHub CLI

```powershell
gh auth login
gh auth status
```

## 2. Build Android Split APKs

```powershell
flutter pub get
flutter analyze
flutter build apk --release --split-per-abi
powershell -ExecutionPolicy Bypass -File scripts/build/build_android_apk.ps1 -SkipPubGet
```

Expected release assets:

```text
releases/hestia-<release-id>-android-arm64-v8a.apk
releases/hestia-<release-id>-android-armeabi-v7a.apk
releases/hestia-<release-id>-android-x86_64.apk
releases/<version>-checksums.txt
releases/latest.json
```

## 3. Upload

```powershell
powershell -ExecutionPolicy Bypass -File scripts/publish_release.ps1 v0.6.20
```

or:

```bash
./scripts/publish_release.sh v0.6.20
```

The publish scripts upload only Android split APKs, checksums, and `latest.json`.
The public landing page should use direct APK asset links rather than sending
users to the technical GitHub Release page.

## 4. Verify

```powershell
gh release view v0.6.20 --web
```

Verify that the landing page points directly to these APK URLs:

```text
https://github.com/RuslanLit/Hestia/releases/download/<tag>/hestia-<version>-android-arm64-v8a.apk
https://github.com/RuslanLit/Hestia/releases/download/<tag>/hestia-<version>-android-armeabi-v7a.apk
https://github.com/RuslanLit/Hestia/releases/download/<tag>/hestia-<version>-android-x86_64.apk
```
