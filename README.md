# Hestia

Hestia is a private messenger project built as a Flutter client, a Node.js backend, and a static landing site.

The product is aimed at close conversations: family, trusted friends, and small groups that want a calmer messaging experience with a server they can choose.

## Project Structure

- `lib/` - Flutter client application
- `server.js` - Node.js WebSocket and HTTP backend
- `Landing_Hestia/` - static landing site
- `assets/` - Flutter assets
- `web/`, `android/`, `ios/`, `windows/`, `linux/`, `macos/` - Flutter platform targets

## Supported Platforms

The Flutter client is structured for:

- Android
- iOS
- Web
- Windows
- Linux
- macOS

The landing site is static HTML/CSS/JS and can be hosted on any standard static host.

## Current Product Capabilities

Hestia currently includes:

- account registration and login
- contact requests and contact management
- one-to-one chats
- local message history on the client
- file attachments
- voice and video calls over WebRTC
- offline delivery queue on the backend
- session management
- localization for multiple languages
- light and dark themes
- configurable server URL in the client

## Privacy Model

Hestia is designed around a simple and explicit privacy model:

- message content is intended to be encrypted on the client before delivery
- the server is not intended to store plaintext message history
- chat history is kept locally on the client
- trust can be strengthened with key fingerprint verification

Important limitation:

- the server may still observe operational metadata needed to run the service, such as accounts, delivery state, connection timing, IP addresses, and call signaling details

See [SECURITY.md](SECURITY.md) for the security notes and disclosure policy.

## Requirements

### Client

- Flutter SDK
- Dart SDK
- platform toolchains as needed for your target build

### Backend

- Node.js 18+ recommended
- npm

## Local Development

### 1. Install Flutter dependencies

```powershell
flutter pub get
```

### 2. Install backend dependencies

```powershell
npm install
```

### 3. Run the backend

```powershell
node server.js
```

By default, the current backend code listens on `localhost:3000`.

### 4. Run the Flutter client

Example for web:

```powershell
flutter run -d chrome
```

Example for Windows desktop:

```powershell
flutter run -d windows
```

Example for Android:

```powershell
flutter run -d android
```

## Backend Environment

The repository includes a safe example file: [.env.example](.env.example)

It documents the backend configuration shape without including real secrets.

Note:

- some variables are already consumed by `server.js`
- some are documented for deployment consistency
- production client builds default to the official Hestia API at `https://api.hestiachat.site`
- local backend development still uses `localhost:3000`

## Custom Server URL

The client supports changing the backend URL from inside the app.

Current default:

- official website: `https://hestiachat.site`
- API: `https://api.hestiachat.site`
- WebSocket: `wss://api.hestiachat.site`
- update manifest: `https://hestiachat.site/releases/latest.json`

Client config is handled in [lib/config.dart](lib/config.dart).

You can point the app to another server through the server settings dialog in the client UI. A saved custom server URL is preserved and is not overwritten by the official defaults.

## Flutter Build Examples

Web build:

```powershell
flutter build web
```

Debug APK:

```powershell
flutter build apk --debug
```

Debug Windows build:

```powershell
flutter build windows --debug
```

For production signing, release packaging, and GitHub release flow, see [docs/release.md](docs/release.md).

## Landing Site

The landing site lives in `Landing_Hestia/` and includes:

- product overview
- downloads
- privacy page
- FAQ
- comparison page
- server setup guide

It uses static HTML, CSS, and JS, with a localized rendering layer.

## GitHub Publishing Notes

Before pushing this repository publicly:

- review `.gitignore`
- confirm that no local `data.json`, `.env`, service account files, or signing keys are staged
- keep secrets out of commits and release assets

## Documentation

- [SECURITY.md](SECURITY.md)
- [docs/release.md](docs/release.md)
- [ILLUSTRATION_SYSTEM.md](ILLUSTRATION_SYSTEM.md)
- [DESIGN_SYSTEM.md](DESIGN_SYSTEM.md)
