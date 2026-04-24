import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/app_localizations.dart';
import 'locale_service.dart';
import 'storage_service.dart';

enum PushProvider {
  fcm,
}

enum PushActionType {
  message,
  contactRequest,
  incomingCall,
  rejectCall,
}

class PushAction {
  final PushActionType type;
  final String? messageId;
  final String? requestId;
  final String? fromUserId;
  final String? fromUsername;
  final bool video;

  const PushAction({
    required this.type,
    this.messageId,
    this.requestId,
    this.fromUserId,
    this.fromUsername,
    this.video = false,
  });

  factory PushAction.fromJson(Map<String, dynamic> json) {
    final rawType = json['type'] as String? ?? '';
    return PushAction(
      type: switch (rawType) {
        'contact_request' => PushActionType.contactRequest,
        'incoming_call' => PushActionType.incomingCall,
        'reject_call' => PushActionType.rejectCall,
        _ => PushActionType.message,
      },
      messageId: json['messageId'] as String?,
      requestId: json['requestId'] as String?,
      fromUserId: json['fromUserId'] as String?,
      fromUsername: json['fromUsername'] as String?,
      video: json['video'] as bool? ?? json['callType'] == 'video',
    );
  }

  Map<String, dynamic> toJson() => {
        'type': switch (type) {
          PushActionType.message => 'message',
          PushActionType.contactRequest => 'contact_request',
          PushActionType.incomingCall => 'incoming_call',
          PushActionType.rejectCall => 'reject_call',
        },
        if (messageId != null) 'messageId': messageId,
        if (requestId != null) 'requestId': requestId,
        if (fromUserId != null) 'fromUserId': fromUserId,
        if (fromUsername != null) 'fromUsername': fromUsername,
        if (type == PushActionType.incomingCall) 'callType': video ? 'video' : 'audio',
      };
}

@pragma('vm:entry-point')
Future<void> hestiaFirebaseMessagingBackgroundHandler(
  RemoteMessage message,
) async {
  try {
    await Firebase.initializeApp();
  } catch (_) {
    // The app must remain usable even if Firebase is not configured.
  }
  await FirebasePushService.storePendingRemoteMessage(message);
  await FirebasePushService.showNotificationForRemoteMessage(message);
}

class PushRegistration {
  final String deviceId;
  final String platform;
  final String pushToken;
  final PushProvider pushProvider;
  final String appVersion;
  final DateTime lastSeenAt;

  const PushRegistration({
    required this.deviceId,
    required this.platform,
    required this.pushToken,
    required this.pushProvider,
    required this.appVersion,
    required this.lastSeenAt,
  });

  Map<String, dynamic> toJson() => {
        'deviceId': deviceId,
        'platform': platform,
        'pushToken': pushToken,
        'pushProvider': pushProvider.name,
        'appVersion': appVersion,
        'lastSeenAt': lastSeenAt.toUtc().toIso8601String(),
      };
}

abstract class PushService {
  Future<void> init();

  Future<PushRegistration?> currentRegistration();

  Future<PushRegistration?> updateToken(String token);

  Future<PushRegistration?> removeToken();
}

class FirebasePushService implements PushService {
  FirebasePushService._();
  static final FirebasePushService instance = FirebasePushService._();
  static const _pendingPushActionsKey = 'hestia_pending_push_actions';
  static const _notificationChannelId = 'hestia_push_sync';
  static const _notificationChannelName = 'Hestia updates';
  static const _callChannelId = 'hestia_incoming_calls';
  static const _callChannelName = 'Hestia calls';
  static const actionAcceptCall = 'accept_call';
  static const actionRejectCall = 'reject_call';
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  String? _token;
  String _appVersion = '';
  bool _initialized = false;
  StreamSubscription<String>? _tokenRefreshSub;
  bool _notificationsInitialized = false;

  void Function(String token)? onTokenRefresh;
  void Function(PushAction action)? onPushAction;

  @override
  Future<void> init() async {
    final package = await PackageInfo.fromPlatform();
    _appVersion = '${package.version}+${package.buildNumber}';

    if (!_isAndroid) {
      _log('FCM disabled on this platform.');
      return;
    }

    try {
      FirebaseMessaging.onBackgroundMessage(
        hestiaFirebaseMessagingBackgroundHandler,
      );
      await Firebase.initializeApp();
      _initialized = true;
      _log('Firebase initialized for Android push.');
      await _initLocalNotifications();
      final launchDetails =
          await _notifications.getNotificationAppLaunchDetails();
      final launchAction = _actionFromPayload(
        launchDetails?.notificationResponse?.payload,
      );
      if (launchAction != null) {
        await _storePendingAction(launchAction);
      }

      try {
        final token = await FirebaseMessaging.instance.getToken();
        if (token == null || token.isEmpty) {
          _log('FCM token unavailable.');
        } else {
          _token = token;
          _log('FCM token received.');
        }
      } catch (error) {
        _log('FCM token fetch failed: $error');
      }

      await _tokenRefreshSub?.cancel();
      _tokenRefreshSub =
          FirebaseMessaging.instance.onTokenRefresh.listen((token) {
        final trimmed = token.trim();
        if (trimmed.isEmpty) {
          return;
        }
        _token = trimmed;
        _log('FCM token refreshed.');
        onTokenRefresh?.call(trimmed);
      }, onError: (error) {
        _log('FCM token refresh failed: $error');
      });

      FirebaseMessaging.onMessageOpenedApp.listen((message) {
        _handleRemoteMessageAction(message);
      });

      final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
      if (initialMessage != null) {
        unawaited(storePendingRemoteMessage(initialMessage));
      }
    } catch (error) {
      _initialized = false;
      _token = null;
      _log('Firebase push unavailable: $error');
    }
  }

  @override
  Future<PushRegistration?> currentRegistration() async {
    if (!_initialized || !_isAndroid) {
      return null;
    }
    final token = _token;
    if (token == null || token.isEmpty) {
      return null;
    }
    return _registrationFor(token);
  }

  @override
  Future<PushRegistration?> updateToken(String token) async {
    if (!_isAndroid) {
      return null;
    }
    final trimmed = token.trim();
    if (trimmed.isEmpty) {
      return removeToken();
    }
    _token = trimmed;
    return _registrationFor(trimmed);
  }

  @override
  Future<PushRegistration?> removeToken() async {
    if (!_isAndroid) {
      return null;
    }
    final previous = _token;
    _token = null;
    if (previous == null || previous.isEmpty) {
      return null;
    }
    return _registrationFor(previous);
  }

  Future<PushRegistration> _registrationFor(String token) async {
    return PushRegistration(
      deviceId: await StorageService.instance.loadOrCreateDeviceId(),
      platform: StorageService.instance.platformName,
      pushToken: token,
      pushProvider: PushProvider.fcm,
      appVersion: _appVersion,
      lastSeenAt: DateTime.now().toUtc(),
    );
  }

  bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<List<PushAction>> drainPendingActions() async {
    final prefs = await SharedPreferences.getInstance();
    final rawItems = prefs.getStringList(_pendingPushActionsKey) ?? const [];
    await prefs.remove(_pendingPushActionsKey);
    return rawItems
        .map((item) {
          try {
            return PushAction.fromJson(jsonDecode(item) as Map<String, dynamic>);
          } catch (_) {
            return null;
          }
        })
        .whereType<PushAction>()
        .toList();
  }

  Future<void> _initLocalNotifications() async {
    if (_notificationsInitialized) {
      return;
    }
    const android = AndroidInitializationSettings('@mipmap/launcher_icon');
    await _notifications.initialize(
      settings: const InitializationSettings(android: android),
      onDidReceiveNotificationResponse: (response) {
        final action = _actionFromPayload(response.payload);
        if (action != null) {
          if (response.actionId == actionRejectCall &&
              action.type == PushActionType.incomingCall) {
            onPushAction?.call(PushAction(
              type: PushActionType.rejectCall,
              requestId: action.requestId,
              fromUserId: action.fromUserId,
              fromUsername: action.fromUsername,
              video: action.video,
            ));
          } else {
            onPushAction?.call(action);
          }
        }
      },
    );
    final l10n = _notificationLocalizations();
    final channel = AndroidNotificationChannel(
      _notificationChannelId,
      _notificationChannelName,
      description: l10n.pushSyncChannelDescription,
      importance: Importance.high,
    );
    await _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
    final callChannel = AndroidNotificationChannel(
      _callChannelId,
      _callChannelName,
      description: l10n.pushCallChannelDescription,
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    );
    await _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(callChannel);
    _notificationsInitialized = true;
  }

  void _handleRemoteMessageAction(RemoteMessage message) {
    final action = _actionFromRemoteMessage(message);
    if (action != null) {
      onPushAction?.call(action);
    }
  }

  static Future<void> storePendingRemoteMessage(RemoteMessage message) async {
    final action = _actionFromRemoteMessage(message);
    if (action == null) {
      return;
    }
    await _storePendingAction(action);
  }

  static Future<void> _storePendingAction(PushAction action) async {
    final prefs = await SharedPreferences.getInstance();
    final rawItems = prefs.getStringList(_pendingPushActionsKey) ?? <String>[];
    final encoded = jsonEncode(action.toJson());
    if (!rawItems.contains(encoded)) {
      rawItems.add(encoded);
    }
    while (rawItems.length > 50) {
      rawItems.removeAt(0);
    }
    await prefs.setStringList(_pendingPushActionsKey, rawItems);
  }

  static Future<void> showNotificationForRemoteMessage(
    RemoteMessage message,
  ) async {
    final action = _actionFromRemoteMessage(message);
    if (action == null) {
      return;
    }
    const android = AndroidInitializationSettings('@mipmap/launcher_icon');
    await _notifications.initialize(
      settings: const InitializationSettings(android: android),
    );
    final l10n = _notificationLocalizations();
    final channel = AndroidNotificationChannel(
      _notificationChannelId,
      _notificationChannelName,
      description: l10n.pushSyncChannelDescription,
      importance: Importance.high,
    );
    await _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
    final callChannel = AndroidNotificationChannel(
      _callChannelId,
      _callChannelName,
      description: l10n.pushCallChannelDescription,
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    );
    await _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(callChannel);
    if (action.type == PushActionType.incomingCall) {
      await _showIncomingCallNotification(action);
      return;
    }
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _notificationChannelId,
        _notificationChannelName,
        channelDescription: l10n.pushSyncChannelDescription,
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/launcher_icon',
      ),
    );
    final title = action.type == PushActionType.contactRequest
        ? l10n.newContactRequestNotification
        : l10n.newMessageNotification;
    await _notifications.show(
      id: _notificationIdFor(action),
      title: 'Hestia',
      body: title,
      notificationDetails: details,
      payload: jsonEncode(action.toJson()),
    );
  }

  static Future<void> _showIncomingCallNotification(PushAction action) async {
    final l10n = _notificationLocalizations();
    final caller = action.fromUsername ?? l10n.unknownCaller;
    final body = action.video
        ? l10n.incomingVideoCallNotification
        : l10n.incomingVoiceCallNotification;
    final payload = jsonEncode(action.toJson());
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _callChannelId,
        _callChannelName,
        channelDescription: l10n.pushCallChannelDescription,
        importance: Importance.max,
        priority: Priority.max,
        category: AndroidNotificationCategory.call,
        fullScreenIntent: true,
        timeoutAfter: 45000,
        ongoing: true,
        autoCancel: false,
        icon: '@mipmap/launcher_icon',
        actions: [
          AndroidNotificationAction(
            actionRejectCall,
            l10n.rejectCall,
            cancelNotification: true,
            semanticAction: SemanticAction.none,
          ),
          AndroidNotificationAction(
            actionAcceptCall,
            l10n.accept,
            showsUserInterface: true,
            cancelNotification: true,
            semanticAction: SemanticAction.call,
          ),
        ],
      ),
    );
    await _notifications.show(
      id: _notificationIdFor(action),
      title: caller,
      body: body,
      notificationDetails: details,
      payload: payload,
    );
  }

  static AppLocalizations _notificationLocalizations() {
    final languageCode = LocaleService.instance.languageCode ?? 'en';
    return lookupAppLocalizations(Locale(languageCode));
  }

  static PushAction? _actionFromRemoteMessage(RemoteMessage message) {
    final data = message.data;
    final type = data['type'] ?? '';
    if (type == 'message') {
      return PushAction(
        type: PushActionType.message,
        messageId: _clean(data['messageId']),
        fromUserId: _clean(data['fromUserId']),
      );
    }
    if (type == 'contact_request') {
      return PushAction(
        type: PushActionType.contactRequest,
        requestId: _clean(data['requestId']),
        fromUserId: _clean(data['fromUserId']),
      );
    }
    if (type == 'incoming_call') {
      return PushAction(
        type: PushActionType.incomingCall,
        requestId: _clean(data['callId']),
        fromUserId: _clean(data['fromUserId']),
        fromUsername: _clean(data['fromUsername']),
        video: data['callType'] == 'video' || data['video'] == 'true',
      );
    }
    return null;
  }

  static PushAction? _actionFromPayload(String? payload) {
    if (payload == null || payload.isEmpty) {
      return null;
    }
    try {
      return PushAction.fromJson(jsonDecode(payload) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  static int _notificationIdFor(PushAction action) {
    final raw = action.messageId ?? action.requestId ?? action.fromUserId ?? '';
    return raw.hashCode & 0x7fffffff;
  }

  static String? _clean(Object? value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }

  void _log(String message) {
    if (kDebugMode) {
      debugPrint('[PushService] $message');
    }
  }
}
