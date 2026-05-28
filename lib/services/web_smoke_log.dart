import 'package:flutter/foundation.dart';

class WebSmokeLog {
  const WebSmokeLog._();

  static void log(String message) {
    if (kIsWeb) {
      debugPrint('[WebSmoke] $message');
    }
  }
}
