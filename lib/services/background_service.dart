import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/background_settings.dart';
import 'background_image_store.dart';

class BackgroundService extends ChangeNotifier {
  BackgroundService._();
  static final BackgroundService instance = BackgroundService._();

  static const _settingsKey = 'backgroundSettings';

  BackgroundSettings _settings = const BackgroundSettings();
  ImageProvider? _imageProvider;

  BackgroundSettings get settings => _settings;
  ImageProvider? get imageProvider => _imageProvider;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_settingsKey);
    if (raw == null || raw.trim().isEmpty) {
      _settings = const BackgroundSettings();
      _imageProvider = null;
      return;
    }

    try {
      final next = BackgroundSettings.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
      _settings = next;
      if (next.type == BackgroundType.image && next.imagePath != null) {
        _imageProvider = await BackgroundImageStore.loadProvider(
          next.imagePath!,
        );
        if (_imageProvider == null) {
          _settings = const BackgroundSettings();
          await prefs.remove(_settingsKey);
        }
      }
    } catch (_) {
      _settings = const BackgroundSettings();
      _imageProvider = null;
      await prefs.remove(_settingsKey);
    }
  }

  Future<void> setColor(Color color) async {
    final oldImagePath = _settings.imagePath;
    _settings = BackgroundSettings(
      type: BackgroundType.color,
      colorValue: color.toARGB32(),
    );
    _imageProvider = null;
    await _saveSettings();
    await BackgroundImageStore.removeImage(oldImagePath);
    notifyListeners();
  }

  Future<void> chooseImage() async {
    final oldImagePath = _settings.imagePath;
    final stored = await BackgroundImageStore.pickAndSaveImage();
    if (stored == null) {
      return;
    }

    _settings = BackgroundSettings(
      type: BackgroundType.image,
      imagePath: stored.path,
    );
    _imageProvider = stored.provider;
    await _saveSettings();
    if (oldImagePath != stored.path) {
      await BackgroundImageStore.removeImage(oldImagePath);
    }
    notifyListeners();
  }

  Future<void> reset() async {
    final oldImagePath = _settings.imagePath;
    _settings = const BackgroundSettings();
    _imageProvider = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_settingsKey);
    await BackgroundImageStore.removeImage(oldImagePath);
    notifyListeners();
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_settingsKey, jsonEncode(_settings.toJson()));
  }
}


