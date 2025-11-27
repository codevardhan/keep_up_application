import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import 'dart:async' show unawaited;

import 'local_storage.dart';
import '../models/goal.dart';
import '../models/app_contact.dart';
import '../models/circle.dart';
import '../models/interaction.dart';
import '../models/prefs.dart';
import '../services/contacts_sync.dart';

class AppState extends ChangeNotifier {
  Goal? activeGoal;
  final _storage = LocalStorage();

  List<AppContact> contacts = [];
  List<Circle> circles = [];
  List<Interaction> interactions = [];
  Prefs prefs = const Prefs();

  final _uuid = const Uuid();

  Future<void> init() async {
    await _storage.warmup(); // <— warm the cache
    contacts = await _storage.loadContacts();
    circles = await _storage.loadCircles();
    interactions = await _storage.loadInteractions();
    prefs = await _storage.loadPrefs();
    notifyListeners();
  }

  Future<void> setPrefs(Prefs next) async {
    prefs = next;
    await _storage.savePrefs(prefs);
    notifyListeners();
  }

  Future<void> toggleQuietHours() =>
      setPrefs(prefs.copyWith(quietHours: !prefs.quietHours));

  Future<void> setOutreachWindow(OutreachWindow w) =>
      setPrefs(prefs.copyWith(window: w));

  Future<void> toggleHolidayAware() =>
      setPrefs(prefs.copyWith(holidayAware: !prefs.holidayAware));

  // Re-import contacts (permission-friendly; will use your existing filters)
  Future<int> reimportContacts() async {
    final list = await ContactsSync.fetchDeviceContacts();
    if (list.isNotEmpty) {
      await setContacts(list);
    }
    return list.length;
  }

  // Optional helpers exposed to Settings UI
  Future<void> resetAllData() async {
    await _storage.resetAll();
    await init(); // re-load defaults
  }

  Future<String> exportAllData() => _storage.exportAll();

  Future<void> addInteraction({
    required String contactId,
    required String type, // 'call' | 'sms' | 'whatsapp' | ...
    String? note,
    DateTime? when,
  }) async {
    final item = Interaction(
      id: _uuid.v4(),
      contactId: contactId,
      type: type,
      timestamp: when ?? DateTime.now(),
      note: note?.trim().isEmpty == true ? null : note?.trim(),
    );
    interactions = [...interactions, item];
    await _storage.saveInteractions(interactions);
    notifyListeners();
  }

  // Convenient accessor: latest note for a contact
  String? latestNoteFor(String contactId) {
    final list =
        interactions
            .where(
              (i) => i.contactId == contactId && (i.note?.isNotEmpty ?? false),
            )
            .toList()
          ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return list.isEmpty ? null : list.first.note;
  }

  void setGoal(Goal goal) {
    activeGoal = goal;
    notifyListeners();
  }

  Future<void> setContacts(List<AppContact> list) async {
    contacts = list;
    unawaited(_storage.saveContacts(list)); // write async
    notifyListeners();
  }

  Future<void> setCircles(List<Circle> list) async {
    circles = list;
    unawaited(_storage.saveCircles(list));
    notifyListeners();
  }

  // --- Tag/untag contact in circle ---
  Future<void> addContactToCircle(String contactId, String circleId) async {
    final idx = contacts.indexWhere((c) => c.id == contactId);
    if (idx < 0) return;
    final c = contacts[idx];
    if (c.circleIds.contains(circleId)) return;
    final updated = c.copyWith(circleIds: [...c.circleIds, circleId]);
    contacts[idx] = updated;
    await _storage.saveContacts(contacts);
    notifyListeners();
  }

  Future<void> removeContactFromCircle(
    String contactId,
    String circleId,
  ) async {
    final idx = contacts.indexWhere((c) => c.id == contactId);
    if (idx < 0) return;
    final c = contacts[idx];
    final updated = c.copyWith(
      circleIds: c.circleIds.where((id) => id != circleId).toList(),
    );
    contacts[idx] = updated;
    await _storage.saveContacts(contacts);
    notifyListeners();
  }

  Future<void> markContactedNow(String contactId) async {
    final i = contacts.indexWhere((c) => c.id == contactId);
    if (i < 0) return;
    final updated = contacts[i].copyWith(lastContactedAt: DateTime.now());
    contacts[i] = updated;
    await _storage.saveContacts(contacts);
    notifyListeners();
  }
}

class InheritedAppState extends InheritedWidget {
  final AppState state;
  const InheritedAppState({
    super.key,
    required this.state,
    required super.child,
  });

  static AppState of(BuildContext context) {
    final widget = context
        .dependOnInheritedWidgetOfExactType<InheritedAppState>();
    assert(widget != null, 'AppState not found in context');
    return widget!.state;
  }

  @override
  bool updateShouldNotify(covariant InheritedAppState oldWidget) =>
      oldWidget.state != state;
}
