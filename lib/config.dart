import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter/foundation.dart';

class AppConfig {
  static bool get enableFileAttachments => true;
  static bool get enableVoiceCalls => _voiceCallsEnabled;
  static bool get enableVideoCalls => _videoCallsEnabled;
  static bool get enablePushNotifications =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  static bool get enableBackupUi => false;
  static bool get enableKeyQrVerification => false;

  static const _serverKey = 'serverUrl';
  static const officialWebsite = 'https://hestiachat.site';
  static const defaultUpdateManifestUrl =
      'https://hestiachat.site/releases/latest.json';
  static const defaultHost = 'hestiachat.site';
  static const defaultHttpBase = 'https://hestiachat.site';
  static const defaultServerInput = 'wss://hestiachat.site/ws';
  static const fallbackHost = defaultHost;
  static const fallbackServerInput = defaultServerInput;

  static String host = defaultHost;
  static bool secure = true;
  static bool _customServer = false;
  static Uri _httpBaseUri = Uri.parse(defaultHttpBase);
  static Uri _wsUri = Uri.parse(defaultServerInput);
  static String _serverInput = defaultServerInput;
  static bool _blobTransferEnabled = true;
  static bool _voiceCallsEnabled = true;
  static bool _videoCallsEnabled = false;
  static String _blobUploadPath = '/api/upload_blob';
  static String _blobDownloadPath = '/api/download_blob/{blobId}';
  static String _legacyBlobUploadPath = '/upload_blob';
  static String _legacyBlobDownloadPath = '/download_blob/{blobId}';

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_serverKey);
    if (saved != null && saved.trim().isNotEmpty) {
      if (_shouldResetSavedServer(saved)) {
        _applyServerInput(defaultServerInput, custom: false);
        await prefs.setString(_serverKey, serverInput);
      } else {
        _applyServerInput(saved, custom: true);
      }
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

  static String get wsUrl => _withoutTrailingHash(_wsUri.toString());
  static String get httpUrl =>
      _withoutTrailingSlash(_withoutTrailingHash(_httpBaseUri.toString()));
  static String get configUrl => '$httpUrl/api/config';
  static List<String> get configUrls => [
        '$httpUrl/api/config',
        '$httpUrl/config',
      ];
  static String get uploadUrl => '$httpUrl/upload';
  static bool get blobTransferEnabled => _blobTransferEnabled;
  static String get uploadBlobUrl => _resolveHttpUrl(_blobUploadPath);
  static List<String> get uploadBlobUrls =>
      _uniqueUrls([_blobUploadPath, _legacyBlobUploadPath]);
  static String downloadBlobUrl(String blobId) =>
      downloadBlobUrls(blobId).first;
  static List<String> downloadBlobUrls(String blobId) => _uniqueUrls([
        _blobDownloadPath.replaceAll('{blobId}', Uri.encodeComponent(blobId)),
        _legacyBlobDownloadPath.replaceAll(
          '{blobId}',
          Uri.encodeComponent(blobId),
        ),
      ]);

  static void applyWebSocketPath(String path) {
    final normalizedPath = path.trim().isEmpty
        ? '/ws'
        : path.trim().startsWith('/')
            ? path.trim()
            : '/${path.trim()}';
    _wsUri = _httpBaseUri.replace(
      scheme: _httpBaseUri.scheme == 'https' ? 'wss' : 'ws',
      path: normalizedPath,
      query: '',
      fragment: '',
    );
  }

  static void applyBlobTransferConfig(Map<String, dynamic> config) {
    final enabled = config['enabled'];
    if (enabled is bool) {
      _blobTransferEnabled = enabled;
    }
    _blobUploadPath = _configuredPath(
      config['uploadPath'],
      fallback: _blobUploadPath,
    );
    _blobDownloadPath = _configuredPath(
      config['downloadPath'],
      fallback: _blobDownloadPath,
    );
    _legacyBlobUploadPath = _configuredPath(
      config['legacyUploadPath'],
      fallback: _legacyBlobUploadPath,
    );
    _legacyBlobDownloadPath = _configuredPath(
      config['legacyDownloadPath'],
      fallback: _legacyBlobDownloadPath,
    );
  }

  static bool applyFeatureConfig(Map<String, dynamic> features) {
    final previousVoiceCalls = _voiceCallsEnabled;
    final previousVideoCalls = _videoCallsEnabled;
    final voiceCalls = features['voiceCalls'];
    final videoCalls = features['videoCalls'];
    if (voiceCalls is bool) {
      _voiceCallsEnabled = voiceCalls;
    }
    if (videoCalls is bool) {
      _videoCallsEnabled = videoCalls;
    }
    if (!_voiceCallsEnabled) {
      _videoCallsEnabled = false;
    }
    return previousVoiceCalls != _voiceCallsEnabled ||
        previousVideoCalls != _videoCallsEnabled;
  }

  static bool switchToFallbackServer() {
    if (!isUsingDefaultServer) {
      return false;
    }
    if (fallbackServerInput == defaultServerInput) {
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
      _serverInput = _withoutTrailingHash(normalizedWs.toString());
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
    _serverInput =
        _withoutTrailingSlash(_withoutTrailingHash(httpBase.toString()));
  }

  static void _setHttpBase(Uri uri, {required bool custom}) {
    _httpBaseUri = uri.replace(path: '', query: '', fragment: '');
    host = _httpBaseUri.hasPort
        ? '${_httpBaseUri.host}:${_httpBaseUri.port}'
        : _httpBaseUri.host;
    secure = _httpBaseUri.scheme == 'https';
    _customServer = custom && host != defaultHost;
  }

  static String _configuredPath(dynamic value, {required String fallback}) {
    if (value is! String || value.trim().isEmpty) {
      return fallback;
    }
    final trimmed = value.trim();
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    return trimmed.startsWith('/') ? trimmed : '/$trimmed';
  }

  static List<String> _uniqueUrls(List<String> paths) {
    final seen = <String>{};
    final urls = <String>[];
    for (final path in paths) {
      final url = _resolveHttpUrl(path);
      if (seen.add(url)) {
        urls.add(url);
      }
    }
    return urls;
  }

  static String _resolveHttpUrl(String pathOrUrl) {
    final value = pathOrUrl.trim();
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return value;
    }
    final path = value.startsWith('/') ? value : '/$value';
    return _withoutTrailingHash(
      _httpBaseUri.replace(path: path, query: '', fragment: '').toString(),
    );
  }

  static String _withoutTrailingSlash(String value) {
    return value.endsWith('/') ? value.substring(0, value.length - 1) : value;
  }

  static String _withoutTrailingHash(String value) {
    return value.endsWith('#') ? value.substring(0, value.length - 1) : value;
  }

  static bool _shouldResetSavedServer(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) {
      return true;
    }
    try {
      final withScheme = trimmed.contains('://') ? trimmed : 'https://$trimmed';
      final uri = Uri.parse(withScheme);
      final host = uri.host.toLowerCase();
      return host == 'localhost' ||
          host == '127.0.0.1' ||
          host == '0.0.0.0' ||
          host == '::1';
    } catch (_) {
      return true;
    }
  }
}
