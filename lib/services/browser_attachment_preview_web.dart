import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'attachment_policy.dart';

class BrowserAttachmentPreview {
  static const _mimeByExtension = <String, String>{
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'png': 'image/png',
    'gif': 'image/gif',
    'webp': 'image/webp',
    'pdf': 'application/pdf',
    'txt': 'text/plain; charset=utf-8',
    'csv': 'text/csv; charset=utf-8',
    'md': 'text/markdown; charset=utf-8',
    'json': 'application/json; charset=utf-8',
    'yaml': 'text/plain; charset=utf-8',
    'yml': 'text/plain; charset=utf-8',
    'ini': 'text/plain; charset=utf-8',
    'log': 'text/plain; charset=utf-8',
    'mp3': 'audio/mpeg',
    'wav': 'audio/wav',
    'ogg': 'audio/ogg',
    'm4a': 'audio/mp4',
    'aac': 'audio/aac',
    'flac': 'audio/flac',
    'mp4': 'video/mp4',
    'webm': 'video/webm',
    'm4v': 'video/mp4',
    'mov': 'video/quicktime',
  };

  static String? previewMimeType(String fileName, String kind) {
    final extension = AttachmentPolicy.extensionForName(fileName);
    return _mimeByExtension[extension];
  }

  static bool canPreview(String fileName, String kind) =>
      previewMimeType(fileName, kind) != null;

  static String? createObjectUrl({
    required String fileName,
    required String kind,
    required Uint8List bytes,
  }) {
    final mimeType = previewMimeType(fileName, kind);
    if (mimeType == null || bytes.isEmpty) {
      debugWebFile(
        'unsupported preview type=${AttachmentPolicy.extensionForName(fileName).isEmpty ? kind : AttachmentPolicy.extensionForName(fileName)}',
      );
      return null;
    }
    final blob = web.Blob(
      <JSUint8Array>[bytes.toJS].toJS,
      web.BlobPropertyBag(type: mimeType),
    );
    final objectUrl = web.URL.createObjectURL(blob);
    debugWebFile('object URL created type=$mimeType size=${bytes.length}');
    return objectUrl;
  }

  static void openObjectUrl(String objectUrl) {
    debugWebFile('open triggered');
    web.window.open(objectUrl, '_blank', 'noopener,noreferrer');
  }

  static void revokeObjectUrl(String objectUrl) {
    web.URL.revokeObjectURL(objectUrl);
    debugWebFile('object URL revoked');
  }
}

void debugWebFile(String message) {
  // ignore: avoid_print
  print('[WebFile] $message');
}
