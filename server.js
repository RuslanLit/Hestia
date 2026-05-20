'use strict';

const dotenvResult = require('dotenv').config();
const WebSocket = require('ws');
const fs = require('fs');
const path = require('path');
const http = require('http');
const crypto = require('crypto');
const { createSQLiteStore, normalizeUsernameKey } = require('./storage/sqlite_store');

const uuidv4 = () => crypto.randomUUID();

const LISTEN_TARGET = process.env.PORT || process.env.SOCKET || process.env.LISTEN_SOCKET || '3000';
const PORT = /^\d+$/.test(LISTEN_TARGET) ? Number(LISTEN_TARGET) : LISTEN_TARGET;
const DB_FILE = path.resolve(process.env.DB_FILE || path.join(__dirname, 'hestia.sqlite'));
const PUBLIC_DIR = resolvePublicDir();
const QUEUE_BLOB_DIR = path.join(__dirname, 'queue_blobs');
const ATTACHMENT_BLOB_DIR = path.join(__dirname, 'attachment_blobs');
const OFFLINE_TTL_MS = Number(process.env.OFFLINE_TTL_MS || 7 * 24 * 60 * 60 * 1000);
const MB = 1024 * 1024;
const SAVE_DEBOUNCE_MS = Number(process.env.SAVE_DEBOUNCE_MS || 750);
const SESSION_TOUCH_INTERVAL_MS = Number(
  process.env.SESSION_TOUCH_INTERVAL_MS || 5 * 60 * 1000,
);
const QUEUE_CLEANUP_INTERVAL_MS = Number(
  process.env.QUEUE_CLEANUP_INTERVAL_MS || 5 * 60 * 1000,
);
const PENDING_DELIVERY_TTL_MS = Number(
  process.env.PENDING_DELIVERY_TTL_MS || 10 * 60 * 1000,
);
const WS_HEARTBEAT_INTERVAL_MS = Number(
  process.env.WS_HEARTBEAT_INTERVAL_MS || 30 * 1000,
);
const WS_HEARTBEAT_MAX_MISSES = Number(
  process.env.WS_HEARTBEAT_MAX_MISSES || 0,
);
const PRESENCE_DEBOUNCE_MS = Number(process.env.PRESENCE_DEBOUNCE_MS || 1500);
const LOG_LEVEL = process.env.LOG_LEVEL || 'info';
const QUEUE_BLOB_CHECKSUM = process.env.QUEUE_BLOB_CHECKSUM === 'true';
const FCM_SERVICE_ACCOUNT_JSON = process.env.FIREBASE_SERVICE_ACCOUNT_JSON || '';
const FCM_SERVICE_ACCOUNT_FILE = process.env.GOOGLE_APPLICATION_CREDENTIALS || '';
const FEATURE_FILE_ATTACHMENTS = process.env.FEATURE_FILE_ATTACHMENTS !== 'false';
const FEATURE_VOICE_CALLS = process.env.FEATURE_VOICE_CALLS !== 'false';
const FEATURE_VIDEO_CALLS = process.env.FEATURE_VIDEO_CALLS !== 'false';
const FEATURE_PUSH_NOTIFICATIONS = process.env.FEATURE_PUSH_NOTIFICATIONS === 'true';

function positiveEnvInt(name, fallback) {
  const value = Number(process.env[name] || fallback);
  return Number.isFinite(value) && value > 0 ? value : fallback;
}

const ATTACHMENT_POLICY = {
  document: {
    maxBytes: positiveEnvInt('ATTACHMENT_POLICY_DOCUMENT_MAX_BYTES', 50 * MB),
  },
  archive: {
    maxBytes: positiveEnvInt('ATTACHMENT_POLICY_DOCUMENT_MAX_BYTES', 50 * MB),
  },
  ebook: {
    maxBytes: positiveEnvInt('ATTACHMENT_POLICY_DOCUMENT_MAX_BYTES', 50 * MB),
  },
  image: {
    maxBytes: positiveEnvInt('ATTACHMENT_POLICY_IMAGE_MAX_BYTES', 50 * MB),
  },
  audio: {
    maxBytes: positiveEnvInt('ATTACHMENT_POLICY_AUDIO_MAX_BYTES', 100 * MB),
  },
  video: {
    maxBytes: positiveEnvInt('ATTACHMENT_POLICY_VIDEO_MAX_BYTES', 250 * MB),
  },
};
const ATTACHMENT_BLOCKED_EXTENSIONS = new Set([
  'exe', 'msi', 'apk', 'ipa',
  'bat', 'cmd', 'sh', 'ps1',
  'js', 'vbs', 'jar', 'scr', 'com',
  'dll', 'so', 'dylib',
  'bin', 'deb', 'rpm', 'dmg', 'app',
  'html', 'htm',
  'php', 'py', 'rb', 'pl',
]);
const ATTACHMENT_KIND_EXTENSIONS = {
  image: new Set(['jpg', 'jpeg', 'png', 'webp', 'gif', 'heic', 'heif']),
  audio: new Set(['mp3', 'wav', 'ogg', 'm4a', 'aac', 'flac']),
  video: new Set(['mp4', 'mov', 'webm', 'mkv', 'm4v', 'mts', 'm2ts', 'ts']),
  archive: new Set(['zip', '7z', 'rar', 'tar', 'gz', 'bz2', 'xz']),
  ebook: new Set(['fb2', 'epub', 'mobi', 'azw3', 'djvu', 'djv']),
};

function kindForExtension(extension) {
  const ext = normalizeExtension(extension);
  for (const [kind, extensions] of Object.entries(ATTACHMENT_KIND_EXTENSIONS)) {
    if (extensions.has(ext)) {
      return kind;
    }
  }
  return 'document';
}

function extensionBlocked(extension) {
  return ATTACHMENT_BLOCKED_EXTENSIONS.has(normalizeExtension(extension));
}

function logAttachmentValidation({
  extension,
  mime,
  blocked,
  allowed,
  reason,
  selectedKind = 'document',
  maxBytes = ATTACHMENT_POLICY.document.maxBytes,
}) {
  logDebug(
    `[debug] attachment validation extension=${extension || 'empty'} ` +
    `mime=${mime || 'empty'} isBlocked=${blocked} selectedKind=${selectedKind} ` +
    `maxBytes=${maxBytes} validationResult=${allowed ? 'allowed' : 'rejected'} reason=${reason}`,
  );
}
const HARD_ATTACHMENT_MAX_BYTES = Math.max(
  positiveEnvInt('HARD_ATTACHMENT_MAX_BYTES', 250 * MB),
  ...Object.values(ATTACHMENT_POLICY).map((policy) => policy.maxBytes),
);
const MAX_WS_MESSAGE_BYTES = Number(process.env.MAX_WS_MESSAGE_BYTES || 768 * 1024);
const MAX_TEXT_BYTES = Number(process.env.MAX_TEXT_BYTES || 64 * 1024);
const MAX_CALL_SDP_BYTES = Number(process.env.MAX_CALL_SDP_BYTES || 128 * 1024);
const MAX_CALL_ICE_BYTES = Number(process.env.MAX_CALL_ICE_BYTES || 8 * 1024);
const CALL_OFFER_TTL_MS = Number(process.env.CALL_OFFER_TTL_MS || 45 * 1000);
const MAX_PUBLIC_KEY_BYTES = Number(process.env.MAX_PUBLIC_KEY_BYTES || 256);
const SESSION_MAX_AGE_MS = Number(
  process.env.SESSION_MAX_AGE_MS || 30 * 24 * 60 * 60 * 1000,
);
const SESSION_IDLE_TTL_MS = Number(
  process.env.SESSION_IDLE_TTL_MS || 14 * 24 * 60 * 60 * 1000,
);
const OFFLINE_QUEUE_RECIPIENT_MAX_BYTES = Number(
  process.env.OFFLINE_QUEUE_RECIPIENT_MAX_BYTES || 300 * MB,
);
const OFFLINE_QUEUE_SERVER_MAX_BYTES = Number(
  process.env.OFFLINE_QUEUE_SERVER_MAX_BYTES || 1024 * MB,
);
const OFFLINE_QUEUE_RECIPIENT_MAX_MESSAGES = Number(
  process.env.OFFLINE_QUEUE_RECIPIENT_MAX_MESSAGES || 500,
);
const OFFLINE_QUEUE_SERVER_MAX_MESSAGES = Number(
  process.env.OFFLINE_QUEUE_SERVER_MAX_MESSAGES || 5000,
);
const OFFLINE_QUEUE_RECIPIENT_ATTACHMENT_MAX_BYTES = Number(
  process.env.OFFLINE_QUEUE_RECIPIENT_ATTACHMENT_MAX_BYTES || 300 * MB,
);
const OFFLINE_QUEUE_SERVER_ATTACHMENT_MAX_BYTES = Number(
  process.env.OFFLINE_QUEUE_SERVER_ATTACHMENT_MAX_BYTES || 1024 * MB,
);
const OFFLINE_QUEUE_RECIPIENT_ATTACHMENT_MAX_FILES = Number(
  process.env.OFFLINE_QUEUE_RECIPIENT_ATTACHMENT_MAX_FILES || 20,
);
const OFFLINE_QUEUE_SERVER_ATTACHMENT_MAX_FILES = Number(
  process.env.OFFLINE_QUEUE_SERVER_ATTACHMENT_MAX_FILES || 200,
);
const DOWNLOADED_BLOB_RETENTION_MS = Number(
  process.env.DOWNLOADED_BLOB_RETENTION_MS || 15 * 60 * 1000,
);
const CALL_MEDIA_CONFIG = {
  audio: {
    echoCancellation: true,
    noiseSuppression: true,
    autoGainControl: true,
  },
  video: {
    width: Number(process.env.CALL_VIDEO_WIDTH || 640),
    height: Number(process.env.CALL_VIDEO_HEIGHT || 360),
    frameRate: Number(process.env.CALL_VIDEO_FRAMERATE || 24),
    maxBitrateKbps: Number(process.env.CALL_VIDEO_MAX_BITRATE_KBPS || 800),
  },
  audio: {
    echoCancellation: true,
    noiseSuppression: true,
    autoGainControl: true,
  },
};
const SERVER_NAME = process.env.SERVER_NAME || 'Hestia';
let REGISTRATION_ENABLED = process.env.REGISTRATION_ENABLED !== 'false';
let INVITE_ONLY = process.env.INVITE_ONLY === 'true';
const INVITE_CODES = new Set(
  (process.env.INVITE_CODES || '')
    .split(',')
    .map((item) => item.trim())
    .filter(Boolean),
);
const ADMIN_TOKEN = process.env.ADMIN_TOKEN || '';
const PUBLIC_STUN_SERVERS = [
  { urls: 'stun:stun.l.google.com:19302' },
  { urls: 'stun:stun1.l.google.com:19302' },
];
const TURN_SERVERS_RAW = process.env.TURN_SERVERS || '';
const TURN_PLACEHOLDER_DETECTED = hasPlaceholderTurnConfig(TURN_SERVERS_RAW);
const CONFIGURED_TURN_SERVERS = parseTurnServers(TURN_SERVERS_RAW);
const ICE_SERVERS = [
  ...PUBLIC_STUN_SERVERS,
  ...CONFIGURED_TURN_SERVERS,
];
const CONFIGURED_TURN_SERVER_COUNT = CONFIGURED_TURN_SERVERS.length;
const PUSH_PROVIDERS = new Set(['fcm']);
const LANDING_PAGES = new Set([
  'index.html',
  'downloads.html',
  'privacy.html',
  'faq.html',
  'comparison.html',
  'server-setup.html',
]);
const STATIC_DIRS = new Set([
  'app',
  'assets',
  'content',
  'CSS',
  'JS',
  'logo',
  'og',
  'releases',
  'scripts',
]);
const STATIC_FILES = new Set([
  'robots.txt',
  'sitemap.xml',
  'favicon.ico',
  'favicon.png',
  'manifest.json',
]);
let fcmServiceAccount = null;
let fcmAccessToken = null;
let fcmAccessTokenExpiresAt = 0;

const clients = new Map(); // userId -> Set<ws>
const rateBuckets = new Map();
const failedLoginBuckets = new Map();
const repeatedContactRequests = new Map();
const callCooldowns = new Map();
const pendingCallOffers = new Map();
const pendingDeliveries = new Map(); // messageId -> sender userId
const pushDedup = new Map();
const presenceTimers = new Map();
let saveTimer = null;
let saveQueued = false;
let shuttingDown = false;

function logInfo(message) {
  if (LOG_LEVEL !== 'silent') {
    console.log(message);
  }
}

function logWarn(message) {
  if (LOG_LEVEL !== 'silent') {
    console.warn(message);
  }
}

function logDebug(message) {
  if (LOG_LEVEL !== 'silent') {
    console.log(message);
  }
}

function sanitizedIceServers(iceServers) {
  return iceServers.map((server) => ({
    ...server,
    ...(server.credential ? { credential: '<redacted>' } : {}),
  }));
}

function logStartupConfig() {
  logInfo(`[config] .env loaded: ${dotenvResult.error ? 'no' : 'yes'}`);
  if (dotenvResult.error && dotenvResult.error.code !== 'ENOENT') {
    logWarn(`[config] .env load warning: ${dotenvResult.error.message}`);
  }
  logInfo(`[config] features attachments=${FEATURE_FILE_ATTACHMENTS ? 'on' : 'off'} voiceCalls=${FEATURE_VOICE_CALLS ? 'on' : 'off'} videoCalls=${FEATURE_VIDEO_CALLS ? 'on' : 'off'} push=${FEATURE_PUSH_NOTIFICATIONS ? 'on' : 'off'}`);
  logInfo(`[config] voiceCalls ${FEATURE_VOICE_CALLS ? 'enabled' : 'disabled'}`);
  logInfo(`[config] videoCalls ${FEATURE_VIDEO_CALLS ? 'enabled' : 'disabled'}`);
  logInfo(
    `[config] attachment policy limits ` +
    `document=${ATTACHMENT_POLICY.document.maxBytes} ` +
    `image=${ATTACHMENT_POLICY.image.maxBytes} ` +
    `audio=${ATTACHMENT_POLICY.audio.maxBytes} ` +
    `video=${ATTACHMENT_POLICY.video.maxBytes} ` +
    `hard=${HARD_ATTACHMENT_MAX_BYTES}`,
  );
  logInfo(`[config] TURN_SERVERS env present: ${TURN_SERVERS_RAW ? 'yes' : 'no'}`);
  logInfo(`[config] TURN configured: ${CONFIGURED_TURN_SERVER_COUNT > 0 ? 'yes' : 'no'}`);
  logInfo(`[config] TURN placeholder detected: ${TURN_PLACEHOLDER_DETECTED ? 'yes' : 'no'}`);
  logInfo(`[config] ICE servers parsed: ${ICE_SERVERS.length}`);
  if (ICE_SERVERS.length === 0) {
    logWarn('[config] ICE config is empty; calls can signal but ICE connectivity may fail.');
  }
  logInfo(`[config] ICE servers: ${JSON.stringify(sanitizedIceServers(ICE_SERVERS))}`);
  logInfo(`[config] callMedia audio: ${JSON.stringify(CALL_MEDIA_CONFIG.audio)}`);
}

function validateStartupConfig() {
  const errors = [];
  const warnings = [];

  // CRITICAL: ADMIN_TOKEN must be set to non-empty value
  if (!ADMIN_TOKEN || ADMIN_TOKEN.length < 8) {
    errors.push('ADMIN_TOKEN must be set to a strong value (min 8 chars) in .env');
  }

  // IMPORTANT: TURN_SERVERS should be configured for WebRTC calls
  if (TURN_PLACEHOLDER_DETECTED) {
    warnings.push('TURN_SERVERS contains placeholder values; placeholder TURN entries are ignored and only STUN fallback is returned.');
  }
  if ((FEATURE_VOICE_CALLS || FEATURE_VIDEO_CALLS) &&
      CONFIGURED_TURN_SERVER_COUNT === 0) {
    warnings.push('TURN_SERVERS not configured; WebRTC calls will fail on restricted networks. Add TURN_SERVERS to .env');
  }

  // IMPORTANT: Firebase FCM should be configured for push notifications
  const fcmConfigured =
    (process.env.FIREBASE_PROJECT_ID || loadFcmServiceAccount()?.project_id) &&
    (FCM_SERVICE_ACCOUNT_JSON || FCM_SERVICE_ACCOUNT_FILE);
  if (FEATURE_PUSH_NOTIFICATIONS && !fcmConfigured) {
    warnings.push('Firebase FCM not configured; push notifications will be disabled. Optional but recommended.');
  }

  // Check database file is writable
  if (typeof DB_FILE === 'string') {
    try {
      const dir = path.dirname(DB_FILE);
      if (!fs.existsSync(dir)) {
        fs.mkdirSync(dir, { recursive: true });
      }
      fs.accessSync(dir, fs.constants.W_OK);
      logInfo(`[startup] Database directory is writable: ${dir}`);
    } catch (error) {
      errors.push(`Database directory not writable: ${error.message}`);
    }
  }

  if (errors.length > 0) {
    console.error('[STARTUP FAILED]');
    for (const error of errors) {
      console.error(`  ✗ ${error}`);
    }
    process.exit(1);
  }

  for (const warning of warnings) {
    logWarn(`[startup] ⚠ ${warning}`);
  }

  logInfo('[startup] Configuration validation passed');
}

function parseTurnServers(value) {
  return String(value || '')
    .split(',')
    .map((item) => item.trim())
    .filter(Boolean)
    .map((item, index) => parseIceServerEntry(item, index))
    .filter(Boolean);
}

function parseIceServerEntry(item, index) {
  const parts = item.split('|').map((part) => part.trim());
  if (parts.length !== 1 && parts.length !== 3) {
    logWarn(`[config] ignored TURN_SERVERS entry ${index + 1}: expected url or url|username|credential`);
    return null;
  }

  const [urls, username, credential] = parts;
  const validation = validateIceServerUrl(urls);
  if (!validation.ok) {
    logWarn(`[config] ignored TURN_SERVERS entry ${index + 1}: ${validation.reason}`);
    return null;
  }

  if ((validation.scheme === 'turn' || validation.scheme === 'turns') &&
      (!username || !credential)) {
    logWarn(`[config] ignored TURN_SERVERS entry ${index + 1}: TURN credentials are required`);
    return null;
  }
  if (validation.scheme === 'stun' && (username || credential)) {
    logWarn(`[config] ignored TURN_SERVERS entry ${index + 1}: STUN credentials are not supported`);
    return null;
  }

  if (isPlaceholderTurnServer(urls, username, credential)) {
    logWarn(`[config] ignored TURN_SERVERS entry ${index + 1}: placeholder TURN config detected`);
    return null;
  }

  return {
    urls,
    ...(username ? { username } : {}),
    ...(credential ? { credential } : {}),
  };
}

function validateIceServerUrl(urls) {
  if (!urls || typeof urls !== 'string') {
    return { ok: false, reason: 'missing url' };
  }
  const match = urls.match(/^(stun|turn|turns):(\[[0-9a-f:.]+\]|[^:/?#\s|]+)(?::(\d{1,5}))?(\?transport=(udp|tcp))?$/i);
  if (!match) {
    return { ok: false, reason: 'invalid url format' };
  }
  const scheme = match[1].toLowerCase();
  const port = match[3] ? Number(match[3]) : null;
  if (port !== null && (port < 1 || port > 65535)) {
    return { ok: false, reason: 'invalid port' };
  }
  if (scheme === 'stun' && match[4]) {
    return { ok: false, reason: 'STUN transport query is not supported' };
  }
  return { ok: true, scheme };
}

function hasPlaceholderTurnConfig(value) {
  const raw = String(value || '').toLowerCase();
  if (!raw) return false;
  return raw.includes('your-domain.com') ||
    raw.includes('|user|') ||
    raw.endsWith('|user') ||
    raw.includes('|pass') ||
    raw.endsWith('|pass');
}

function isPlaceholderTurnServer(urls, username, credential) {
  const rawUrl = String(urls || '').toLowerCase();
  return rawUrl.includes('your-domain.com') ||
    String(username || '').trim().toLowerCase() === 'user' ||
    String(credential || '').trim().toLowerCase() === 'pass';
}

function loadData() {
  return store.loadData();
}

function ensureQueueBlobDir() {
  if (!fs.existsSync(QUEUE_BLOB_DIR)) {
    fs.mkdirSync(QUEUE_BLOB_DIR, { recursive: true });
  }
}

function ensureAttachmentBlobDir() {
  if (!fs.existsSync(ATTACHMENT_BLOB_DIR)) {
    fs.mkdirSync(ATTACHMENT_BLOB_DIR, { recursive: true });
  }
}

function safeAttachmentBlobPath(fileName) {
  const safeName = String(fileName || '').replace(/[^a-zA-Z0-9._-]/g, '');
  if (!safeName) {
    return null;
  }
  const resolved = path.resolve(ATTACHMENT_BLOB_DIR, safeName);
  const root = path.resolve(ATTACHMENT_BLOB_DIR);
  return resolved.startsWith(`${root}${path.sep}`) ? resolved : null;
}

function safeQueueBlobPath(fileName) {
  const safeName = String(fileName || '').replace(/[^a-zA-Z0-9._-]/g, '');
  if (!safeName) {
    return null;
  }
  const resolved = path.resolve(QUEUE_BLOB_DIR, safeName);
  const root = path.resolve(QUEUE_BLOB_DIR);
  return resolved.startsWith(`${root}${path.sep}`) ? resolved : null;
}

function createAttachmentRef(messageId, attachment, expiresAt) {
  if (!attachment?.base64) {
    return null;
  }
  ensureQueueBlobDir();
  const fileName = `${String(messageId || uuidv4()).replace(/[^a-zA-Z0-9_-]/g, '_')}-${uuidv4()}.blob`;
  const filePath = path.join(QUEUE_BLOB_DIR, fileName);
  fs.writeFileSync(filePath, attachment.base64, 'utf8');
  const checksum = QUEUE_BLOB_CHECKSUM
    ? crypto.createHash('sha256').update(attachment.base64).digest('hex')
    : null;
  return {
    fileName,
    filePath: fileName,
    sizeBytes: Buffer.byteLength(attachment.base64, 'utf8'),
    mimeType: attachment.mimeType || null,
    kind: attachment.originalKind || attachment.kind || 'document',
    name: attachment.originalName || attachment.name || 'encrypted.hestia',
    encrypted: attachment.encrypted === true,
    ...(checksum ? { checksum } : {}),
    createdAt: Date.now(),
    expiresAt,
  };
}

function deleteAttachmentRef(item) {
  const fileName = item?.attachmentRef?.fileName || item?.attachmentRef?.filePath;
  const filePath = safeQueueBlobPath(fileName);
  if (!filePath) {
    return false;
  }
  try {
    if (fs.existsSync(filePath)) {
      fs.unlinkSync(filePath);
      return true;
    }
  } catch (error) {
    logWarn(`[queue] blob delete failed: ${error.message}`);
  }
  return false;
}

function lightweightQueuedPayload(payload) {
  if (!payload?.attachment?.base64) {
    return payload;
  }
  const { base64, ...attachment } = payload.attachment;
  return {
    ...payload,
    attachment,
  };
}

function restoreQueuedPayload(item) {
  const payload = item?.payload;
  if (!payload?.attachment || payload.attachment.base64 || payload.attachment.blobId) {
    return payload || null;
  }
  const filePath = safeQueueBlobPath(
    item.attachmentRef?.fileName || item.attachmentRef?.filePath,
  );
  if (!filePath || !fs.existsSync(filePath)) {
    return null;
  }
  try {
    const base64 = fs.readFileSync(filePath, 'utf8');
    const expectedSize = Number(item.attachmentRef?.sizeBytes || 0);
    if (expectedSize > 0 && Buffer.byteLength(base64, 'utf8') !== expectedSize) {
      return null;
    }
    const checksum = item.attachmentRef?.checksum;
    if (checksum) {
      const actual = crypto.createHash('sha256').update(base64).digest('hex');
      if (actual !== checksum) {
        return null;
      }
    }
    return {
      ...payload,
      attachment: {
        ...payload.attachment,
        base64,
      },
    };
  } catch (error) {
    logWarn(`[queue] blob read failed: ${error.message}`);
    return null;
  }
}

function migrateInlineQueuedAttachment(item) {
  if (!item?.payload?.attachment?.base64 || item.attachmentRef) {
    return false;
  }
  try {
    item.attachmentRef = createAttachmentRef(
      item.id,
      item.payload.attachment,
      Number(item.expiresAt || Date.now() + OFFLINE_TTL_MS),
    );
    item.attachmentBytes = Number(
      item.attachmentBytes || queuedAttachmentBytes(item.payload),
    );
    item.payload = lightweightQueuedPayload(item.payload);
    return true;
  } catch (error) {
    logWarn(`[queue] inline blob migration failed: ${error.message}`);
    return false;
  }
}

function cleanupOrphanQueueBlobs(queue) {
  ensureQueueBlobDir();
  const referenced = new Set(
    (Array.isArray(queue) ? queue : [])
      .map((item) => item?.attachmentRef?.fileName || item?.attachmentRef?.filePath)
      .filter(Boolean),
  );
  let removed = 0;
  for (const fileName of fs.readdirSync(QUEUE_BLOB_DIR)) {
    const filePath = safeQueueBlobPath(fileName);
    if (!filePath) {
      continue;
    }
    const isReferenced = referenced.has(fileName);
    try {
      fs.statSync(filePath);
      if (!isReferenced) {
        fs.unlinkSync(filePath);
        removed += 1;
      }
    } catch (error) {
      logWarn(`[queue] orphan cleanup failed: ${error.message}`);
    }
  }
  return removed;
}

function findBlobById(blobId) {
  return data.blobs.find((blob) => blob.blobId === blobId) || null;
}

function authenticateHttp(req) {
  const userId = String(req.headers['x-user-id'] || '').trim();
  const token = String(req.headers['x-auth-token'] || '').trim();
  const user = userId ? findUserById(userId) : null;
  if (!user || user.disabled === true || !token) {
    return null;
  }
  const session = findSessionByToken(user, token);
  if (!session) {
    return null;
  }
  if (sessionExpired(session)) {
    user.sessions = ensureSessions(user).filter((item) => item.id !== session.id);
    saveData();
    return null;
  }
  return { user, session };
}

function attachmentBlobFileName(blobId) {
  return `${blobId}.blob`;
}

function deleteStoredBlob(blob) {
  const filePath = safeAttachmentBlobPath(blob?.fileName || blob?.filePath);
  if (!filePath) {
    return false;
  }
  try {
    if (fs.existsSync(filePath)) {
      fs.unlinkSync(filePath);
      return true;
    }
  } catch (error) {
    logWarn(`[blob] delete failed: ${error.message}`);
  }
  return false;
}

function blobIsReferenced(blobId) {
  return data.queuedMessages.some(
    (item) => item.payload?.attachment?.blobId === blobId,
  );
}

function cleanupStoredAttachmentBlobs() {
  ensureAttachmentBlobDir();
  const now = Date.now();
  const kept = [];
  let removed = 0;
  for (const blob of data.blobs || []) {
    const expired = Number(blob.expiresAt || 0) <= now;
    const downloadedExpired =
      blob.state === 'downloaded' &&
      Number(blob.downloadedAt || 0) > 0 &&
      Number(blob.downloadedAt || 0) + DOWNLOADED_BLOB_RETENTION_MS <= now &&
      !blobIsReferenced(blob.blobId);
    const filePath = safeAttachmentBlobPath(blob.fileName || blob.filePath);
    const missing = !filePath || !fs.existsSync(filePath);
    if ((expired && !blobIsReferenced(blob.blobId)) || downloadedExpired || missing) {
      deleteStoredBlob(blob);
      removed += 1;
      continue;
    }
    kept.push(blob);
  }
  data.blobs = kept;

  const referencedFiles = new Set(
    data.blobs.map((blob) => blob.fileName || blob.filePath).filter(Boolean),
  );
  for (const fileName of fs.readdirSync(ATTACHMENT_BLOB_DIR)) {
    const filePath = safeAttachmentBlobPath(fileName);
    if (!filePath || referencedFiles.has(fileName)) {
      continue;
    }
    try {
      fs.unlinkSync(filePath);
      removed += 1;
    } catch (error) {
      logWarn(`[blob] orphan cleanup failed: ${error.message}`);
    }
  }
  return removed;
}

function saveDataNow() {
  store.saveData(data);
}

function saveData() {
  saveQueued = true;
  if (saveTimer) {
    return;
  }
  saveTimer = setTimeout(flushData, SAVE_DEBOUNCE_MS);
}

function nextMessageSequence() {
  data.metadata.messageSequence = (Number(data.metadata.messageSequence || 0) || 0) + 1;
  return data.metadata.messageSequence;
}

function flushData() {
  if (saveTimer) {
    clearTimeout(saveTimer);
    saveTimer = null;
  }
  if (!saveQueued) {
    return;
  }
  saveQueued = false;
  try {
    saveDataNow();
  } catch (error) {
    logWarn(`[storage] save failed: ${error.message}`);
    saveQueued = true;
  }
  if (saveQueued) {
    saveTimer = setTimeout(flushData, SAVE_DEBOUNCE_MS);
  }
}

const store = createSQLiteStore(DB_FILE);
logInfo(`[storage] SQLite database: ${DB_FILE}`);
logInfo('[storage] Backup recommendation: snapshot the .sqlite file together with matching -wal and -shm files while the process is stopped, or use SQLite online backup tooling.');
logStartupConfig();
validateStartupConfig();
const data = loadData();
let users = data.users;
data.contacts = data.contacts || [];
data.contactRequests = data.contactRequests || [];
data.blocks = data.blocks || [];
data.blobs = data.blobs || [];
data.retentionEvents = data.retentionEvents || [];
data.metadata = data.metadata || {};
if (typeof data.metadata.registrationEnabled === 'boolean') {
  REGISTRATION_ENABLED = data.metadata.registrationEnabled;
}
if (typeof data.metadata.inviteOnly === 'boolean') {
  INVITE_ONLY = data.metadata.inviteOnly;
}
data.metadata.registrationEnabled = REGISTRATION_ENABLED;
data.metadata.inviteOnly = INVITE_ONLY;
data.metadata.messageSequence = Number(data.metadata.messageSequence || 0) || 0;
const initialQueueCleanup = cleanupQueuedMessages(data.queuedMessages);
data.queuedMessages = initialQueueCleanup.queue;
const initialBlobCleanup = cleanupOrphanQueueBlobs(data.queuedMessages);
const initialAttachmentBlobCleanup = cleanupStoredAttachmentBlobs();
if (initialQueueCleanup.removed > 0 || initialQueueCleanup.migrated > 0) {
  logInfo(
    `[queue] startup cleanup removed ${initialQueueCleanup.removed} messages and migrated ${initialQueueCleanup.migrated} attachments`,
  );
}
if (initialBlobCleanup > 0) {
  logInfo(`[queue] startup blob cleanup removed ${initialBlobCleanup} files`);
}
if (initialAttachmentBlobCleanup > 0) {
  logInfo(`[blob] startup cleanup removed ${initialAttachmentBlobCleanup} files`);
}
if (
  initialQueueCleanup.removed > 0 ||
  initialQueueCleanup.migrated > 0 ||
  initialBlobCleanup > 0 ||
  initialAttachmentBlobCleanup > 0
) {
  saveDataNow();
}

function send(ws, payload) {
  if (ws.readyState === WebSocket.OPEN) {
    ws.send(JSON.stringify(payload));
  }
}

function sendError(ws, message, options = {}) {
  const payload = {
    type: 'error',
    message,
    ...(options.messageId ? { id: options.messageId } : {}),
  };
  logDebug(
    `[debug] error sent userId=${ws.userId || 'unauthenticated'} ` +
    `sessionId=${ws.sessionId || 'none'} messageId=${options.messageId || 'none'} ` +
    `message=${message}`,
  );
  send(ws, payload);
}

function sendMessageFailed(ws, messageId, reason, logContext = {}) {
  const id = String(messageId || '').trim();
  const payload = {
    type: 'message_failed',
    id,
    reason,
  };
  logDebug(
    `[debug] message_failed sent sender=${logContext.senderId || ws.userId || 'unauthenticated'} ` +
    `to=${logContext.toUserId || 'empty'} messageId=${id || 'empty'} ` +
    `reason=${reason}`,
  );
  send(ws, payload);
}

function addClient(userId, ws) {
  const sockets = clients.get(userId) || new Set();
  if (ws.socketRole === 'foreground_service') {
    for (const socket of sockets) {
      if (socket !== ws &&
          socket.readyState === WebSocket.OPEN &&
          socket.socketRole === 'foreground_service' &&
          socket.sessionId === ws.sessionId &&
          socket.deviceId === ws.deviceId) {
        logDebug(
          `[debug] duplicate foreground service socket closing userId=${userId} ` +
          `sessionId=${ws.sessionId || 'none'} deviceId=${ws.deviceId || 'unknown'}`,
        );
        socket.close(1000, 'Duplicate foreground service socket');
      }
    }
  }
  sockets.add(ws);
  clients.set(userId, sockets);
}

function removeClient(userId, ws) {
  const sockets = clients.get(userId);
  if (!sockets) {
    return false;
  }
  const removed = sockets.delete(ws);
  if (sockets.size === 0) {
    clients.delete(userId);
  }
  return removed;
}

function userSockets(userId) {
  return Array.from(clients.get(userId) || [])
    .filter((socket) => socket.readyState === WebSocket.OPEN);
}

function isUserOnline(userId) {
  return userSockets(userId).length > 0;
}

function activeUserSockets(userId) {
  return userSockets(userId).filter((socket) => socket.appLifecycleState !== 'background');
}

function hasActiveSocket(userId) {
  return activeUserSockets(userId).length > 0;
}

function androidPushSessions(user) {
  return ensureSessions(user).filter((session) =>
    session.platform === 'android' &&
    session.pushProvider === 'fcm' &&
    typeof session.pushToken === 'string' &&
    session.pushToken.length > 0);
}

function pushSessionSummary(user) {
  return ensureSessions(user)
    .filter((session) => session.platform === 'android')
    .map((session) =>
      `${session.deviceId || session.id || 'unknown'}:${session.pushMode || 'none'}/${session.pushProvider || 'none'}/${session.pushToken ? 'token' : 'no_token'}`)
    .join(',');
}

function recipientSessionSummary(user) {
  return ensureSessions(user)
    .map((session) =>
      `${session.id || 'none'}:${session.deviceId || 'unknown'}:${session.platform || 'unknown'}/${session.pushMode || 'none'}/${session.pushProvider || 'none'}`)
    .join(',');
}

function socketStateSummary(userId) {
  return userSockets(userId)
    .map((socket) =>
      `${socket.sessionId || 'none'}:${socket.deviceId || 'unknown'}:${socket.platform || 'unknown'}/${socket.pushMode || 'none'}/${socket.socketRole || 'unknown'}/${socket.appLifecycleState || 'unknown'}`)
    .join(',');
}

function foregroundServiceSocketCount(userId) {
  return userSockets(userId).filter((socket) =>
    socket.platform === 'android' && socket.socketRole === 'foreground_service').length;
}

function androidSocketCount(userId) {
  return userSockets(userId).filter((socket) => socket.platform === 'android').length;
}

function androidSocketWithoutFcmCount(user, userId) {
  return userSockets(userId).filter((socket) => {
    if (socket.platform !== 'android') {
      return false;
    }
    const session = ensureSessions(user).find((item) => item.id === socket.sessionId);
    return !session?.pushToken || session.pushProvider !== 'fcm';
  }).length;
}

function targetPlatformSummary(user, userId) {
  const sessionPlatforms = ensureSessions(user)
    .map((session) =>
      `${session.platform || 'unknown'}:${session.deviceId || session.id || 'unknown'}:${session.pushMode || 'none'}`)
    .join(',');
  const socketPlatforms = userSockets(userId)
    .map((socket) =>
      `${socket.platform || 'unknown'}:${socket.deviceId || socket.sessionId || 'unknown'}:${socket.pushMode || 'none'}:${socket.socketRole || 'unknown'}:${socket.appLifecycleState || 'unknown'}`)
    .join(',');
  return `sessions=[${sessionPlatforms || 'none'}] sockets=[${socketPlatforms || 'none'}]`;
}

function attachmentDebugSummary(attachment) {
  if (!attachment || typeof attachment !== 'object') {
    return {
      hasAttachment: false,
      fields: [],
      blobId: null,
      name: null,
      kind: null,
      sizeBytes: null,
      encrypted: null,
    };
  }
  return {
    hasAttachment: true,
    fields: Object.keys(attachment).filter((key) => key !== 'base64'),
    blobId: attachment.blobId || null,
    name: attachment.originalName || attachment.name || null,
    kind: attachment.originalKind || attachment.kind || null,
    sizeBytes: Number(attachment.originalSizeBytes || attachment.sizeBytes || 0) || null,
    encrypted: attachment.encrypted === true,
  };
}

function logMessageAttachmentDebug(label, message) {
  const summary = attachmentDebugSummary(message?.attachment);
  logDebug(
    `[debug] ${label} messageId=${message?.id || 'none'} keys=${Object.keys(message || {}).join(',')} ` +
    `hasAttachment=${summary.hasAttachment} attachmentFields=${summary.fields.join(',')} ` +
    `blobId=${summary.blobId || 'none'} name=${summary.name || 'none'} ` +
    `kind=${summary.kind || 'none'} sizeBytes=${summary.sizeBytes || 0} encrypted=${summary.encrypted === true}`,
  );
}

function sendToUser(userId, payload, options = {}) {
  let delivered = 0;
  for (const socket of userSockets(userId)) {
    if (options.excludeSessionId && socket.sessionId === options.excludeSessionId) {
      continue;
    }
    if (payload?.type === 'new_message') {
      logMessageAttachmentDebug(
        `sendToUser new_message to=${userId} sessionId=${socket.sessionId || 'none'} appState=${socket.appLifecycleState || 'unknown'}`,
        payload.message,
      );
    }
    send(socket, payload);
    delivered += 1;
  }
  return delivered;
}

function hasOpenSocket(userId) {
  return userSockets(userId).length > 0;
}

function connectedClientCount(userId) {
  return userSockets(userId).length;
}

function allClientSockets() {
  return Array.from(clients.values()).flatMap((sockets) => Array.from(sockets));
}

function readRequestBody(req, maxBytes = 1024 * 1024) {
  return new Promise((resolve) => {
    let raw = '';
    let tooLarge = false;
    req.on('data', (chunk) => {
      if (tooLarge) {
        return;
      }
      raw += chunk;
      if (Buffer.byteLength(raw, 'utf8') > maxBytes) {
        tooLarge = true;
        req.destroy();
      }
    });
    req.on('end', () => {
      if (tooLarge) {
        resolve(null);
        return;
      }
      try {
        resolve(raw ? JSON.parse(raw) : {});
      } catch {
        resolve(null);
      }
    });
    req.on('error', () => resolve(null));
  });
}

function jsonResponse(res, statusCode, payload) {
  res.writeHead(statusCode, {
    'Content-Type': 'application/json',
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET,POST,OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type, X-Admin-Token, X-User-Id, X-Auth-Token',
  });
  res.end(JSON.stringify(payload));
}

function resolvePublicDir() {
  const candidates = [
    process.env.PUBLIC_DIR,
    path.join(__dirname, 'public'),
    path.join(__dirname, 'Landing_Hestia'),
    __dirname,
  ].filter(Boolean);

  for (const candidate of candidates) {
    const resolved = path.resolve(candidate);
    if (fs.existsSync(path.join(resolved, 'index.html'))) {
      return resolved;
    }
  }
  return null;
}

function staticContentType(filePath) {
  const ext = path.extname(filePath).toLowerCase();
  const types = {
    '.css': 'text/css; charset=utf-8',
    '.html': 'text/html; charset=utf-8',
    '.js': 'application/javascript; charset=utf-8',
    '.json': 'application/json; charset=utf-8',
    '.map': 'application/json; charset=utf-8',
    '.svg': 'image/svg+xml',
    '.png': 'image/png',
    '.jpg': 'image/jpeg',
    '.jpeg': 'image/jpeg',
    '.webp': 'image/webp',
    '.ico': 'image/x-icon',
    '.txt': 'text/plain; charset=utf-8',
    '.xml': 'application/xml; charset=utf-8',
    '.wasm': 'application/wasm',
    '.webmanifest': 'application/manifest+json; charset=utf-8',
  };
  return types[ext] || 'application/octet-stream';
}

function serveLandingStatic(req, res, url) {
  if (!PUBLIC_DIR || (req.method !== 'GET' && req.method !== 'HEAD')) {
    return false;
  }

  let requestPath;
  try {
    requestPath = decodeURIComponent(url.pathname);
  } catch {
    return false;
  }

  if (requestPath === '/') {
    requestPath = '/index.html';
  }
  if (requestPath === '/app') {
    res.writeHead(308, {
      Location: '/app/',
      'Cache-Control': 'no-cache',
    });
    res.end();
    return true;
  }

  let relativePath = requestPath.replace(/^\/+/, '');
  if (relativePath === 'app/') {
    relativePath = 'app/index.html';
  }
  const firstSegment = relativePath.split('/')[0];
  const isAllowed =
    LANDING_PAGES.has(relativePath) ||
    STATIC_FILES.has(relativePath) ||
    STATIC_DIRS.has(firstSegment);

  if (!isAllowed) {
    return false;
  }

  const filePath = path.resolve(PUBLIC_DIR, relativePath);
  const publicRoot = path.resolve(PUBLIC_DIR);
  if (filePath !== publicRoot && !filePath.startsWith(`${publicRoot}${path.sep}`)) {
    return false;
  }

  if (!fs.existsSync(filePath) || !fs.statSync(filePath).isFile()) {
    if (firstSegment === 'app' && !path.extname(relativePath)) {
      const appIndexPath = path.resolve(PUBLIC_DIR, 'app', 'index.html');
      if (appIndexPath.startsWith(`${publicRoot}${path.sep}`) &&
          fs.existsSync(appIndexPath) &&
          fs.statSync(appIndexPath).isFile()) {
        const stat = fs.statSync(appIndexPath);
        res.writeHead(200, {
          'Content-Type': staticContentType(appIndexPath),
          'Content-Length': String(stat.size),
          'Cache-Control': 'no-cache',
        });
        if (req.method === 'HEAD') {
          res.end();
          return true;
        }
        fs.createReadStream(appIndexPath).pipe(res);
        return true;
      }
    }
    return false;
  }

  const stat = fs.statSync(filePath);
  res.writeHead(200, {
    'Content-Type': staticContentType(filePath),
    'Content-Length': String(stat.size),
    'Cache-Control': relativePath === 'index.html' ||
      relativePath === 'app/index.html' ||
      relativePath === 'releases/latest.json'
      ? 'no-cache'
      : 'public, max-age=300',
  });
  if (req.method === 'HEAD') {
    res.end();
    return true;
  }
  fs.createReadStream(filePath).pipe(res);
  return true;
}

function requireAdmin(req, res) {
  if (!ADMIN_TOKEN || req.headers['x-admin-token'] !== ADMIN_TOKEN) {
    jsonResponse(res, 404, { error: 'Not found' });
    return false;
  }
  return true;
}

function clientAddress(ws) {
  return ws._socket?.remoteAddress || 'unknown';
}

function bucketAllowed(map, key, limit, windowMs) {
  const now = Date.now();
  const bucket = map.get(key) || [];
  const fresh = bucket.filter((timestamp) => now - timestamp < windowMs);
  if (fresh.length >= limit) {
    map.set(key, fresh);
    return false;
  }
  fresh.push(now);
  map.set(key, fresh);
  return true;
}

function rateLimit(ws, scope, limit, windowMs) {
  const actor = ws.userId || clientAddress(ws);
  return bucketAllowed(rateBuckets, `${scope}:${actor}`, limit, windowMs);
}

function pairCooldown(map, key, windowMs) {
  const now = Date.now();
  const previous = map.get(key) || 0;
  if (now - previous < windowMs) {
    return false;
  }
  map.set(key, now);
  return true;
}

function tooManyRequests(ws) {
  send(ws, {
    type: 'error',
    message: 'Too many requests. Try again later.',
  });
}

function findUserById(userId) {
  return users.find((user) => user.id === userId);
}

function findUserByNickname(nickname) {
  const normalized = String(nickname).trim().toLowerCase();
  const normalizedKey = normalizeUsernameKey(nickname);
  return users.find(
    (user) => user.nickname.toLowerCase() === normalized ||
      user.nicknameNormalized === normalizedKey,
  );
}

function hashPassword(password) {
  const salt = crypto.randomBytes(16).toString('hex');
  const digest = crypto
    .pbkdf2Sync(String(password), salt, 210000, 32, 'sha256')
    .toString('hex');
  return `pbkdf2-sha256$210000$${salt}$${digest}`;
}

function verifyPassword(password, storedHash) {
  const value = String(storedHash || '');
  if (value.startsWith('pbkdf2-sha256$')) {
    const [, iterationsRaw, salt, digest] = value.split('$');
    const iterations = Number(iterationsRaw);
    if (!Number.isFinite(iterations) || !salt || !digest) {
      return false;
    }
    const candidate = crypto
      .pbkdf2Sync(String(password), salt, iterations, Buffer.from(digest, 'hex').length, 'sha256')
      .toString('hex');
    return timingSafeStringEqual(candidate, digest);
  }
  const legacy = crypto.createHash('sha256').update(String(password)).digest('hex');
  return timingSafeStringEqual(legacy, value);
}

function isLegacyPasswordHash(storedHash) {
  return /^[a-f0-9]{64}$/i.test(String(storedHash || ''));
}

function timingSafeStringEqual(left, right) {
  const a = Buffer.from(String(left || ''), 'utf8');
  const b = Buffer.from(String(right || ''), 'utf8');
  if (a.length !== b.length) {
    return false;
  }
  return crypto.timingSafeEqual(a, b);
}

function createAuthToken() {
  return crypto.randomBytes(32).toString('hex');
}

function ensureSessions(user) {
  if (!Array.isArray(user.sessions)) {
    user.sessions = [];
  }
  return user.sessions;
}

function createSession(user, msg, token = createAuthToken()) {
  const sessions = ensureSessions(user);
  const deviceId = String(msg.deviceId || uuidv4()).trim();
  const existing = sessions.find((session) => session.deviceId === deviceId);
  const now = new Date().toISOString();
  const session = existing || {
    id: uuidv4(),
    deviceId,
    createdAt: now,
  };
  session.token = token;
  session.deviceName = String(msg.deviceName || 'Unknown device').trim() || 'Unknown device';
  session.platform = String(msg.platform || 'unknown').trim() || 'unknown';
  session.appVersion = normalizeAppVersion(msg.appVersion || session.appVersion);
  session.lastActiveAt = now;
  session.lastSeenAt = now;
  if (!existing) sessions.push(session);
  return session;
}

function normalizeAppVersion(value) {
  return String(value || '').trim().slice(0, 80);
}

function normalizePushProvider(value) {
  const provider = String(value || '').trim().toLowerCase();
  return PUSH_PROVIDERS.has(provider) ? provider : '';
}

function normalizePushToken(value) {
  const token = String(value || '').trim();
  if (token.length < 16 || token.length > 4096) {
    return '';
  }
  return token;
}

function normalizePublicKey(value) {
  const key = String(value || '').trim();
  if (!key || Buffer.byteLength(key, 'utf8') > MAX_PUBLIC_KEY_BYTES) {
    return '';
  }
  let decoded;
  try {
    decoded = Buffer.from(key, 'base64');
  } catch {
    return '';
  }
  if (decoded.length !== 65 || decoded[0] !== 0x04) {
    return '';
  }
  return key;
}

function boundedString(value, maxBytes) {
  const text = typeof value === 'string' ? value : '';
  if (Buffer.byteLength(text, 'utf8') > maxBytes) {
    return null;
  }
  return text;
}

function currentSessionFor(ws) {
  const user = findUserById(ws.userId);
  if (!user || !ws.sessionId) {
    return null;
  }
  return ensureSessions(user).find((session) => session.id === ws.sessionId) || null;
}

const RETENTION_EVENTS = new Set([
  'user_registered',
  'first_contact_added',
  'first_message_sent',
  'first_message_received',
  'call_started',
  'call_received',
  'reply_received',
]);

function ensureRetentionState(user) {
  if (!user.retentionState || typeof user.retentionState !== 'object') {
    user.retentionState = {};
  }
  return user.retentionState;
}

function recordRetentionEvent(userId, event, metadata = {}) {
  if (!RETENTION_EVENTS.has(event)) {
    return false;
  }
  const user = findUserById(userId);
  if (!user) {
    return false;
  }
  const state = ensureRetentionState(user);
  const now = new Date().toISOString();
  let firstEvent = false;

  if (!state[event]) {
    state[event] = now;
    firstEvent = true;
  }
  state.lastActiveAt = now;

  if (event === 'first_contact_added') {
    state.hasContacts = true;
  } else if (event === 'first_message_sent') {
    state.hasSentMessage = true;
  } else if (event === 'first_message_received' || event === 'reply_received') {
    state.hasReceivedMessage = true;
  }

  if (firstEvent) {
    data.retentionEvents.push({
      id: uuidv4(),
      userId,
      event,
      createdAt: now,
      metadata: {
        source: String(metadata.source || 'server').slice(0, 32),
      },
    });
    if (data.retentionEvents.length > 5000) {
      data.retentionEvents = data.retentionEvents.slice(-5000);
    }
  }
  saveData();
  return firstEvent;
}

function touchRetentionActivity(userId) {
  const user = findUserById(userId);
  if (!user) {
    return;
  }
  ensureRetentionState(user).lastActiveAt = new Date().toISOString();
}

function findSessionByToken(user, token) {
  const sessions = ensureSessions(user);
  const now = Date.now();
  let changed = false;
  user.sessions = sessions.filter((session) => {
    if (sessionExpired(session, now)) {
      changed = true;
      return false;
    }
    return true;
  });
  if (changed) {
    saveData();
  }
  return user.sessions.find((session) => session.token === token) || null;
}

function sessionExpired(session, now = Date.now()) {
  const createdAt = Date.parse(session.createdAt || session.lastActiveAt || '');
  if (Number.isFinite(createdAt) && now - createdAt > SESSION_MAX_AGE_MS) {
    return true;
  }
  const lastActiveAt = Date.parse(session.lastActiveAt || session.lastSeenAt || session.createdAt || '');
  return Number.isFinite(lastActiveAt) && now - lastActiveAt > SESSION_IDLE_TTL_MS;
}

function sessionDto(session, currentSessionId) {
  return {
    id: session.id,
    deviceId: session.deviceId,
    deviceName: session.deviceName || 'Unknown device',
    platform: session.platform || 'unknown',
    pushMode: session.pushMode || null,
    pushProvider: session.pushProvider || null,
    pushEnabled: Boolean(session.pushToken && session.pushProvider),
    appVersion: session.appVersion || null,
    createdAt: session.createdAt,
    lastActiveAt: session.lastActiveAt,
    lastSeenAt: session.lastSeenAt || session.lastActiveAt,
    pushTokenUpdatedAt: session.pushTokenUpdatedAt || null,
    current: session.id === currentSessionId,
  };
}

function sendSessions(ws) {
  const user = findUserById(ws.userId);
  if (!user) return;
  send(ws, {
    type: 'sessions',
    sessions: ensureSessions(user).map((session) =>
      sessionDto(session, ws.sessionId)),
  });
}

function cleanupPendingDeliveries() {
  const now = Date.now();
  let removed = 0;
  for (const [messageId, item] of pendingDeliveries.entries()) {
    if (now - Number(item.createdAt || 0) > PENDING_DELIVERY_TTL_MS) {
      pendingDeliveries.delete(messageId);
      removed += 1;
    }
  }
  if (removed > 0) {
    logInfo(`[queue] removed ${removed} expired pending deliveries`);
  }
}

function cleanupPendingCallOffers() {
  const now = Date.now();
  let removed = 0;
  for (const [callId, offer] of pendingCallOffers.entries()) {
    if (now > Number(offer.endedExpiresAt || offer.expiresAt || 0)) {
      pendingCallOffers.delete(callId);
      removed += 1;
    }
  }
  return removed;
}

function runQueueMaintenance() {
  const cleanup = cleanupQueuedMessages(data.queuedMessages);
  data.queuedMessages = cleanup.queue;
  cleanupPendingDeliveries();
  cleanupPendingCallOffers();
  const orphanBlobs = cleanupOrphanQueueBlobs(data.queuedMessages);
  const storedBlobs = cleanupStoredAttachmentBlobs();
  if (cleanup.removed > 0) {
    logInfo(`[queue] periodic cleanup removed ${cleanup.removed} messages`);
  }
  if (orphanBlobs > 0) {
    logInfo(`[queue] blob cleanup removed ${orphanBlobs} files`);
  }
  if (storedBlobs > 0) {
    logInfo(`[blob] cleanup removed ${storedBlobs} files`);
  }
  if (cleanup.removed > 0 || cleanup.migrated > 0 || orphanBlobs > 0 || storedBlobs > 0) {
    saveData();
  }
}

function cleanupQueuedMessages(queue) {
  const now = Date.now();
  const source = Array.isArray(queue) ? queue : [];
  const live = [];
  let removed = 0;
  let migrated = 0;
  for (const item of source) {
    if (Number(item.expiresAt || 0) <= now) {
      deleteAttachmentRef(item);
      removed += 1;
      continue;
    }
    if (migrateInlineQueuedAttachment(item)) {
      migrated += 1;
    }
    live.push(item);
  }
  const sorted = live.sort((a, b) => Number(b.queuedAt || 0) - Number(a.queuedAt || 0));
  const kept = [];
  const countsByRecipient = new Map();
  const bytesByRecipient = new Map();
  const attachmentBytesByRecipient = new Map();
  const attachmentFilesByRecipient = new Map();
  let serverBytes = 0;
  let serverAttachmentBytes = 0;
  let serverAttachmentFiles = 0;

  for (const item of sorted) {
    const toUserId = String(item.toUserId || '');
    const payloadBytes = Number(item.payloadBytes || queuedPayloadBytes(item.payload));
    const attachmentBytes = Number(
      item.attachmentBytes || queuedAttachmentBytes(item.payload),
    );
    const attachmentFiles = item.attachmentRef || item.payload?.attachment ? 1 : 0;
    const recipientCount = countsByRecipient.get(toUserId) || 0;
    const recipientBytes = bytesByRecipient.get(toUserId) || 0;
    const recipientAttachmentBytes = attachmentBytesByRecipient.get(toUserId) || 0;
    const recipientAttachmentFiles = attachmentFilesByRecipient.get(toUserId) || 0;
    const overLimit =
      kept.length >= OFFLINE_QUEUE_SERVER_MAX_MESSAGES ||
      serverBytes + payloadBytes > OFFLINE_QUEUE_SERVER_MAX_BYTES ||
      serverAttachmentBytes + attachmentBytes > OFFLINE_QUEUE_SERVER_ATTACHMENT_MAX_BYTES ||
      serverAttachmentFiles + attachmentFiles > OFFLINE_QUEUE_SERVER_ATTACHMENT_MAX_FILES ||
      recipientCount + 1 > OFFLINE_QUEUE_RECIPIENT_MAX_MESSAGES ||
      recipientBytes + payloadBytes > OFFLINE_QUEUE_RECIPIENT_MAX_BYTES ||
      recipientAttachmentBytes + attachmentBytes >
        OFFLINE_QUEUE_RECIPIENT_ATTACHMENT_MAX_BYTES ||
      recipientAttachmentFiles + attachmentFiles >
        OFFLINE_QUEUE_RECIPIENT_ATTACHMENT_MAX_FILES;

    if (overLimit) {
      deleteAttachmentRef(item);
      removed += 1;
      continue;
    }

    item.payloadBytes = payloadBytes;
    item.attachmentBytes = attachmentBytes;
    kept.push(item);
    countsByRecipient.set(toUserId, recipientCount + 1);
    bytesByRecipient.set(toUserId, recipientBytes + payloadBytes);
    attachmentBytesByRecipient.set(
      toUserId,
      recipientAttachmentBytes + attachmentBytes,
    );
    attachmentFilesByRecipient.set(
      toUserId,
      recipientAttachmentFiles + attachmentFiles,
    );
    serverBytes += payloadBytes;
    serverAttachmentBytes += attachmentBytes;
    serverAttachmentFiles += attachmentFiles;
  }

  return {
    queue: kept.sort((a, b) => Number(a.queuedAt || 0) - Number(b.queuedAt || 0)),
    removed,
    migrated,
  };
}

function queueOfflineMessage(toUserId, payload) {
  const cleanup = cleanupQueuedMessages(data.queuedMessages);
  data.queuedMessages = cleanup.queue;
  if (cleanup.removed > 0) {
    logInfo(`[queue] cleanup removed ${cleanup.removed} messages before enqueue`);
  }
  const payloadBytes = queuedPayloadBytes(payload);
  const attachmentBytes = queuedAttachmentBytes(payload);
  const attachmentFiles = payload?.attachment ? 1 : 0;
  const limitError = queueLimitError(
    toUserId,
    payloadBytes,
    attachmentBytes,
    attachmentFiles,
  );
  if (limitError) {
    logWarn(`[queue] rejected offline message for ${toUserId}: ${limitError}`);
    saveData();
    return { ok: false, message: limitError };
  }
  const expiresAt = Date.now() + OFFLINE_TTL_MS;
  let attachmentRef = null;
  let queuedPayload = payload;
  if (payload?.attachment?.base64) {
    try {
      attachmentRef = createAttachmentRef(payload.id, payload.attachment, expiresAt);
      queuedPayload = lightweightQueuedPayload(payload);
    } catch (error) {
      logWarn(`[queue] blob write failed: ${error.message}`);
      return {
        ok: false,
        message: 'Attachment cannot be queued. Try again later.',
      };
    }
  }
  data.queuedMessages.push({
    id: payload.id,
    toUserId,
    payload: queuedPayload,
    attachmentRef,
    payloadBytes,
    attachmentBytes,
    queuedAt: Date.now(),
    expiresAt,
  });
  saveData();
  return { ok: true };
}

function queuedPayloadBytes(payload) {
  const textBytes = typeof payload?.text === 'string'
    ? Buffer.byteLength(payload.text, 'utf8')
    : 0;
  return textBytes + queuedAttachmentBytes(payload) + 1024;
}

function queuedAttachmentBytes(payload) {
  const attachment = payload?.attachment;
  if (!attachment) return 0;
  if (attachment.blobId && !attachment.base64) return 0;
  return Number(attachment.encodedSizeBytes || attachment.base64?.length || 0);
}

function queuedBytesForRecipient(userId) {
  return data.queuedMessages
    .filter((item) => item.toUserId === userId)
    .reduce((sum, item) => sum + Number(item.payloadBytes || queuedPayloadBytes(item.payload)), 0);
}

function queuedAttachmentBytesForRecipient(userId) {
  return data.queuedMessages
    .filter((item) => item.toUserId === userId)
    .reduce(
      (sum, item) =>
        sum + Number(item.attachmentBytes || queuedAttachmentBytes(item.payload)),
      0,
    );
}

function queuedBytesForServer() {
  return data.queuedMessages.reduce(
    (sum, item) => sum + Number(item.payloadBytes || queuedPayloadBytes(item.payload)),
    0,
  );
}

function queuedAttachmentBytesForServer() {
  return data.queuedMessages.reduce(
    (sum, item) =>
      sum + Number(item.attachmentBytes || queuedAttachmentBytes(item.payload)),
    0,
  );
}

function queuedMessagesForRecipient(userId) {
  return data.queuedMessages.filter((item) => item.toUserId === userId).length;
}

function queuedAttachmentFilesForRecipient(userId) {
  return data.queuedMessages.filter(
    (item) => item.toUserId === userId && (item.attachmentRef || item.payload?.attachment),
  ).length;
}

function queuedAttachmentFilesForServer() {
  return data.queuedMessages.filter(
    (item) => item.attachmentRef || item.payload?.attachment,
  ).length;
}

function storedBlobBytesForRecipient(userId) {
  return data.blobs
    .filter((blob) => blob.recipientUserId === userId && blobCountsTowardStorage(blob))
    .reduce((sum, blob) => sum + Number(blob.sizeBytes || 0), 0);
}

function storedBlobBytesForServer() {
  return data.blobs
    .filter(blobCountsTowardStorage)
    .reduce((sum, blob) => sum + Number(blob.sizeBytes || 0), 0);
}

function storedBlobFilesForRecipient(userId) {
  return data.blobs.filter((blob) =>
    blob.recipientUserId === userId && blobCountsTowardStorage(blob)).length;
}

function storedBlobFilesForServer() {
  return data.blobs.filter(blobCountsTowardStorage).length;
}

function blobCountsTowardStorage(blob) {
  if (!blob) return false;
  if (blobIsReferenced(blob.blobId)) return true;
  return blob.state === 'ready';
}

function queueLimitError(toUserId, payloadBytes, attachmentBytes, attachmentFiles = 0) {
  if (data.queuedMessages.length + 1 > OFFLINE_QUEUE_SERVER_MAX_MESSAGES) {
    return 'Server offline queue is full. Try again later.';
  }
  if (queuedMessagesForRecipient(toUserId) + 1 > OFFLINE_QUEUE_RECIPIENT_MAX_MESSAGES) {
    return 'Recipient offline queue is full. Try again later.';
  }
  if (queuedBytesForRecipient(toUserId) + payloadBytes > OFFLINE_QUEUE_RECIPIENT_MAX_BYTES) {
    return 'Recipient offline queue is full. Try again later.';
  }
  if (queuedBytesForServer() + payloadBytes > OFFLINE_QUEUE_SERVER_MAX_BYTES) {
    return 'Server offline queue is full. Try again later.';
  }
  if (
    attachmentBytes > 0 &&
    queuedAttachmentBytesForRecipient(toUserId) + storedBlobBytesForRecipient(toUserId) + attachmentBytes >
      OFFLINE_QUEUE_RECIPIENT_ATTACHMENT_MAX_BYTES
  ) {
    return 'Recipient attachment queue is full. Try again later.';
  }
  if (
    attachmentBytes > 0 &&
    queuedAttachmentBytesForServer() + storedBlobBytesForServer() + attachmentBytes >
      OFFLINE_QUEUE_SERVER_ATTACHMENT_MAX_BYTES
  ) {
    return 'Server attachment queue is full. Try again later.';
  }
  if (
    attachmentFiles > 0 &&
    queuedAttachmentFilesForRecipient(toUserId) + storedBlobFilesForRecipient(toUserId) + attachmentFiles >
      OFFLINE_QUEUE_RECIPIENT_ATTACHMENT_MAX_FILES
  ) {
    return 'Recipient attachment queue is full. Try again later.';
  }
  if (
    attachmentFiles > 0 &&
    queuedAttachmentFilesForServer() + storedBlobFilesForServer() + attachmentFiles >
      OFFLINE_QUEUE_SERVER_ATTACHMENT_MAX_FILES
  ) {
    return 'Server attachment queue is full. Try again later.';
  }
  return null;
}

function deliverQueuedMessages(ws, userId) {
  const cleanup = cleanupQueuedMessages(data.queuedMessages);
  data.queuedMessages = cleanup.queue;
  const user = findUserById(userId);
  const queued = data.queuedMessages.filter((item) => {
    if (item.toUserId !== userId) return false;
    const recipientPublicKey = item.payload?.recipientPublicKey;
    return !recipientPublicKey || recipientPublicKey === user?.publicKey;
  });
  for (const item of queued) {
    const message = restoreQueuedPayload(item);
    if (!message) {
      deleteAttachmentRef(item);
      data.queuedMessages = data.queuedMessages.filter((entry) => entry.id !== item.id);
      pendingDeliveries.delete(item.id);
      logWarn(`[queue] dropped queued message with missing blob: ${item.id}`);
      continue;
    }
    logMessageAttachmentDebug(`offline new_message to=${userId}`, message);
    send(ws, {
      type: 'new_message',
      message,
      queued: true,
    });
  }
  if (cleanup.removed > 0 || cleanup.migrated > 0 || data.queuedMessages.length !== cleanup.queue.length) {
    saveData();
  }
}

function ackDelivery(messageId, userId, senderHint = '') {
  const queued = data.queuedMessages.find(
    (item) => item.id === messageId && item.toUserId === userId,
  );
  const before = data.queuedMessages.length;
  data.queuedMessages = data.queuedMessages.filter(
    (item) => !(item.id === messageId && item.toUserId === userId),
  );
  if (data.queuedMessages.length !== before) {
    deleteAttachmentRef(queued);
    saveData();
  }
  const hintedSender =
    senderHint &&
    findUserById(senderHint) &&
    hasMutualActiveContact(senderHint, userId)
      ? senderHint
      : null;
  const senderUserId =
    pendingDeliveries.get(messageId)?.senderUserId ||
    queued?.payload?.fromUserId ||
    hintedSender;
  pendingDeliveries.delete(messageId);
  logDebug(
    `[debug] delivery_ack messageId=${messageId || 'empty'} userId=${userId} ` +
    `queuedRemoved=${data.queuedMessages.length !== before} ` +
    `senderUserId=${senderUserId || 'none'} senderSocketExists=${senderUserId ? hasOpenSocket(senderUserId) : false}`,
  );
  if (senderUserId) {
    sendToUser(senderUserId, { type: 'delivery_ack', id: messageId });
  }
}

function finishAuth(ws, user, session, msg = {}) {
  ws.userId = user.id;
  ws.sessionId = session?.id || null;
  ws.deviceId = session?.deviceId || null;
  ws.platform = session?.platform || 'unknown';
  ws.pushMode = session?.pushMode || 'none';
  ws.socketRole = String(msg.socketRole || '').trim() ||
    (ws.pushMode === 'foreground_service' ? 'foreground_service' : 'main_app');
  ws.appLifecycleState = 'active';
  ws.appLifecycleUpdatedAt = Date.now();
  addClient(user.id, ws);
  logDebug(
    `[debug] auth ok userId=${user.id} sessionId=${ws.sessionId || 'none'} ` +
    `deviceId=${ws.deviceId || 'unknown'} platform=${ws.platform} pushMode=${ws.pushMode} socketRole=${ws.socketRole} ` +
    `activeSockets=${connectedClientCount(user.id)}`,
  );
  logDebug(
    `[debug] user connected userId=${user.id} sessionId=${ws.sessionId || 'none'} ` +
    `deviceId=${ws.deviceId || 'unknown'} platform=${ws.platform} pushMode=${ws.pushMode} socketRole=${ws.socketRole} ` +
    `activeSockets=${connectedClientCount(user.id)}`,
  );

  send(ws, {
    type: 'auth_ok',
    userId: user.id,
    nickname: user.nickname,
    authToken: session?.token || null,
    publicKey: user.publicKey || null,
  });

  sendUsers(ws, user.id);
  sendContacts(ws, user.id);
  sendContactRequests(ws, user.id);
  sendSessions(ws);
  deliverQueuedMessages(ws, user.id);
  schedulePresence(user.id);
}

function publicUser(user) {
  return {
    userId: user.id,
    nickname: user.nickname,
    online: isUserOnline(user.id),
    publicKey: user.publicKey || null,
  };
}

function contactDto(contact, currentUserId) {
  const peerUserId = contact.userId === currentUserId ? contact.peerUserId : contact.userId;
  const peer = findUserById(peerUserId);
  return {
    userId: currentUserId,
    peerUserId,
    username: peer?.nickname || contact.username || 'Unknown',
    status: contact.status || 'active',
    publicKey: peer?.publicKey || null,
    online: isUserOnline(peerUserId),
  };
}

function requestDto(request) {
  return {
    id: request.id,
    fromUserId: request.fromUserId,
    toUserId: request.toUserId,
    fromUsername: request.fromUsername,
    status: request.status,
    createdAt: request.createdAt,
  };
}

function hasActiveContact(a, b) {
  return data.contacts.some((contact) =>
    contact.status === 'active' &&
    ((contact.userId === a && contact.peerUserId === b) ||
      (contact.userId === b && contact.peerUserId === a)));
}

function contactStateBetween(a, b) {
  const fromSender = data.contacts.filter((contact) =>
    contact.userId === a && contact.peerUserId === b);
  const fromRecipient = data.contacts.filter((contact) =>
    contact.userId === b && contact.peerUserId === a);
  return {
    senderContactCount: fromSender.length,
    recipientContactCount: fromRecipient.length,
    senderHasActiveContact: fromSender.some((contact) => contact.status === 'active'),
    recipientHasActiveContact: fromRecipient.some((contact) => contact.status === 'active'),
  };
}

function hasMutualActiveContact(a, b) {
  const state = contactStateBetween(a, b);
  return state.senderHasActiveContact && state.recipientHasActiveContact;
}

function isBlockedBy(userId, blockedUserId) {
  return data.blocks.some(
    (item) => item.userId === userId && item.blockedUserId === blockedUserId,
  );
}

function sendContacts(ws, currentUserId) {
  send(ws, {
    type: 'contacts',
    contacts: data.contacts
      .filter((contact) => contact.userId === currentUserId)
      .map((contact) => contactDto(contact, currentUserId)),
  });
}

function sendContactRequests(ws, currentUserId) {
  send(ws, {
    type: 'contact_requests',
    requests: data.contactRequests
      .filter((request) => request.toUserId === currentUserId && request.status === 'pending')
      .map(requestDto),
  });
}

function schedulePresence(userId) {
  if (presenceTimers.has(userId)) {
    return;
  }
  const timer = setTimeout(() => {
    presenceTimers.delete(userId);
    broadcastPresence(userId);
  }, PRESENCE_DEBOUNCE_MS);
  presenceTimers.set(userId, timer);
}

function broadcastPresence(userId) {
  const user = findUserById(userId);
  if (!user) {
    return;
  }

  const payload = {
    type: 'user_presence',
    user: publicUser(user),
  };

  for (const [viewerUserId, sockets] of clients.entries()) {
    if (viewerUserId === userId || hasActiveContact(viewerUserId, userId)) {
      for (const socket of sockets) {
        send(socket, payload);
      }
    }
  }
}

function touchSession(ws) {
  const currentSession = currentSessionFor(ws);
  if (!currentSession) {
    return true;
  }
  if (sessionExpired(currentSession)) {
    const user = findUserById(ws.userId);
    if (user) {
      user.sessions = ensureSessions(user).filter((session) => session.id !== currentSession.id);
      saveData();
    }
    send(ws, { type: 'session_revoked' });
    ws.close();
    logDebug(
      `[debug] session expired userId=${ws.userId || 'unknown'} ` +
      `sessionId=${ws.sessionId || 'none'}`,
    );
    return false;
  }

  const now = Date.now();
  const previous = currentSession.lastActiveAt
    ? Date.parse(currentSession.lastActiveAt)
    : 0;
  if (Number.isFinite(previous) && now - previous < SESSION_TOUCH_INTERVAL_MS) {
    return true;
  }
  const stamp = new Date(now).toISOString();
  currentSession.lastActiveAt = stamp;
  currentSession.lastSeenAt = stamp;
  touchRetentionActivity(ws.userId);
  saveData();
  return true;
}

function updatePushToken(ws, msg) {
  if (!rateLimit(ws, 'push_token_update', 30, 60 * 60 * 1000)) {
    return tooManyRequests(ws);
  }

  const session = currentSessionFor(ws);
  if (!session) {
    return send(ws, {
      type: 'error',
      message: 'Session unavailable.',
    });
  }

  const provider = normalizePushProvider(msg.pushProvider);
  const token = normalizePushToken(msg.pushToken);
  if (!provider || !token) {
    return send(ws, {
      type: 'error',
      message: 'Invalid push token.',
    });
  }

  const now = new Date().toISOString();
  session.pushProvider = provider;
  session.pushToken = token;
  session.pushMode = String(msg.pushMode || 'fcm').trim() || 'fcm';
  session.platform = String(msg.platform || session.platform || 'unknown').trim() || 'unknown';
  session.appVersion = normalizeAppVersion(msg.appVersion || session.appVersion);
  session.pushTokenUpdatedAt = now;
  session.lastSeenAt = now;
  ws.platform = session.platform;
  ws.pushMode = session.pushMode;
  ws.deviceId = session.deviceId || ws.deviceId || null;
  saveData();
  logInfo(
    `[push] token registered userId=${ws.userId} sessionId=${session.id || 'none'} ` +
    `deviceId=${session.deviceId || 'unknown'} platform=${session.platform} pushMode=${session.pushMode}`,
  );

  send(ws, {
    type: 'push_token_updated',
    pushProvider: provider,
  });
  sendSessions(ws);
}

function removePushToken(ws, msg) {
  const session = currentSessionFor(ws);
  if (!session) {
    return send(ws, {
      type: 'error',
      message: 'Session unavailable.',
    });
  }

  const provider = normalizePushProvider(msg.pushProvider || session.pushProvider);
  if (provider && session.pushProvider && provider !== session.pushProvider) {
    return send(ws, {
      type: 'error',
      message: 'Push provider mismatch.',
    });
  }

  delete session.pushToken;
  delete session.pushProvider;
  delete session.pushMode;
  delete session.pushTokenUpdatedAt;
  session.appVersion = normalizeAppVersion(msg.appVersion || session.appVersion);
  session.lastSeenAt = new Date().toISOString();
  ws.pushMode = 'none';
  saveData();
  logInfo(
    `[push] token removed userId=${ws.userId} sessionId=${session.id || 'none'} ` +
    `deviceId=${session.deviceId || 'unknown'}`,
  );

  send(ws, { type: 'push_token_removed' });
  sendSessions(ws);
}

function updateClientAppState(ws, msg) {
  const rawState = String(msg.state || msg.appLifecycleState || '').trim();
  const backgroundStates = new Set(['inactive', 'paused', 'detached', 'hidden', 'background', 'minimized']);
  ws.appLifecycleState = backgroundStates.has(rawState) ? 'background' : 'active';
  ws.appLifecycleUpdatedAt = Date.now();
  logDebug(
    `[debug] app state updated userId=${ws.userId || 'unknown'} ` +
    `sessionId=${ws.sessionId || 'none'} state=${ws.appLifecycleState}`,
  );
}

function handleRetentionEvent(ws, msg) {
  const event = String(msg.event || '').trim();
  if (!RETENTION_EVENTS.has(event)) {
    return;
  }
  recordRetentionEvent(ws.userId, event, { source: 'client' });
}

function getCallOffer(ws, msg) {
  const callId = String(msg.callId || '').trim();
  const offer = callId ? pendingCallOffers.get(callId) : null;
  const logUnavailable = (reason) => {
    logDebug(
      `[debug] call signaling rejected reason=${reason} msg.type=get_call_offer ` +
      `callId=${callId || 'empty'} fromUserId=${ws.userId || 'unauthenticated'} ` +
      `toUserId=${offer?.toUserId || 'empty'} targetSocketExists=${offer ? hasOpenSocket(offer.toUserId) : false} ` +
      `recipientOnline=${offer ? isUserOnline(offer.toUserId) : false} hasActiveContact=${offer ? hasActiveContact(offer.fromUserId, offer.toUserId) : false}`,
    );
  };
  if (!offer || offer.toUserId !== ws.userId) {
    logUnavailable(callId ? 'stale_call' : 'missing_callId');
    return send(ws, {
      type: 'call_unavailable',
      callId,
      reason: callId ? 'stale_call' : 'missing_callId',
      message: 'Call unavailable.',
    });
  }
  if (offer.status && offer.status !== 'ringing') {
    pendingCallOffers.delete(callId);
    return send(ws, {
      type: 'missed_call',
      callId,
      fromUserId: offer.fromUserId,
      fromNickname: offer.fromNickname || '',
      timestamp: offer.endedAt || offer.createdAt || Date.now(),
      video: false,
    });
  }
  if (Date.now() > Number(offer.expiresAt || 0)) {
    pendingCallOffers.delete(callId);
    return send(ws, {
      type: 'missed_call',
      callId,
      fromUserId: offer.fromUserId,
      fromNickname: offer.fromNickname || '',
      timestamp: offer.createdAt || Date.now(),
      video: false,
    });
  }
  send(ws, offer.payload);
}

function pushPayloadForMessage(message) {
  return {
    type: 'message',
    messageId: String(message?.id || ''),
    fromUserId: String(message?.fromUserId || ''),
    fromNickname: String(message?.fromNickname || ''),
    timestamp: String(message?.timestamp || message?.serverTimestamp || Date.now()),
  };
}

function pushPayloadForCall(signal) {
  const timestamp = Number(signal?.serverTimestamp || signal?.callCreatedAt || Date.now()) || Date.now();
  return {
    type: 'call',
    callId: String(signal?.callId || ''),
    fromUserId: String(signal?.fromUserId || ''),
    fromNickname: String(signal?.fromNickname || signal?.fromUsername || ''),
    video: signal?.video ? 'true' : 'false',
    timestamp: String(timestamp),
    ttlMs: String(signal?.callOfferTtlMs || CALL_OFFER_TTL_MS),
  };
}

function pushDataPayload(payload) {
  return Object.fromEntries(
    Object.entries(payload || {})
      .filter(([, value]) => value !== null && value !== undefined && String(value).trim() !== '')
      .map(([key, value]) => [key, String(value)]),
  );
}

function loadFcmServiceAccount() {
  if (fcmServiceAccount !== null) {
    return fcmServiceAccount;
  }
  try {
    if (FCM_SERVICE_ACCOUNT_JSON) {
      fcmServiceAccount = JSON.parse(FCM_SERVICE_ACCOUNT_JSON);
      return fcmServiceAccount;
    }
    if (FCM_SERVICE_ACCOUNT_FILE && fs.existsSync(FCM_SERVICE_ACCOUNT_FILE)) {
      fcmServiceAccount = JSON.parse(fs.readFileSync(FCM_SERVICE_ACCOUNT_FILE, 'utf8'));
      return fcmServiceAccount;
    }
  } catch (error) {
    logWarn(`[push] service account load failed: ${error.message}`);
  }
  fcmServiceAccount = false;
  return null;
}

function base64Url(value) {
  return Buffer.from(value)
    .toString('base64')
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=+$/g, '');
}

async function fcmBearerToken() {
  const now = Math.floor(Date.now() / 1000);
  if (fcmAccessToken && fcmAccessTokenExpiresAt - 60 > now) {
    return fcmAccessToken;
  }
  const account = loadFcmServiceAccount();
  if (!account?.client_email || !account?.private_key) {
    return null;
  }
  const header = base64Url(JSON.stringify({ alg: 'RS256', typ: 'JWT' }));
  const claims = base64Url(JSON.stringify({
    iss: account.client_email,
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
    aud: 'https://oauth2.googleapis.com/token',
    iat: now,
    exp: now + 3600,
  }));
  const signature = crypto
    .createSign('RSA-SHA256')
    .update(`${header}.${claims}`)
    .sign(account.private_key, 'base64')
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=+$/g, '');
  const assertion = `${header}.${claims}.${signature}`;
  const response = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion,
    }),
  });
  if (!response.ok) {
    throw new Error(`OAuth token failed: ${response.status}`);
  }
  const body = await response.json();
  fcmAccessToken = body.access_token;
  fcmAccessTokenExpiresAt = now + Number(body.expires_in || 3600);
  return fcmAccessToken;
}

function isInvalidFcmTokenResponse(status, bodyText) {
  if (status === 404 || status === 410) {
    return true;
  }
  if (status !== 400) {
    return false;
  }
  return /UNREGISTERED|INVALID_ARGUMENT|registration token|not a valid FCM/i.test(bodyText || '');
}

async function sendFcmDataMessage(token, payload) {
  const account = loadFcmServiceAccount();
  const projectId = process.env.FIREBASE_PROJECT_ID || account?.project_id;
  if (!account || !projectId) {
    throw new Error('FCM not configured');
  }
  const bearer = await fcmBearerToken();
  if (!bearer) {
    throw new Error('FCM bearer token unavailable');
  }
  const isIncomingCall = payload?.type === 'call';
  const ttlSeconds = Math.max(1, Math.ceil(Number(payload?.ttlMs || CALL_OFFER_TTL_MS) / 1000));
  const message = {
    token,
    data: pushDataPayload(payload),
    android: {
      priority: 'HIGH',
      ...(isIncomingCall ? { ttl: `${ttlSeconds}s` } : {}),
    },
  };
  const response = await fetch(
    `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
    {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${bearer}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        message,
      }),
    },
  );
  if (!response.ok) {
    const bodyText = await response.text().catch(() => '');
    const error = new Error(`FCM send failed: ${response.status}`);
    error.status = response.status;
    error.invalidToken = isInvalidFcmTokenResponse(response.status, bodyText);
    throw error;
  }
  return true;
}

function sendPushToUser(userId, payload, options = {}) {
  const isCallPush = payload?.type === 'call';
  const pushLabel = isCallPush ? 'FCM call push' : 'FCM push';
  if (!FEATURE_PUSH_NOTIFICATIONS) {
    logInfo(`[push] ${pushLabel} attempted=no reason=feature_disabled userId=${userId} type=${payload?.type || 'unknown'}`);
    return;
  }
  const user = findUserById(userId);
  if (!user) {
    logInfo(`[push] ${pushLabel} attempted=no reason=user_not_found userId=${userId} type=${payload?.type || 'unknown'}`);
    return;
  }
  const now = Date.now();
  const dedupKey = [
    userId,
    payload?.type || 'unknown',
    payload?.messageId || payload?.requestId || payload?.callId || payload?.fromUserId || '',
  ].join(':');
  const cooldownMs = Number(options.cooldownMs || 90 * 1000);
  const previousPushAt = pushDedup.get(dedupKey) || 0;
  if (now - previousPushAt < cooldownMs) {
    logInfo(`[push] ${pushLabel} attempted=no reason=dedup_cooldown userId=${userId} type=${payload?.type || 'unknown'} id=${payload?.callId || payload?.messageId || 'none'}`);
    return;
  }
  pushDedup.set(dedupKey, now);
  for (const [key, timestamp] of pushDedup.entries()) {
    if (now - timestamp > 24 * 60 * 60 * 1000) {
      pushDedup.delete(key);
    }
  }
  const sessions = ensureSessions(user)
    .filter((session) =>
      session.id !== options.excludeSessionId &&
      session.pushProvider === 'fcm' &&
      (!options.androidOnly || session.platform === 'android') &&
      typeof session.pushToken === 'string' &&
      session.pushToken.length > 0);
  logInfo(`[push] ${pushLabel} send start userId=${userId} type=${payload?.type || 'unknown'} id=${payload?.callId || payload?.messageId || 'none'}`);
  logInfo(`[push] ${pushLabel} recipient token count userId=${userId} count=${sessions.length}`);
  for (const session of sessions) {
    sendFcmDataMessage(session.pushToken, payload)
      .then(() => {
        logInfo(`[push] ${pushLabel} success userId=${userId} deviceId=${session.deviceId || 'unknown'} id=${payload?.callId || payload?.messageId || 'none'}`);
      })
      .catch((error) => {
        logWarn(`[push] ${pushLabel} failure userId=${userId} deviceId=${session.deviceId || 'unknown'} error=${error.message}`);
        if (error.invalidToken) {
          delete session.pushToken;
          delete session.pushProvider;
          delete session.pushMode;
          delete session.pushTokenUpdatedAt;
          session.lastSeenAt = new Date().toISOString();
          saveData();
          logWarn(`[push] invalid token cleanup userId=${userId} deviceId=${session.deviceId || 'unknown'} provider=fcm`);
        }
      });
  }
}

function sendUsers(ws, currentUserId) {
  send(ws, {
    type: 'users',
    users: data.contacts
      .filter((contact) =>
        contact.status === 'active' && contact.userId === currentUserId)
      .map((contact) => {
        const peerUserId = contact.userId === currentUserId ? contact.peerUserId : contact.userId;
        const peer = findUserById(peerUserId);
        return peer ? publicUser(peer) : null;
      })
      .filter(Boolean),
  });
}

function findUserByUsernameExact(ws, msg) {
  if (!rateLimit(ws, 'username_lookup', 20, 60 * 1000)) {
    logDebug(`[debug] username lookup rate_limited requester=${ws.userId || 'unknown'}`);
    return tooManyRequests(ws);
  }

  const query = String(msg.username || '').trim();
  logDebug(`[debug] username lookup request requester=${ws.userId} queryLength=${query.length}`);
  if (!query) {
    logDebug(`[debug] username lookup result requester=${ws.userId} reason=empty_query`);
    return send(ws, { type: 'user_search_result', user: null });
  }
  const user = findUserByNickname(query);
  if (!user) {
    logDebug(`[debug] username lookup result requester=${ws.userId} reason=not_found`);
    return send(ws, { type: 'user_search_result', user: null });
  }
  if (user.id === ws.userId) {
    logDebug(`[debug] username lookup result requester=${ws.userId} target=${user.id} reason=self`);
    return send(ws, { type: 'user_search_result', user: null });
  }
  if (user.allowUserDiscovery === false) {
    logDebug(
      `[debug] username lookup result requester=${ws.userId} target=${user.id} reason=discovery_disabled`,
    );
    return send(ws, { type: 'user_search_result', user: null });
  }
  if (isBlockedBy(user.id, ws.userId) || isBlockedBy(ws.userId, user.id)) {
    logDebug(`[debug] username lookup result requester=${ws.userId} target=${user.id} reason=blocked`);
    return send(ws, { type: 'user_search_result', user: null });
  }
  logDebug(`[debug] username lookup result requester=${ws.userId} target=${user.id} reason=found`);
  send(ws, { type: 'user_search_result', user: publicUser(user) });
}

function sendContactRequest(ws, msg) {
  if (!rateLimit(ws, 'contact_request', 10, 60 * 60 * 1000)) {
    return tooManyRequests(ws);
  }

  const toUserId = String(msg.toUserId || '').trim();
  const sender = findUserById(ws.userId);
  const recipient = findUserById(toUserId);
  if (!sender || !recipient || sender.id === recipient.id) return;
  if (!pairCooldown(
    repeatedContactRequests,
    `${sender.id}:${recipient.id}`,
    6 * 60 * 60 * 1000,
  )) {
    return tooManyRequests(ws);
  }
  if (isBlockedBy(recipient.id, sender.id) || isBlockedBy(sender.id, recipient.id)) return;
  if (hasActiveContact(sender.id, recipient.id)) return;

  const existing = data.contactRequests.find((request) =>
    request.status === 'pending' &&
    request.fromUserId === sender.id &&
    request.toUserId === recipient.id);
  if (existing) return;

  const request = {
    id: uuidv4(),
    fromUserId: sender.id,
    toUserId: recipient.id,
    fromUsername: sender.nickname,
    status: 'pending',
    createdAt: new Date().toISOString(),
  };
  data.contactRequests.push(request);
  saveData();

  const delivered = sendToUser(recipient.id, {
    type: 'contact_request',
    request: requestDto(request),
  });
  logDebug(
    `[debug] contact request ${delivered > 0 ? 'forwarded' : 'recipient offline'} from=${sender.id} to=${recipient.id} sockets=${delivered}`,
  );
  send(ws, { type: 'contact_request_sent', request: requestDto(request) });
}

function acceptContactRequest(ws, msg) {
  const requestId = String(msg.id || '').trim();
  const request = data.contactRequests.find(
    (item) => item.id === requestId && item.toUserId === ws.userId && item.status === 'pending',
  );
  if (!request) return;
  if (isBlockedBy(request.toUserId, request.fromUserId) ||
      isBlockedBy(request.fromUserId, request.toUserId)) return;
  const contactState = contactStateBetween(request.fromUserId, request.toUserId);
  if (contactState.senderHasActiveContact && contactState.recipientHasActiveContact) return;

  request.status = 'accepted';
  const fromUser = findUserById(request.fromUserId);
  const toUser = findUserById(request.toUserId);
  if (!contactState.senderHasActiveContact) {
    data.contacts.push({
      userId: request.fromUserId,
      peerUserId: request.toUserId,
      username: toUser?.nickname || '',
      status: 'active',
      createdAt: new Date().toISOString(),
    });
  }
  if (!contactState.recipientHasActiveContact) {
    data.contacts.push({
      userId: request.toUserId,
      peerUserId: request.fromUserId,
      username: fromUser?.nickname || request.fromUsername || '',
      status: 'active',
      createdAt: new Date().toISOString(),
    });
  }
  recordRetentionEvent(request.fromUserId, 'first_contact_added', {
    source: 'contact_request',
  });
  recordRetentionEvent(request.toUserId, 'first_contact_added', {
    source: 'contact_request',
  });
  saveData();

  for (const socket of userSockets(request.fromUserId)) {
    sendContacts(socket, request.fromUserId);
  }
  for (const socket of userSockets(request.toUserId)) {
    sendContacts(socket, request.toUserId);
    sendContactRequests(socket, request.toUserId);
  }
}

function declineContactRequest(ws, msg) {
  const requestId = String(msg.id || '').trim();
  const request = data.contactRequests.find(
    (item) => item.id === requestId && item.toUserId === ws.userId && item.status === 'pending',
  );
  if (!request) return;
  request.status = 'declined';
  saveData();
  sendContactRequests(ws, ws.userId);
}

function blockUser(ws, msg) {
  const blockedUserId = String(msg.userId || '').trim();
  if (!findUserById(blockedUserId) || blockedUserId === ws.userId) return;
  if (!isBlockedBy(ws.userId, blockedUserId)) {
    data.blocks.push({ userId: ws.userId, blockedUserId, createdAt: new Date().toISOString() });
  }
  for (const contact of data.contacts) {
    if (contact.userId === ws.userId && contact.peerUserId === blockedUserId) {
      contact.status = 'blocked';
    }
  }
  saveData();
  sendContacts(ws, ws.userId);
}

function updatePrivacySettings(ws, msg) {
  const user = findUserById(ws.userId);
  if (!user) return;
  user.allowUserDiscovery = msg.allowUserDiscovery !== false;
  saveData();
}

function unblockUser(ws, msg) {
  const blockedUserId = String(msg.userId || '').trim();
  data.blocks = data.blocks.filter(
    (item) => !(item.userId === ws.userId && item.blockedUserId === blockedUserId),
  );
  for (const contact of data.contacts) {
    if (contact.userId === ws.userId && contact.peerUserId === blockedUserId) {
      contact.status = 'active';
    }
  }
  saveData();
  sendContacts(ws, ws.userId);
}

function revokeSession(ws, msg) {
  const user = findUserById(ws.userId);
  if (!user) return;
  const sessionId = String(msg.sessionId || '').trim();
  if (!sessionId || sessionId === ws.sessionId) {
    return;
  }
  const before = ensureSessions(user).length;
  user.sessions = user.sessions.filter((session) => session.id !== sessionId);
  if (user.sessions.length !== before) {
    for (const client of allClientSockets()) {
      if (client.userId === user.id && client.sessionId === sessionId) {
        send(client, { type: 'session_revoked' });
        client.close();
      }
    }
    saveData();
  }
  sendSessions(ws);
}

function logoutSession(ws) {
  const user = findUserById(ws.userId);
  if (user && ws.sessionId) {
    user.sessions = ensureSessions(user).filter(
      (session) => session.id !== ws.sessionId,
    );
    saveData();
  }
  send(ws, { type: 'logout_ok' });
  ws.close();
}

function auth(ws, msg) {
  if (!rateLimit(ws, 'auth_attempt', 20, 15 * 60 * 1000)) {
    return tooManyRequests(ws);
  }

  const requestedNickname = String(msg.nickname || '').trim();
  const requestedUserId = String(msg.userId || '').trim();
  const requestedPassword = String(msg.password || '');
  const requestedToken = String(msg.authToken || '').trim();
  const requestedPublicKey = normalizePublicKey(msg.publicKey);

  if (requestedUserId && requestedToken) {
    const user = findUserById(requestedUserId);
    const existingSession = user ? findSessionByToken(user, requestedToken) : null;
    const legacyTokenAccepted = user && user.token === requestedToken;
    if (!user || (!existingSession && !legacyTokenAccepted)) {
      return send(ws, {
        type: 'error',
        message: 'Saved session expired. Please log in again.',
      });
    }
    if (user.disabled === true) {
      return send(ws, {
        type: 'error',
        message: 'Account unavailable.',
      });
    }

    let authDataChanged = false;

    const session = existingSession || createSession(user, msg);
    if (requestedPublicKey && user.publicKey !== requestedPublicKey) {
      user.publicKey = requestedPublicKey;
      authDataChanged = true;
    }
    if (existingSession) {
      const now = Date.now();
      const previous = session.lastActiveAt ? Date.parse(session.lastActiveAt) : 0;
      if (!Number.isFinite(previous) || now - previous >= SESSION_TOUCH_INTERVAL_MS) {
        const stamp = new Date(now).toISOString();
        session.lastActiveAt = stamp;
        session.lastSeenAt = stamp;
        authDataChanged = true;
      }
      const appVersion = normalizeAppVersion(msg.appVersion || session.appVersion);
      if (appVersion && session.appVersion !== appVersion) {
        session.appVersion = appVersion;
        authDataChanged = true;
      }
      const pushMode = String(msg.pushMode || '').trim();
      if (pushMode && session.pushMode !== pushMode) {
        session.pushMode = pushMode;
        authDataChanged = true;
      }
    } else {
      const pushMode = String(msg.pushMode || '').trim();
      if (pushMode) {
        session.pushMode = pushMode;
      }
      authDataChanged = true;
    }
    if (authDataChanged) {
      saveData();
    }
    if (legacyTokenAccepted) {
      delete user.token;
      saveData();
    }
    return finishAuth(ws, user, session, msg);
  }

  if (!requestedNickname) {
    return send(ws, {
      type: 'error',
      message: 'Nickname is required',
    });
  }

  if (!requestedPassword) {
    return send(ws, {
      type: 'error',
      message: 'Password is required',
    });
  }

  const user = findUserByNickname(requestedNickname);
  if (!user) {
    return send(ws, {
      type: 'error',
      message: 'User not found. Please register first.',
    });
  }

  if (user.disabled === true) {
    return send(ws, {
      type: 'error',
      message: 'Account unavailable.',
    });
  }

  if (!user.passwordHash) {
    return send(ws, {
      type: 'error',
      message: 'This account has no password. Ask the server owner to reset it.',
    });
  }

  if (!verifyPassword(requestedPassword, user.passwordHash)) {
    const failKey = `${clientAddress(ws)}:${requestedNickname.toLowerCase()}`;
    if (!bucketAllowed(failedLoginBuckets, failKey, 5, 15 * 60 * 1000)) {
      return tooManyRequests(ws);
    }
    return send(ws, {
      type: 'error',
      message: 'Wrong password.',
    });
  }

  const session = createSession(user, msg);
  if (requestedPublicKey) {
    user.publicKey = requestedPublicKey;
  }
  if (isLegacyPasswordHash(user.passwordHash)) {
    user.passwordHash = hashPassword(requestedPassword);
  }
  saveData();
  finishAuth(ws, user, session, msg);
}

function register(ws, msg) {
  if (!rateLimit(ws, 'register', 5, 60 * 60 * 1000)) {
    return tooManyRequests(ws);
  }

  if (!REGISTRATION_ENABLED) {
    return send(ws, {
      type: 'error',
      message: 'Registration is disabled.',
    });
  }

  const requestedNickname = String(msg.nickname || '').trim();
  const requestedNicknameKey = normalizeUsernameKey(requestedNickname);
  const requestedPassword = String(msg.password || '');
  const requestedPublicKey = normalizePublicKey(msg.publicKey);
  const inviteCode = String(msg.inviteCode || '').trim();

  if (INVITE_ONLY && !INVITE_CODES.has(inviteCode)) {
    return send(ws, {
      type: 'error',
      message: 'Registration is invite-only.',
    });
  }

  if (requestedNickname.length < 2 || requestedNicknameKey.length < 2) {
    return send(ws, {
      type: 'error',
      message: 'Nickname must be at least 2 characters.',
    });
  }

  if (requestedNickname.length > 32 || !/^[\p{L}\p{N}._ -]+$/u.test(requestedNickname)) {
    return send(ws, {
      type: 'error',
      message: 'Nickname contains unsupported characters.',
    });
  }

  if (requestedPassword.length < 6) {
    return send(ws, {
      type: 'error',
      message: 'Password must be at least 6 characters.',
    });
  }

  if (!requestedPublicKey) {
    return send(ws, {
      type: 'error',
      message: 'Encryption public key is required.',
    });
  }

  if (findUserByNickname(requestedNickname)) {
    return send(ws, {
      type: 'error',
      message: 'This nickname is already registered.',
    });
  }

  const user = {
    id: uuidv4(),
    nickname: requestedNickname,
    nicknameNormalized: requestedNicknameKey,
    passwordHash: hashPassword(requestedPassword),
    publicKey: requestedPublicKey,
    createdAt: new Date().toISOString(),
  };

  users.push(user);
  const session = createSession(user, msg);
  recordRetentionEvent(user.id, 'user_registered', { source: 'register' });
  saveData();

  finishAuth(ws, user, session, msg);
}

function relayMessage(ws, msg) {
  const requestedMessageId = String(msg.id || '').trim();
  const messageId = requestedMessageId || uuidv4();
  const toUserId = String(msg.toUserId || '').trim();
  const rawText = typeof msg.text === 'string' ? msg.text : '';
  const hasText = rawText.trim().length > 0;
  const hasCiphertext = rawText.startsWith('HESTIA_TEXT_V1:');
  const recipientPublicKey = normalizePublicKey(msg.recipientPublicKey);
  const rawClientTimestamp = Number(msg.clientCreatedAt || msg.clientTimestamp || msg.timestamp || 0);
  const clientTimestamp = Number.isFinite(rawClientTimestamp) && rawClientTimestamp > 0
    ? rawClientTimestamp
    : null;
  const rawTimestamp = Number(msg.timestamp || 0);
  const rawClientCreatedAt = Number(msg.clientCreatedAt || msg.clientCreatedAtMs || rawClientTimestamp || 0);
  const messageFieldKeys = Object.keys(msg).filter((key) =>
    !['text', 'password', 'authToken', 'token', 'privateKey'].includes(key));
  const fail = (reason, logReason = reason, senderId = ws.userId || 'unauthenticated') => {
    logDebug(
      `[debug] message rejected sender=${senderId} to=${toUserId || 'empty'} ` +
      `messageId=${messageId || 'empty'} reason=${logReason}`,
    );
    return sendMessageFailed(ws, messageId, reason, {
      senderId,
      toUserId,
    });
  };

  if (!ws.userId) {
    return fail('unauthenticated', 'unauthenticated');
  }
  logDebug(
    `[debug] message frame messageId=${messageId || 'empty'} ` +
    `fromUserId=${ws.userId} toUserId=${toUserId || 'empty'} ` +
    `sessionId=${ws.sessionId || 'none'} hasText=${hasText} ` +
    `hasCiphertext=${hasCiphertext} hasRecipientPublicKey=${recipientPublicKey !== ''} ` +
    `clientTimestamp=${clientTimestamp || 0} timestamp=${Number.isFinite(rawTimestamp) ? rawTimestamp : 0} ` +
    `clientCreatedAt=${Number.isFinite(rawClientCreatedAt) ? rawClientCreatedAt : 0} ` +
    `payloadKeys=${messageFieldKeys.join(',')}`,
  );
  if (!rateLimit(ws, 'message_relay', 120, 60 * 1000)) {
    return fail('rate_limited', 'rate_limited');
  }

  const sender = findUserById(ws.userId);
  if (!sender) {
    return fail('sender_unavailable', 'sender_not_found');
  }

  if (!toUserId) {
    return fail('invalid_recipient', 'invalid_or_missing_toUserId', sender.id);
  }

  const recipient = findUserById(toUserId);
  if (!recipient) {
    return fail('recipient_unavailable', 'recipient_not_found', sender.id);
  }
  const contactState = contactStateBetween(sender.id, recipient.id);
  const activeContact = contactState.senderHasActiveContact && contactState.recipientHasActiveContact;
  const senderBlocked = isBlockedBy(sender.id, recipient.id);
  const recipientBlocked = isBlockedBy(recipient.id, sender.id);
  const targetSocketExists = hasOpenSocket(recipient.id);
  logDebug(
    `[debug] message route messageId=${messageId || 'empty'} ` +
    `fromUserId=${sender.id} toUserId=${recipient.id} ` +
    `senderHasActiveContact=${contactState.senderHasActiveContact} ` +
    `recipientHasActiveContact=${contactState.recipientHasActiveContact} ` +
    `senderContactCount=${contactState.senderContactCount} ` +
    `recipientContactCount=${contactState.recipientContactCount} ` +
    `mutualActiveContact=${activeContact} senderBlocked=${senderBlocked} ` +
    `recipientBlocked=${recipientBlocked} recipientOnline=${targetSocketExists}`,
  );
  if (!activeContact) {
    logDebug(
      `[debug] message contact metadata broken=${contactState.senderHasActiveContact !== contactState.recipientHasActiveContact} ` +
      `sender=${sender.id} to=${recipient.id} senderContactCount=${contactState.senderContactCount} ` +
      `recipientContactCount=${contactState.recipientContactCount}`,
    );
  }
  if (!activeContact) {
    return fail('recipient_unavailable', 'not_active_contact', sender.id);
  }
  if (senderBlocked) {
    return fail('recipient_unavailable', 'blocked_by_sender', sender.id);
  }
  if (recipientBlocked) {
    return fail('recipient_unavailable', 'blocked_by_recipient', sender.id);
  }

  if (!messageId || messageId.length > 80) {
    return fail('invalid_message', 'invalid_message_id', sender.id);
  }
  const text = boundedString(msg.text, MAX_TEXT_BYTES);
  if (text === null) {
    return fail('invalid_message', 'text_too_large', sender.id);
  }
  if (!text && !msg.attachment) {
    return fail('invalid_message', 'empty_text_payload', sender.id);
  }
  if (text && !text.startsWith('HESTIA_TEXT_V1:')) {
    return fail('invalid_message', 'empty_or_invalid_ciphertext_payload', sender.id);
  }
  if (recipient.publicKey && recipientPublicKey && recipientPublicKey !== recipient.publicKey) {
    return fail('encryption_key_mismatch', 'recipient_key_mismatch', sender.id);
  }
  if (!FEATURE_FILE_ATTACHMENTS && msg.attachment) {
    return fail('invalid_message', 'attachments_disabled', sender.id);
  }

  const attachmentResult = normalizeAttachment(msg.attachment, {
    senderId: sender.id,
    recipientId: recipient.id,
    messageId,
  });
  if (!attachmentResult.ok) {
    return fail('invalid_message', 'attachment_unavailable', sender.id);
  }

  const serverTimestamp = Date.now();
  const serverSequence = nextMessageSequence();
  const payload = {
    id: messageId,
    fromUserId: sender.id,
    fromNickname: sender.nickname,
    toUserId: recipient.id,
    recipientPublicKey: recipientPublicKey || null,
    text,
    timestamp: clientTimestamp || serverTimestamp,
    clientTimestamp,
    clientCreatedAt: clientTimestamp,
    serverTimestamp,
    serverReceivedAt: serverTimestamp,
    serverSequence,
    attachment: attachmentResult.attachment,
  };

  logMessageAttachmentDebug(`relay payload sender=${sender.id} to=${recipient.id}`, payload);
  logDebug(
    `[debug] message sort relay id=${payload.id} direction=backend ` +
    `clientTimestamp=${clientTimestamp || 0} serverTimestamp=${serverTimestamp} ` +
    `serverSequence=${serverSequence}`,
  );
  logDebug(`[debug] message relay accepted sender=${sender.id} to=${recipient.id}`);
  recordRetentionEvent(sender.id, 'first_message_sent', { source: 'message' });
  recordRetentionEvent(recipient.id, 'first_message_received', { source: 'message' });
  saveData();
  pendingDeliveries.set(payload.id, {
    senderUserId: sender.id,
    blobId: payload.attachment?.blobId || null,
    createdAt: Date.now(),
  });
  const deliveredCount = sendToUser(recipient.id, {
    type: 'new_message',
    message: payload,
  });
  const recipientAndroidTokenCount = androidPushSessions(recipient).length;
  logInfo(
    `[push-debug] message route recipient=${recipient.id} messageId=${messageId} ` +
    `activeSockets=${activeUserSockets(recipient.id).length} openSockets=${userSockets(recipient.id).length} ` +
    `androidSockets=${androidSocketCount(recipient.id)} androidSocketsWithoutFcm=${androidSocketWithoutFcmCount(recipient, recipient.id)} ` +
    `foregroundServiceSockets=${foregroundServiceSocketCount(recipient.id)} ` +
    `socketStates=${socketStateSummary(recipient.id) || 'none'} ` +
    `recipientSessions=${recipientSessionSummary(recipient) || 'none'} ` +
    `androidTokens=${recipientAndroidTokenCount} pushSessions=${pushSessionSummary(recipient) || 'none'} ` +
    `forwardedToSocket=${deliveredCount > 0} forwardedSockets=${deliveredCount} ` +
    `fcmAttempted=${deliveredCount === 0 || !hasActiveSocket(recipient.id)}`,
  );
  if (deliveredCount === 0) {
    logDebug(
      `[debug] message recipient offline sender=${sender.id} to=${recipient.id} ` +
      `messageId=${messageId}`,
    );
    const queueResult = queueOfflineMessage(recipient.id, payload);
    if (!queueResult.ok) {
      pendingDeliveries.delete(payload.id);
      return fail('queue_failed', 'queue_failed', sender.id);
    }
    logDebug(
      `[debug] message queued offline sender=${sender.id} to=${recipient.id} ` +
      `messageId=${messageId}`,
    );
    sendPushToUser(recipient.id, pushPayloadForMessage(payload));
  } else {
    logDebug(
      `[debug] message forwarded online sender=${sender.id} to=${recipient.id} ` +
      `messageId=${messageId} sockets=${deliveredCount}`,
    );
    if (!hasActiveSocket(recipient.id)) {
      logDebug(
        `[debug] message recipient background sender=${sender.id} to=${recipient.id} ` +
        `messageId=${messageId} sockets=${deliveredCount}`,
      );
      sendPushToUser(recipient.id, pushPayloadForMessage(payload), {
        excludeSessionId: ws.sessionId,
      });
    }
  }
  logDebug(
    `[debug] message relay ${deliveredCount > 0 ? 'forwarded' : 'queued'} sender=${sender.id} to=${recipient.id} sockets=${deliveredCount}`,
  );

  send(ws, {
    type: 'message_sent',
    message: payload,
    delivered: deliveredCount > 0,
  });
}

function relayCallSignal(ws, msg) {
  const rawType = String(msg.type || 'unknown');
  const rawToUserId = String(msg.toUserId || '').trim();
  const callId = String(msg.callId || '').trim();
  let sender = null;
  let recipient = null;
  let targetOnline = false;
  let targetSocketExists = false;
  let activeContact = false;
  let blockedBySender = false;
  let blockedByRecipient = false;
  let forwarded = 0;
  let signalType = rawType;
  let contactState = null;
  let callOfferInitFcmAttempted = false;

  const logCallEvent = (stage, reason = 'none') => {
    logDebug(
      `[debug] call signaling ${stage} reason=${reason} ` +
      `msg.type=${rawType} forwardedType=${signalType || 'none'} ` +
      `callId=${callId || 'empty'} fromUserId=${ws.userId || 'unauthenticated'} ` +
      `toUserId=${rawToUserId || 'empty'} senderExists=${sender !== null} ` +
      `recipientExists=${recipient !== null} recipientOnline=${targetOnline} ` +
      `targetSocketExists=${targetSocketExists} hasActiveContact=${activeContact} ` +
      `senderHasActiveContact=${contactState?.senderHasActiveContact ?? false} ` +
      `recipientHasActiveContact=${contactState?.recipientHasActiveContact ?? false} ` +
      `blockedBySender=${blockedBySender} blockedByRecipient=${blockedByRecipient} ` +
      `voiceCalls=${FEATURE_VOICE_CALLS ? 'enabled' : 'disabled'} forwarded=${forwarded > 0}`,
    );
  };
  const logCallOfferInitRoute = (stage, reason = 'none') => {
    if (rawType !== 'call_offer_init') {
      return;
    }
    const targetUser = recipient || (rawToUserId ? findUserById(rawToUserId) : null);
    const targetUserId = targetUser?.id || rawToUserId || 'empty';
    const fcmTokenCount = targetUser ? androidPushSessions(targetUser).length : 0;
    logInfo(
      `[call-offer-init-debug] stage=${stage} reason=${reason} ` +
      `callerUserId=${ws.userId || 'unauthenticated'} targetUserId=${targetUserId} callId=${callId || 'empty'} ` +
      `targetActiveSockets=${activeUserSockets(targetUserId).length} targetOpenSockets=${userSockets(targetUserId).length} ` +
      `targetSessions=${targetUser ? recipientSessionSummary(targetUser) || 'none' : 'none'} ` +
      `targetPlatforms=${targetUser ? targetPlatformSummary(targetUser, targetUserId) : 'none'} ` +
      `contactActive=${activeContact} senderHasActiveContact=${contactState?.senderHasActiveContact ?? false} ` +
      `recipientHasActiveContact=${contactState?.recipientHasActiveContact ?? false} ` +
      `blockedByCaller=${blockedBySender} blockedByTarget=${blockedByRecipient} ` +
      `forwardedSockets=${forwarded} forwardedToSockets=${forwarded > 0} ` +
      `pushedViaFcm=${callOfferInitFcmAttempted && fcmTokenCount > 0} fcmTokens=${fcmTokenCount}`,
    );
  };

  if (!FEATURE_VOICE_CALLS && !FEATURE_VIDEO_CALLS) {
    logCallEvent('rejected', 'voice_calls_disabled');
    logCallOfferInitRoute('rejected', 'voice_calls_disabled');
    return send(ws, {
      type: 'call_unavailable',
      callId: String(msg.callId || ''),
      reason: 'voice_calls_disabled',
    });
  }
  if (!ws.userId) {
    logCallEvent('rejected', 'unauthenticated');
    logCallOfferInitRoute('rejected', 'unauthenticated');
    return;
  }
  if (!rateLimit(ws, 'call_signal', 600, 60 * 1000)) {
    logCallEvent('rejected', 'rate_limited');
    logCallOfferInitRoute('rejected', 'rate_limited');
    return send(ws, {
      type: 'call_unavailable',
      callId,
      reason: 'rate_limited',
      message: 'Too many requests. Try again later.',
    });
  }

  const allowedTypes = new Set([
    'call_offer_init',
    'call_offer',
    'call_answer',
    'call_ice_candidate',
    'call_reject',
    'call_rejected',
    'call_hangup',
  ]);
  if (!allowedTypes.has(rawType)) {
    logCallEvent('rejected', 'invalid_payload');
    logCallOfferInitRoute('rejected', 'invalid_payload');
    return send(ws, {
      type: 'call_unavailable',
      callId,
      reason: 'invalid_payload',
      message: 'Call unavailable.',
    });
  }
  signalType = normalizeCallSignalType(rawType);
  logCallEvent('accepted');
  const callUnavailable = (reason, message = 'Call unavailable.') => {
    logCallEvent('rejected', reason);
    logCallOfferInitRoute('rejected', reason);
    return send(ws, {
      type: 'call_unavailable',
      callId,
      reason,
      message,
    });
  };
  logCallEvent('received');
  if (!callId) {
    return callUnavailable('missing_callId');
  }
  if (callId.length > 80) {
    return callUnavailable('invalid_payload');
  }
  if (!rawToUserId) {
    return callUnavailable('missing_toUserId');
  }
  if ((signalType === 'call_offer' || signalType === 'call_answer') &&
      typeof msg.sdp === 'string' &&
      boundedString(msg.sdp, MAX_CALL_SDP_BYTES) === null) {
    return callUnavailable('invalid_payload');
  }
  if (signalType === 'call_ice_candidate' &&
      boundedString(msg.candidate, MAX_CALL_ICE_BYTES) === null) {
    return callUnavailable('invalid_payload');
  }

  sender = findUserById(ws.userId);
  recipient = findUserById(rawToUserId);
  if (rawType === 'call_offer_init') {
    if (!rateLimit(ws, 'call_offer', 8, 60 * 1000)) {
      return callUnavailable('rate_limited');
    }
    if (!pairCooldown(callCooldowns, `${ws.userId}:${rawToUserId}`, 30 * 1000)) {
      return callUnavailable('cooldown');
    }
  }
  if (msg.video === true && !FEATURE_VIDEO_CALLS) {
    return callUnavailable('invalid_payload', 'Video calls are disabled.');
  }

  if (!sender) {
    return callUnavailable('invalid_payload', 'User not found.');
  }
  if (!recipient) {
    return callUnavailable('recipient_not_found', 'User not found.');
  }
  contactState = contactStateBetween(sender.id, recipient.id);
  activeContact = hasActiveContact(sender.id, recipient.id);
  blockedBySender = isBlockedBy(sender.id, recipient.id);
  blockedByRecipient = isBlockedBy(recipient.id, sender.id);
  targetSocketExists = hasOpenSocket(recipient.id);
  targetOnline = isUserOnline(recipient.id);
  logCallEvent('routed');
  logCallOfferInitRoute('routed');
  if (blockedBySender || blockedByRecipient) {
    return callUnavailable('blocked', 'User is unavailable.');
  }
  if (!activeContact) {
    return callUnavailable('not_active_contact', 'User is unavailable.');
  }

  const signal = {
    ...msg,
    type: rawType === 'call_offer_init' ? 'call_offer_init' : signalType,
    callId,
    callCreatedAt: Number(msg.callCreatedAt || msg.serverTimestamp || 0) || Date.now(),
    serverTimestamp: Date.now(),
    callOfferTtlMs: CALL_OFFER_TTL_MS,
    sdp: typeof msg.sdp === 'string' ? msg.sdp : undefined,
    candidate: typeof msg.candidate === 'string' ? msg.candidate : undefined,
    fromUserId: sender.id,
    fromNickname: sender.nickname,
    senderPublicKey: sender.publicKey || null,
  };

  const existingPendingOffer = pendingCallOffers.get(callId);
  const signalEndsPendingOffer =
    rawType === 'call_reject' ||
    rawType === 'call_rejected' ||
    rawType === 'call_hangup' ||
    signalType === 'call_answer';
  if (signalEndsPendingOffer && existingPendingOffer && (
      (existingPendingOffer.fromUserId === sender.id && existingPendingOffer.toUserId === recipient.id) ||
      (existingPendingOffer.fromUserId === recipient.id && existingPendingOffer.toUserId === sender.id))) {
    existingPendingOffer.status =
      signalType === 'call_answer' ? 'answered' :
      rawType === 'call_hangup' ? (msg.reason === 'timeout' ? 'timed_out' : 'ended') :
      'rejected';
    existingPendingOffer.endedAt = Date.now();
    existingPendingOffer.endedExpiresAt = Date.now() + CALL_OFFER_TTL_MS;
    pendingCallOffers.set(callId, existingPendingOffer);
  }

  if (!targetOnline && rawType !== 'call_offer_init') {
    return callUnavailable('recipient_offline', 'User is offline.');
  }

  if (rawType === 'call_offer_init') {
    recordRetentionEvent(sender.id, 'call_started', { source: 'call' });
    recordRetentionEvent(recipient.id, 'call_received', { source: 'call' });
    pendingCallOffers.set(callId, {
      toUserId: recipient.id,
      fromUserId: sender.id,
      fromNickname: sender.nickname,
      payload: signal,
      createdAt: signal.callCreatedAt,
      expiresAt: signal.callCreatedAt + CALL_OFFER_TTL_MS,
      status: 'ringing',
    });
    logInfo(
      `[push-debug] call route recipient=${recipient.id} callId=${callId} ` +
      `activeSockets=${activeUserSockets(recipient.id).length} openSockets=${userSockets(recipient.id).length} ` +
      `androidSockets=${androidSocketCount(recipient.id)} androidSocketsWithoutFcm=${androidSocketWithoutFcmCount(recipient, recipient.id)} ` +
      `foregroundServiceSockets=${foregroundServiceSocketCount(recipient.id)} ` +
      `socketStates=${socketStateSummary(recipient.id) || 'none'} ` +
      `recipientSessions=${recipientSessionSummary(recipient) || 'none'} ` +
      `androidTokens=${androidPushSessions(recipient).length} pushSessions=${pushSessionSummary(recipient) || 'none'} ` +
      'fcmAttempted=true',
    );
    callOfferInitFcmAttempted = true;
    logCallOfferInitRoute('push_start');
    sendPushToUser(recipient.id, pushPayloadForCall(signal), {
      androidOnly: true,
      cooldownMs: 45 * 1000,
    });
    logDebug(
      `[debug] call push sent sender=${sender.id} to=${recipient.id} callId=${callId} targetOnline=${targetOnline}`,
    );
    if (!targetOnline) {
      logDebug(
        `[debug] call signal queued_for_push sender=${sender.id} to=${recipient.id} type=${rawType} forwardedType=${signalType} callId=${callId}`,
      );
      logCallOfferInitRoute('queued_for_push', 'target_offline');
      return;
    }
  } else if (
    rawType === 'call_reject' ||
    rawType === 'call_rejected' ||
    rawType === 'call_hangup' ||
    signalType === 'call_answer'
  ) {
    if (targetOnline || signalType === 'call_answer') {
      pendingCallOffers.delete(callId);
    }
  }

  forwarded = sendToUser(recipient.id, signal);
  logCallOfferInitRoute('forwarded');
  logInfo(
    `[push-debug] call forward recipient=${recipient.id} callId=${callId} ` +
    `forwardedToSocket=${forwarded > 0} forwardedSockets=${forwarded} ` +
    `activeSockets=${activeUserSockets(recipient.id).length} openSockets=${userSockets(recipient.id).length} ` +
    `androidSockets=${androidSocketCount(recipient.id)} androidSocketsWithoutFcm=${androidSocketWithoutFcmCount(recipient, recipient.id)} ` +
    `foregroundServiceSockets=${foregroundServiceSocketCount(recipient.id)} ` +
    `socketStates=${socketStateSummary(recipient.id) || 'none'} ` +
    `recipientSessions=${recipientSessionSummary(recipient) || 'none'}`,
  );
  if (forwarded === 0) {
    return callUnavailable('recipient_offline', 'User is offline.');
  }
  logCallEvent('forwarded');
}

function normalizeCallSignalType(type) {
  switch (type) {
    case 'call_offer_init':
    case 'call_sdp_offer':
      return 'call_offer';
    case 'call_accepted':
    case 'call_sdp_answer':
      return 'call_answer';
    case 'call_ice':
      return 'call_ice_candidate';
    case 'call_rejected':
      return 'call_reject';
    case 'call_ended':
      return 'call_hangup';
    default:
      return type;
  }
}

function normalizeAttachment(attachment, context = {}) {
  if (!attachment || typeof attachment !== 'object') {
    return { ok: true, attachment: null };
  }

  const blobId = typeof attachment.blobId === 'string' ? attachment.blobId.trim() : '';
  if (blobId) {
    const blob = findBlobById(blobId);
    if (!blob ||
        blob.senderUserId !== context.senderId ||
        blob.recipientUserId !== context.recipientId ||
        (blob.messageId && context.messageId && blob.messageId !== context.messageId)) {
      logDebug(
        `[debug] attachment blob unavailable blobId=${blobId} sender=${context.senderId || ''} recipient=${context.recipientId || ''} messageId=${context.messageId || ''}`,
      );
      return { ok: false, message: 'Attachment is unavailable.' };
    }
    if (Number(blob.expiresAt || 0) <= Date.now()) {
      deleteStoredBlob(blob);
      data.blobs = data.blobs.filter((item) => item.blobId !== blob.blobId);
      saveData();
      return { ok: false, message: 'Attachment is unavailable.' };
    }
    const filePath = safeAttachmentBlobPath(blob.fileName || blob.filePath);
    if (!filePath || !fs.existsSync(filePath)) {
      data.blobs = data.blobs.filter((item) => item.blobId !== blob.blobId);
      saveData();
      logWarn(`[blob] missing file for blobId=${blob.blobId}`);
      return { ok: false, message: 'Attachment is unavailable.' };
    }
    blob.state = 'attached';
    blob.attachedAt = Date.now();
    saveData();
    return {
      ok: true,
      attachment: {
        name: 'encrypted.hestia',
        originalName: blob.originalName,
        extension: blob.extension,
        kind: 'document',
        originalKind: blob.originalKind,
        mimeType: blob.mimeType || null,
        sizeBytes: blob.sizeBytes,
        originalSizeBytes: blob.originalSizeBytes,
        encodedSizeBytes: blob.sizeBytes,
        blobId: blob.blobId,
        encrypted: true,
      },
    };
  }

  const base64 = typeof attachment.base64 === 'string' ? attachment.base64 : '';
  if (!base64) {
    return { ok: false, message: 'Attachment validation failed.' };
  }
  if (attachment.encrypted !== true || !isEncryptedAttachmentPayload(base64)) {
    return { ok: false, message: 'Attachment validation failed.' };
  }

  const originalName = sanitizeFileName(
    typeof attachment.originalName === 'string'
      ? attachment.originalName
      : typeof attachment.name === 'string'
        ? attachment.name
        : '',
  );
  const extension = normalizeExtension(
    typeof attachment.extension === 'string'
      ? attachment.extension
      : extensionForName(originalName),
  );
  const originalKind = normalizeKind(
    typeof attachment.originalKind === 'string'
      ? attachment.originalKind
      : typeof attachment.kind === 'string'
        ? attachment.kind
        : '',
  );
  const extensionKind = kindForExtension(extension);
  const kind = extensionKind || originalKind || 'document';
  const policy = ATTACHMENT_POLICY[kind] || ATTACHMENT_POLICY.document;
  const mimeType = typeof attachment.mimeType === 'string' ? attachment.mimeType.slice(0, 120) : '';
  if (!originalName) {
    logAttachmentValidation({
      extension,
      mime: mimeType,
      blocked: false,
      allowed: false,
      reason: 'missing_name',
      selectedKind: kind,
      maxBytes: policy.maxBytes,
    });
    return { ok: false, message: 'Attachment validation failed.' };
  }
  if (extensionBlocked(extension)) {
    logAttachmentValidation({
      extension,
      mime: mimeType,
      blocked: true,
      allowed: false,
      reason: 'blocked_extension',
      selectedKind: kind,
      maxBytes: policy.maxBytes,
    });
    logDebug(`attachment reject source=backend reason=blocked_extension ext=${extension || 'empty'}`);
    return { ok: false, message: 'Attachment type is blocked for safety.' };
  }

  const originalSizeBytes = Number(attachment.originalSizeBytes || attachment.sizeBytes || 0);
  if (!Number.isFinite(originalSizeBytes) ||
      originalSizeBytes <= 0 ||
      originalSizeBytes > HARD_ATTACHMENT_MAX_BYTES ||
      originalSizeBytes > policy.maxBytes) {
    logAttachmentValidation({
      extension,
      mime: mimeType,
      blocked: false,
      allowed: false,
      reason: 'too_large',
      selectedKind: kind,
      maxBytes: policy.maxBytes,
    });
    return { ok: false, message: 'Attachment is too large.' };
  }

  const encodedSizeBytes = Buffer.byteLength(base64, 'utf8');
  const encryptedPayloadBytes = estimateEncryptedAttachmentPayloadBytes(base64);
  const maxExpectedEncodedBytes = Math.ceil(originalSizeBytes * 3.4) + 8192;
  if (encodedSizeBytes > Math.ceil(HARD_ATTACHMENT_MAX_BYTES * 3.5) ||
      encryptedPayloadBytes < originalSizeBytes ||
      encodedSizeBytes > maxExpectedEncodedBytes) {
    logAttachmentValidation({
      extension,
      mime: mimeType,
      blocked: false,
      allowed: false,
      reason: 'invalid_encrypted_payload',
      selectedKind: kind,
      maxBytes: policy.maxBytes,
    });
    return { ok: false, message: 'Attachment validation failed.' };
  }

  logAttachmentValidation({
    extension,
    mime: mimeType,
    blocked: false,
    allowed: true,
    reason: 'allowed_by_default',
    selectedKind: kind,
    maxBytes: policy.maxBytes,
  });

  return {
    ok: true,
    attachment: {
    name: 'encrypted.hestia',
    originalName,
    extension,
    kind: 'document',
    originalKind: kind,
    mimeType: mimeType || null,
    sizeBytes: encodedSizeBytes,
    originalSizeBytes,
    encodedSizeBytes,
    base64,
    encrypted: attachment.encrypted === true,
    },
  };
}

function normalizeKind(value) {
  const kind = String(value || '').trim().toLowerCase();
  return ['document', 'image', 'video', 'audio', 'archive', 'ebook'].includes(kind)
    ? kind
    : '';
}

function extensionForName(name) {
  const normalized = String(name || '').trim().toLowerCase();
  const index = normalized.lastIndexOf('.');
  if (index === -1 || index === normalized.length - 1) return '';
  return normalized.slice(index + 1);
}

function normalizeExtension(value) {
  return String(value || '').trim().toLowerCase().replace(/^\.+/, '');
}

function sanitizeFileName(value) {
  const raw = String(value || '')
    .replace(/[\x00-\x1F\x7F]/g, '_')
    .replace(/[\\/:*?"<>|]/g, '_')
    .replace(/\s+/g, ' ')
    .trim()
    .replace(/^[. ]+|[. ]+$/g, '');
  const ext = extensionForName(raw).replace(/[^a-z0-9]/g, '').slice(0, 16);
  const suffix = ext ? `.${ext}` : '';
  let base = ext ? raw.slice(0, Math.max(0, raw.length - suffix.length)) : raw;
  base = base.replace(/^[. ]+|[. ]+$/g, '');
  if (!base) {
    base = 'attachment';
  }
  const maxLength = 180;
  const maxBaseLength = Math.max(1, maxLength - suffix.length);
  if (base.length > maxBaseLength) {
    base = base.slice(0, maxBaseLength).replace(/[. ]+$/g, '') || 'attachment';
  }
  return `${base}${suffix}`;
}

function isLikelyBase64(value) {
  return value.length % 4 === 0 && /^[A-Za-z0-9+/]+={0,2}$/.test(value);
}

function isEncryptedAttachmentPayload(value) {
  if (value.startsWith('HESTIA_FILE_V1:')) {
    const encoded = value.slice('HESTIA_FILE_V1:'.length);
    return encoded.length > 0 && isLikelyBase64(encoded);
  }
  if (value.startsWith('HESTIA_FILE_V2:')) {
    return value.length > 'HESTIA_FILE_V2:'.length &&
      !/[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]/.test(value);
  }
  return false;
}

function estimateEncryptedAttachmentPayloadBytes(value) {
  if (value.startsWith('HESTIA_FILE_V2:')) {
    return Buffer.byteLength(value, 'utf8');
  }
  const encoded = value.slice('HESTIA_FILE_V1:'.length);
  return estimateBase64DecodedBytes(encoded);
}

function estimateBase64DecodedBytes(value) {
  const padding = value.endsWith('==') ? 2 : value.endsWith('=') ? 1 : 0;
  return Math.floor((value.length * 3) / 4) - padding;
}

function publicAttachmentPolicy() {
  return {
    hardMaxBytes: HARD_ATTACHMENT_MAX_BYTES,
    blockedExtensions: Array.from(ATTACHMENT_BLOCKED_EXTENSIONS),
    maxBytesByKind: Object.fromEntries(
      Object.entries(ATTACHMENT_POLICY).map(([kind, policy]) => [kind, policy.maxBytes]),
    ),
    document: {
      maxBytes: ATTACHMENT_POLICY.document.maxBytes,
      extensions: [],
    },
    archive: {
      maxBytes: ATTACHMENT_POLICY.archive.maxBytes,
      extensions: Array.from(ATTACHMENT_KIND_EXTENSIONS.archive),
    },
    ebook: {
      maxBytes: ATTACHMENT_POLICY.ebook.maxBytes,
      extensions: Array.from(ATTACHMENT_KIND_EXTENSIONS.ebook),
    },
    image: {
      maxBytes: ATTACHMENT_POLICY.image.maxBytes,
      extensions: Array.from(ATTACHMENT_KIND_EXTENSIONS.image),
    },
    audio: {
      maxBytes: ATTACHMENT_POLICY.audio.maxBytes,
      extensions: Array.from(ATTACHMENT_KIND_EXTENSIONS.audio),
    },
    video: {
      maxBytes: ATTACHMENT_POLICY.video.maxBytes,
      extensions: Array.from(ATTACHMENT_KIND_EXTENSIONS.video),
    },
  };
}

function requestUrl(req) {
  return new URL(req.url, `http://${req.headers.host || 'localhost'}`);
}

function validateAttachmentMetadata({ originalName, extension, originalKind, originalSizeBytes }) {
  const safeName = sanitizeFileName(originalName);
  const ext = normalizeExtension(extension || extensionForName(safeName));
  const declaredKind = normalizeKind(originalKind);
  const extensionKind = kindForExtension(ext);
  const kind = extensionKind || declaredKind || 'document';
  const policy = ATTACHMENT_POLICY[kind] || ATTACHMENT_POLICY.document;
  if (!safeName) {
    logAttachmentValidation({
      extension: ext,
      mime: '',
      blocked: false,
      allowed: false,
      reason: 'missing_name',
      selectedKind: kind,
      maxBytes: policy.maxBytes,
    });
    logDebug(
      `[debug] attachment metadata decision=reject reason=metadata name=${safeName || 'empty'} extension=${ext || 'empty'} declaredKind=${declaredKind || 'empty'} extensionKind=${extensionKind || 'empty'}`,
    );
    return { ok: false, message: 'Attachment validation failed.' };
  }
  if (extensionBlocked(ext)) {
    logAttachmentValidation({
      extension: ext,
      mime: '',
      blocked: true,
      allowed: false,
      reason: 'blocked_extension',
      selectedKind: kind,
      maxBytes: policy.maxBytes,
    });
    logDebug(`attachment reject source=backend reason=blocked_extension ext=${ext || 'empty'}`);
    logDebug(
      `[debug] attachment metadata decision=reject reason=blocked_extension name=${safeName} extension=${ext} kind=${kind}`,
    );
    return { ok: false, message: 'Attachment type is blocked for safety.' };
  }
  const size = Number(originalSizeBytes || 0);
  if (!Number.isFinite(size) ||
      size <= 0 ||
      size > HARD_ATTACHMENT_MAX_BYTES ||
      size > policy.maxBytes) {
    logAttachmentValidation({
      extension: ext,
      mime: '',
      blocked: false,
      allowed: false,
      reason: 'too_large',
      selectedKind: kind,
      maxBytes: policy.maxBytes,
    });
    logDebug(
      `[debug] attachment metadata decision=reject reason=size name=${safeName} extension=${ext} kind=${kind} sizeBytes=${size || 0} maxBytes=${policy.maxBytes}`,
    );
    return { ok: false, message: 'Attachment is too large.' };
  }
  if (declaredKind && declaredKind !== kind) {
    logDebug(
      `[debug] attachment metadata decision=allow reason=extension_overrode_kind name=${safeName} extension=${ext} declaredKind=${declaredKind} kind=${kind}`,
    );
  } else {
    logDebug(
      `[debug] attachment metadata decision=allow name=${safeName} extension=${ext} kind=${kind} sizeBytes=${size}`,
    );
  }
  logAttachmentValidation({
    extension: ext,
    mime: '',
    blocked: false,
    allowed: true,
    reason: 'allowed_by_default',
    selectedKind: kind,
    maxBytes: policy.maxBytes,
  });
  return { ok: true, originalName: safeName, extension: ext, originalKind: kind, originalSizeBytes: size };
}

function blobLimitError(recipientUserId, sizeBytes) {
  if (storedBlobBytesForRecipient(recipientUserId) + sizeBytes >
      OFFLINE_QUEUE_RECIPIENT_ATTACHMENT_MAX_BYTES) {
    return 'Recipient attachment storage is full. Try again later.';
  }
  if (storedBlobBytesForServer() + sizeBytes > OFFLINE_QUEUE_SERVER_ATTACHMENT_MAX_BYTES) {
    return 'Server attachment storage is full. Try again later.';
  }
  if (storedBlobFilesForRecipient(recipientUserId) + 1 >
      OFFLINE_QUEUE_RECIPIENT_ATTACHMENT_MAX_FILES) {
    return 'Recipient attachment storage is full. Try again later.';
  }
  if (storedBlobFilesForServer() + 1 > OFFLINE_QUEUE_SERVER_ATTACHMENT_MAX_FILES) {
    return 'Server attachment storage is full. Try again later.';
  }
  return null;
}

function handleUploadBlob(req, res) {
  if (!FEATURE_FILE_ATTACHMENTS) {
    return jsonResponse(res, 404, { error: 'File attachments are disabled in v0.1.0.' });
  }
  const auth = authenticateHttp(req);
  if (!auth) {
    logDebug('[debug] blob upload rejected reason=unauthorized');
    return jsonResponse(res, 401, { error: 'Unauthorized' });
  }
  if (!bucketAllowed(rateBuckets, `blob_upload:${auth.user.id}`, 30, 60 * 1000)) {
    logDebug(`[debug] blob upload rejected reason=rate_limited sender=${auth.user.id}`);
    return jsonResponse(res, 429, { error: 'Too many requests. Try again later.' });
  }
  const url = requestUrl(req);
  const recipientUserId = String(url.searchParams.get('toUserId') || '').trim();
  const messageId = String(url.searchParams.get('messageId') || uuidv4()).trim();
  const recipient = findUserById(recipientUserId);
  const sender = auth.user;
  logDebug(
    `[debug] blob upload route hit sender=${sender.id} recipient=${recipientUserId || 'none'} messageId=${messageId || 'none'} contentLength=${req.headers['content-length'] || 'unknown'}`,
  );
  if (!recipient ||
      !hasActiveContact(sender.id, recipient.id) ||
      isBlockedBy(sender.id, recipient.id) ||
      isBlockedBy(recipient.id, sender.id)) {
    logDebug(
      `[debug] blob upload rejected unavailable sender=${sender.id} recipient=${recipientUserId}`,
    );
    return jsonResponse(res, 403, { error: 'User is unavailable.' });
  }

  const metadata = validateAttachmentMetadata({
    originalName: url.searchParams.get('originalName') || '',
    extension: url.searchParams.get('extension') || '',
    originalKind: url.searchParams.get('originalKind') || url.searchParams.get('kind') || '',
    originalSizeBytes: url.searchParams.get('originalSizeBytes') || url.searchParams.get('sizeBytes') || '',
  });
  if (!metadata.ok) {
    logDebug(
      `[debug] blob upload metadata rejected sender=${sender.id} recipient=${recipientUserId} name=${sanitizeFileName(url.searchParams.get('originalName') || '')} extension=${normalizeExtension(url.searchParams.get('extension') || '')} kind=${normalizeKind(url.searchParams.get('originalKind') || url.searchParams.get('kind') || '')} message=${metadata.message}`,
    );
    return jsonResponse(res, 400, { error: metadata.message });
  }

  ensureAttachmentBlobDir();
  const blobId = uuidv4();
  const fileName = attachmentBlobFileName(blobId);
  const filePath = safeAttachmentBlobPath(fileName);
  const tmpPath = safeAttachmentBlobPath(`${fileName}.tmp`);
  if (!filePath || !tmpPath) {
    logWarn(`[blob] upload rejected reason=invalid_blob_path sender=${sender.id}`);
    return jsonResponse(res, 500, { error: 'Attachment upload failed.' });
  }

  let sizeBytes = 0;
  let prefix = '';
  let rejected = false;
  let invalidPayloadChars = false;
  const maxEncodedBytes = Math.ceil(HARD_ATTACHMENT_MAX_BYTES * 3.5);
  const contentLength = Number(req.headers['content-length'] || 0);
  if (Number.isFinite(contentLength) && contentLength > maxEncodedBytes) {
    logDebug(`[debug] blob upload rejected reason=content_length_too_large sender=${sender.id} contentLength=${contentLength}`);
    return jsonResponse(res, 413, { error: 'Attachment is too large.' });
  }
  const out = fs.createWriteStream(tmpPath, { encoding: 'utf8' });
  let writeFailed = false;
  const startedAt = Date.now();

  out.on('error', (error) => {
    writeFailed = true;
    logWarn(`[blob] upload write failed sender=${sender.id} message=${error.message}`);
    try { if (fs.existsSync(tmpPath)) fs.unlinkSync(tmpPath); } catch {}
    if (!res.headersSent) {
      jsonResponse(res, 500, { error: 'Attachment upload failed.' });
    }
  });

  req.on('data', (chunk) => {
    if (rejected) {
      return;
    }
    sizeBytes += chunk.length;
    if (prefix.length < 32) {
      prefix += chunk.toString('utf8', 0, Math.min(chunk.length, 32 - prefix.length));
    }
    const textChunk = chunk.toString('utf8');
    if (/[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]/.test(textChunk)) {
      invalidPayloadChars = true;
    }
    if (sizeBytes > maxEncodedBytes) {
      rejected = true;
      return;
    }
    if (!out.write(chunk)) {
      req.pause();
      out.once('drain', () => req.resume());
    }
  });

  req.on('end', () => {
    out.end(() => {
      if (writeFailed || res.headersSent) {
        return;
      }
      const isV1 = prefix.startsWith('HESTIA_FILE_V1:');
      const isV2 = prefix.startsWith('HESTIA_FILE_V2:');
      if (rejected || invalidPayloadChars || (!isV1 && !isV2)) {
        try { if (fs.existsSync(tmpPath)) fs.unlinkSync(tmpPath); } catch {}
        if (rejected) {
          logDebug(
            `[debug] blob upload rejected reason=encoded_body_too_large sender=${sender.id} recipient=${recipient.id} sizeBytes=${sizeBytes} maxEncodedBytes=${maxEncodedBytes}`,
          );
          return jsonResponse(res, 413, { error: 'Attachment is too large.' });
        }
        logDebug(
          `[debug] blob upload rejected reason=invalid_encrypted_payload sender=${sender.id} recipient=${recipient.id} invalidChars=${invalidPayloadChars} prefix=${prefix.slice(0, 15)}`,
        );
        return jsonResponse(res, 400, { error: 'Attachment validation failed.' });
      }
      const expectedMax = Math.ceil(metadata.originalSizeBytes * (isV2 ? 1.6 : 3.4)) + 65536;
      if (sizeBytes > expectedMax) {
        try { fs.unlinkSync(tmpPath); } catch {}
        logDebug(
          `[debug] blob upload rejected reason=encoded_size_unexpected sender=${sender.id} recipient=${recipient.id} encodedSizeBytes=${sizeBytes} expectedMax=${expectedMax} format=${isV2 ? 'v2' : 'v1'}`,
        );
        return jsonResponse(res, 400, { error: 'Attachment validation failed.' });
      }
      const limitError = blobLimitError(recipient.id, sizeBytes);
      if (limitError) {
        try { fs.unlinkSync(tmpPath); } catch {}
        logWarn(`[blob] rejected upload for ${recipient.id}: ${limitError}`);
        return jsonResponse(res, 413, { error: limitError });
      }
      fs.renameSync(tmpPath, filePath);
      const now = Date.now();
      const blob = {
        blobId,
        fileName,
        filePath: fileName,
        senderUserId: sender.id,
        recipientUserId: recipient.id,
        messageId,
        sizeBytes,
        mimeType: String(url.searchParams.get('mimeType') || '').slice(0, 120) || null,
        originalName: metadata.originalName,
        extension: metadata.extension,
        originalKind: metadata.originalKind,
        originalSizeBytes: metadata.originalSizeBytes,
        encrypted: true,
        createdAt: now,
        expiresAt: now + OFFLINE_TTL_MS,
        state: 'ready',
      };
      data.blobs.push(blob);
      saveData();
      logDebug(
        `[debug] blob upload stored blobId=${blobId} sender=${sender.id} recipient=${recipient.id} name=${blob.originalName} extension=${blob.extension} kind=${blob.originalKind} sizeBytes=${blob.sizeBytes} durationMs=${Date.now() - startedAt}`,
      );
      return jsonResponse(res, 200, {
        ok: true,
        blobId,
        sizeBytes,
        expiresAt: blob.expiresAt,
      });
    });
  });

  req.on('aborted', () => {
    try { if (fs.existsSync(tmpPath)) fs.unlinkSync(tmpPath); } catch {}
    logWarn(`[blob] upload aborted sender=${sender.id} recipient=${recipient.id} sizeBytes=${sizeBytes}`);
  });

  req.on('error', (error) => {
    try { if (fs.existsSync(tmpPath)) fs.unlinkSync(tmpPath); } catch {}
    logWarn(`[blob] upload request error sender=${sender.id} recipient=${recipient.id} sizeBytes=${sizeBytes} message=${error.message}`);
    if (!res.headersSent) {
      jsonResponse(res, 400, { error: 'Attachment upload failed.' });
    }
  });
}

function handleDownloadBlob(req, res) {
  if (!FEATURE_FILE_ATTACHMENTS) {
    return jsonResponse(res, 404, { error: 'File attachments are disabled in v0.1.0.' });
  }
  const auth = authenticateHttp(req);
  if (!auth) {
    return jsonResponse(res, 401, { error: 'Unauthorized' });
  }
  if (!bucketAllowed(rateBuckets, `blob_download:${auth.user.id}`, 120, 60 * 1000)) {
    return jsonResponse(res, 429, { error: 'Too many requests. Try again later.' });
  }
  const url = requestUrl(req);
  const match = url.pathname.match(/^\/(?:api\/)?download_blob\/([^/]+)$/);
  const blobId = String((match && match[1]) || url.searchParams.get('blobId') || '').trim();
  const blob = findBlobById(blobId);
  if (!blob ||
      (blob.senderUserId !== auth.user.id && blob.recipientUserId !== auth.user.id)) {
    logDebug(
      `[debug] blob download not found blobId=${blobId} user=${auth.user.id} route=${url.pathname}`,
    );
    return jsonResponse(res, 404, { error: 'Not found' });
  }
  if (Number(blob.expiresAt || 0) <= Date.now()) {
    deleteStoredBlob(blob);
    data.blobs = data.blobs.filter((item) => item.blobId !== blob.blobId);
    saveData();
    logDebug(`[debug] blob download expired blobId=${blobId} user=${auth.user.id}`);
    return jsonResponse(res, 404, { error: 'Not found' });
  }
  const filePath = safeAttachmentBlobPath(blob.fileName || blob.filePath);
  if (!filePath || !fs.existsSync(filePath)) {
    data.blobs = data.blobs.filter((item) => item.blobId !== blob.blobId);
    saveData();
    logWarn(`[blob] download missing file blobId=${blobId} user=${auth.user.id}`);
    return jsonResponse(res, 404, { error: 'Not found' });
  }
  if (blob.recipientUserId === auth.user.id) {
    const now = Date.now();
    blob.state = 'downloaded';
    blob.downloadedAt = now;
    blob.expiresAt = Math.min(
      Number(blob.expiresAt || now + DOWNLOADED_BLOB_RETENTION_MS),
      now + DOWNLOADED_BLOB_RETENTION_MS,
    );
    saveData();
  }
  res.writeHead(200, {
    'Content-Type': 'text/plain; charset=utf-8',
    'Content-Length': String(blob.sizeBytes || fs.statSync(filePath).size),
    'Access-Control-Allow-Origin': '*',
  });
  fs.createReadStream(filePath).pipe(res);
}

function backendConfigPayload() {
  return {
    serverName: SERVER_NAME,
    registrationEnabled: REGISTRATION_ENABLED,
    inviteOnly: INVITE_ONLY,
    features: {
      fileAttachments: FEATURE_FILE_ATTACHMENTS,
      voiceCalls: FEATURE_VOICE_CALLS,
      videoCalls: FEATURE_VIDEO_CALLS,
      pushNotifications: FEATURE_PUSH_NOTIFICATIONS,
    },
    iceServers: FEATURE_VOICE_CALLS || FEATURE_VIDEO_CALLS ? ICE_SERVERS : [],
    offlineTtlMs: OFFLINE_TTL_MS,
    websocketPath: '/ws',
    blobTransfer: {
      enabled: FEATURE_FILE_ATTACHMENTS,
      uploadPath: '/api/upload_blob',
      downloadPath: '/api/download_blob/{blobId}',
      legacyUploadPath: '/upload_blob',
      legacyDownloadPath: '/download_blob/{blobId}',
    },
    queueLimits: {
      recipientMaxMessages: OFFLINE_QUEUE_RECIPIENT_MAX_MESSAGES,
      serverMaxMessages: OFFLINE_QUEUE_SERVER_MAX_MESSAGES,
      recipientMaxBytes: OFFLINE_QUEUE_RECIPIENT_MAX_BYTES,
      serverMaxBytes: OFFLINE_QUEUE_SERVER_MAX_BYTES,
      recipientAttachmentMaxBytes: OFFLINE_QUEUE_RECIPIENT_ATTACHMENT_MAX_BYTES,
      serverAttachmentMaxBytes: OFFLINE_QUEUE_SERVER_ATTACHMENT_MAX_BYTES,
      recipientAttachmentMaxFiles: OFFLINE_QUEUE_RECIPIENT_ATTACHMENT_MAX_FILES,
      serverAttachmentMaxFiles: OFFLINE_QUEUE_SERVER_ATTACHMENT_MAX_FILES,
    },
    callMedia: FEATURE_VOICE_CALLS || FEATURE_VIDEO_CALLS ? CALL_MEDIA_CONFIG : null,
    attachmentPolicy: FEATURE_FILE_ATTACHMENTS ? publicAttachmentPolicy() : null,
  };
}

const server = http.createServer();
server.on('request', async (req, res) => {
  if (req.method === 'OPTIONS') {
    jsonResponse(res, 204, {});
    return;
  }

  const url = requestUrl(req);

  if (req.method === 'POST' &&
      (url.pathname === '/api/upload_blob' || url.pathname === '/upload_blob')) {
    handleUploadBlob(req, res);
    return;
  }

  if (req.method === 'GET' &&
      (url.pathname === '/download_blob' ||
       url.pathname === '/api/download_blob' ||
       url.pathname.startsWith('/download_blob/') ||
       url.pathname.startsWith('/api/download_blob/'))) {
    handleDownloadBlob(req, res);
    return;
  }

  if (req.method === 'GET' &&
      (url.pathname === '/api/config' || url.pathname === '/config')) {
    jsonResponse(res, 200, backendConfigPayload());
    return;
  }

  if (req.method === 'GET' &&
      (url.pathname === '/health' || url.pathname === '/api/health')) {
    jsonResponse(res, 200, {
      status: 'ok',
      uptime: Math.floor(process.uptime()),
      users: users.length,
      onlineUsers: clients.size,
      queuedMessages: data.queuedMessages.length,
      timestamp: new Date().toISOString(),
    });
    return;
  }

  if (req.method === 'POST' && req.url === '/admin/disable_user') {
    if (!requireAdmin(req, res)) return;
    const body = await readRequestBody(req);
    const user = body && findUserById(String(body.userId || ''));
    if (!user) return jsonResponse(res, 404, { error: 'Not found' });
    user.disabled = true;
    user.sessions = [];
    for (const client of allClientSockets()) {
      if (client.userId === user.id) {
        send(client, { type: 'session_revoked' });
        client.close();
      }
    }
    saveData();
    return jsonResponse(res, 200, { ok: true });
  }

  if (req.method === 'POST' && req.url === '/admin/enable_user') {
    if (!requireAdmin(req, res)) return;
    const body = await readRequestBody(req);
    const user = body && findUserById(String(body.userId || ''));
    if (!user) return jsonResponse(res, 404, { error: 'Not found' });
    user.disabled = false;
    saveData();
    return jsonResponse(res, 200, { ok: true });
  }

  if (req.method === 'POST' && req.url === '/admin/revoke_sessions') {
    if (!requireAdmin(req, res)) return;
    const body = await readRequestBody(req);
    const user = body && findUserById(String(body.userId || ''));
    if (!user) return jsonResponse(res, 404, { error: 'Not found' });
    user.sessions = [];
    for (const client of allClientSockets()) {
      if (client.userId === user.id) {
        send(client, { type: 'session_revoked' });
        client.close();
      }
    }
    saveData();
    return jsonResponse(res, 200, { ok: true });
  }

  if (req.method === 'POST' && req.url === '/admin/registration') {
    if (!requireAdmin(req, res)) return;
    const body = await readRequestBody(req);
    if (body && typeof body.registrationEnabled === 'boolean') {
      REGISTRATION_ENABLED = body.registrationEnabled;
      data.metadata.registrationEnabled = REGISTRATION_ENABLED;
    }
    if (body && typeof body.inviteOnly === 'boolean') {
      INVITE_ONLY = body.inviteOnly;
      data.metadata.inviteOnly = INVITE_ONLY;
    }
    saveData();
    return jsonResponse(res, 200, {
      ok: true,
      registrationEnabled: REGISTRATION_ENABLED,
      inviteOnly: INVITE_ONLY,
    });
  }

  if (serveLandingStatic(req, res, url)) {
    return;
  }

  jsonResponse(res, 404, { error: 'Not found' });
});
const wss = new WebSocket.Server({
  noServer: true,
  maxPayload: FEATURE_FILE_ATTACHMENTS
    ? Math.max(MAX_WS_MESSAGE_BYTES, Math.ceil(HARD_ATTACHMENT_MAX_BYTES * 3.5))
    : MAX_WS_MESSAGE_BYTES,
});

server.on('upgrade', (req, socket, head) => {
  const url = requestUrl(req);
  if (url.pathname !== '/ws') {
    socket.destroy();
    return;
  }

  wss.handleUpgrade(req, socket, head, (ws) => {
    wss.emit('connection', ws, req);
  });
});

wss.on('connection', (ws, req) => {
  ws.isAlive = true;
  ws.missedHeartbeats = 0;
  logDebug(
    `[debug] ws open remote=${req?.socket?.remoteAddress || 'unknown'} ` +
    'userId=unauthenticated sessionId=none',
  );

  ws.on('pong', () => {
    ws.isAlive = true;
    ws.missedHeartbeats = 0;
  });

  ws.on('message', (raw) => {
    ws.isAlive = true;
    ws.missedHeartbeats = 0;
    const maxFrameBytes = FEATURE_FILE_ATTACHMENTS
      ? Math.ceil(HARD_ATTACHMENT_MAX_BYTES * 3.5)
      : MAX_WS_MESSAGE_BYTES;
    if (raw.length > maxFrameBytes) {
      return ws.close(1009, 'Message too large');
    }
    let msg;
    try {
      msg = JSON.parse(raw);
    } catch {
      return sendError(ws, 'Invalid request.');
    }
    if (!msg || typeof msg !== 'object' || typeof msg.type !== 'string') {
      return sendError(ws, 'Invalid request.');
    }
    logDebug(
      `[debug] ws frame type=${msg.type} userId=${ws.userId || 'unauthenticated'} ` +
      `sessionId=${ws.sessionId || 'none'}`,
    );

    try {
      if (msg.type === 'auth') {
        return auth(ws, msg);
      }

      if (msg.type === 'register') {
        return register(ws, msg);
      }

      if (!ws.userId) {
        return sendError(ws, 'Authenticate first');
      }
      if (!touchSession(ws)) {
        return;
      }

      if (msg.type === 'get_users') {
        return sendUsers(ws, ws.userId);
      }

      if (msg.type === 'get_contacts') {
        sendContacts(ws, ws.userId);
        return deliverQueuedMessages(ws, ws.userId);
      }

      if (msg.type === 'get_contact_requests') {
        return sendContactRequests(ws, ws.userId);
      }

      if (msg.type === 'find_user_by_username_exact') {
        return findUserByUsernameExact(ws, msg);
      }

      if (msg.type === 'send_contact_request') {
        return sendContactRequest(ws, msg);
      }

      if (msg.type === 'accept_contact_request') {
        return acceptContactRequest(ws, msg);
      }

      if (msg.type === 'decline_contact_request') {
        return declineContactRequest(ws, msg);
      }

      if (msg.type === 'block_user') {
        return blockUser(ws, msg);
      }

      if (msg.type === 'unblock_user') {
        return unblockUser(ws, msg);
      }

      if (msg.type === 'update_privacy_settings') {
        return updatePrivacySettings(ws, msg);
      }

      if (msg.type === 'get_sessions') {
        return sendSessions(ws);
      }

      if (msg.type === 'register_push_token' || msg.type === 'update_push_token') {
        return updatePushToken(ws, msg);
      }

      if (msg.type === 'remove_push_token') {
        return removePushToken(ws, msg);
      }

      if (msg.type === 'client_app_state') {
        return updateClientAppState(ws, msg);
      }

      if (msg.type === 'retention_event') {
        return handleRetentionEvent(ws, msg);
      }

      if (msg.type === 'get_call_offer') {
        if (!FEATURE_VOICE_CALLS && !FEATURE_VIDEO_CALLS) {
          return send(ws, {
            type: 'call_unavailable',
            callId: String(msg.callId || ''),
            reason: 'voice_calls_disabled',
          });
        }
        return getCallOffer(ws, msg);
      }

      if (msg.type === 'revoke_session') {
        return revokeSession(ws, msg);
      }

      if (msg.type === 'logout') {
        return logoutSession(ws);
      }

      if (msg.type === 'delivery_ack') {
        return ackDelivery(
          String(msg.id || ''),
          ws.userId,
          String(msg.fromUserId || ''),
        );
      }

      if (msg.type === 'message') {
        return relayMessage(ws, msg);
      }

      if (typeof msg.type === 'string' && msg.type.startsWith('call_')) {
        return relayCallSignal(ws, msg);
      }
    } catch (error) {
      logWarn(
        `[ws] frame handling failed type=${msg.type} userId=${ws.userId || 'unauthenticated'} ` +
        `sessionId=${ws.sessionId || 'none'} error=${error.stack || error.message}`,
      );
      return sendError(ws, 'Server error.', { messageId: msg.id });
    }
  });

  ws.on('close', (code, reasonBuffer) => {
    if (!ws.userId) {
      logDebug(
        `[debug] ws close userId=unauthenticated sessionId=none ` +
        `code=${code} reason=${reasonBuffer?.toString() || ''}`,
      );
      return;
    }
    const userId = ws.userId;
    const sessionId = ws.sessionId;
    ws.userId = null;
    ws.sessionId = null;
    if (removeClient(userId, ws)) {
      logDebug(
        `[debug] user disconnected userId=${userId} sessionId=${sessionId || 'none'} ` +
        `code=${code} reason=${reasonBuffer?.toString() || ''} ` +
        `activeSockets=${connectedClientCount(userId)}`,
      );
      schedulePresence(userId);
    }
  });

  ws.on('error', (error) => {
    logDebug(`[debug] websocket error: ${error.message}`);
  });
});

if (typeof PORT === 'string') {
  try {
    if (fs.existsSync(PORT)) {
      fs.unlinkSync(PORT);
    }
  } catch (error) {
    logInfo(`[server] unable to remove stale socket ${PORT}: ${error.message}`);
  }
}

server.on('error', (error) => {
  console.error(`[server] failed to start: ${error.stack || error.message}`);
});

server.listen(PORT, () => {
  if (typeof PORT === 'string') {
    try {
      fs.chmodSync(PORT, 0o777);
    } catch (error) {
      logInfo(`[server] unable to chmod socket ${PORT}: ${error.message}`);
    }
  }
  const listenLabel = typeof PORT === 'number' ? `http://localhost:${PORT}` : PORT;
  logInfo(`Hestia relay server is listening on ${listenLabel}`);
});

const queueMaintenanceTimer = setInterval(runQueueMaintenance, QUEUE_CLEANUP_INTERVAL_MS);
queueMaintenanceTimer.unref();

const heartbeatTimer = setInterval(() => {
  for (const ws of wss.clients) {
    if (ws.readyState !== WebSocket.OPEN) {
      continue;
    }
    if (ws.isAlive === false) {
      ws.missedHeartbeats = Number(ws.missedHeartbeats || 0) + 1;
      logDebug(
        `[debug] websocket heartbeat missed userId=${ws.userId || 'unauthenticated'} ` +
        `sessionId=${ws.sessionId || 'none'} misses=${ws.missedHeartbeats}`,
      );
      if (WS_HEARTBEAT_MAX_MISSES > 0 &&
          ws.missedHeartbeats >= WS_HEARTBEAT_MAX_MISSES) {
        logDebug(
          `[debug] websocket heartbeat terminating userId=${ws.userId || 'unauthenticated'} ` +
          `sessionId=${ws.sessionId || 'none'} misses=${ws.missedHeartbeats}`,
        );
        ws.terminate();
        continue;
      }
    }
    ws.isAlive = false;
    try {
      ws.ping();
    } catch (error) {
      logDebug(
        `[debug] websocket heartbeat ping failed userId=${ws.userId || 'unauthenticated'} ` +
        `sessionId=${ws.sessionId || 'none'} error=${error.message}`,
      );
      ws.terminate();
    }
  }
}, WS_HEARTBEAT_INTERVAL_MS);
heartbeatTimer.unref();

function shutdown() {
  if (shuttingDown) {
    return;
  }
  shuttingDown = true;
  clearInterval(queueMaintenanceTimer);
  clearInterval(heartbeatTimer);
  for (const ws of wss.clients) {
    try {
      ws.close(1001, 'Server shutting down');
    } catch {}
  }
  wss.close();
  server.close();
  if (saveTimer || saveQueued) {
    if (saveTimer) {
      clearTimeout(saveTimer);
      saveTimer = null;
    }
    saveDataNow();
    saveQueued = false;
  }
  store.close();
}

process.on('beforeExit', shutdown);
process.on('SIGINT', () => {
  shutdown();
  process.exit(0);
});
process.on('SIGTERM', () => {
  shutdown();
  process.exit(0);
});
