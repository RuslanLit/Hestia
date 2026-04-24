import 'package:file_picker/file_picker.dart';

class AttachmentPolicy {
  static const imageMaxBytes = 25 * 1024 * 1024;
  static const audioMaxBytes = 50 * 1024 * 1024;
  static const documentMaxBytes = 50 * 1024 * 1024;
  static const videoMaxBytes = 200 * 1024 * 1024;
  static const hardMaxBytes = videoMaxBytes;

  static const documentExtensions = {
    'pdf',
    'doc',
    'docx',
    'xls',
    'xlsx',
    'ppt',
    'pptx',
    'odt',
    'ods',
    'odp',
    'rtf',
    'txt',
    'csv',
  };

  static const imageExtensions = {
    'jpg',
    'jpeg',
    'png',
    'webp',
    'gif',
    'heic',
    'heif',
  };

  static const videoExtensions = {
    'mp4',
    'mov',
    'webm',
    'mkv',
    'm4v',
  };

  static const audioExtensions = {
    'mp3',
    'wav',
    'ogg',
    'm4a',
    'aac',
    'flac',
  };

  static const allowedExtensions = {
    ...documentExtensions,
    ...imageExtensions,
    ...videoExtensions,
    ...audioExtensions,
  };

  static String extensionForName(String name) {
    final normalized = name.trim().toLowerCase();
    final index = normalized.lastIndexOf('.');
    if (index == -1 || index == normalized.length - 1) {
      return '';
    }
    return normalized.substring(index + 1);
  }

  static String? kindForExtension(String extension) {
    final ext = extension.toLowerCase();
    if (imageExtensions.contains(ext)) return 'image';
    if (videoExtensions.contains(ext)) return 'video';
    if (audioExtensions.contains(ext)) return 'audio';
    if (documentExtensions.contains(ext)) return 'document';
    return null;
  }

  static int maxBytesForKind(String kind) {
    switch (kind) {
      case 'image':
        return imageMaxBytes;
      case 'audio':
        return audioMaxBytes;
      case 'video':
        return videoMaxBytes;
      case 'document':
        return documentMaxBytes;
      default:
        return 0;
    }
  }

  static String describeLimits() {
    return 'Allowed files: documents, images, audio and video. Limits: images 25 MB, audio/documents 50 MB, video 200 MB.';
  }

  static AttachmentValidationResult validatePlatformFile(PlatformFile file) {
    final extension =
        (file.extension ?? extensionForName(file.name)).toLowerCase();
    return validateFileMetadata(
      name: file.name,
      extension: extension,
      sizeBytes: file.size,
    );
  }

  static AttachmentValidationResult validateFileMetadata({
    required String name,
    required String extension,
    required int sizeBytes,
  }) {
    final kind = kindForExtension(extension);
    if (name.trim().isEmpty || extension.isEmpty || kind == null) {
      return const AttachmentValidationResult.invalid(
        'Attachment type is not allowed.',
      );
    }

    final maxBytes = maxBytesForKind(kind);
    if (sizeBytes <= 0) {
      return const AttachmentValidationResult.invalid(
        'Attachment validation failed.',
      );
    }
    if (sizeBytes > hardMaxBytes || sizeBytes > maxBytes) {
      return const AttachmentValidationResult.invalid(
        'Attachment is too large.',
      );
    }

    return AttachmentValidationResult.valid(
      extension: extension,
      kind: kind,
      sizeBytes: sizeBytes,
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
