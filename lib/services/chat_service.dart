import 'dart:async';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../config.dart';
import '../models/models.dart';
import 'attachment_policy.dart';
import 'backup_service.dart';
import 'call_service.dart';
import 'crypto_service.dart';
import 'diagnostic_service.dart';
import 'local_data_service.dart';
import 'push_service.dart';
import 'retention_service.dart';
import 'storage_service.dart';

class ChatService extends ChangeNotifier {
  ChatService._();
  static final ChatService instance = ChatService._();

  UserProfile? profile;
  bool get isConnected => _isConnected;

  final Map<String, Conversation> _conversations = {};
  final List<UserContact> _users = [];
  final List<Contact> _contacts = [];
  final List<ContactRequest> _contactRequests = [];
  final List<BlockListEntry> _blockList = [];
  final List<SessionInfo> _sessions = [];
  final Map<String, ChatLocalSettings> _chatSettings = {};
  final Map<String, int> _unreadCounts = {};
  final Set<String> _unreadContactRequestIds = {};
  PrivacySettings _privacySettings = const PrivacySettings();
  UserContact? _lastSearchResult;
  String _lastUsernameSearchRequest = 'none';
  String _lastUsernameSearchResult = 'none';
  String _lastError = 'none';

  List<Conversation> get conversations {
    final list = _conversations.values
        .where((conversation) => !chatSettingsFor(conversation.id).archived)
        .toList();
    list.sort((a, b) {
      final aPinned = chatSettingsFor(a.id).pinned;
      final bPinned = chatSettingsFor(b.id).pinned;
      if (aPinned != bPinned) {
        return aPinned ? -1 : 1;
      }
      final left =
          a.lastMessage?.timestamp ?? DateTime.fromMillisecondsSinceEpoch(0);
      final right =
          b.lastMessage?.timestamp ?? DateTime.fromMillisecondsSinceEpoch(0);
      return right.compareTo(left);
    });
    return list;
  }

  List<Conversation> get _storedConversations => _conversations.values.toList()
    ..sort((a, b) {
      final left =
          a.lastMessage?.timestamp ?? DateTime.fromMillisecondsSinceEpoch(0);
      final right =
          b.lastMessage?.timestamp ?? DateTime.fromMillisecondsSinceEpoch(0);
      return right.compareTo(left);
    });

  List<UserContact> get availableUsers {
    final currentUserId = profile?.userId;
    return _users.where((user) => user.userId != currentUserId).toList()
      ..sort((a, b) =>
          a.nickname.toLowerCase().compareTo(b.nickname.toLowerCase()));
  }

  List<Contact> get contacts => _contacts
      .where((contact) => contact.status == ContactStatus.active)
      .toList()
    ..sort(
        (a, b) => a.username.toLowerCase().compareTo(b.username.toLowerCase()));

  List<ContactRequest> get pendingRequests => _contactRequests
      .where((request) => request.status == ContactRequestStatus.pending)
      .toList()
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  PrivacySettings get privacySettings => _privacySettings;
  List<SessionInfo> get sessions => List.unmodifiable(_sessions);
  UserContact? get lastSearchResult => _lastSearchResult;
  String get lastUsernameSearchRequest => _lastUsernameSearchRequest;
  String get lastUsernameSearchResult => _lastUsernameSearchResult;
  String get lastError => _lastError;
  int get unreadChatCount =>
      _unreadCounts.values.fold(0, (sum, count) => sum + count);
  int get newContactRequestCount => _unreadContactRequestIds.length;
  bool hasPendingRequestWith(String peerUserId) {
    return _contactRequests.any((request) =>
        request.status == ContactRequestStatus.pending &&
        (request.fromUserId == peerUserId || request.toUserId == peerUserId));
  }

  bool shouldShowSearchResult(UserContact user) {
    return !_isActiveContact(user.userId) &&
        !hasPendingRequestWith(user.userId);
  }

  List<ChatMessage> messagesFor(String conversationId) =>
      _conversations[conversationId]?.messages ?? [];

  bool hasUnreadConversation(String conversationId) =>
      unreadCountForConversation(conversationId) > 0;

  int unreadCountForConversation(String conversationId) =>
      _unreadCounts[conversationId] ?? 0;

  void markConversationRead(String conversationId) {
    if (_unreadCounts.remove(conversationId) != null) {
      unawaited(LocalDataService.instance.saveUnreadCounts(_unreadCounts));
      notifyListeners();
    }
  }

  void markContactRequestsSeen() {
    if (_unreadContactRequestIds.isEmpty) {
      return;
    }
    _unreadContactRequestIds.clear();
    unawaited(
      LocalDataService.instance
          .saveUnreadContactRequestIds(_unreadContactRequestIds),
    );
    notifyListeners();
  }

  Conversation? conversationForPeer(String peerUserId) {
    for (final conversation in _conversations.values) {
      if (conversation.peerUserId == peerUserId) {
        return conversation;
      }
    }
    return null;
  }

  String peerNameFor(String peerUserId) {
    final conversation = conversationForPeer(peerUserId);
    if (conversation != null && conversation.peerNickname.isNotEmpty) {
      return conversation.peerNickname;
    }
    for (final contact in _contacts) {
      if (contact.peerUserId == peerUserId && contact.username.isNotEmpty) {
        return contact.username;
      }
    }
    for (final user in _users) {
      if (user.userId == peerUserId && user.nickname.isNotEmpty) {
        return user.nickname;
      }
    }
    return 'Unknown';
  }

  bool isPeerOnline(String peerUserId) =>
      _users.any((user) => user.userId == peerUserId && user.online);

  ChatLocalSettings chatSettingsFor(String conversationId) =>
      _chatSettings[conversationId] ??
      ChatLocalSettings(conversationId: conversationId);

  Future<void> toggleChatMute(String conversationId) =>
      _updateChatSettings(conversationId, (settings) {
        return settings.copyWith(muted: !settings.muted);
      });

  Future<void> toggleChatPin(String conversationId) =>
      _updateChatSettings(conversationId, (settings) {
        return settings.copyWith(pinned: !settings.pinned);
      });

  Future<void> toggleChatArchive(String conversationId) =>
      _updateChatSettings(conversationId, (settings) {
        return settings.copyWith(archived: !settings.archived);
      });

  Future<void> deleteConversationForMe(String conversationId) async {
    _conversations.remove(conversationId);
    _unreadCounts.remove(conversationId);
    await LocalDataService.instance.saveConversations(_storedConversations);
    await LocalDataService.instance.saveUnreadCounts(_unreadCounts);
    notifyListeners();
  }

  void Function(String)? onError;

  WebSocketChannel? _channel;
  bool _isConnected = false;
  Completer<UserProfile>? _authCompleter;
  Future<void> _incomingSignalQueue = Future<void>.value();
  bool _socketFailureReported = false;
  bool _pushSyncInFlight = false;
  DateTime? _lastPushSyncAt;

  Future<void> init() async {
    FirebasePushService.instance.onTokenRefresh = (token) {
      unawaited(registerPushToken(token));
    };
    final savedProfile = StorageService.instance.loadProfile();
    if (savedProfile == null) {
      return;
    }
    if (savedProfile.authToken == null || savedProfile.authToken!.isEmpty) {
      await StorageService.instance.clearProfile();
      return;
    }

    await _activateProfile(savedProfile);
    await connectWithProfile(savedProfile);
  }

  Future<UserProfile> login(String nickname, String password) async {
    final trimmed = nickname.trim();
    if (trimmed.isEmpty) {
      throw Exception('Nickname is required');
    }
    if (password.isEmpty) {
      throw Exception('Password is required');
    }

    _authCompleter = Completer<UserProfile>();
    final publicKey = await CryptoService.instance.publicKeyBase64();
    final device = await _devicePayload();
    _openSocket(
      onReady: () {
        _send({
          'type': 'auth',
          'nickname': trimmed,
          'password': password,
          'publicKey': publicKey,
          ...device,
        });
      },
    );

    await _authCompleter!.future;
    await RetentionService.instance.markSeen(RetentionMoment.userRegistered);
    sendRetentionEvent(RetentionMoment.userRegistered);
    await requestUsers();
    return profile!;
  }

  Future<UserProfile> register(String nickname, String password) async {
    final trimmed = nickname.trim();
    if (trimmed.length < 2) {
      throw Exception('Nickname must be at least 2 characters');
    }
    if (password.length < 6) {
      throw Exception('Password must be at least 6 characters');
    }

    _authCompleter = Completer<UserProfile>();
    final publicKey = await CryptoService.instance.publicKeyBase64();
    final device = await _devicePayload();
    _openSocket(
      onReady: () {
        _send({
          'type': 'register',
          'nickname': trimmed,
          'password': password,
          'publicKey': publicKey,
          ...device,
        });
      },
    );

    await _authCompleter!.future;
    await requestUsers();
    return profile!;
  }

  Future<void> connectWithProfile(UserProfile savedProfile) async {
    final authToken = savedProfile.authToken;
    if (authToken == null || authToken.isEmpty) {
      await StorageService.instance.clearProfile();
      profile = null;
      notifyListeners();
      return;
    }

    _authCompleter = Completer<UserProfile>();
    final publicKey = await CryptoService.instance.publicKeyBase64();
    final device = await _devicePayload();
    _openSocket(
      onReady: () {
        _send({
          'type': 'auth',
          'userId': savedProfile.userId,
          'nickname': savedProfile.nickname,
          'authToken': authToken,
          'publicKey': publicKey,
          ...device,
        });
      },
    );

    try {
      await _authCompleter!.future;
      await requestUsers();
    } catch (error) {
      await StorageService.instance.clearProfile();
      profile = null;
      notifyListeners();
      _recordError(error.toString());
      onError?.call(error.toString());
    }
  }

  Future<void> reconnect() async {
    final current = profile ?? StorageService.instance.loadProfile();
    if (current == null) {
      return;
    }
    await connectWithProfile(current);
  }

  Future<void> loadBackendConfig() async {
    try {
      final response = await http
          .get(Uri.parse(AppConfig.configUrl))
          .timeout(const Duration(seconds: 4));
      if (response.statusCode != 200) {
        return;
      }
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final iceServers = json['iceServers'];
      if (iceServers is List) {
        final hasTurn = iceServers.whereType<Map>().any((item) {
          final urls = item['urls'];
          if (urls is String) {
            final lower = urls.toLowerCase();
            return lower.startsWith('turn:') || lower.startsWith('turns:');
          }
          if (urls is List) {
            return urls.whereType<String>().any((url) {
              final lower = url.toLowerCase();
              return lower.startsWith('turn:') || lower.startsWith('turns:');
            });
          }
          return false;
        });
        DiagnosticService.instance.log(
          'backend config iceServers=${iceServers.length} hasTurn=$hasTurn',
        );
        CallService.instance.setIceServers(
          iceServers
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList(),
        );
      }
      final callMedia = json['callMedia'];
      if (callMedia is Map) {
        CallService.instance.setMediaConfig(
          Map<String, dynamic>.from(callMedia),
        );
      }
    } catch (error) {
      DiagnosticService.instance.log(
        'backend config unavailable; using default STUN fallback',
      );
      if (kDebugMode) {
        debugPrint('[ChatService] Backend config unavailable: $error');
      }
    }
  }

  Future<void> requestUsers() async {
    if (profile == null) {
      return;
    }
    _send({'type': 'get_contacts'});
    _send({'type': 'get_contact_requests'});
  }

  Future<void> requestSessions() async {
    if (profile == null) {
      return;
    }
    _send({'type': 'get_sessions'});
  }

  void sendRetentionEvent(RetentionMoment moment) {
    if (profile == null) {
      return;
    }
    final event = switch (moment) {
      RetentionMoment.userRegistered => 'user_registered',
      RetentionMoment.firstContactAdded => 'first_contact_added',
      RetentionMoment.firstMessageSent => 'first_message_sent',
      RetentionMoment.firstMessageReceived => 'first_message_received',
      RetentionMoment.firstCallStarted => 'call_started',
      RetentionMoment.callReceived => 'call_received',
      RetentionMoment.replyReceived => 'reply_received',
    };
    _send({'type': 'retention_event', 'event': event});
  }

  Future<void> syncAfterPush(PushAction action) async {
    final current = profile ?? StorageService.instance.loadProfile();
    if (current == null || _pushSyncInFlight) {
      return;
    }
    final now = DateTime.now();
    final previous = _lastPushSyncAt;
    if (previous != null && now.difference(previous).inSeconds < 3) {
      return;
    }
    _pushSyncInFlight = true;
    _lastPushSyncAt = now;
    try {
      if (action.type == PushActionType.contactRequest && _isConnected) {
        requestUsers();
      } else if (action.type == PushActionType.incomingCall && _isConnected) {
        _send({'type': 'get_call_offer', 'callId': action.requestId});
      } else {
        await reconnect();
        if (action.type == PushActionType.incomingCall) {
          _send({'type': 'get_call_offer', 'callId': action.requestId});
        }
      }
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[ChatService] Push sync failed: $error');
      }
    } finally {
      _pushSyncInFlight = false;
    }
  }

  Future<void> registerPushToken(String token) async {
    final registration = await FirebasePushService.instance.updateToken(token);
    if (registration == null || profile == null) {
      return;
    }
    if (kDebugMode) {
      debugPrint('[ChatService] Registering push token with backend.');
    }
    _send({'type': 'register_push_token', ...registration.toJson()});
  }

  Future<void> refreshPushRegistration() async {
    final registration =
        await FirebasePushService.instance.currentRegistration();
    if (registration == null || profile == null) {
      return;
    }
    if (kDebugMode) {
      debugPrint('[ChatService] Updating push token with backend.');
    }
    _send({'type': 'update_push_token', ...registration.toJson()});
  }

  Future<void> removePushToken() async {
    final registration = await FirebasePushService.instance.removeToken();
    if (registration == null || profile == null) {
      return;
    }
    _send({
      'type': 'remove_push_token',
      'deviceId': registration.deviceId,
      'pushProvider': registration.pushProvider.name,
      'appVersion': registration.appVersion,
    });
  }

  Future<void> rejectPushCall(PushAction action) async {
    final callId = action.requestId;
    final fromUserId = action.fromUserId;
    if (callId == null ||
        callId.isEmpty ||
        fromUserId == null ||
        fromUserId.isEmpty) {
      return;
    }
    try {
      if (!_isConnected) {
        await reconnect();
      }
      _send({
        'type': 'call_rejected',
        'callId': callId,
        'toUserId': fromUserId,
      });
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[ChatService] Push call reject failed: $error');
      }
    }
  }

  Future<void> revokeSession(String sessionId) async {
    _send({'type': 'revoke_session', 'sessionId': sessionId});
  }

  Future<void> logoutCurrentSession() async {
    _send({'type': 'logout'});
    await StorageService.instance.clearProfile();
    profile = null;
    disconnect();
    notifyListeners();
  }

  Future<void> searchUsername(String username) async {
    final query = username.trim();
    _lastSearchResult = null;
    _lastUsernameSearchRequest = query.isEmpty
        ? 'empty'
        : 'length=${query.length} hash=${query.hashCode & 0x7fffffff}';
    _lastUsernameSearchResult = 'pending';
    DiagnosticService.instance.log(
      'username search request $_lastUsernameSearchRequest',
    );
    notifyListeners();
    _send({'type': 'find_user_by_username_exact', 'username': query});
  }

  Future<void> sendContactRequest(String peerUserId) async {
    if (_isBlocked(peerUserId)) {
      throw Exception('User is unavailable.');
    }
    _send({'type': 'send_contact_request', 'toUserId': peerUserId});
    if (_lastSearchResult?.userId == peerUserId) {
      _lastSearchResult = null;
      notifyListeners();
    }
  }

  Future<void> acceptContactRequest(String requestId) async {
    _send({'type': 'accept_contact_request', 'id': requestId});
  }

  Future<void> declineContactRequest(String requestId) async {
    _send({'type': 'decline_contact_request', 'id': requestId});
  }

  Future<void> blockUser(String peerUserId) async {
    final current = profile;
    if (current == null) return;
    if (!_isBlocked(peerUserId)) {
      _blockList.add(BlockListEntry(
        id: _nextId(),
        userId: current.userId,
        blockedUserId: peerUserId,
        createdAt: DateTime.now(),
      ));
    }
    final index = _contacts.indexWhere((item) => item.peerUserId == peerUserId);
    if (index != -1) {
      _contacts[index] =
          _contacts[index].copyWith(status: ContactStatus.blocked);
      await LocalDataService.instance.saveContacts(_contacts);
    }
    await LocalDataService.instance.saveBlockList(_blockList);
    _send({'type': 'block_user', 'userId': peerUserId});
    notifyListeners();
  }

  Future<void> unblockUser(String peerUserId) async {
    _blockList.removeWhere((item) => item.blockedUserId == peerUserId);
    final index = _contacts.indexWhere((item) => item.peerUserId == peerUserId);
    if (index != -1) {
      _contacts[index] =
          _contacts[index].copyWith(status: ContactStatus.active);
      await LocalDataService.instance.saveContacts(_contacts);
    }
    await LocalDataService.instance.saveBlockList(_blockList);
    _send({'type': 'unblock_user', 'userId': peerUserId});
    notifyListeners();
  }

  Future<void> updatePrivacySettings(PrivacySettings settings) async {
    _privacySettings = settings;
    await LocalDataService.instance.savePrivacySettings(settings);
    _send({
      'type': 'update_privacy_settings',
      'allowUserDiscovery': settings.allowUserDiscovery,
    });
    notifyListeners();
  }

  void ensureCanMessage(String peerUserId) {
    if (_isBlocked(peerUserId) || !_isActiveContact(peerUserId)) {
      throw Exception('User is unavailable.');
    }
  }

  void ensureCanCall(String peerUserId) {
    ensureCanMessage(peerUserId);
    final peerName = peerNameFor(peerUserId);
    final keyInfo = peerKeyInfo(peerUserId, peerName);
    if (keyInfo.state == PeerKeyTrustState.changed) {
      throw Exception(
        '$peerName encryption key changed. Verify the fingerprint before calling.',
      );
    }
  }

  bool isBlockedByMe(String peerUserId) => _isBlocked(peerUserId);
  bool isActiveContact(String peerUserId) => _isActiveContact(peerUserId);

  Future<void> sendText({
    required String peerUserId,
    required String peerNickname,
    required String text,
    ChatMessage? replyTo,
    ChatMessage? forwardedFrom,
  }) async {
    final profile = this.profile;
    final trimmed = text.trim();
    if (profile == null || trimmed.isEmpty) {
      return;
    }
    ensureCanMessage(peerUserId);
    await _ensureLocalStorageReady(profile);

    final messageId = _nextId();
    final conversationId = makeConversationId(profile.userId, peerUserId);
    final peerPublicKey = _requiredPeerPublicKey(peerUserId, peerNickname);
    final metadata = _messageMetadata(
      replyTo: replyTo,
      forwardedFrom: forwardedFrom,
    );
    final encryptedText = await CryptoService.instance.encryptText(
      plaintext: _encodeTextPayload(trimmed, metadata),
      recipientPublicKeyBase64: peerPublicKey,
    );

    final message = ChatMessage(
      id: messageId,
      conversationId: conversationId,
      peerUserId: peerUserId,
      fromUserId: profile.userId,
      fromNickname: profile.nickname,
      text: trimmed,
      timestamp: DateTime.now(),
      isMe: true,
      status: MessageDeliveryStatus.sending,
      replyToMessageId: _metadataString(metadata, 'replyToMessageId'),
      replyToSenderId: _metadataString(metadata, 'replyToSenderId'),
      replyToSenderName: _metadataString(metadata, 'replyToSenderName'),
      replyPreviewText: _metadataString(metadata, 'replyPreviewText'),
      replyPreviewType: _metadataReplyPreviewType(metadata),
      isForwarded: metadata['isForwarded'] as bool? ?? false,
      forwardedFromSenderId: _metadataString(metadata, 'forwardedFromSenderId'),
      forwardedFromSenderName:
          _metadataString(metadata, 'forwardedFromSenderName'),
      forwardedFromMessageId:
          _metadataString(metadata, 'forwardedFromMessageId'),
    );

    await _persistMessage(message, peerNickname: peerNickname);
    _send({
      'type': 'message',
      'id': message.id,
      'toUserId': peerUserId,
      'recipientPublicKey': peerPublicKey,
      'text': encryptedText,
    });
    _scheduleSendTimeout(message.id);
  }

  Future<void> sendPickedFile({
    required String peerUserId,
    required String peerNickname,
    ChatMessage? replyTo,
  }) async {
    final profile = this.profile;
    if (profile == null) {
      return;
    }
    ensureCanMessage(peerUserId);
    await _ensureLocalStorageReady(profile);
    final peerPublicKey = _requiredPeerPublicKey(peerUserId, peerNickname);

    final result = await FilePicker.pickFiles(
      withData: true,
      allowMultiple: false,
      type: FileType.custom,
      allowedExtensions: AttachmentPolicy.allowedExtensions.toList(),
    );

    if (result == null || result.files.isEmpty) {
      return;
    }

    final file = result.files.single;
    final validation = AttachmentPolicy.validatePlatformFile(file);
    if (!validation.isValid) {
      throw Exception(
        '${validation.error ?? 'Attachment validation failed.'} ${AttachmentPolicy.describeLimits()}',
      );
    }

    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) {
      throw Exception('Could not read the selected file');
    }
    if (bytes.length != validation.sizeBytes) {
      throw Exception('Attachment validation failed.');
    }

    final metadata = _messageMetadata(replyTo: replyTo);
    await _sendFileBytes(
      peerUserId: peerUserId,
      peerNickname: peerNickname,
      fileName: file.name,
      bytes: bytes,
      validation: validation,
      peerPublicKey: peerPublicKey,
      metadata: metadata,
    );
  }

  Future<void> forwardMessage({
    required ChatMessage source,
    required String peerUserId,
    required String peerNickname,
  }) async {
    ensureCanMessage(peerUserId);
    if (source.attachment == null) {
      await sendText(
        peerUserId: peerUserId,
        peerNickname: peerNickname,
        text: source.text,
        forwardedFrom: source,
      );
      return;
    }

    final profile = this.profile;
    if (profile == null) return;
    await _ensureLocalStorageReady(profile);
    final bytes =
        await LocalDataService.instance.readAttachmentBytes(source.attachment!);
    if (bytes == null || bytes.isEmpty) {
      throw Exception('Forward failed: local file is unavailable.');
    }
    final extension =
        AttachmentPolicy.extensionForName(source.attachment!.name);
    final validation = AttachmentPolicy.validateFileMetadata(
      name: source.attachment!.name,
      extension: extension,
      sizeBytes: bytes.length,
    );
    if (!validation.isValid) {
      throw Exception(validation.error ?? 'Attachment validation failed.');
    }
    final peerPublicKey = _requiredPeerPublicKey(peerUserId, peerNickname);
    await _sendFileBytes(
      peerUserId: peerUserId,
      peerNickname: peerNickname,
      fileName: source.attachment!.name,
      bytes: bytes,
      validation: validation,
      peerPublicKey: peerPublicKey,
      metadata: _messageMetadata(forwardedFrom: source),
    );
  }

  Future<void> _sendFileBytes({
    required String peerUserId,
    required String peerNickname,
    required String fileName,
    required Uint8List bytes,
    required AttachmentValidationResult validation,
    required String peerPublicKey,
    required Map<String, dynamic> metadata,
  }) async {
    final profile = this.profile;
    if (profile == null) return;

    final messageId = _nextId();
    final attachmentKind = validation.kind;
    final encryptedAttachment = await CryptoService.instance.encryptAttachment(
      fileName: fileName,
      kind: attachmentKind,
      sizeBytes: validation.sizeBytes,
      bytes: bytes,
      recipientPublicKeyBase64: peerPublicKey,
      messageMetadata: metadata,
    );
    final blobId = await _uploadEncryptedAttachmentBlob(
      messageId: messageId,
      peerUserId: peerUserId,
      fileName: fileName,
      validation: validation,
      encryptedAttachment: encryptedAttachment,
    );
    final savedAttachment =
        await LocalDataService.instance.saveBytesAsAttachment(
      messageId: messageId,
      fileName: fileName,
      bytes: bytes,
    );

    final conversationId = makeConversationId(profile.userId, peerUserId);
    final message = ChatMessage(
      id: messageId,
      conversationId: conversationId,
      peerUserId: peerUserId,
      fromUserId: profile.userId,
      fromNickname: profile.nickname,
      text: '',
      timestamp: DateTime.now(),
      isMe: true,
      attachment: savedAttachment.attachment,
      status: MessageDeliveryStatus.sending,
      replyToMessageId: _metadataString(metadata, 'replyToMessageId'),
      replyToSenderId: _metadataString(metadata, 'replyToSenderId'),
      replyToSenderName: _metadataString(metadata, 'replyToSenderName'),
      replyPreviewText: _metadataString(metadata, 'replyPreviewText'),
      replyPreviewType: _metadataReplyPreviewType(metadata),
      isForwarded: metadata['isForwarded'] as bool? ?? false,
      forwardedFromSenderId: _metadataString(metadata, 'forwardedFromSenderId'),
      forwardedFromSenderName:
          _metadataString(metadata, 'forwardedFromSenderName'),
      forwardedFromMessageId:
          _metadataString(metadata, 'forwardedFromMessageId'),
    );

    await _persistMessage(message, peerNickname: peerNickname);
    _send({
      'type': 'message',
      'id': message.id,
      'toUserId': peerUserId,
      'recipientPublicKey': peerPublicKey,
      'text': '',
      'attachment': {
        'name': 'encrypted.hestia',
        'originalName': fileName,
        'extension': validation.extension,
        'kind': 'document',
        'originalKind': attachmentKind,
        'sizeBytes': encryptedAttachment.length,
        'originalSizeBytes': validation.sizeBytes,
        'encodedSizeBytes': encryptedAttachment.length,
        'blobId': blobId,
        'encrypted': true,
      },
    });
    _scheduleSendTimeout(message.id);
  }

  Future<String> _uploadEncryptedAttachmentBlob({
    required String messageId,
    required String peerUserId,
    required String fileName,
    required AttachmentValidationResult validation,
    required String encryptedAttachment,
  }) async {
    final profile = this.profile;
    final authToken = profile?.authToken;
    if (profile == null || authToken == null || authToken.isEmpty) {
      throw Exception('Authentication required.');
    }

    final uri = Uri.parse(AppConfig.uploadBlobUrl).replace(
      queryParameters: {
        'toUserId': peerUserId,
        'messageId': messageId,
        'originalName': fileName,
        'extension': validation.extension,
        'originalKind': validation.kind,
        'originalSizeBytes': validation.sizeBytes.toString(),
        'sizeBytes': validation.sizeBytes.toString(),
      },
    );
    final request = http.Request('POST', uri)
      ..headers.addAll(_blobAuthHeaders())
      ..headers['Content-Type'] = 'text/plain; charset=utf-8'
      ..body = encryptedAttachment;

    final response = await http.Response.fromStream(await request.send())
        .timeout(const Duration(minutes: 10));
    if (response.statusCode != 200) {
      final message = _serverErrorMessage(response.body) ??
          'Attachment upload failed (${response.statusCode}).';
      throw Exception(message);
    }
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final blobId = json['blobId'] as String? ?? '';
    if (blobId.isEmpty) {
      throw Exception('Attachment upload failed.');
    }
    return blobId;
  }

  Future<String> exportAttachment(ChatAttachment attachment) {
    return LocalDataService.instance.exportAttachment(attachment);
  }

  Future<String?> exportEncryptedBackup(String passphrase) {
    return BackupService.instance.exportEncryptedBackup(passphrase);
  }

  Future<void> importEncryptedBackup(String passphrase) async {
    final restoredProfile =
        await BackupService.instance.importEncryptedBackup(passphrase);
    await _activateProfile(restoredProfile);
    await connectWithProfile(restoredProfile);
  }

  PeerKeyInfo peerKeyInfo(String peerUserId, String peerNickname) {
    final publicKey = _publicKeyForPeer(peerUserId);
    if (publicKey == null || publicKey.isEmpty) {
      return PeerKeyInfo(
        userId: peerUserId,
        nickname: peerNickname,
        publicKey: null,
        fingerprint: null,
        state: PeerKeyTrustState.missing,
      );
    }

    final trustedKey =
        StorageService.instance.loadTrustedPeerPublicKey(peerUserId);
    final state = trustedKey == null
        ? PeerKeyTrustState.untrusted
        : trustedKey == publicKey
            ? PeerKeyTrustState.verified
            : PeerKeyTrustState.changed;

    return PeerKeyInfo(
      userId: peerUserId,
      nickname: peerNickname,
      publicKey: publicKey,
      fingerprint: CryptoService.instance.fingerprintForPublicKey(publicKey),
      state: state,
    );
  }

  Future<void> trustPeerKey(String peerUserId, String peerNickname) async {
    final info = peerKeyInfo(peerUserId, peerNickname);
    final publicKey = info.publicKey;
    if (publicKey == null || publicKey.isEmpty) {
      throw Exception('$peerNickname has no encryption key yet.');
    }

    await StorageService.instance.saveTrustedPeerPublicKey(
      peerUserId: peerUserId,
      publicKey: publicKey,
    );
    notifyListeners();
  }

  Future<void> removePeerKeyTrust(String peerUserId) async {
    await StorageService.instance.removeTrustedPeerPublicKey(peerUserId);
    notifyListeners();
  }

  void disconnect() {
    _setConnected(false);
    _channel?.sink.close();
    _channel = null;
    _socketFailureReported = false;
  }

  void _openSocket({required void Function() onReady}) {
    disconnect();

    try {
      _channel = WebSocketChannel.connect(Uri.parse(AppConfig.wsUrl));
    } catch (error) {
      _handleSocketError(error);
      return;
    }

    final channel = _channel!;
    unawaited(
      channel.ready.timeout(const Duration(seconds: 6)).catchError((error) {
        if (AppConfig.switchToFallbackServer()) {
          if (kDebugMode) {
            debugPrint(
              '[ChatService] Official server unavailable, trying ${AppConfig.host}',
            );
          }
          _openSocket(onReady: onReady);
          return;
        }
        _handleSocketError(error);
      }),
    );

    _incomingSignalQueue = Future<void>.value();
    channel.stream.listen(
      (raw) {
        _incomingSignalQueue = _incomingSignalQueue
            .then((_) => _handleRaw(raw))
            .catchError(_handleQueuedSignalError);
      },
      onDone: () => _setConnected(false),
      onError: _handleSocketError,
    );

    _setConnected(true);
    loadBackendConfig();
    onReady();
  }

  void _handleSocketError(Object error) {
    _setConnected(false);
    if (_socketFailureReported) {
      return;
    }
    _socketFailureReported = true;
    final message = 'Could not connect to ${AppConfig.host}';
    _recordError(message);
    if (_authCompleter != null && !_authCompleter!.isCompleted) {
      _authCompleter!.completeError(message);
      _authCompleter = null;
    }
    onError?.call(message);
    if (kDebugMode) {
      debugPrint('[ChatService] WebSocket error: $error');
    }
  }

  void _handleQueuedSignalError(Object error, StackTrace stackTrace) {
    _recordError(error.toString());
    if (kDebugMode) {
      debugPrint('[ChatService] WebSocket message handling failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
    if (_authCompleter != null && !_authCompleter!.isCompleted) {
      _authCompleter!.completeError(error, stackTrace);
      _authCompleter = null;
    } else {
      onError?.call(error.toString());
    }
  }

  Future<void> _handleRaw(dynamic raw) async {
    Map<String, dynamic> json;
    try {
      json = jsonDecode(raw.toString()) as Map<String, dynamic>;
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[ChatService] Invalid JSON: $error');
      }
      return;
    }

    final type = json['type'] as String? ?? '';
    if (type.startsWith('call_')) {
      if (type == 'call_offer_init') {
        final fromUserId = json['fromUserId'] as String? ?? '';
        final senderPublicKey = json['senderPublicKey'] as String?;
        final keyInfo = peerKeyInfo(fromUserId, peerNameFor(fromUserId));
        final advertisedKey = senderPublicKey == null || senderPublicKey.isEmpty
            ? keyInfo.publicKey
            : senderPublicKey;
        if (_isBlocked(fromUserId) ||
            (_privacySettings.allowCallsFrom == PrivacyAllowFrom.contacts &&
                !_isActiveContact(fromUserId)) ||
            keyInfo.state == PeerKeyTrustState.changed ||
            (keyInfo.state == PeerKeyTrustState.verified &&
                advertisedKey != keyInfo.publicKey)) {
          DiagnosticService.instance.log(
            'call rejected locally reason=privacy_or_key from=${_shortId(fromUserId)}',
          );
          _send({
            'type': 'call_rejected',
            'callId': json['callId'],
            'toUserId': fromUserId,
          });
          return;
        }
        final firstCallReceived = await RetentionService.instance
            .markSeen(RetentionMoment.callReceived);
        if (firstCallReceived) {
          sendRetentionEvent(RetentionMoment.callReceived);
        }
      }
      await CallService.instance.handleSignal(json);
      return;
    }

    switch (type) {
      case 'auth_ok':
        final user = UserProfile(
          userId: json['userId'] as String,
          nickname: json['nickname'] as String,
          authToken: json['authToken'] as String?,
          publicKey: json['publicKey'] as String?,
        );
        await _activateProfile(user);
        if (_authCompleter != null && !_authCompleter!.isCompleted) {
          _authCompleter!.complete(user);
          _authCompleter = null;
        }
        break;
      case 'users':
        final users = (json['users'] as List<dynamic>? ?? [])
            .map((item) =>
                UserContact.fromJson(Map<String, dynamic>.from(item as Map)))
            .toList();
        _users
          ..clear()
          ..addAll(users);
        notifyListeners();
        break;
      case 'contacts':
        final contactJson = (json['contacts'] as List<dynamic>? ?? [])
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();
        final contacts = contactJson.map(_contactFromServer).toList();
        _contacts
          ..clear()
          ..addAll(contacts);
        _lastSearchResult = _lastSearchResult == null ||
                _contacts.any((item) =>
                    item.status == ContactStatus.active &&
                    item.peerUserId == _lastSearchResult!.userId)
            ? null
            : _lastSearchResult;
        _users
          ..clear()
          ..addAll(contactJson.map(_userFromContactJson));
        await RetentionService.instance.updateState(
          hasContacts: _contacts.any(
            (contact) => contact.status == ContactStatus.active,
          ),
        );
        await LocalDataService.instance.saveContacts(_contacts);
        notifyListeners();
        break;
      case 'contact_requests':
        final knownRequestIds =
            _contactRequests.map((request) => request.id).toSet();
        final requests = (json['requests'] as List<dynamic>? ?? [])
            .map((item) =>
                ContactRequest.fromJson(Map<String, dynamic>.from(item as Map)))
            .toList();
        for (final request in requests) {
          if (!knownRequestIds.contains(request.id) &&
              request.status == ContactRequestStatus.pending) {
            _unreadContactRequestIds.add(request.id);
          }
        }
        await LocalDataService.instance
            .saveUnreadContactRequestIds(_unreadContactRequestIds);
        _contactRequests
          ..clear()
          ..addAll(requests);
        _lastSearchResult = _lastSearchResult == null ||
                hasPendingRequestWith(_lastSearchResult!.userId)
            ? null
            : _lastSearchResult;
        await LocalDataService.instance.saveContactRequests(_contactRequests);
        notifyListeners();
        break;
      case 'contact_request':
        final request = ContactRequest.fromJson(
          Map<String, dynamic>.from(json['request'] as Map),
        );
        _contactRequests.removeWhere((item) => item.id == request.id);
        _contactRequests.add(request);
        if (request.status == ContactRequestStatus.pending) {
          _unreadContactRequestIds.add(request.id);
          await LocalDataService.instance
              .saveUnreadContactRequestIds(_unreadContactRequestIds);
        }
        await LocalDataService.instance.saveContactRequests(_contactRequests);
        notifyListeners();
        break;
      case 'sessions':
        final sessions = (json['sessions'] as List<dynamic>? ?? [])
            .map((item) =>
                SessionInfo.fromJson(Map<String, dynamic>.from(item as Map)))
            .toList()
          ..sort((a, b) {
            final left =
                a.lastActiveAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            final right =
                b.lastActiveAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            return right.compareTo(left);
          });
        _sessions
          ..clear()
          ..addAll(sessions);
        notifyListeners();
        break;
      case 'session_revoked':
        await StorageService.instance.clearProfile();
        profile = null;
        disconnect();
        _recordError('This session was revoked.');
        onError?.call('This session was revoked.');
        notifyListeners();
        break;
      case 'logout_ok':
        break;
      case 'push_token_updated':
        if (kDebugMode) {
          debugPrint('[ChatService] FCM token registered on backend.');
        }
        await requestSessions();
        break;
      case 'push_token_removed':
        if (kDebugMode) {
          debugPrint('[ChatService] FCM token removed on backend.');
        }
        await requestSessions();
        break;
      case 'user_search_result':
        final userJson = json['user'];
        _lastSearchResult = userJson is Map
            ? UserContact.fromJson(Map<String, dynamic>.from(userJson))
            : null;
        _lastUsernameSearchResult = _lastSearchResult == null
            ? 'not_found_or_hidden'
            : 'found userId=${_shortId(_lastSearchResult!.userId)} online=${_lastSearchResult!.online}';
        DiagnosticService.instance.log(
          'username search result $_lastUsernameSearchResult',
        );
        notifyListeners();
        break;
      case 'user_presence':
        final user = UserContact.fromJson(
          Map<String, dynamic>.from(json['user'] as Map),
        );
        if (!_isActiveContact(user.userId)) {
          break;
        }
        final index =
            _users.indexWhere((element) => element.userId == user.userId);
        if (index == -1) {
          _users.add(user);
        } else {
          _users[index] = user;
        }
        notifyListeners();
        break;
      case 'new_message':
        final messageJson = Map<String, dynamic>.from(json['message'] as Map);
        final stored = await _receiveMessage(messageJson);
        if (stored) {
          _send({'type': 'delivery_ack', 'id': messageJson['id']});
        }
        break;
      case 'message_sent':
        final messageJson = Map<String, dynamic>.from(json['message'] as Map);
        await _markMessageStatus(
          messageJson['id'] as String? ?? '',
          MessageDeliveryStatus.sent,
        );
        break;
      case 'delivery_ack':
        await _markMessageStatus(
          json['id'] as String? ?? '',
          MessageDeliveryStatus.delivered,
        );
        break;
      case 'error':
        final message = json['message'] as String? ?? 'Unknown server error';
        if (_authCompleter != null && !_authCompleter!.isCompleted) {
          _authCompleter!.completeError(message);
          _authCompleter = null;
        } else {
          _recordError(message);
          onError?.call(message);
        }
        break;
    }
  }

  Future<bool> _receiveMessage(Map<String, dynamic> json) async {
    final profile = this.profile;
    if (profile == null) {
      return false;
    }
    await _ensureLocalStorageReady(profile);

    final fromUserId = json['fromUserId'] as String;
    final fromNickname = json['fromNickname'] as String? ?? 'Unknown';
    if (_isBlocked(fromUserId) ||
        (_privacySettings.allowMessagesFrom == PrivacyAllowFrom.contacts &&
            !_isActiveContact(fromUserId))) {
      return false;
    }
    final messageId = json['id'] as String? ?? _nextId();
    final conversationId = makeConversationId(profile.userId, fromUserId);
    if (_hasMessage(conversationId, messageId)) {
      return true;
    }
    final encryptedText = json['text'] as String? ?? '';
    final text = await CryptoService.instance.decryptText(encryptedText);
    if (CryptoService.instance.isEncryptedTextPayload(encryptedText) &&
        CryptoService.instance.isDecryptFailureText(text)) {
      return false;
    }
    final decodedText = _decodeTextPayload(text);
    final attachmentJson = json['attachment'];
    ChatAttachment? attachment;
    Map<String, dynamic> metadata = decodedText.metadata;

    if (attachmentJson is Map) {
      final storedAttachment = await _storeIncomingAttachment(
        messageId: messageId,
        attachmentJson: Map<String, dynamic>.from(attachmentJson),
      );
      attachment = storedAttachment?.attachment;
      if (storedAttachment?.messageMetadata != null) {
        metadata = {
          ...metadata,
          ...storedAttachment!.messageMetadata,
        };
      }
      if (attachmentJson['encrypted'] == true && attachment == null) {
        return false;
      }
    }

    final message = ChatMessage(
      id: messageId,
      conversationId: conversationId,
      peerUserId: fromUserId,
      fromUserId: fromUserId,
      fromNickname: fromNickname,
      text: decodedText.text,
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        json['timestamp'] as int? ?? DateTime.now().millisecondsSinceEpoch,
      ),
      isMe: false,
      attachment: attachment,
      replyToMessageId: _metadataString(metadata, 'replyToMessageId'),
      replyToSenderId: _metadataString(metadata, 'replyToSenderId'),
      replyToSenderName: _metadataString(metadata, 'replyToSenderName'),
      replyPreviewText: _metadataString(metadata, 'replyPreviewText'),
      replyPreviewType: _metadataReplyPreviewType(metadata),
      isForwarded: metadata['isForwarded'] as bool? ?? false,
      forwardedFromSenderId: _metadataString(metadata, 'forwardedFromSenderId'),
      forwardedFromSenderName:
          _metadataString(metadata, 'forwardedFromSenderName'),
      forwardedFromMessageId:
          _metadataString(metadata, 'forwardedFromMessageId'),
    );

    await _persistMessage(message, peerNickname: fromNickname);
    final firstReceived = await RetentionService.instance
        .markSeen(RetentionMoment.firstMessageReceived);
    if (firstReceived) {
      sendRetentionEvent(RetentionMoment.firstMessageReceived);
    } else {
      await RetentionService.instance.updateState(hasReceivedMessage: true);
    }
    if (message.replyToSenderId == profile.userId) {
      final firstReply = await RetentionService.instance
          .markSeen(RetentionMoment.replyReceived);
      if (firstReply) {
        sendRetentionEvent(RetentionMoment.replyReceived);
      }
    }
    _unreadCounts[message.conversationId] =
        (_unreadCounts[message.conversationId] ?? 0) + 1;
    await LocalDataService.instance.saveUnreadCounts(_unreadCounts);
    notifyListeners();
    return true;
  }

  Future<_StoredIncomingAttachment?> _storeIncomingAttachment({
    required String messageId,
    required Map<String, dynamic> attachmentJson,
  }) async {
    final base64Value = await _attachmentPayloadBase64(attachmentJson);
    if (base64Value == null || base64Value.isEmpty) {
      return null;
    }

    if (attachmentJson['encrypted'] == true) {
      final decrypted =
          await CryptoService.instance.decryptAttachment(base64Value);
      if (decrypted == null) {
        return null;
      }

      final saved = await LocalDataService.instance.saveBytesAsAttachment(
        messageId: messageId,
        fileName: decrypted.name,
        bytes: decrypted.bytes,
      );
      return _StoredIncomingAttachment(
        attachment: saved.attachment,
        messageMetadata: decrypted.messageMetadata ?? const {},
      );
    }

    final name = attachmentJson['name'] as String? ?? 'attachment.bin';
    Uint8List bytes;
    try {
      bytes = base64Decode(base64Value);
    } catch (_) {
      return null;
    }

    final saved = await LocalDataService.instance.saveBytesAsAttachment(
      messageId: messageId,
      fileName: name,
      bytes: bytes,
    );
    return _StoredIncomingAttachment(
      attachment: saved.attachment,
      messageMetadata: const {},
    );
  }

  Future<String?> _attachmentPayloadBase64(
    Map<String, dynamic> attachmentJson,
  ) async {
    final inline = attachmentJson['base64'] as String?;
    if (inline != null && inline.isNotEmpty) {
      return inline;
    }
    final blobId = attachmentJson['blobId'] as String?;
    final profile = this.profile;
    final authToken = profile?.authToken;
    if (blobId == null ||
        blobId.isEmpty ||
        profile == null ||
        authToken == null ||
        authToken.isEmpty) {
      return null;
    }
    final response = await http
        .get(
          Uri.parse(AppConfig.downloadBlobUrl(blobId)),
          headers: _blobAuthHeaders(),
        )
        .timeout(const Duration(minutes: 10));
    if (response.statusCode != 200) {
      if (kDebugMode) {
        debugPrint(
          '[ChatService] Attachment download failed: ${response.statusCode}',
        );
      }
      return null;
    }
    return response.body;
  }

  Map<String, String> _blobAuthHeaders() {
    final current = profile;
    return {
      if (current != null) 'X-User-Id': current.userId,
      if (current?.authToken != null) 'X-Auth-Token': current!.authToken!,
    };
  }

  String? _serverErrorMessage(String body) {
    try {
      final json = jsonDecode(body) as Map<String, dynamic>;
      return json['error'] as String?;
    } catch (_) {
      return null;
    }
  }

  Future<void> _persistMessage(
    ChatMessage message, {
    required String peerNickname,
  }) async {
    final profile = this.profile;
    if (profile != null) {
      await _ensureLocalStorageReady(profile);
    }

    final existing = _conversations[message.conversationId];
    final nextConversation = (existing ??
            Conversation(
              id: message.conversationId,
              peerUserId: message.peerUserId,
              peerNickname: peerNickname,
              messages: const [],
            ))
        .copyWith(
          peerUserId: message.peerUserId,
          peerNickname: peerNickname,
        )
        .copyWithMessage(message);

    _conversations[message.conversationId] = nextConversation;
    await LocalDataService.instance.saveConversations(_storedConversations);
    notifyListeners();
  }

  bool _hasMessage(String conversationId, String messageId) {
    final conversation = _conversations[conversationId];
    if (conversation == null) {
      return false;
    }
    return conversation.messages.any((message) => message.id == messageId);
  }

  Future<void> _markMessageStatus(
    String messageId,
    MessageDeliveryStatus status,
  ) async {
    if (messageId.isEmpty) {
      return;
    }

    for (final entry in _conversations.entries) {
      final messages = entry.value.messages;
      final index = messages.indexWhere((message) => message.id == messageId);
      if (index == -1) {
        continue;
      }

      final current = messages[index];
      if (!current.isMe || current.status == status) {
        return;
      }
      final nextMessages = [...messages];
      nextMessages[index] = _copyMessageWithStatus(current, status);
      _conversations[entry.key] = entry.value.copyWith(messages: nextMessages);
      await LocalDataService.instance.saveConversations(_storedConversations);
      notifyListeners();
      return;
    }
  }

  void _scheduleSendTimeout(String messageId) {
    unawaited(Future<void>.delayed(const Duration(seconds: 30), () async {
      for (final conversation in _conversations.values) {
        for (final message in conversation.messages) {
          if (message.id != messageId) {
            continue;
          }
          if (message.status == MessageDeliveryStatus.sending) {
            await _markMessageStatus(messageId, MessageDeliveryStatus.failed);
          }
          return;
        }
      }
    }));
  }

  ChatMessage _copyMessageWithStatus(
    ChatMessage message,
    MessageDeliveryStatus status,
  ) =>
      ChatMessage(
        id: message.id,
        conversationId: message.conversationId,
        peerUserId: message.peerUserId,
        fromUserId: message.fromUserId,
        fromNickname: message.fromNickname,
        text: message.text,
        timestamp: message.timestamp,
        isMe: message.isMe,
        attachment: message.attachment,
        status: status,
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

  Map<String, dynamic> _messageMetadata({
    ChatMessage? replyTo,
    ChatMessage? forwardedFrom,
  }) {
    final metadata = <String, dynamic>{};
    if (replyTo != null) {
      metadata.addAll({
        'replyToMessageId': replyTo.id,
        'replyToSenderId': replyTo.fromUserId,
        'replyToSenderName': replyTo.fromNickname,
        'replyPreviewText': _messagePreview(replyTo),
        'replyPreviewType': _replyPreviewType(replyTo).name,
      });
    }
    if (forwardedFrom != null) {
      metadata.addAll({
        'isForwarded': true,
        'forwardedFromSenderId': forwardedFrom.fromUserId,
        'forwardedFromSenderName': forwardedFrom.fromNickname,
        'forwardedFromMessageId': forwardedFrom.id,
      });
    }
    return metadata;
  }

  String _encodeTextPayload(String text, Map<String, dynamic> metadata) {
    if (metadata.isEmpty) {
      return text;
    }

    return jsonEncode({
      'hestiaMessageV': 1,
      'text': text,
      'messageMetadata': metadata,
    });
  }

  _DecodedMessagePayload _decodeTextPayload(String value) {
    try {
      final decoded = jsonDecode(value);
      if (decoded is Map &&
          decoded['hestiaMessageV'] == 1 &&
          decoded['text'] is String) {
        return _DecodedMessagePayload(
          text: decoded['text'] as String,
          metadata: decoded['messageMetadata'] is Map
              ? Map<String, dynamic>.from(decoded['messageMetadata'] as Map)
              : const {},
        );
      }
    } catch (_) {
      // Older messages are plain decrypted text.
    }
    return _DecodedMessagePayload(text: value, metadata: const {});
  }

  String _messagePreview(ChatMessage message) {
    if (message.attachment != null) {
      return message.attachment!.name;
    }
    final trimmed = message.text.trim();
    if (trimmed.isEmpty) {
      return 'Attachment';
    }
    return trimmed.length > 120 ? '${trimmed.substring(0, 120)}...' : trimmed;
  }

  ReplyPreviewType _replyPreviewType(ChatMessage message) {
    final attachment = message.attachment;
    if (attachment == null) {
      return ReplyPreviewType.text;
    }
    if (attachment.isImage) {
      return ReplyPreviewType.image;
    }
    if (attachment.isVideo) {
      return ReplyPreviewType.video;
    }
    if (attachment.isAudio) {
      return ReplyPreviewType.audio;
    }
    return ReplyPreviewType.document;
  }

  String? _metadataString(Map<String, dynamic> metadata, String key) {
    final value = metadata[key];
    return value is String && value.isNotEmpty ? value : null;
  }

  ReplyPreviewType? _metadataReplyPreviewType(Map<String, dynamic> metadata) {
    final value = metadata['replyPreviewType'];
    if (value is! String) {
      return null;
    }
    return ReplyPreviewType.values.firstWhere(
      (item) => item.name == value,
      orElse: () => ReplyPreviewType.unknown,
    );
  }

  String? _publicKeyForPeer(String peerUserId) {
    for (final user in _users) {
      if (user.userId == peerUserId) {
        return user.publicKey;
      }
    }
    return null;
  }

  bool _isBlocked(String peerUserId) {
    return _blockList.any((item) => item.blockedUserId == peerUserId) ||
        _contacts.any((item) =>
            item.peerUserId == peerUserId &&
            item.status == ContactStatus.blocked);
  }

  bool _isActiveContact(String peerUserId) {
    return _contacts.any((item) =>
        item.peerUserId == peerUserId && item.status == ContactStatus.active);
  }

  Contact _contactFromServer(Map<String, dynamic> json) {
    final current = profile;
    return Contact(
      id: makeConversationId(
        json['userId'] as String? ?? current?.userId ?? '',
        json['peerUserId'] as String,
      ),
      userId: json['userId'] as String? ?? current?.userId ?? '',
      peerUserId: json['peerUserId'] as String,
      username: json['username'] as String? ?? 'Unknown',
      createdAt: DateTime.now(),
      status: ContactStatus.values.firstWhere(
        (item) => item.name == (json['status'] as String? ?? 'active'),
        orElse: () => ContactStatus.active,
      ),
    );
  }

  UserContact _userFromContactJson(Map<String, dynamic> json) {
    return UserContact(
      userId: json['peerUserId'] as String,
      nickname: json['username'] as String? ?? 'Unknown',
      online: json['online'] as bool? ?? false,
      publicKey: json['publicKey'] as String?,
    );
  }

  String _requiredPeerPublicKey(String peerUserId, String peerNickname) {
    final info = peerKeyInfo(peerUserId, peerNickname);
    final publicKey = info.publicKey;
    if (publicKey == null || publicKey.isEmpty) {
      throw Exception(
          'Cannot encrypt for $peerNickname: no encryption key yet.');
    }
    if (info.state == PeerKeyTrustState.changed) {
      throw Exception(
        '$peerNickname encryption key changed. Verify the fingerprint before sending.',
      );
    }
    return publicKey;
  }

  void _replaceConversations(List<Conversation> items) {
    _conversations
      ..clear()
      ..addEntries(
          items.map((conversation) => MapEntry(conversation.id, conversation)));
    notifyListeners();
  }

  Future<void> _activateProfile(UserProfile user) async {
    await StorageService.instance.saveProfile(user);
    await LocalDataService.instance.init(user.userId);
    final storedConversations =
        await LocalDataService.instance.loadConversations();
    final storedContacts = await LocalDataService.instance.loadContacts();
    final storedRequests =
        await LocalDataService.instance.loadContactRequests();
    final storedBlockList = await LocalDataService.instance.loadBlockList();
    final storedPrivacy = await LocalDataService.instance.loadPrivacySettings();
    final storedUnreadCounts =
        await LocalDataService.instance.loadUnreadCounts();
    final storedUnreadContactRequestIds =
        await LocalDataService.instance.loadUnreadContactRequestIds();
    final storedChatSettings =
        await LocalDataService.instance.loadChatSettings();

    profile = user;
    CallService.instance.sendSignal = (message) {
      message['fromUserId'] = user.userId;
      message['fromNickname'] = user.nickname;
      _send(message);
    };
    _contacts
      ..clear()
      ..addAll(storedContacts);
    _contactRequests
      ..clear()
      ..addAll(storedRequests);
    _blockList
      ..clear()
      ..addAll(storedBlockList);
    _unreadCounts
      ..clear()
      ..addAll(storedUnreadCounts);
    _unreadContactRequestIds
      ..clear()
      ..addAll(storedUnreadContactRequestIds);
    _chatSettings
      ..clear()
      ..addEntries(
        storedChatSettings.map(
          (settings) => MapEntry(settings.conversationId, settings),
        ),
      );
    _privacySettings = storedPrivacy;
    _replaceConversations(storedConversations);
    notifyListeners();
    unawaited(refreshPushRegistration());
  }

  Future<void> _ensureLocalStorageReady(UserProfile user) async {
    if (!LocalDataService.instance.isInitialized ||
        LocalDataService.instance.userId != user.userId) {
      await LocalDataService.instance.init(user.userId);
    }
  }

  void _setConnected(bool value) {
    _isConnected = value;
    DiagnosticService.instance.log(
      'websocket ${value ? 'connected' : 'disconnected'} ${AppConfig.wsUrl}',
    );
    notifyListeners();
  }

  void _send(Map<String, dynamic> obj) {
    final type = obj['type']?.toString() ?? 'unknown';
    if (type.startsWith('call_') || type == 'get_call_offer') {
      DiagnosticService.instance.log(
        'websocket sent $type callId=${_shortId(obj['callId']?.toString() ?? '')}',
      );
    }
    _channel?.sink.add(jsonEncode(obj));
  }

  Future<String> diagnosticReport() async {
    SessionInfo? currentSession;
    for (final session in _sessions) {
      if (session.current) {
        currentSession = session;
        break;
      }
    }
    final deviceId = await StorageService.instance.loadOrCreateDeviceId();
    final call = CallService.instance;
    final lines = <String>[
      'Hestia diagnostics',
      'generatedAt: ${DateTime.now().toIso8601String()}',
      'diagnosticMode: ${DiagnosticService.instance.enabled}',
      'serverInput: ${AppConfig.serverInput}',
      'serverUrl: ${AppConfig.wsUrl}',
      'httpUrl: ${AppConfig.httpUrl}',
      'websocket: ${_isConnected ? 'connected' : 'disconnected'}',
      'authenticatedUserId: ${_shortId(profile?.userId ?? '')}',
      'sessionId: ${_shortId(currentSession?.id ?? '')}',
      'deviceId: ${_shortId(currentSession?.deviceId ?? deviceId)}',
      'pushEnabled: ${currentSession?.pushEnabled ?? false}',
      'pushProvider: ${currentSession?.pushProvider ?? 'none'}',
      'contactsCount: ${contacts.length}',
      'pendingRequestsCount: ${pendingRequests.length}',
      'allowUserDiscovery: ${_privacySettings.allowUserDiscovery}',
      'allowMessagesFrom: ${_privacySettings.allowMessagesFrom.name}',
      'allowCallsFrom: ${_privacySettings.allowCallsFrom.name}',
      'lastUsernameSearchRequest: $_lastUsernameSearchRequest',
      'lastUsernameSearchResult: $_lastUsernameSearchResult',
      'lastCallEventSent: ${call.lastCallEventSent}',
      'lastCallEventReceived: ${call.lastCallEventReceived}',
      'callState: ${call.state.name}',
      'webrtcConnectionState: ${call.connectionState}',
      'iceConnectionState: ${call.iceConnectionState}',
      'localAudioTracks: ${call.localAudioTrackCount}',
      'localVideoTracks: ${call.localVideoTrackCount}',
      'remoteAudioTracks: ${call.remoteAudioTrackCount}',
      'remoteVideoTracks: ${call.remoteVideoTrackCount}',
      'chatLastError: $_lastError',
      'callLastError: ${call.lastError}',
      'logs:',
      ...DiagnosticService.instance.entries,
    ];
    return lines.join('\n');
  }

  void _recordError(String message) {
    _lastError = message;
    DiagnosticService.instance.log('error $message');
  }

  String _shortId(String value) {
    if (value.isEmpty) {
      return 'none';
    }
    return value.length <= 8 ? value : '${value.substring(0, 8)}...';
  }

  Future<Map<String, String>> _devicePayload() async {
    final package = await PackageInfo.fromPlatform();
    return {
      'deviceId': await StorageService.instance.loadOrCreateDeviceId(),
      'deviceName': StorageService.instance.deviceName,
      'platform': StorageService.instance.platformName,
      'appVersion': '${package.version}+${package.buildNumber}',
    };
  }

  Future<void> _updateChatSettings(
    String conversationId,
    ChatLocalSettings Function(ChatLocalSettings) update,
  ) async {
    _chatSettings[conversationId] = update(chatSettingsFor(conversationId));
    await LocalDataService.instance
        .saveChatSettings(_chatSettings.values.toList());
    notifyListeners();
  }

  String _nextId() => DateTime.now().microsecondsSinceEpoch.toRadixString(16);
}

class _DecodedMessagePayload {
  final String text;
  final Map<String, dynamic> metadata;

  const _DecodedMessagePayload({
    required this.text,
    required this.metadata,
  });
}

class _StoredIncomingAttachment {
  final ChatAttachment attachment;
  final Map<String, dynamic> messageMetadata;

  const _StoredIncomingAttachment({
    required this.attachment,
    required this.messageMetadata,
  });
}
