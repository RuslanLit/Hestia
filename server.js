'use strict';

const WebSocket = require('ws');
const fs = require('fs');
const path = require('path');
const http = require('http');
const crypto = require('crypto');
const { v4: uuidv4 } = require('uuid');

const LISTEN_TARGET = process.env.PORT || process.env.SOCKET || process.env.LISTEN_SOCKET || '3000';
const PORT = /^\d+$/.test(LISTEN_TARGET) ? Number(LISTEN_TARGET) : LISTEN_TARGET;
const DATA_FILE = path.join(__dirname, 'data.json');
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
const PRESENCE_DEBOUNCE_MS = Number(process.env.PRESENCE_DEBOUNCE_MS || 1500);
const LOG_LEVEL = process.env.LOG_LEVEL || 'info';
const QUEUE_BLOB_CHECKSUM = process.env.QUEUE_BLOB_CHECKSUM === 'true';
const FCM_SERVICE_ACCOUNT_JSON = process.env.FIREBASE_SERVICE_ACCOUNT_JSON || '';
const FCM_SERVICE_ACCOUNT_FILE = process.env.GOOGLE_APPLICATION_CREDENTIALS || '';
const ATTACHMENT_POLICY = {
  document: {
    maxBytes: Number(process.env.ATTACHMENT_DOCUMENT_MAX_BYTES || 50 * MB),
    extensions: new Set(['pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx', 'odt', 'ods', 'odp', 'rtf', 'txt', 'csv']),
  },
  image: {
    maxBytes: Number(process.env.ATTACHMENT_IMAGE_MAX_BYTES || 25 * MB),
    extensions: new Set(['jpg', 'jpeg', 'png', 'webp', 'gif', 'heic', 'heif']),
  },
  video: {
    maxBytes: Number(process.env.ATTACHMENT_VIDEO_MAX_BYTES || 200 * MB),
    extensions: new Set(['mp4', 'mov', 'webm', 'mkv', 'm4v']),
  },
  audio: {
    maxBytes: Number(process.env.ATTACHMENT_AUDIO_MAX_BYTES || 50 * MB),
    extensions: new Set(['mp3', 'wav', 'ogg', 'm4a', 'aac', 'flac']),
  },
};
const HARD_ATTACHMENT_MAX_BYTES = Number(
  process.env.HARD_ATTACHMENT_MAX_BYTES || 200 * MB,
);
const MAX_WS_MESSAGE_BYTES = Number(process.env.MAX_WS_MESSAGE_BYTES || 768 * 1024);
const MAX_TEXT_BYTES = Number(process.env.MAX_TEXT_BYTES || 64 * 1024);
const MAX_CALL_SDP_BYTES = Number(process.env.MAX_CALL_SDP_BYTES || 128 * 1024);
const MAX_CALL_ICE_BYTES = Number(process.env.MAX_CALL_ICE_BYTES || 8 * 1024);
const MAX_PUBLIC_KEY_BYTES = Number(process.env.MAX_PUBLIC_KEY_BYTES || 256);
const SESSION_MAX_AGE_MS = Number(
  process.env.SESSION_MAX_AGE_MS || 30 * 24 * 60 * 60 * 1000,
);
const OFFLINE_QUEUE_RECIPIENT_MAX_BYTES = Number(
  process.env.OFFLINE_QUEUE_RECIPIENT_MAX_BYTES || 250 * MB,
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
  process.env.OFFLINE_QUEUE_RECIPIENT_ATTACHMENT_MAX_BYTES || 220 * MB,
);
const OFFLINE_QUEUE_SERVER_ATTACHMENT_MAX_BYTES = Number(
  process.env.OFFLINE_QUEUE_SERVER_ATTACHMENT_MAX_BYTES || 800 * MB,
);
const OFFLINE_QUEUE_RECIPIENT_ATTACHMENT_MAX_FILES = Number(
  process.env.OFFLINE_QUEUE_RECIPIENT_ATTACHMENT_MAX_FILES || 20,
);
const OFFLINE_QUEUE_SERVER_ATTACHMENT_MAX_FILES = Number(
  process.env.OFFLINE_QUEUE_SERVER_ATTACHMENT_MAX_FILES || 500,
);
const CALL_MEDIA_CONFIG = {
  video: {
    width: Number(process.env.CALL_VIDEO_WIDTH || 640),
    height: Number(process.env.CALL_VIDEO_HEIGHT || 360),
    frameRate: Number(process.env.CALL_VIDEO_FRAMERATE || 24),
    maxBitrateKbps: Number(process.env.CALL_VIDEO_MAX_BITRATE_KBPS || 900),
  },
  audio: {
    echoCancellation: true,
    noiseSuppression: true,
    autoGainControl: true,
  },
};
const SERVER_NAME = process.env.SERVER_NAME || 'Hestia';
const REGISTRATION_ENABLED = process.env.REGISTRATION_ENABLED !== 'false';
const INVITE_ONLY = process.env.INVITE_ONLY === 'true';
const INVITE_CODES = new Set(
  (process.env.INVITE_CODES || '')
    .split(',')
    .map((item) => item.trim())
    .filter(Boolean),
);
const ADMIN_TOKEN = process.env.ADMIN_TOKEN || '';
const ICE_SERVERS = [
  { urls: 'stun:stun.l.google.com:19302' },
  { urls: 'stun:stun1.l.google.com:19302' },
  ...parseTurnServers(process.env.TURN_SERVERS || ''),
];
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

const clients = new Map(); // userId -> ws
const rateBuckets = new Map();
const failedLoginBuckets = new Map();
const repeatedContactRequests = new Map();
const callCooldowns = new Map();
const pendingCallOffers = new Map();
const pendingDeliveries = new Map(); // messageId -> sender userId
const pushDedup = new Map();
const presenceTimers = new Map();
let saveTimer = null;
let saveInFlight = false;
let saveQueued = false;

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

function parseTurnServers(value) {
  return value
    .split(',')
    .map((item) => item.trim())
    .filter(Boolean)
    .map((item) => {
      const [urls, username, credential] = item.split('|');
      return {
        urls,
        ...(username ? { username } : {}),
        ...(credential ? { credential } : {}),
      };
    });
}

function loadData() {
  if (!fs.existsSync(DATA_FILE)) {
    return {
      users: [],
      queuedMessages: [],
      contacts: [],
      contactRequests: [],
      blocks: [],
      blobs: [],
      retentionEvents: [],
    };
  }

  try {
    const parsed = JSON.parse(fs.readFileSync(DATA_FILE, 'utf8'));
    return {
      users: Array.isArray(parsed.users) ? parsed.users : [],
      queuedMessages: Array.isArray(parsed.queuedMessages) ? parsed.queuedMessages : [],
      contacts: Array.isArray(parsed.contacts) ? parsed.contacts : [],
      contactRequests: Array.isArray(parsed.contactRequests) ? parsed.contactRequests : [],
      blocks: Array.isArray(parsed.blocks) ? parsed.blocks : [],
      blobs: Array.isArray(parsed.blobs) ? parsed.blobs : [],
      retentionEvents: Array.isArray(parsed.retentionEvents) ? parsed.retentionEvents : [],
    };
  } catch {
    return {
      users: [],
      queuedMessages: [],
      contacts: [],
      contactRequests: [],
      blocks: [],
      blobs: [],
      retentionEvents: [],
    };
  }
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
    const filePath = safeAttachmentBlobPath(blob.fileName || blob.filePath);
    const missing = !filePath || !fs.existsSync(filePath);
    if ((expired && !blobIsReferenced(blob.blobId)) || missing) {
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
  fs.writeFileSync(DATA_FILE, JSON.stringify(data, null, 2));
}

function saveData() {
  saveQueued = true;
  if (saveTimer || saveInFlight) {
    return;
  }
  saveTimer = setTimeout(flushData, SAVE_DEBOUNCE_MS);
}

function flushData() {
  if (saveTimer) {
    clearTimeout(saveTimer);
    saveTimer = null;
  }
  if (!saveQueued || saveInFlight) {
    return;
  }
  saveQueued = false;
  saveInFlight = true;
  const tmpFile = `${DATA_FILE}.tmp`;
  fs.promises
    .writeFile(tmpFile, JSON.stringify(data, null, 2))
    .then(() => fs.promises.rename(tmpFile, DATA_FILE))
    .catch((error) => {
      logWarn(`[storage] save failed: ${error.message}`);
      saveQueued = true;
    })
    .finally(() => {
      saveInFlight = false;
      if (saveQueued) {
        saveTimer = setTimeout(flushData, SAVE_DEBOUNCE_MS);
      }
    });
}

const data = loadData();
let users = data.users;
data.contacts = data.contacts || [];
data.contactRequests = data.contactRequests || [];
data.blocks = data.blocks || [];
data.blobs = data.blobs || [];
data.retentionEvents = data.retentionEvents || [];
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

  const relativePath = requestPath.replace(/^\/+/, '');
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
    return false;
  }

  const stat = fs.statSync(filePath);
  res.writeHead(200, {
    'Content-Type': staticContentType(filePath),
    'Content-Length': String(stat.size),
    'Cache-Control': relativePath === 'index.html' ||
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
  return users.find(
    (user) => user.nickname.toLowerCase() === normalized,
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
    const createdAt = Date.parse(session.createdAt || session.lastActiveAt || '');
    const expired = Number.isFinite(createdAt) && now - createdAt > SESSION_MAX_AGE_MS;
    if (expired) {
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

function sessionDto(session, currentSessionId) {
  return {
    id: session.id,
    deviceId: session.deviceId,
    deviceName: session.deviceName || 'Unknown device',
    platform: session.platform || 'unknown',
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
    if (now > Number(offer.expiresAt || 0)) {
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
    .filter((blob) => blob.recipientUserId === userId)
    .reduce((sum, blob) => sum + Number(blob.sizeBytes || 0), 0);
}

function storedBlobBytesForServer() {
  return data.blobs.reduce((sum, blob) => sum + Number(blob.sizeBytes || 0), 0);
}

function storedBlobFilesForRecipient(userId) {
  return data.blobs.filter((blob) => blob.recipientUserId === userId).length;
}

function storedBlobFilesForServer() {
  return data.blobs.length;
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

function ackDelivery(messageId, userId) {
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
  const senderUserId =
    pendingDeliveries.get(messageId)?.senderUserId || queued?.payload?.fromUserId || null;
  const deliveredBlobId =
    pendingDeliveries.get(messageId)?.blobId || queued?.payload?.attachment?.blobId || null;
  if (deliveredBlobId) {
    const blob = findBlobById(deliveredBlobId);
    if (blob) {
      deleteStoredBlob(blob);
      data.blobs = data.blobs.filter((item) => item.blobId !== deliveredBlobId);
      saveData();
    }
  }
  pendingDeliveries.delete(messageId);
  if (senderUserId) {
    const senderSocket = clients.get(senderUserId);
    if (senderSocket) {
      send(senderSocket, { type: 'delivery_ack', id: messageId });
    }
  }
}

function finishAuth(ws, user, session) {
  ws.userId = user.id;
  ws.sessionId = session?.id || null;
  const previousSocket = clients.get(user.id);
  if (previousSocket && previousSocket !== ws) {
    previousSocket.close();
  }
  clients.set(user.id, ws);

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
    online: clients.has(user.id),
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
    online: clients.has(peerUserId),
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

  for (const [viewerUserId, socket] of clients.entries()) {
    if (viewerUserId === userId || hasActiveContact(viewerUserId, userId)) {
      send(socket, payload);
    }
  }
}

function touchSession(ws) {
  const currentSession = currentSessionFor(ws);
  if (!currentSession) {
    return;
  }

  const now = Date.now();
  const previous = currentSession.lastActiveAt
    ? Date.parse(currentSession.lastActiveAt)
    : 0;
  if (Number.isFinite(previous) && now - previous < SESSION_TOUCH_INTERVAL_MS) {
    return;
  }
  const stamp = new Date(now).toISOString();
  currentSession.lastActiveAt = stamp;
  currentSession.lastSeenAt = stamp;
  touchRetentionActivity(ws.userId);
  saveData();
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
  session.appVersion = normalizeAppVersion(msg.appVersion || session.appVersion);
  session.pushTokenUpdatedAt = now;
  session.lastSeenAt = now;
  saveData();

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
  delete session.pushTokenUpdatedAt;
  session.appVersion = normalizeAppVersion(msg.appVersion || session.appVersion);
  session.lastSeenAt = new Date().toISOString();
  saveData();

  send(ws, { type: 'push_token_removed' });
  sendSessions(ws);
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
  if (!offer || offer.toUserId !== ws.userId) {
    return send(ws, {
      type: 'call_unavailable',
      callId,
      message: 'Call unavailable.',
    });
  }
  if (Date.now() > Number(offer.expiresAt || 0)) {
    pendingCallOffers.delete(callId);
    return send(ws, {
      type: 'call_unavailable',
      callId,
      message: 'Call unavailable.',
    });
  }
  send(ws, offer.payload);
}

function pushPayloadForMessage(message) {
  return {
    type: 'message',
    messageId: String(message?.id || ''),
    fromUserId: String(message?.fromUserId || ''),
  };
}

function pushPayloadForContactRequest(request) {
  return {
    type: 'contact_request',
    requestId: String(request?.id || ''),
    fromUserId: String(request?.fromUserId || ''),
  };
}

function pushPayloadForCall(signal) {
  return {
    type: 'incoming_call',
    callId: String(signal?.callId || ''),
    fromUserId: String(signal?.fromUserId || ''),
    callType: signal?.video ? 'video' : 'audio',
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

async function sendFcmDataMessage(token, payload) {
  const account = loadFcmServiceAccount();
  const projectId = process.env.FIREBASE_PROJECT_ID || account?.project_id;
  if (!account || !projectId) {
    return false;
  }
  const bearer = await fcmBearerToken();
  if (!bearer) {
    return false;
  }
  const response = await fetch(
    `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
    {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${bearer}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        message: {
          token,
          data: pushDataPayload(payload),
          android: {
            priority: 'HIGH',
          },
        },
      }),
    },
  );
  if (!response.ok) {
    throw new Error(`FCM send failed: ${response.status}`);
  }
  return true;
}

function sendPushToUser(userId, payload, options = {}) {
  const user = findUserById(userId);
  if (!user) {
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
      typeof session.pushToken === 'string' &&
      session.pushToken.length > 0);
  for (const session of sessions) {
    sendFcmDataMessage(session.pushToken, payload).catch((error) => {
      logWarn(`[push] send failed for ${userId}/${session.deviceId}: ${error.message}`);
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
    return tooManyRequests(ws);
  }

  const query = String(msg.username || '').trim();
  if (!query) {
    return send(ws, { type: 'user_search_result', user: null });
  }
  const user = findUserByNickname(query);
  if (!user || user.id === ws.userId || user.allowUserDiscovery === false) {
    return send(ws, { type: 'user_search_result', user: null });
  }
  if (isBlockedBy(user.id, ws.userId) || isBlockedBy(ws.userId, user.id)) {
    return send(ws, { type: 'user_search_result', user: null });
  }
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

  const targetSocket = clients.get(recipient.id);
  if (targetSocket) {
    send(targetSocket, { type: 'contact_request', request: requestDto(request) });
  } else {
    sendPushToUser(recipient.id, pushPayloadForContactRequest(request));
  }
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
  if (hasActiveContact(request.fromUserId, request.toUserId)) return;

  request.status = 'accepted';
  const fromUser = findUserById(request.fromUserId);
  const toUser = findUserById(request.toUserId);
  data.contacts.push({
    userId: request.fromUserId,
    peerUserId: request.toUserId,
    username: toUser?.nickname || '',
    status: 'active',
    createdAt: new Date().toISOString(),
  });
  data.contacts.push({
    userId: request.toUserId,
    peerUserId: request.fromUserId,
    username: fromUser?.nickname || request.fromUsername || '',
    status: 'active',
    createdAt: new Date().toISOString(),
  });
  recordRetentionEvent(request.fromUserId, 'first_contact_added', {
    source: 'contact_request',
  });
  recordRetentionEvent(request.toUserId, 'first_contact_added', {
    source: 'contact_request',
  });
  saveData();

  const fromSocket = clients.get(request.fromUserId);
  const toSocket = clients.get(request.toUserId);
  if (fromSocket) sendContacts(fromSocket, request.fromUserId);
  if (toSocket) {
    sendContacts(toSocket, request.toUserId);
    sendContactRequests(toSocket, request.toUserId);
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
    for (const client of clients.values()) {
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
    } else {
      authDataChanged = true;
    }
    if (authDataChanged) {
      saveData();
    }
    if (legacyTokenAccepted) {
      delete user.token;
      saveData();
    }
    return finishAuth(ws, user, session);
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
  finishAuth(ws, user, session);
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
  const requestedPassword = String(msg.password || '');
  const requestedPublicKey = normalizePublicKey(msg.publicKey);
  const inviteCode = String(msg.inviteCode || '').trim();

  if (INVITE_ONLY && !INVITE_CODES.has(inviteCode)) {
    return send(ws, {
      type: 'error',
      message: 'Registration is invite-only.',
    });
  }

  if (requestedNickname.length < 2) {
    return send(ws, {
      type: 'error',
      message: 'Nickname must be at least 2 characters.',
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
    passwordHash: hashPassword(requestedPassword),
    publicKey: requestedPublicKey,
  };

  users.push(user);
  const session = createSession(user, msg);
  recordRetentionEvent(user.id, 'user_registered', { source: 'register' });
  saveData();

  finishAuth(ws, user, session);
}

function relayMessage(ws, msg) {
  if (!ws.userId) {
    return;
  }
  if (!rateLimit(ws, 'message_relay', 120, 60 * 1000)) {
    return tooManyRequests(ws);
  }

  const sender = findUserById(ws.userId);
  if (!sender) {
    return send(ws, {
      type: 'error',
      message: 'Sender not found',
    });
  }

  const toUserId = String(msg.toUserId || '').trim();
  const recipient = findUserById(toUserId);
  if (!recipient) {
    return send(ws, {
      type: 'error',
      message: 'Recipient not found',
    });
  }
  if (!hasActiveContact(sender.id, recipient.id) ||
      isBlockedBy(sender.id, recipient.id) ||
      isBlockedBy(recipient.id, sender.id)) {
    return send(ws, {
      type: 'error',
      message: 'User is unavailable.',
    });
  }

  const messageId = String(msg.id || uuidv4()).trim();
  if (!messageId || messageId.length > 80) {
    return send(ws, {
      type: 'error',
      message: 'Message validation failed.',
    });
  }
  const text = boundedString(msg.text, MAX_TEXT_BYTES);
  if (text === null) {
    return send(ws, {
      type: 'error',
      message: 'Message is too large.',
    });
  }
  if (text && !text.startsWith('HESTIA_TEXT_V1:')) {
    return send(ws, {
      type: 'error',
      message: 'Message encryption is required.',
    });
  }
  const recipientPublicKey = normalizePublicKey(msg.recipientPublicKey);
  if (recipient.publicKey && recipientPublicKey && recipientPublicKey !== recipient.publicKey) {
    return send(ws, {
      type: 'error',
      message: 'Recipient encryption key is outdated.',
    });
  }

  const attachmentResult = normalizeAttachment(msg.attachment, {
    senderId: sender.id,
    recipientId: recipient.id,
    messageId,
  });
  if (!attachmentResult.ok) {
    return send(ws, {
      type: 'error',
      message: attachmentResult.message,
    });
  }

  const payload = {
    id: messageId,
    fromUserId: sender.id,
    fromNickname: sender.nickname,
    toUserId: recipient.id,
    recipientPublicKey: recipientPublicKey || null,
    text,
    timestamp: Date.now(),
    attachment: attachmentResult.attachment,
  };

  const targetSocket = clients.get(recipient.id);
  recordRetentionEvent(sender.id, 'first_message_sent', { source: 'message' });
  recordRetentionEvent(recipient.id, 'first_message_received', { source: 'message' });
  pendingDeliveries.set(payload.id, {
    senderUserId: sender.id,
    blobId: payload.attachment?.blobId || null,
    createdAt: Date.now(),
  });
  if (targetSocket) {
    send(targetSocket, {
      type: 'new_message',
      message: payload,
    });
  } else {
    const queueResult = queueOfflineMessage(recipient.id, payload);
    if (!queueResult.ok) {
      pendingDeliveries.delete(payload.id);
      return send(ws, {
        type: 'error',
        message: queueResult.message || 'Message cannot be queued.',
      });
    }
    sendPushToUser(recipient.id, pushPayloadForMessage(payload));
  }

  send(ws, {
    type: 'message_sent',
    message: payload,
    delivered: Boolean(targetSocket),
  });
}

function relayCallSignal(ws, msg) {
  if (!ws.userId) {
    return;
  }
  if (!rateLimit(ws, 'call_signal', 240, 60 * 1000)) {
    return tooManyRequests(ws);
  }

  const allowedTypes = new Set([
    'call_offer_init',
    'call_accepted',
    'call_rejected',
    'call_ended',
    'call_sdp_offer',
    'call_sdp_answer',
    'call_ice',
  ]);
  if (!allowedTypes.has(msg.type)) {
    return;
  }
  const callId = String(msg.callId || '').trim();
  if (!callId || callId.length > 80) {
    return send(ws, {
      type: 'call_unavailable',
      callId,
      message: 'Call unavailable.',
    });
  }
  if ((msg.type === 'call_sdp_offer' || msg.type === 'call_sdp_answer') &&
      boundedString(msg.sdp, MAX_CALL_SDP_BYTES) === null) {
    return send(ws, {
      type: 'call_unavailable',
      callId,
      message: 'Call unavailable.',
    });
  }
  if (msg.type === 'call_ice' &&
      boundedString(msg.candidate, MAX_CALL_ICE_BYTES) === null) {
    return send(ws, {
      type: 'call_unavailable',
      callId,
      message: 'Call unavailable.',
    });
  }

  const sender = findUserById(ws.userId);
  const toUserId = String(msg.toUserId || '').trim();
  const recipient = findUserById(toUserId);
  if (msg.type === 'call_offer_init') {
    if (!rateLimit(ws, 'call_offer', 8, 60 * 1000)) {
      return send(ws, {
        type: 'call_unavailable',
        callId,
        message: 'Call unavailable.',
      });
    }
    if (!pairCooldown(callCooldowns, `${ws.userId}:${toUserId}`, 30 * 1000)) {
      return send(ws, {
        type: 'call_unavailable',
        callId,
        message: 'Call unavailable.',
      });
    }
  }

  if (!sender || !recipient) {
    return send(ws, {
      type: 'call_unavailable',
      callId,
      message: 'User not found.',
    });
  }
  if (!hasActiveContact(sender.id, recipient.id) ||
      isBlockedBy(sender.id, recipient.id) ||
      isBlockedBy(recipient.id, sender.id)) {
    return send(ws, {
      type: 'call_unavailable',
      callId,
      message: 'User is unavailable.',
    });
  }

  const targetSocket = clients.get(recipient.id);
  if (!targetSocket && msg.type !== 'call_offer_init') {
    return send(ws, {
      type: 'call_unavailable',
      callId,
      message: 'User is offline.',
    });
  }

  const signal = {
    ...msg,
    callId,
    sdp: typeof msg.sdp === 'string' ? msg.sdp : undefined,
    candidate: typeof msg.candidate === 'string' ? msg.candidate : undefined,
    fromUserId: sender.id,
    fromNickname: sender.nickname,
    senderPublicKey: sender.publicKey || null,
  };

  if (msg.type === 'call_offer_init') {
    recordRetentionEvent(sender.id, 'call_started', { source: 'call' });
    recordRetentionEvent(recipient.id, 'call_received', { source: 'call' });
    pendingCallOffers.set(callId, {
      toUserId: recipient.id,
      fromUserId: sender.id,
      payload: signal,
      expiresAt: Date.now() + 45 * 1000,
    });
    if (!targetSocket) {
      sendPushToUser(recipient.id, pushPayloadForCall(signal));
      return;
    }
  } else if (
    msg.type === 'call_rejected' ||
    msg.type === 'call_ended' ||
    msg.type === 'call_accepted'
  ) {
    pendingCallOffers.delete(callId);
  }

  send(targetSocket, signal);
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
      return { ok: false, message: 'Attachment is unavailable.' };
    }
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
  const policy = ATTACHMENT_POLICY[originalKind];
  if (!originalName || !extension || !policy || !policy.extensions.has(extension)) {
    return { ok: false, message: 'Attachment type is not allowed.' };
  }

  const originalSizeBytes = Number(attachment.originalSizeBytes || attachment.sizeBytes || 0);
  if (!Number.isFinite(originalSizeBytes) ||
      originalSizeBytes <= 0 ||
      originalSizeBytes > HARD_ATTACHMENT_MAX_BYTES ||
      originalSizeBytes > policy.maxBytes) {
    return { ok: false, message: 'Attachment is too large.' };
  }

  const encodedSizeBytes = Buffer.byteLength(base64, 'utf8');
  const encryptedPayloadBytes = estimateEncryptedAttachmentPayloadBytes(base64);
  const maxExpectedEncodedBytes = Math.ceil(originalSizeBytes * 3.4) + 8192;
  if (encodedSizeBytes > Math.ceil(HARD_ATTACHMENT_MAX_BYTES * 3.5) ||
      encryptedPayloadBytes < originalSizeBytes ||
      encodedSizeBytes > maxExpectedEncodedBytes) {
    return { ok: false, message: 'Attachment validation failed.' };
  }

  return {
    ok: true,
    attachment: {
    name: 'encrypted.hestia',
    originalName,
    extension,
    kind: 'document',
    originalKind,
    mimeType: typeof attachment.mimeType === 'string'
      ? attachment.mimeType.slice(0, 120)
      : null,
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
  return ['document', 'image', 'video', 'audio'].includes(kind) ? kind : '';
}

function extensionForName(name) {
  const normalized = String(name || '').trim().toLowerCase();
  const index = normalized.lastIndexOf('.');
  if (index === -1 || index === normalized.length - 1) return '';
  return normalized.slice(index + 1);
}

function normalizeExtension(value) {
  return String(value || '').trim().toLowerCase().replace(/^\./, '');
}

function sanitizeFileName(value) {
  return String(value || '').trim().replace(/[\\/:*?"<>|]/g, '_').slice(0, 180);
}

function isLikelyBase64(value) {
  return value.length % 4 === 0 && /^[A-Za-z0-9+/]+={0,2}$/.test(value);
}

function isEncryptedAttachmentPayload(value) {
  if (!value.startsWith('HESTIA_FILE_V1:')) return false;
  const encoded = value.slice('HESTIA_FILE_V1:'.length);
  return encoded.length > 0 && isLikelyBase64(encoded);
}

function estimateEncryptedAttachmentPayloadBytes(value) {
  const encoded = value.slice('HESTIA_FILE_V1:'.length);
  return estimateBase64DecodedBytes(encoded);
}

function estimateBase64DecodedBytes(value) {
  const padding = value.endsWith('==') ? 2 : value.endsWith('=') ? 1 : 0;
  return Math.floor((value.length * 3) / 4) - padding;
}

function publicAttachmentPolicy() {
  return Object.fromEntries(
    Object.entries(ATTACHMENT_POLICY).map(([kind, policy]) => [
      kind,
      {
        maxBytes: policy.maxBytes,
        extensions: Array.from(policy.extensions),
      },
    ]),
  );
}

function requestUrl(req) {
  return new URL(req.url, `http://${req.headers.host || 'localhost'}`);
}

function validateAttachmentMetadata({ originalName, extension, originalKind, originalSizeBytes }) {
  const safeName = sanitizeFileName(originalName);
  const ext = normalizeExtension(extension || extensionForName(safeName));
  const kind = normalizeKind(originalKind);
  const policy = ATTACHMENT_POLICY[kind];
  if (!safeName || !ext || !policy || !policy.extensions.has(ext)) {
    return { ok: false, message: 'Attachment type is not allowed.' };
  }
  const size = Number(originalSizeBytes || 0);
  if (!Number.isFinite(size) ||
      size <= 0 ||
      size > HARD_ATTACHMENT_MAX_BYTES ||
      size > policy.maxBytes) {
    return { ok: false, message: 'Attachment is too large.' };
  }
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
  const auth = authenticateHttp(req);
  if (!auth) {
    return jsonResponse(res, 401, { error: 'Unauthorized' });
  }
  if (!bucketAllowed(rateBuckets, `blob_upload:${auth.user.id}`, 30, 60 * 1000)) {
    return jsonResponse(res, 429, { error: 'Too many requests. Try again later.' });
  }
  const url = requestUrl(req);
  const recipientUserId = String(url.searchParams.get('toUserId') || '').trim();
  const messageId = String(url.searchParams.get('messageId') || uuidv4()).trim();
  const recipient = findUserById(recipientUserId);
  const sender = auth.user;
  if (!recipient ||
      !hasActiveContact(sender.id, recipient.id) ||
      isBlockedBy(sender.id, recipient.id) ||
      isBlockedBy(recipient.id, sender.id)) {
    return jsonResponse(res, 403, { error: 'User is unavailable.' });
  }

  const metadata = validateAttachmentMetadata({
    originalName: url.searchParams.get('originalName') || '',
    extension: url.searchParams.get('extension') || '',
    originalKind: url.searchParams.get('originalKind') || url.searchParams.get('kind') || '',
    originalSizeBytes: url.searchParams.get('originalSizeBytes') || url.searchParams.get('sizeBytes') || '',
  });
  if (!metadata.ok) {
    return jsonResponse(res, 400, { error: metadata.message });
  }

  ensureAttachmentBlobDir();
  const blobId = uuidv4();
  const fileName = attachmentBlobFileName(blobId);
  const filePath = safeAttachmentBlobPath(fileName);
  const tmpPath = safeAttachmentBlobPath(`${fileName}.tmp`);
  if (!filePath || !tmpPath) {
    return jsonResponse(res, 500, { error: 'Attachment upload failed.' });
  }

  let sizeBytes = 0;
  let prefix = '';
  let rejected = false;
  let invalidPayloadChars = false;
  const maxEncodedBytes = Math.ceil(HARD_ATTACHMENT_MAX_BYTES * 3.5);
  const contentLength = Number(req.headers['content-length'] || 0);
  if (Number.isFinite(contentLength) && contentLength > maxEncodedBytes) {
    return jsonResponse(res, 413, { error: 'Attachment is too large.' });
  }
  const out = fs.createWriteStream(tmpPath, { encoding: 'utf8' });

  req.on('data', (chunk) => {
    if (rejected) {
      return;
    }
    sizeBytes += chunk.length;
    if (prefix.length < 32) {
      prefix += chunk.toString('utf8', 0, Math.min(chunk.length, 32 - prefix.length));
    }
    const textChunk = chunk.toString('utf8');
    if (!/^[A-Za-z0-9+/=:_\-]+$/.test(textChunk)) {
      invalidPayloadChars = true;
    }
    if (sizeBytes > maxEncodedBytes) {
      rejected = true;
      return;
    }
    out.write(chunk);
  });

  req.on('end', () => {
    out.end(() => {
      if (rejected || invalidPayloadChars || !prefix.startsWith('HESTIA_FILE_V1:')) {
        try { if (fs.existsSync(tmpPath)) fs.unlinkSync(tmpPath); } catch {}
        return jsonResponse(res, 400, { error: 'Attachment validation failed.' });
      }
      const expectedMax = Math.ceil(metadata.originalSizeBytes * 3.4) + 8192;
      if (sizeBytes > expectedMax) {
        try { fs.unlinkSync(tmpPath); } catch {}
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
      return jsonResponse(res, 200, {
        ok: true,
        blobId,
        sizeBytes,
        expiresAt: blob.expiresAt,
      });
    });
  });

  req.on('error', () => {
    try { if (fs.existsSync(tmpPath)) fs.unlinkSync(tmpPath); } catch {}
    if (!res.headersSent) {
      jsonResponse(res, 400, { error: 'Attachment upload failed.' });
    }
  });
}

function handleDownloadBlob(req, res) {
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
    return jsonResponse(res, 404, { error: 'Not found' });
  }
  if (Number(blob.expiresAt || 0) <= Date.now()) {
    deleteStoredBlob(blob);
    data.blobs = data.blobs.filter((item) => item.blobId !== blob.blobId);
    saveData();
    return jsonResponse(res, 404, { error: 'Not found' });
  }
  const filePath = safeAttachmentBlobPath(blob.fileName || blob.filePath);
  if (!filePath || !fs.existsSync(filePath)) {
    data.blobs = data.blobs.filter((item) => item.blobId !== blob.blobId);
    saveData();
    return jsonResponse(res, 404, { error: 'Not found' });
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
    iceServers: ICE_SERVERS,
    offlineTtlMs: OFFLINE_TTL_MS,
    websocketPath: '/ws',
    blobTransfer: {
      enabled: true,
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
    callMedia: CALL_MEDIA_CONFIG,
    attachmentPolicy: publicAttachmentPolicy(),
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

  if (req.method === 'POST' && req.url === '/admin/disable_user') {
    if (!requireAdmin(req, res)) return;
    const body = await readRequestBody(req);
    const user = body && findUserById(String(body.userId || ''));
    if (!user) return jsonResponse(res, 404, { error: 'Not found' });
    user.disabled = true;
    user.sessions = [];
    for (const client of clients.values()) {
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
    for (const client of clients.values()) {
      if (client.userId === user.id) {
        send(client, { type: 'session_revoked' });
        client.close();
      }
    }
    saveData();
    return jsonResponse(res, 200, { ok: true });
  }

  if (serveLandingStatic(req, res, url)) {
    return;
  }

  jsonResponse(res, 404, { error: 'Not found' });
});
const wss = new WebSocket.Server({
  noServer: true,
  maxPayload: Math.max(MAX_WS_MESSAGE_BYTES, Math.ceil(HARD_ATTACHMENT_MAX_BYTES * 3.5)),
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

wss.on('connection', (ws) => {
  ws.on('message', (raw) => {
    if (raw.length > Math.ceil(HARD_ATTACHMENT_MAX_BYTES * 3.5)) {
      return ws.close(1009, 'Message too large');
    }
    let msg;
    try {
      msg = JSON.parse(raw);
    } catch {
      return;
    }

    if (msg.type === 'auth') {
      return auth(ws, msg);
    }

    if (msg.type === 'register') {
      return register(ws, msg);
    }

    if (!ws.userId) {
      return send(ws, {
        type: 'error',
        message: 'Authenticate first',
      });
    }
    touchSession(ws);

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

    if (msg.type === 'retention_event') {
      return handleRetentionEvent(ws, msg);
    }

    if (msg.type === 'get_call_offer') {
      return getCallOffer(ws, msg);
    }

    if (msg.type === 'revoke_session') {
      return revokeSession(ws, msg);
    }

    if (msg.type === 'logout') {
      return logoutSession(ws);
    }

    if (msg.type === 'delivery_ack') {
      return ackDelivery(String(msg.id || ''), ws.userId);
    }

    if (msg.type === 'message') {
      return relayMessage(ws, msg);
    }

    if (typeof msg.type === 'string' && msg.type.startsWith('call_')) {
      return relayCallSignal(ws, msg);
    }
  });

  ws.on('close', () => {
    if (!ws.userId) {
      return;
    }
    if (clients.get(ws.userId) === ws) {
      clients.delete(ws.userId);
      schedulePresence(ws.userId);
    }
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

setInterval(runQueueMaintenance, QUEUE_CLEANUP_INTERVAL_MS).unref();

function shutdown() {
  if (saveTimer || saveQueued) {
    if (saveTimer) {
      clearTimeout(saveTimer);
      saveTimer = null;
    }
    saveDataNow();
    saveQueued = false;
  }
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
