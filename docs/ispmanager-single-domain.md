# Hestia Single-Domain Deployment on ispmanager

This guide is for hosting plans where ispmanager allows only one website and no separate `api` subdomain. The same Node.js app serves the landing site, update manifest, HTTP backend config, file relay API, and WebSocket backend.

## Public URLs

- Landing: `https://hestiachat.site/`
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
  data.json
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
```

If `data.json` does not exist yet, create it with an empty object:

```json
{}
```

The app also creates runtime storage directories for queued/file blobs near `server.js`. Make sure the Node.js user can write to the application directory.

## Prepare Files

1. Upload `server.js` and `package.json` from the backend package.
2. Copy the landing files into `public/`.
3. Copy `latest.json` into `public/releases/latest.json`.
4. Keep release binaries in GitHub Releases. Do not upload APK, EXE, ZIP, DMG, AppImage, DEB, or tar.gz files into git.

The Node.js server also supports `PUBLIC_DIR=/absolute/path/to/public` if your ispmanager layout stores the landing files elsewhere.

## Install Dependencies

Run from the Node.js application directory:

```bash
npm install
```

The required runtime packages are installed from `package.json`, including `ws` and `uuid`.

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
REGISTRATION_ENABLED=true
INVITE_ONLY=false
ADMIN_TOKEN=<GENERATE_A_LONG_RANDOM_TOKEN>
```

If ispmanager provides its own port variable, keep it and let the panel route traffic to the Node.js app.

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
