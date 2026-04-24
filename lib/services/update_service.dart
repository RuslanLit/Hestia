// update_service.dart
// Checks for a new app version and prompts the user to update.
//
// Platforms:
//   Android  → downloads APK and launches installer
//   iOS      → shows "update via TestFlight / App Store" message
//   Web/Desktop → shows dialog with a link to open manually
//
// Nothing in this file touches existing chat logic.

import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config.dart';
import '../l10n/l10n.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Config — official Hestia release manifest
// ─────────────────────────────────────────────────────────────────────────────
const String _kVersionUrl = AppConfig.defaultUpdateManifestUrl;

// ─────────────────────────────────────────────────────────────────────────────
// Version manifest returned by the server
// ─────────────────────────────────────────────────────────────────────────────
class _VersionInfo {
  final String version; // e.g. "1.0.2"
  final String build; // e.g. "12"
  final String apkUrl; // direct APK download link (Android only)
  final String downloadUrl; // current-platform installer or release page
  final String notes; // release notes shown in the dialog
  final bool platformAvailable;
  final String unavailableReason;

  const _VersionInfo({
    required this.version,
    required this.build,
    required this.apkUrl,
    required this.downloadUrl,
    required this.notes,
    required this.platformAvailable,
    required this.unavailableReason,
  });

  factory _VersionInfo.fromJson(Map<String, dynamic> j) {
    final platforms = j['platforms'];
    final platform = platforms is Map<String, dynamic>
        ? platforms[_currentPlatformKey()]
        : null;
    final platformMap =
        platform is Map<String, dynamic> ? platform : <String, dynamic>{};
    final available = platformMap['available'];
    final platformUrl = platformMap['url'] as String?;
    final legacyApkUrl = j['apk_url'] as String? ?? '';
    final legacyDownloadUrl = _legacyDownloadUrl(j);

    return _VersionInfo(
      version: j['version'] as String? ?? '',
      build: (j['build'] as Object?)?.toString() ?? '',
      apkUrl: legacyApkUrl,
      downloadUrl: platformUrl ?? legacyDownloadUrl,
      notes: j['notes'] as String? ??
          j['releaseNotesUrl'] as String? ??
          j['release_notes_url'] as String? ??
          '',
      platformAvailable: available is bool ? available : true,
      unavailableReason: platformMap['reason'] as String? ?? '',
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Simple semver comparison  ("1.2.3" > "1.2.2" → true)
// Only handles numeric segments — enough for a simple update system.
// ─────────────────────────────────────────────────────────────────────────────
bool _isNewer(String remote, String current) {
  try {
    final r = remote.split('.').map(int.parse).toList();
    final c = current.split('.').map(int.parse).toList();
    for (var i = 0; i < r.length && i < c.length; i++) {
      if (r[i] > c[i]) return true;
      if (r[i] < c[i]) return false;
    }
    return r.length > c.length;
  } catch (_) {
    return false;
  }
}

bool _isNewerRelease(
  String remoteVersion,
  String remoteBuild,
  String currentVersion,
  String currentBuild,
) {
  if (_isNewer(remoteVersion, currentVersion)) return true;
  if (_isNewer(currentVersion, remoteVersion)) return false;

  final remoteBuildNumber = int.tryParse(remoteBuild);
  final currentBuildNumber = int.tryParse(currentBuild);
  if (remoteBuildNumber == null || currentBuildNumber == null) return false;
  return remoteBuildNumber > currentBuildNumber;
}

String _currentPlatformKey() {
  if (kIsWeb) return 'webStatic';
  if (Platform.isAndroid) return 'android';
  if (Platform.isWindows) return 'windows';
  if (Platform.isLinux) return 'linuxAppImage';
  if (Platform.isMacOS) return 'macos';
  if (Platform.isIOS) return 'ios';
  return 'webStatic';
}

String _legacyDownloadUrl(Map<String, dynamic> j) {
  if (kIsWeb) {
    return j['web_url'] as String? ?? j['downloads_url'] as String? ?? '';
  }
  if (Platform.isAndroid) return j['apk_url'] as String? ?? '';
  if (Platform.isWindows) {
    return j['windows_url'] as String? ?? j['downloads_url'] as String? ?? '';
  }
  if (Platform.isLinux) {
    return j['linux_appimage_url'] as String? ??
        j['downloads_url'] as String? ??
        '';
  }
  if (Platform.isMacOS) {
    return j['macos_dmg_url'] as String? ?? j['downloads_url'] as String? ?? '';
  }
  return j['downloads_url'] as String? ?? '';
}

// ─────────────────────────────────────────────────────────────────────────────
// Public entry point
// Call this once from AppShell.initState() after the first frame.
// It is fully self-contained — shows its own dialog, never throws.
// ─────────────────────────────────────────────────────────────────────────────
Future<void> checkForUpdate(BuildContext context) async {
  try {
    // 1. Fetch version manifest
    final response = await http
        .get(Uri.parse(_kVersionUrl))
        .timeout(const Duration(seconds: 8));

    if (response.statusCode != 200) return; // server not reachable — silent
    final info = _VersionInfo.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);

    // 2. Get current app version
    final pkg = await PackageInfo.fromPlatform();
    final current = pkg.version; // e.g. "1.0.1"

    if (!_isNewerRelease(info.version, info.build, current, pkg.buildNumber)) {
      return; // already up to date
    }
    if (!info.platformAvailable) {
      debugPrint(
        '[UpdateService] update not available for this platform: '
        '${info.unavailableReason}',
      );
      return;
    }

    // 3. Show update dialog (must still be mounted)
    if (!context.mounted) return;
    await _showUpdateDialog(context, info);
  } catch (e) {
    // Network unavailable, JSON malformed, etc. — never crash the app.
    debugPrint('[UpdateService] check failed: $e');
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Update dialog
// ─────────────────────────────────────────────────────────────────────────────
Future<void> _showUpdateDialog(BuildContext context, _VersionInfo info) {
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => _UpdateDialog(info: info),
  );
}

class _UpdateDialog extends StatefulWidget {
  final _VersionInfo info;
  const _UpdateDialog({required this.info});

  @override
  State<_UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<_UpdateDialog> {
  // Download progress: null = idle, 0.0–1.0 = downloading, -1 = error
  double? _progress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    return AlertDialog(
      title: Row(children: [
        Icon(Icons.system_update, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Text(l10n.updateAvailable),
      ]),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.versionAvailable(widget.info.version),
              style: const TextStyle(fontWeight: FontWeight.w600)),
          if (widget.info.notes.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(widget.info.notes,
                style: TextStyle(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 13,
                )),
          ],
          if (_progress != null && _progress! >= 0) ...[
            const SizedBox(height: 16),
            LinearProgressIndicator(value: _progress == 0 ? null : _progress),
            const SizedBox(height: 4),
            Text(
              _progress == 0
                  ? l10n.startingDownload
                  : l10n.downloadingProgress(
                      (_progress! * 100).toStringAsFixed(0),
                    ),
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          if (_progress == -1) ...[
            const SizedBox(height: 12),
            Text(l10n.downloadFailedRetry,
                style: TextStyle(
                  color: theme.colorScheme.error,
                  fontSize: 13,
                )),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.later),
        ),
        _buildUpdateButton(context),
      ],
    );
  }

  Widget _buildUpdateButton(BuildContext context) {
    // Downloading — disable button
    if (_progress != null && _progress! >= 0 && _progress! < 1.0) {
      return FilledButton(
        onPressed: null,
        child: Text(context.l10n.downloading),
      );
    }

    // ── iOS: direct to TestFlight / App Store ──────────────────────────────
    if (!kIsWeb && Platform.isIOS) {
      return FilledButton(
        onPressed: () => Navigator.pop(context),
        child: Text(context.l10n.updateViaAppStore),
      );
    }

    // ── Android: download and install APK ─────────────────────────────────
    if (!kIsWeb && Platform.isAndroid) {
      return FilledButton(
        onPressed: _progress == null ? _downloadAndInstall : null,
        child: Text(context.l10n.downloadAndInstall),
      );
    }

    // ── Web / Desktop: open download link in browser ─────────────────────
    return FilledButton(
      onPressed: () {
        Navigator.pop(context);
        _openUrl(widget.info.downloadUrl);
      },
      child: Text(context.l10n.openDownloadPage),
    );
  }

  // ── Android APK download ──────────────────────────────────────────────────
  Future<void> _downloadAndInstall() async {
    setState(() {
      _progress = 0;
    });

    try {
      final client = http.Client();
      final request = http.Request('GET', Uri.parse(widget.info.downloadUrl));
      final response = await client.send(request);

      final total = response.contentLength ?? 0;
      var received = 0;

      final dir = await getTemporaryDirectory();
      final apkFile = File('${dir.path}/update.apk');
      final sink = apkFile.openWrite();

      await response.stream.forEach((chunk) {
        sink.add(chunk);
        received += chunk.length;
        if (total > 0) {
          setState(() {
            _progress = received / total;
          });
        }
      });
      await sink.close();
      client.close();

      if (!mounted) return;

      setState(() {
        _progress = 1.0;
      });

      // Launch the APK installer
      final result = await OpenFile.open(apkFile.path);
      debugPrint('[UpdateService] open result: ${result.message}');

      if (mounted) Navigator.pop(context);
    } catch (e) {
      debugPrint('[UpdateService] download error: $e');
      if (mounted) {
        setState(() {
          _progress = -1;
        });
      }
    }
  }

  // ── Fallback URL opener (Web / Desktop) ───────────────────────────────────
  Future<void> _openUrl(String url) async {
    debugPrint('[UpdateService] open URL: $url');
    if (url.isEmpty) return;
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }
}
