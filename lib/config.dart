import 'package:shared_preferences/shared_preferences.dart';

class AppConfig {
  static const _serverKey = 'serverUrl';
  static const defaultHost = 'localhost:3000';

  static String host = 'localhost:3000';
  static bool secure = false;

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_serverKey);
    if (saved != null && saved.trim().isNotEmpty) {
      _applyServerInput(saved);
    }
  }

  static Future<void> setServerInput(String input) async {
    _applyServerInput(input);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_serverKey, serverInput);
  }

  static String get serverInput => '${secure ? 'https' : 'http'}://$host';

  static String get wsUrl => '${secure ? 'wss' : 'ws'}://$host';
  static String get httpUrl => '${secure ? 'https' : 'http'}://$host';
  static String get uploadUrl => '$httpUrl/upload';
  static String get uploadBlobUrl => '$httpUrl/upload_blob';
  static String downloadBlobUrl(String blobId) =>
      '$httpUrl/download_blob/${Uri.encodeComponent(blobId)}';

  static void _applyServerInput(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) {
      host = defaultHost;
      secure = false;
      return;
    }

    final withScheme = trimmed.contains('://') ? trimmed : 'http://$trimmed';
    final uri = Uri.parse(withScheme);
    if (uri.host.isEmpty) {
      throw FormatException('Invalid server URL: $input');
    }

    host = uri.hasPort ? '${uri.host}:${uri.port}' : uri.host;
    secure = uri.scheme == 'https' || uri.scheme == 'wss';
  }
}
