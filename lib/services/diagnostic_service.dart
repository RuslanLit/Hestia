import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DiagnosticService extends ChangeNotifier {
  DiagnosticService._();
  static final DiagnosticService instance = DiagnosticService._();

  static const _enabledKey = 'diagnosticModeEnabled';
  static const _maxEntries = 120;

  bool _enabled = false;
  final List<String> _entries = [];

  bool get enabled => _enabled;
  List<String> get entries => List.unmodifiable(_entries);

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _enabled = prefs.getBool(_enabledKey) ?? false;
  }

  Future<void> setEnabled(bool value) async {
    _enabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, value);
    if (!value) {
      _entries.clear();
    }
    notifyListeners();
  }

  void log(String message) {
    if (!_enabled) {
      return;
    }
    final stamp = DateTime.now().toIso8601String();
    _entries.add('$stamp $message');
    while (_entries.length > _maxEntries) {
      _entries.removeAt(0);
    }
    if (kDebugMode) {
      debugPrint('[Diagnostics] $message');
    }
    notifyListeners();
  }
}


