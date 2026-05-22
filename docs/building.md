# Building Hestia

This guide describes the current Android-first repository state. It does not add signing keys, certificates, provisioning profiles, or secrets.

Official URLs:

- website: `https://hestiachat.site`
- API config: `https://hestiachat.site/api/config`
- WebSocket: `wss://hestiachat.site/ws`
- update manifest: `https://hestiachat.site/releases/latest.json`

## Platform Audit

- `android/`: current public client target.
- `web/`: Flutter web entrypoint kept buildable for future web work.
- `Landing_Hestia/`: current static landing and download site.
- `windows/`, `linux/`, `macos/`, `ios/`: removed from this Android-first repository state.

## Common Requirements

- Flutter SDK matching the project.
- Android SDK and a working Android toolchain.
- Node.js/npm only when working on the backend or deployment server.
- Optional local `android/app/google-services.json` for FCM-capable Android builds.

## Android Debug Build

```powershell
flutter pub get
flutter build apk --debug
```

## Android Release APKs

Build ABI-specific release APKs:

```powershell
flutter build apk --release --split-per-abi
```

or use the helper:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/build/build_android_apk.ps1
```

Release output:

- `releases/hestia-<version>-android-arm64-v8a.apk`
- `releases/hestia-<version>-android-armeabi-v7a.apk`
- `releases/hestia-<version>-android-x86_64.apk`

ABI guidance:

- `arm64-v8a`: recommended for most modern Android phones and tablets.
- `armeabi-v7a`: compatibility build for older 32-bit Android devices.
- `x86_64`: emulator and uncommon Intel or ChromeOS-style Android devices.

Do not remove an ABI unless the target user base has been checked. WebRTC and other native plugins ship native libraries per ABI; split APKs keep native functionality while avoiding one large universal APK.

For internal fallback testing only:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/build/build_android_apk.ps1 -Universal
```

## Flutter Web Check

`web/` is not a public app target yet, but it should remain buildable:

```powershell
flutter build web
```

## Landing Site

The public landing/download site is static and lives in `Landing_Hestia/`. The backend serves it directly from that directory.

Before publishing a release:

1. Update `Landing_Hestia/JS/release-config.js`.
2. Ensure Android ARM64 is the recommended download.
3. Keep ARMv7 and x86_64 visible as manual choices.
4. Keep Web, Windows, Linux, macOS, and iOS marked as coming soon.
5. Use direct GitHub Release asset URLs for each APK:
   `https://github.com/RuslanLit/Hestia/releases/download/<tag>/<apk-name>.apk`.

## App Bundle Option

For store distribution, an Android App Bundle can be built later:

```powershell
flutter build appbundle --release
```

Do not remove direct APK release flow; GitHub downloads still need APK files.
