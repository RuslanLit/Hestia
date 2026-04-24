# Building Hestia Clients

This guide covers local client builds and release packaging for the existing Flutter app. It does not add signing keys, certificates, provisioning profiles, or secrets to the repository.

Official URLs:

- website: `https://hestiachat.site`
- API: `https://api.hestiachat.site`
- WebSocket: `wss://api.hestiachat.site`
- update manifest: `https://hestiachat.site/releases/latest.json`

## Platform Audit

- `android/`: present and buildable through Gradle/Flutter. Current package id is `com.example.hestia`; replace it before a public production release if the app needs a final owned id.
- `windows/`: present and configured for a Flutter desktop build named `hestia.exe`. Flutter creates a release runner directory; an installer needs an external packager.
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
- Run platform desktop packaging on the matching OS: Windows on Windows, Linux on Linux, macOS/iOS on macOS.
- The build process must be able to write to the Flutter SDK cache directory, for example `C:\flutter\bin\cache` on Windows.

## Commands

Run scripts from the repository root with PowerShell 7+:

```powershell
pwsh -File scripts/build/build_android_apk.ps1
pwsh -File scripts/build/build_web.ps1
pwsh -File scripts/build/build_windows.ps1
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

Command:

```powershell
pwsh -File scripts/build/build_android_apk.ps1
```

Release output:

- `releases/hestia-<version>-android.apk`

The APK can be distributed directly. For store distribution, use app signing and store-specific release requirements outside this repository.

## Windows

Requirements:

- Windows host.
- Visual Studio with the C++ desktop workload.
- Visual Studio C++ ATL/MFC headers for the installed MSVC toolset. Current Windows plugins include headers such as `atlbase.h` and `atlstr.h`.
- Optional: Inno Setup 6 for a `.exe` installer.

Command:

```powershell
pwsh -File scripts/build/build_windows.ps1
```

Release output:

- Always: `releases/hestia-<version>-windows-portable.zip`
- If Inno Setup 6 is installed: `releases/hestia-<version>-windows-setup.exe`

Packaging dependency justification:

- Flutter only produces the Windows runner directory. A real installer requires a packaging tool. The script supports Inno Setup because it is a standard Windows installer builder and does not require adding signing material or new Flutter dependencies to the project.

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
- Windows: obtain a code-signing certificate, sign `hestia.exe` and the installer with `signtool`, timestamp signatures, and keep certificates outside git.
- Linux: optionally sign checksums or repository metadata; do not commit private GPG keys.
- macOS: enroll in Apple Developer Program, use Developer ID Application signing, notarize with Apple, staple the notarization ticket, then build a signed DMG.
- iOS: enroll in Apple Developer Program, configure bundle id, signing certificates, provisioning profiles, and TestFlight/App Store distribution in Xcode or CI.
