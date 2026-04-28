'use strict';

const path = require('path');
const crypto = require('crypto');
const Database = require('better-sqlite3');

const uuidv4 = () => crypto.randomUUID();

function boolToInt(value, fallback = false) {
  if (value === undefined || value === null) {
    return fallback ? 1 : 0;
  }
  return value === true || value === 1 ? 1 : 0;
}

function intToBool(value, fallback = false) {
  if (value === undefined || value === null) {
    return fallback;
  }
  return Number(value) === 1;
}

function jsonString(value, fallback = null) {
  return JSON.stringify(value === undefined ? fallback : value);
}

function parseJson(value, fallback = null) {
  if (typeof value !== 'string' || value.length === 0) {
    return fallback;
  }
  try {
    return JSON.parse(value);
  } catch {
    return fallback;
  }
}

class SQLiteStore {
  constructor(filePath) {
    this.filePath = path.resolve(filePath || path.join(__dirname, '..', 'hestia.sqlite'));
    this.db = new Database(this.filePath);
    this.db.pragma('journal_mode = WAL');
    this.db.pragma('foreign_keys = ON');
    this.init();
  }

  init() {
    this.db.exec(`
      CREATE TABLE IF NOT EXISTS users (
        id TEXT PRIMARY KEY,
        nickname TEXT UNIQUE NOT NULL,
        passwordHash TEXT,
        token TEXT,
        publicKey TEXT,
        allowUserDiscovery INTEGER DEFAULT 1,
        disabled INTEGER DEFAULT 0,
        retentionState TEXT,
        createdAt TEXT,
        updatedAt TEXT
      );

      CREATE TABLE IF NOT EXISTS sessions (
        id TEXT PRIMARY KEY,
        userId TEXT NOT NULL,
        deviceId TEXT,
        deviceName TEXT,
        platform TEXT,
        token TEXT UNIQUE NOT NULL,
        appVersion TEXT,
        pushProvider TEXT,
        pushToken TEXT,
        pushTokenUpdatedAt TEXT,
        createdAt TEXT,
        lastActiveAt TEXT,
        lastSeenAt TEXT,
        FOREIGN KEY(userId) REFERENCES users(id) ON DELETE CASCADE
      );

      CREATE TABLE IF NOT EXISTS contacts (
        id TEXT PRIMARY KEY,
        userId TEXT NOT NULL,
        peerUserId TEXT NOT NULL,
        username TEXT,
        status TEXT DEFAULT 'active',
        createdAt TEXT,
        UNIQUE(userId, peerUserId)
      );

      CREATE TABLE IF NOT EXISTS contact_requests (
        id TEXT PRIMARY KEY,
        fromUserId TEXT NOT NULL,
        toUserId TEXT NOT NULL,
        fromUsername TEXT,
        status TEXT DEFAULT 'pending',
        createdAt TEXT
      );

      CREATE TABLE IF NOT EXISTS blocks (
        id TEXT PRIMARY KEY,
        userId TEXT NOT NULL,
        blockedUserId TEXT NOT NULL,
        createdAt TEXT,
        UNIQUE(userId, blockedUserId)
      );

      CREATE TABLE IF NOT EXISTS queued_messages (
        id TEXT PRIMARY KEY,
        toUserId TEXT NOT NULL,
        fromUserId TEXT,
        payload TEXT NOT NULL,
        attachmentRef TEXT,
        payloadBytes INTEGER,
        attachmentBytes INTEGER,
        queuedAt INTEGER,
        expiresAt INTEGER
      );

      CREATE TABLE IF NOT EXISTS push_tokens (
        id TEXT PRIMARY KEY,
        userId TEXT NOT NULL,
        sessionId TEXT,
        platform TEXT,
        token TEXT NOT NULL,
        createdAt TEXT,
        lastSeenAt TEXT,
        UNIQUE(userId, token)
      );

      CREATE TABLE IF NOT EXISTS blobs (
        blobId TEXT PRIMARY KEY,
        senderUserId TEXT,
        recipientUserId TEXT,
        messageId TEXT,
        name TEXT,
        mimeType TEXT,
        sizeBytes INTEGER,
        fileName TEXT,
        filePath TEXT,
        createdAt INTEGER,
        expiresAt INTEGER
      );

      CREATE TABLE IF NOT EXISTS retention_events (
        id TEXT PRIMARY KEY,
        userId TEXT,
        event TEXT,
        metadata TEXT,
        createdAt TEXT
      );

      CREATE INDEX IF NOT EXISTS idx_users_nickname ON users(nickname);
      CREATE INDEX IF NOT EXISTS idx_sessions_userId ON sessions(userId);
      CREATE INDEX IF NOT EXISTS idx_sessions_token ON sessions(token);
      CREATE INDEX IF NOT EXISTS idx_contacts_userId ON contacts(userId);
      CREATE INDEX IF NOT EXISTS idx_contacts_peerUserId ON contacts(peerUserId);
      CREATE INDEX IF NOT EXISTS idx_contact_requests_to_status ON contact_requests(toUserId, status);
      CREATE INDEX IF NOT EXISTS idx_contact_requests_from_to_status ON contact_requests(fromUserId, toUserId, status);
      CREATE INDEX IF NOT EXISTS idx_blocks_user_blocked ON blocks(userId, blockedUserId);
      CREATE INDEX IF NOT EXISTS idx_queued_messages_toUserId ON queued_messages(toUserId);
      CREATE INDEX IF NOT EXISTS idx_queued_messages_expiresAt ON queued_messages(expiresAt);
      CREATE INDEX IF NOT EXISTS idx_push_tokens_userId ON push_tokens(userId);
    `);
  }

  loadData() {
    const users = this.db.prepare('SELECT * FROM users ORDER BY createdAt, nickname').all()
      .map((row) => ({
        id: row.id,
        nickname: row.nickname,
        passwordHash: row.passwordHash || undefined,
        token: row.token || undefined,
        publicKey: row.publicKey || undefined,
        allowUserDiscovery: intToBool(row.allowUserDiscovery, true),
        disabled: intToBool(row.disabled, false),
        retentionState: parseJson(row.retentionState, {}),
        createdAt: row.createdAt || undefined,
        updatedAt: row.updatedAt || undefined,
        sessions: [],
      }));
    const userById = new Map(users.map((user) => [user.id, user]));
    for (const row of this.db.prepare('SELECT * FROM sessions ORDER BY createdAt').all()) {
      const user = userById.get(row.userId);
      if (!user) continue;
      user.sessions.push({
        id: row.id,
        deviceId: row.deviceId || '',
        deviceName: row.deviceName || 'Unknown device',
        platform: row.platform || 'unknown',
        token: row.token,
        appVersion: row.appVersion || undefined,
        pushProvider: row.pushProvider || undefined,
        pushToken: row.pushToken || undefined,
        pushTokenUpdatedAt: row.pushTokenUpdatedAt || undefined,
        createdAt: row.createdAt || undefined,
        lastActiveAt: row.lastActiveAt || undefined,
        lastSeenAt: row.lastSeenAt || undefined,
      });
    }
    return {
      users,
      queuedMessages: this.db.prepare('SELECT * FROM queued_messages ORDER BY queuedAt').all()
        .map((row) => ({
          id: row.id,
          toUserId: row.toUserId,
          payload: parseJson(row.payload, {}),
          attachmentRef: parseJson(row.attachmentRef, null),
          payloadBytes: Number(row.payloadBytes || 0),
          attachmentBytes: Number(row.attachmentBytes || 0),
          queuedAt: Number(row.queuedAt || 0),
          expiresAt: Number(row.expiresAt || 0),
        })),
      contacts: this.db.prepare('SELECT * FROM contacts ORDER BY createdAt').all()
        .map((row) => ({
          id: row.id,
          userId: row.userId,
          peerUserId: row.peerUserId,
          username: row.username || '',
          status: row.status || 'active',
          createdAt: row.createdAt || undefined,
        })),
      contactRequests: this.db.prepare('SELECT * FROM contact_requests ORDER BY createdAt').all()
        .map((row) => ({
          id: row.id,
          fromUserId: row.fromUserId,
          toUserId: row.toUserId,
          fromUsername: row.fromUsername || '',
          status: row.status || 'pending',
          createdAt: row.createdAt || undefined,
        })),
      blocks: this.db.prepare('SELECT * FROM blocks ORDER BY createdAt').all()
        .map((row) => ({
          id: row.id,
          userId: row.userId,
          blockedUserId: row.blockedUserId,
          createdAt: row.createdAt || undefined,
        })),
      blobs: this.db.prepare('SELECT * FROM blobs ORDER BY createdAt').all()
        .map((row) => ({
          blobId: row.blobId,
          senderUserId: row.senderUserId,
          recipientUserId: row.recipientUserId,
          messageId: row.messageId || undefined,
          name: row.name || '',
          mimeType: row.mimeType || '',
          sizeBytes: Number(row.sizeBytes || 0),
          fileName: row.fileName || undefined,
          filePath: row.filePath || undefined,
          createdAt: Number(row.createdAt || 0),
          expiresAt: Number(row.expiresAt || 0),
        })),
      retentionEvents: this.db.prepare('SELECT * FROM retention_events ORDER BY createdAt').all()
        .map((row) => ({
          id: row.id,
          userId: row.userId,
          event: row.event,
          metadata: parseJson(row.metadata, {}),
          createdAt: row.createdAt,
        })),
    };
  }

  saveData(data) {
    const tx = this.db.transaction(() => {
      this.db.exec(`
        DELETE FROM push_tokens;
        DELETE FROM retention_events;
        DELETE FROM blobs;
        DELETE FROM queued_messages;
        DELETE FROM blocks;
        DELETE FROM contact_requests;
        DELETE FROM contacts;
        DELETE FROM sessions;
        DELETE FROM users;
      `);

      const insertUser = this.db.prepare(`
        INSERT INTO users (
          id, nickname, passwordHash, token, publicKey, allowUserDiscovery,
          disabled, retentionState, createdAt, updatedAt
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      `);
      const insertSession = this.db.prepare(`
        INSERT INTO sessions (
          id, userId, deviceId, deviceName, platform, token, appVersion,
          pushProvider, pushToken, pushTokenUpdatedAt, createdAt, lastActiveAt,
          lastSeenAt
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      `);
      const insertPushToken = this.db.prepare(`
        INSERT OR REPLACE INTO push_tokens (
          id, userId, sessionId, platform, token, createdAt, lastSeenAt
        ) VALUES (?, ?, ?, ?, ?, ?, ?)
      `);

      for (const user of data.users || []) {
        const now = new Date().toISOString();
        insertUser.run(
          user.id,
          user.nickname,
          user.passwordHash || null,
          user.token || null,
          user.publicKey || null,
          boolToInt(user.allowUserDiscovery, true),
          boolToInt(user.disabled, false),
          jsonString(user.retentionState, {}),
          user.createdAt || now,
          user.updatedAt || now,
        );
        for (const session of user.sessions || []) {
          insertSession.run(
            session.id,
            user.id,
            session.deviceId || '',
            session.deviceName || '',
            session.platform || '',
            session.token,
            session.appVersion || null,
            session.pushProvider || null,
            session.pushToken || null,
            session.pushTokenUpdatedAt || null,
            session.createdAt || now,
            session.lastActiveAt || null,
            session.lastSeenAt || null,
          );
          if (session.pushToken) {
            insertPushToken.run(
              `${user.id}:${session.pushToken}`,
              user.id,
              session.id,
              session.platform || '',
              session.pushToken,
              session.pushTokenUpdatedAt || session.createdAt || now,
              session.lastSeenAt || session.lastActiveAt || now,
            );
          }
        }
      }

      const insertContact = this.db.prepare(`
        INSERT OR REPLACE INTO contacts (
          id, userId, peerUserId, username, status, createdAt
        ) VALUES (?, ?, ?, ?, ?, ?)
      `);
      for (const contact of data.contacts || []) {
        insertContact.run(
          contact.id || `${contact.userId}:${contact.peerUserId}`,
          contact.userId,
          contact.peerUserId,
          contact.username || '',
          contact.status || 'active',
          contact.createdAt || null,
        );
      }

      const insertRequest = this.db.prepare(`
        INSERT INTO contact_requests (
          id, fromUserId, toUserId, fromUsername, status, createdAt
        ) VALUES (?, ?, ?, ?, ?, ?)
      `);
      for (const request of data.contactRequests || []) {
        insertRequest.run(
          request.id,
          request.fromUserId,
          request.toUserId,
          request.fromUsername || '',
          request.status || 'pending',
          request.createdAt || null,
        );
      }

      const insertBlock = this.db.prepare(`
        INSERT OR REPLACE INTO blocks (
          id, userId, blockedUserId, createdAt
        ) VALUES (?, ?, ?, ?)
      `);
      for (const block of data.blocks || []) {
        insertBlock.run(
          block.id || `${block.userId}:${block.blockedUserId}`,
          block.userId,
          block.blockedUserId,
          block.createdAt || null,
        );
      }

      const insertQueued = this.db.prepare(`
        INSERT INTO queued_messages (
          id, toUserId, fromUserId, payload, attachmentRef, payloadBytes,
          attachmentBytes, queuedAt, expiresAt
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
      `);
      for (const item of data.queuedMessages || []) {
        insertQueued.run(
          item.id,
          item.toUserId,
          item.payload?.fromUserId || item.fromUserId || null,
          jsonString(item.payload, {}),
          jsonString(item.attachmentRef, null),
          Number(item.payloadBytes || 0),
          Number(item.attachmentBytes || 0),
          Number(item.queuedAt || 0),
          Number(item.expiresAt || 0),
        );
      }

      const insertBlob = this.db.prepare(`
        INSERT INTO blobs (
          blobId, senderUserId, recipientUserId, messageId, name, mimeType,
          sizeBytes, fileName, filePath, createdAt, expiresAt
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      `);
      for (const blob of data.blobs || []) {
        insertBlob.run(
          blob.blobId,
          blob.senderUserId,
          blob.recipientUserId,
          blob.messageId || null,
          blob.name || '',
          blob.mimeType || '',
          Number(blob.sizeBytes || 0),
          blob.fileName || null,
          blob.filePath || null,
          Number(blob.createdAt || 0),
          Number(blob.expiresAt || 0),
        );
      }

      const insertRetention = this.db.prepare(`
        INSERT INTO retention_events (
          id, userId, event, metadata, createdAt
        ) VALUES (?, ?, ?, ?, ?)
      `);
      for (const event of data.retentionEvents || []) {
        insertRetention.run(
          event.id || uuidv4(),
          event.userId || '',
          event.event || '',
          jsonString(event.metadata, {}),
          event.createdAt || new Date().toISOString(),
        );
      }
    });
    tx();
  }

  findUserById(userId) {
    return this.loadData().users.find((user) => user.id === userId) || null;
  }

  findUserByNickname(nickname) {
    const normalized = String(nickname || '').trim().toLowerCase();
    return this.loadData().users.find(
      (user) => String(user.nickname || '').toLowerCase() === normalized,
    ) || null;
  }

  createUser(user, data) {
    data.users.push(user);
    this.saveData(data);
    return user;
  }

  updateUser(user, data) {
    user.updatedAt = new Date().toISOString();
    this.saveData(data);
    return user;
  }

  createSession(user, session, data) {
    user.sessions = Array.isArray(user.sessions) ? user.sessions : [];
    user.sessions.push(session);
    this.saveData(data);
    return session;
  }

  findSessionByToken(user, token) {
    return (user.sessions || []).find((session) => session.token === token) || null;
  }

  listSessions(user) {
    return Array.isArray(user.sessions) ? user.sessions : [];
  }

  revokeSession(user, sessionId, data) {
    user.sessions = (user.sessions || []).filter((session) => session.id !== sessionId);
    this.saveData(data);
  }

  getContacts(data, userId) {
    return (data.contacts || []).filter((contact) => contact.userId === userId);
  }

  addContact(data, contact) {
    data.contacts.push(contact);
    this.saveData(data);
  }

  updateContactStatus(data, userId, peerUserId, status) {
    for (const contact of data.contacts || []) {
      if (contact.userId === userId && contact.peerUserId === peerUserId) {
        contact.status = status;
      }
    }
    this.saveData(data);
  }

  getPendingRequests(data, userId) {
    return (data.contactRequests || []).filter(
      (request) => request.toUserId === userId && request.status === 'pending',
    );
  }

  createContactRequest(data, request) {
    data.contactRequests.push(request);
    this.saveData(data);
  }

  acceptContactRequest(data, requestId) {
    const request = (data.contactRequests || []).find((item) => item.id === requestId);
    if (request) request.status = 'accepted';
    this.saveData(data);
    return request || null;
  }

  declineContactRequest(data, requestId) {
    const request = (data.contactRequests || []).find((item) => item.id === requestId);
    if (request) request.status = 'declined';
    this.saveData(data);
    return request || null;
  }

  blockUser(data, block) {
    data.blocks.push(block);
    this.saveData(data);
  }

  unblockUser(data, userId, blockedUserId) {
    data.blocks = (data.blocks || []).filter(
      (item) => !(item.userId === userId && item.blockedUserId === blockedUserId),
    );
    this.saveData(data);
  }

  isBlockedBy(data, userId, blockedUserId) {
    return (data.blocks || []).some(
      (item) => item.userId === userId && item.blockedUserId === blockedUserId,
    );
  }

  hasActiveContact(data, a, b) {
    return (data.contacts || []).some((contact) =>
      contact.status === 'active' &&
      ((contact.userId === a && contact.peerUserId === b) ||
        (contact.userId === b && contact.peerUserId === a)));
  }

  queueOfflineMessage(data, item) {
    data.queuedMessages.push(item);
    this.saveData(data);
  }

  getQueuedMessages(data, userId) {
    return (data.queuedMessages || []).filter((item) => item.toUserId === userId);
  }

  ackDelivery(data, messageId, userId) {
    data.queuedMessages = (data.queuedMessages || []).filter(
      (item) => !(item.id === messageId && item.toUserId === userId),
    );
    this.saveData(data);
  }

  cleanupQueuedMessages(data, now = Date.now()) {
    const before = (data.queuedMessages || []).length;
    data.queuedMessages = (data.queuedMessages || []).filter(
      (item) => Number(item.expiresAt || 0) > now,
    );
    if (data.queuedMessages.length !== before) {
      this.saveData(data);
    }
    return before - data.queuedMessages.length;
  }
}

function createSQLiteStore(filePath) {
  return new SQLiteStore(filePath);
}

module.exports = {
  SQLiteStore,
  createSQLiteStore,
};
