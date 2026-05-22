# Platform Install and Runtime Configuration

This document records the current Android-first runtime configuration for Hestia.

## Backend

Requirements:

- Node.js 18 or newer.
- `npm install` in the repository.
- A writable backend directory for `hestia.sqlite`, `uploads/`, `queue_blobs/`, and `attachment_blobs/`.

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
- the static landing site from `Landing_Hestia/`

Runtime state is stored in SQLite. Set `DB_FILE` to move the database away from the app root.

## TURN/STUN

Hestia returns built-in public STUN plus optional `TURN_SERVERS` from the backend. TURN is strongly recommended for reliable calls across mobile networks, enterprise Wi-Fi, carrier NAT, and strict firewalls.

Format:

```text
TURN_SERVERS=turn:turn.example.com:3478?transport=udp|turn-user|turn-password,turn:turn.example.com:3478?transport=tcp|turn-user|turn-password,turns:turn.example.com:5349?transport=tcp|turn-user|turn-password
```

## Android FCM

Android screen-off/background incoming calls cannot rely on WebSocket alone. Configure FCM if Android incoming call alerts must work while the app is backgrounded or the screen is off.

Server-side:

1. Create a Firebase project.
2. Add an Android app with the package name from `android/app/build.gradle.kts`.
3. Create a service account JSON for Firebase Cloud Messaging HTTP v1.
4. Set `GOOGLE_APPLICATION_CREDENTIALS`, `FIREBASE_SERVICE_ACCOUNT_JSON`, and optionally `FIREBASE_PROJECT_ID`.

Client-side:

1. Download Firebase `google-services.json` for the Android app.
2. Put it at `android/app/google-services.json` locally.
3. Keep it out of public commits.

Limitations:

- If the user force-stops the app, Android normally blocks background delivery until manual launch.
- Battery optimization and vendor task killers can delay delivery.
- Full-screen intent may require explicit user/system permission on newer Android versions.

## Android Build

```bash
flutter pub get
flutter build apk --debug
flutter build apk --release --split-per-abi
```

## Android Runtime Permissions

- `INTERNET`: backend HTTP/WebSocket and FCM.
- `ACCESS_NETWORK_STATE`: connectivity-aware networking.
- `RECORD_AUDIO`: WebRTC audio calls.
- `CAMERA`: WebRTC video calls.
- `MODIFY_AUDIO_SETTINGS`: speaker/Bluetooth audio routing.
- `BLUETOOTH` / `BLUETOOTH_CONNECT`: headset routing.
- `POST_NOTIFICATIONS`: Android 13+ notifications.
- `USE_FULL_SCREEN_INTENT`: incoming call UI from call notification.
- `VIBRATE`: incoming call alert vibration.
- `WAKE_LOCK`: notification/call wake behavior.

## Planned Platforms

Web, Windows, Linux, macOS, and iOS are planned but are not public release targets in the current repository state. Do not publish download links for those platforms until they are restored, built, and manually verified.

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
