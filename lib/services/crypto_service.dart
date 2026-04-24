import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pointycastle/export.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CryptoService {
  CryptoService._();
  static final CryptoService instance = CryptoService._();

  static const _privateKeyPref = 'hestia_ecdh_private_key_v1';
  static const _publicKeyPref = 'hestia_ecdh_public_key_v1';
  static const _messagePrefix = 'HESTIA_TEXT_V1:';
  static const _attachmentPrefix = 'HESTIA_FILE_V1:';
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();

  final ECDomainParameters _domain = ECDomainParameters('secp256r1');
  ECPrivateKey? _privateKey;
  String? _publicKeyBase64;

  Future<String> publicKeyBase64() async {
    await _ensureIdentityKey();
    return _publicKeyBase64!;
  }

  Future<Map<String, String>> exportIdentityForBackup() async {
    await _ensureIdentityKey();
    final privateKey = await _readSecureWithMigration(_privateKeyPref);
    final publicKey = await _readSecureWithMigration(_publicKeyPref);
    if (privateKey == null || publicKey == null) {
      throw StateError('Encryption identity is not available.');
    }
    return {
      'privateKey': privateKey,
      'publicKey': publicKey,
    };
  }

  Future<void> importIdentityFromBackup(Map<String, dynamic> json) async {
    final privateKey = json['privateKey'] as String?;
    final publicKey = json['publicKey'] as String?;
    if (privateKey == null ||
        privateKey.isEmpty ||
        publicKey == null ||
        publicKey.isEmpty) {
      throw StateError('Backup does not contain a valid encryption identity.');
    }

    await _writeSecure(_privateKeyPref, privateKey);
    await _writeSecure(_publicKeyPref, publicKey);
    _privateKey = null;
    _publicKeyBase64 = null;
    await _ensureIdentityKey();
  }

  bool isEncryptedTextPayload(String value) => value.startsWith(_messagePrefix);

  bool isDecryptFailureText(String value) =>
      value == '[Encrypted message could not be verified]' ||
      value == '[Encrypted message could not be decrypted]';

  String fingerprintForPublicKey(String publicKeyBase64) {
    final digest = SHA256Digest().process(base64Decode(publicKeyBase64));
    final hex = digest
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join()
        .toUpperCase();
    final groups = <String>[];
    for (var i = 0; i < hex.length; i += 4) {
      groups.add(hex.substring(i, i + 4));
    }
    return groups.join(' ');
  }

  Future<String> encryptText({
    required String plaintext,
    required String recipientPublicKeyBase64,
  }) async {
    if (plaintext.isEmpty) {
      return plaintext;
    }

    await _ensureIdentityKey();

    final recipientPublicKey = _decodePublicKey(recipientPublicKeyBase64);
    final keyMaterial = _deriveConversationKeys(recipientPublicKey);
    final iv = _secureBytes(16);
    final ciphertext = _aesCbc(
      encrypt: true,
      key: keyMaterial.encryptionKey,
      iv: iv,
      input: Uint8List.fromList(utf8.encode(plaintext)),
    );

    final macInput = _concat([
      utf8.encode('Hestia text v1'),
      iv,
      ciphertext,
      utf8.encode(_publicKeyBase64!),
      utf8.encode(recipientPublicKeyBase64),
    ]);
    final mac = _hmacSha256(keyMaterial.macKey, macInput);

    final payload = jsonEncode({
      'senderPublicKey': _publicKeyBase64,
      'recipientPublicKey': recipientPublicKeyBase64,
      'iv': base64Encode(iv),
      'ciphertext': base64Encode(ciphertext),
      'mac': base64Encode(mac),
    });

    return '$_messagePrefix${base64Encode(utf8.encode(payload))}';
  }

  Future<String> encryptAttachment({
    required String fileName,
    required String kind,
    required int sizeBytes,
    required Uint8List bytes,
    required String recipientPublicKeyBase64,
    Map<String, dynamic>? messageMetadata,
  }) async {
    final plaintext = jsonEncode({
      'name': fileName,
      'kind': kind,
      'sizeBytes': sizeBytes,
      'base64': base64Encode(bytes),
      if (messageMetadata != null) 'messageMetadata': messageMetadata,
    });

    final payload = await _encryptPayload(
      plaintext: Uint8List.fromList(utf8.encode(plaintext)),
      recipientPublicKeyBase64: recipientPublicKeyBase64,
      macLabel: 'Hestia attachment v1',
    );

    return '$_attachmentPrefix${base64Encode(utf8.encode(payload))}';
  }

  Future<String> decryptText(String value) async {
    if (!value.startsWith(_messagePrefix)) {
      return value;
    }

    await _ensureIdentityKey();

    try {
      final encoded = value.substring(_messagePrefix.length);
      final payload = jsonDecode(utf8.decode(base64Decode(encoded)))
          as Map<String, dynamic>;
      final senderPublicKeyBase64 = payload['senderPublicKey'] as String;
      final recipientPublicKeyBase64 =
          payload['recipientPublicKey'] as String? ?? _publicKeyBase64!;
      final iv = base64Decode(payload['iv'] as String);
      final ciphertext = base64Decode(payload['ciphertext'] as String);
      final mac = base64Decode(payload['mac'] as String);

      final senderPublicKey = _decodePublicKey(senderPublicKeyBase64);
      final keyMaterial = _deriveConversationKeys(senderPublicKey);
      final macInput = _concat([
        utf8.encode('Hestia text v1'),
        iv,
        ciphertext,
        utf8.encode(senderPublicKeyBase64),
        utf8.encode(recipientPublicKeyBase64),
      ]);
      final expectedMac = _hmacSha256(keyMaterial.macKey, macInput);

      if (!_constantTimeEquals(mac, expectedMac)) {
        return '[Encrypted message could not be verified]';
      }

      final plaintext = _aesCbc(
        encrypt: false,
        key: keyMaterial.encryptionKey,
        iv: Uint8List.fromList(iv),
        input: Uint8List.fromList(ciphertext),
      );

      return utf8.decode(plaintext);
    } catch (error) {
      debugPrint('[CryptoService] decryptText failed: $error');
      return '[Encrypted message could not be decrypted]';
    }
  }

  Future<DecryptedAttachmentData?> decryptAttachment(String value) async {
    if (!value.startsWith(_attachmentPrefix)) {
      return null;
    }

    try {
      final encoded = value.substring(_attachmentPrefix.length);
      final plaintext = await _decryptPayload(
        payloadJson: utf8.decode(base64Decode(encoded)),
        macLabel: 'Hestia attachment v1',
      );
      final json = jsonDecode(utf8.decode(plaintext)) as Map<String, dynamic>;
      final data = base64Decode(json['base64'] as String);

      return DecryptedAttachmentData(
        name: json['name'] as String? ?? 'attachment.bin',
        kind: json['kind'] as String? ?? 'document',
        sizeBytes: json['sizeBytes'] as int? ?? data.length,
        bytes: Uint8List.fromList(data),
        messageMetadata: json['messageMetadata'] is Map
            ? Map<String, dynamic>.from(json['messageMetadata'] as Map)
            : null,
      );
    } catch (error) {
      debugPrint('[CryptoService] decryptAttachment failed: $error');
      return null;
    }
  }

  Future<String> _encryptPayload({
    required Uint8List plaintext,
    required String recipientPublicKeyBase64,
    required String macLabel,
  }) async {
    await _ensureIdentityKey();

    final recipientPublicKey = _decodePublicKey(recipientPublicKeyBase64);
    final keyMaterial = _deriveConversationKeys(recipientPublicKey);
    final iv = _secureBytes(16);
    final ciphertext = _aesCbc(
      encrypt: true,
      key: keyMaterial.encryptionKey,
      iv: iv,
      input: plaintext,
    );

    final macInput = _concat([
      utf8.encode(macLabel),
      iv,
      ciphertext,
      utf8.encode(_publicKeyBase64!),
      utf8.encode(recipientPublicKeyBase64),
    ]);
    final mac = _hmacSha256(keyMaterial.macKey, macInput);

    return jsonEncode({
      'senderPublicKey': _publicKeyBase64,
      'recipientPublicKey': recipientPublicKeyBase64,
      'iv': base64Encode(iv),
      'ciphertext': base64Encode(ciphertext),
      'mac': base64Encode(mac),
    });
  }

  Future<Uint8List> _decryptPayload({
    required String payloadJson,
    required String macLabel,
  }) async {
    await _ensureIdentityKey();

    final payload = jsonDecode(payloadJson) as Map<String, dynamic>;
    final senderPublicKeyBase64 = payload['senderPublicKey'] as String;
    final recipientPublicKeyBase64 =
        payload['recipientPublicKey'] as String? ?? _publicKeyBase64!;
    final iv = base64Decode(payload['iv'] as String);
    final ciphertext = base64Decode(payload['ciphertext'] as String);
    final mac = base64Decode(payload['mac'] as String);

    final senderPublicKey = _decodePublicKey(senderPublicKeyBase64);
    final keyMaterial = _deriveConversationKeys(senderPublicKey);
    final macInput = _concat([
      utf8.encode(macLabel),
      iv,
      ciphertext,
      utf8.encode(senderPublicKeyBase64),
      utf8.encode(recipientPublicKeyBase64),
    ]);
    final expectedMac = _hmacSha256(keyMaterial.macKey, macInput);

    if (!_constantTimeEquals(mac, expectedMac)) {
      throw StateError('Encrypted payload verification failed');
    }

    return _aesCbc(
      encrypt: false,
      key: keyMaterial.encryptionKey,
      iv: Uint8List.fromList(iv),
      input: Uint8List.fromList(ciphertext),
    );
  }

  Future<void> _ensureIdentityKey() async {
    if (_privateKey != null && _publicKeyBase64 != null) {
      return;
    }

    final storedPrivateKey = await _readSecureWithMigration(_privateKeyPref);
    final storedPublicKey = await _readSecureWithMigration(_publicKeyPref);

    if (storedPrivateKey != null && storedPublicKey != null) {
      _privateKey = ECPrivateKey(_decodeBigInt(storedPrivateKey), _domain);
      _publicKeyBase64 = storedPublicKey;
      return;
    }

    final pair = _generateKeyPair();
    final privateKey = pair.privateKey as ECPrivateKey;
    final publicKey = pair.publicKey as ECPublicKey;

    final privateKeyBase64 = _encodeBigInt(privateKey.d!, 32);
    final publicKeyBase64 = base64Encode(publicKey.Q!.getEncoded(false));

    await _writeSecure(_privateKeyPref, privateKeyBase64);
    await _writeSecure(_publicKeyPref, publicKeyBase64);

    _privateKey = privateKey;
    _publicKeyBase64 = publicKeyBase64;
  }

  AsymmetricKeyPair<PublicKey, PrivateKey> _generateKeyPair() {
    final generator = ECKeyGenerator()
      ..init(
        ParametersWithRandom(
          ECKeyGeneratorParameters(_domain),
          _secureRandom(),
        ),
      );

    return generator.generateKeyPair();
  }

  ECPublicKey _decodePublicKey(String publicKeyBase64) {
    final point = _domain.curve.decodePoint(base64Decode(publicKeyBase64));
    if (point == null) {
      throw ArgumentError('Invalid public key');
    }
    return ECPublicKey(point, _domain);
  }

  _ConversationKeys _deriveConversationKeys(ECPublicKey peerPublicKey) {
    final agreement = ECDHBasicAgreement()..init(_privateKey!);
    final sharedSecret = agreement.calculateAgreement(peerPublicKey);
    final secretBytes = _bigIntToBytes(sharedSecret, 32);
    final digest = SHA256Digest();

    final encryptionKey = digest.process(
      _concat([
        utf8.encode('Hestia E2EE encryption key v1'),
        secretBytes,
      ]),
    );
    final macKey = digest.process(
      _concat([
        utf8.encode('Hestia E2EE mac key v1'),
        secretBytes,
      ]),
    );

    return _ConversationKeys(encryptionKey: encryptionKey, macKey: macKey);
  }

  Uint8List _aesCbc({
    required bool encrypt,
    required Uint8List key,
    required Uint8List iv,
    required Uint8List input,
  }) {
    final cipher = PaddedBlockCipherImpl(
      PKCS7Padding(),
      CBCBlockCipher(AESEngine()),
    )..init(
        encrypt,
        PaddedBlockCipherParameters<ParametersWithIV<KeyParameter>, Null>(
          ParametersWithIV(KeyParameter(key), iv),
          null,
        ),
      );

    return cipher.process(input);
  }

  Uint8List _hmacSha256(Uint8List key, Uint8List input) {
    final hmac = HMac(SHA256Digest(), 64)..init(KeyParameter(key));
    return hmac.process(input);
  }

  SecureRandom _secureRandom() {
    final random = FortunaRandom();
    random.seed(KeyParameter(_secureBytes(32)));
    return random;
  }

  Uint8List _secureBytes(int length) {
    final random = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(length, (_) => random.nextInt(256)),
    );
  }

  Uint8List _concat(List<List<int>> chunks) {
    final length = chunks.fold<int>(0, (sum, chunk) => sum + chunk.length);
    final result = Uint8List(length);
    var offset = 0;
    for (final chunk in chunks) {
      result.setRange(offset, offset + chunk.length, chunk);
      offset += chunk.length;
    }
    return result;
  }

  bool _constantTimeEquals(List<int> left, List<int> right) {
    if (left.length != right.length) {
      return false;
    }

    var diff = 0;
    for (var i = 0; i < left.length; i += 1) {
      diff |= left[i] ^ right[i];
    }
    return diff == 0;
  }

  String _encodeBigInt(BigInt value, int size) =>
      base64Encode(_bigIntToBytes(value, size));

  BigInt _decodeBigInt(String value) {
    var result = BigInt.zero;
    for (final byte in base64Decode(value)) {
      result = (result << 8) | BigInt.from(byte);
    }
    return result;
  }

  Uint8List _bigIntToBytes(BigInt value, int size) {
    final result = Uint8List(size);
    var current = value;
    for (var i = size - 1; i >= 0; i -= 1) {
      result[i] = (current & BigInt.from(0xff)).toInt();
      current = current >> 8;
    }
    return result;
  }

  Future<String?> _readSecureWithMigration(String key) async {
    final secureValue = await _secureStorage.read(key: key);
    if (secureValue != null && secureValue.isNotEmpty) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(key);
      return secureValue;
    }
    final prefs = await SharedPreferences.getInstance();
    final legacyValue = prefs.getString(key);
    if (legacyValue == null || legacyValue.isEmpty) {
      return null;
    }
    await _writeSecure(key, legacyValue);
    await prefs.remove(key);
    return legacyValue;
  }

  Future<void> _writeSecure(String key, String value) =>
      _secureStorage.write(key: key, value: value);
}

class DecryptedAttachmentData {
  final String name;
  final String kind;
  final int sizeBytes;
  final Uint8List bytes;
  final Map<String, dynamic>? messageMetadata;

  const DecryptedAttachmentData({
    required this.name,
    required this.kind,
    required this.sizeBytes,
    required this.bytes,
    this.messageMetadata,
  });
}

class _ConversationKeys {
  final Uint8List encryptionKey;
  final Uint8List macKey;

  const _ConversationKeys({
    required this.encryptionKey,
    required this.macKey,
  });
}
