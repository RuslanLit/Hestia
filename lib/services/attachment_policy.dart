import 'package:file_picker/file_picker.dart';

class AttachmentPolicy {
  static const fallbackMaxBytes = 50 * 1024 * 1024;
  static const maxConfiguredBytes = 250 * 1024 * 1024;
  static const documentMaxBytes = fallbackMaxBytes;
  static const imageMaxBytes = fallbackMaxBytes;
  static const audioMaxBytes = 100 * 1024 * 1024;
  static const videoMaxBytes = maxConfiguredBytes;
  static int _hardMaxBytes = videoMaxBytes;

  static int get hardMaxBytes => _hardMaxBytes;

  static final Set<String> blockedExtensions = {
    'exe',
    'msi',
    'apk',
    'ipa',
    'bat',
    'cmd',
    'sh',
    'ps1',
    'js',
    'vbs',
    'jar',
    'scr',
    'com',
    'dll',
    'so',
    'dylib',
    'bin',
    'deb',
    'rpm',
    'dmg',
    'app',
    'html',
    'htm',
    'php',
    'py',
    'rb',
    'pl',
  };

  static final Set<String> imageExtensions = {
    'jpg',
    'jpeg',
    'png',
    'webp',
    'gif',
    'heic',
    'heif',
  };

  static final Set<String> audioExtensions = {
    'mp3',
    'wav',
    'ogg',
    'm4a',
    'aac',
    'flac',
  };

  static final Set<String> videoExtensions = {
    'mp4',
    'mov',
    'webm',
    'mkv',
    'm4v',
    'mts',
    'm2ts',
    'ts',
  };

  static final Set<String> archiveExtensions = {
    'zip',
    '7z',
    'rar',
    'tar',
    'gz',
    'bz2',
    'xz',
  };

  static final Set<String> ebookExtensions = {
    'fb2',
    'epub',
    'mobi',
    'azw3',
    'djvu',
    'djv',
  };

  static final Map<String, int> _maxBytesByKind = {
    'document': documentMaxBytes,
    'archive': documentMaxBytes,
    'ebook': documentMaxBytes,
    'image': imageMaxBytes,
    'audio': audioMaxBytes,
    'video': videoMaxBytes,
  };

  static void applyBackendPolicy(Map<String, dynamic> policy) {
    final rawHardMaxBytes = policy['hardMaxBytes'];
    final hardMaxBytes = rawHardMaxBytes is num
        ? rawHardMaxBytes.toInt()
        : int.tryParse('$rawHardMaxBytes');
    if (hardMaxBytes != null &&
        hardMaxBytes > 0 &&
        hardMaxBytes <= maxConfiguredBytes) {
      _hardMaxBytes = hardMaxBytes;
    }

    final rawBlocked = policy['blockedExtensions'];
    if (rawBlocked is List) {
      final next = rawBlocked
          .whereType<String>()
          .map(_normalizeExtension)
          .where(_validPolicyExtension)
          .toSet();
      if (next.isNotEmpty) {
        blockedExtensions
          ..clear()
          ..addAll(next);
      }
    }

    final rawMaxBytesByKind = policy['maxBytesByKind'];
    if (rawMaxBytesByKind is Map) {
      for (final kind in const [
        'document',
        'archive',
        'ebook',
        'image',
        'audio',
        'video',
      ]) {
        _applyKindMaxBytes(
          rawMaxBytesByKind[kind],
          kind: kind,
          fallbackMaxBytes: _fallbackMaxBytesForKind(kind),
        );
      }
    } else {
      _applyLegacyKindPolicy(policy['document'],
          kind: 'document', fallbackMaxBytes: documentMaxBytes);
      _applyLegacyKindPolicy(policy['image'],
          kind: 'image', fallbackMaxBytes: imageMaxBytes);
      _applyLegacyKindPolicy(policy['audio'],
          kind: 'audio', fallbackMaxBytes: audioMaxBytes);
      _applyLegacyKindPolicy(policy['video'],
          kind: 'video', fallbackMaxBytes: videoMaxBytes);
    }

    final categoryMaxBytes = _maxBytesByKind.values.fold<int>(
      0,
      (max, value) => value > max ? value : max,
    );
    if (_hardMaxBytes < categoryMaxBytes) {
      _hardMaxBytes = categoryMaxBytes;
    }
  }

  static void _applyLegacyKindPolicy(
    Object? raw, {
    required String kind,
    required int fallbackMaxBytes,
  }) {
    if (raw is! Map) return;
    _applyKindMaxBytes(
      raw['maxBytes'],
      kind: kind,
      fallbackMaxBytes: fallbackMaxBytes,
    );
  }

  static void _applyKindMaxBytes(
    Object? raw, {
    required String kind,
    required int fallbackMaxBytes,
  }) {
    final maxBytes = raw is num ? raw.toInt() : int.tryParse('$raw');
    if (maxBytes != null && maxBytes > 0 && maxBytes <= maxConfiguredBytes) {
      _maxBytesByKind[kind] = maxBytes;
    } else {
      _maxBytesByKind.putIfAbsent(kind, () => fallbackMaxBytes);
    }
  }

  static int _fallbackMaxBytesForKind(String kind) => switch (kind) {
        'image' => imageMaxBytes,
        'audio' => audioMaxBytes,
        'video' => videoMaxBytes,
        'archive' => documentMaxBytes,
        'ebook' => documentMaxBytes,
        _ => documentMaxBytes,
      };

  static String extensionForName(String name) {
    final normalized = baseName(name).trim().toLowerCase();
    final index = normalized.lastIndexOf('.');
    if (index == -1 || index == normalized.length - 1) return '';
    return normalized.substring(index + 1);
  }

  static String baseName(String pathOrName) {
    final normalized = pathOrName.trim().replaceAll('\\', '/');
    final index = normalized.lastIndexOf('/');
    return index == -1 ? normalized : normalized.substring(index + 1);
  }

  static String sanitizeFileName(String name, {String fallbackId = 'file'}) {
    final normalized = baseName(name)
        .replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '_')
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim()
        .replaceAll(RegExp(r'^[. ]+|[. ]+$'), '');
    final rawExtension =
        extensionForName(normalized).replaceAll(RegExp(r'[^a-z0-9]'), '');
    final extension = rawExtension.length > 16
        ? rawExtension.substring(0, 16)
        : rawExtension;
    final suffix = extension.isEmpty ? '' : '.$extension';
    var base = extension.isEmpty
        ? normalized
        : normalized.substring(0, normalized.length - suffix.length);
    base = base.replaceAll(RegExp(r'^[. ]+|[. ]+$'), '');
    if (base.isEmpty) base = 'attachment_$fallbackId';
    const maxLength = 180;
    final maxBaseLength = (maxLength - suffix.length).clamp(1, maxLength);
    if (base.length > maxBaseLength) {
      base = base.substring(0, maxBaseLength).replaceAll(
            RegExp(r'[. ]+$'),
            '',
          );
    }
    if (base.isEmpty) base = 'attachment_$fallbackId';
    return '$base$suffix';
  }

  static String? kindForExtension(String extension) {
    final ext = _normalizeExtension(extension);
    if (imageExtensions.contains(ext)) return 'image';
    if (audioExtensions.contains(ext)) return 'audio';
    if (videoExtensions.contains(ext)) return 'video';
    if (archiveExtensions.contains(ext)) return 'archive';
    if (ebookExtensions.contains(ext)) return 'ebook';
    return 'document';
  }

  static String? kindForFileName(String name) =>
      kindForExtension(extensionForName(name));

  static int maxBytesForKind(String kind) {
    return _maxBytesByKind[kind] ?? documentMaxBytes;
  }

  static String describeLimits() {
    final document = _formatMegabytes(maxBytesForKind('document'));
    final image = _formatMegabytes(maxBytesForKind('image'));
    final audio = _formatMegabytes(maxBytesForKind('audio'));
    final video = _formatMegabytes(maxBytesForKind('video'));
    return 'Allowed files: any safe file type. Blocked: ${blockedExtensions.join(', ')}. Limits: documents/archives/ebooks/other $document, images $image, audio $audio, video $video. One file per message.';
  }

  static String diagnosticsSummary({required String source}) {
    return 'attachment policy loaded source=$source '
        'document=${maxBytesForKind('document')} '
        'image=${maxBytesForKind('image')} '
        'audio=${maxBytesForKind('audio')} '
        'video=${maxBytesForKind('video')} '
        'hard=$hardMaxBytes blocked=${blockedExtensions.length}';
  }

  static String _formatMegabytes(int bytes) {
    if (bytes <= 0) return '0 MB';
    final mb = bytes / (1024 * 1024);
    return mb == mb.roundToDouble()
        ? '${mb.toInt()} MB'
        : '${mb.toStringAsFixed(1)} MB';
  }

  static AttachmentValidationResult validatePlatformFile(
    PlatformFile file, {
    int? sizeBytes,
  }) {
    final nameExtension = extensionForName(file.name);
    final pickerExtension = _normalizeExtension(file.extension ?? '');
    final extension = nameExtension.isNotEmpty ? nameExtension : pickerExtension;
    return validateFileMetadata(
      name: baseName(file.name),
      extension: extension,
      sizeBytes: sizeBytes ?? file.size,
    );
  }

  static AttachmentValidationResult validateFileMetadata({
    required String name,
    required String extension,
    required int sizeBytes,
  }) {
    final safeName = baseName(name).trim();
    final ext = _normalizeExtension(extension);
    if (safeName.isEmpty) {
      _logValidation(
        extension: ext,
        mime: '',
        blocked: false,
        allowed: false,
        reason: 'missing_name',
        selectedKind: 'document',
        maxBytes: documentMaxBytes,
      );
      return const AttachmentValidationResult.invalid(
        'Attachment validation failed.',
      );
    }
    if (blockedExtensions.contains(ext)) {
      // ignore: avoid_print
      print('attachment reject source=client reason=blocked_extension ext=$ext');
      _logValidation(
        extension: ext,
        mime: '',
        blocked: true,
        allowed: false,
        reason: 'blocked_extension',
        selectedKind: 'document',
        maxBytes: documentMaxBytes,
      );
      return const AttachmentValidationResult.invalid(
        'Attachment type is blocked for safety.',
      );
    }

    final kind = kindForExtension(ext) ?? 'document';
    final maxBytes = maxBytesForKind(kind);
    if (sizeBytes <= 0) {
      _logValidation(
        extension: ext,
        mime: '',
        blocked: false,
        allowed: false,
        reason: 'invalid_size',
        selectedKind: kind,
        maxBytes: maxBytes,
      );
      return const AttachmentValidationResult.invalid(
        'Attachment validation failed.',
      );
    }
    if (sizeBytes > hardMaxBytes || sizeBytes > maxBytes) {
      _logValidation(
        extension: ext,
        mime: '',
        blocked: false,
        allowed: false,
        reason: 'too_large',
        selectedKind: kind,
        maxBytes: maxBytes,
      );
      return const AttachmentValidationResult.invalid(
        'Attachment is too large.',
      );
    }

    _logValidation(
      extension: ext,
      mime: '',
      blocked: false,
      allowed: true,
      reason: 'allowed_by_default',
      selectedKind: kind,
      maxBytes: maxBytes,
    );
    return AttachmentValidationResult.valid(
      extension: ext,
      kind: kind,
      sizeBytes: sizeBytes,
    );
  }

  static bool canOpenInPlace(String name, String kind) {
    final extension = extensionForName(name);
    return !blockedExtensions.contains(extension) &&
        {'document', 'archive', 'ebook', 'image', 'audio', 'video'}
            .contains(kind);
  }

  static String _normalizeExtension(String value) =>
      value.trim().toLowerCase().replaceFirst(RegExp(r'^\.+'), '');

  static bool _validPolicyExtension(String value) =>
      value.isNotEmpty && RegExp(r'^[a-z0-9]+$').hasMatch(value);

  static void _logValidation({
    required String extension,
    required String mime,
    required bool blocked,
    required bool allowed,
    required String reason,
    required String selectedKind,
    required int maxBytes,
  }) {
    // ignore: avoid_print
    print(
      'attachment validation extension=$extension mime=$mime '
      'isBlocked=$blocked selectedKind=$selectedKind maxBytes=$maxBytes '
      'validationResult=${allowed ? 'allowed' : 'rejected'} reason=$reason',
    );
  }
}

class AttachmentValidationResult {
  final bool isValid;
  final String? error;
  final String extension;
  final String kind;
  final int sizeBytes;

  const AttachmentValidationResult.valid({
    required this.extension,
    required this.kind,
    required this.sizeBytes,
  })  : isValid = true,
        error = null;

  const AttachmentValidationResult.invalid(this.error)
      : isValid = false,
        extension = '',
        kind = '',
        sizeBytes = 0;
}


