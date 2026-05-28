import 'package:flutter/foundation.dart';

class PlatformCapabilities {
  const PlatformCapabilities._();

  static bool get isWeb => kIsWeb;
  static bool get isAndroid =>
      !isWeb && defaultTargetPlatform == TargetPlatform.android;

  static bool get supportsLocalNotifications => isAndroid;
  static bool get supportsFirebasePush => isAndroid;
  static bool get supportsApkInstall => isAndroid;
  static bool get supportsForegroundService => isAndroid;
  static bool get supportsIoFilePaths => !isWeb;
  static bool get supportsPersistentAttachments => !isWeb;
  static bool get supportsForegroundFileTransfers =>
      isWeb || supportsPersistentAttachments;
  static bool get supportsForegroundVoiceCalls => isWeb || isAndroid;

  // Browser autoplay policy makes a ringtone unreliable without user input.
  static bool get supportsAutomaticRingtonePlayback => !isWeb;
}
