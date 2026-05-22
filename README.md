# Hestia

Hestia is a private messenger project with a Flutter Android client, a Node.js backend, and a static landing/download site.

The current public product focus is Android. Web, Windows, Linux, macOS, and iOS builds are planned, but they are not public release targets yet.

## Current Public Status

- Android: available now as direct APK downloads from GitHub Release assets.
- Website / landing / download page: available from `Landing_Hestia/`.
- Web app: planned / coming soon.
- Windows, Linux, macOS, iOS: planned / coming soon.

Do not present desktop, iOS, or web app builds as public downloads until those targets are reintroduced and verified.

## Project Structure

- `android/` - Android platform target.
- `lib/` - Flutter application code.
- `assets/` - Flutter assets used by the Android client.
- `web/` - Flutter web entrypoint kept buildable for future web work.
- `Landing_Hestia/` - current public landing and download site.
- `server.js` - Node.js HTTP/WebSocket backend.
- `storage/` - backend storage helpers.
- `docs/` - current Android-first build, release, deployment, and platform notes.
- `scripts/` - Android/web build and GitHub release helper scripts.

Removed platform targets:

- `windows/`
- `linux/`
- `macos/`
- `ios/`

## Android Downloads

The landing page recommends Android ARM64 for most users and starts a direct APK download. It still shows manual ABI choices:

- `arm64-v8a` - recommended for most modern Android phones and tablets.
- `armeabi-v7a` - older 32-bit Android devices.
- `x86_64` - emulators and uncommon Intel or ChromeOS-style Android devices.

APK installation is manual. Android may ask users to allow installation from unknown sources. Users should download APKs only from the official Hestia GitHub Release assets.

## Current Capabilities

- account registration and login
- contact requests and contact management
- one-to-one chats
- local message history on the client
- file attachments
- voice and video calls over WebRTC
- Android incoming call wake-up handling
- Android notifications for calls and messages
- offline delivery queue on the backend
- session management
- localization for multiple languages
- configurable server URL in the client

## Privacy Model

Hestia is designed around a simple and explicit privacy model:

- message content is intended to be encrypted on the client before delivery
- the server is not intended to store plaintext message history
- chat history is kept locally on the client
- trust can be strengthened with key fingerprint verification

Important limitation: the server may still observe operational metadata needed to run the service, such as accounts, delivery state, connection timing, IP addresses, and call signaling details.

See [SECURITY.md](SECURITY.md) for security notes and disclosure policy.

## Local Development

Install Flutter dependencies:

```powershell
flutter pub get
```

Install backend dependencies:

```powershell
npm install
```

Run the backend:

```powershell
npm start
```

Run the Android client:

```powershell
flutter run -d android
```

For Android FCM/high-priority incoming call alerts, place a local `google-services.json` at `android/app/google-services.json` and configure the backend with a Firebase service account. Keep real Firebase config and service-account JSON out of public commits.

## Builds

Debug Android build:

```powershell
flutter build apk --debug
```

Release Android split APKs:

```powershell
flutter build apk --release --split-per-abi
```

Flutter web build check:

```powershell
flutter build web
```

For release packaging and GitHub upload flow, see [docs/release.md](docs/release.md).

## Landing Site

The public landing/download site lives in `Landing_Hestia/`.

It states:

- Android is available now.
- ARM64 is recommended for most Android users.
- ARMv7 and x86_64 APKs are available as manual choices.
- Web, Windows, Linux, macOS, and iOS are coming later.

Landing buttons should point directly to GitHub Release asset URLs in the form `https://github.com/RuslanLit/Hestia/releases/download/<tag>/<apk-name>.apk`.

## Documentation

- [docs/building.md](docs/building.md)
- [docs/release.md](docs/release.md)
- [docs/release-publishing.md](docs/release-publishing.md)
- [docs/platform-install-config.md](docs/platform-install-config.md)
- [docs/ispmanager-single-domain.md](docs/ispmanager-single-domain.md)
- [SECURITY.md](SECURITY.md)
