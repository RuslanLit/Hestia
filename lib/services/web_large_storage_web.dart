import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

class WebLargeStorage {
  static const _dbName = 'hestia_local_data_v1';
  static const _storeName = 'records';

  static web.IDBDatabase? _db;

  static Future<String?> getString(String key) async {
    final store = await _store('readonly');
    final value = await _waitRequest(store.get(key.toJS));
    final dartValue = value?.dartify();
    return dartValue is String ? dartValue : null;
  }

  static Future<void> setString(String key, String value) async {
    final store = await _store('readwrite');
    await _waitRequest(store.put(value.toJS, key.toJS));
  }

  static Future<void> remove(String key) async {
    final store = await _store('readwrite');
    await _waitRequest(store.delete(key.toJS));
  }

  static Future<web.IDBObjectStore> _store(String mode) async {
    final db = await _open();
    final transaction = db.transaction(_storeName.toJS, mode);
    return transaction.objectStore(_storeName);
  }

  static Future<web.IDBDatabase> _open() async {
    final existing = _db;
    if (existing != null) {
      return existing;
    }

    final request = web.window.indexedDB.open(_dbName, 1);
    request.onupgradeneeded = ((web.Event event) {
      final db = request.result as web.IDBDatabase;
      if (!db.objectStoreNames.contains(_storeName)) {
        db.createObjectStore(_storeName);
      }
    }).toJS;

    final result = await _waitRequest(request);
    final db = result as web.IDBDatabase;
    _db = db;
    return db;
  }

  static Future<JSAny?> _waitRequest(web.IDBRequest request) {
    final completer = Completer<JSAny?>();
    request.onsuccess = ((web.Event event) {
      completer.complete(request.result);
    }).toJS;
    request.onerror = ((web.Event event) {
      completer.completeError(
        request.error?.message ?? 'IndexedDB request failed',
      );
    }).toJS;
    return completer.future;
  }
}


