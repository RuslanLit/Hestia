import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

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

  static Future<StoredBackgroundImage?> pickAndSaveImage() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp'],
      withData: false,
    );
    final file = result?.files.single;
    final sourcePath = file?.path;
    if (file == null || sourcePath == null) {
      return null;
    }

    if (!_hasAllowedExtension(file.name)) {
      throw const FormatException('Unsupported image format.');
    }
    final source = File(sourcePath);
    final length = await source.length();
    if (length > maxImageBytes) {
      throw const FormatException('Image is too large.');
    }

    final directory = await _backgroundDirectory();
    final extension = _extensionFor(file.name);
    final target = File('${directory.path}${Platform.pathSeparator}background$extension');
    await source.copy(target.path);

    return StoredBackgroundImage(
      path: target.path,
      provider: _providerForFile(target),
    );
  }

  static Future<ImageProvider?> loadProvider(String path) async {
    final file = File(path);
    if (!await file.exists()) {
      return null;
    }
    return _providerForFile(file);
  }

  static Future<void> removeImage(String? path) async {
    if (path == null || path.isEmpty) {
      return;
    }
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }

  static ImageProvider _providerForFile(File file) {
    return ResizeImage.resizeIfNeeded(
      _targetDecodeWidth,
      null,
      FileImage(file),
    );
  }

  static Future<Directory> _backgroundDirectory() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final directory = Directory(
      '${docsDir.path}${Platform.pathSeparator}hestia${Platform.pathSeparator}background',
    );
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory;
  }

  static bool _hasAllowedExtension(String name) {
    final normalized = name.toLowerCase();
    return normalized.endsWith('.jpg') ||
        normalized.endsWith('.jpeg') ||
        normalized.endsWith('.png') ||
        normalized.endsWith('.webp');
  }

  static String _extensionFor(String name) {
    final normalized = name.toLowerCase();
    if (normalized.endsWith('.jpeg')) {
      return '.jpg';
    }
    if (normalized.endsWith('.png')) {
      return '.png';
    }
    if (normalized.endsWith('.webp')) {
      return '.webp';
    }
    return '.jpg';
  }
}


