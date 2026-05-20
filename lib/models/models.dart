class UserProfile {
  final String userId;
  final String nickname;
  final String? authToken;
  final String? publicKey;

  const UserProfile({
    required this.userId,
    required this.nickname,
    this.authToken,
    this.publicKey,
  });

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'nickname': nickname,
        if (authToken != null) 'authToken': authToken,
        if (publicKey != null) 'publicKey': publicKey,
      };

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        userId: json['userId'] as String,
        nickname: json['nickname'] as String,
        authToken: json['authToken'] as String?,
        publicKey: json['publicKey'] as String?,
      );
}

class UserContact {
  final String userId;
  final String nickname;
  final bool online;
  final String? publicKey;

  const UserContact({
    required this.userId,
    required this.nickname,
    required this.online,
    this.publicKey,
  });

  factory UserContact.fromJson(Map<String, dynamic> json) => UserContact(
        userId: json['userId'] as String,
        nickname: json['nickname'] as String,
        online: json['online'] as bool? ?? false,
        publicKey: json['publicKey'] as String?,
      );
}

enum PeerKeyTrustState {
  missing,
  untrusted,
  verified,
  changed,
}

class PeerKeyInfo {
  final String userId;
  final String nickname;
  final String? publicKey;
  final String? fingerprint;
  final PeerKeyTrustState state;

  const PeerKeyInfo({
    required this.userId,
    required this.nickname,
    required this.publicKey,
    required this.fingerprint,
    required this.state,
  });

  bool get canSend =>
      state == PeerKeyTrustState.untrusted ||
      state == PeerKeyTrustState.verified;
}

class SessionInfo {
  final String id;
  final String deviceId;
  final String deviceName;
  final String platform;
  final String? pushProvider;
  final String? appVersion;
  final DateTime? createdAt;
  final DateTime? lastActiveAt;
  final DateTime? lastSeenAt;
  final DateTime? pushTokenUpdatedAt;
  final bool current;
  final bool pushEnabled;

  const SessionInfo({
    required this.id,
    required this.deviceId,
    required this.deviceName,
    required this.platform,
    required this.current,
    this.pushProvider,
    this.appVersion,
    this.createdAt,
    this.lastActiveAt,
    this.lastSeenAt,
    this.pushTokenUpdatedAt,
    this.pushEnabled = false,
  });

  factory SessionInfo.fromJson(Map<String, dynamic> json) => SessionInfo(
        id: json['id'] as String,
        deviceId: json['deviceId'] as String? ?? '',
        deviceName: json['deviceName'] as String? ?? 'Unknown device',
        platform: json['platform'] as String? ?? 'unknown',
        pushProvider: json['pushProvider'] as String?,
        appVersion: json['appVersion'] as String?,
        current: json['current'] as bool? ?? false,
        pushEnabled: json['pushEnabled'] as bool? ?? false,
        createdAt: json['createdAt'] == null
            ? null
            : DateTime.tryParse(json['createdAt'] as String),
        lastActiveAt: json['lastActiveAt'] == null
            ? null
            : DateTime.tryParse(json['lastActiveAt'] as String),
        lastSeenAt: json['lastSeenAt'] == null
            ? null
            : DateTime.tryParse(json['lastSeenAt'] as String),
        pushTokenUpdatedAt: json['pushTokenUpdatedAt'] == null
            ? null
            : DateTime.tryParse(json['pushTokenUpdatedAt'] as String),
      );
}

enum ContactStatus { active, blocked }

class Contact {
  final String id;
  final String userId;
  final String peerUserId;
  final String username;
  final DateTime createdAt;
  final ContactStatus status;
  final DateTime? lastInteractionAt;

  const Contact({
    required this.id,
    required this.userId,
    required this.peerUserId,
    required this.username,
    required this.createdAt,
    required this.status,
    this.lastInteractionAt,
  });

  factory Contact.fromJson(Map<String, dynamic> json) => Contact(
        id: json['id'] as String,
        userId: json['userId'] as String,
        peerUserId: json['peerUserId'] as String,
        username: json['username'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
        status: ContactStatus.values.firstWhere(
          (item) => item.name == (json['status'] as String? ?? 'active'),
          orElse: () => ContactStatus.active,
        ),
        lastInteractionAt: json['lastInteractionAt'] == null
            ? null
            : DateTime.parse(json['lastInteractionAt'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'peerUserId': peerUserId,
        'username': username,
        'createdAt': createdAt.toIso8601String(),
        'status': status.name,
        if (lastInteractionAt != null)
          'lastInteractionAt': lastInteractionAt!.toIso8601String(),
      };

  Contact copyWith({
    String? username,
    ContactStatus? status,
    DateTime? lastInteractionAt,
  }) =>
      Contact(
        id: id,
        userId: userId,
        peerUserId: peerUserId,
        username: username ?? this.username,
        createdAt: createdAt,
        status: status ?? this.status,
        lastInteractionAt: lastInteractionAt ?? this.lastInteractionAt,
      );
}

enum ContactRequestStatus { pending, accepted, declined }

class ContactRequest {
  final String id;
  final String fromUserId;
  final String toUserId;
  final String fromUsername;
  final ContactRequestStatus status;
  final DateTime createdAt;

  const ContactRequest({
    required this.id,
    required this.fromUserId,
    required this.toUserId,
    required this.fromUsername,
    required this.status,
    required this.createdAt,
  });

  factory ContactRequest.fromJson(Map<String, dynamic> json) => ContactRequest(
        id: json['id'] as String,
        fromUserId: json['fromUserId'] as String,
        toUserId: json['toUserId'] as String,
        fromUsername: json['fromUsername'] as String? ?? '',
        status: ContactRequestStatus.values.firstWhere(
          (item) => item.name == (json['status'] as String? ?? 'pending'),
          orElse: () => ContactRequestStatus.pending,
        ),
        createdAt: DateTime.parse(json['createdAt'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'fromUserId': fromUserId,
        'toUserId': toUserId,
        'fromUsername': fromUsername,
        'status': status.name,
        'createdAt': createdAt.toIso8601String(),
      };
}

class BlockListEntry {
  final String id;
  final String userId;
  final String blockedUserId;
  final DateTime createdAt;

  const BlockListEntry({
    required this.id,
    required this.userId,
    required this.blockedUserId,
    required this.createdAt,
  });

  factory BlockListEntry.fromJson(Map<String, dynamic> json) => BlockListEntry(
        id: json['id'] as String,
        userId: json['userId'] as String,
        blockedUserId: json['blockedUserId'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'blockedUserId': blockedUserId,
        'createdAt': createdAt.toIso8601String(),
      };
}

enum PrivacyAllowFrom { contacts, everyone }

class PrivacySettings {
  final bool allowUserDiscovery;
  final PrivacyAllowFrom allowMessagesFrom;
  final PrivacyAllowFrom allowCallsFrom;

  const PrivacySettings({
    this.allowUserDiscovery = true,
    this.allowMessagesFrom = PrivacyAllowFrom.contacts,
    this.allowCallsFrom = PrivacyAllowFrom.contacts,
  });

  factory PrivacySettings.fromJson(Map<String, dynamic> json) =>
      PrivacySettings(
        allowUserDiscovery: json['allowUserDiscovery'] as bool? ?? true,
        allowMessagesFrom: PrivacyAllowFrom.values.firstWhere(
          (item) =>
              item.name == (json['allowMessagesFrom'] as String? ?? 'contacts'),
          orElse: () => PrivacyAllowFrom.contacts,
        ),
        allowCallsFrom: PrivacyAllowFrom.values.firstWhere(
          (item) =>
              item.name == (json['allowCallsFrom'] as String? ?? 'contacts'),
          orElse: () => PrivacyAllowFrom.contacts,
        ),
      );

  Map<String, dynamic> toJson() => {
        'allowUserDiscovery': allowUserDiscovery,
        'allowMessagesFrom': allowMessagesFrom.name,
        'allowCallsFrom': allowCallsFrom.name,
      };
}

class ChatAttachment {
  final String id;
  final String name;
  final String localPath;
  final int sizeBytes;
  final String kind;

  const ChatAttachment({
    required this.id,
    required this.name,
    required this.localPath,
    required this.sizeBytes,
    required this.kind,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'localPath': localPath,
        'sizeBytes': sizeBytes,
        'kind': kind,
      };

  factory ChatAttachment.fromJson(Map<String, dynamic> json) => ChatAttachment(
        id: json['id'] as String,
        name: json['name'] as String,
        localPath: json['localPath'] as String,
        sizeBytes: json['sizeBytes'] as int? ?? 0,
        kind: json['kind'] as String? ??
            _inferAttachmentKind(json['name'] as String? ?? ''),
      );

  bool get isImage => kind == 'image';
  bool get isVideo => kind == 'video';
  bool get isAudio => kind == 'audio';
  bool get isArchive => kind == 'archive';
  bool get isEbook => kind == 'ebook';
  bool get isDocument => kind == 'document' || isArchive || isEbook;
}

enum MessageDeliveryStatus { sending, sent, delivered, failed }

enum ReplyPreviewType { text, image, video, audio, document, unknown }

enum ChatMessageType { text, call }

enum CallDirection { incoming, outgoing }

enum CallStatus {
  outgoingRinging,
  incomingRinging,
  rejectedByRecipient,
  canceledByCaller,
  missed,
  connected,
  completed,
  failedTimeout,
  failedNetwork,
}

class ChatMessage {
  final String id;
  final String conversationId;
  final String peerUserId;
  final String fromUserId;
  final String fromNickname;
  final String text;
  final DateTime timestamp;
  final DateTime? clientTimestamp;
  final DateTime? serverTimestamp;
  final DateTime? deliveredAt;
  final DateTime? receivedAt;
  final DateTime? localCreatedAt;
  final int? serverSequence;
  final bool isMe;
  final ChatAttachment? attachment;
  final MessageDeliveryStatus status;
  final String? replyToMessageId;
  final String? replyToSenderId;
  final String? replyToSenderName;
  final String? replyPreviewText;
  final ReplyPreviewType? replyPreviewType;
  final bool isForwarded;
  final String? forwardedFromSenderId;
  final String? forwardedFromSenderName;
  final String? forwardedFromMessageId;
  final ChatMessageType type;
  final String? callId;
  final CallDirection? callDirection;
  final CallStatus? callStatus;
  final bool isVideoCall;
  final int? callDurationSeconds;

  const ChatMessage({
    required this.id,
    required this.conversationId,
    required this.peerUserId,
    required this.fromUserId,
    required this.fromNickname,
    required this.text,
    required this.timestamp,
    required this.isMe,
    this.clientTimestamp,
    this.serverTimestamp,
    this.deliveredAt,
    this.receivedAt,
    this.localCreatedAt,
    this.serverSequence,
    this.attachment,
    this.status = MessageDeliveryStatus.delivered,
    this.replyToMessageId,
    this.replyToSenderId,
    this.replyToSenderName,
    this.replyPreviewText,
    this.replyPreviewType,
    this.isForwarded = false,
    this.forwardedFromSenderId,
    this.forwardedFromSenderName,
    this.forwardedFromMessageId,
    this.type = ChatMessageType.text,
    this.callId,
    this.callDirection,
    this.callStatus,
    this.isVideoCall = false,
    this.callDurationSeconds,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'conversationId': conversationId,
        'peerUserId': peerUserId,
        'fromUserId': fromUserId,
        'fromNickname': fromNickname,
        'text': text,
        'timestamp': timestamp.toIso8601String(),
        if (clientTimestamp != null)
          'clientTimestamp': clientTimestamp!.toIso8601String(),
        if (serverTimestamp != null)
          'serverTimestamp': serverTimestamp!.toIso8601String(),
        if (deliveredAt != null) 'deliveredAt': deliveredAt!.toIso8601String(),
        if (receivedAt != null) 'receivedAt': receivedAt!.toIso8601String(),
        if (localCreatedAt != null)
          'localCreatedAt': localCreatedAt!.toIso8601String(),
        if (serverSequence != null) 'serverSequence': serverSequence,
        'isMe': isMe,
        'attachment': attachment?.toJson(),
        'status': status.name,
        if (replyToMessageId != null) 'replyToMessageId': replyToMessageId,
        if (replyToSenderId != null) 'replyToSenderId': replyToSenderId,
        if (replyToSenderName != null) 'replyToSenderName': replyToSenderName,
        if (replyPreviewText != null) 'replyPreviewText': replyPreviewText,
        if (replyPreviewType != null)
          'replyPreviewType': replyPreviewType!.name,
        'isForwarded': isForwarded,
        if (forwardedFromSenderId != null)
          'forwardedFromSenderId': forwardedFromSenderId,
        if (forwardedFromSenderName != null)
          'forwardedFromSenderName': forwardedFromSenderName,
        if (forwardedFromMessageId != null)
          'forwardedFromMessageId': forwardedFromMessageId,
        'type': type.name,
        if (callId != null) 'callId': callId,
        if (callDirection != null) 'callDirection': callDirection!.name,
        if (callStatus != null) 'callStatus': callStatus!.name,
        'isVideoCall': isVideoCall,
        if (callDurationSeconds != null)
          'callDurationSeconds': callDurationSeconds,
      };

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        id: json['id'] as String,
        conversationId: json['conversationId'] as String,
        peerUserId: json['peerUserId'] as String,
        fromUserId: json['fromUserId'] as String,
        fromNickname: json['fromNickname'] as String,
        text: json['text'] as String? ?? '',
        timestamp: _parseDateTimeValue(json['timestamp']) ??
            DateTime.fromMillisecondsSinceEpoch(0),
        clientTimestamp: _parseDateTimeValue(json['clientTimestamp']),
        serverTimestamp: _parseDateTimeValue(
          json['serverTimestamp'] ?? json['serverReceivedAt'],
        ),
        deliveredAt: _parseDateTimeValue(json['deliveredAt']),
        receivedAt: _parseDateTimeValue(json['receivedAt']),
        localCreatedAt: _parseDateTimeValue(
          json['localCreatedAt'] ?? json['clientCreatedAt'],
        ),
        serverSequence: _parseIntValue(json['serverSequence']),
        isMe: json['isMe'] as bool? ?? false,
        attachment: json['attachment'] is Map<String, dynamic>
            ? ChatAttachment.fromJson(
                json['attachment'] as Map<String, dynamic>)
            : null,
        status: MessageDeliveryStatus.values.firstWhere(
          (item) =>
              item.name ==
              (json['status'] as String? ??
                  ((json['isMe'] as bool? ?? false) ? 'sent' : 'delivered')),
          orElse: () => MessageDeliveryStatus.sent,
        ),
        replyToMessageId: json['replyToMessageId'] as String?,
        replyToSenderId: json['replyToSenderId'] as String?,
        replyToSenderName: json['replyToSenderName'] as String?,
        replyPreviewText: json['replyPreviewText'] as String?,
        replyPreviewType: json['replyPreviewType'] == null
            ? null
            : ReplyPreviewType.values.firstWhere(
                (item) => item.name == json['replyPreviewType'],
                orElse: () => ReplyPreviewType.unknown,
              ),
        isForwarded: json['isForwarded'] as bool? ?? false,
        forwardedFromSenderId: json['forwardedFromSenderId'] as String?,
        forwardedFromSenderName: json['forwardedFromSenderName'] as String?,
        forwardedFromMessageId: json['forwardedFromMessageId'] as String?,
        type: ChatMessageType.values.firstWhere(
          (item) =>
              item.name ==
              (json['type'] as String? ??
                  ((json['callId'] != null) ? 'call' : 'text')),
          orElse: () => ChatMessageType.text,
        ),
        callId: json['callId'] as String?,
        callDirection: json['callDirection'] == null
            ? null
            : CallDirection.values.firstWhere(
                (item) => item.name == json['callDirection'],
                orElse: () => CallDirection.incoming,
              ),
        callStatus: _parseCallStatus(json['callStatus']),
        isVideoCall: json['isVideoCall'] as bool? ?? false,
        callDurationSeconds: _parseIntValue(json['callDurationSeconds']),
      );

  ChatMessage copyWith({
    String? id,
    String? conversationId,
    String? peerUserId,
    String? fromUserId,
    String? fromNickname,
    String? text,
    DateTime? timestamp,
    DateTime? clientTimestamp,
    DateTime? serverTimestamp,
    DateTime? deliveredAt,
    DateTime? receivedAt,
    DateTime? localCreatedAt,
    int? serverSequence,
    bool? isMe,
    ChatAttachment? attachment,
    bool clearAttachment = false,
    MessageDeliveryStatus? status,
    String? replyToMessageId,
    String? replyToSenderId,
    String? replyToSenderName,
    String? replyPreviewText,
    ReplyPreviewType? replyPreviewType,
    bool? isForwarded,
    String? forwardedFromSenderId,
    String? forwardedFromSenderName,
    String? forwardedFromMessageId,
    ChatMessageType? type,
    String? callId,
    CallDirection? callDirection,
    CallStatus? callStatus,
    bool? isVideoCall,
    int? callDurationSeconds,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      peerUserId: peerUserId ?? this.peerUserId,
      fromUserId: fromUserId ?? this.fromUserId,
      fromNickname: fromNickname ?? this.fromNickname,
      text: text ?? this.text,
      timestamp: timestamp ?? this.timestamp,
      clientTimestamp: clientTimestamp ?? this.clientTimestamp,
      serverTimestamp: serverTimestamp ?? this.serverTimestamp,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      receivedAt: receivedAt ?? this.receivedAt,
      localCreatedAt: localCreatedAt ?? this.localCreatedAt,
      serverSequence: serverSequence ?? this.serverSequence,
      isMe: isMe ?? this.isMe,
      attachment: clearAttachment ? null : attachment ?? this.attachment,
      status: status ?? this.status,
      replyToMessageId: replyToMessageId ?? this.replyToMessageId,
      replyToSenderId: replyToSenderId ?? this.replyToSenderId,
      replyToSenderName: replyToSenderName ?? this.replyToSenderName,
      replyPreviewText: replyPreviewText ?? this.replyPreviewText,
      replyPreviewType: replyPreviewType ?? this.replyPreviewType,
      isForwarded: isForwarded ?? this.isForwarded,
      forwardedFromSenderId:
          forwardedFromSenderId ?? this.forwardedFromSenderId,
      forwardedFromSenderName:
          forwardedFromSenderName ?? this.forwardedFromSenderName,
      forwardedFromMessageId:
          forwardedFromMessageId ?? this.forwardedFromMessageId,
      type: type ?? this.type,
      callId: callId ?? this.callId,
      callDirection: callDirection ?? this.callDirection,
      callStatus: callStatus ?? this.callStatus,
      isVideoCall: isVideoCall ?? this.isVideoCall,
      callDurationSeconds: callDurationSeconds ?? this.callDurationSeconds,
    );
  }

  int get primarySortMillis =>
      (serverTimestamp ?? clientTimestamp ?? timestamp).millisecondsSinceEpoch;

  int get secondarySortMillis =>
      (receivedAt ?? localCreatedAt ?? timestamp).millisecondsSinceEpoch;

  static int compareForDisplay(ChatMessage a, ChatMessage b) {
    final primary = a.primarySortMillis.compareTo(b.primarySortMillis);
    if (primary != 0) return primary;
    final sequence = (a.serverSequence ?? 0).compareTo(b.serverSequence ?? 0);
    if (sequence != 0) return sequence;
    final secondary = a.secondarySortMillis.compareTo(b.secondarySortMillis);
    if (secondary != 0) return secondary;
    return a.id.compareTo(b.id);
  }
}

DateTime? _parseDateTimeValue(Object? value) {
  if (value == null) return null;
  if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
  if (value is num) return DateTime.fromMillisecondsSinceEpoch(value.toInt());
  if (value is String) {
    final numeric = int.tryParse(value);
    if (numeric != null) {
      return DateTime.fromMillisecondsSinceEpoch(numeric);
    }
    return DateTime.tryParse(value);
  }
  return null;
}

int? _parseIntValue(Object? value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

CallStatus? _parseCallStatus(Object? value) {
  final raw = value?.toString();
  if (raw == null || raw.isEmpty) {
    return null;
  }
  switch (raw) {
    case 'ringing':
      return CallStatus.outgoingRinging;
    case 'accepted':
      return CallStatus.connected;
    case 'rejected':
      return CallStatus.rejectedByRecipient;
    case 'canceled':
      return CallStatus.canceledByCaller;
  }
  return CallStatus.values.firstWhere(
    (item) => item.name == raw,
    orElse: () => CallStatus.missed,
  );
}

class Conversation {
  final String id;
  final String peerUserId;
  final String peerNickname;
  final List<ChatMessage> messages;

  const Conversation({
    required this.id,
    required this.peerUserId,
    required this.peerNickname,
    required this.messages,
  });

  Conversation copyWith({
    String? id,
    String? peerUserId,
    String? peerNickname,
    List<ChatMessage>? messages,
  }) {
    return Conversation(
      id: id ?? this.id,
      peerUserId: peerUserId ?? this.peerUserId,
      peerNickname: peerNickname ?? this.peerNickname,
      messages: messages ?? this.messages,
    );
  }

  Conversation copyWithMessage(ChatMessage message) {
    final existingIndex = messages.indexWhere((item) => item.id == message.id);
    final nextMessages = [...messages];
    if (existingIndex == -1) {
      nextMessages.add(message);
    } else {
      nextMessages[existingIndex] = message;
    }
    nextMessages.sort(ChatMessage.compareForDisplay);
    return copyWith(messages: nextMessages);
  }

  ChatMessage? get lastMessage => messages.isEmpty ? null : messages.last;

  Map<String, dynamic> toJson() => {
        'id': id,
        'peerUserId': peerUserId,
        'peerNickname': peerNickname,
        'messages': messages.map((message) => message.toJson()).toList(),
      };

  factory Conversation.fromJson(Map<String, dynamic> json) => Conversation(
        id: json['id'] as String,
        peerUserId: json['peerUserId'] as String,
        peerNickname: json['peerNickname'] as String,
        messages: (json['messages'] as List<dynamic>? ?? [])
            .map((item) =>
                ChatMessage.fromJson(Map<String, dynamic>.from(item as Map)))
            .toList()
          ..sort(ChatMessage.compareForDisplay),
      );
}

class ChatLocalSettings {
  final String conversationId;
  final bool muted;
  final bool pinned;
  final bool archived;

  const ChatLocalSettings({
    required this.conversationId,
    this.muted = false,
    this.pinned = false,
    this.archived = false,
  });

  factory ChatLocalSettings.fromJson(Map<String, dynamic> json) =>
      ChatLocalSettings(
        conversationId: json['conversationId'] as String,
        muted: json['muted'] as bool? ?? false,
        pinned: json['pinned'] as bool? ?? false,
        archived: json['archived'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'conversationId': conversationId,
        'muted': muted,
        'pinned': pinned,
        'archived': archived,
      };

  ChatLocalSettings copyWith({
    bool? muted,
    bool? pinned,
    bool? archived,
  }) =>
      ChatLocalSettings(
        conversationId: conversationId,
        muted: muted ?? this.muted,
        pinned: pinned ?? this.pinned,
        archived: archived ?? this.archived,
      );
}

String makeConversationId(String a, String b) {
  final sorted = [a, b]..sort();
  return '${sorted.first}_${sorted.last}';
}

String inferAttachmentKind(String name) => _inferAttachmentKind(name);

String _inferAttachmentKind(String name) {
  final normalized = name.toLowerCase();
  const imageExt = ['.jpg', '.jpeg', '.png', '.webp', '.heic', '.heif'];
  const videoExt = [
    '.mp4',
    '.mov',
    '.mkv',
    '.webm',
    '.m4v',
    '.mts',
    '.m2ts',
    '.ts'
  ];
  const audioExt = ['.mp3', '.wav', '.ogg', '.m4a', '.aac', '.flac'];
  const archiveExt = ['.zip', '.7z', '.rar', '.tar', '.gz', '.bz2', '.xz'];
  const ebookExt = ['.fb2', '.epub', '.mobi', '.azw3', '.djvu', '.djv'];
  const documentExt = [
    '.pdf',
    '.txt',
    '.csv',
    '.rtf',
    '.md',
    '.json',
    '.yaml',
    '.yml',
    '.ini',
    '.log',
    '.doc',
    '.docx',
    '.xls',
    '.xlsx',
    '.ppt',
    '.pptx',
    '.odt',
    '.ods',
    '.odp',
  ];

  if (imageExt.any(normalized.endsWith)) {
    return 'image';
  }
  if (videoExt.any(normalized.endsWith)) {
    return 'video';
  }
  if (audioExt.any(normalized.endsWith)) {
    return 'audio';
  }
  if (archiveExt.any(normalized.endsWith)) {
    return 'archive';
  }
  if (ebookExt.any(normalized.endsWith)) {
    return 'ebook';
  }
  if (documentExt.any(normalized.endsWith)) {
    return 'document';
  }
  return 'document';
}


