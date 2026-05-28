// ─────────────────────────────────────────────────────────────────────────────
// StorageService — Local Storage Layer
// Wraps SharedPreferences. Single responsibility: persist identity.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import 'platform_capabilities.dart';
import 'web_smoke_log.dart';

class StorageService {
  static const _keyUserId = 'userId';
  static const _keyNickname = 'nickname';
  static const _keyAuthToken = 'authToken';
  static const _keyPublicKey = 'publicKey';
  static const _keyDeviceId = 'deviceId';
  static const _keyOnboardingSeen = 'onboardingSeen';
  static const _trustedPeerPrefix = 'trustedPeerPublicKey:';
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();

  StorageService._();
  static final StorageService instance = StorageService._();

  late SharedPreferences _prefs;
  String? _authToken;
  String? _publicKey;
  bool _secureValuesLoaded = false;

  bool get secureValuesLoaded => _secureValuesLoaded;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _secureValuesLoaded = false;
    try {
      _authToken = await _readSecureWithMigration(_keyAuthToken);
      _publicKey = await _readSecureWithMigration(_keyPublicKey);
      _secureValuesLoaded = true;
    } catch (error) {
      if (PlatformCapabilities.isWeb) {
        WebSmokeLog.log('runtime blocker reason=secure_storage error=$error');
      }
      rethrow;
    }
    if (PlatformCapabilities.isWeb &&
        loadProfile()?.authToken?.isNotEmpty == true) {
      WebSmokeLog.log('storage restored after reload');
    }
  }

  // Returns null if user has never registered
  UserProfile? loadProfile() {
    final userId = _prefs.getString(_keyUserId);
    final nickname = _prefs.getString(_keyNickname);
    if (userId == null || nickname == null) return null;
    return UserProfile(
      userId: userId,
      nickname: nickname,
      authToken: _authToken,
      publicKey: _publicKey,
    );
  }

  Future<void> saveProfile(UserProfile profile) async {
    await _prefs.setString(_keyUserId, profile.userId);
    await _prefs.setString(_keyNickname, profile.nickname);
    if (profile.authToken == null) {
      await _removeSecure(_keyAuthToken);
      _authToken = null;
    } else {
      await _writeSecure(_keyAuthToken, profile.authToken!);
      _authToken = profile.authToken;
    }
    if (profile.publicKey == null) {
      await _removeSecure(_keyPublicKey);
      _publicKey = null;
    } else {
      await _writeSecure(_keyPublicKey, profile.publicKey!);
      _publicKey = profile.publicKey;
    }
  }

  Future<void> clearProfile() async {
    await _prefs.remove(_keyUserId);
    await _prefs.remove(_keyNickname);
    await _removeSecure(_keyAuthToken);
    await _removeSecure(_keyPublicKey);
    _authToken = null;
    _publicKey = null;
  }

  bool get hasSeenOnboarding => _prefs.getBool(_keyOnboardingSeen) ?? false;

  Future<void> markOnboardingSeen() async {
    await _prefs.setBool(_keyOnboardingSeen, true);
  }

  Future<String> loadOrCreateDeviceId() async {
    final existing = _prefs.getString(_keyDeviceId);
    if (existing != null && existing.isNotEmpty) {
      return existing;
    }
    final next = DateTime.now().microsecondsSinceEpoch.toRadixString(16);
    await _prefs.setString(_keyDeviceId, next);
    return next;
  }

  String get deviceName {
    if (kIsWeb) {
      return 'Web device';
    }
    return '${defaultTargetPlatform.name} device';
  }

  String get platformName => kIsWeb ? 'web' : defaultTargetPlatform.name;

  String? loadTrustedPeerPublicKey(String peerUserId) {
    return _prefs.getString('$_trustedPeerPrefix$peerUserId');
  }

  Future<void> saveTrustedPeerPublicKey({
    required String peerUserId,
    required String publicKey,
  }) async {
    await _prefs.setString('$_trustedPeerPrefix$peerUserId', publicKey);
  }

  Future<void> removeTrustedPeerPublicKey(String peerUserId) async {
    await _prefs.remove('$_trustedPeerPrefix$peerUserId');
  }

  Map<String, String> exportTrustedPeerKeys() {
    final result = <String, String>{};
    for (final key in _prefs.getKeys()) {
      if (!key.startsWith(_trustedPeerPrefix)) {
        continue;
      }
      final peerUserId = key.substring(_trustedPeerPrefix.length);
      final publicKey = _prefs.getString(key);
      if (peerUserId.isNotEmpty && publicKey != null) {
        result[peerUserId] = publicKey;
      }
    }
    return result;
  }

  Future<void> importTrustedPeerKeys(Map<String, dynamic> keys) async {
    for (final entry in keys.entries) {
      final publicKey = entry.value;
      if (publicKey is String && publicKey.isNotEmpty) {
        await saveTrustedPeerPublicKey(
          peerUserId: entry.key,
          publicKey: publicKey,
        );
      }
    }
  }

  Future<String?> _readSecureWithMigration(String key) async {
    final secureValue = await _secureStorage.read(key: key);
    if (secureValue != null && secureValue.isNotEmpty) {
      await _prefs.remove(key);
      return secureValue;
    }
    final legacyValue = _prefs.getString(key);
    if (legacyValue == null || legacyValue.isEmpty) {
      return null;
    }
    await _writeSecure(key, legacyValue);
    await _prefs.remove(key);
    return legacyValue;
  }

  Future<void> _writeSecure(String key, String value) =>
      _secureStorage.write(key: key, value: value);

  Future<void> _removeSecure(String key) async {
    await _secureStorage.delete(key: key);
    await _prefs.remove(key);
  }
}
