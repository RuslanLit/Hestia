import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'web_large_storage_stub.dart'
    if (dart.library.html) 'web_large_storage_web.dart';

class StoredBackgroundImage {
  final String path;
  final ImageProvider provider;

  const StoredBackgroundImage({
    required this.path,
    required this.provider,
  });
}

class BackgroundImageStore {
  static const maxImageBytes = 6 * 1024 * 1024;
  static const _targetDecodeWidth = 1600;
  static const _imageKey = 'hestia_background_image_v1';

  static Future<StoredBackgroundImage?> pickAndSaveImage() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp'],
      withData: true,
    );
    final file = result?.files.single;
    final bytes = file?.bytes;
    if (file == null || bytes == null) {
      return null;
    }

    if (!_hasAllowedExtension(file.name)) {
      throw const FormatException('Unsupported image format.');
    }
    if (bytes.length > maxImageBytes) {
      throw const FormatException('Image is too large.');
    }

    await WebLargeStorage.setString(_imageKey, base64Encode(bytes));
    return StoredBackgroundImage(
      path: _imageKey,
      provider: _providerForBytes(bytes),
    );
  }

  static Future<ImageProvider?> loadProvider(String path) async {
    final raw = await WebLargeStorage.getString(path);
    if (raw == null || raw.isEmpty) {
      return null;
    }
    return _providerForBytes(base64Decode(raw));
  }

  static Future<void> removeImage(String? path) async {
    if (path == null || path.isEmpty) {
      return;
    }
    await WebLargeStorage.remove(path);
  }

  static ImageProvider _providerForBytes(List<int> bytes) {
    return ResizeImage.resizeIfNeeded(
      _targetDecodeWidth,
      null,
      MemoryImage(Uint8List.fromList(bytes)),
    );
  }

  static bool _hasAllowedExtension(String name) {
    final normalized = name.toLowerCase();
    return normalized.endsWith('.jpg') ||
        normalized.endsWith('.jpeg') ||
        normalized.endsWith('.png') ||
        normalized.endsWith('.webp');
  }
}
