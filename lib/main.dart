import 'dart:async';

import 'package:flutter/material.dart';

import 'config.dart';
import 'l10n/app_localizations.dart';
import 'l10n/l10n.dart';
import 'screens/call_screen.dart';
import 'screens/chat_screen.dart';
import 'screens/chat_list_screen.dart';
import 'screens/incoming_call_dialog.dart';
import 'screens/onboarding_screen.dart';
import 'screens/splash_screen.dart';
import 'services/background_service.dart';
import 'services/call_service.dart';
import 'screens/login_screen.dart';
import 'services/chat_service.dart';
import 'services/diagnostic_service.dart';
import 'services/locale_service.dart';
import 'services/micro_onboarding_service.dart';
import 'services/push_service.dart';
import 'services/retention_service.dart';
import 'services/storage_service.dart';
import 'services/theme_service.dart';
import 'theme/app_theme.dart';
import 'widgets/motion.dart';
import 'widgets/notifications.dart';
import 'widgets/ui_kit.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const HestiaApp());
}

class HestiaApp extends StatefulWidget {
  const HestiaApp({super.key});

  @override
  State<HestiaApp> createState() => _HestiaAppState();
}

class _HestiaAppState extends State<HestiaApp> with WidgetsBindingObserver {
  final _chat = ChatService.instance;
  final _locale = LocaleService.instance;
  final _theme = ThemeService.instance;
  final _background = BackgroundService.instance;
  final _navigatorKey = GlobalKey<NavigatorState>();
  String? _incomingCallDialogCallId;
  final Set<String> _notificationAcceptingCallIds = <String>{};
  int _homeTabIndex = 0;
  int _homeRevision = 0;
  bool _ready = false;
  bool _listenersAttached = false;
  bool _showOnboarding = false;
  bool _initialRegisterMode = false;
  String? _error;
  Timer? _errorTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    CallService.instance.setRecipientUiDiagnostics(
      appLifecycleState:
          WidgetsBinding.instance.lifecycleState?.name ?? 'unknown',
      routeDialogState: 'app_starting',
    );
    unawaited(_bootstrap());
  }

  Future<void> _bootstrap() async {
    await _bootStep('AppConfig.init', AppConfig.init);
    await _bootStep('StorageService.init', StorageService.instance.init);
    await _bootStep('LocaleService.init', LocaleService.instance.init);
    await _bootStep('ThemeService.init', ThemeService.instance.init);
    await _bootStep('BackgroundService.init', BackgroundService.instance.init);
    await _bootStep(
      'MicroOnboardingService.init',
      MicroOnboardingService.instance.init,
    );
    await _bootStep('RetentionService.init', RetentionService.instance.init);
    await _bootStep('DiagnosticService.init', DiagnosticService.instance.init);
    if (AppConfig.enablePushNotifications) {
      await _bootStep(
        'FirebasePushService.init',
        FirebasePushService.instance.init,
      );
      FirebasePushService.instance.onBatteryOptimizationPromptNeeded =
          _queueBatteryOptimizationPrompt;
      unawaited(FirebasePushService.instance.updateAndroidAppState(
        WidgetsBinding.instance.lifecycleState?.name ?? 'unknown',
      ));
    }
    await _bootStep('ChatService.init', ChatService.instance.init);
    if (!mounted) {
      return;
    }
    _chat.addListener(_refresh);
    _locale.addListener(_refresh);
    _theme.addListener(_refresh);
    _background.addListener(_refresh);
    _listenersAttached = true;
    _showOnboarding = StorageService.instance.loadProfile() == null &&
        !StorageService.instance.hasSeenOnboarding;
    if (AppConfig.enablePushNotifications) {
      FirebasePushService.instance.onPushAction = _handlePushAction;
      unawaited(_drainPendingPushActions());
    }
    _chat.onError = (message) {
      if (!mounted) {
        return;
      }
      _showTransientError(message);
    };
    setState(() {
      _ready = true;
    });
    if (AppConfig.enablePushNotifications &&
        FirebasePushService.instance.consumeBatteryOptimizationPrompt()) {
      _queueBatteryOptimizationPrompt();
    }
    if (AppConfig.enableVoiceCalls || AppConfig.enableVideoCalls) {
      CallService.instance.onIncomingCall = (info) {
        unawaited(_showIncomingCall(info));
      };
      CallService.instance.onMissedCall = (info, reason) {
        unawaited(_chat.recordMissedCall(
          callId: info.callId,
          fromUserId: info.fromUserId,
          fromNickname: info.fromNickname,
          timestampMs: info.callCreatedAtMs,
          reason: reason,
        ));
      };
      CallService.instance.onCallHistoryEvent = (event) {
        unawaited(_chat.recordCallEvent(
          callId: event.callId,
          peerUserId: event.peerUserId,
          peerNickname: event.peerNickname,
          direction: event.direction,
          status: event.status,
          timestampMs: event.timestampMs,
          durationSeconds: event.durationSeconds,
          isVideo: event.isVideo,
          reason: 'call_service',
        ));
      };
      CallService.instance.onError = (message) {
        if (!mounted) {
          return;
        }
        _showTransientError(message);
      };
    }
  }

  Future<void> _bootStep(String label, Future<void> Function() action) async {
    debugPrint('[Startup] begin $label');
    try {
      await action();
      debugPrint('[Startup] ok $label');
      DiagnosticService.instance.log('startup ok $label');
    } catch (error) {
      debugPrint('[Startup] failed $label: $error');
      DiagnosticService.instance.log('startup failed $label error=$error');
    }
  }

  void _showTransientError(String message) {
    _errorTimer?.cancel();
    setState(() {
      _error = message;
    });
    _errorTimer = Timer(const Duration(seconds: 4), () {
      if (!mounted || _error != message) {
        return;
      }
      setState(() {
        _error = null;
      });
    });
  }

  Future<void> _showIncomingCall(IncomingCallInfo info) async {
    final disposition =
        CallService.instance.incomingDispositionFor(info.callId);
    debugPrint(
      '[HestiaIncomingUi] BEFORE_DIALOG callId=${_shortId(info.callId)} '
      'currentState=${CallService.instance.state.name} '
      'callDisposition=${disposition?.name ?? 'absent'} '
      'source=CallService.onIncomingCall '
      'notificationAcceptAlreadyReceived=${_notificationAcceptingCallIds.contains(info.callId)}',
    );
    CallService.instance.setRecipientUiDiagnostics(
      routeDialogState: 'incoming_call_requested',
    );
    DiagnosticService.instance.log(
      'incoming call UI requested callId=${_shortId(info.callId)} '
      'fromUserId=${_shortId(info.fromUserId)} from=${info.fromNickname} '
      'video=${info.video}',
    );
    if (!mounted || _chat.profile == null) {
      CallService.instance.setRecipientUiDiagnostics(
        routeDialogState: 'app_not_ready',
      );
      DiagnosticService.instance.log(
        'incoming call UI ignored reason=app_not_ready callId=${_shortId(info.callId)}',
      );
      return;
    }
    if (CallService.instance.incomingDispositionFor(info.callId) ==
            IncomingCallDisposition.accepting ||
        _notificationAcceptingCallIds.contains(info.callId)) {
      DiagnosticService.instance.log(
        'incoming dialog suppressed reason=accepted_from_notification callId=${_shortId(info.callId)}',
      );
      debugPrint(
        '[HestiaIncomingUi] SUPPRESS_DIALOG callId=${_shortId(info.callId)} reason=accepted_from_notification',
      );
      return;
    }
    if (_incomingCallDialogCallId == info.callId) {
      CallService.instance.setRecipientUiDiagnostics(
        routeDialogState: 'duplicate_dialog',
      );
      DiagnosticService.instance.log(
        'incoming call UI ignored reason=duplicate_dialog callId=${_shortId(info.callId)}',
      );
      return;
    }
    final context = _navigatorKey.currentContext;
    if (context == null) {
      CallService.instance.setRecipientUiDiagnostics(
        routeDialogState: 'navigator_context_missing',
      );
      DiagnosticService.instance.log(
        'incoming call UI ignored reason=navigator_context_missing callId=${_shortId(info.callId)}',
      );
      return;
    }

    _incomingCallDialogCallId = info.callId;
    CallService.instance.setRecipientUiDiagnostics(
      routeDialogState: 'incoming_dialog_showing',
    );
    DiagnosticService.instance.log(
      'incoming call UI showing callId=${_shortId(info.callId)}',
    );
    debugPrint(
      '[HestiaIncomingUi] SHOW_DIALOG callId=${_shortId(info.callId)} reason=incoming_call_state',
    );
    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => IncomingCallDialog(info: info),
      );
      DiagnosticService.instance.log(
        'incoming call UI dismissed callId=${_shortId(info.callId)}',
      );
    } finally {
      if (_incomingCallDialogCallId == info.callId) {
        _incomingCallDialogCallId = null;
      }
      CallService.instance.setRecipientUiDiagnostics(
        routeDialogState: 'incoming_dialog_dismissed',
      );
    }
  }

  String _shortId(String value) =>
      value.length <= 8 ? value : '${value.substring(0, 8)}...';

  Future<void> _finishOnboarding({required bool registerMode}) async {
    await StorageService.instance.markOnboardingSeen();
    if (!mounted) {
      return;
    }
    setState(() {
      _showOnboarding = false;
      _initialRegisterMode = registerMode;
    });
  }

  @override
  void dispose() {
    if (_listenersAttached) {
      _chat.removeListener(_refresh);
      _locale.removeListener(_refresh);
      _theme.removeListener(_refresh);
      _background.removeListener(_refresh);
    }
    WidgetsBinding.instance.removeObserver(this);
    _errorTimer?.cancel();
    _chat.onError = null;
    FirebasePushService.instance.onPushAction = null;
    FirebasePushService.instance.onBatteryOptimizationPromptNeeded = null;
    CallService.instance.onIncomingCall = null;
    CallService.instance.onMissedCall = null;
    CallService.instance.onCallHistoryEvent = null;
    CallService.instance.onError = null;
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    CallService.instance.setRecipientUiDiagnostics(
      appLifecycleState: state.name,
    );
    _chat.updateClientAppState(state.name);
    if (AppConfig.enablePushNotifications &&
        state == AppLifecycleState.resumed) {
      unawaited(_drainPendingPushActions());
    }
  }

  void _queueBatteryOptimizationPrompt() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      unawaited(_showBatteryOptimizationPrompt());
    });
  }

  bool _batteryOptimizationPromptShowing = false;

  Future<void> _showBatteryOptimizationPrompt() async {
    if (_batteryOptimizationPromptShowing || !mounted) {
      return;
    }
    final context = _navigatorKey.currentContext;
    if (context == null) {
      return;
    }
    _batteryOptimizationPromptShowing = true;
    final allow = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.alwaysReachableTitle),
        content: Text(context.l10n.alwaysReachablePrompt),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.l10n.notNow),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(context.l10n.allow),
          ),
        ],
      ),
    );
    _batteryOptimizationPromptShowing = false;
    if (allow == true) {
      await FirebasePushService.instance.requestIgnoreBatteryOptimizations();
    }
  }

  void _refresh() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _login(String nickname, String password) async {
    setState(() {
      _error = null;
    });
    await _chat.login(nickname, password);
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _register(String nickname, String password) async {
    setState(() {
      _error = null;
    });
    await _chat.register(nickname, password);
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _drainPendingPushActions() async {
    final actions = await FirebasePushService.instance.drainPendingActions();
    debugPrint(
      '[HestiaIncomingUi] native pending action polled ${actions.isEmpty ? 'no' : 'yes'} count=${actions.length}',
    );
    for (final action in actions) {
      await _handlePushAction(action);
    }
  }

  Future<void> _handlePushAction(PushAction action) async {
    if (action.type == PushActionType.incomingCall && action.acceptCall) {
      DiagnosticService.instance.log(
        'native call action received action=accept_call callId=${_shortId(action.requestId ?? '')}',
      );
      debugPrint(
        '[HestiaIncomingUi] native action received action=accept_call callId=${_shortId(action.requestId ?? '')}',
      );
    } else if (action.type == PushActionType.rejectCall) {
      DiagnosticService.instance.log(
        'native call action received action=decline_call callId=${_shortId(action.requestId ?? '')}',
      );
      debugPrint(
        '[HestiaIncomingUi] native action received action=decline_call callId=${_shortId(action.requestId ?? '')}',
      );
    } else if (action.type == PushActionType.incomingCall) {
      DiagnosticService.instance.log(
        'native call action received action=open_call callId=${_shortId(action.requestId ?? '')}',
      );
      debugPrint(
        '[HestiaIncomingUi] native action received action=open_call callId=${_shortId(action.requestId ?? '')}',
      );
    }
    if (action.type != PushActionType.rejectCall &&
        !(action.type == PushActionType.incomingCall && action.acceptCall)) {
      await _chat.syncAfterPush(action);
    }
    if (!mounted || _chat.profile == null) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_runAfterFrame(action));
    });
  }

  Future<void> _runAfterFrame(PushAction action) async {
    if (!mounted) return;

    if (action.type == PushActionType.contactRequest) {
      setState(() {
        _homeTabIndex = 2;
        _homeRevision++;
      });
      _navigatorKey.currentState?.popUntil((route) => route.isFirst);
      return;
    }

    if (action.type == PushActionType.rejectCall) {
      final callId = action.requestId;
      if (callId == null || callId.isEmpty) {
        return;
      }
      if (!CallService.instance.beginIncomingDecline(
        callId,
        source: 'notification',
      )) {
        return;
      }
      await _chat.rejectPushCall(action);
      CallService.instance
          .closePendingIncomingCall(callId, 'notification_decline');
      return;
    }

    if (action.type == PushActionType.incomingCall) {
      if (action.acceptCall) {
        await _acceptPushCall(action);
      }
      return;
    }

    final peerUserId = action.fromUserId;
    if (peerUserId == null || peerUserId.isEmpty) {
      return;
    }
    _navigatorKey.currentState?.popUntil((route) => route.isFirst);
    final peerName = _chat.peerNameFor(peerUserId);
    await _navigatorKey.currentState?.push(
      HestiaMotion.route(
        (_) => ChatScreen(
          peerUserId: peerUserId,
          peerNickname: peerName,
        ),
      ),
    );
  }

  Future<void> _acceptPushCall(PushAction action) async {
    final callId = action.requestId;
    if (callId == null || callId.isEmpty) {
      return;
    }
    // Synthesize call_offer signal metadata if it is not already set/incoming.
    // This allows the app to transition immediately to incoming state and accept
    // the call without waiting for the socket connection to establish and download the signal.
    _notificationAcceptingCallIds.add(callId);
    debugPrint(
      '[HestiaIncomingUi] notificationAcceptAlreadyReceived=true callId=${_shortId(callId)}',
    );
    if (CallService.instance.incomingCall?.callId != callId) {
      await CallService.instance.handleSignal({
        'type': 'call_offer',
        'callId': callId,
        'fromUserId': action.fromUserId ?? '',
        'fromNickname': action.fromUsername ?? 'Hestia call',
        'video': action.video,
        'callCreatedAt':
            action.timestampMs ?? DateTime.now().millisecondsSinceEpoch,
        'ttlMs': action.ttlMs ?? CallService.callOfferTtlMs,
      });
      DiagnosticService.instance.log(
        'pending call reconstructed/found callId=${_shortId(callId)}',
      );
    } else {
      DiagnosticService.instance.log(
        'pending call reconstructed/found callId=${_shortId(callId)}',
      );
    }

    final incoming = CallService.instance.incomingCall;
    if (incoming?.callId == callId) {
      if (!CallService.instance.beginIncomingAccept(
        callId,
        source: 'notification',
      )) {
        _notificationAcceptingCallIds.remove(callId);
        return;
      }
      DiagnosticService.instance.log(
        'accept flow started from notification callId=${_shortId(callId)}',
      );
      if (incoming!.isExpired) {
        debugPrint(
          '[HestiaIncomingUi] acceptCall() invoked source=notification callId=${_shortId(callId)}',
        );
        await CallService.instance.acceptCall();
        _notificationAcceptingCallIds.remove(callId);
        return;
      }
      _navigatorKey.currentState?.popUntil((route) => route.isFirst);
      unawaited(_navigatorKey.currentState?.push(
        HestiaMotion.route(
          (_) => CallScreen(peerNickname: incoming.fromNickname),
        ),
      ));
      debugPrint(
        '[HestiaIncomingUi] acceptCall() invoked source=notification callId=${_shortId(callId)}',
      );
      unawaited(CallService.instance.acceptCall());
      _notificationAcceptingCallIds.remove(callId);
      return;
    }
    _notificationAcceptingCallIds.remove(callId);
  }

  @override
  Widget build(BuildContext context) {
    final loggedIn = _ready && _chat.profile != null;

    return MaterialApp(
      navigatorKey: _navigatorKey,
      debugShowCheckedModeBanner: false,
      locale: _locale.locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      localeResolutionCallback: (locale, supportedLocales) {
        if (locale == null) {
          return const Locale('en');
        }
        for (final supported in supportedLocales) {
          if (supported.languageCode == locale.languageCode) {
            return supported;
          }
        }
        return const Locale('en');
      },
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: _theme.themeMode,
      home: Builder(
        builder: (context) => Stack(
          children: [
            AnimatedSwitcher(
              duration: HestiaMotion.slow,
              switchInCurve: HestiaMotion.curve,
              switchOutCurve: Curves.easeInOut,
              child: !_ready
                  ? const SplashScreen(key: ValueKey('splash'))
                  : !loggedIn && _showOnboarding
                      ? OnboardingScreen(
                          key: const ValueKey('onboarding'),
                          onFinish: _finishOnboarding,
                        )
                      : loggedIn
                          ? ChatListScreen(
                              key: ValueKey('chat_list_$_homeRevision'),
                              initialTabIndex: _homeTabIndex,
                            )
                          : LoginScreen(
                              key: const ValueKey('login'),
                              onLogin: _login,
                              onRegister: _register,
                              initialRegisterMode: _initialRegisterMode,
                            ),
            ),
            if (_error != null)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: HestiaNotificationBanner(
                  message: context.localizedError(_error!),
                  tone: HestiaStatusTone.error,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
