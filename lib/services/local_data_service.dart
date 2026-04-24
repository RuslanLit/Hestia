import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';
import 'web_large_storage_stub.dart'
    if (dart.library.html) 'web_large_storage_web.dart';

class SavedAttachment {
  final ChatAttachment attachment;
  final String base64Data;

  const SavedAttachment({
    required this.attachment,
    required this.base64Data,
  });
}

class LocalDataService {
  LocalDataService._();
  static final LocalDataService instance = LocalDataService._();

  Directory? _rootDir;
  Directory? _attachmentsDir;
  File? _conversationsFile;
  SharedPreferences? _prefs;
  String? _userId;
  final Map<String, String> _webAttachmentData = {};

  bool get isInitialized =>
      kIsWeb ? _prefs != null && _userId != null : _conversationsFile != null;
  String? get userId => _userId;

  Future<void> init(String userId) async {
    if (_userId == userId && isInitialized) {
      return;
    }

    if (kIsWeb) {
      _prefs = await SharedPreferences.getInstance();
      _userId = userId;
      return;
    }

    final docsDir = await getApplicationDocumentsDirectory();
    final rootDir = Directory(
        '${docsDir.path}${Platform.pathSeparator}hestia${Platform.pathSeparator}$userId');
    final attachmentsDir =
        Directory('${rootDir.path}${Platform.pathSeparator}attachments');

    if (!rootDir.existsSync()) {
      await rootDir.create(recursive: true);
    }
    if (!attachmentsDir.existsSync()) {
      await attachmentsDir.create(recursive: true);
    }

    _userId = userId;
    _rootDir = rootDir;
    _attachmentsDir = attachmentsDir;
    _conversationsFile =
        File('${rootDir.path}${Platform.pathSeparator}conversations.json');

    if (!_conversationsFile!.existsSync()) {
      await _conversationsFile!.writeAsString('[]');
    }
  }

  Future<List<Conversation>> loadConversations() async {
    if (kIsWeb) {
      return _loadWebConversations();
    }

    final file = _requireConversationsFile();
    if (!file.existsSync()) {
      return [];
    }

    final raw = await file.readAsString();
    if (raw.trim().isEmpty) {
      return [];
    }

    return _decodeConversations(raw);
  }

  Future<void> saveConversations(List<Conversation> conversations) async {
    if (kIsWeb) {
      await _saveWebConversations(conversations);
      return;
    }

    final safeConversations = conversations;
    final encoded = jsonEncode(
      safeConversations.map((conversation) => conversation.toJson()).toList(),
    );

    final file = _requireConversationsFile();
    await _safeWriteFile(file, encoded);
  }

  Future<List<Contact>> loadContacts() async {
    return _decodeList(_contactsKey, 'contacts.json', Contact.fromJson);
  }

  Future<void> saveContacts(List<Contact> contacts) async {
    await _saveList(_contactsKey, 'contacts.json', contacts);
  }

  Future<List<ContactRequest>> loadContactRequests() async {
    return _decodeList(
      _contactRequestsKey,
      'contact_requests.json',
      ContactRequest.fromJson,
    );
  }

  Future<void> saveContactRequests(List<ContactRequest> requests) async {
    await _saveList(_contactRequestsKey, 'contact_requests.json', requests);
  }

  Future<List<BlockListEntry>> loadBlockList() async {
    return _decodeList(
        _blockListKey, 'block_list.json', BlockListEntry.fromJson);
  }

  Future<void> saveBlockList(List<BlockListEntry> entries) async {
    await _saveList(_blockListKey, 'block_list.json', entries);
  }

  Future<PrivacySettings> loadPrivacySettings() async {
    final raw = kIsWeb
        ? _requirePrefs().getString(_privacySettingsKey)
        : await _readLocalJsonFile('privacy_settings.json');
    if (raw == null || raw.trim().isEmpty) {
      return const PrivacySettings();
    }
    return PrivacySettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> savePrivacySettings(PrivacySettings settings) async {
    final raw = jsonEncode(settings.toJson());
    if (kIsWeb) {
      await _safePrefsSetString(_privacySettingsKey, raw);
      return;
    }
    await _writeLocalJsonFile('privacy_settings.json', raw);
  }

  Future<Map<String, int>> loadUnreadCounts() async {
    final raw = kIsWeb
        ? _requirePrefs().getString(_unreadCountsKey)
        : await _readLocalJsonFile('unread_counts.json');
    if (raw == null || raw.trim().isEmpty) {
      return {};
    }

    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return decoded.map(
      (key, value) => MapEntry(key, (value as num?)?.toInt() ?? 0),
    )..removeWhere((_, value) => value <= 0);
  }

  Future<void> saveUnreadCounts(Map<String, int> unreadCounts) async {
    final cleaned = Map<String, int>.from(unreadCounts)
      ..removeWhere((_, value) => value <= 0);
    final raw = jsonEncode(cleaned);
    if (kIsWeb) {
      await _safePrefsSetString(_unreadCountsKey, raw);
      return;
    }
    await _writeLocalJsonFile('unread_counts.json', raw);
  }

  Future<Set<String>> loadUnreadContactRequestIds() async {
    final raw = kIsWeb
        ? _requirePrefs().getString(_unreadContactRequestsKey)
        : await _readLocalJsonFile('unread_contact_requests.json');
    if (raw == null || raw.trim().isEmpty) {
      return {};
    }

    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded.whereType<String>().toSet();
  }

  Future<void> saveUnreadContactRequestIds(Set<String> requestIds) async {
    final raw = jsonEncode(requestIds.toList()..sort());
    if (kIsWeb) {
      await _safePrefsSetString(_unreadContactRequestsKey, raw);
      return;
    }
    await _writeLocalJsonFile('unread_contact_requests.json', raw);
  }

  Future<List<ChatLocalSettings>> loadChatSettings() async {
    return _decodeList(
      _chatSettingsKey,
      'chat_settings.json',
      ChatLocalSettings.fromJson,
    );
  }

  Future<void> saveChatSettings(List<ChatLocalSettings> settings) async {
    await _saveList(_chatSettingsKey, 'chat_settings.json', settings);
  }

  Future<List<Conversation>> _loadWebConversations() async {
    final migrated = await _migrateLegacyWebConversations();
    if (migrated.isNotEmpty) {
      return migrated;
    }

    final indexRaw = await WebLargeStorage.getString(_webConversationIndexKey);
    if (indexRaw == null || indexRaw.trim().isEmpty) {
      return [];
    }

    final index = jsonDecode(indexRaw) as List<dynamic>;
    final conversations = <Conversation>[];
    for (final item in index) {
      final summary = Map<String, dynamic>.from(item as Map);
      final id = summary['id'] as String? ?? '';
      if (id.isEmpty) {
        continue;
      }
      final messagesRaw =
          await WebLargeStorage.getString(_webConversationMessagesKey(id));
      final messages = messagesRaw == null || messagesRaw.trim().isEmpty
          ? <ChatMessage>[]
          : (jsonDecode(messagesRaw) as List<dynamic>)
              .map((message) => ChatMessage.fromJson(
                    Map<String, dynamic>.from(message as Map),
                  ))
              .toList();
      conversations.add(
        Conversation(
          id: id,
          peerUserId: summary['peerUserId'] as String? ?? '',
          peerNickname: summary['peerNickname'] as String? ?? 'Unknown',
          messages: messages,
        ),
      );
    }
    return conversations..sort(_sortConversations);
  }

  Future<void> _saveWebConversations(List<Conversation> conversations) async {
    final sanitized = _conversationsWithoutWebBytes(conversations);
    final index = sanitized
        .map((conversation) => {
              'id': conversation.id,
              'peerUserId': conversation.peerUserId,
              'peerNickname': conversation.peerNickname,
              'updatedAt': (conversation.lastMessage?.timestamp ??
                      DateTime.fromMillisecondsSinceEpoch(0))
                  .toIso8601String(),
              'lastMessagePreview': _lastMessagePreview(conversation),
            })
        .toList();

    try {
      await WebLargeStorage.setString(
        _webConversationIndexKey,
        jsonEncode(index),
      );
      for (final conversation in sanitized) {
        await WebLargeStorage.setString(
          _webConversationMessagesKey(conversation.id),
          jsonEncode(
            conversation.messages.map((message) => message.toJson()).toList(),
          ),
        );
      }
      await _safePrefsRemove(_webConversationsKey);
    } catch (error) {
      debugPrint('[LocalDataService] Web conversation save failed: $error');
    }
  }

  Future<List<Conversation>> _migrateLegacyWebConversations() async {
    final legacyRaw = _requirePrefs().getString(_webConversationsKey);
    if (legacyRaw == null || legacyRaw.trim().isEmpty) {
      return [];
    }

    try {
      final conversations = _decodeConversations(legacyRaw);
      await _saveWebConversations(conversations);
      await _safePrefsRemove(_webConversationsKey);
      return conversations;
    } catch (error) {
      debugPrint(
          '[LocalDataService] Legacy web conversation migration failed: $error');
      return [];
    }
  }

  Future<SavedAttachment> saveBytesAsAttachment({
    required String messageId,
    required String fileName,
    required Uint8List bytes,
  }) async {
    if (kIsWeb) {
      final base64Data = base64Encode(bytes);
      _webAttachmentData[messageId] = base64Data;
      return SavedAttachment(
        attachment: ChatAttachment(
          id: messageId,
          name: fileName,
          localPath: 'web:$messageId',
          sizeBytes: bytes.length,
          kind: inferAttachmentKind(fileName),
        ),
        base64Data: base64Data,
      );
    }

    final dir = _requireAttachmentsDir();
    final safeName = _sanitizeFileName(fileName);
    final path = '${dir.path}${Platform.pathSeparator}${messageId}_$safeName';
    final file = File(path);
    await file.writeAsBytes(bytes, flush: true);

    return SavedAttachment(
      attachment: ChatAttachment(
        id: messageId,
        name: fileName,
        localPath: file.path,
        sizeBytes: bytes.length,
        kind: inferAttachmentKind(fileName),
      ),
      base64Data: base64Encode(bytes),
    );
  }

  Future<String> exportAttachment(ChatAttachment attachment) async {
    if (kIsWeb) {
      return _webAttachmentData.containsKey(attachment.id)
          ? 'Файл доступен в текущей сессии браузера.'
          : 'Файл недоступен после перезапуска браузера.';
    }

    final source = File(attachment.localPath);
    if (!source.existsSync()) {
      throw Exception('Local file not found: ${attachment.localPath}');
    }

    final destinationDir = await _resolveExportDirectory();
    if (!destinationDir.existsSync()) {
      await destinationDir.create(recursive: true);
    }

    final destination = File(
      '${destinationDir.path}${Platform.pathSeparator}${_buildExportName(attachment.name)}',
    );

    await source.copy(destination.path);
    return destination.path;
  }

  Future<Uint8List?> readAttachmentBytes(ChatAttachment attachment) async {
    if (kIsWeb) {
      return webAttachmentBytes(attachment);
    }

    final file = File(attachment.localPath);
    if (!file.existsSync()) {
      return null;
    }
    return file.readAsBytes();
  }

  List<Conversation> _decodeConversations(String raw) {
    if (raw.trim().isEmpty) {
      return [];
    }

    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((item) =>
            Conversation.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList()
      ..sort(_sortConversations);
  }

  Uint8List? webAttachmentBytes(ChatAttachment attachment) {
    if (!kIsWeb) {
      return null;
    }
    final inlineValue = attachment.localPath.startsWith('web:')
        ? attachment.localPath.substring(4)
        : '';
    final base64Value = inlineValue.length > 128
        ? inlineValue
        : _webAttachmentData[attachment.id];
    if (base64Value == null || base64Value.isEmpty) {
      return null;
    }
    try {
      return base64Decode(base64Value);
    } catch (_) {
      return null;
    }
  }

  List<Conversation> _conversationsWithoutWebBytes(
    List<Conversation> conversations,
  ) {
    return conversations
        .map((conversation) => conversation.copyWith(
              messages:
                  conversation.messages.map(_messageWithoutWebBytes).toList(),
            ))
        .toList();
  }

  ChatMessage _messageWithoutWebBytes(ChatMessage message) {
    final attachment = message.attachment;
    if (attachment == null ||
        !attachment.localPath.startsWith('web:') ||
        attachment.localPath.length <= 128) {
      return message;
    }
    _webAttachmentData[attachment.id] = attachment.localPath.substring(4);
    return ChatMessage(
      id: message.id,
      conversationId: message.conversationId,
      peerUserId: message.peerUserId,
      fromUserId: message.fromUserId,
      fromNickname: message.fromNickname,
      text: message.text,
      timestamp: message.timestamp,
      isMe: message.isMe,
      attachment: ChatAttachment(
        id: attachment.id,
        name: attachment.name,
        localPath: 'web:${attachment.id}',
        sizeBytes: attachment.sizeBytes,
        kind: attachment.kind,
      ),
      status: message.status,
      replyToMessageId: message.replyToMessageId,
      replyToSenderId: message.replyToSenderId,
      replyToSenderName: message.replyToSenderName,
      replyPreviewText: message.replyPreviewText,
      replyPreviewType: message.replyPreviewType,
      isForwarded: message.isForwarded,
      forwardedFromSenderId: message.forwardedFromSenderId,
      forwardedFromSenderName: message.forwardedFromSenderName,
      forwardedFromMessageId: message.forwardedFromMessageId,
    );
  }

  int _sortConversations(Conversation a, Conversation b) {
    final left =
        a.lastMessage?.timestamp ?? DateTime.fromMillisecondsSinceEpoch(0);
    final right =
        b.lastMessage?.timestamp ?? DateTime.fromMillisecondsSinceEpoch(0);
    return right.compareTo(left);
  }

  String _lastMessagePreview(Conversation conversation) {
    final last = conversation.lastMessage;
    if (last == null) {
      return '';
    }
    if (last.attachment != null) {
      return 'Attachment: ${last.attachment!.name}';
    }
    return last.text;
  }

  Future<List<T>> _decodeList<T>(
    String webKey,
    String fileName,
    T Function(Map<String, dynamic>) fromJson,
  ) async {
    final raw = kIsWeb
        ? _requirePrefs().getString(webKey) ?? '[]'
        : await _readLocalJsonFile(fileName) ?? '[]';
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((item) => fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
  }

  Future<void> _saveList<T>(
    String webKey,
    String fileName,
    List<T> items,
  ) async {
    final encoded = jsonEncode(
      items.map((item) => (item as dynamic).toJson()).toList(),
    );
    if (kIsWeb) {
      await _safePrefsSetString(webKey, encoded);
      return;
    }
    await _writeLocalJsonFile(fileName, encoded);
  }

  Future<String?> _readLocalJsonFile(String fileName) async {
    final rootDir = _rootDir;
    if (rootDir == null) {
      throw StateError('LocalDataService is not initialized.');
    }
    final file = File('${rootDir.path}${Platform.pathSeparator}$fileName');
    if (!file.existsSync()) return null;
    return file.readAsString();
  }

  Future<void> _writeLocalJsonFile(String fileName, String raw) async {
    final rootDir = _rootDir;
    if (rootDir == null) {
      throw StateError('LocalDataService is not initialized.');
    }
    final file = File('${rootDir.path}${Platform.pathSeparator}$fileName');
    await _safeWriteFile(file, raw);
  }

  Future<void> _safeWriteFile(File file, String raw) async {
    try {
      await file.writeAsString(raw);
    } catch (error) {
      debugPrint('[LocalDataService] File write failed (${file.path}): $error');
    }
  }

  Future<void> _safePrefsSetString(String key, String value) async {
    try {
      await _requirePrefs().setString(key, value);
    } catch (error) {
      debugPrint(
          '[LocalDataService] SharedPreferences write failed ($key): $error');
    }
  }

  Future<void> _safePrefsRemove(String key) async {
    try {
      await _requirePrefs().remove(key);
    } catch (error) {
      debugPrint(
          '[LocalDataService] SharedPreferences remove failed ($key): $error');
    }
  }

  Future<Directory> _resolveExportDirectory() async {
    final downloads = await getDownloadsDirectory();
    if (downloads != null) {
      return Directory('${downloads.path}${Platform.pathSeparator}Hestia');
    }
    final rootDir = _rootDir;
    if (rootDir == null) {
      throw StateError('LocalDataService is not initialized.');
    }
    return Directory('${rootDir.path}${Platform.pathSeparator}exports');
  }

  Directory _requireAttachmentsDir() {
    final dir = _attachmentsDir;
    if (dir == null) {
      throw StateError('LocalDataService is not initialized.');
    }
    return dir;
  }

  File _requireConversationsFile() {
    final file = _conversationsFile;
    if (file == null) {
      throw StateError('LocalDataService is not initialized.');
    }
    return file;
  }

  SharedPreferences _requirePrefs() {
    final prefs = _prefs;
    if (prefs == null) {
      throw StateError('LocalDataService is not initialized.');
    }
    return prefs;
  }

  String get _webConversationsKey {
    final currentUserId = _userId;
    if (currentUserId == null) {
      throw StateError('LocalDataService is not initialized.');
    }
    return 'hestia_${currentUserId}_conversations';
  }

  String get _webConversationIndexKey =>
      'hestia_${_requireUserId()}_conversation_index_v2';

  String _webConversationMessagesKey(String conversationId) =>
      'hestia_${_requireUserId()}_conversation_messages_v2_$conversationId';

  String get _contactsKey => 'hestia_${_requireUserId()}_contacts';
  String get _contactRequestsKey =>
      'hestia_${_requireUserId()}_contact_requests';
  String get _blockListKey => 'hestia_${_requireUserId()}_block_list';
  String get _privacySettingsKey =>
      'hestia_${_requireUserId()}_privacy_settings';
  String get _unreadCountsKey => 'hestia_${_requireUserId()}_unread_counts';
  String get _unreadContactRequestsKey =>
      'hestia_${_requireUserId()}_unread_contact_requests';
  String get _chatSettingsKey => 'hestia_${_requireUserId()}_chat_settings';

  String _requireUserId() {
    final currentUserId = _userId;
    if (currentUserId == null) {
      throw StateError('LocalDataService is not initialized.');
    }
    return currentUserId;
  }

  String _sanitizeFileName(String name) =>
      name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');

  String _buildExportName(String originalName) {
    final stamp = DateTime.now().millisecondsSinceEpoch;
    return '${stamp}_${_sanitizeFileName(originalName)}';
  }
}
