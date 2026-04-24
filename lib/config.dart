import 'package:shared_preferences/shared_preferences.dart';

class AppConfig {
  static const _serverKey = 'serverUrl';
  static const officialWebsite = 'https://hestiachat.site';
  static const defaultUpdateManifestUrl =
      'https://hestiachat.site/releases/latest.json';
  static const defaultHost = 'api.hestiachat.site';
  static const defaultServerInput = 'https://api.hestiachat.site';
  static const fallbackHost = 'localhost:3000';
  static const fallbackServerInput = 'http://localhost:3000';

  static String host = defaultHost;
  static bool secure = true;
  static bool _customServer = false;

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_serverKey);
    if (saved != null && saved.trim().isNotEmpty) {
      _applyServerInput(saved, custom: true);
    } else {
      _applyServerInput(defaultServerInput, custom: false);
    }
  }

  static Future<void> setServerInput(String input) async {
    _applyServerInput(input, custom: input.trim().isNotEmpty);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_serverKey, serverInput);
  }

  static String get serverInput => '${secure ? 'https' : 'http'}://$host';
  static bool get isUsingDefaultServer => !_customServer && host == defaultHost;

  static String get wsUrl => '${secure ? 'wss' : 'ws'}://$host';
  static String get httpUrl => '${secure ? 'https' : 'http'}://$host';
  static String get uploadUrl => '$httpUrl/upload';
  static String get uploadBlobUrl => '$httpUrl/upload_blob';
  static String downloadBlobUrl(String blobId) =>
      '$httpUrl/download_blob/${Uri.encodeComponent(blobId)}';

  static bool switchToFallbackServer() {
    if (!isUsingDefaultServer) {
      return false;
    }
    _applyServerInput(fallbackServerInput, custom: false);
    return true;
  }

  static void _applyServerInput(String input, {required bool custom}) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) {
      host = defaultHost;
      secure = true;
      _customServer = false;
      return;
    }

    final withScheme = trimmed.contains('://') ? trimmed : 'https://$trimmed';
    final uri = Uri.parse(withScheme);
    if (uri.host.isEmpty) {
      throw FormatException('Invalid server URL: $input');
    }

    host = uri.hasPort ? '${uri.host}:${uri.port}' : uri.host;
    secure = uri.scheme == 'https' || uri.scheme == 'wss';
    _customServer = custom && host != defaultHost;
  }
}
