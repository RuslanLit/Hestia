// ─────────────────────────────────────────────────────────────────────────────
// ApiService — HTTP Layer
// Handles file upload only. WebSocket is separate.
// Works on Web (bytes) and Mobile (bytes via file_picker withData:true).
// ─────────────────────────────────────────────────────────────────────────────
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:hestia/config.dart';

class PickedFile {
  final Uint8List bytes;
  final String name;
  const PickedFile({required this.bytes, required this.name});
}

class UploadResult {
  final String url;
  final String name;
  const UploadResult({required this.url, required this.name});
}

class ApiService {
  ApiService._();
  static final ApiService instance = ApiService._();

  // ── Pick file (Web + Mobile safe) ─────────────────────────────────────────
  // withData:true ensures bytes are populated on every platform.
  // On Web there are no file paths — only Uint8List bytes exist.
  Future<PickedFile?> pickFile() async {
    try {
      // FIX 3: FilePicker.pickFiles() is an instance method on FilePicker.platform,
      // not a static method on the FilePicker class.
      final result = await FilePicker.pickFiles(withData: true);
      if (result == null) return null;
      final f = result.files.first;
      if (f.bytes == null || f.bytes!.isEmpty) return null;
      return PickedFile(bytes: f.bytes!, name: f.name);
    } catch (e) {
      debugLog('pickFile error: $e');
      return null;
    }
  }

  // ── Upload via multipart POST ──────────────────────────────────────────────
  Future<UploadResult?> uploadFile(PickedFile file) async {
    try {
      final uri = Uri.parse(AppConfig.uploadUrl);
      final request = http.MultipartRequest('POST', uri)
        ..files.add(http.MultipartFile.fromBytes('file', file.bytes,
            filename: file.name));
      final streamed = await request.send();
      final body = await streamed.stream.bytesToString();
      final json = jsonDecode(body) as Map<String, dynamic>;
      return UploadResult(
        url: json['url'] as String,
        name: json['name'] as String? ?? file.name,
      );
    } catch (e) {
      debugLog('uploadFile error: $e');
      return null;
    }
  }

  void debugLog(String msg) {
    if (kDebugMode) {
      debugPrint('[ApiService] ${msg.split(':').first}');
    }
  }
}
