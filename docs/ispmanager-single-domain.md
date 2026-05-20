# Hestia Single-Domain Deployment on ispmanager

This guide is for hosting plans where ispmanager allows only one website and no separate `api` subdomain. The same Node.js app serves the landing site, update manifest, HTTP backend config, file relay API, and WebSocket backend.

## Public URLs

- Landing: `https://hestiachat.site/`
- Hosted web app: `https://hestiachat.site/app/`
- Downloads page: `https://hestiachat.site/downloads.html`
- Update manifest: `https://hestiachat.site/releases/latest.json`
- Backend config: `https://hestiachat.site/api/config`
- WebSocket backend: `wss://hestiachat.site/ws`

`https://hestiachat.site/config` remains as a backward-compatible alias, but new clients should use `/api/config`.

## Folder Layout

Place the backend app files in the Node.js application directory:

```text
hestia-app/
  server.js
  package.json
  hestia.sqlite
  public/
    index.html
    downloads.html
    privacy.html
    faq.html
    comparison.html
    server-setup.html
    robots.txt
    sitemap.xml
    CSS/
    JS/
    assets/
    logo/
    og/
    releases/
      latest.json
    app/
      index.html
      main.dart.js
      flutter_bootstrap.js
      flutter.js
      flutter_service_worker.js
      manifest.json
      version.json
      assets/
      canvaskit/
      icons/
```

The app creates `hestia.sqlite` automatically on first start. You can move it by
setting `DB_FILE=/absolute/path/to/hestia.sqlite`. Legacy `data.json` files are
not migrated automatically and are no longer used by the current backend.

The app also creates runtime storage directories for queued/file blobs near
`server.js`. Make sure the Node.js user can write to the application directory
or to the directory configured by `DB_FILE`.

## Prepare Files

1. Upload `server.js` and `package.json` from the backend package.
2. Copy the landing files from `Landing_Hestia/` into `public/`.
3. Build Flutter web for the hosted app path:

```bash
flutter build web --release --base-href /app/
```

4. Copy the contents of `build/web/` into `public/app/`.
5. Copy `latest.json` into `public/releases/latest.json`.
6. Keep release binaries in GitHub Releases. Do not upload APK, EXE, ZIP, DMG, AppImage, DEB, or tar.gz files into git.

Do not copy Flutter web `index.html` into `public/index.html`; that would replace
the landing page. The root `public/index.html` belongs to the landing site, and
the Flutter app lives under `public/app/index.html`.

The Node.js server also supports `PUBLIC_DIR=/absolute/path/to/public` if your ispmanager layout stores the landing files elsewhere.

## Install Dependencies

Run from the Node.js application directory:

```bash
npm install
```

The required runtime packages are installed from `package.json`, including `ws`
and `better-sqlite3`.

## Start in ispmanager

1. Open `WWW domains` and choose `hestiachat.site`.
2. Enable Node.js for the site.
3. Set the application root to the folder that contains `server.js`.
4. Set the startup file to `server.js`.
5. Use Node.js 18 or newer.
6. Add environment variables as needed:

```text
PORT=3000
SERVER_NAME=Hestia
DB_FILE=./hestia.sqlite
REGISTRATION_ENABLED=true
INVITE_ONLY=false
ADMIN_TOKEN=<GENERATE_A_LONG_RANDOM_TOKEN>
TURN_SERVERS=turn:turn.example.com:3478?transport=udp|turn-user|turn-password,turn:turn.example.com:3478?transport=tcp|turn-user|turn-password,turns:turn.example.com:5349?transport=tcp|turn-user|turn-password
GOOGLE_APPLICATION_CREDENTIALS=/absolute/path/to/firebase-service-account.json
```

`server.js` loads `.env` automatically through `dotenv`, so values such as
`TURN_SERVERS`, `DB_FILE`, and `ADMIN_TOKEN` can live in the app-root `.env`
file. If ispmanager provides its own port variable, keep it and let the panel
route traffic to the Node.js app.

For PM2 deploys, use the checked-in ecosystem file from the app root:

```bash
pm2 delete hestia || true
pm2 start ecosystem.config.js
pm2 save --force
```

For Android incoming calls while the screen is off or the app is in the
background, configure Firebase Cloud Messaging on the backend. Hestia uses FCM
data messages plus a local Android call notification; WebSocket alone is not a
reliable Android wake mechanism. Keep Firebase service account JSON outside the
web root and outside git.

For restrictive networks, configure `TURN_SERVERS`. Without TURN, direct WebRTC
may work on simple networks but fail or connect media one-way on carrier NAT,
enterprise Wi-Fi, and some routers.

TURN requires a relay such as coturn reachable from both clients. Open
`3478/udp`, `3478/tcp`, `5349/tcp` for TLS TURN, and the coturn relay UDP range
configured by `min-port`/`max-port`. After updating `.env`, restart PM2 and
check that `/api/config` returns `turn:` or `turns:` entries in `iceServers`.

## Verify

Open or check these URLs after the app starts:

```bash
curl -I https://hestiachat.site/
curl -I https://hestiachat.site/downloads.html
curl https://hestiachat.site/releases/latest.json
curl https://hestiachat.site/api/config
```

Then verify WebSocket with a client that supports WSS:

```bash
wscat -c wss://hestiachat.site/ws
```

The old `https://hestiachat.site/config` endpoint may be checked for compatibility, but `/api/config` is the canonical config URL.

## Client Settings

The default Hestia client URL is:

```text
wss://hestiachat.site/ws
```

If a user enters `https://hestiachat.site`, the client derives:

```text
https://hestiachat.site/api/config
wss://hestiachat.site/ws
```

If a user enters `wss://hestiachat.site/ws`, the client uses that WebSocket URL directly.
