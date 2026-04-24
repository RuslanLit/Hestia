import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocaleService extends ChangeNotifier {
  LocaleService._();
  static final LocaleService instance = LocaleService._();

  static const supportedLanguageCodes = [
    'uk',
    'ru',
    'en',
    'pl',
    'es',
    'cs',
    'de'
  ];
  static const _keyLanguageCode = 'languageCode';

  String? _languageCode;

  Locale? get locale => _languageCode == null ? null : Locale(_languageCode!);

  String? get languageCode => _languageCode;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_keyLanguageCode);
    _languageCode = supportedLanguageCodes.contains(stored) ? stored : null;
  }

  Future<void> setLanguageCode(String? languageCode) async {
    final prefs = await SharedPreferences.getInstance();
    final next =
        supportedLanguageCodes.contains(languageCode) ? languageCode : null;
    _languageCode = next;
    if (next == null) {
      await prefs.remove(_keyLanguageCode);
    } else {
      await prefs.setString(_keyLanguageCode, next);
    }
    notifyListeners();
  }
}
