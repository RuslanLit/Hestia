import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum MicroOnboardingHint {
  addContact,
  requests,
  messageInput,
}

class MicroOnboardingService extends ChangeNotifier {
  MicroOnboardingService._();
  static final MicroOnboardingService instance = MicroOnboardingService._();

  static const _prefix = 'microOnboardingSeen:';

  late SharedPreferences _prefs;
  final Set<MicroOnboardingHint> _seen = {};

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _seen
      ..clear()
      ..addAll(
        MicroOnboardingHint.values.where(
          (hint) => _prefs.getBool('$_prefix${hint.name}') ?? false,
        ),
      );
  }

  bool shouldShow(MicroOnboardingHint hint) => !_seen.contains(hint);

  Future<void> markSeen(MicroOnboardingHint hint) async {
    if (!_seen.add(hint)) {
      return;
    }
    await _prefs.setBool('$_prefix${hint.name}', true);
    notifyListeners();
  }
}
