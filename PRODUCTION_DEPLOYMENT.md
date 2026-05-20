# HESTIA v4.0.3+4 PRODUCTION DEPLOYMENT CHECKLIST

## BLOCKING ISSUES FIXED вњ“

| Issue | Status | File | Fix |
|-------|--------|------|-----|
| No .env file | вњ“ FIXED | `.env` | Created production template |
| ADMIN_TOKEN empty | вљ  REQUIRES ACTION | `.env` | Must set before production |
| Android App ID | вњ“ FIXED | `android/app/build.gradle.kts` | Changed to `org.hestiachat.messenger` |
| Cleartext traffic enabled | вњ“ FIXED | `android/app/src/main/AndroidManifest.xml` | Disabled, HTTPS-only + network security config |
| Android signing debug-only | вњ“ SCAFFOLD | `android/app/build.gradle.kts` | Added production keystore scaffold |
| Package.json version mismatch | вњ“ FIXED | `package.json` | Updated 3.1.0 в†’ 4.0.3 |
| TURN servers not configured | вљ  REQUIRES ACTION | `.env` | Must configure `TURN_SERVERS` |

---

## BEFORE GOING LIVE - REQUIRED ACTIONS

### 1. ADMIN TOKEN (CRITICAL)
**File:** `.env` (Line 18)

```bash
# DO NOT use this default
ADMIN_TOKEN=hestia-admin-prod-$(date +%s)

# PRODUCTION: Generate random token and replace
# On Linux/macOS:
openssl rand -hex 32

$bytes = New-Object byte[] 32; (New-Object System.Security.Cryptography.RNGCryptoServiceProvider).GetBytes($bytes); ([System.BitConverter]::ToString($bytes) -replace '-','').ToLower()

# Copy output and set:
ADMIN_TOKEN=<your-generated-token>
```

**Why:** Protects admin endpoints (`/admin/*`). Default token is insecure.

---

### 2. FIREBASE PUSH NOTIFICATIONS (CRITICAL)
**File:** `.env` (Lines 52-54)

**Option A: Using Service Account JSON (Recommended)**
```bash
# Get from: Firebase Console в†’ Project Settings в†’ Service Accounts в†’ Generate New Private Key
# This downloads a JSON file.

# Copy entire JSON content to .env (single line):
FIREBASE_SERVICE_ACCOUNT_JSON={"type":"service_account","project_id":"...","private_key":"..."}
```

**Option B: Using File Path**
```bash
# Save downloaded JSON to secure location:
GOOGLE_APPLICATION_CREDENTIALS=/secure/path/to/firebase-service-account.json
chmod 600 /secure/path/to/firebase-service-account.json
```

**Why:** Without Firebase, clients can't receive push notifications for:
- Incoming messages
- Contact requests  
- Incoming calls

**Test after configuration:**
```bash
node server.js
# Watch logs for: "[push] service account loaded" or "[push] service account load failed"
```

---

### 3. TURN SERVERS (CRITICAL FOR CALLS)
**File:** `.env` (Line 51)

```bash
# Format: url|username|credential (comma-separated)
# You need a coturn or equivalent TURN server running

# Example with coturn on turn.example.com:
TURN_SERVERS=turn:turn.example.com:3478?transport=udp|user|pass,turns:turn.example.com:5349?transport=tcp|user|pass

# Or use public TURN (temporary testing only):
# Free public TURN servers exist but shouldn't be relied on for production
```

**Why:** Without TURN, WebRTC calls fail on:
- Mobile networks (CGNAT)
- Strict NAT
- Corporate firewalls
- ~40% of networks

**Setup coturn on Ubuntu/Debian:**
```bash
sudo apt install coturn
sudo systemctl enable coturn

# Edit /etc/turnserver.conf
# Set: realm, user credentials, min/max ports
# Restart: sudo systemctl restart coturn
```

**Test after configuration:**
```bash
# Backend will parse and show in logs:
node server.js
# Look for: "[config] TURN_SERVERS configured: yes"
# And: "[config] ICE servers parsed: 3" (STUN x2 + TURN x1)
```

---

### 4. ANDROID PRODUCTION BUILD
**Files:** 
- `android/app/build.gradle.kts` (Lines 20-50)
- `android/app/src/main/res/xml/network_security_config.xml`

**Step 1: Generate Release Keystore**
```bash
# Generate signing key for Play Store
keytool -genkey -v -keystore ~/hestia-release.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias hestia

# You will be prompted for passwords and info
```

**Step 2: Configure build.gradle.kts**
Edit `android/app/build.gradle.kts` Lines 20-50:
```kotlin
signingConfigs {
    release {
        keyStore = file("/path/to/hestia-release.jks")
        keyStorePassword = "your-keystore-password"
        keyAlias = "hestia"
        keyPassword = "your-key-password"
    }
}

buildTypes {
    release {
        signingConfig = signingConfigs.getByName("release")  // Change from "debug"
    }
}
```

**Step 3: Build Release APK**
```bash
cd c:\Users\Master\Desktop\Hestia_copy
flutter build apk --release
# Output: build/app/outputs/apk/release/app-release.apk
```

**Step 4: Verify Signing**
```bash
jarsigner -verify -verbose build/app/outputs/apk/release/app-release.apk
# Should show: "jar verified"
```

---


**For Public Distribution:**
```bash
# Code signing (optional but recommended):
```


---

## VERIFICATION COMMANDS

### Test Backend Startup
```bash
cd c:\Users\Master\Desktop\Hestia_copy
npm install
node server.js

# Should show (in order):
# [config] .env loaded: yes
# [config] TURN_SERVERS configured: yes (or no, if not set)
# [config] ICE servers parsed: 2 or 3
# [push] service account loaded (if Firebase configured)
# [storage] SQLite database: ./hestia.sqlite
# Server listening on port 3000
```

### Test WebSocket Connection
```bash
# From PowerShell, test connection:
$ws = New-Object System.Net.WebSockets.ClientWebSocket
$ws.ConnectAsync("ws://localhost:3000/ws", [System.Threading.CancellationToken]::None).Wait()
$ws.State  # Should print: Open
```

### Test HTTP API
```bash
Invoke-WebRequest -Uri "http://localhost:3000/api/config" | ConvertTo-Json
# Should return JSON with iceServers, serverName, etc.
```

### Verify Release Files
```bash
# Check all v4.0.3 artifacts exist:
Get-ChildItem -Path c:\Users\Master\Desktop\Hestia_copy\releases\hestia-4.0.3_4*
```

### Validate Checksums
```bash
# Compare released artifacts against checksums:
Get-Content c:\Users\Master\Desktop\Hestia_copy\releases\4.0.3-checksums.txt
```

---

## ENV VARIABLE REFERENCE

### Must-Configure Before Production
| Variable | Example | Purpose |
|----------|---------|---------|
| `ADMIN_TOKEN` | `<random-32-hex>` | Protects `/admin/*` endpoints |
| `TURN_SERVERS` | `turn:example.com:3478\|user\|pass` | WebRTC NAT traversal |
| `FIREBASE_SERVICE_ACCOUNT_JSON` | `{...json...}` | Firebase push notifications |

### Should-Configure for Production
| Variable | Example | Purpose |
|----------|---------|---------|
| `LOG_LEVEL` | `info` or `silent` | Logging verbosity |
| `PORT` | `3000` | Listen port (use reverse proxy for HTTPS) |
| `REGISTRATION_ENABLED` | `true` or `false` | Allow new accounts |
| `INVITE_ONLY` | `true` or `false` | Require invite codes |

### Already Configured (Defaults OK)
```
OFFLINE_TTL_MS=604800000 (7 days)
OFFLINE_QUEUE_RECIPIENT_MAX_MESSAGES=500
OFFLINE_QUEUE_SERVER_MAX_MESSAGES=5000
ATTACHMENT_DOCUMENT_MAX_BYTES=52428800 (50 MB)
ATTACHMENT_IMAGE_MAX_BYTES=26214400 (25 MB)
ATTACHMENT_VIDEO_MAX_BYTES=209715200 (200 MB)
ATTACHMENT_AUDIO_MAX_BYTES=52428800 (50 MB)
```

---

## PRODUCTION DEPLOYMENT STEPS

1. **Create .env** (вњ“ Already created)
   ```bash
   cp .env .env.production  # Backup
   # Edit .env with production values
   ```

2. **Set ADMIN_TOKEN** (вљ  Do this now)
   ```bash
   # Generate and update .env line 18
   ```

3. **Configure Firebase** (вљ  Do this if using push notifications)
   ```bash
   # Add FIREBASE_SERVICE_ACCOUNT_JSON or GOOGLE_APPLICATION_CREDENTIALS
   ```

4. **Configure TURN** (вљ  Do this for reliable calls)
   ```bash
   # Set TURN_SERVERS in .env
   ```

5. **Build Android APK** (Optional: if distributing)
   ```bash
   flutter build apk --release
   ```

6. **Start Backend**
   ```bash
   node server.js
   # Monitor logs for errors
   ```

7. **Verify Connectivity**
   ```bash
   # Test auth, messaging, calls
   ```

8. **Deploy with Reverse Proxy**
   ```bash
   # Nginx/Apache в†’ localhost:3000
   # Enable SSL/HTTPS
   # Set WSS path for WebSocket
   ```

---

## MONITORING & HEALTH CHECKS

### Backend Logs to Watch
```
[config] .env loaded: yes/no              # .env present?
[config] TURN_SERVERS configured: yes/no  # TURN ready?
[push] service account loaded             # Firebase ready?
[storage] SQLite database: ./hestia.sqlite # DB ready?
```

### Common Issues

**Issue: "ADMIN_TOKEN=change-me"**
- **Problem:** Default token not changed
- **Fix:** Generate random token and update .env

**Issue: TURN_SERVERS not working**
- **Check:** `netstat -tulpn | grep 3478` (is TURN running?)
- **Fix:** Configure TURN server IP/port/credentials correctly

**Issue: Firebase push not sending**
- **Check:** `[push] service account load failed` in logs
- **Fix:** Verify FIREBASE_SERVICE_ACCOUNT_JSON or file path

**Issue: WebRTC calls fail**
- **Without TURN:** Works ~60% of time (STUN-only)
- **With TURN:** Works >99% of time

---

## CHECKLIST FOR LAUNCH

```
вђ .env created                                      (вњ“ Done)
вђ ADMIN_TOKEN changed from default                 (вљ  Do This)
вђ Firebase configured (or intentionally skipped)    (вљ  Do This)
вђ TURN configured (or noted for future setup)       (вљ  Do This)
вђ Android applicationId changed                     (вњ“ Done)
вђ Android cleartext disabled                        (вњ“ Done)
вђ Android signing configured                        (вњ“ Scaffold ready)
вђ Version numbers synchronized                      (вњ“ Done)
вђ Backend starts without errors                     (вљ  Test This)
вђ WebSocket connects                                (вљ  Test This)
вђ /api/config responds                              (вљ  Test This)
вђ HTTPS/WSS reverse proxy configured                (вљ  Deploy Step)
```

---

## PRODUCTION HARDENING (Optional)

```bash
# Enable invite-only mode:
INVITE_ONLY=true
INVITE_CODES=code1,code2,code3

# Disable user discovery:
# (Users must know exact username to find)

# Rotate ADMIN_TOKEN periodically:
# (Every 90 days)

# Monitor queue size:
# If OFFLINE_QUEUE_SERVER_MAX_BYTES exceeds 80%:
#   - Consider increasing or archiving old messages
```

---

## FILES CHANGED IN THIS AUDIT

| File | Change | Reason |
|------|--------|--------|
| `.env` | Created | Production config template |
| `android/app/build.gradle.kts` | App ID + signing scaffold | Production safety |
| `android/app/src/main/AndroidManifest.xml` | usesCleartextTraffic=false | HTTPS-only |
| `android/app/src/main/res/xml/network_security_config.xml` | Created | Network security policy |
| `package.json` | Version 3.1.0 в†’ 4.0.3 | Version consistency |

---

**Status: PRODUCTION-READY (with Action Items marked вљ )**

**Next: Complete the вљ  Action Items before launching**
