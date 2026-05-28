import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config.dart';
import '../l10n/l10n.dart';
import 'platform_capabilities.dart';

const String _kVersionUrl = AppConfig.defaultUpdateManifestUrl;
const MethodChannel _updateChannel = MethodChannel('hestia/app_update');

class _VersionInfo {
  final String version;
  final String build;
  final String downloadUrl;
  final String notes;
  final _AndroidArtifact? androidArtifact;

  const _VersionInfo({
    required this.version,
    required this.build,
    required this.downloadUrl,
    required this.notes,
    required this.androidArtifact,
  });

  static Future<_VersionInfo> fromJson(Map<String, dynamic> json) async {
    final releasePageUrl = json['downloads_url'] as String? ??
        json['releaseNotesUrl'] as String? ??
        json['release_notes_url'] as String? ??
        '${AppConfig.officialWebsite}/downloads.html';

    return _VersionInfo(
      version: json['version'] as String? ?? '',
      build: (json['build'] as Object?)?.toString() ?? '',
      downloadUrl: releasePageUrl,
      notes: json['notes'] as String? ?? '',
      androidArtifact: _supportsManualUpdateCheck
          ? await _selectAndroidArtifact(json)
          : null,
    );
  }
}

class _AndroidArtifact {
  final String abi;
  final String platformKey;
  final String url;
  final String expectedSha256;
  final String fileName;

  const _AndroidArtifact({
    required this.abi,
    required this.platformKey,
    required this.url,
    required this.expectedSha256,
    required this.fileName,
  });

  bool get canVerify => url.isNotEmpty && expectedSha256.isNotEmpty;
}

Future<_AndroidArtifact?> _selectAndroidArtifact(
  Map<String, dynamic> manifest,
) async {
  final androidInfo = await DeviceInfoPlugin().androidInfo;
  final supportedAbis = androidInfo.supportedAbis
      .map((abi) => abi.toLowerCase())
      .toList(growable: false);
  final selectedAbi = supportedAbis.firstWhere(
    _abiPlatformKeys.containsKey,
    orElse: () => supportedAbis.isNotEmpty ? supportedAbis.first : 'unknown',
  );
  final platformKey = _abiPlatformKeys[selectedAbi];
  debugPrint('[UpdateService] selected ABI $selectedAbi');
  debugPrint(
    '[UpdateService] selected platform key ${platformKey ?? 'fallback'}',
  );

  final platforms = manifest['platforms'];
  final platform = platforms is Map<String, dynamic> && platformKey != null
      ? platforms[platformKey]
      : null;
  if (platform is Map<String, dynamic>) {
    return _AndroidArtifact(
      abi: selectedAbi,
      platformKey: platformKey!,
      url: platform['url'] as String? ?? '',
      expectedSha256: platform['sha256'] as String? ?? '',
      fileName: platform['file'] as String? ?? '',
    );
  }

  final fallbackUrl = manifest['apk_url'] as String? ?? '';
  if (fallbackUrl.isEmpty) return null;
  return _AndroidArtifact(
    abi: selectedAbi,
    platformKey: 'apk_url',
    url: fallbackUrl,
    expectedSha256: manifest['apk_sha256'] as String? ??
        manifest['sha256'] as String? ??
        '',
    fileName: '',
  );
}

const _abiPlatformKeys = <String, String>{
  'arm64-v8a': 'androidArm64',
  'armeabi-v7a': 'androidArmv7',
  'x86_64': 'androidX64',
};

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
    PlatformCapabilities.supportsApkInstall;

Future<void> checkForUpdate(BuildContext context) async {
  debugPrint('[UpdateService] manual check started');

  if (!_supportsManualUpdateCheck) {
    if (PlatformCapabilities.isWeb) {
      debugPrint('[WebPlatform] updater install disabled reason=web');
    }
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

    final info = await _VersionInfo.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
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

class _UpdateDialog extends StatefulWidget {
  final _VersionInfo info;
  final String currentVersion;

  const _UpdateDialog({
    required this.info,
    required this.currentVersion,
  });

  @override
  State<_UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<_UpdateDialog> {
  double? _progress;
  bool? _verified;
  bool _downloading = false;
  bool _installPermissionRequired = false;
  bool _installPackageMismatch = false;
  File? _verifiedFile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final artifact = widget.info.androidArtifact;
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.system_update, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Flexible(child: Text(l10n.updateAvailable)),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.currentVersionLabel(widget.currentVersion)),
            const SizedBox(height: 4),
            Text(
              l10n.latestVersionLabel(widget.info.version),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            if (widget.info.notes.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                l10n.releaseNotes,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                widget.info.notes,
                style: TextStyle(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 13,
                ),
              ),
            ],
            if (artifact == null || !artifact.canVerify) ...[
              const SizedBox(height: 12),
              Text(
                l10n.downloadUnavailableForDevice,
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ],
            if (_downloading) ...[
              const SizedBox(height: 16),
              LinearProgressIndicator(value: _progress),
              const SizedBox(height: 4),
              Text(
                _progress == null
                    ? l10n.downloading
                    : l10n.downloadingProgress(
                        (_progress! * 100).round().toString(),
                      ),
              ),
            ],
            if (_verified != null) ...[
              const SizedBox(height: 12),
              Text(
                _verified!
                    ? l10n.downloadVerified
                    : l10n.downloadVerificationFailed,
                style: TextStyle(
                  color: _verified!
                      ? theme.colorScheme.primary
                      : theme.colorScheme.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            if (_installPermissionRequired) ...[
              const SizedBox(height: 12),
              Text(
                l10n.installPermissionRequired,
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ],
            if (_installPackageMismatch) ...[
              const SizedBox(height: 12),
              Text(
                l10n.updatePackageMismatch,
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ],
          ],
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
      actions: [
        SizedBox(
          width: double.infinity,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(l10n.later),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: _openDownloadPage,
                child: Text(l10n.openDownloadPage),
              ),
              const SizedBox(height: 8),
              FilledButton.tonal(
                onPressed: !_downloading &&
                        _verified != true &&
                        artifact?.canVerify == true
                    ? () => _downloadAndVerify(artifact!)
                    : null,
                child: Text(_downloading ? l10n.downloading : l10n.downloadApk),
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: _verified == true &&
                        _verifiedFile != null &&
                        !_installPackageMismatch
                    ? _installVerifiedDownload
                    : null,
                child: Text(l10n.installVerifiedDownload),
              ),
              if (_installPermissionRequired) ...[
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: _openInstallPermissionSettings,
                  child: Text(l10n.openInstallSettings),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _openDownloadPage() async {
    await launchUrl(
      Uri.parse(widget.info.downloadUrl),
      mode: LaunchMode.externalApplication,
    );
  }

  Future<void> _downloadAndVerify(_AndroidArtifact artifact) async {
    if (!PlatformCapabilities.supportsApkInstall) {
      if (PlatformCapabilities.isWeb) {
        debugPrint('[WebPlatform] updater install disabled reason=web');
      }
      _showMessage(context, context.l10n.updatesAndroidOnly);
      return;
    }
    setState(() {
      _downloading = true;
      _progress = null;
      _verified = null;
      _installPermissionRequired = false;
      _installPackageMismatch = false;
      _verifiedFile = null;
    });
    debugPrint('[UpdateService] download started');

    File? target;
    http.Client? client;
    IOSink? sink;
    try {
      final downloadsDir = Directory(
        '${(await getTemporaryDirectory()).path}${Platform.pathSeparator}updates',
      );
      await downloadsDir.create(recursive: true);
      target = File(
        '${downloadsDir.path}${Platform.pathSeparator}${_safeFileName(artifact)}',
      );

      client = http.Client();
      final response =
          await client.send(http.Request('GET', Uri.parse(artifact.url)));
      if (response.statusCode != 200) {
        throw Exception('http_status=${response.statusCode}');
      }
      final totalBytes = response.contentLength;
      var receivedBytes = 0;
      var lastLoggedPercent = -10;
      sink = target.openWrite();
      await for (final chunk in response.stream) {
        sink.add(chunk);
        receivedBytes += chunk.length;
        if (totalBytes != null && totalBytes > 0) {
          final percent = ((receivedBytes / totalBytes) * 100).floor();
          if (percent >= lastLoggedPercent + 10 || percent == 100) {
            lastLoggedPercent = percent;
            debugPrint('[UpdateService] download progress $percent%');
          }
          if (mounted) {
            setState(
              () => _progress = (receivedBytes / totalBytes).clamp(0.0, 1.0),
            );
          }
        }
      }
      if (totalBytes == null || totalBytes <= 0) {
        debugPrint(
          '[UpdateService] download progress bytes=$receivedBytes complete=true',
        );
      } else if (lastLoggedPercent < 100) {
        debugPrint('[UpdateService] download progress 100%');
      }
      await sink.close();
      sink = null;

      final actualSha256 =
          (await sha256.bind(target.openRead()).first).toString();
      final verified =
          actualSha256.toLowerCase() == artifact.expectedSha256.toLowerCase();
      debugPrint('[UpdateService] sha256 calculated');
      debugPrint('[UpdateService] sha256 verified=$verified');
      if (!verified) {
        await target.delete();
      } else if (kDebugMode) {
        debugPrint('[UpdateService] verified local path ${target.path}');
      }
      if (!mounted) return;
      setState(() {
        _downloading = false;
        _progress = verified ? 1 : null;
        _verified = verified;
        _verifiedFile = verified ? target : null;
      });
      _showMessage(
        context,
        verified
            ? context.l10n.downloadVerified
            : context.l10n.downloadVerificationFailed,
      );
    } catch (error) {
      debugPrint('[UpdateService] download failed reason=$error');
      await sink?.close();
      if (target != null && await target.exists()) {
        await target.delete();
      }
      if (!mounted) return;
      setState(() {
        _downloading = false;
        _progress = null;
        _verified = false;
        _verifiedFile = null;
      });
      _showMessage(context, context.l10n.downloadFailedRetry);
    } finally {
      client?.close();
    }
  }

  Future<void> _installVerifiedDownload() async {
    if (!PlatformCapabilities.supportsApkInstall) {
      if (PlatformCapabilities.isWeb) {
        debugPrint('[WebPlatform] updater install disabled reason=web');
      }
      _showMessage(context, context.l10n.updatesAndroidOnly);
      return;
    }
    final verifiedFile = _verifiedFile;
    if (_verified != true || verifiedFile == null) return;
    if (!await verifiedFile.exists()) {
      if (!mounted) return;
      setState(() {
        _verified = false;
        _verifiedFile = null;
      });
      _showMessage(context, context.l10n.downloadVerificationFailed);
      return;
    }

    try {
      debugPrint('[UpdateService] install requested');
      final outcome = await _updateChannel.invokeMethod<String>(
        'installVerifiedApk',
        <String, String>{'path': verifiedFile.path},
      );
      if (!mounted) return;
      if (outcome == 'permission_required') {
        setState(() => _installPermissionRequired = true);
        _showMessage(context, context.l10n.installPermissionRequired);
        return;
      }
      if (outcome == 'package_mismatch') {
        debugPrint('[UpdateService] install blocked reason=package_mismatch');
        setState(() => _installPackageMismatch = true);
        _showMessage(context, context.l10n.updatePackageMismatch);
        return;
      }
      if (outcome != 'opened') {
        throw Exception('installer_result=$outcome');
      }
      debugPrint('[UpdateService] system installer opened');
    } catch (error) {
      debugPrint('[UpdateService] install failed reason=$error');
      if (mounted) {
        _showMessage(context, context.l10n.installOpenFailed);
      }
    }
  }

  Future<void> _openInstallPermissionSettings() async {
    if (!PlatformCapabilities.supportsApkInstall) {
      if (PlatformCapabilities.isWeb) {
        debugPrint('[WebPlatform] updater install disabled reason=web');
      }
      _showMessage(context, context.l10n.updatesAndroidOnly);
      return;
    }
    final opened = await _updateChannel
        .invokeMethod<bool>('openInstallPermissionSettings');
    if (!mounted || opened == true) return;
    _showMessage(context, context.l10n.installOpenFailed);
  }

  String _safeFileName(_AndroidArtifact artifact) {
    final suggested = artifact.fileName.isNotEmpty
        ? artifact.fileName
        : 'hestia-${widget.info.version}-${artifact.abi}.apk';
    return suggested.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
  }
}
