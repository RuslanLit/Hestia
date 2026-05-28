import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:pointycastle/export.dart';

import '../config.dart';
import '../models/models.dart';
import 'crypto_service.dart';
import 'local_data_service.dart';
import 'storage_service.dart';

class BackupService {
  BackupService._();
  static final BackupService instance = BackupService._();

  static const _format = 'HESTIA_BACKUP_V1';
  static const _iterations = 120000;

  Future<String?> exportEncryptedBackup(
    String passphrase, {
    required String dialogTitle,
  }) async {
    final profile = StorageService.instance.loadProfile();
    if (profile == null) {
      throw StateError('No profile is available to export.');
    }
    _validatePassphrase(passphrase);

    await LocalDataService.instance.init(profile.userId);
    final payload = await _buildBackupPayload(profile);
    final encrypted = _encryptBackup(
      plaintext: Uint8List.fromList(utf8.encode(jsonEncode(payload))),
      passphrase: passphrase,
    );
    final bytes = Uint8List.fromList(utf8.encode(jsonEncode(encrypted)));
    final fileName =
        'hestia-backup-${DateTime.now().millisecondsSinceEpoch}.hbak';

    final path = await FilePicker.saveFile(
      dialogTitle: dialogTitle,
      fileName: fileName,
      bytes: bytes,
    );
    if (path != null && !kIsWeb) {
      await File(path).writeAsBytes(bytes, flush: true);
    }
    return path;
  }

  Future<UserProfile> importEncryptedBackup(String passphrase) async {
    _validatePassphrase(passphrase);
    final result = await FilePicker.pickFiles(
      allowMultiple: false,
      withData: true,
    );
    if (result == null || result.files.isEmpty) {
      throw StateError('No backup file selected.');
    }

    final picked = result.files.single;
    final bytes = picked.bytes ??
        (!kIsWeb && picked.path != null
            ? await File(picked.path!).readAsBytes()
            : null);
    if (bytes == null || bytes.isEmpty) {
      throw StateError('Could not read backup file.');
    }

    final encrypted = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
    final plaintext = _decryptBackup(encrypted, passphrase);
    final payload = jsonDecode(utf8.decode(plaintext)) as Map<String, dynamic>;
    return _restoreBackupPayload(payload);
  }

  Future<Map<String, dynamic>> _buildBackupPayload(UserProfile profile) async {
    final conversations = await LocalDataService.instance.loadConversations();
    final attachments = await _collectAttachments(conversations);

    return {
      'format': _format,
      'exportedAt': DateTime.now().toIso8601String(),
      'serverUrl': AppConfig.serverInput,
      'profile': profile.toJson(),
      'cryptoIdentity': await CryptoService.instance.exportIdentityForBackup(),
      'trustedPeerKeys': StorageService.instance.exportTrustedPeerKeys(),
      'localData': {
        'conversations':
            conversations.map((conversation) => conversation.toJson()).toList(),
        'contacts': (await LocalDataService.instance.loadContacts())
            .map((contact) => contact.toJson())
            .toList(),
        'contactRequests':
            (await LocalDataService.instance.loadContactRequests())
                .map((request) => request.toJson())
                .toList(),
        'blockList': (await LocalDataService.instance.loadBlockList())
            .map((entry) => entry.toJson())
            .toList(),
        'privacySettings':
            (await LocalDataService.instance.loadPrivacySettings()).toJson(),
        'unreadCounts': await LocalDataService.instance.loadUnreadCounts(),
        'unreadContactRequestIds':
            (await LocalDataService.instance.loadUnreadContactRequestIds())
                .toList(),
        'chatSettings': (await LocalDataService.instance.loadChatSettings())
            .map((settings) => settings.toJson())
            .toList(),
      },
      'attachments': attachments,
    };
  }

  Future<Map<String, dynamic>> _collectAttachments(
    List<Conversation> conversations,
  ) async {
    final result = <String, dynamic>{};
    for (final conversation in conversations) {
      for (final message in conversation.messages) {
        final attachment = message.attachment;
        if (attachment == null || result.containsKey(attachment.id)) {
          continue;
        }
        Uint8List? bytes;
        if (kIsWeb && attachment.localPath.startsWith('web:')) {
          bytes = base64Decode(attachment.localPath.substring(4));
        } else if (!kIsWeb && File(attachment.localPath).existsSync()) {
          bytes = await File(attachment.localPath).readAsBytes();
        }
        if (bytes == null) {
          continue;
        }
        result[attachment.id] = {
          'name': attachment.name,
          'base64': base64Encode(bytes),
        };
      }
    }
    return result;
  }

  Future<UserProfile> _restoreBackupPayload(
      Map<String, dynamic> payload) async {
    if (payload['format'] != _format) {
      throw StateError('Unsupported backup format.');
    }

    final profile = UserProfile.fromJson(
      Map<String, dynamic>.from(payload['profile'] as Map),
    );
    await AppConfig.setServerInput(payload['serverUrl'] as String? ?? '');
    await StorageService.instance.saveProfile(profile);
    await CryptoService.instance.importIdentityFromBackup(
      Map<String, dynamic>.from(payload['cryptoIdentity'] as Map),
    );
    await StorageService.instance.importTrustedPeerKeys(
      Map<String, dynamic>.from(payload['trustedPeerKeys'] as Map? ?? {}),
    );

    await LocalDataService.instance.init(profile.userId);
    final localData = Map<String, dynamic>.from(payload['localData'] as Map);
    final attachments = Map<String, dynamic>.from(
      payload['attachments'] as Map? ?? {},
    );

    await LocalDataService.instance.saveConversations(
      await _restoreConversations(localData, attachments),
    );
    await LocalDataService.instance.saveContacts(
      _decodeList(localData['contacts'], Contact.fromJson),
    );
    await LocalDataService.instance.saveContactRequests(
      _decodeList(localData['contactRequests'], ContactRequest.fromJson),
    );
    await LocalDataService.instance.saveBlockList(
      _decodeList(localData['blockList'], BlockListEntry.fromJson),
    );
    await LocalDataService.instance.savePrivacySettings(
      PrivacySettings.fromJson(
        Map<String, dynamic>.from(localData['privacySettings'] as Map? ?? {}),
      ),
    );
    await LocalDataService.instance.saveUnreadCounts(
      Map<String, dynamic>.from(localData['unreadCounts'] as Map? ?? {}).map(
        (key, value) => MapEntry(key, (value as num?)?.toInt() ?? 0),
      ),
    );
    await LocalDataService.instance.saveUnreadContactRequestIds(
      (localData['unreadContactRequestIds'] as List<dynamic>? ?? [])
          .whereType<String>()
          .toSet(),
    );
    await LocalDataService.instance.saveChatSettings(
      _decodeList(localData['chatSettings'], ChatLocalSettings.fromJson),
    );
    return profile;
  }

  Future<List<Conversation>> _restoreConversations(
    Map<String, dynamic> localData,
    Map<String, dynamic> attachmentBytes,
  ) async {
    final raw = localData['conversations'] as List<dynamic>? ?? [];
    final conversations = <Conversation>[];
    for (final item in raw) {
      final conversation =
          Conversation.fromJson(Map<String, dynamic>.from(item as Map));
      final messages = <ChatMessage>[];
      for (final message in conversation.messages) {
        messages.add(await _restoreMessageAttachment(message, attachmentBytes));
      }
      conversations.add(conversation.copyWith(messages: messages));
    }
    return conversations;
  }

  Future<ChatMessage> _restoreMessageAttachment(
    ChatMessage message,
    Map<String, dynamic> attachmentBytes,
  ) async {
    final attachment = message.attachment;
    if (attachment == null) {
      return message;
    }
    final data = attachmentBytes[attachment.id];
    if (data is! Map) {
      return message;
    }
    final base64Value = data['base64'] as String?;
    if (base64Value == null) {
      return message;
    }
    final saved = await LocalDataService.instance.saveBytesAsAttachment(
      messageId: attachment.id,
      fileName: data['name'] as String? ?? attachment.name,
      bytes: base64Decode(base64Value),
    );
    return message.copyWith(
      attachment: saved.attachment,
    );
  }

  List<T> _decodeList<T>(
    Object? raw,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    return (raw as List<dynamic>? ?? [])
        .map((item) => fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
  }

  Map<String, dynamic> _encryptBackup({
    required Uint8List plaintext,
    required String passphrase,
  }) {
    final salt = _secureBytes(16);
    final iv = _secureBytes(16);
    final keys = _deriveBackupKeys(passphrase, salt);
    final ciphertext = _aesCbc(
      encrypt: true,
      key: keys.encryptionKey,
      iv: iv,
      input: plaintext,
    );
    final mac = _hmacSha256(
      keys.macKey,
      _concat([utf8.encode(_format), salt, iv, ciphertext]),
    );
    return {
      'format': _format,
      'kdf': 'PBKDF2-HMAC-SHA256',
      'iterations': _iterations,
      'salt': base64Encode(salt),
      'iv': base64Encode(iv),
      'ciphertext': base64Encode(ciphertext),
      'mac': base64Encode(mac),
    };
  }

  Uint8List _decryptBackup(Map<String, dynamic> encrypted, String passphrase) {
    if (encrypted['format'] != _format) {
      throw StateError('Unsupported backup format.');
    }
    final salt = base64Decode(encrypted['salt'] as String);
    final iv = base64Decode(encrypted['iv'] as String);
    final ciphertext = base64Decode(encrypted['ciphertext'] as String);
    final mac = base64Decode(encrypted['mac'] as String);
    final keys = _deriveBackupKeys(passphrase, Uint8List.fromList(salt));
    final expectedMac = _hmacSha256(
      keys.macKey,
      _concat([utf8.encode(_format), salt, iv, ciphertext]),
    );
    if (!_constantTimeEquals(mac, expectedMac)) {
      throw StateError('Backup password is wrong or file is corrupted.');
    }
    return _aesCbc(
      encrypt: false,
      key: keys.encryptionKey,
      iv: Uint8List.fromList(iv),
      input: Uint8List.fromList(ciphertext),
    );
  }

  _BackupKeys _deriveBackupKeys(String passphrase, Uint8List salt) {
    final derivator = KeyDerivator('SHA-256/HMAC/PBKDF2')
      ..init(Pbkdf2Parameters(salt, _iterations, 64));
    final material = derivator.process(
      Uint8List.fromList(utf8.encode(passphrase)),
    );
    return _BackupKeys(
      encryptionKey: Uint8List.fromList(material.sublist(0, 32)),
      macKey: Uint8List.fromList(material.sublist(32, 64)),
    );
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

  Uint8List _hmacSha256(Uint8List key, List<int> input) {
    final hmac = HMac(SHA256Digest(), 64)..init(KeyParameter(key));
    return hmac.process(Uint8List.fromList(input));
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

  void _validatePassphrase(String passphrase) {
    if (passphrase.length < 8) {
      throw StateError('Backup password must be at least 8 characters.');
    }
  }
}

class _BackupKeys {
  final Uint8List encryptionKey;
  final Uint8List macKey;

  const _BackupKeys({
    required this.encryptionKey,
    required this.macKey,
  });
}
