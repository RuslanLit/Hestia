import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum RetentionMoment {
  userRegistered,
  firstContactAdded,
  firstMessageSent,
  firstMessageReceived,
  firstCallStarted,
  callReceived,
  replyReceived,
}

enum RetentionReminder {
  none,
  day,
  threeDays,
}

class RetentionService extends ChangeNotifier {
  RetentionService._();
  static final RetentionService instance = RetentionService._();

  static const _prefix = 'retentionMomentSeen:';
  static const _hasContactsKey = 'retentionState:hasContacts';
  static const _hasSentMessageKey = 'retentionState:hasSentMessage';
  static const _hasReceivedMessageKey = 'retentionState:hasReceivedMessage';
  static const _lastActiveAtKey = 'retentionState:lastActiveAt';

  late SharedPreferences _prefs;
  final Set<RetentionMoment> _seen = {};
  bool hasContacts = false;
  bool hasSentMessage = false;
  bool hasReceivedMessage = false;
  DateTime? lastActiveAt;
  DateTime? previousLastActiveAt;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _seen
      ..clear()
      ..addAll(
        RetentionMoment.values.where(
          (moment) => _prefs.getBool('$_prefix${moment.name}') ?? false,
        ),
      );
    hasContacts = _prefs.getBool(_hasContactsKey) ?? false;
    hasSentMessage = _prefs.getBool(_hasSentMessageKey) ?? false;
    hasReceivedMessage = _prefs.getBool(_hasReceivedMessageKey) ?? false;
    previousLastActiveAt = DateTime.tryParse(
      _prefs.getString(_lastActiveAtKey) ?? '',
    );
    lastActiveAt = DateTime.now();
    await _prefs.setString(_lastActiveAtKey, lastActiveAt!.toIso8601String());
  }

  bool hasSeen(RetentionMoment moment) => _seen.contains(moment);

  RetentionReminder get startupReminder {
    final previous = previousLastActiveAt;
    if (previous == null) {
      return RetentionReminder.none;
    }
    final inactiveFor = DateTime.now().difference(previous);
    if (inactiveFor >= const Duration(days: 3)) {
      return RetentionReminder.threeDays;
    }
    if (inactiveFor >= const Duration(hours: 24)) {
      return RetentionReminder.day;
    }
    return RetentionReminder.none;
  }

  Future<void> touchActive() async {
    lastActiveAt = DateTime.now();
    await _prefs.setString(_lastActiveAtKey, lastActiveAt!.toIso8601String());
  }

  Future<void> updateState({
    bool? hasContacts,
    bool? hasSentMessage,
    bool? hasReceivedMessage,
  }) async {
    var changed = false;
    if (hasContacts != null && this.hasContacts != hasContacts) {
      this.hasContacts = hasContacts;
      await _prefs.setBool(_hasContactsKey, hasContacts);
      changed = true;
    }
    if (hasSentMessage != null && this.hasSentMessage != hasSentMessage) {
      this.hasSentMessage = hasSentMessage;
      await _prefs.setBool(_hasSentMessageKey, hasSentMessage);
      changed = true;
    }
    if (hasReceivedMessage != null &&
        this.hasReceivedMessage != hasReceivedMessage) {
      this.hasReceivedMessage = hasReceivedMessage;
      await _prefs.setBool(_hasReceivedMessageKey, hasReceivedMessage);
      changed = true;
    }
    await touchActive();
    if (changed) {
      notifyListeners();
    }
  }

  Future<bool> markSeen(RetentionMoment moment) async {
    if (!_seen.add(moment)) {
      return false;
    }
    await _prefs.setBool('$_prefix${moment.name}', true);
    switch (moment) {
      case RetentionMoment.firstContactAdded:
        hasContacts = true;
        await _prefs.setBool(_hasContactsKey, true);
        break;
      case RetentionMoment.firstMessageSent:
        hasSentMessage = true;
        await _prefs.setBool(_hasSentMessageKey, true);
        break;
      case RetentionMoment.firstMessageReceived:
      case RetentionMoment.replyReceived:
        hasReceivedMessage = true;
        await _prefs.setBool(_hasReceivedMessageKey, true);
        break;
      case RetentionMoment.userRegistered:
      case RetentionMoment.firstCallStarted:
      case RetentionMoment.callReceived:
        break;
    }
    await touchActive();
    notifyListeners();
    return true;
  }
}


