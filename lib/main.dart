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
  int _homeTabIndex = 0;
  int _homeRevision = 0;
  bool _ready = false;
  bool _listenersAttached = false;
  bool _showOnboarding = false;
  bool _initialRegisterMode = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_bootstrap());
  }

  Future<void> _bootstrap() async {
    await AppConfig.init();
    await StorageService.instance.init();
    await LocaleService.instance.init();
    await ThemeService.instance.init();
    await BackgroundService.instance.init();
    await MicroOnboardingService.instance.init();
    await RetentionService.instance.init();
    await FirebasePushService.instance.init();
    await ChatService.instance.init();
    if (!mounted) {
      return;
    }
    _chat.addListener(_refresh);
    _locale.addListener(_refresh);
    _theme.addListener(_refresh);
    _background.addListener(_refresh);
    _listenersAttached = true;
    _showOnboarding =
        StorageService.instance.loadProfile() == null &&
            !StorageService.instance.hasSeenOnboarding;
    FirebasePushService.instance.onPushAction = _handlePushAction;
    unawaited(_drainPendingPushActions());
    _chat.onError = (message) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = message;
      });
    };
    setState(() {
      _ready = true;
    });
    CallService.instance.onIncomingCall = (info) {
      final context = _navigatorKey.currentContext;
      if (context == null) {
        return;
      }
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => IncomingCallDialog(info: info),
      );
    };
    CallService.instance.onError = (message) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = message;
      });
    };
  }

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
    _chat.onError = null;
    FirebasePushService.instance.onPushAction = null;
    CallService.instance.onIncomingCall = null;
    CallService.instance.onError = null;
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_drainPendingPushActions());
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
    for (final action in actions) {
      await _handlePushAction(action);
    }
  }

  Future<void> _handlePushAction(PushAction action) async {
    if (action.type != PushActionType.rejectCall) {
      await _chat.syncAfterPush(action);
    }
    if (!mounted || _chat.profile == null) {
      return;
    }

    if (action.type == PushActionType.contactRequest) {
      setState(() {
        _homeTabIndex = 2;
        _homeRevision++;
      });
      _navigatorKey.currentState?.popUntil((route) => route.isFirst);
      return;
    }

    if (action.type == PushActionType.rejectCall) {
      await _chat.rejectPushCall(action);
      return;
    }

    if (action.type == PushActionType.incomingCall) {
      await _chat.syncAfterPush(action);
      final info = CallService.instance.incomingCall;
      if (!mounted || info == null || info.callId != action.requestId) {
        return;
      }
      if (CallService.instance.state != CallState.incoming) {
        return;
      }
      _navigatorKey.currentState?.popUntil((route) => route.isFirst);
      await _navigatorKey.currentState?.push(
        HestiaMotion.route((_) => CallScreen(peerNickname: info.fromNickname)),
      );
      await CallService.instance.acceptCall();
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
