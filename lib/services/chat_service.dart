import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
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
import 'web_smoke_log.dart';

bool get _androidRuntime => !kIsWeb && Platform.isAndroid;
const int _androidTemporaryLargeAttachmentMaxBytes = 100 * 1024 * 1024;

void _webVoiceLog(String message) {
  if (kIsWeb) {
    debugPrint('[WebVoice] $message');
  }
}

void _webFileLog(String message) {
  if (kIsWeb) {
    debugPrint('[WebFile] $message');
  }
}

String _iceServerSchemeSummary(Iterable<Map<String, dynamic>> iceServers) {
  final schemes = <String>{};
  for (final server in iceServers) {
    final urls = server['urls'];
    final values =
        urls is List ? urls.whereType<String>() : [if (urls is String) urls];
    for (final url in values) {
      final separator = url.indexOf(':');
      if (separator > 0) {
        schemes.add(url.substring(0, separator).toLowerCase());
      }
    }
  }
  final ordered = ['stun', 'turn', 'turns']
      .where(schemes.contains)
      .followedBy(schemes.where((scheme) =>
          scheme != 'stun' && scheme != 'turn' && scheme != 'turns'))
      .toList();
  return ordered.isEmpty ? 'none' : ordered.join(',');
}

int _iceServerSchemeEntryCount(
  Iterable<Map<String, dynamic>> iceServers,
  bool Function(String scheme) matches,
) {
  var count = 0;
  for (final server in iceServers) {
    final urls = server['urls'];
    final values =
        urls is List ? urls.whereType<String>() : [if (urls is String) urls];
    final serverSchemes = <String>{};
    for (final url in values) {
      final separator = url.indexOf(':');
      if (separator > 0) {
        serverSchemes.add(url.substring(0, separator).toLowerCase());
      }
    }
    if (serverSchemes.any(matches)) {
      count += 1;
    }
  }
  return count;
}

enum ServerConnectionStatus {
  disconnected,
  connecting,
  connected,
  authError,
  serverError,
}

enum AttachmentTransferStage {
  preparing,
  encrypting,
  uploading,
  downloading,
  decrypting,
  saving,
  sent,
  received,
  failed,
}

class AttachmentTransferProgress {
  final AttachmentTransferStage stage;
  final int transferredBytes;
  final int? totalBytes;
  final String? error;

  const AttachmentTransferProgress({
    required this.stage,
    this.transferredBytes = 0,
    this.totalBytes,
    this.error,
  });

  double? get fraction {
    final total = totalBytes;
    if (total == null || total <= 0) return null;
    return (transferredBytes / total).clamp(0, 1).toDouble();
  }

  bool get isActive => switch (stage) {
        AttachmentTransferStage.preparing ||
        AttachmentTransferStage.encrypting ||
        AttachmentTransferStage.uploading ||
        AttachmentTransferStage.downloading ||
        AttachmentTransferStage.decrypting ||
        AttachmentTransferStage.saving =>
          true,
        AttachmentTransferStage.sent ||
        AttachmentTransferStage.received ||
        AttachmentTransferStage.failed =>
          false,
      };
}

class ChatService extends ChangeNotifier {
  ChatService._() {
    CallService.instance.refreshBackendIceConfig = loadBackendConfig;
  }
  static final ChatService instance = ChatService._();

  UserProfile? profile;
  bool get isConnected => _isConnected;
  ServerConnectionStatus get connectionStatus => _connectionStatus;

  final Map<String, Conversation> _conversations = {};
  final List<UserContact> _users = [];
  final List<Contact> _contacts = [];
  final List<ContactRequest> _contactRequests = [];
  final List<BlockListEntry> _blockList = [];
  final List<SessionInfo> _sessions = [];
  final Map<String, ChatLocalSettings> _chatSettings = {};
  final Map<String, int> _unreadCounts = {};
  final Map<String, AttachmentTransferProgress> _attachmentProgress = {};
  final _incomingAttachmentQueue = _AsyncSemaphore(_androidRuntime ? 1 : 2);
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
      final left = a.lastMessage?.primarySortMillis ?? 0;
      final right = b.lastMessage?.primarySortMillis ?? 0;
      final primary = right.compareTo(left);
      if (primary != 0) return primary;
      return a.id.compareTo(b.id);
    });
    return list;
  }

  List<Conversation> get _storedConversations => _conversations.values.toList()
    ..sort((a, b) {
      final left = a.lastMessage?.primarySortMillis ?? 0;
      final right = b.lastMessage?.primarySortMillis ?? 0;
      final primary = right.compareTo(left);
      if (primary != 0) return primary;
      return a.id.compareTo(b.id);
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

  List<Contact> get blockedContacts => _contacts
      .where((contact) =>
          contact.status == ContactStatus.blocked ||
          _blockList.any((item) => item.blockedUserId == contact.peerUserId))
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

  List<ChatMessage> messagesFor(String conversationId) {
    final messages = [...?_conversations[conversationId]?.messages];
    messages.sort(ChatMessage.compareForDisplay);
    return messages;
  }

  AttachmentTransferProgress? attachmentProgressFor(String messageId) =>
      _attachmentProgress[messageId];

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
  Timer? _reconnectTimer;
  bool _reconnectInFlight = false;
  bool _intentionalDisconnect = false;
  bool _isConnected = false;
  ServerConnectionStatus _connectionStatus =
      ServerConnectionStatus.disconnected;
  Completer<UserProfile>? _authCompleter;
  Future<void> _incomingSignalQueue = Future<void>.value();
  bool _socketFailureReported = false;
  bool _pushSyncInFlight = false;
  DateTime? _lastPushSyncAt;
  DateTime? _lastBackgroundWsEventAt;
  String _lastBackgroundWsEventType = 'none';
  String _foregroundServiceSocketState = 'not_started';
  DateTime? _foregroundServiceStartedAt;
  DateTime? _foregroundServiceConnectingAt;
  DateTime? _foregroundServiceConnectedAt;
  DateTime? _foregroundServiceAuthSentAt;
  DateTime? _foregroundServiceAuthOkAt;
  String _foregroundServiceActiveUserId = 'none';
  String _foregroundServiceActiveDeviceId = 'none';
  String _foregroundServiceLastIncomingFrameType = 'none';
  DateTime? _foregroundServiceLastIncomingFrameAt;
  String _foregroundServiceLastNotificationType = 'none';
  DateTime? _foregroundServiceLastNotificationAt;
  DateTime? _foregroundServiceLastSocketClosedAt;
  String _foregroundServiceLastSocketError = 'none';
  DateTime? _foregroundServiceLastReconnectAt;

  Future<void> init() async {
    if (AppConfig.enablePushNotifications) {
      FirebasePushService.instance.onTokenRefresh = (token) {
        unawaited(registerPushToken(token));
      };
    }
    UserProfile? savedProfile;
    try {
      savedProfile = StorageService.instance.loadProfile();
    } catch (error) {
      DiagnosticService.instance.log('startup loadProfile failed error=$error');
      return;
    }
    if (savedProfile == null) {
      return;
    }
    if (kIsWeb && !StorageService.instance.secureValuesLoaded) {
      WebSmokeLog.log('runtime blocker reason=storage_credentials_unavailable');
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
    await loadBackendConfig();
    _openSocket(
      onReady: () {
        _logConnection('auth sent nicknameLength=${trimmed.length}');
        _send({
          'type': 'auth',
          'nickname': trimmed,
          'password': password,
          'publicKey': publicKey,
          ...device,
          'socketRole': 'main_app',
        });
        _recordForegroundServiceAuthSent(device['deviceId'] ?? 'none');
      },
    );

    await _authCompleter!.future.timeout(const Duration(seconds: 12));
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
    await loadBackendConfig();
    _openSocket(
      onReady: () {
        _logConnection('register sent nicknameLength=${trimmed.length}');
        _send({
          'type': 'register',
          'nickname': trimmed,
          'password': password,
          'publicKey': publicKey,
          ...device,
          'socketRole': 'main_app',
        });
        _recordForegroundServiceAuthSent(device['deviceId'] ?? 'none');
      },
    );

    await _authCompleter!.future.timeout(const Duration(seconds: 12));
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
    await loadBackendConfig();
    _openSocket(
      onReady: () {
        _logConnection('auth sent userId=${_shortId(savedProfile.userId)}');
        _send({
          'type': 'auth',
          'userId': savedProfile.userId,
          'nickname': savedProfile.nickname,
          'authToken': authToken,
          'publicKey': publicKey,
          ...device,
          'socketRole': 'main_app',
        });
        _recordForegroundServiceAuthSent(device['deviceId'] ?? 'none');
      },
    );

    try {
      await _authCompleter!.future.timeout(const Duration(seconds: 12));
      await requestUsers();
    } catch (error) {
      if (_connectionStatus == ServerConnectionStatus.authError) {
        await StorageService.instance.clearProfile();
        profile = null;
      } else {
        _scheduleReconnect('auth_retry');
      }
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
    _logConnection('reconnect attempt userId=${_shortId(current.userId)}');
    var scheduleRetry = false;
    try {
      _reconnectInFlight = true;
      await connectWithProfile(current);
      if (!_isConnected) {
        throw Exception('Reconnect did not establish a websocket session.');
      }
      _logConnection('reconnect success userId=${_shortId(current.userId)}');
    } catch (error) {
      _logConnection('reconnect fail error=$error');
      scheduleRetry = true;
      rethrow;
    } finally {
      _reconnectInFlight = false;
      if (scheduleRetry) {
        _scheduleReconnect('reconnect_failed');
      }
    }
  }

  Future<void> loadBackendConfig() async {
    try {
      Map<String, dynamic>? config;
      for (final configUrl in AppConfig.configUrls) {
        late final http.Response candidate;
        try {
          candidate = await http
              .get(Uri.parse(configUrl))
              .timeout(const Duration(seconds: 4));
        } catch (error) {
          DiagnosticService.instance.log(
            'backend config endpoint unavailable url=${_redactQuery(configUrl)} error=$error',
          );
          continue;
        }
        if (candidate.statusCode == 200) {
          try {
            final decoded = jsonDecode(candidate.body);
            if (decoded is Map<String, dynamic>) {
              config = decoded;
              break;
            }
            if (decoded is Map) {
              config = Map<String, dynamic>.from(decoded);
              break;
            }
            DiagnosticService.instance.log(
              'backend config ignored non-object response url=${_redactQuery(configUrl)}',
            );
          } catch (error) {
            DiagnosticService.instance.log(
              'backend config invalid json url=${_redactQuery(configUrl)} error=$error',
            );
          }
          continue;
        }
        DiagnosticService.instance.log(
          'backend config endpoint status=${candidate.statusCode} url=${_redactQuery(configUrl)}',
        );
        if (candidate.statusCode == 404 || candidate.statusCode == 405) {
          continue;
        }
      }
      if (config == null) {
        DiagnosticService.instance.log(
          AttachmentPolicy.diagnosticsSummary(source: 'fallback'),
        );
        _webVoiceLog('fallback reason=backend_config_unavailable');
        CallService.instance.setIceServers(
          const [],
          source: 'default',
          fallbackReason: 'backend_config_unavailable',
        );
        return;
      }
      final features = config['features'];
      var featureConfigChanged = false;
      if (features is Map) {
        featureConfigChanged = AppConfig.applyFeatureConfig(
          Map<String, dynamic>.from(features),
        );
        DiagnosticService.instance.log(
          'config loaded voiceCalls=${AppConfig.enableVoiceCalls} '
          'videoCalls=${AppConfig.enableVideoCalls}',
        );
      }
      final attachmentPolicy = config['attachmentPolicy'];
      if (attachmentPolicy is Map) {
        AttachmentPolicy.applyBackendPolicy(
          Map<String, dynamic>.from(attachmentPolicy),
        );
        DiagnosticService.instance.log(
          '${AttachmentPolicy.diagnosticsSummary(source: 'backend')} '
          'blockedExtensions=${AttachmentPolicy.blockedExtensions.length}',
        );
      } else {
        DiagnosticService.instance.log(
          AttachmentPolicy.diagnosticsSummary(source: 'fallback'),
        );
      }
      final websocketPath = config['websocketPath'];
      if (websocketPath is String && websocketPath.trim().isNotEmpty) {
        AppConfig.applyWebSocketPath(websocketPath);
        DiagnosticService.instance.log(
          'backend config websocketPath=$websocketPath wsUrl=${AppConfig.wsUrl}',
        );
      }
      final blobTransfer = config['blobTransfer'];
      if (blobTransfer is Map) {
        AppConfig.applyBlobTransferConfig(
          Map<String, dynamic>.from(blobTransfer),
        );
        DiagnosticService.instance.log(
          'backend config blobTransfer enabled=${AppConfig.blobTransferEnabled} '
          'upload=${_redactQuery(AppConfig.uploadBlobUrl)} '
          'download=${_redactQuery(AppConfig.downloadBlobUrl('{blobId}'))}',
        );
      }
      final iceServers = config['iceServers'];
      if ((AppConfig.enableVoiceCalls || AppConfig.enableVideoCalls) &&
          iceServers is List) {
        final iceServerMaps = iceServers
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
        final hasTurn = iceServerMaps.any((item) {
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
        final turnEntries = _iceServerSchemeEntryCount(
          iceServerMaps,
          (scheme) => scheme == 'turn' || scheme == 'turns',
        );
        final stunEntries = _iceServerSchemeEntryCount(
          iceServerMaps,
          (scheme) => scheme == 'stun',
        );
        _webVoiceLog(
          'backend ICE config loaded '
          'parsed ICE servers count=${iceServerMaps.length} '
          'TURN entries count=$turnEntries '
          'STUN entries count=$stunEntries '
          'schemes detected=${_iceServerSchemeSummary(iceServerMaps)} '
          'hasTurn=$hasTurn',
        );
        _webVoiceLog(
          'config source=backend '
          'parsed ICE servers count=${iceServerMaps.length} '
          'TURN entries count=$turnEntries '
          'STUN entries count=$stunEntries '
          'schemes detected=${_iceServerSchemeSummary(iceServerMaps)} '
          'hasTurn=$hasTurn',
        );
        CallService.instance.setIceServers(
          iceServerMaps,
          source: 'backend',
          fallbackReason: 'backend_ice_empty_or_invalid',
        );
      } else if (AppConfig.enableVoiceCalls || AppConfig.enableVideoCalls) {
        _webVoiceLog('fallback reason=backend_ice_missing');
        CallService.instance.setIceServers(
          const [],
          source: 'default',
          fallbackReason: 'backend_ice_missing',
        );
      }
      final callMedia = config['callMedia'];
      if ((AppConfig.enableVoiceCalls || AppConfig.enableVideoCalls) &&
          callMedia is Map) {
        CallService.instance.setMediaConfig(
          Map<String, dynamic>.from(callMedia),
        );
      }
      if (featureConfigChanged) {
        DiagnosticService.instance.log(
          'config features changed notifying UI videoCalls=${AppConfig.enableVideoCalls}',
        );
        notifyListeners();
      }
    } catch (error) {
      DiagnosticService.instance.log(
        'backend config unavailable; using default STUN fallback',
      );
      _webVoiceLog('fallback reason=backend_config_error');
      CallService.instance.setIceServers(
        const [],
        source: 'default',
        fallbackReason: 'backend_config_error',
      );
      DiagnosticService.instance.log(
        AttachmentPolicy.diagnosticsSummary(source: 'fallback'),
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
    if (!AppConfig.enablePushNotifications) {
      return;
    }
    final registration = await FirebasePushService.instance.updateToken(token);
    if (registration == null || profile == null) {
      DiagnosticService.instance
          .log('fcm token upload skipped reason=not_ready');
      final current = profile;
      if (current != null) {
        await _ensureWakeupAfterAuthAndRecord(current);
      } else {
        await FirebasePushService.instance.ensureWakeupAfterAuth();
      }
      return;
    }
    if (kDebugMode) {
      debugPrint('[ChatService] Registering push token with backend.');
    }
    DiagnosticService.instance.log('fcm token upload sent reason=refresh');
    _send({'type': 'register_push_token', ...registration.toJson()});
  }

  Future<void> refreshPushRegistration() async {
    if (!AppConfig.enablePushNotifications) {
      return;
    }
    final registration =
        await FirebasePushService.instance.currentRegistration();
    if (registration == null || profile == null) {
      DiagnosticService.instance
          .log('fcm token upload skipped reason=not_ready');
      final current = profile;
      if (current != null) {
        await _ensureWakeupAfterAuthAndRecord(current);
      } else {
        await FirebasePushService.instance.ensureWakeupAfterAuth();
      }
      return;
    }
    if (kDebugMode) {
      debugPrint('[ChatService] Updating push token with backend.');
    }
    DiagnosticService.instance.log('fcm token upload sent reason=auth_ok');
    _send({'type': 'update_push_token', ...registration.toJson()});
  }

  Future<void> removePushToken() async {
    if (!AppConfig.enablePushNotifications) {
      return;
    }
    final registration = await FirebasePushService.instance.removeToken();
    if (registration == null || profile == null) {
      DiagnosticService.instance
          .log('fcm token removal skipped reason=not_ready');
      await FirebasePushService.instance.stopForegroundFallback();
      return;
    }
    DiagnosticService.instance.log('fcm token removal sent');
    _send({
      'type': 'remove_push_token',
      'deviceId': registration.deviceId,
      'pushProvider': registration.pushProvider.name,
      'appVersion': registration.appVersion,
    });
  }

  void updateClientAppState(String state) {
    unawaited(FirebasePushService.instance.updateAndroidAppState(state));
    if (profile == null) {
      return;
    }
    if (state == 'resumed') {
      unawaited(_ensureWakeupAfterAuthAndRecord(profile!));
    }
    if (!_isConnected) {
      if (FirebasePushService.instance.foregroundServiceActive) {
        DiagnosticService.instance.log(
          'foreground service websocket disconnected on app_state=$state; reconnect scheduled',
        );
        _scheduleReconnect('foreground_service_app_state_$state');
      }
      return;
    }
    try {
      _send({
        'type': 'client_app_state',
        'state': state,
      });
      DiagnosticService.instance.log(
        'client app state sent state=$state foregroundService=${FirebasePushService.instance.foregroundServiceActive}',
      );
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[ChatService] App state update failed: $error');
      }
    }
  }

  bool get _shouldNotifyWhileBackgrounded {
    final lifecycle = CallService.instance.appLifecycleState;
    return lifecycle == 'inactive' ||
        lifecycle == 'paused' ||
        lifecycle == 'detached' ||
        lifecycle == 'hidden';
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
    if (_channel != null && _isConnected) {
      try {
        await removePushToken();
        _send({'type': 'logout'});
      } catch (error) {
        DiagnosticService.instance.log('logout send failed error=$error');
      }
    }
    await FirebasePushService.instance.stopForegroundFallback();
    await StorageService.instance.clearProfile();
    _clearRuntimeUserState();
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
    if (!_isConnected) {
      _lastUsernameSearchResult = 'not_sent_disconnected';
      const message = 'No server connection.';
      _recordError(message);
      DiagnosticService.instance.log('username search rejected disconnected');
      notifyListeners();
      throw Exception(message);
    }
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

  Future<void> recordMissedCall({
    required String callId,
    required String fromUserId,
    required String fromNickname,
    int? timestampMs,
    String reason = 'missed',
  }) async {
    await recordCallEvent(
      callId: callId,
      peerUserId: fromUserId,
      peerNickname: fromNickname,
      direction: CallDirection.incoming,
      status: CallStatus.missed,
      timestampMs: timestampMs,
      reason: reason,
    );
  }

  Future<void> recordCallEvent({
    required String callId,
    required String peerUserId,
    required String peerNickname,
    required CallDirection direction,
    required CallStatus status,
    int? timestampMs,
    int? durationSeconds,
    bool isVideo = false,
    String reason = 'call_event',
  }) async {
    final profile = this.profile;
    if (profile == null || callId.isEmpty || peerUserId.isEmpty) {
      DiagnosticService.instance.log(
        'call event ignored reason=missing_context callId=${_shortId(callId)} peer=${_shortId(peerUserId)} status=${status.name}',
      );
      return;
    }
    final conversationId = makeConversationId(profile.userId, peerUserId);
    final messageId = 'call_event_$callId';
    final timestamp = DateTime.fromMillisecondsSinceEpoch(
      timestampMs ?? DateTime.now().millisecondsSinceEpoch,
    );
    final peerName =
        peerNickname.isNotEmpty ? peerNickname : peerNameFor(peerUserId);
    final existing = _messageById(conversationId, messageId);
    final resolvedTimestamp = existing?.timestamp ?? timestamp;
    final resolvedServerTimestamp = existing?.serverTimestamp ?? timestamp;
    final resolvedReceivedAt = existing?.receivedAt ?? DateTime.now();
    final message = ChatMessage(
      id: messageId,
      conversationId: conversationId,
      peerUserId: peerUserId,
      fromUserId:
          direction == CallDirection.incoming ? peerUserId : profile.userId,
      fromNickname: peerName,
      text: _callEventText(direction, status, isVideo: isVideo),
      timestamp: resolvedTimestamp,
      serverTimestamp: resolvedServerTimestamp,
      receivedAt: resolvedReceivedAt,
      isMe: direction == CallDirection.outgoing,
      status: MessageDeliveryStatus.delivered,
      type: ChatMessageType.call,
      callId: callId,
      callDirection: direction,
      callStatus: status,
      isVideoCall: isVideo,
      callDurationSeconds: durationSeconds ?? existing?.callDurationSeconds,
    );
    await _persistMessage(message, peerNickname: peerName);
    final action = existing == null ? 'created' : 'updated';
    DiagnosticService.instance.log(
      'call history event $action status=${status.name} callId=${_shortId(callId)} peer=${_shortId(peerUserId)} '
      'direction=${direction.name} status=${status.name} video=$isVideo duration=${message.callDurationSeconds ?? 'none'} reason=$reason',
    );
  }

  String _callEventText(
    CallDirection direction,
    CallStatus status, {
    required bool isVideo,
  }) {
    final media = isVideo ? 'video' : 'voice';
    switch (status) {
      case CallStatus.outgoingRinging:
        return 'Outgoing $media call';
      case CallStatus.incomingRinging:
        return 'Incoming $media call';
      case CallStatus.missed:
        return 'Missed $media call';
      case CallStatus.rejectedByRecipient:
        return 'Rejected $media call';
      case CallStatus.canceledByCaller:
        return 'Canceled $media call';
      case CallStatus.failedTimeout:
      case CallStatus.failedNetwork:
        return 'Call failed';
      case CallStatus.connected:
        return direction == CallDirection.incoming
            ? 'Incoming $media call'
            : 'Outgoing $media call';
      case CallStatus.completed:
        return isVideo ? 'Video call' : 'Voice call';
    }
  }

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
    final localCreatedAt = DateTime.now();
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
      timestamp: localCreatedAt,
      clientTimestamp: localCreatedAt,
      localCreatedAt: localCreatedAt,
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
    if (!_isConnected) {
      try {
        await reconnect();
      } catch (error) {
        DiagnosticService.instance.log(
          'outgoing message reconnect failed id=${message.id} '
          'toUserId=${_shortId(peerUserId)} error=$error',
        );
        await _markMessageStatus(message.id, MessageDeliveryStatus.failed);
        rethrow;
      }
    }
    try {
      DiagnosticService.instance.log(
        'outgoing message payload id=${message.id} '
        'toUserId=${_shortId(peerUserId)} hasText=${encryptedText.isNotEmpty} '
        'hasCiphertext=${encryptedText.startsWith('HESTIA_TEXT_V1:')} '
        'hasRecipientPublicKey=${peerPublicKey.isNotEmpty} '
        'clientCreatedAt=${localCreatedAt.millisecondsSinceEpoch}',
      );
      _send({
        'type': 'message',
        'id': message.id,
        'toUserId': peerUserId,
        'recipientPublicKey': peerPublicKey,
        'text': encryptedText,
        'clientTimestamp': localCreatedAt.millisecondsSinceEpoch,
        'clientCreatedAt': localCreatedAt.millisecondsSinceEpoch,
      });
      WebSmokeLog.log('message sent id=${_shortId(message.id)}');
    } catch (error) {
      DiagnosticService.instance.log(
        'outgoing message send failed id=${message.id} '
        'toUserId=${_shortId(peerUserId)} error=$error',
      );
      await _markMessageStatus(message.id, MessageDeliveryStatus.failed);
      rethrow;
    }
    _scheduleSendTimeout(message.id);
  }

  Future<void> sendPickedFile({
    required String peerUserId,
    required String peerNickname,
    ChatMessage? replyTo,
  }) async {
    if (!AppConfig.enableFileAttachments) {
      throw Exception('File attachments are disabled in v0.1.0.');
    }
    final profile = this.profile;
    if (profile == null) {
      return;
    }
    ensureCanMessage(peerUserId);
    await loadBackendConfig();
    await _ensureLocalStorageReady(profile);
    final peerPublicKey = _requiredPeerPublicKey(peerUserId, peerNickname);

    _webFileLog('picker opened');
    final result = await FilePicker.pickFiles(
      withData: kIsWeb,
      withReadStream: !kIsWeb && !Platform.isMacOS,
      allowMultiple: false,
      type: FileType.any,
    );

    if (result == null || result.files.isEmpty) {
      return;
    }

    final file = result.files.single;
    _webFileLog(
      'file selected name=${file.name} size=${file.size} '
      'type=${AttachmentPolicy.kindForFileName(file.name) ?? 'unknown'}',
    );
    await _logPickedAttachmentVerification(file, phase: 'selected');
    final preflightValidation = AttachmentPolicy.validatePlatformFile(
      file,
      sizeBytes: file.size > 0 ? file.size : 1,
    );
    _logAndroidAttachmentPolicy(
      label: 'send preflight',
      name: file.name,
      extension: AttachmentPolicy.extensionForName(file.name),
      sizeBytes: file.size,
    );
    if (!preflightValidation.isValid) {
      await _logPickedAttachmentVerification(
        file,
        phase: 'preflight_failed',
        error: preflightValidation.error,
      );
      throw Exception(
        '${preflightValidation.error ?? 'Attachment validation failed.'} ${AttachmentPolicy.describeLimits()}',
      );
    }
    final androidPreflightLimitError = _androidAttachmentLimitError(
      kind: preflightValidation.kind,
      sizeBytes: file.size,
    );
    if (androidPreflightLimitError != null) {
      throw Exception(androidPreflightLimitError);
    }

    late final Uint8List bytes;
    late final AttachmentValidationResult validation;
    try {
      bytes = await _readPickedAttachmentBytes(file);
      validation = AttachmentPolicy.validateFileMetadata(
        name: AttachmentPolicy.baseName(file.name),
        extension: AttachmentPolicy.extensionForName(file.name),
        sizeBytes: bytes.length,
      );
    } catch (error) {
      await _logPickedAttachmentVerification(
        file,
        phase: 'verification_exception',
        error: error,
      );
      rethrow;
    }
    _logAndroidAttachmentPolicy(
      label: 'send validation',
      name: file.name,
      extension: validation.extension,
      kind: validation.kind,
      sizeBytes: bytes.length,
    );
    if (!validation.isValid) {
      await _logPickedAttachmentVerification(
        file,
        phase: 'validation_failed',
        error: validation.error,
      );
      throw Exception(
        '${validation.error ?? 'Attachment validation failed.'} ${AttachmentPolicy.describeLimits()}',
      );
    }
    final androidLimitError = _androidAttachmentLimitError(
      kind: validation.kind,
      sizeBytes: validation.sizeBytes,
    );
    if (androidLimitError != null) {
      throw Exception(androidLimitError);
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
    if (source.attachment != null && !AppConfig.enableFileAttachments) {
      throw Exception('Forwarding file attachments is disabled in v0.1.0.');
    }
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
    final localCreatedAt = DateTime.now();
    final attachmentKind =
        AttachmentPolicy.kindForFileName(fileName) ?? validation.kind;
    _setAttachmentProgress(
      messageId,
      AttachmentTransferProgress(
        stage: AttachmentTransferStage.preparing,
        transferredBytes: 0,
        totalBytes: validation.sizeBytes,
      ),
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
      timestamp: localCreatedAt,
      clientTimestamp: localCreatedAt,
      localCreatedAt: localCreatedAt,
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

    try {
      _setAttachmentProgress(
        messageId,
        AttachmentTransferProgress(
          stage: AttachmentTransferStage.encrypting,
          transferredBytes: 0,
          totalBytes: validation.sizeBytes,
        ),
      );
      final encryptionStopwatch = Stopwatch()..start();
      final transportFileName = _attachmentTransportFileName(
        messageId: messageId,
        extension: validation.extension,
      );
      final encryptedAttachment =
          await CryptoService.instance.encryptAttachment(
        fileName: transportFileName,
        kind: attachmentKind,
        sizeBytes: validation.sizeBytes,
        bytes: bytes,
        recipientPublicKeyBase64: peerPublicKey,
        messageMetadata: metadata,
      );
      encryptionStopwatch.stop();
      _webFileLog(
        'encrypted name=$fileName size=${validation.sizeBytes} '
        'payloadBytes=${encryptedAttachment.length}',
      );
      DiagnosticService.instance.log(
        'attachment encryption completed id=$messageId '
        'kind=$attachmentKind fileSizeBytes=${validation.sizeBytes} '
        'originalName=$fileName transportName=$transportFileName '
        'payloadBytes=${encryptedAttachment.length} '
        'durationMs=${encryptionStopwatch.elapsedMilliseconds}',
      );
      String? blobId;
      if (AppConfig.blobTransferEnabled) {
        blobId = await _uploadEncryptedAttachmentBlob(
          messageId: messageId,
          peerUserId: peerUserId,
          fileName: fileName,
          validation: validation,
          encryptedAttachment: encryptedAttachment,
        );
      } else {
        throw const _AttachmentBlobUploadException(
          'Upload endpoint unavailable.',
          allowInlineFallback: false,
        );
      }

      final attachmentPayload = <String, dynamic>{
        'name': 'encrypted.hestia',
        'originalName': fileName,
        'extension': validation.extension,
        'kind': 'document',
        'originalKind': attachmentKind,
        'sizeBytes': encryptedAttachment.length,
        'originalSizeBytes': validation.sizeBytes,
        'encodedSizeBytes': encryptedAttachment.length,
        'encrypted': true,
        'blobId': blobId,
      };
      DiagnosticService.instance.log(
        'attachment message payload id=${message.id} '
        'originalName=$fileName extension=${validation.extension} '
        'kind=document originalKind=$attachmentKind '
        'sizeBytes=${encryptedAttachment.length} '
        'originalSizeBytes=${validation.sizeBytes} blobId=$blobId '
        'keys=${attachmentPayload.keys.join(',')}',
      );

      _send({
        'type': 'message',
        'id': message.id,
        'toUserId': peerUserId,
        'recipientPublicKey': peerPublicKey,
        'text': '',
        'clientTimestamp': localCreatedAt.millisecondsSinceEpoch,
        'attachment': attachmentPayload,
      });
      _webFileLog(
          'attachment message sent name=$fileName size=${validation.sizeBytes}');
      _setAttachmentProgress(
        messageId,
        AttachmentTransferProgress(
          stage: AttachmentTransferStage.sent,
          transferredBytes: encryptedAttachment.length,
          totalBytes: encryptedAttachment.length,
        ),
      );
      _scheduleSendTimeout(message.id);
    } catch (error) {
      _webFileLog('error reason=send_failed');
      DiagnosticService.instance.log(
        'attachment send failed id=$messageId '
        'toUserId=${_shortId(peerUserId)} error=$error',
      );
      _setAttachmentProgress(
        messageId,
        AttachmentTransferProgress(
          stage: AttachmentTransferStage.failed,
          transferredBytes: 0,
          totalBytes: validation.sizeBytes,
          error: error.toString(),
        ),
      );
      await _markMessageStatus(messageId, MessageDeliveryStatus.failed);
      rethrow;
    }
  }

  Future<void> _logPickedAttachmentVerification(
    PlatformFile file, {
    required String phase,
    Object? error,
  }) async {
    final originalPath = file.path ?? '';
    final originalName = file.name;
    final baseName = AttachmentPolicy.baseName(originalName);
    final nameExtension = AttachmentPolicy.extensionForName(originalName);
    final pickerExtension = (file.extension ?? '').trim().toLowerCase();
    final extension =
        nameExtension.isNotEmpty ? nameExtension : pickerExtension;
    final kind = AttachmentPolicy.kindForExtension(extension);
    final sanitizedName = AttachmentPolicy.sanitizeFileName(originalName);
    var exists = false;
    var canRead = false;
    var lengthBytes = file.size;
    String? probeError;

    if (file.bytes != null) {
      exists = true;
      canRead = true;
      lengthBytes = file.bytes!.length;
    } else if (file.readStream != null) {
      exists = true;
      canRead = true;
    } else if (!kIsWeb && originalPath.trim().isNotEmpty) {
      try {
        final localFile = File(originalPath);
        exists = await localFile.exists();
        if (exists) {
          lengthBytes = await localFile.length();
          final handle = await localFile.open();
          await handle.close();
          canRead = true;
        }
      } catch (probeException) {
        probeError = '${probeException.runtimeType}: $probeException';
      }
    }

    DiagnosticService.instance.log(
      'attachment verification phase=$phase platform=${_platformName()} '
      'originalPath=$originalPath originalName=$originalName '
      'baseName=$baseName sanitizedName=$sanitizedName '
      'extension=$extension pickerExtension=$pickerExtension mimeType=unknown '
      'kind=${kind ?? 'unknown'} fileExists=$exists canRead=$canRead '
      'fileLengthBytes=$lengthBytes policyMax=${kind == null ? 0 : AttachmentPolicy.maxBytesForKind(kind)} '
      'hardMax=${AttachmentPolicy.hardMaxBytes} '
      'probeError=${probeError ?? 'none'} '
      'exception=${error == null ? 'none' : '${error.runtimeType}: $error'}',
    );
  }

  Future<Uint8List> _readPickedAttachmentBytes(PlatformFile file) async {
    DiagnosticService.instance.log(
      'attachment picked platform=${_platformName()} name=${file.name} '
      'ext=${AttachmentPolicy.extensionForName(file.name)} sizeBytes=${file.size} '
      'hasPath=${file.path?.isNotEmpty == true} hasBytes=${file.bytes != null} '
      'hasReadStream=${file.readStream != null}',
    );

    final directBytes = file.bytes;
    if (directBytes != null && directBytes.isNotEmpty) {
      if (directBytes.length > AttachmentPolicy.hardMaxBytes) {
        throw Exception('Attachment is too large.');
      }
      DiagnosticService.instance
          .log('attachment read source=bytes sizeBytes=${directBytes.length}');
      return directBytes;
    }

    final stream = file.readStream;
    if (stream != null) {
      try {
        final builder = BytesBuilder(copy: false);
        var totalBytes = 0;
        await for (final chunk in stream) {
          totalBytes += chunk.length;
          if (totalBytes > AttachmentPolicy.hardMaxBytes) {
            throw Exception('Attachment is too large.');
          }
          builder.add(chunk);
        }
        final bytes = builder.takeBytes();
        if (bytes.isEmpty) {
          throw Exception('Could not read the selected file');
        }
        DiagnosticService.instance
            .log('attachment read source=stream sizeBytes=${bytes.length}');
        return bytes;
      } on FileSystemException catch (error) {
        DiagnosticService.instance
            .log('attachment read stream filesystem error=${error.message}');
        throw Exception('Could not access the selected file.');
      } catch (error) {
        if ('$error'.contains('Attachment is too large.')) {
          throw Exception('Attachment is too large.');
        }
        DiagnosticService.instance.log('attachment read stream error=$error');
        throw Exception('Could not read the selected file');
      }
    }

    final path = file.path;
    if (kIsWeb || path == null || path.trim().isEmpty) {
      DiagnosticService.instance.log('attachment read failed missing path');
      throw Exception('Could not read the selected file');
    }

    try {
      final localFile = File(path);
      if (!await localFile.exists()) {
        DiagnosticService.instance.log('attachment read path not found');
        throw Exception('File was not found on device.');
      }
      final sizeBytes = await localFile.length();
      if (sizeBytes > AttachmentPolicy.hardMaxBytes) {
        throw Exception('Attachment is too large.');
      }
      final bytes = _androidRuntime
          ? await compute(_readFileBytesWorker, path)
          : await localFile.readAsBytes();
      if (bytes.isEmpty) {
        throw Exception('Could not read the selected file');
      }
      DiagnosticService.instance
          .log('attachment read source=path sizeBytes=${bytes.length}');
      return bytes;
    } on FileSystemException catch (error) {
      DiagnosticService.instance
          .log('attachment read path filesystem error=${error.message}');
      throw Exception('Could not access the selected file.');
    }
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

    DiagnosticService.instance.log(
      'attachment upload start name=$fileName ext=${validation.extension} '
      'kind=${validation.kind} sizeBytes=${validation.sizeBytes} '
      'payloadBytes=${encryptedAttachment.length}',
    );
    _webFileLog(
      'upload started name=$fileName size=${validation.sizeBytes} '
      'payloadBytes=${encryptedAttachment.length}',
    );
    _setAttachmentProgress(
      messageId,
      AttachmentTransferProgress(
        stage: AttachmentTransferStage.uploading,
        transferredBytes: 0,
        totalBytes: encryptedAttachment.length,
      ),
    );

    http.Response? lastResponse;
    for (final uploadUrl in AppConfig.uploadBlobUrls) {
      final attempts = _uploadMetadataAttempts(validation);
      for (var attemptIndex = 0;
          attemptIndex < attempts.length;
          attemptIndex++) {
        final metadata = attempts[attemptIndex];
        final uri = Uri.parse(uploadUrl).replace(
          queryParameters: {
            'toUserId': peerUserId,
            'messageId': messageId,
            'originalName': fileName,
            'extension': metadata.extension,
            'originalKind': metadata.kind,
            'originalSizeBytes': validation.sizeBytes.toString(),
            'sizeBytes': validation.sizeBytes.toString(),
          },
        );
        DiagnosticService.instance.log(
          'attachment upload url=${_redactQuery(uri.toString())} '
          'metadataExt=${metadata.extension} metadataKind=${metadata.kind} '
          'compat=${metadata.compatibility}',
        );
        final request = http.StreamedRequest('POST', uri)
          ..headers.addAll(_blobAuthHeaders())
          ..headers['Content-Type'] = 'text/plain; charset=utf-8';

        late final http.Response response;
        try {
          final uploadStopwatch = Stopwatch()..start();
          final sendFuture = request.send();
          await _writeAsciiStringToSink(
            request.sink,
            encryptedAttachment,
            onProgress: (sentBytes) {
              _setAttachmentProgress(
                messageId,
                AttachmentTransferProgress(
                  stage: AttachmentTransferStage.uploading,
                  transferredBytes: sentBytes,
                  totalBytes: encryptedAttachment.length,
                ),
              );
            },
          );
          response = await http.Response.fromStream(await sendFuture)
              .timeout(const Duration(minutes: 10));
          uploadStopwatch.stop();
          DiagnosticService.instance.log(
            'attachment upload completed status=${response.statusCode} '
            'payloadBytes=${encryptedAttachment.length} '
            'durationMs=${uploadStopwatch.elapsedMilliseconds}',
          );
        } on TimeoutException {
          DiagnosticService.instance.log(
            'attachment upload failed reason=timeout '
            'payloadBytes=${encryptedAttachment.length}',
          );
          throw const _AttachmentBlobUploadException(
            'Upload endpoint unavailable.',
            allowInlineFallback: true,
          );
        } catch (error) {
          DiagnosticService.instance
              .log('attachment upload failed reason=network error=$error');
          throw const _AttachmentBlobUploadException(
            'Upload endpoint unavailable.',
            allowInlineFallback: true,
          );
        }
        lastResponse = response;
        DiagnosticService.instance.log(
          'attachment upload status=${response.statusCode} '
          'message=${_serverErrorMessage(response.body) ?? ''}',
        );
        if (response.statusCode == 200) {
          late final Map<String, dynamic> json;
          try {
            json = jsonDecode(response.body) as Map<String, dynamic>;
          } catch (error) {
            DiagnosticService.instance.log(
              'attachment upload invalid response status=${response.statusCode} error=$error',
            );
            throw const _AttachmentBlobUploadException(
              'Invalid upload response.',
              allowInlineFallback: true,
            );
          }
          final blobId = json['blobId'] as String? ?? '';
          if (blobId.isEmpty) {
            throw const _AttachmentBlobUploadException(
              'Invalid upload response.',
              allowInlineFallback: true,
            );
          }
          DiagnosticService.instance.log('attachment upload blobId=$blobId');
          _webFileLog(
            'upload completed name=$fileName size=${validation.sizeBytes}',
          );
          return blobId;
        }
        final serverMessage = _serverErrorMessage(response.body);
        if (response.statusCode == 400 &&
            serverMessage == 'Attachment type is not allowed.' &&
            attemptIndex + 1 < attempts.length) {
          DiagnosticService.instance.log(
            'attachment upload retry reason=legacy_backend_policy '
            'originalExt=${validation.extension} nextExt=${attempts[attemptIndex + 1].extension}',
          );
          continue;
        }
        if (response.statusCode != 404 && response.statusCode != 405) {
          break;
        }
      }
      final response = lastResponse;
      if (response != null &&
          response.statusCode != 404 &&
          response.statusCode != 405) {
        break;
      }
    }

    final response = lastResponse;
    if (response == null) {
      throw const _AttachmentBlobUploadException(
        'Upload endpoint unavailable.',
        allowInlineFallback: true,
      );
    }
    final uploadError = _attachmentUploadError(response);
    _webFileLog('error reason=upload_failed status=${response.statusCode}');
    throw _AttachmentBlobUploadException(
      uploadError,
      allowInlineFallback: _canFallbackToInline(response),
    );
  }

  List<_AttachmentUploadMetadata> _uploadMetadataAttempts(
    AttachmentValidationResult validation,
  ) {
    final actual = _AttachmentUploadMetadata(
      extension: validation.extension,
      kind: validation.kind,
      compatibility: false,
    );
    final compat = _legacyBackendUploadMetadata(validation);
    if (compat == null ||
        (compat.extension == actual.extension && compat.kind == actual.kind)) {
      return [actual];
    }
    return [actual, compat];
  }

  _AttachmentUploadMetadata? _legacyBackendUploadMetadata(
    AttachmentValidationResult validation,
  ) {
    if (validation.kind == 'video') {
      return const _AttachmentUploadMetadata(
        extension: 'mp4',
        kind: 'video',
        compatibility: true,
      );
    }
    if (validation.kind == 'archive' ||
        validation.kind == 'ebook' ||
        validation.kind == 'document') {
      return const _AttachmentUploadMetadata(
        extension: 'txt',
        kind: 'document',
        compatibility: true,
      );
    }
    return null;
  }

  Future<void> _writeAsciiStringToSink(
    StreamSink<List<int>> sink,
    String value, {
    void Function(int sentBytes)? onProgress,
  }) async {
    const chunkChars = 256 * 1024;
    var sentBytes = 0;
    var lastProgressAt = DateTime.fromMillisecondsSinceEpoch(0);
    try {
      for (var offset = 0; offset < value.length; offset += chunkChars) {
        final end = (offset + chunkChars) < value.length
            ? offset + chunkChars
            : value.length;
        final chunk = utf8.encode(value.substring(offset, end));
        sink.add(chunk);
        sentBytes += chunk.length;
        final now = DateTime.now();
        if (onProgress != null &&
            (sentBytes >= value.length ||
                now.difference(lastProgressAt).inMilliseconds >= 250)) {
          lastProgressAt = now;
          onProgress(sentBytes);
        }
        if (offset % (chunkChars * 8) == 0) {
          await Future<void>.delayed(Duration.zero);
        }
      }
      await sink.close();
    } catch (error) {
      await sink.close();
      rethrow;
    }
  }

  String _attachmentTransportFileName({
    required String messageId,
    required String extension,
  }) {
    final safeExtension = extension
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]'), '')
        .replaceAll(RegExp(r'^\.+'), '');
    final safeId = messageId
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9_-]'), '')
        .replaceAll(RegExp(r'^[-_]+|[-_]+$'), '');
    final base = safeId.isEmpty ? 'attachment' : 'attachment_$safeId';
    return safeExtension.isEmpty ? base : '$base.$safeExtension';
  }

  Future<String> exportAttachment(ChatAttachment attachment) {
    return LocalDataService.instance.exportAttachment(attachment);
  }

  Future<String?> exportEncryptedBackup(
    String passphrase, {
    required String dialogTitle,
  }) {
    return BackupService.instance.exportEncryptedBackup(
      passphrase,
      dialogTitle: dialogTitle,
    );
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
    _intentionalDisconnect = true;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _setConnectionStatus(ServerConnectionStatus.disconnected);
    _channel?.sink.close();
    _channel = null;
    _socketFailureReported = false;
  }

  void _openSocket({required void Function() onReady}) {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _intentionalDisconnect = false;
    _channel?.sink.close();
    _channel = null;
    _setConnectionStatus(ServerConnectionStatus.connecting);
    _logConnection('connecting target=${AppConfig.wsUrl}');
    WebSmokeLog.log('websocket connecting url=${AppConfig.wsUrl}');
    _recordForegroundServiceSocketConnecting();

    try {
      _channel = WebSocketChannel.connect(Uri.parse(AppConfig.wsUrl));
    } catch (error) {
      _handleSocketError(error);
      return;
    }

    final channel = _channel!;

    _incomingSignalQueue = Future<void>.value();
    channel.stream.listen(
      (raw) {
        if (!identical(_channel, channel)) {
          _logConnection('ignored stale websocket frame');
          return;
        }
        _incomingSignalQueue = _incomingSignalQueue
            .then((_) => _handleRaw(raw))
            .catchError(_handleQueuedSignalError);
      },
      onDone: () {
        if (!identical(_channel, channel)) {
          _logConnection('ignored stale websocket disconnected');
          return;
        }
        _logConnection('disconnected');
        _recordForegroundServiceSocketClosed('socket_done');
        if (_connectionStatus != ServerConnectionStatus.authError &&
            _connectionStatus != ServerConnectionStatus.serverError) {
          _setConnectionStatus(ServerConnectionStatus.disconnected);
        }
        _channel = null;
        if (!_intentionalDisconnect) {
          _scheduleReconnect('socket_done');
        }
      },
      onError: (error) {
        if (!identical(_channel, channel)) {
          _logConnection('ignored stale websocket error $error');
          return;
        }
        _handleSocketError(error);
      },
    );

    unawaited(_completeSocketOpen(channel, onReady));
  }

  Future<void> _completeSocketOpen(
    WebSocketChannel channel,
    void Function() onReady,
  ) async {
    try {
      await channel.ready.timeout(const Duration(seconds: 6));
    } catch (error) {
      if (!identical(_channel, channel)) {
        return;
      }
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
      return;
    }
    if (!identical(_channel, channel)) {
      return;
    }
    _logConnection('websocket opened');
    _recordForegroundServiceSocketConnected();
    onReady();
  }

  void _handleSocketError(Object error) {
    _setConnectionStatus(ServerConnectionStatus.serverError);
    _recordForegroundServiceSocketError(error);
    WebSmokeLog.log(
        'runtime blocker reason=websocket_connect_failed error=$error');
    if (!_intentionalDisconnect) {
      _scheduleReconnect('socket_error');
    }
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

  void _scheduleReconnect(String reason) {
    if (profile == null || _intentionalDisconnect || _reconnectInFlight) {
      return;
    }
    if (_reconnectTimer?.isActive ?? false) {
      return;
    }
    DiagnosticService.instance
        .log('websocket reconnect scheduled reason=$reason');
    _recordForegroundServiceReconnect('scheduled:$reason');
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      if (profile == null || _intentionalDisconnect || _isConnected) {
        return;
      }
      unawaited(_runAutoReconnect(reason));
    });
  }

  Future<void> _runAutoReconnect(String reason) async {
    if (_reconnectInFlight) {
      return;
    }
    _reconnectInFlight = true;
    try {
      DiagnosticService.instance
          .log('websocket reconnect begin reason=$reason');
      _recordForegroundServiceReconnect('begin:$reason');
      final current = profile ?? StorageService.instance.loadProfile();
      if (current == null) {
        return;
      }
      await connectWithProfile(current);
      if (_isConnected) {
        DiagnosticService.instance.log('websocket reconnect ok reason=$reason');
        _recordForegroundServiceReconnect('ok:$reason');
        return;
      }
    } catch (error) {
      DiagnosticService.instance
          .log('websocket reconnect failed reason=$reason error=$error');
      _recordForegroundServiceSocketError(error);
    } finally {
      _reconnectInFlight = false;
    }
    _scheduleReconnect('retry_after_failure');
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
    DiagnosticService.instance.log(
      'websocket incoming frame type=${type.isEmpty ? 'unknown' : type} '
      'currentUserId=${_shortId(profile?.userId ?? '')} '
      'sessionId=${_shortId(_currentSessionInfo()?.id ?? '')} '
      'deviceId=${_shortId(_currentSessionInfo()?.deviceId ?? '')} '
      'appLifecycleState=${CallService.instance.appLifecycleState}',
    );
    _recordBackgroundWsEvent(type);
    _recordForegroundServiceIncomingFrame(json);
    if (type == 'new_message') {
      final messageJson = json['message'];
      final messageId = messageJson is Map ? messageJson['id'] : null;
      DiagnosticService.instance.log(
        'websocket received new_message id=${messageId ?? 'none'}',
      );
    } else if (type == 'message_sent' ||
        type == 'message_failed' ||
        type == 'delivery_ack') {
      final messageJson = json['message'];
      final messageId = type == 'message_sent' && messageJson is Map
          ? messageJson['id']
          : json['id'];
      DiagnosticService.instance.log(
        'websocket received $type id=${messageId ?? 'none'} '
        'reason=${json['reason'] ?? 'none'}',
      );
    } else if (type == 'error') {
      DiagnosticService.instance.log(
        'websocket received error id=${json['id'] ?? 'none'} '
        'message=${json['message'] ?? 'Unknown server error'}',
      );
    } else if (type == 'missed_call') {
      await recordMissedCall(
        callId: json['callId'] as String? ?? '',
        fromUserId: json['fromUserId'] as String? ?? '',
        fromNickname: json['fromNickname'] as String? ?? '',
        timestampMs: _callTimestampMs(json),
        reason: 'server_missed_call',
      );
      return;
    }
    if (type.startsWith('call_') || type == 'call_offer') {
      DiagnosticService.instance.log(
        'websocket received $type callId=${_shortId(json['callId']?.toString() ?? '')} '
        'fromUserId=${_shortId(json['fromUserId']?.toString() ?? '')} '
        'toUserId=${_shortId(json['toUserId']?.toString() ?? '')} '
        'voiceCalls=${AppConfig.enableVoiceCalls} socketState=${_connectionStatus.name}',
      );
      if (!AppConfig.enableVoiceCalls && !AppConfig.enableVideoCalls) {
        DiagnosticService.instance.log(
          'call signal ignored reason=voiceCalls_disabled type=$type',
        );
        return;
      }
      if (type == 'call_offer_init' ||
          (type == 'call_offer' && json['sdp'] is! String)) {
        final fromUserId = json['fromUserId'] as String? ?? '';
        final callId = json['callId'] as String? ?? '';
        final diagnosticType = type == 'call_offer' || type == 'call_offer_init'
            ? type
            : 'call_offer_init';
        final createdAtMs = _callTimestampMs(json);
        final nowMs = DateTime.now().millisecondsSinceEpoch;
        final ttlMs = _positiveInt(
          json['ttlMs'] ?? json['callOfferTtlMs'],
          CallService.callOfferTtlMs,
        );
        // Relax the TTL verification to tolerate up to 5 minutes of clock drift
        final effectiveTtlMs = ttlMs > 300000 ? ttlMs : 300000;
        final ageMs = nowMs - createdAtMs;
        final callerClockAgeMs = nowMs - createdAtMs;
        final hasActiveContact = _isActiveContact(fromUserId);
        final contactSummary = _contactStatusSummary(fromUserId);
        final blockSummary = _blockStatusSummary(fromUserId);
        final currentSession = _currentSessionInfo();
        final microphoneStatus = await _microphonePermissionStatusForLog();
        final call = CallService.instance;
        DiagnosticService.instance.log(
          'incoming call frame received type=$type callId=${_shortId(callId)} '
          'fromUserId=${_shortId(fromUserId)} rawType=$type '
          'currentUserId=${_shortId(profile?.userId ?? '')} '
          'sessionId=${_shortId(currentSession?.id ?? '')} '
          'deviceId=${_shortId(currentSession?.deviceId ?? '')}',
        );
        DiagnosticService.instance.log(
          'incoming call_offer type=$type semanticType=$diagnosticType callId=${_shortId(callId)} '
          'from=${_shortId(fromUserId)} fromName=${json['fromNickname'] ?? ''} '
          'video=${json['video'] == true} callCreatedAt=$createdAtMs '
          'serverTimestamp=${json['serverTimestamp'] ?? 'none'} '
          'timestamp=${json['timestamp'] ?? 'none'} nowMs=$nowMs ageMs=$ageMs '
          'callerClockAgeMs=$callerClockAgeMs ttlMs=$ttlMs '
          'appLifecycleState=${call.appLifecycleState} '
          'isAlreadyInCall=${call.isAlreadyInCall} '
          'currentCallId=${_shortId(call.currentCallId)} '
          'hasActiveContact=$hasActiveContact voiceCalls=${AppConfig.enableVoiceCalls} '
          'contactStatus=$contactSummary blockStatus=$blockSummary '
          'microphonePermission=$microphoneStatus '
          'routeDialogState=${call.routeDialogState}',
        );
        if (callId.isEmpty) {
          DiagnosticService.instance.log(
            'call signal ignored reason=callId_missing type=$type',
          );
          return;
        }
        if (fromUserId.isEmpty) {
          DiagnosticService.instance.log(
            'call signal ignored reason=fromUserId_missing callId=${_shortId(callId)}',
          );
          return;
        }
        if (ageMs > effectiveTtlMs) {
          DiagnosticService.instance.log(
            'incoming call expired ageMs=$ageMs ttlMs=$ttlMs '
            'effectiveTtlMs=$effectiveTtlMs callId=${_shortId(callId)}',
          );
          await recordMissedCall(
            callId: callId,
            fromUserId: fromUserId,
            fromNickname: json['fromNickname'] as String? ?? '',
            timestampMs: _callTimestampMs(json),
            reason: 'expired_offer',
          );
          return;
        }
        final senderPublicKey = json['senderPublicKey'] as String?;
        final keyInfo = peerKeyInfo(fromUserId, peerNameFor(fromUserId));
        final advertisedKey = senderPublicKey == null || senderPublicKey.isEmpty
            ? keyInfo.publicKey
            : senderPublicKey;
        final blocked = _isBlocked(fromUserId);
        final notActiveContact =
            _privacySettings.allowCallsFrom == PrivacyAllowFrom.contacts &&
                !hasActiveContact;
        final keyMismatch = keyInfo.state == PeerKeyTrustState.verified &&
            advertisedKey != keyInfo.publicKey;
        DiagnosticService.instance.log(
          'incoming call_offer local checks callId=${_shortId(callId)} '
          'blocked=$blocked notActiveContact=$notActiveContact '
          'keyState=${keyInfo.state.name} keyMismatch=$keyMismatch '
          'allowCallsFrom=${_privacySettings.allowCallsFrom.name} '
          'contactStatus=$contactSummary blockStatus=$blockSummary '
          'appLifecycleState=${call.appLifecycleState}',
        );
        if (blocked) {
          DiagnosticService.instance.log(
            'incoming call rejected reason=blocked '
            'from=${_shortId(fromUserId)} callId=${_shortId(callId)}',
          );
          _send({
            'type': 'call_reject',
            'callId': json['callId'],
            'toUserId': fromUserId,
            'reason': 'blocked',
          });
          return;
        }
        final firstCallReceived = await RetentionService.instance
            .markSeen(RetentionMoment.callReceived);
        if (firstCallReceived) {
          sendRetentionEvent(RetentionMoment.callReceived);
        }
        DiagnosticService.instance.log(
          'incoming call accepted for UI preflight type=$type callId=${_shortId(callId)} '
          'from=${_shortId(fromUserId)} reason=local_preflight_ok '
          'contactStatus=$contactSummary blockStatus=$blockSummary',
        );
        if (call.state == CallState.incoming &&
            call.incomingCall?.callId == callId) {
          DiagnosticService.instance.log(
            'duplicate call ignored callId=${_shortId(callId)} source=ChatService',
          );
          return;
        }
        if (call.canShowIncomingCallNotification(
          callId,
          source: 'main_app_websocket',
        )) {
          await FirebasePushService.showLocalNotificationForAction(
            PushAction(
              type: PushActionType.incomingCall,
              requestId: callId,
              fromUserId: fromUserId,
              fromUsername: json['fromNickname'] as String? ?? '',
              video: json['video'] == true,
              timestampMs: createdAtMs,
              ttlMs: ttlMs,
            ),
          );
          _recordForegroundServiceNotificationShown('call');
        }
      }
      await CallService.instance.handleSignal(json);
      if (type == 'call_offer_init' ||
          (type == 'call_offer' && json['sdp'] is! String)) {
        DiagnosticService.instance.log(
          'incoming call UI shown callId=${_shortId(json['callId']?.toString() ?? '')} '
          'state=${CallService.instance.state.name} lifecycle=${CallService.instance.appLifecycleState}',
        );
      }
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
        _setConnectionStatus(ServerConnectionStatus.connected);
        _logConnection('auth_ok received userId=${_shortId(user.userId)}');
        WebSmokeLog.log('auth_ok userId=${_shortId(user.userId)}');
        _recordForegroundServiceAuthOk(user);
        if (AppConfig.enablePushNotifications) {
          unawaited(refreshPushRegistration());
          unawaited(_ensureWakeupAfterAuthAndRecord(user));
        }
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
        WebSmokeLog.log('contacts loaded count=${contacts.length}');
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
        await FirebasePushService.instance.stopForegroundFallback();
        await StorageService.instance.clearProfile();
        _clearRuntimeUserState();
        disconnect();
        _recordError('This session was revoked.');
        onError?.call('This session was revoked.');
        notifyListeners();
        break;
      case 'logout_ok':
        await FirebasePushService.instance.stopForegroundFallback();
        await StorageService.instance.clearProfile();
        _clearRuntimeUserState();
        disconnect();
        notifyListeners();
        break;
      case 'push_token_updated':
        if (kDebugMode) {
          debugPrint('[ChatService] FCM token registered on backend.');
        }
        FirebasePushService.instance.markTokenUploaded();
        await _ensureWakeupAfterAuthAndRecord(profile!);
        await requestSessions();
        break;
      case 'push_token_removed':
        if (kDebugMode) {
          debugPrint('[ChatService] FCM token removed on backend.');
        }
        FirebasePushService.instance.markTokenRemoved();
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
        _logIncomingMessageDebug('new_message frame', messageJson);
        var stored = false;
        try {
          stored = await _receiveMessage(messageJson);
        } catch (error) {
          DiagnosticService.instance.log(
            "message receive failed messageId=${messageJson['id'] ?? 'none'} "
            'error=$error',
          );
        }
        if (stored) {
          WebSmokeLog.log(
            'message received id=${_shortId(messageJson['id']?.toString() ?? '')}',
          );
          DiagnosticService.instance.log(
            'websocket sending delivery_ack id=${messageJson['id'] ?? 'none'}',
          );
          _send({
            'type': 'delivery_ack',
            'id': messageJson['id'],
            'fromUserId': messageJson['fromUserId'],
          });
        }
        break;
      case 'message_sent':
        final messageJson = Map<String, dynamic>.from(json['message'] as Map);
        await _applyServerMessageUpdate(
          messageJson,
          status: MessageDeliveryStatus.sent,
          direction: 'outgoing',
        );
        break;
      case 'message_failed':
        final messageId = json['id'] as String? ?? '';
        await _markMessageStatus(messageId, MessageDeliveryStatus.failed);
        final reason = json['reason'] as String? ?? 'message_failed';
        _recordError(reason);
        onError?.call(reason);
        break;
      case 'delivery_ack':
        await _markMessageStatus(
          json['id'] as String? ?? '',
          MessageDeliveryStatus.delivered,
        );
        break;
      case 'error':
        final message = json['message'] as String? ?? 'Unknown server error';
        final messageId = json['id'] as String? ?? '';
        if (messageId.isNotEmpty) {
          await _markMessageStatus(messageId, MessageDeliveryStatus.failed);
        }
        if (_authCompleter != null && !_authCompleter!.isCompleted) {
          _setConnectionStatus(ServerConnectionStatus.authError);
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
      await _applyServerMessageUpdate(
        json,
        status: MessageDeliveryStatus.delivered,
        direction: 'incoming-duplicate',
      );
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
    var messageStatus = MessageDeliveryStatus.delivered;

    _logIncomingMessageDebug('receiveMessage parsed header', json);
    if (attachmentJson is Map) {
      final attachmentMap = Map<String, dynamic>.from(attachmentJson);
      final placeholderAttachment = _placeholderIncomingAttachment(
        messageId: messageId,
        attachmentJson: attachmentMap,
      );
      _setAttachmentProgress(
        messageId,
        AttachmentTransferProgress(
          stage: AttachmentTransferStage.downloading,
          transferredBytes: 0,
          totalBytes: placeholderAttachment.sizeBytes > 0
              ? placeholderAttachment.sizeBytes
              : null,
        ),
      );
      await _persistMessage(
        ChatMessage(
          id: messageId,
          conversationId: conversationId,
          peerUserId: fromUserId,
          fromUserId: fromUserId,
          fromNickname: fromNickname,
          text: decodedText.text,
          timestamp: _messageDateTime(json, 'timestamp') ?? DateTime.now(),
          clientTimestamp: _messageDateTime(json, 'clientCreatedAt') ??
              _messageDateTime(json, 'clientTimestamp'),
          serverTimestamp: _messageDateTime(json, 'serverReceivedAt') ??
              _messageDateTime(json, 'serverTimestamp'),
          receivedAt: DateTime.now(),
          serverSequence: _messageInt(json, 'serverSequence'),
          isMe: false,
          attachment: placeholderAttachment,
          status: MessageDeliveryStatus.delivered,
        ),
        peerNickname: fromNickname,
      );
      final storedAttachment = await _storeIncomingAttachment(
        messageId: messageId,
        attachmentJson: attachmentMap,
      );
      attachment = storedAttachment?.attachment;
      DiagnosticService.instance.log(
        "attachment receive store result messageId=$messageId "
        "saved=${attachment != null} localName=${attachment?.name ?? 'none'} "
        "localKind=${attachment?.kind ?? 'none'} "
        "localSizeBytes=${attachment?.sizeBytes ?? 0}",
      );
      if (storedAttachment?.messageMetadata != null) {
        metadata = {
          ...metadata,
          ...storedAttachment!.messageMetadata,
        };
      }
      if (attachmentJson['encrypted'] == true && attachment == null) {
        DiagnosticService.instance.log(
          'attachment receive continuing without file messageId=$messageId',
        );
        attachment = placeholderAttachment;
        messageStatus = MessageDeliveryStatus.failed;
        _failAttachmentProgressIfMissing(
          messageId,
          'Attachment processing failed.',
        );
      } else if (attachment != null) {
        _setAttachmentProgress(
          messageId,
          AttachmentTransferProgress(
            stage: AttachmentTransferStage.received,
            transferredBytes: attachment.sizeBytes,
            totalBytes: attachment.sizeBytes,
          ),
        );
      }
    }

    final message = ChatMessage(
      id: messageId,
      conversationId: conversationId,
      peerUserId: fromUserId,
      fromUserId: fromUserId,
      fromNickname: fromNickname,
      text: decodedText.text,
      timestamp: _messageDateTime(json, 'timestamp') ?? DateTime.now(),
      clientTimestamp: _messageDateTime(json, 'clientCreatedAt') ??
          _messageDateTime(json, 'clientTimestamp'),
      serverTimestamp: _messageDateTime(json, 'serverReceivedAt') ??
          _messageDateTime(json, 'serverTimestamp'),
      receivedAt: DateTime.now(),
      serverSequence: _messageInt(json, 'serverSequence'),
      isMe: false,
      attachment: attachment,
      status: messageStatus,
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
    _logMessageSortDebug(message, direction: 'incoming');
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
    if (_shouldNotifyWhileBackgrounded) {
      await FirebasePushService.showLocalNotificationForAction(
        PushAction(
          type: PushActionType.message,
          messageId: message.id,
          fromUserId: fromUserId,
          fromUsername: fromNickname,
          timestampMs: (message.serverTimestamp ?? message.timestamp)
              .millisecondsSinceEpoch,
        ),
      );
      _recordForegroundServiceNotificationShown('message');
    }
    notifyListeners();
    return true;
  }

  Future<_StoredIncomingAttachment?> _storeIncomingAttachment({
    required String messageId,
    required Map<String, dynamic> attachmentJson,
  }) async {
    return _incomingAttachmentQueue.run(
      () => _storeIncomingAttachmentQueued(
        messageId: messageId,
        attachmentJson: attachmentJson,
      ),
    );
  }

  ChatAttachment _placeholderIncomingAttachment({
    required String messageId,
    required Map<String, dynamic> attachmentJson,
  }) {
    final name = (attachmentJson['originalName'] as String?) ??
        (attachmentJson['name'] as String?) ??
        'attachment.bin';
    final declaredKind = _attachmentKindForLog(attachmentJson);
    final extensionKind = AttachmentPolicy.kindForFileName(name);
    final kind = extensionKind ?? declaredKind;
    final sizeBytes = _attachmentSizeForLog(attachmentJson);
    return ChatAttachment(
      id: messageId,
      name: name,
      localPath: '',
      sizeBytes: sizeBytes,
      kind: {'document', 'archive', 'ebook', 'image', 'audio', 'video'}
              .contains(kind)
          ? kind
          : inferAttachmentKind(name),
    );
  }

  Future<_StoredIncomingAttachment?> _storeIncomingAttachmentQueued({
    required String messageId,
    required Map<String, dynamic> attachmentJson,
  }) async {
    _logIncomingAttachmentDebug(
      'storeIncomingAttachment start',
      messageId: messageId,
      attachmentJson: attachmentJson,
    );
    final kind = _attachmentKindForLog(attachmentJson);
    final sizeBytes = _attachmentSizeForLog(attachmentJson);
    final androidLimitError = _androidAttachmentLimitError(
      kind: kind,
      sizeBytes: sizeBytes,
    );
    if (androidLimitError != null) {
      DiagnosticService.instance.log(
        'attachment android receive skipped messageId=$messageId '
        'kind=$kind fileSizeBytes=$sizeBytes reason=$androidLimitError',
      );
      _setAttachmentFailure(messageId, androidLimitError);
      return null;
    }
    late final String? base64Value;
    try {
      base64Value = await _attachmentPayloadBase64(
        attachmentJson,
        messageId: messageId,
      );
    } catch (error) {
      DiagnosticService.instance.log(
        'attachment stage=download failed messageId=$messageId '
        'kind=$kind fileSizeBytes=$sizeBytes error=$error',
      );
      _setAttachmentFailure(messageId, 'download failed: $error');
      return null;
    }
    if (base64Value == null || base64Value.isEmpty) {
      DiagnosticService.instance.log(
        "attachment receive payload missing messageId=$messageId "
        'hasBlobId=${(attachmentJson['blobId'] as String?)?.isNotEmpty == true} '
        "hasInlineBase64=${(attachmentJson['base64'] as String?)?.isNotEmpty == true}",
      );
      _setAttachmentFailure(messageId, 'download failed: payload missing');
      return null;
    }

    if (attachmentJson['encrypted'] == true) {
      late final DecryptedAttachmentData? decrypted;
      try {
        DiagnosticService.instance.log(
          'attachment stage=decrypt start messageId=$messageId '
          'kind=$kind fileSizeBytes=$sizeBytes',
        );
        _setAttachmentProgress(
          messageId,
          AttachmentTransferProgress(
            stage: AttachmentTransferStage.decrypting,
            transferredBytes: sizeBytes,
            totalBytes: sizeBytes > 0 ? sizeBytes : null,
          ),
        );
        if (_androidRuntime) {
          await Future<void>.delayed(Duration.zero);
        }
        decrypted = await CryptoService.instance.decryptAttachment(base64Value);
        if (decrypted != null) {
          _webFileLog(
            'decrypted name=${decrypted.name} size=${decrypted.bytes.length}',
          );
        }
      } catch (error) {
        _webFileLog('error reason=decrypt_failed');
        DiagnosticService.instance.log(
          'attachment stage=decrypt exception messageId=$messageId '
          'kind=$kind fileSizeBytes=$sizeBytes error=$error',
        );
        _setAttachmentFailure(messageId, 'decrypt exception: $error');
        return null;
      }
      if (decrypted == null) {
        DiagnosticService.instance.log(
          'attachment stage=decrypt failed messageId=$messageId '
          'kind=$kind fileSizeBytes=$sizeBytes '
          "name=${attachmentJson['originalName'] ?? attachmentJson['name'] ?? 'none'} "
          "extension=${attachmentJson['extension'] ?? 'none'}",
        );
        _setAttachmentFailure(messageId, 'decrypt failed: invalid payload');
        return null;
      }

      late final SavedAttachment saved;
      final originalName = (attachmentJson['originalName'] as String?) ??
          (attachmentJson['name'] as String?) ??
          decrypted.name;
      final saveName =
          originalName.trim().isEmpty ? decrypted.name : originalName;
      final normalizedKind =
          AttachmentPolicy.kindForFileName(saveName) ?? decrypted.kind;
      try {
        DiagnosticService.instance.log(
          'attachment stage=save start messageId=$messageId '
          'kind=$normalizedKind fileSizeBytes=${decrypted.bytes.length} '
          'name=$saveName decryptedName=${decrypted.name}',
        );
        _setAttachmentProgress(
          messageId,
          AttachmentTransferProgress(
            stage: AttachmentTransferStage.saving,
            transferredBytes: decrypted.bytes.length,
            totalBytes: decrypted.bytes.length,
          ),
        );
        saved = await LocalDataService.instance.saveBytesAsAttachment(
          messageId: messageId,
          fileName: saveName,
          bytes: decrypted.bytes,
        );
      } catch (error) {
        _webFileLog('error reason=save_failed');
        DiagnosticService.instance.log(
          'attachment stage=save failed messageId=$messageId '
          'kind=${decrypted.kind} fileSizeBytes=${decrypted.bytes.length} '
          'error=$error',
        );
        _setAttachmentFailure(messageId, 'file write failed: $error');
        return null;
      }
      return _StoredIncomingAttachment(
        attachment: saved.attachment.kind == normalizedKind
            ? saved.attachment
            : ChatAttachment(
                id: saved.attachment.id,
                name: saved.attachment.name,
                localPath: saved.attachment.localPath,
                sizeBytes: saved.attachment.sizeBytes,
                kind: normalizedKind,
              ),
        messageMetadata: decrypted.messageMetadata ?? const {},
      );
    }

    final name = attachmentJson['name'] as String? ?? 'attachment.bin';
    Uint8List bytes;
    try {
      DiagnosticService.instance.log(
        'attachment stage=decode start messageId=$messageId '
        'kind=$kind fileSizeBytes=$sizeBytes',
      );
      bytes = await compute(_decodeBase64AttachmentPayload, base64Value);
    } catch (error) {
      DiagnosticService.instance.log(
        'attachment stage=decode failed messageId=$messageId '
        'kind=$kind fileSizeBytes=$sizeBytes error=$error',
      );
      _setAttachmentFailure(messageId, 'decode failed: $error');
      return null;
    }

    late final SavedAttachment saved;
    try {
      DiagnosticService.instance.log(
        'attachment stage=save start messageId=$messageId '
        'kind=$kind fileSizeBytes=${bytes.length}',
      );
      saved = await LocalDataService.instance.saveBytesAsAttachment(
        messageId: messageId,
        fileName: name,
        bytes: bytes,
      );
    } catch (error) {
      DiagnosticService.instance.log(
        'attachment stage=save failed messageId=$messageId '
        'kind=$kind fileSizeBytes=${bytes.length} error=$error',
      );
      _setAttachmentFailure(messageId, 'file write failed: $error');
      return null;
    }
    return _StoredIncomingAttachment(
      attachment: saved.attachment,
      messageMetadata: const {},
    );
  }

  Future<String?> _attachmentPayloadBase64(
    Map<String, dynamic> attachmentJson, {
    required String messageId,
  }) async {
    final inline = attachmentJson['base64'] as String?;
    if (inline != null && inline.isNotEmpty) {
      DiagnosticService.instance.log(
        "attachment receive payload source=inline messageId=${attachmentJson['id'] ?? 'unknown'} "
        "hasBlobId=${(attachmentJson['blobId'] as String?)?.isNotEmpty == true}",
      );
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
      DiagnosticService.instance.log(
        "attachment receive blob unavailable blobId=${blobId ?? 'none'} "
        "hasProfile=${profile != null} hasAuthToken=${authToken?.isNotEmpty == true}",
      );
      return null;
    }
    for (final downloadUrl in AppConfig.downloadBlobUrls(blobId)) {
      DiagnosticService.instance.log(
        'attachment download url=${_redactQuery(downloadUrl)} blobId=$blobId',
      );
      late final http.Response response;
      try {
        DiagnosticService.instance.log(
          'attachment stage=download start blobId=$blobId '
          'kind=${_attachmentKindForLog(attachmentJson)} '
          'fileSizeBytes=${_attachmentSizeForLog(attachmentJson)}',
        );
        _webFileLog(
          'download started blobId=$blobId '
          'size=${_attachmentSizeForLog(attachmentJson)}',
        );
        response = await _downloadAttachmentResponse(
          Uri.parse(downloadUrl),
          messageId: messageId,
          blobId: blobId,
        ).timeout(const Duration(minutes: 10));
      } on TimeoutException {
        _webFileLog('error reason=download_timeout');
        DiagnosticService.instance.log(
          'attachment stage=download timeout blobId=$blobId',
        );
        return null;
      } catch (error) {
        _webFileLog('error reason=download_failed');
        DiagnosticService.instance.log(
          'attachment stage=download network error=$error blobId=$blobId',
        );
        return null;
      }
      DiagnosticService.instance.log(
        'attachment download status=${response.statusCode} blobId=$blobId '
        'message=${_serverErrorMessage(response.body) ?? ''}',
      );
      if (response.statusCode == 200) {
        _webFileLog(
          'download completed blobId=$blobId bytes=${response.body.length}',
        );
        return response.body;
      }
      if (response.statusCode != 404 && response.statusCode != 405) {
        if (kDebugMode) {
          debugPrint(
            '[ChatService] Attachment download failed: ${response.statusCode}',
          );
        }
        _setAttachmentFailure(
          messageId,
          'download failed: status ${response.statusCode} ${_serverErrorMessage(response.body) ?? ''}',
        );
        return null;
      }
    }
    _setAttachmentFailure(messageId, 'download failed: blob not found');
    return null;
  }

  Future<http.Response> _downloadAttachmentResponse(
    Uri uri, {
    required String messageId,
    required String blobId,
  }) async {
    final request = http.Request('GET', uri)
      ..headers.addAll(_blobAuthHeaders());
    final streamed = await request.send();
    final contentLength = streamed.contentLength;
    DiagnosticService.instance.log(
      'attachment download response start blobId=$blobId '
      'status=${streamed.statusCode} contentLength=$contentLength',
    );
    final builder = BytesBuilder(copy: false);
    var receivedBytes = 0;
    await for (final chunk in streamed.stream) {
      receivedBytes += chunk.length;
      builder.add(chunk);
      _setAttachmentProgress(
        messageId,
        AttachmentTransferProgress(
          stage: AttachmentTransferStage.downloading,
          transferredBytes: receivedBytes,
          totalBytes:
              contentLength != null && contentLength > 0 ? contentLength : null,
        ),
      );
      if (_androidRuntime && receivedBytes % (2 * 1024 * 1024) < chunk.length) {
        await Future<void>.delayed(Duration.zero);
      }
    }
    final bodyBytes = builder.takeBytes();
    DiagnosticService.instance.log(
      'attachment download response complete blobId=$blobId '
      'status=${streamed.statusCode} bytes=${bodyBytes.length}',
    );
    final body = await compute(_decodeUtf8Payload, bodyBytes);
    return http.Response(
      body,
      streamed.statusCode,
      headers: streamed.headers,
      request: streamed.request,
      reasonPhrase: streamed.reasonPhrase,
    );
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

  String _attachmentUploadError(http.Response response) {
    final message = _serverErrorMessage(response.body);
    if (response.statusCode == 0) return 'No server connection.';
    if (response.statusCode == 404 || response.statusCode == 405) {
      return 'Server does not support file uploads.';
    }
    if (response.statusCode == 400 &&
        message == 'Attachment type is not allowed.') {
      DiagnosticService.instance.log(
        'attachment upload failed reason=legacy_backend_policy_not_retried',
      );
      return 'Attachment upload failed.';
    }
    if (response.statusCode == 400 &&
        message == 'Attachment type is blocked for safety.') {
      return 'Attachment type is blocked for safety.';
    }
    if (response.statusCode == 400 &&
        message == 'Attachment validation failed.') {
      return 'Attachment validation failed.';
    }
    if (response.statusCode == 413 ||
        message == 'Attachment is too large.' ||
        (message != null && message.contains('storage is full'))) {
      return message ?? 'Attachment is too large.';
    }
    if (response.statusCode == 401 || response.statusCode == 403) {
      return message ?? 'Attachment upload failed.';
    }
    return message ?? 'Attachment upload failed.';
  }

  bool _canFallbackToInline(http.Response response) {
    final message = _serverErrorMessage(response.body);
    if (response.statusCode == 404 ||
        response.statusCode == 405 ||
        response.statusCode == 408 ||
        response.statusCode == 413 ||
        response.statusCode == 502 ||
        response.statusCode == 503 ||
        response.statusCode == 504) {
      return message == null ||
          message == 'Attachment upload failed.' ||
          response.statusCode == 404 ||
          response.statusCode == 405;
    }
    return false;
  }

  void _logIncomingMessageDebug(
    String label,
    Map<String, dynamic> messageJson,
  ) {
    final attachmentJson = messageJson['attachment'];
    final attachment = attachmentJson is Map
        ? Map<String, dynamic>.from(attachmentJson)
        : null;
    final fields = attachment == null
        ? const <String>[]
        : attachment.keys
            .where((key) => key != 'base64')
            .cast<String>()
            .toList();
    DiagnosticService.instance.log(
      "attachment debug $label messageId=${messageJson['id'] ?? 'none'} "
      "messageKeys=${messageJson.keys.join(',')} "
      "hasAttachment=${attachment != null} attachmentFields=${fields.join(',')} "
      "blobId=${attachment?['blobId'] ?? 'none'} "
      "name=${attachment?['originalName'] ?? attachment?['name'] ?? 'none'} "
      "kind=${attachment?['originalKind'] ?? attachment?['kind'] ?? 'none'} "
      "sizeBytes=${attachment?['originalSizeBytes'] ?? attachment?['sizeBytes'] ?? 0} "
      "encrypted=${attachment?['encrypted'] == true}",
    );
  }

  void _logIncomingAttachmentDebug(
    String label, {
    required String messageId,
    required Map<String, dynamic> attachmentJson,
  }) {
    final fields = attachmentJson.keys
        .where((key) => key != 'base64')
        .cast<String>()
        .toList();
    DiagnosticService.instance.log(
      'attachment debug $label messageId=$messageId '
      "attachmentFields=${fields.join(',')} "
      "hasInlineBase64=${(attachmentJson['base64'] as String?)?.isNotEmpty == true} "
      "blobId=${attachmentJson['blobId'] ?? 'none'} "
      "name=${attachmentJson['originalName'] ?? attachmentJson['name'] ?? 'none'} "
      "kind=${attachmentJson['originalKind'] ?? attachmentJson['kind'] ?? 'none'} "
      "sizeBytes=${attachmentJson['originalSizeBytes'] ?? attachmentJson['sizeBytes'] ?? 0} "
      "encrypted=${attachmentJson['encrypted'] == true}",
    );
  }

  String _attachmentKindForLog(Map<String, dynamic> attachmentJson) {
    return (attachmentJson['originalKind'] as String?) ??
        (attachmentJson['kind'] as String?) ??
        'unknown';
  }

  String? _androidAttachmentLimitError({
    required String kind,
    required int sizeBytes,
  }) {
    if (!_androidRuntime || sizeBytes <= 0) {
      return null;
    }
    if ({'video', 'audio'}.contains(kind) &&
        sizeBytes > _androidTemporaryLargeAttachmentMaxBytes) {
      return 'Large video/audio transfer on Android is temporarily limited to 100 MB.';
    }
    return null;
  }

  void _logAndroidAttachmentPolicy({
    required String label,
    required String name,
    required String extension,
    String? kind,
    required int sizeBytes,
  }) {
    if (!_androidRuntime) {
      return;
    }
    final resolvedKind = kind ?? AttachmentPolicy.kindForExtension(extension);
    DiagnosticService.instance.log(
      'attachment android $label name=$name ext=$extension '
      'kind=${resolvedKind ?? 'unknown'} sizeBytes=$sizeBytes '
      'policyMax=${resolvedKind == null ? 0 : AttachmentPolicy.maxBytesForKind(resolvedKind)} '
      'hardMax=${AttachmentPolicy.hardMaxBytes}',
    );
  }

  int _attachmentSizeForLog(Map<String, dynamic> attachmentJson) {
    final raw =
        attachmentJson['originalSizeBytes'] ?? attachmentJson['sizeBytes'];
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return int.tryParse('$raw') ?? 0;
  }

  DateTime? _messageDateTime(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value == null) return null;
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is num) {
      return DateTime.fromMillisecondsSinceEpoch(value.toInt());
    }
    if (value is String) {
      final millis = int.tryParse(value);
      if (millis != null) return DateTime.fromMillisecondsSinceEpoch(millis);
      return DateTime.tryParse(value);
    }
    return null;
  }

  int _callTimestampMs(Map<String, dynamic> json) {
    final value =
        json['serverTimestamp'] ?? json['callCreatedAt'] ?? json['timestamp'];
    if (value is int) return _normalizeTimestampMs(value);
    if (value is num) return _normalizeTimestampMs(value.toInt());
    if (value is String) {
      final millis = int.tryParse(value);
      if (millis != null) return _normalizeTimestampMs(millis);
      return DateTime.tryParse(value)?.millisecondsSinceEpoch ??
          DateTime.now().millisecondsSinceEpoch;
    }
    return DateTime.now().millisecondsSinceEpoch;
  }

  Future<String> _microphonePermissionStatusForLog() async {
    try {
      return (await Permission.microphone.status).name;
    } catch (error) {
      return 'unknown:$error';
    }
  }

  int _normalizeTimestampMs(int value) {
    return value > 0 && value < 100000000000 ? value * 1000 : value;
  }

  int _positiveInt(Object? value, int fallback) {
    final parsed = value is num ? value.toInt() : int.tryParse('$value');
    return parsed != null && parsed > 0 ? parsed : fallback;
  }

  int? _messageInt(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  void _logMessageSortDebug(
    ChatMessage message, {
    required String direction,
  }) {
    DiagnosticService.instance.log(
      'message sort id=${message.id} direction=$direction '
      'clientTimestamp=${message.clientTimestamp?.millisecondsSinceEpoch ?? 0} '
      'serverTimestamp=${message.serverTimestamp?.millisecondsSinceEpoch ?? 0} '
      'receivedAt=${message.receivedAt?.millisecondsSinceEpoch ?? 0} '
      'localCreatedAt=${message.localCreatedAt?.millisecondsSinceEpoch ?? 0} '
      'deliveredAt=${message.deliveredAt?.millisecondsSinceEpoch ?? 0} '
      'serverSequence=${message.serverSequence ?? 0} '
      'sortPrimary=${message.primarySortMillis} '
      'sortSecondary=${message.secondarySortMillis}',
    );
  }

  String _redactQuery(String value) {
    try {
      final uri = Uri.parse(value);
      return uri.replace(query: '').toString();
    } catch (_) {
      return value.split('?').first;
    }
  }

  String _platformName() {
    if (kIsWeb) return 'web';
    return Platform.operatingSystem;
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
    _logMessageSortDebug(message,
        direction: message.isMe ? 'outgoing' : 'incoming');
    notifyListeners();
  }

  bool _hasMessage(String conversationId, String messageId) {
    final conversation = _conversations[conversationId];
    if (conversation == null) {
      return false;
    }
    return conversation.messages.any((message) => message.id == messageId);
  }

  ChatMessage? _messageById(String conversationId, String messageId) {
    final conversation = _conversations[conversationId];
    if (conversation == null) {
      return null;
    }
    for (final message in conversation.messages) {
      if (message.id == messageId) {
        return message;
      }
    }
    return null;
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
      nextMessages.sort(ChatMessage.compareForDisplay);
      _conversations[entry.key] = entry.value.copyWith(messages: nextMessages);
      await LocalDataService.instance.saveConversations(_storedConversations);
      if (current.attachment != null) {
        if (status == MessageDeliveryStatus.failed) {
          _attachmentProgress[messageId] = const AttachmentTransferProgress(
              stage: AttachmentTransferStage.failed);
        } else if (status == MessageDeliveryStatus.sent ||
            status == MessageDeliveryStatus.delivered) {
          _attachmentProgress[messageId] = AttachmentTransferProgress(
            stage: current.isMe
                ? AttachmentTransferStage.sent
                : AttachmentTransferStage.received,
            transferredBytes: current.attachment!.sizeBytes,
            totalBytes: current.attachment!.sizeBytes,
          );
        }
      }
      notifyListeners();
      return;
    }
  }

  void _setAttachmentProgress(
    String messageId,
    AttachmentTransferProgress progress,
  ) {
    if (messageId.isEmpty) {
      return;
    }
    final previous = _attachmentProgress[messageId];
    if (previous != null &&
        previous.stage == progress.stage &&
        previous.transferredBytes == progress.transferredBytes &&
        previous.totalBytes == progress.totalBytes &&
        previous.error == progress.error) {
      return;
    }
    _attachmentProgress[messageId] = progress;
    notifyListeners();
  }

  void _setAttachmentFailure(String messageId, String reason) {
    _setAttachmentProgress(
      messageId,
      AttachmentTransferProgress(
        stage: AttachmentTransferStage.failed,
        error: reason,
      ),
    );
    DiagnosticService.instance.log(
      'attachment failure messageId=$messageId reason=$reason',
    );
  }

  void _failAttachmentProgressIfMissing(String messageId, String fallback) {
    final current = _attachmentProgress[messageId];
    if (current?.stage == AttachmentTransferStage.failed) {
      return;
    }
    _setAttachmentFailure(messageId, fallback);
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
      message.copyWith(
        status: status,
        deliveredAt: status == MessageDeliveryStatus.delivered
            ? message.deliveredAt ?? DateTime.now()
            : message.deliveredAt,
      );

  Future<void> _applyServerMessageUpdate(
    Map<String, dynamic> messageJson, {
    required MessageDeliveryStatus status,
    required String direction,
  }) async {
    final messageId = messageJson['id'] as String? ?? '';
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
      final serverTimestamp =
          _messageDateTime(messageJson, 'serverReceivedAt') ??
              _messageDateTime(messageJson, 'serverTimestamp') ??
              current.serverTimestamp;
      final clientTimestamp =
          _messageDateTime(messageJson, 'clientCreatedAt') ??
              _messageDateTime(messageJson, 'clientTimestamp') ??
              current.clientTimestamp;
      final timestamp =
          _messageDateTime(messageJson, 'timestamp') ?? current.timestamp;
      final updated = current.copyWith(
        status: current.isMe ? status : current.status,
        timestamp: timestamp,
        clientTimestamp: clientTimestamp,
        serverTimestamp: serverTimestamp,
        serverSequence: _messageInt(messageJson, 'serverSequence') ??
            current.serverSequence,
        receivedAt: current.receivedAt ?? DateTime.now(),
        deliveredAt: status == MessageDeliveryStatus.delivered
            ? DateTime.now()
            : current.deliveredAt,
      );
      final nextMessages = [...messages];
      nextMessages[index] = updated;
      nextMessages.sort(ChatMessage.compareForDisplay);
      _conversations[entry.key] = entry.value.copyWith(messages: nextMessages);
      await LocalDataService.instance.saveConversations(_storedConversations);
      _logMessageSortDebug(updated, direction: direction);
      notifyListeners();
      return;
    }
  }

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

  String _contactStatusSummary(String peerUserId) {
    if (peerUserId.isEmpty) {
      return 'peer_empty';
    }
    final matches =
        _contacts.where((item) => item.peerUserId == peerUserId).toList();
    if (matches.isEmpty) {
      return 'none';
    }
    return matches
        .map((item) => '${item.status.name}:${_shortId(item.peerUserId)}')
        .join(',');
  }

  String _blockStatusSummary(String peerUserId) {
    if (peerUserId.isEmpty) {
      return 'peer_empty';
    }
    final blockListBlocked =
        _blockList.any((item) => item.blockedUserId == peerUserId);
    final contactBlocked = _contacts.any((item) =>
        item.peerUserId == peerUserId && item.status == ContactStatus.blocked);
    return 'blockList=$blockListBlocked contactBlocked=$contactBlocked';
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
    await _startupStep(
      'saveProfile',
      () => StorageService.instance.saveProfile(user),
    );
    await _startupStep(
      'localData.init',
      () => LocalDataService.instance.init(user.userId),
    );
    final storedConversations = await _startupLoad(
      'loadConversations',
      LocalDataService.instance.loadConversations,
      <Conversation>[],
    );
    final storedContacts = await _startupLoad(
      'loadContacts',
      LocalDataService.instance.loadContacts,
      <Contact>[],
    );
    final storedRequests = await _startupLoad(
      'loadContactRequests',
      LocalDataService.instance.loadContactRequests,
      <ContactRequest>[],
    );
    final storedBlockList = await _startupLoad(
      'loadBlockList',
      LocalDataService.instance.loadBlockList,
      <BlockListEntry>[],
    );
    final storedPrivacy = await _startupLoad(
      'loadPrivacySettings',
      LocalDataService.instance.loadPrivacySettings,
      const PrivacySettings(),
    );
    final storedUnreadCounts = await _startupLoad(
      'loadUnreadCounts',
      LocalDataService.instance.loadUnreadCounts,
      <String, int>{},
    );
    final storedUnreadContactRequestIds = await _startupLoad(
      'loadUnreadContactRequestIds',
      LocalDataService.instance.loadUnreadContactRequestIds,
      <String>{},
    );
    final storedChatSettings = await _startupLoad(
      'loadChatSettings',
      LocalDataService.instance.loadChatSettings,
      <ChatLocalSettings>[],
    );

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
    final restoredConversations =
        _failStaleSendingMessages(storedConversations);
    if (!identical(restoredConversations, storedConversations)) {
      unawaited(
        LocalDataService.instance.saveConversations(restoredConversations),
      );
    }
    _replaceConversations(restoredConversations);
    notifyListeners();
  }

  void _clearRuntimeUserState() {
    profile = null;
    _authCompleter = null;
    _conversations.clear();
    _users.clear();
    _contacts.clear();
    _contactRequests.clear();
    _blockList.clear();
    _sessions.clear();
    _chatSettings.clear();
    _unreadCounts.clear();
    _unreadContactRequestIds.clear();
    _privacySettings = const PrivacySettings();
    _lastSearchResult = null;
    _lastUsernameSearchRequest = 'none';
    _lastUsernameSearchResult = 'none';
  }

  List<Conversation> _failStaleSendingMessages(
    List<Conversation> conversations,
  ) {
    var changed = false;
    final next = conversations.map((conversation) {
      var conversationChanged = false;
      final messages = conversation.messages.map((message) {
        if (message.isMe && message.status == MessageDeliveryStatus.sending) {
          changed = true;
          conversationChanged = true;
          return message.copyWith(status: MessageDeliveryStatus.failed);
        }
        return message;
      }).toList()
        ..sort(ChatMessage.compareForDisplay);
      return conversationChanged
          ? conversation.copyWith(messages: messages)
          : conversation;
    }).toList();
    return changed ? next : conversations;
  }

  Future<void> _startupStep(
    String label,
    Future<void> Function() action,
  ) async {
    DiagnosticService.instance.log('startup local begin $label');
    try {
      await action();
      DiagnosticService.instance.log('startup local ok $label');
    } catch (error) {
      DiagnosticService.instance
          .log('startup local failed $label error=$error');
    }
  }

  Future<T> _startupLoad<T>(
    String label,
    Future<T> Function() action,
    T fallback,
  ) async {
    DiagnosticService.instance.log('startup local begin $label');
    try {
      final value = await action();
      DiagnosticService.instance.log('startup local ok $label');
      return value;
    } catch (error) {
      DiagnosticService.instance
          .log('startup local failed $label error=$error');
      return fallback;
    }
  }

  Future<void> _ensureLocalStorageReady(UserProfile user) async {
    if (!LocalDataService.instance.isInitialized ||
        LocalDataService.instance.userId != user.userId) {
      await LocalDataService.instance.init(user.userId);
    }
  }

  void _setConnectionStatus(ServerConnectionStatus status) {
    _connectionStatus = status;
    _isConnected = status == ServerConnectionStatus.connected;
    if (_isConnected) {
      _socketFailureReported = false;
      _reconnectTimer?.cancel();
      _reconnectTimer = null;
    }
    DiagnosticService.instance.log(
      'websocket status=${status.name} ${AppConfig.wsUrl}',
    );
    notifyListeners();
  }

  void _logConnection(String message) {
    DiagnosticService.instance.log('websocket $message');
    if (kDebugMode) {
      debugPrint('[ChatService] websocket $message');
    }
  }

  void _send(Map<String, dynamic> obj) {
    final type = obj['type']?.toString() ?? 'unknown';
    if (type == 'message') {
      DiagnosticService.instance.log(
        'outgoing message id=${obj['id'] ?? 'none'} '
        'toUserId=${_shortId(obj['toUserId']?.toString() ?? '')} '
        'socketState=${_connectionStatus.name}',
      );
    }
    if (type == 'find_user_by_username_exact') {
      DiagnosticService.instance.log(
        'websocket sent $type usernameLength=${obj['username']?.toString().length ?? 0}',
      );
    }
    if (type.startsWith('call_') || type == 'get_call_offer') {
      DiagnosticService.instance.log(
        'websocket sent $type callId=${_shortId(obj['callId']?.toString() ?? '')} '
        'toUserId=${_shortId(obj['toUserId']?.toString() ?? '')} '
        'socketState=${_connectionStatus.name}',
      );
    }
    if (_channel == null) {
      throw StateError('WebSocket is not connected.');
    }
    _channel!.sink.add(jsonEncode(obj));
  }

  void _recordBackgroundWsEvent(String type) {
    final lifecycle = CallService.instance.appLifecycleState;
    final background = lifecycle == 'inactive' ||
        lifecycle == 'paused' ||
        lifecycle == 'detached' ||
        lifecycle == 'hidden';
    if (!background) {
      return;
    }
    _lastBackgroundWsEventType = type;
    _lastBackgroundWsEventAt = DateTime.now().toUtc();
    DiagnosticService.instance.log(
      'websocket background event type=$type lifecycle=$lifecycle',
    );
  }

  bool get _foregroundServiceDiagnosticsActive =>
      FirebasePushService.instance.foregroundServiceActive;

  void _foregroundServiceLog(String message) {
    DiagnosticService.instance.log('HestiaFgService $message');
  }

  void _recordForegroundServiceSocketConnecting() {
    if (!_foregroundServiceDiagnosticsActive) {
      return;
    }
    _foregroundServiceStartedAt ??= DateTime.now().toUtc();
    _foregroundServiceConnectingAt = DateTime.now().toUtc();
    _foregroundServiceSocketState = 'connecting';
    _foregroundServiceLog('WebSocket connecting target=${AppConfig.wsUrl}');
  }

  void _recordForegroundServiceSocketConnected() {
    if (!_foregroundServiceDiagnosticsActive) {
      return;
    }
    _foregroundServiceConnectedAt = DateTime.now().toUtc();
    _foregroundServiceSocketState = 'connected_waiting_auth';
    _foregroundServiceLog(
      'websocket open mainSocketConnected=$_isConnected '
      'foregroundServiceActive=${FirebasePushService.instance.foregroundServiceActive} '
      'sameProcessSocket=true',
    );
  }

  void _recordForegroundServiceAuthSent(String deviceId) {
    if (!_foregroundServiceDiagnosticsActive) {
      return;
    }
    _foregroundServiceAuthSentAt = DateTime.now().toUtc();
    _foregroundServiceActiveDeviceId = _shortId(deviceId);
    _foregroundServiceLog(
      'auth sent userId=${_shortId(profile?.userId ?? '')} '
      'deviceId=$_foregroundServiceActiveDeviceId',
    );
  }

  void _recordForegroundServiceAuthOk(UserProfile user) {
    if (!_foregroundServiceDiagnosticsActive) {
      return;
    }
    _foregroundServiceAuthOkAt = DateTime.now().toUtc();
    _foregroundServiceActiveUserId = _shortId(user.userId);
    _foregroundServiceSocketState = 'authenticated';
    _foregroundServiceLog(
      'auth_ok received userId=$_foregroundServiceActiveUserId '
      'deviceId=$_foregroundServiceActiveDeviceId '
      'mainSocketConnected=$_isConnected sameProcessSocket=true',
    );
  }

  void _recordForegroundServiceIncomingFrame(Map<String, dynamic> json) {
    if (!_foregroundServiceDiagnosticsActive) {
      return;
    }
    final type = json['type'] as String? ?? '';
    final diagnosticType = type == 'call_offer' && json['sdp'] is! String
        ? 'call_offer_init'
        : type;
    if (type != 'new_message' && type != 'call_offer_init') {
      if (diagnosticType != 'call_offer_init') {
        return;
      }
    }
    if (diagnosticType != 'new_message' &&
        diagnosticType != 'call_offer_init') {
      return;
    }
    _foregroundServiceLastIncomingFrameType = diagnosticType;
    _foregroundServiceLastIncomingFrameAt = DateTime.now().toUtc();
    _foregroundServiceLog(
      'incoming frame type=$diagnosticType rawType=$type '
      'mainSocketConnected=$_isConnected sameProcessSocket=true',
    );
  }

  void _recordForegroundServiceNotificationShown(String type) {
    if (!_foregroundServiceDiagnosticsActive) {
      return;
    }
    _foregroundServiceLastNotificationType = type;
    _foregroundServiceLastNotificationAt = DateTime.now().toUtc();
    _foregroundServiceLog('local notification shown type=$type');
  }

  void _recordForegroundServiceSocketClosed(String reason) {
    if (!_foregroundServiceDiagnosticsActive) {
      return;
    }
    _foregroundServiceLastSocketClosedAt = DateTime.now().toUtc();
    _foregroundServiceSocketState = 'closed';
    _foregroundServiceLog('socket closed reason=$reason');
  }

  void _recordForegroundServiceSocketError(Object error) {
    if (!_foregroundServiceDiagnosticsActive) {
      return;
    }
    _foregroundServiceLastSocketError = error.toString();
    _foregroundServiceSocketState = 'error';
    _foregroundServiceLog('socket error=$_foregroundServiceLastSocketError');
  }

  void _recordForegroundServiceReconnect(String reason) {
    if (!_foregroundServiceDiagnosticsActive) {
      return;
    }
    _foregroundServiceLastReconnectAt = DateTime.now().toUtc();
    _foregroundServiceLog('socket reconnect $reason');
  }

  Future<void> _ensureWakeupAfterAuthAndRecord(UserProfile user) async {
    await FirebasePushService.instance.ensureWakeupAfterAuth(
      foregroundSocketConfig: await _foregroundSocketConfig(user),
    );
    if (!_foregroundServiceDiagnosticsActive) {
      return;
    }
    final now = DateTime.now().toUtc();
    _foregroundServiceStartedAt ??= now;
    _foregroundServiceActiveUserId = _shortId(user.userId);
    _foregroundServiceActiveDeviceId =
        _shortId(await StorageService.instance.loadOrCreateDeviceId());
    _foregroundServiceLog(
      'started yes activeUserId=$_foregroundServiceActiveUserId '
      'deviceId=$_foregroundServiceActiveDeviceId',
    );
    if (_isConnected) {
      _foregroundServiceConnectedAt ??= now;
      _foregroundServiceAuthSentAt ??= now;
      _foregroundServiceAuthOkAt ??= now;
      _foregroundServiceSocketState = 'authenticated';
      _foregroundServiceLog('WebSocket connected existing=true');
      _foregroundServiceLog(
        'auth sent existing=true userId=$_foregroundServiceActiveUserId '
        'deviceId=$_foregroundServiceActiveDeviceId '
        'mainSocketConnected=$_isConnected sameProcessSocket=true',
      );
      _foregroundServiceLog(
        'auth_ok received existing=true userId=$_foregroundServiceActiveUserId '
        'deviceId=$_foregroundServiceActiveDeviceId '
        'mainSocketConnected=$_isConnected sameProcessSocket=true',
      );
    }
    notifyListeners();
  }

  String _diagnosticDate(DateTime? value) => value?.toIso8601String() ?? 'none';

  Future<Map<String, String>> _foregroundSocketConfig(UserProfile user) async {
    final deviceId = await StorageService.instance.loadOrCreateDeviceId();
    final package = await PackageInfo.fromPlatform();
    return {
      'wsUrl': AppConfig.wsUrl,
      'userId': user.userId,
      'nickname': user.nickname,
      'authToken': user.authToken ?? '',
      'publicKey': user.publicKey ?? '',
      'deviceId': deviceId,
      'appVersion': '${package.version}+${package.buildNumber}',
    };
  }

  SessionInfo? _currentSessionInfo() {
    for (final session in _sessions) {
      if (session.current) {
        return session;
      }
    }
    return null;
  }

  Future<String> diagnosticReport() async {
    final currentSession = _currentSessionInfo();
    final deviceId = await StorageService.instance.loadOrCreateDeviceId();
    final call = CallService.instance;
    final lines = <String>[
      'Hestia diagnostics',
      'generatedAt: ${DateTime.now().toIso8601String()}',
      'diagnosticMode: ${DiagnosticService.instance.enabled}',
      'serverInput: ${AppConfig.serverInput}',
      'serverUrl: ${AppConfig.wsUrl}',
      'httpUrl: ${AppConfig.httpUrl}',
      'websocket: ${_connectionStatus.name}',
      'foregroundServiceStarted: ${FirebasePushService.instance.foregroundServiceActive}',
      'foregroundServiceSocketState: $_foregroundServiceSocketState',
      'foregroundServiceWebSocketConnected: ${FirebasePushService.instance.foregroundServiceActive && _isConnected}',
      'foregroundServiceStartedAt: ${_diagnosticDate(_foregroundServiceStartedAt)}',
      'foregroundServiceWebSocketConnectingAt: ${_diagnosticDate(_foregroundServiceConnectingAt)}',
      'foregroundServiceWebSocketConnectedAt: ${_diagnosticDate(_foregroundServiceConnectedAt)}',
      'foregroundServiceAuthSentAt: ${_diagnosticDate(_foregroundServiceAuthSentAt)}',
      'foregroundServiceAuthOkAt: ${_diagnosticDate(_foregroundServiceAuthOkAt)}',
      'foregroundServiceActiveUserId: $_foregroundServiceActiveUserId',
      'foregroundServiceActiveDeviceId: $_foregroundServiceActiveDeviceId',
      'foregroundServiceLastIncomingFrame: $_foregroundServiceLastIncomingFrameType ${_diagnosticDate(_foregroundServiceLastIncomingFrameAt)}',
      'foregroundServiceLastNotificationShown: $_foregroundServiceLastNotificationType ${_diagnosticDate(_foregroundServiceLastNotificationAt)}',
      'foregroundServiceLastSocketClosedAt: ${_diagnosticDate(_foregroundServiceLastSocketClosedAt)}',
      'foregroundServiceLastSocketError: $_foregroundServiceLastSocketError',
      'foregroundServiceLastReconnectAt: ${_diagnosticDate(_foregroundServiceLastReconnectAt)}',
      'appLifecycleState: ${call.appLifecycleState}',
      'lastIncomingWsEventWhileBackgrounded: $_lastBackgroundWsEventType ${_lastBackgroundWsEventAt?.toIso8601String() ?? 'none'}',
      'authenticatedUserId: ${_shortId(profile?.userId ?? '')}',
      'sessionId: ${_shortId(currentSession?.id ?? '')}',
      'deviceId: ${_shortId(currentSession?.deviceId ?? deviceId)}',
      'pushEnabled: ${currentSession?.pushEnabled ?? false}',
      'pushProvider: ${currentSession?.pushProvider ?? 'none'}',
      ...FirebasePushService.instance.diagnosticLines,
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

class _AsyncSemaphore {
  _AsyncSemaphore(this.maxConcurrent);

  final int maxConcurrent;
  int _running = 0;
  final List<Completer<void>> _waiters = [];

  Future<T> run<T>(Future<T> Function() action) async {
    await _acquire();
    try {
      return await action();
    } finally {
      _release();
    }
  }

  Future<void> _acquire() {
    if (_running < maxConcurrent) {
      _running += 1;
      return Future.value();
    }
    final completer = Completer<void>();
    _waiters.add(completer);
    return completer.future;
  }

  void _release() {
    if (_waiters.isNotEmpty) {
      final next = _waiters.removeAt(0);
      next.complete();
      return;
    }
    _running -= 1;
  }
}

Uint8List _decodeBase64AttachmentPayload(String value) {
  return base64Decode(value);
}

Uint8List _readFileBytesWorker(String path) {
  return File(path).readAsBytesSync();
}

String _decodeUtf8Payload(Uint8List value) {
  return utf8.decode(value);
}

class _AttachmentBlobUploadException implements Exception {
  final String message;
  final bool allowInlineFallback;

  const _AttachmentBlobUploadException(
    this.message, {
    required this.allowInlineFallback,
  });

  @override
  String toString() => message;
}

class _AttachmentUploadMetadata {
  final String extension;
  final String kind;
  final bool compatibility;

  const _AttachmentUploadMetadata({
    required this.extension,
    required this.kind,
    required this.compatibility,
  });
}
