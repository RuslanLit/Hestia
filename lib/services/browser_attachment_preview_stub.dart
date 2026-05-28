import 'dart:typed_data';

class BrowserAttachmentPreview {
  static String? previewMimeType(String fileName, String kind) => null;

  static bool canPreview(String fileName, String kind) => false;

  static String? createObjectUrl({
    required String fileName,
    required String kind,
    required Uint8List bytes,
  }) =>
      null;

  static void openObjectUrl(String objectUrl) {}

  static void revokeObjectUrl(String objectUrl) {}
}
