# Hestia

Hestia is a private messenger project built as a Flutter client, a Node.js backend, and a static landing site.

The product is aimed at close conversations: family, trusted friends, and small groups that want a calmer messaging experience with a server they can choose.

## Project Structure

- `lib/` - Flutter client application
- `server.js` - Node.js WebSocket and HTTP backend
- `Landing_Hestia/` - static landing site
- `assets/` - Flutter assets
- `web/`, `android/`, `ios/`, `windows/`, `linux/`, `macos/` - Flutter platform targets

## Platform Status

The current install targets are:

- Android
- Windows

The Flutter project also contains scaffolded targets for:

- Web
- iOS
- Linux
- macOS

Those scaffolded targets are kept build-safe where practical, but Android and
Windows are the primary supported client platforms in the current product state.

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
- SQLite is embedded through the backend dependency set; no separate database
  server is required.

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
npm start
```

By default, the current backend code listens on `localhost:3000`.

Copy [.env.example](.env.example) to `.env` on deployments that need explicit
server configuration. Keep real service-account JSON, admin tokens, signing
keys, and Firebase config files out of public commits.

Backend state is stored in SQLite. The default database file is
`./hestia.sqlite`; override it with `DB_FILE=/absolute/or/relative/path.sqlite`.
Legacy `data.json` files are not migrated automatically and are no longer used
by the current backend.

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

For Android FCM/high-priority incoming call alerts, place your local
`google-services.json` at `android/app/google-services.json` and configure the
backend with a Firebase service account. See
[docs/platform-install-config.md](docs/platform-install-config.md).

## Backend Environment

The repository includes a safe example file: [.env.example](.env.example)

It documents the backend configuration shape without including real secrets.

Note:

- some variables are already consumed by `server.js`
- some are documented for deployment consistency
- production client builds default to the single-domain Hestia deployment at `https://hestiachat.site`
- local backend development still uses `localhost:3000`

## WebRTC TURN Setup

Hestia calls use WebRTC ICE servers from `/api/config` and `/config`. Public
STUN is always included as a fallback, but STUN alone is not enough on many
mobile networks, CGNAT connections, strict NATs, and corporate firewalls. TURN
provides a relay path so calls can still connect when direct peer-to-peer media
cannot.

Run a TURN server such as coturn on a host reachable by both callers. Minimal
`/etc/turnserver.conf` example:

```ini
listening-port=3478
tls-listening-port=5349
realm=your-domain.com
server-name=your-domain.com
fingerprint
lt-cred-mech
user=user:pass
no-multicast-peers
no-cli
```

For TLS on `turns:` also configure coturn certificates, for example
`cert=/path/fullchain.pem` and `pkey=/path/privkey.pem`.

Open these firewall ports on the TURN host:

- `3478/udp` and `3478/tcp` for TURN
- `5349/tcp` for TURN over TLS
- the coturn relay range, commonly `49152-65535/udp`, or the smaller
  `min-port`/`max-port` range you set in coturn

Configure the backend with comma-separated ICE entries. TURN entries use
`url|username|credential`; secrets stay in environment variables and only the
WebRTC TURN credentials needed by clients are returned:

```env
TURN_SERVERS=turn:your-domain.com:3478?transport=udp|user|pass,turn:your-domain.com:3478?transport=tcp|user|pass,turns:your-domain.com:5349?transport=tcp|user|pass
```

After restarting the backend, verify:

```powershell
Invoke-RestMethod https://your-domain.com/api/config | Select-Object -ExpandProperty iceServers
```

The result should contain the built-in Google STUN servers plus your configured
`turn:`/`turns:` entries. Invalid or incomplete `TURN_SERVERS` entries are
ignored with a server warning instead of breaking `/config`.

## Custom Server URL

The client supports changing the backend URL from inside the app.

Current default:

- official website: `https://hestiachat.site`
- API config: `https://hestiachat.site/api/config`
- WebSocket: `wss://hestiachat.site/ws`
- update manifest: `https://hestiachat.site/releases/latest.json`

Client config is handled in [lib/config.dart](lib/config.dart).

You can point the app to another server through the server settings dialog in the client UI. A saved custom server URL is preserved and is not overwritten by the official defaults.

## Android Background Calls and Diagnostics

Android can stop or suspend background WebSocket work when the app is in the
background, the screen is off, battery optimization is active, or the app has
been force-stopped. Hestia therefore uses FCM data push plus a local high
importance call notification for Android incoming calls. A live WebSocket is
still used in the foreground.

Diagnostic mode is available from the chat list. It is off by default and can
copy a report with server URL, WebSocket/auth/session state, contact/privacy
state, username-search result, call signaling, WebRTC tracks, ICE state, push
session status, and recent errors. It does not include passwords, auth tokens,
or message plaintext.

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
- confirm that no local `data.json`, `hestia.sqlite`, `.env`, service account files, or signing keys are staged
- keep secrets out of commits and release assets

## Documentation

- [DEPLOYMENT.md](DEPLOYMENT.md)
- [SECURITY.md](SECURITY.md)
- [docs/platform-install-config.md](docs/platform-install-config.md)
- [docs/building.md](docs/building.md)
- [docs/release.md](docs/release.md)
- [ILLUSTRATION_SYSTEM.md](ILLUSTRATION_SYSTEM.md)
- [DESIGN_SYSTEM.md](DESIGN_SYSTEM.md)
