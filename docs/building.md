# Building Hestia Clients

This guide covers local client builds and release packaging for the existing Flutter app. It does not add signing keys, certificates, provisioning profiles, or secrets to the repository.

Official URLs:

- website: `https://hestiachat.site`
- API config: `https://hestiachat.site/api/config`
- WebSocket: `wss://hestiachat.site/ws`
- update manifest: `https://hestiachat.site/releases/latest.json`

## Platform Audit

- `android/`: present and buildable through Gradle/Flutter. Current package id is `com.example.hestia`; replace it before a public production release if the app needs a final owned id.
- `linux/`: present and configured for a Flutter GTK build named `hestia` with application id `com.example.hestia`. Flutter creates a bundle directory; `.deb` or AppImage packaging needs system tools.
- `macos/`: present and configured for a Flutter desktop app named `hestia.app`. The unsigned DMG script intentionally does not sign or notarize.
- `web/`: present with standard Flutter web assets. `flutter build web --release` produces static files.
- `ios/`: present for development builds, but production distribution is not supported here without Apple Developer Program membership, signing certificates, provisioning profiles, and App Store/TestFlight or enterprise distribution setup.

## Output Layout

- `dist/`: temporary packaging workspace and copied static/bundle outputs.
- `releases/`: final release artifacts ready to upload.

Both directories keep only `.gitkeep` in git. Generated artifacts stay ignored.

## Common Requirements

- Flutter SDK matching the project.
- Dart SDK provided by Flutter.
- `flutter pub get` completed, or let the scripts run it.
- Platform toolchain for the target OS.

## Commands

Run scripts from the repository root with PowerShell 7+:

```powershell
pwsh -File scripts/build/build_android_apk.ps1
pwsh -File scripts/build/build_web.ps1
pwsh -File scripts/build/build_linux.ps1
pwsh -File scripts/build/build_macos_unsigned.ps1
pwsh -File scripts/build/build_backend_archive.ps1
pwsh -File scripts/build/build_landing_archive.ps1
```

Use `-SkipPubGet` when dependencies were already restored:

```powershell
pwsh -File scripts/build/build_web.ps1 -SkipPubGet
```

If a Flutter build hangs before printing build output, stop stale `dart`/`flutter` processes and check that the Flutter SDK cache lock is writable. The scripts fail fast when `bin/cache/lockfile` cannot be opened.

## Android APK

Requirement:

- Android SDK and a working Flutter Android toolchain.
- Android 8.0/API 26 or newer is supported.
- For FCM-capable Android builds, a local `android/app/google-services.json`
  matching the app id. Use `android/app/google-services.example.json` only as a
  shape reference and keep real Firebase config out of public commits.

Command:

```powershell
pwsh -File scripts/build/build_android_apk.ps1
```

Release output:

- `releases/hestia-<version>-android.apk`

The APK can be distributed directly. For store distribution, use app signing and store-specific release requirements outside this repository.

Android release notes:

- Incoming call notifications use an Android call notification channel with high
  importance and full-screen intent fallback behavior.
- The same APK supports FCM and the foreground-service WebSocket fallback. Users
  do not choose a Google/no-Google build.
- Android 13+ requires the `POST_NOTIFICATIONS` runtime permission. Android 8-12
  continue with normal notification behavior and no notification permission
  prompt.
- If FCM is unavailable, the Android foreground-service fallback keeps the
  authenticated WebSocket alive after login.


Requirements:


Command:

```powershell
```

Release output:


Packaging dependency justification:



  `flutter_webrtc` runtime.
- Android FCM/background-call notification code paths are disabled outside
  Android.
- The diagnostics panel is available from the desktop chat-list menu.

## Linux

Requirements:

- Linux host.
- Flutter Linux desktop requirements: Clang, CMake, Ninja, GTK 3 development headers, and standard build tools.
- Optional for `.deb`: `dpkg-deb` from Debian packaging tools.
- Optional for AppImage: `appimagetool`.

Command:

```powershell
pwsh -File scripts/build/build_linux.ps1
```

Release output:

- Always: `releases/hestia-<version>-linux-x64.tar.gz`
- If `dpkg-deb` is available: `releases/hestia-<version>-linux-amd64.deb`
- If `appimagetool` is available: `releases/hestia-<version>-linux-x64.AppImage`

Packaging dependency justification:

- Flutter creates a relocatable Linux bundle, not a distro package. `dpkg-deb` creates Debian/Ubuntu packages; `appimagetool` creates portable AppImage artifacts.

## Web Static Build

Requirement:

- Flutter web support enabled.

Command:

```powershell
pwsh -File scripts/build/build_web.ps1
```

Release output:

- `dist/web/`
- `releases/hestia-<version>-web-static.zip`

Deploy the contents of `dist/web/` or the extracted archive to any static host.

Web runtime notes:

- Browser WebRTC permission prompts control camera/microphone access.
- Android-only FCM incoming-call logic is not active on web.
- Browser storage and background execution limits still apply.

If `build/web/` already exists and you only need to recreate the release zip, use:

```powershell
pwsh -File scripts/build/build_web.ps1 -PackageExistingBuild
```

## Backend Archive

Requirement:

- Node.js available on `PATH`.

Command:

```powershell
pwsh -File scripts/build/build_backend_archive.ps1
```

Release output:

- `releases/hestia-<version>-backend.zip`

The archive includes `server.js`, `package.json`, `package-lock.json`, and `.env.example`. It intentionally excludes local runtime data, uploads, blob queues, `.env`, and secrets.

For backend runtime variables, TURN, FCM, custom server URL, and diagnostic mode
checks, see `docs/platform-install-config.md`.

## Landing Archive

Command:

```powershell
pwsh -File scripts/build/build_landing_archive.ps1
```

Release output:

- `releases/hestia-<version>-landing.zip`

The archive contains the static `Landing_Hestia/` site contents.

## macOS Unsigned DMG

Requirements:

- macOS host.
- Xcode and Flutter macOS desktop support.
- Built-in `hdiutil`.

Command:

```powershell
pwsh -File scripts/build/build_macos_unsigned.ps1
```

Release output:

- `releases/hestia-<version>-macos-unsigned.dmg`

Important limitation:

- This build is unsigned and not notarized. macOS Gatekeeper may block launch or show a warning. Users may need to manually allow the app in System Settings. Do not present this as a trusted notarized production build.

## iOS Limitation

Do not produce iOS production distribution from this repository without Apple Developer Program access.

Supported without Apple Developer Program:

- local development builds on devices/simulators according to Xcode and Flutter limits.

Not supported here:

- App Store distribution
- TestFlight distribution
- enterprise distribution
- signed production `.ipa`

Those require Apple Developer Program membership, a valid team, certificates, provisioning profiles, bundle id ownership, and Apple distribution workflows.

## Future Signing Checklist

If signing is added later, keep these steps manual or in secure CI secrets:

- Android: create a private upload/release keystore, keep it outside git, configure Gradle signing through local properties or CI secrets, then build signed APK/AAB.
- Linux: optionally sign checksums or repository metadata; do not commit private GPG keys.
- macOS: enroll in Apple Developer Program, use Developer ID Application signing, notarize with Apple, staple the notarization ticket, then build a signed DMG.
- iOS: enroll in Apple Developer Program, configure bundle id, signing certificates, provisioning profiles, and TestFlight/App Store distribution in Xcode or CI.
