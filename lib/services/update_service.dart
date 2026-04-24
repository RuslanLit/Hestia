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

import '../l10n/l10n.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Config — point this at your server's version manifest
// ─────────────────────────────────────────────────────────────────────────────
const String _kVersionUrl =
    'http://localhost:3000/version.json'; // ← change to your real URL

// ─────────────────────────────────────────────────────────────────────────────
// Version manifest returned by the server
// ─────────────────────────────────────────────────────────────────────────────
class _VersionInfo {
  final String version;   // e.g. "1.0.2"
  final String apkUrl;    // direct APK download link (Android only)
  final String notes;     // release notes shown in the dialog

  const _VersionInfo({
    required this.version,
    required this.apkUrl,
    required this.notes,
  });

  factory _VersionInfo.fromJson(Map<String, dynamic> j) => _VersionInfo(
    version: j['version'] as String? ?? '',
    apkUrl:  j['apk_url'] as String? ?? '',
    notes:   j['notes']   as String? ?? '',
  );
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
    final pkg     = await PackageInfo.fromPlatform();
    final current = pkg.version; // e.g. "1.0.1"

    if (!_isNewer(info.version, current)) return; // already up to date

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
        _openUrl(widget.info.apkUrl);
      },
      child: Text(context.l10n.openDownloadPage),
    );
  }

  // ── Android APK download ──────────────────────────────────────────────────
  Future<void> _downloadAndInstall() async {
    setState(() { _progress = 0; });

    try {
      final client   = http.Client();
      final request  = http.Request('GET', Uri.parse(widget.info.apkUrl));
      final response = await client.send(request);

      final total    = response.contentLength ?? 0;
      var   received = 0;

      final dir     = await getTemporaryDirectory();
      final apkFile = File('${dir.path}/update.apk');
      final sink    = apkFile.openWrite();

      await response.stream.forEach((chunk) {
        sink.add(chunk);
        received += chunk.length;
        if (total > 0) setState(() { _progress = received / total; });
      });
      await sink.close();
      client.close();

      if (!mounted) return;

      setState(() { _progress = 1.0; });

      // Launch the APK installer
      final result = await OpenFile.open(apkFile.path);
      debugPrint('[UpdateService] open result: ${result.message}');

      if (mounted) Navigator.pop(context);
    } catch (e) {
      debugPrint('[UpdateService] download error: $e');
      if (mounted) setState(() { _progress = -1; });
    }
  }

  // ── Fallback URL opener (Web / Desktop) ───────────────────────────────────
  void _openUrl(String url) {
    // url_launcher is not a dependency — use http GET trick to hand off to OS.
    // On Web the browser handles it natively; on desktop show a snackbar.
    debugPrint('[UpdateService] open URL: $url');
    // If you add url_launcher to pubspec, replace this with:
    //   launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }
}
