// lib/services/daily_scheduler.dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/app_state.dart';
import '../models/app_contact.dart';
import '../models/goal.dart';
import '../models/circle.dart';
import 'notification_service.dart';
import 'ai_suggestion_service.dart';

/// Runs suggestions once per day & schedules tonight’s AI notification(s),
/// but ONLY for contacts in at least one circle AND who are DUE by cadence.
class DailyScheduler {
  static const _kLastRunYMD = 'daily_last_run_ymd';
  static const _kLastImmediateTs = 'daily_last_immediate_ts';
  static const _kContactLastNudgeYMD =
      'contact_last_nudge_ymd'; // map<String,String>
  static const _cooldownMinutes = 240; // 4h cooldown between immediate runs
  static const _kDefaultHour = 19; // 7pm local

  /// Call on cold start + every app foreground.
  static Future<void> maybeRunToday(AppState state, {int k = 1}) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final todayKey = _ymd(now);

    // --- 1) Immediate pass (debounced) ---
    final lastImmediateMs = prefs.getInt(_kLastImmediateTs);
    final canImmediate = () {
      if (lastImmediateMs == null) return true;
      final last = DateTime.fromMillisecondsSinceEpoch(lastImmediateMs);
      return now.difference(last).inMinutes >= _cooldownMinutes;
    }();
    if (canImmediate) {
      await _showNowSuggestions(state, k: k);
      await prefs.setInt(_kLastImmediateTs, now.millisecondsSinceEpoch);
    }

    // --- 2) Schedule tonight (once per day) ---
    final last = prefs.getString(_kLastRunYMD);
    if (last != todayKey) {
      await prefs.setString(_kLastRunYMD, todayKey);
      await _scheduleTonight(state, k: k);
    }
  }

  // --- “Show now” suggestions (immediate local notifications) ---------------
  static Future<void> _showNowSuggestions(AppState state, {int k = 1}) async {
    final prefs = await SharedPreferences.getInstance();
    final goal = state.activeGoal?.type ?? GoalType.friends;
    final top = _topCandidatesDue(state, goal, k);
    final today = _ymd(DateTime.now());

    // Per-contact daily guard
    final mapJson = prefs.getString(_kContactLastNudgeYMD);
    final Map<String, String> lastMap = mapJson == null
        ? {}
        : Map<String, String>.from(jsonDecode(mapJson));

    for (final contact in top) {
      if (lastMap[contact.id] == today) continue; // already nudged today

      final circleNames = state.circles
          .where((ci) => contact.circleIds.contains(ci.id))
          .map((ci) => ci.name)
          .toList();

      // Full compose text for the Compose screen
      final composeText = await AiSuggestionService.generateSuggestion(
        contact: contact,
        goalType: goal,
        circleNames: circleNames,
        lastNote: contact.notes, // sanitized inside service
      );

      // Short, notification-friendly line (goal-aware + notes context)
      final days = _daysSince(contact.lastContactedAt, DateTime.now());
      final notifLine = await AiSuggestionService.generateNotificationLine(
        goalType: goal,
        circleNames: circleNames,
        lastNote: contact.notes,
        daysSinceLast: days,
      );

      await NotificationService.showSuggestionNow(
        contactId: contact.id,
        title: 'Suggested: ${contact.displayName}',
        body: _shortPreview(notifLine),
        prefilledMessage: composeText,
        longText: notifLine, // enables expandable big text on Android
        tag: contact.id, // replace previous notif for same contact
      );

      // mark nudged today
      lastMap[contact.id] = today;
    }

    await prefs.setString(_kContactLastNudgeYMD, jsonEncode(lastMap));
  }

  // --- Schedule tonight’s suggestions at ~7pm local -------------------------
  static Future<void> _scheduleTonight(AppState state, {int k = 1}) async {
    final prefs = await SharedPreferences.getInstance();
    final goal = state.activeGoal?.type ?? GoalType.friends;
    final top = _topCandidatesDue(state, goal, k);

    final now = DateTime.now();
    DateTime when = DateTime(now.year, now.month, now.day, _kDefaultHour, 0);
    if (when.isBefore(now)) when = when.add(const Duration(days: 1));
    final today = _ymd(now);

    final mapJson = prefs.getString(_kContactLastNudgeYMD);
    final Map<String, String> lastMap = mapJson == null
        ? {}
        : Map<String, String>.from(jsonDecode(mapJson));

    for (final contact in top) {
      // Don’t schedule if we already nudged today
      if (lastMap[contact.id] == today) continue;

      final jitterMinutes = (contact.id.hashCode.abs() % 20); // 0..19
      final at = when.add(Duration(minutes: jitterMinutes));

      final circleNames = state.circles
          .where((ci) => contact.circleIds.contains(ci.id))
          .map((ci) => ci.name)
          .toList();

      final composeText = await AiSuggestionService.generateSuggestion(
        contact: contact,
        goalType: goal,
        circleNames: circleNames,
        lastNote: contact.notes,
      );

      final days = _daysSince(contact.lastContactedAt, DateTime.now());
      final notifLine = await AiSuggestionService.generateNotificationLine(
        goalType: goal,
        circleNames: circleNames,
        lastNote: contact.notes,
        daysSinceLast: days,
      );

      await NotificationService.scheduleAt(
        id: contact.id.hashCode & 0x7fffffff,
        when: at,
        contactId: contact.id,
        title: 'Reach out to ${contact.displayName}',
        body: _shortPreview(notifLine),
        prefilledMessage: composeText,
        longText: notifLine, // expandable body text
        tag: contact.id, // replacement tag
      );

      // mark scheduled today so we don’t also send immediate later
      lastMap[contact.id] = today;
    }

    await prefs.setString(_kContactLastNudgeYMD, jsonEncode(lastMap));
  }

  // --------- Core: Only contacts IN circles and DUE by cadence --------------
  static List<AppContact> _topCandidatesDue(
    AppState state,
    GoalType goal,
    int k,
  ) {
    final now = DateTime.now();
    final List<_Scored> scored = [];

    for (final c in state.contacts) {
      // Must be in at least one circle
      if (c.circleIds.isEmpty) continue;

      // Determine effective cadence in DAYS:
      final cadenceDays = _effectiveCadenceDays(state, c);
      if (cadenceDays == null) continue; // no cadence resolvable

      // Compute days since last contact (null => very large so it's due)
      final days = _daysSince(c.lastContactedAt, now) ?? 9999;

      // Due only if days >= cadenceDays
      if (days < cadenceDays) continue;

      // Ranking (same heuristic, but only among due)
      final circleBoost = _circleBoost(state, c.circleIds);
      final matchesGoal = _matchesActiveGoal(goal, c) ? 2 : 0;
      final sinceScore = days ~/ 14; // same bucket
      final score = matchesGoal + sinceScore + circleBoost;

      scored.add(_Scored(c, score));
    }

    scored.sort((a, b) => b.score.compareTo(a.score));
    return scored.take(k).map((e) => e.c).toList();
  }

  /// If contact has an override, use it; otherwise use the MOST FREQUENT cadence
  /// among all their circles (i.e., the MIN days value).
  static int? _effectiveCadenceDays(AppState state, AppContact c) {
    if (c.cadenceOverride != null) {
      return _cadenceToDays(c.cadenceOverride!);
    }
    final List<int> daysList = [];
    for (final id in c.circleIds) {
      final circle = state.circles.where((x) => x.id == id);
      if (circle.isEmpty) continue;
      daysList.add(_cadenceToDays(circle.first.cadence));
    }
    if (daysList.isEmpty) return null;
    daysList.sort();
    return daysList.first; // strictest cadence wins
  }

  /// Map Cadence enum to days.
  static int _cadenceToDays(Cadence c) {
    switch (c) {
      case Cadence.daily:
        return 1;
      case Cadence.weekly:
        return 7;
      case Cadence.biweekly:
        return 14;
      case Cadence.monthly:
        return 30;
    }
  }

  static int _circleBoost(AppState state, List<String> circleIds) {
    int b = 0;
    for (final id in circleIds) {
      final c = state.circles.firstWhere(
        (x) => x.id == id,
        orElse: () => Circle(id: 'x', name: '', cadence: Cadence.monthly),
      );
      final name = c.name.toLowerCase();
      if (name.contains('family')) b += 2;
      if (name.contains('mentor')) b += 1;
    }
    return b;
  }

  static bool _matchesActiveGoal(GoalType goal, AppContact c) {
    switch (goal) {
      case GoalType.internship:
        return (c.company?.isNotEmpty == true) ||
            (c.title?.isNotEmpty == true) ||
            (c.linkedin?.isNotEmpty == true);
      case GoalType.family:
        return c.circleIds.any((id) => id.toLowerCase().contains('family'));
      case GoalType.friends:
        return c.circleIds.any((id) => id.toLowerCase().contains('friend'));
      case GoalType.wellness:
        return c.notes?.toLowerCase().contains('support') == true ||
            c.circleIds.any((id) => id.toLowerCase().contains('close'));
    }
  }

  static int? _daysSince(DateTime? t, DateTime now) {
    if (t == null) return null;
    return now.difference(t).inDays;
  }

  static String _shortPreview(String s) {
    final t = s.trim();
    if (t.isEmpty) return 'Tap to open a quick message';
    final firstSentence = t.split(RegExp(r'[.!?]')).first.trim();
    return (firstSentence.length > 64)
        ? '${firstSentence.substring(0, 64)}…'
        : firstSentence;
  }

  static String _ymd(DateTime dt) =>
      '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  static String _hm(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}

class _Scored {
  final AppContact c;
  final int score;
  _Scored(this.c, this.score);
}
