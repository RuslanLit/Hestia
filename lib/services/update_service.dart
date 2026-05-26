import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config.dart';
import '../l10n/l10n.dart';

const String _kVersionUrl = AppConfig.defaultUpdateManifestUrl;

class _VersionInfo {
  final String version;
  final String build;
  final String downloadUrl;
  final String notes;

  const _VersionInfo({
    required this.version,
    required this.build,
    required this.downloadUrl,
    required this.notes,
  });

  factory _VersionInfo.fromJson(Map<String, dynamic> json) {
    final releasePageUrl = json['downloads_url'] as String? ??
        json['releaseNotesUrl'] as String? ??
        json['release_notes_url'] as String? ??
        '${AppConfig.officialWebsite}/downloads.html';

    return _VersionInfo(
      version: json['version'] as String? ?? '',
      build: (json['build'] as Object?)?.toString() ?? '',
      downloadUrl: releasePageUrl,
      notes: json['notes'] as String? ?? '',
    );
  }
}

bool _isNewer(String remote, String current) {
  try {
    final remoteParts = remote.split('.').map(int.parse).toList();
    final currentParts = current.split('.').map(int.parse).toList();
    final segmentCount = remoteParts.length > currentParts.length
        ? remoteParts.length
        : currentParts.length;
    for (var index = 0; index < segmentCount; index++) {
      final remotePart = index < remoteParts.length ? remoteParts[index] : 0;
      final currentPart = index < currentParts.length ? currentParts[index] : 0;
      if (remotePart > currentPart) return true;
      if (remotePart < currentPart) return false;
    }
    return false;
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

bool get _supportsManualUpdateCheck =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

Future<void> checkForUpdate(BuildContext context) async {
  debugPrint('[UpdateService] manual check started');

  if (!_supportsManualUpdateCheck) {
    if (context.mounted) {
      _showMessage(context, context.l10n.updatesAndroidOnly);
    }
    return;
  }

  try {
    final response = await http
        .get(Uri.parse(_kVersionUrl))
        .timeout(const Duration(seconds: 8));
    if (response.statusCode != 200) {
      throw Exception('http_status=${response.statusCode}');
    }

    final info = _VersionInfo.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
    debugPrint('[UpdateService] latest manifest fetched');

    final packageInfo = await PackageInfo.fromPlatform();
    final updateAvailable = _isNewerRelease(
      info.version,
      info.build,
      packageInfo.version,
      packageInfo.buildNumber,
    );
    debugPrint(
      '[UpdateService] version comparison '
      'current=${packageInfo.version}+${packageInfo.buildNumber} '
      'latest=${info.version}+${info.build}',
    );
    debugPrint('[UpdateService] update available=$updateAvailable');

    if (!context.mounted) return;
    if (!updateAvailable) {
      _showMessage(context, context.l10n.latestVersionInstalled);
      return;
    }

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) => _UpdateDialog(
        info: info,
        currentVersion: packageInfo.version,
      ),
    );
  } catch (error) {
    debugPrint('[UpdateService] manual check failed reason=$error');
    if (context.mounted) {
      _showMessage(context, context.l10n.updateCheckFailed);
    }
  }
}

void _showMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message)),
  );
}

class _UpdateDialog extends StatelessWidget {
  final _VersionInfo info;
  final String currentVersion;

  const _UpdateDialog({
    required this.info,
    required this.currentVersion,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.system_update, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Flexible(child: Text(l10n.updateAvailable)),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.currentVersionLabel(currentVersion)),
          const SizedBox(height: 4),
          Text(
            l10n.latestVersionLabel(info.version),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          if (info.notes.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              l10n.releaseNotes,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              info.notes,
              style: TextStyle(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 13,
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.later),
        ),
        FilledButton(
          onPressed: () async {
            Navigator.pop(context);
            await launchUrl(
              Uri.parse(info.downloadUrl),
              mode: LaunchMode.externalApplication,
            );
          },
          child: Text(l10n.openDownloadPage),
        ),
      ],
    );
  }
}
