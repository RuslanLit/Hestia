import 'package:shared_preferences/shared_preferences.dart';

class AppConfig {
  static const _serverKey = 'serverUrl';
  static const officialWebsite = 'https://hestiachat.site';
  static const defaultUpdateManifestUrl =
      'https://hestiachat.site/releases/latest.json';
  static const defaultHost = 'hestiachat.site';
  static const defaultHttpBase = 'https://hestiachat.site';
  static const defaultServerInput = 'wss://hestiachat.site/ws';
  static const fallbackHost = 'localhost:3000';
  static const fallbackServerInput = 'ws://localhost:3000/ws';

  static String host = defaultHost;
  static bool secure = true;
  static bool _customServer = false;
  static Uri _httpBaseUri = Uri.parse(defaultHttpBase);
  static Uri _wsUri = Uri.parse(defaultServerInput);
  static String _serverInput = defaultServerInput;

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

  static String get serverInput => _serverInput;
  static bool get isUsingDefaultServer =>
      !_customServer && host == defaultHost && wsUrl == defaultServerInput;

  static String get wsUrl => _wsUri.toString();
  static String get httpUrl => _withoutTrailingSlash(_httpBaseUri.toString());
  static String get configUrl => '$httpUrl/api/config';
  static String get uploadUrl => '$httpUrl/upload';
  static String get uploadBlobUrl => '$httpUrl/api/upload_blob';
  static String downloadBlobUrl(String blobId) =>
      '$httpUrl/api/download_blob/${Uri.encodeComponent(blobId)}';

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
      _setHttpBase(Uri.parse(defaultHttpBase), custom: false);
      _wsUri = Uri.parse(defaultServerInput);
      _serverInput = defaultServerInput;
      return;
    }

    final withScheme = trimmed.contains('://') ? trimmed : 'https://$trimmed';
    final uri = Uri.parse(withScheme);
    if (uri.host.isEmpty) {
      throw FormatException('Invalid server URL: $input');
    }

    final scheme = uri.scheme.toLowerCase();
    if (scheme == 'ws' || scheme == 'wss') {
      final normalizedWs = uri.replace(
        scheme: scheme,
        path: uri.path.isEmpty ? '/ws' : uri.path,
        query: '',
        fragment: '',
      );
      final httpScheme = scheme == 'wss' ? 'https' : 'http';
      _setHttpBase(
        normalizedWs.replace(
          scheme: httpScheme,
          path: '',
          query: '',
          fragment: '',
        ),
        custom: custom,
      );
      _wsUri = normalizedWs;
      _serverInput = normalizedWs.toString();
      return;
    }

    if (scheme != 'http' && scheme != 'https') {
      throw FormatException('Unsupported server URL scheme: ${uri.scheme}');
    }

    final httpBase = uri.replace(path: '', query: '', fragment: '');
    _setHttpBase(httpBase, custom: custom);
    _wsUri = httpBase.replace(
      scheme: scheme == 'https' ? 'wss' : 'ws',
      path: '/ws',
      query: '',
      fragment: '',
    );
    _serverInput = _withoutTrailingSlash(httpBase.toString());
  }

  static void _setHttpBase(Uri uri, {required bool custom}) {
    _httpBaseUri = uri.replace(path: '', query: '', fragment: '');
    host = _httpBaseUri.hasPort
        ? '${_httpBaseUri.host}:${_httpBaseUri.port}'
        : _httpBaseUri.host;
    secure = _httpBaseUri.scheme == 'https';
    _customServer = custom && host != defaultHost;
  }

  static String _withoutTrailingSlash(String value) {
    return value.endsWith('/') ? value.substring(0, value.length - 1) : value;
  }
}
