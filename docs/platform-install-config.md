# Platform Install and Runtime Configuration

This document records the platform configuration needed by the current Hestia
client and backend. It is intentionally operational: it does not describe the
chat, encryption, or WebRTC business logic.

## Backend

Requirements:

- Node.js 18 or newer.
- `npm install` in the repository or backend archive directory.
- A writable backend directory for `hestia.sqlite`, `uploads/`, `queue_blobs/`,
  and `attachment_blobs/`.

Start locally:

```bash
cp .env.example .env
npm install
npm start
```

The backend serves:

- HTTP config: `http://127.0.0.1:3000/api/config`
- WebSocket signaling: `ws://127.0.0.1:3000/ws`
- file/blob APIs under the same origin

Runtime state is stored in SQLite. Set `DB_FILE` to move the database away from
the app root; otherwise the backend creates `./hestia.sqlite`. Legacy
`data.json` files are left untouched and are not read by the current backend.
Back up the SQLite database together with its WAL/shm sidecar files when WAL is
enabled by SQLite.

Important environment variables are documented in `.env.example`:

- `PORT`
- `DB_FILE`
- `SERVER_NAME`
- `REGISTRATION_ENABLED`
- `INVITE_ONLY`
- `INVITE_CODES`
- `ADMIN_TOKEN`
- `OFFLINE_TTL_MS`
- `TURN_SERVERS`
- `FIREBASE_PROJECT_ID`
- `GOOGLE_APPLICATION_CREDENTIALS`
- `FIREBASE_SERVICE_ACCOUNT_JSON`

### TURN/STUN

Hestia returns built-in public STUN plus optional `TURN_SERVERS` from the
backend. TURN is strongly recommended for reliable calls across mobile networks,
enterprise Wi-Fi, carrier NAT, and strict firewalls.

Format:

```text
TURN_SERVERS=turn:hestiachat.site:3478?transport=udp|USERNAME|PASSWORD,turn:hestiachat.site:3478?transport=tcp|USERNAME|PASSWORD,turns:hestiachat.site:5349?transport=tcp|USERNAME|PASSWORD
```

`TURN_SERVERS` entries are comma-separated. The backend accepts `stun:`,
`turn:`, and `turns:` URLs. TURN entries must include
`url|username|credential`; invalid entries are ignored with a warning so the
built-in STUN fallback remains available.
Placeholder values such as `your-domain.com`, `user`, and `pass` are ignored
and are not returned to clients.

Minimal coturn checklist:

- Open `3478/udp` and `3478/tcp` for TURN.
- Open `5349/tcp` for `turns:`.
- Open the coturn relay range, commonly `49152-65535/udp`, or the smaller
  `min-port`/`max-port` range configured in coturn.
- Restart the Hestia backend after changing `.env`.
- Verify `GET /api/config` contains both STUN and TURN entries.
- Use `docs/coturn-production-setup.md` for the full Ubuntu/coturn setup and
  Trickle ICE test flow.

### Android Wake-Up Delivery

Android screen-off/background incoming calls cannot rely on WebSocket alone.
Hestia supports Android 8.0+ (API 26+) with one runtime-selected wake-up system:
FCM is preferred when Google Play Services and an FCM token are available, and
the Android foreground-service WebSocket fallback is used when FCM is not
available.

Server-side:

1. Create a Firebase project.
2. Add an Android app with the same package name as `android/app/build.gradle.kts`.
3. Create a service account JSON for Firebase Cloud Messaging HTTP v1.
4. Set either:

```text
GOOGLE_APPLICATION_CREDENTIALS=/absolute/path/to/firebase-service-account.json
```

or:

```text
FIREBASE_SERVICE_ACCOUNT_JSON={"type":"service_account",...}
```

Optionally set `FIREBASE_PROJECT_ID` if the project id is not present in the
service-account JSON.

Client-side:

1. Download Firebase `google-services.json` for the Android app.
2. Put it at `android/app/google-services.json` locally.
3. Keep the file out of public commits. Use
   `android/app/google-services.example.json` as a shape reference only.

Limitations:

- If the user force-stops the app, Android normally blocks background delivery
  until the user launches the app again.
- Battery optimization and vendor task killers can delay push or foreground
  service delivery.
- Full-screen intent may require explicit user/system permission on newer
  Android versions; Hestia requests it and falls back to a high-priority call
  notification.
- Android 13+ requires the `POST_NOTIFICATIONS` runtime permission. Android
  8-12 continue to show app notifications without that runtime permission.

## Android

Build:

```bash
flutter pub get
flutter build apk --debug
flutter build apk --release
```

Runtime permissions and why they exist:

- `INTERNET`: backend HTTP/WebSocket and FCM.
- `ACCESS_NETWORK_STATE`: connectivity-aware networking.
- `RECORD_AUDIO`: WebRTC audio calls.
- `CAMERA`: WebRTC video calls.
- `MODIFY_AUDIO_SETTINGS`: speaker/Bluetooth audio routing.
- `BLUETOOTH`/`BLUETOOTH_CONNECT`: headset routing.
- `POST_NOTIFICATIONS`: Android 13+ local/FCM notifications. Android 8-12 do
  not require this runtime permission.
- `USE_FULL_SCREEN_INTENT`: incoming call UI from call notification.
- `VIBRATE`: incoming call alert vibration.
- `WAKE_LOCK`: notification/call wake behavior.
- `FOREGROUND_SERVICE`/`FOREGROUND_SERVICE_REMOTE_MESSAGING`: Android
  foreground-service WebSocket fallback when FCM is unavailable.
- `RECEIVE_BOOT_COMPLETED`: reserved for restoring the fallback after reboot
  once session restore is active.

Compatibility notes:

- Minimum supported Android version: Android 8.0/API 26.
- Android 13+ requires runtime notification permission.
- Android 8-12 keep normal notification behavior without the Android 13
  notification permission prompt.

QA notes:

- Test one Android 13+ device with Google Play Services and confirm
  `pushMode=fcm`.
- Test one Android 8+ device without Google Play Services and confirm
  `pushMode=foregroundService` plus the persistent background notification.


Build:

```powershell
flutter pub get
```

Packaging:

```powershell
```

Notes:

  Flutter.
- The diagnostic panel is available from the desktop chat-list menu.

## Web

Build:

```bash
flutter build web --release
```

Notes:

- WebRTC camera/microphone permissions are browser prompts.
- Android FCM incoming-call logic is not enabled on web.
- Browser storage and background execution limits still apply.

## iOS, macOS, and Linux

install targets in this project state.

- iOS has camera/microphone usage strings. Production distribution still needs
  Apple signing, bundle id ownership, and provisioning.
- macOS has camera/microphone usage strings and sandbox entitlements for network,
  camera, and audio input.
- Linux uses Flutter desktop packaging; distribution packages require external
  distro tooling.

## Custom Server URL

In the client, open server settings and enter either:

```text
https://your-domain.example
```

or:

```text
wss://your-domain.example/ws
```

The client derives `/api/config` and `/ws` when given an HTTP(S) base URL.

## Diagnostic Mode

Open `Diagnostics` from the chat list:

- Android: bug icon in the top bar.

Turn diagnostic mode on, reproduce the issue, then use `Copy diagnostics`.
The report includes server URL, WebSocket/auth/session state, contact/privacy
state, username-search result, call signaling, WebRTC tracks, ICE state, push
session status, and recent errors. It does not include passwords, auth tokens,
or message plaintext.
