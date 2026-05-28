import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../firebase_options.dart';
import '../l10n/app_localizations.dart';
import '../l10n/l10n.dart';
import 'diagnostic_service.dart';
import 'platform_capabilities.dart';
import 'storage_service.dart';

enum PushProvider {
  fcm,
}

enum PushMode {
  fcm,
  foregroundService,
  unavailable,
}

enum PushActionType {
  message,
  contactRequest,
  incomingCall,
  rejectCall,
}

String? _clean(Object? value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}

int? _positiveIntOrNull(Object? value) {
  final parsed = value is num ? value.toInt() : int.tryParse('$value');
  return parsed != null && parsed > 0 ? parsed : null;
}

int? _normalizeTimestampMs(int? value) {
  if (value == null) {
    return null;
  }
  return value < 100000000000 ? value * 1000 : value;
}

class PushAction {
  final PushActionType type;
  final String? messageId;
  final String? requestId;
  final String? fromUserId;
  final String? fromUsername;
  final bool video;
  final int? timestampMs;
  final int? ttlMs;
  final bool acceptCall;

  const PushAction({
    required this.type,
    this.messageId,
    this.requestId,
    this.fromUserId,
    this.fromUsername,
    this.video = false,
    this.timestampMs,
    this.ttlMs,
    this.acceptCall = false,
  });

  factory PushAction.fromJson(Map<String, dynamic> json) {
    final rawType = json['type'] as String? ?? '';
    return PushAction(
      type: switch (rawType) {
        'contact_request' => PushActionType.contactRequest,
        'call' || 'incoming_call' => PushActionType.incomingCall,
        'reject_call' => PushActionType.rejectCall,
        _ => PushActionType.message,
      },
      messageId: _clean(json['messageId']),
      requestId: _clean(json['callId'] ?? json['requestId']),
      fromUserId: _clean(json['fromUserId']),
      fromUsername: _clean(json['fromNickname'] ?? json['fromUsername']),
      video: json['video'] == true ||
          json['video'] == 'true' ||
          json['callType'] == 'video',
      timestampMs: _normalizeTimestampMs(_positiveIntOrNull(json['timestamp'])),
      ttlMs: _positiveIntOrNull(json['ttlMs']),
      acceptCall: json['acceptCall'] == true || json['acceptCall'] == 'true',
    );
  }

  bool get isExpired {
    if (type != PushActionType.incomingCall) {
      return false;
    }
    final timestamp = timestampMs;
    final ttl = ttlMs;
    if (timestamp == null || ttl == null) {
      return false;
    }
    // Relax call push action expiration to tolerate clock drift
    final effectiveTtl = ttl > 300000 ? ttl : 300000;
    return DateTime.now().millisecondsSinceEpoch - timestamp > effectiveTtl;
  }

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'type': switch (type) {
        PushActionType.message => 'message',
        PushActionType.contactRequest => 'contact_request',
        PushActionType.incomingCall => 'call',
        PushActionType.rejectCall => 'reject_call',
      },
      if (messageId != null) 'messageId': messageId,
      if (fromUserId != null) 'fromUserId': fromUserId,
      if (fromUsername != null) 'fromNickname': fromUsername,
      if (type == PushActionType.incomingCall)
        'video': video ? 'true' : 'false',
      if (timestampMs != null) 'timestamp': timestampMs.toString(),
      if (ttlMs != null) 'ttlMs': ttlMs.toString(),
      if (acceptCall) 'acceptCall': 'true',
    };
    if (requestId != null) {
      json[type == PushActionType.incomingCall ? 'callId' : 'requestId'] =
          requestId;
    }
    return json;
  }
}

@pragma('vm:entry-point')
Future<void> hestiaFirebaseMessagingBackgroundHandler(
  RemoteMessage message,
) async {
  DartPluginRegistrant.ensureInitialized();
  debugPrint('[PushService] FCM background message received');
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  } catch (_) {
    // Push must never make the Android client unusable.
  }
  await FirebasePushService.storePendingRemoteMessage(message);
  await FirebasePushService.showLocalNotificationForRemoteMessage(message);
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
        'pushMode': PushMode.fcm.name,
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
  static const _messageChannelId = 'hestia_messages';
  static const _callChannelId = 'hestia_calls';
  static const _backgroundServiceChannelId = 'hestia_background_service';
  static const _actionAcceptCall = 'accept_call';
  static const _actionDeclineCall = 'decline_call';
  static const _actionOpenApp = 'open_app';
  static const _ringtoneSound = RawResourceAndroidNotificationSound('ringtone');
  static final Int64List _callVibrationPattern =
      Int64List.fromList(const [0, 700, 250, 700, 250, 1200]);
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  static const MethodChannel _androidWakeupChannel =
      MethodChannel('hestia/android_wakeup');
  static bool _localNotificationsReady = false;
  static final Set<String> _cancelledCallNotificationIds = <String>{};

  String? _token;
  String _appVersion = '';
  bool _initialized = false;
  String _permissionStatus = 'not_requested';
  bool _tokenObtained = false;
  bool _tokenUploaded = false;
  bool _tokenRefreshHandled = false;
  bool _foregroundServiceActive = false;
  bool _notificationPermissionGranted = false;
  bool? _googlePlayServicesAvailable;
  bool? _notificationsEnabled;
  bool? _fullScreenIntentAllowed;
  bool? _batteryOptimizationIgnored;
  bool? _nativeWebSocketConnected;
  bool? _nativeWebSocketAuthenticated;
  bool? _nativeBootReceiverFired;
  bool? _nativeAndroidStoppedWarning;
  String _nativeLastRestartReason = 'none';
  int _nativeWatchdogLastCheckMs = 0;
  int _nativeServiceKilledRestartedCount = 0;
  bool _batteryOptimizationPromptPending = false;
  bool _batteryOptimizationPromptShown = false;
  PushMode _pushMode = PushMode.unavailable;
  DateTime? _lastPushReceivedAt;
  String _lastPushReceivedType = 'none';
  DateTime? _lastNotificationShownAt;
  String _lastNotificationShownType = 'none';
  DateTime? _lastCallPushAt;
  String _lastCallPushCallId = 'none';
  DateTime? _lastTokenUpdatedAt;
  StreamSubscription<String>? _tokenRefreshSub;

  void Function(String token)? onTokenRefresh;
  void Function(PushAction action)? onPushAction;
  void Function()? onBatteryOptimizationPromptNeeded;

  bool get initialized => _initialized;
  String get permissionStatus => _permissionStatus;
  bool get tokenObtained => _tokenObtained;
  bool get tokenUploaded => _tokenUploaded;
  bool get tokenRefreshHandled => _tokenRefreshHandled;
  bool get foregroundServiceActive => _foregroundServiceActive;
  PushMode get pushMode => _pushMode;
  DateTime? get lastTokenUpdatedAt => _lastTokenUpdatedAt;

  List<String> get diagnosticLines => [
        'pushMode=$_pushModeLabel',
        'androidMinimumSupported: Android 8.0/API 26',
        'postNotificationsRuntimePermission: Android 13+ only',
        'googlePlayServicesAvailable: ${_googlePlayServicesAvailable ?? 'unknown'}',
        'fcmAvailable: ${_initialized && _tokenObtained}',
        'fcmTokenExists: $_tokenObtained',
        'fcmInitialized: $_initialized',
        'notificationPermission: $_permissionStatus',
        'notificationPermissionGranted: $_notificationPermissionGranted',
        'notificationsEnabled: ${_notificationsEnabled ?? 'unknown'}',
        'fullScreenIntentAllowed: ${_fullScreenIntentAllowed ?? 'unknown'}',
        if (_fullScreenIntentAllowed == false)
          'Full-screen call alerts are disabled by Android settings',
        'foregroundServiceRunning: $_foregroundServiceActive',
        'foregroundServiceWebSocketConnected: ${_nativeWebSocketConnected ?? 'unknown'}',
        'foregroundServiceWebSocketAuthenticated: ${_nativeWebSocketAuthenticated ?? 'unknown'}',
        'foregroundServiceLastRestartReason: $_nativeLastRestartReason',
        'batteryOptimizationIgnored: ${_batteryOptimizationIgnored ?? 'unknown'}',
        'bootReceiverFired: ${_nativeBootReceiverFired ?? 'unknown'}',
        'watchdogLastCheck: ${_nativeWatchdogLastCheckMs == 0 ? 'none' : DateTime.fromMillisecondsSinceEpoch(_nativeWatchdogLastCheckMs, isUtc: false).toIso8601String()}',
        'serviceKilledRestartedCount: $_nativeServiceKilledRestartedCount',
        if (_nativeAndroidStoppedWarning == true)
          'Android stopped background service. Calls/messages may not arrive until Hestia is opened again.',
        'fcmTokenObtained: $_tokenObtained',
        'fcmTokenUploaded: $_tokenUploaded',
        'fcmTokenRefreshHandled: $_tokenRefreshHandled',
        'fcmTokenUpdatedAt: ${_lastTokenUpdatedAt?.toIso8601String() ?? 'none'}',
        'lastFcmReceived: $_lastPushReceivedType ${_lastPushReceivedAt?.toIso8601String() ?? 'none'}',
        'lastPushReceived: $_lastPushReceivedType ${_lastPushReceivedAt?.toIso8601String() ?? 'none'}',
        'lastNotificationShown: $_lastNotificationShownType ${_lastNotificationShownAt?.toIso8601String() ?? 'none'}',
        'lastCallPush: $_lastCallPushCallId ${_lastCallPushAt?.toIso8601String() ?? 'none'}',
      ];

  @override
  Future<void> init() async {
    final package = await PackageInfo.fromPlatform();
    _appVersion = '${package.version}+${package.buildNumber}';

    if (!_isAndroid) {
      _log('disabled platform=non_android');
      return;
    }
    await _initLocalNotifications();
    await _requestAndroidNotificationPermission();
    await _refreshAndroidDiagnostics();

    try {
      FirebaseMessaging.onBackgroundMessage(
        hestiaFirebaseMessagingBackgroundHandler,
      );
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }
      _initialized = true;
      _log('initialized');

      await _requestFirebaseNotificationPermission();
      await _refreshCurrentToken();
      await _listenForTokenRefresh();
      _updatePushMode();

      FirebaseMessaging.onMessage.listen((message) {
        unawaited(showLocalNotificationForRemoteMessage(message));
      });

      FirebaseMessaging.onMessageOpenedApp.listen((message) {
        _handleRemoteMessageAction(message);
      });

      final launchDetails =
          await _localNotifications.getNotificationAppLaunchDetails();
      final launchResponse = launchDetails?.notificationResponse;
      if (launchDetails?.didNotificationLaunchApp == true &&
          launchResponse != null) {
        await _handleLocalNotificationResponse(launchResponse);
      }

      final initialMessage =
          await FirebaseMessaging.instance.getInitialMessage();
      if (initialMessage != null) {
        unawaited(storePendingRemoteMessage(initialMessage));
      }
    } catch (error) {
      _initialized = false;
      _token = null;
      _tokenObtained = false;
      _updatePushMode();
      await _refreshAndroidDiagnostics();
      _log('unavailable error=$error');
    }
  }

  @override
  Future<PushRegistration?> currentRegistration() async {
    if (!_initialized || !_isAndroid) {
      _log(
          'registration skipped initialized=$_initialized android=$_isAndroid');
      return null;
    }
    final token = _token;
    if (token == null || token.isEmpty) {
      _log('registration skipped reason=no_token');
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
    _tokenObtained = true;
    _lastTokenUpdatedAt = DateTime.now().toUtc();
    return _registrationFor(trimmed);
  }

  @override
  Future<PushRegistration?> removeToken() async {
    if (!_isAndroid) {
      return null;
    }
    final previous = _token;
    _token = null;
    _tokenObtained = false;
    _tokenUploaded = false;
    if (previous == null || previous.isEmpty) {
      return null;
    }
    return _registrationFor(previous);
  }

  void markTokenUploaded() {
    _tokenUploaded = true;
    _lastTokenUpdatedAt = DateTime.now().toUtc();
    _updatePushMode();
    _log('token uploaded');
  }

  void markTokenRemoved() {
    _tokenUploaded = false;
    _updatePushMode();
    _log('token removed');
  }

  Future<void> ensureWakeupAfterAuth({
    Map<String, String>? foregroundSocketConfig,
  }) async {
    if (!_isAndroid) {
      return;
    }
    await _ensureLocalNotificationsReady();
    await _refreshAndroidDiagnostics();
    if (foregroundSocketConfig != null) {
      await startForegroundFallback(socketConfig: foregroundSocketConfig);
      await _maybePromptForBatteryOptimization();
      _updatePushMode();
      return;
    }
    if (_initialized && _tokenObtained && _tokenUploaded) {
      _updatePushMode();
      return;
    }
    await startForegroundFallback(socketConfig: foregroundSocketConfig);
  }

  Future<void> startForegroundFallback({
    Map<String, String>? socketConfig,
  }) async {
    if (!_isAndroid || _foregroundServiceActive) {
      if (_foregroundServiceActive && socketConfig != null) {
        await _startNativeForegroundSocketService(socketConfig);
        await _scheduleNativeWatchdog();
        await _refreshAndroidDiagnostics();
      }
      _updatePushMode();
      return;
    }
    await _ensureLocalNotificationsReady();
    try {
      await _startNativeForegroundSocketService(socketConfig ?? const {});
      await _scheduleNativeWatchdog();
      _foregroundServiceActive = true;
      await _refreshAndroidDiagnostics();
      _log('foreground service active native_socket=true');
    } catch (error) {
      _foregroundServiceActive = false;
      _log('foreground service failed error=$error');
    }
    _updatePushMode();
  }

  Future<void> stopForegroundFallback() async {
    if (!_isAndroid || !_foregroundServiceActive) {
      _updatePushMode();
      return;
    }
    try {
      await _androidWakeupChannel.invokeMethod<bool>(
        'stopForegroundSocketService',
      );
      _foregroundServiceActive = false;
      _log('foreground service stopped');
    } catch (error) {
      _log('foreground service stop failed error=$error');
    }
    _updatePushMode();
  }

  Future<void> updateAndroidAppState(String state) async {
    if (!_isAndroid) {
      return;
    }
    try {
      await _androidWakeupChannel.invokeMethod<bool>(
        'updateAppState',
        {'state': state},
      );
    } catch (error) {
      _log('android app state update failed error=$error');
    }
  }

  Future<void> updateAndroidCallState(
    String callId,
    String state, {
    required String source,
  }) async {
    if (!_isAndroid || callId.isEmpty) {
      return;
    }
    try {
      await _androidWakeupChannel.invokeMethod<bool>(
        'updateCallState',
        {
          'callId': callId,
          'state': state,
          'source': source,
        },
      );
    } catch (error) {
      _log('android call state update failed error=$error');
    }
  }

  Future<void> cancelCallNotifications(String callId) async {
    if (!PlatformCapabilities.supportsLocalNotifications) {
      if (PlatformCapabilities.isWeb) {
        debugPrint('[WebPlatform] local notifications skipped reason=web');
      }
      return;
    }
    // 1. Cancel the Flutter local notification (shown by _showIncomingCallNotification)
    final notificationId = _javaHashCode(callId) & 0x7fffffff;
    _log(
      'cancel call notification requested callId=$callId notificationId=$notificationId',
    );
    if (!_cancelledCallNotificationIds.add(callId)) {
      _log('duplicate cancel ignored callId=$callId');
    }
    try {
      await _localNotifications.cancel(id: notificationId);
      _log(
        'cancel call notification success callId=$callId source=flutter_local',
      );
    } catch (error) {
      _log('flutter local call notification cancel failed error=$error');
    }

    // 2. Cancel the native foreground service notification (shown by HestiaForegroundService)
    if (!_isAndroid) return;
    try {
      await _androidWakeupChannel.invokeMethod<bool>(
        'cancelCallNotification',
        {'callId': callId},
      );
      _log('cancel call notification success callId=$callId source=native');
    } catch (error) {
      _log('native call notification cancel failed error=$error');
    }
  }

  Future<void> _startNativeForegroundSocketService(
    Map<String, String> socketConfig,
  ) async {
    final args = Map<String, String>.from(socketConfig);
    await _androidWakeupChannel.invokeMethod<bool>(
      'startForegroundSocketService',
      args,
    );
  }

  Future<void> requestIgnoreBatteryOptimizations() async {
    if (!_isAndroid) {
      return;
    }
    try {
      await _androidWakeupChannel.invokeMethod<bool>(
        'requestIgnoreBatteryOptimizations',
      );
      await _refreshAndroidDiagnostics();
    } catch (error) {
      _log('battery optimization request failed error=$error');
    }
  }

  bool consumeBatteryOptimizationPrompt() {
    final pending = _batteryOptimizationPromptPending;
    _batteryOptimizationPromptPending = false;
    return pending;
  }

  Future<void> _scheduleNativeWatchdog() async {
    if (!_isAndroid) {
      return;
    }
    try {
      await _androidWakeupChannel.invokeMethod<bool>(
        'scheduleAlwaysReachableWatchdog',
      );
    } catch (error) {
      _log('watchdog schedule failed error=$error');
    }
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

  bool get _isAndroid => PlatformCapabilities.isAndroid;

  Future<void> _requestFirebaseNotificationPermission() async {
    try {
      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
      _permissionStatus = settings.authorizationStatus.name;
      _notificationPermissionGranted =
          settings.authorizationStatus == AuthorizationStatus.authorized ||
              settings.authorizationStatus == AuthorizationStatus.provisional;
      await _requestAndroidNotificationPermission();
      _log('notification permission=$_permissionStatus');
    } catch (error) {
      _permissionStatus = 'error';
      _log('notification permission failed error=$error');
    }
  }

  Future<void> _requestAndroidNotificationPermission() async {
    try {
      final android = _localNotifications.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      final notificationGranted =
          await android?.requestNotificationsPermission();
      if (notificationGranted != null) {
        _notificationPermissionGranted = notificationGranted;
        _permissionStatus = notificationGranted ? 'authorized' : 'denied';
      }
      _fullScreenIntentAllowed =
          await android?.requestFullScreenIntentPermission();
    } catch (error) {
      _log('android notification permission failed error=$error');
    }
  }

  Future<void> _refreshAndroidDiagnostics() async {
    if (!_isAndroid) {
      return;
    }
    try {
      _googlePlayServicesAvailable =
          await _androidWakeupChannel.invokeMethod<bool>(
        'isGooglePlayServicesAvailable',
      );
    } catch (_) {
      _googlePlayServicesAvailable = null;
    }
    try {
      _notificationsEnabled = await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.areNotificationsEnabled();
      if (_notificationsEnabled != null) {
        _notificationPermissionGranted = _notificationsEnabled!;
      }
    } catch (_) {
      _notificationsEnabled = null;
    }
    try {
      _batteryOptimizationIgnored =
          await _androidWakeupChannel.invokeMethod<bool>(
        'isIgnoringBatteryOptimizations',
      );
    } catch (error) {
      try {
        _batteryOptimizationIgnored =
            (await Permission.ignoreBatteryOptimizations.status).isGranted;
      } catch (_) {
        _batteryOptimizationIgnored = null;
      }
    }
    try {
      _fullScreenIntentAllowed = await _androidWakeupChannel.invokeMethod<bool>(
        'canUseFullScreenIntent',
      );
    } catch (_) {
      // Older builds may only expose this through flutter_local_notifications.
    }
    try {
      final diagnostics = await _androidWakeupChannel
          .invokeMapMethod<dynamic, dynamic>('readAlwaysReachableDiagnostics');
      if (diagnostics != null) {
        _foregroundServiceActive =
            diagnostics['foregroundServiceRunning'] == true;
        _nativeWebSocketConnected = diagnostics['websocketConnected'] == true;
        _nativeWebSocketAuthenticated =
            diagnostics['websocketAuthenticated'] == true;
        _nativeLastRestartReason =
            diagnostics['lastRestartReason']?.toString() ?? 'none';
        if (diagnostics['batteryOptimizationIgnored'] is bool) {
          _batteryOptimizationIgnored =
              diagnostics['batteryOptimizationIgnored'] as bool;
        }
        _nativeBootReceiverFired = diagnostics['bootReceiverFired'] == true;
        _nativeWatchdogLastCheckMs =
            (diagnostics['watchdogLastCheck'] as num?)?.toInt() ?? 0;
        _nativeServiceKilledRestartedCount =
            (diagnostics['serviceKilledRestartedCount'] as num?)?.toInt() ?? 0;
        _nativeAndroidStoppedWarning =
            diagnostics['androidStoppedWarning'] == true;
      }
    } catch (error) {
      _log('always reachable diagnostics failed error=$error');
    }
  }

  Future<void> _maybePromptForBatteryOptimization() async {
    if (!_isAndroid ||
        _batteryOptimizationIgnored != false ||
        _batteryOptimizationPromptShown) {
      return;
    }
    _batteryOptimizationPromptShown = true;
    _batteryOptimizationPromptPending = true;
    DiagnosticService.instance.log(
      'battery optimization prompt needed always_reachable=true',
    );
    final callback = onBatteryOptimizationPromptNeeded;
    if (callback != null) {
      callback();
    }
  }

  Future<void> _refreshCurrentToken() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.isEmpty) {
        _token = null;
        _tokenObtained = false;
        _updatePushMode();
        _log('token unavailable');
        return;
      }
      _token = token;
      _tokenObtained = true;
      _lastTokenUpdatedAt = DateTime.now().toUtc();
      _updatePushMode();
      _log('token obtained');
    } catch (error) {
      _token = null;
      _tokenObtained = false;
      _updatePushMode();
      _log('token fetch failed error=$error');
    }
  }

  Future<void> _listenForTokenRefresh() async {
    await _tokenRefreshSub?.cancel();
    _tokenRefreshSub =
        FirebaseMessaging.instance.onTokenRefresh.listen((token) {
      final trimmed = token.trim();
      if (trimmed.isEmpty) {
        return;
      }
      _token = trimmed;
      _tokenObtained = true;
      _tokenUploaded = false;
      _tokenRefreshHandled = true;
      _lastTokenUpdatedAt = DateTime.now().toUtc();
      _updatePushMode();
      _log('token refresh handled');
      onTokenRefresh?.call(trimmed);
    }, onError: (error) {
      _log('token refresh failed error=$error');
    });
  }

  Future<List<PushAction>> drainPendingActions() async {
    final prefs = await SharedPreferences.getInstance();
    final rawItems = prefs.getStringList(_pendingPushActionsKey) ?? const [];
    await prefs.remove(_pendingPushActionsKey);
    final nativeItems = <String>[];
    if (_isAndroid) {
      try {
        final drained = await _androidWakeupChannel
            .invokeListMethod<String>('drainForegroundServiceActions');
        if (drained != null) {
          nativeItems.addAll(drained);
        }
        debugPrint(
          '[HestiaIncomingUi] native pending action polled ${nativeItems.isEmpty ? 'no' : 'yes'} count=${nativeItems.length}',
        );
      } catch (error) {
        _log('native pending actions drain failed error=$error');
      }
    }
    return [...rawItems, ...nativeItems]
        .map((item) {
          try {
            return PushAction.fromJson(
                jsonDecode(item) as Map<String, dynamic>);
          } catch (_) {
            return null;
          }
        })
        .whereType<PushAction>()
        .toList();
  }

  static Future<void> storePendingRemoteMessage(RemoteMessage message) async {
    final action = _actionFromRemoteMessage(message);
    if (action == null) {
      return;
    }
    instance._recordPushReceived(action);
    await storePendingAction(action);
  }

  static Future<void> storePendingAction(PushAction action) async {
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

  static Future<void> showLocalNotificationForRemoteMessage(
    RemoteMessage message,
  ) async {
    final action = _actionFromRemoteMessage(message);
    if (action == null) {
      return;
    }
    instance._recordPushReceived(action);
    await showLocalNotificationForAction(action);
  }

  static Future<void> showLocalNotificationForAction(PushAction action) async {
    if (!PlatformCapabilities.supportsLocalNotifications) {
      if (PlatformCapabilities.isWeb) {
        debugPrint('[WebPlatform] local notifications skipped reason=web');
      }
      return;
    }
    if (action.type == PushActionType.incomingCall && action.isExpired) {
      debugPrint('[PushService] expired call push ignored');
      DiagnosticService.instance.log('fcm expired call push ignored');
      return;
    }
    await _ensureLocalNotificationsReady();
    if (action.type == PushActionType.incomingCall) {
      await _showIncomingCallNotification(action);
      return;
    }
    if (action.type != PushActionType.message) {
      return;
    }
    final l10n = await _notificationL10n();
    final sender = action.fromUsername;
    final title = sender == null || sender.isEmpty ? 'Hestia' : sender;
    final body = l10n.newMessageNotification;
    final idString = action.messageId ?? action.fromUserId ?? '';
    final notificationId = idString.isNotEmpty ? _javaHashCode(idString) : 9001;
    await _localNotifications.show(
      id: notificationId & 0x7fffffff,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _messageChannelId,
          l10n.pushMessagesChannel,
          channelDescription: l10n.pushMessageChannelDescription,
          importance: Importance.high,
          priority: Priority.high,
          category: AndroidNotificationCategory.message,
          visibility: NotificationVisibility.private,
        ),
      ),
      payload: jsonEncode(action.toJson()),
    );
    instance._recordNotificationShown(action);
    debugPrint('[PushService] local notification shown');
    DiagnosticService.instance.log('fcm local notification shown');
  }

  static Future<void> _showIncomingCallNotification(PushAction action) async {
    final l10n = await _notificationL10n();
    final caller = action.fromUsername;
    final title = action.video
        ? l10n.incomingVideoCallNotification
        : l10n.incomingVoiceCallNotification;
    final body = caller == null || caller.isEmpty ? l10n.unknownCaller : caller;
    final callId = action.requestId ?? action.fromUserId ?? '';
    final notificationId = _javaHashCode(callId) & 0x7fffffff;
    _cancelledCallNotificationIds.remove(callId);
    try {
      final shownNative = await _androidWakeupChannel.invokeMethod<bool>(
        'showIncomingCallNotification',
        {
          'callId': action.requestId ?? '',
          'fromUserId': action.fromUserId ?? '',
          'fromNickname': action.fromUsername ?? '',
          'video': action.video.toString(),
          'serverTimestamp':
              (action.timestampMs ?? DateTime.now().millisecondsSinceEpoch)
                  .toString(),
          'ttlMs': (action.ttlMs ?? 45000).toString(),
        },
      );
      if (shownNative != null) {
        if (shownNative) {
          instance._recordNotificationShown(action);
          DiagnosticService.instance.log(
            'fcm native incoming call notification/fullscreen requested',
          );
        } else {
          DiagnosticService.instance.log(
            'fcm native incoming call notification suppressed callId=$callId',
          );
        }
        return;
      }
    } catch (_) {
      // Background FCM isolates may not have the app Activity channel attached.
    }
    try {
      final allowed = await _androidWakeupChannel.invokeMethod<bool>(
        'canUseFullScreenIntent',
      );
      debugPrint('[HestiaCallUi] canUseFullScreenIntent=${allowed ?? true}');
      if (allowed == false) {
        DiagnosticService.instance.log(
          'Full-screen call alerts are disabled by Android settings',
        );
        debugPrint(
          '[HestiaCallUi] fallback heads-up notification used reason=fullscreen_intent_disabled callId=$callId',
        );
      } else {
        debugPrint('[HestiaCallUi] fullScreenIntent requested callId=$callId');
      }
    } catch (_) {
      debugPrint('[HestiaCallUi] fullScreenIntent requested callId=$callId');
    }
    await _localNotifications.show(
      id: notificationId,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _callChannelId,
          l10n.pushCallsChannel,
          channelDescription: l10n.pushCallChannelDescription,
          importance: Importance.max,
          priority: Priority.max,
          category: AndroidNotificationCategory.call,
          visibility: NotificationVisibility.public,
          fullScreenIntent: true,
          playSound: true,
          sound: _ringtoneSound,
          enableVibration: true,
          vibrationPattern: _callVibrationPattern,
          ongoing: true,
          autoCancel: false,
          actions: [
            AndroidNotificationAction(
              _actionAcceptCall,
              l10n.accept,
              showsUserInterface: true,
              semanticAction: SemanticAction.call,
            ),
            AndroidNotificationAction(
              _actionDeclineCall,
              l10n.decline,
              showsUserInterface: false,
              semanticAction: SemanticAction.delete,
            ),
            AndroidNotificationAction(
              _actionOpenApp,
              l10n.open,
              showsUserInterface: true,
            ),
          ],
        ),
      ),
      payload: jsonEncode(action.toJson()),
    );
    debugPrint(
      '[HestiaCallUi] call notification shown callId=$callId notificationId=$notificationId',
    );
    DiagnosticService.instance.log(
      'fcm call notification shown callId=$callId notificationId=$notificationId',
    );
    instance._recordNotificationShown(action);
    debugPrint('[PushService] incoming call notification shown');
    DiagnosticService.instance.log('fcm incoming call notification shown');
  }

  void _handleRemoteMessageAction(RemoteMessage message) {
    final action = _actionFromRemoteMessage(message);
    if (action != null) {
      _recordPushReceived(action);
      onPushAction?.call(action);
    }
  }

  void _recordPushReceived(PushAction action) {
    _lastPushReceivedAt = DateTime.now().toUtc();
    _lastPushReceivedType = action.type.name;
    if (action.type == PushActionType.incomingCall) {
      _lastCallPushAt = _lastPushReceivedAt;
      _lastCallPushCallId = action.requestId ?? 'none';
    }
  }

  void _recordNotificationShown(PushAction action) {
    _lastNotificationShownAt = DateTime.now().toUtc();
    _lastNotificationShownType = action.type.name;
  }

  static PushAction? _actionFromRemoteMessage(RemoteMessage message) {
    final data = message.data;
    final type = data['type'] ?? '';
    if (type == 'message') {
      return PushAction(
        type: PushActionType.message,
        messageId: _clean(data['messageId']),
        fromUserId: _clean(data['fromUserId']),
        fromUsername: _clean(data['fromNickname']),
      );
    }
    if (type == 'contact_request') {
      return PushAction(
        type: PushActionType.contactRequest,
        requestId: _clean(data['requestId']),
        fromUserId: _clean(data['fromUserId']),
        fromUsername: _clean(data['fromNickname']),
      );
    }
    if (type == 'call' || type == 'incoming_call') {
      return PushAction(
        type: PushActionType.incomingCall,
        requestId: _clean(data['callId']),
        fromUserId: _clean(data['fromUserId']),
        fromUsername: _clean(data['fromNickname'] ?? data['fromUsername']),
        video: data['video'] == true ||
            data['video'] == 'true' ||
            data['callType'] == 'video',
        timestampMs: _normalizeTimestampMs(_positiveIntOrNull(
          data['timestamp'] ?? data['serverTimestamp'] ?? data['callCreatedAt'],
        )),
        ttlMs: _positiveIntOrNull(data['ttlMs'] ?? data['callOfferTtlMs']),
      );
    }
    return null;
  }

  static Future<void> _ensureLocalNotificationsReady() async {
    if (!PlatformCapabilities.supportsLocalNotifications) {
      if (PlatformCapabilities.isWeb) {
        debugPrint('[WebPlatform] local notifications skipped reason=web');
      }
      return;
    }
    if (_localNotificationsReady) {
      return;
    }
    const initializationSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/launcher_icon'),
    );
    await _localNotifications.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: _handleLocalNotificationResponse,
      onDidReceiveBackgroundNotificationResponse:
          _handleLocalNotificationResponse,
    );
    final android = _localNotifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final l10n = await _notificationL10n();
    await android?.createNotificationChannel(
      AndroidNotificationChannel(
        _messageChannelId,
        l10n.pushMessagesChannel,
        description: l10n.pushMessageChannelDescription,
        importance: Importance.high,
      ),
    );
    await android?.createNotificationChannel(
      AndroidNotificationChannel(
        _callChannelId,
        l10n.pushCallsChannel,
        description: l10n.pushCallChannelDescription,
        importance: Importance.max,
        playSound: true,
        sound: _ringtoneSound,
        enableVibration: true,
        vibrationPattern: _callVibrationPattern,
      ),
    );
    await android?.createNotificationChannel(
      AndroidNotificationChannel(
        _backgroundServiceChannelId,
        l10n.pushBackgroundChannel,
        description: l10n.pushBackgroundChannelDescription,
        importance: Importance.low,
        showBadge: false,
      ),
    );
    _localNotificationsReady = true;
  }

  static Future<AppLocalizations> _notificationL10n() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString('languageCode');
    const supported = {'uk', 'ru', 'en', 'pl', 'es', 'cs', 'de'};
    final systemCode = PlatformDispatcher.instance.locale.languageCode;
    final code = supported.contains(stored)
        ? stored!
        : supported.contains(systemCode)
            ? systemCode
            : 'en';
    return lookupAppLocalizations(Locale(code));
  }

  Future<void> _initLocalNotifications() => _ensureLocalNotificationsReady();

  @pragma('vm:entry-point')
  static Future<void> _handleLocalNotificationResponse(
    NotificationResponse response,
  ) async {
    debugPrint('[PushService] notification tapped');
    DiagnosticService.instance.log('fcm notification tapped');
    final payload = response.payload;
    if (payload == null || payload.trim().isEmpty) {
      return;
    }
    try {
      var action = PushAction.fromJson(
        jsonDecode(payload) as Map<String, dynamic>,
      );
      if (response.actionId == _actionDeclineCall &&
          action.type == PushActionType.incomingCall) {
        action = PushAction(
          type: PushActionType.rejectCall,
          requestId: action.requestId,
          fromUserId: action.fromUserId,
          fromUsername: action.fromUsername,
          video: action.video,
          timestampMs: action.timestampMs,
          ttlMs: action.ttlMs,
        );
      } else if (response.actionId == _actionAcceptCall &&
          action.type == PushActionType.incomingCall) {
        action = PushAction(
          type: PushActionType.incomingCall,
          requestId: action.requestId,
          fromUserId: action.fromUserId,
          fromUsername: action.fromUsername,
          video: action.video,
          timestampMs: action.timestampMs,
          ttlMs: action.ttlMs,
          acceptCall: true,
        );
      }
      if (action.type == PushActionType.incomingCall && action.isExpired) {
        debugPrint('[PushService] expired call notification action ignored');
        DiagnosticService.instance
            .log('fcm expired call notification action ignored');
        await storePendingAction(action);
        return;
      }
      await storePendingAction(action);
      instance.onPushAction?.call(action);
    } catch (error) {
      debugPrint('[PushService] notification tap payload failed: $error');
    }
  }

  void _log(String message) {
    final full = 'fcm $message';
    DiagnosticService.instance.log(full);
    if (kDebugMode) {
      debugPrint('[PushService] $full');
    }
  }

  void _updatePushMode() {
    if (_initialized && _tokenObtained && _tokenUploaded) {
      _pushMode = PushMode.fcm;
    } else if (_foregroundServiceActive) {
      _pushMode = PushMode.foregroundService;
    } else {
      _pushMode = PushMode.unavailable;
    }
  }

  String get _pushModeLabel => switch (_pushMode) {
        PushMode.fcm => 'fcm',
        PushMode.foregroundService => 'foreground_service',
        PushMode.unavailable => 'none',
      };

  static int _javaHashCode(String s) {
    int hash = 0;
    for (int i = 0; i < s.length; i++) {
      hash = (31 * hash + s.codeUnitAt(i)) & 0xFFFFFFFF;
    }
    return hash;
  }
}
