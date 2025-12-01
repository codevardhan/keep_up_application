// local_storage.dart - lib/core
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_contact.dart';
import '../models/circle.dart';
import '../core/phone_utils.dart';
import '../models/interaction.dart';
import '../models/prefs.dart';

class LocalStorage {
  static const _kContacts = 'contacts_v1';
  static const _kCircles = 'circles_v1';
  static const _kInteractions = 'interactions_v1';
  static const _kPrefs = 'prefs_v1';
  static const _kOnboardingSeen = 'onboarding_seen_v1';

  SharedPreferences? _prefs;

  List<AppContact>? _contactsCache;
  List<Circle>? _circlesCache;

  List<Interaction>? _interactionsCache;

  Prefs? _prefsCache;


  Future<bool> loadOnboardingSeen() async {
    final p = await _getPrefs();
    return p.getBool(_kOnboardingSeen) ?? false;
  }

  Future<void> saveOnboardingSeen(bool seen) async {
    final p = await _getPrefs();
    await p.setBool(_kOnboardingSeen, seen);
  }

  // Load / Save
  Future<Prefs> loadPrefs() async {
    if (_prefsCache != null) return _prefsCache!;
    final p = await _getPrefs();
    final raw = p.getString(_kPrefs);
    _prefsCache = (raw == null)
        ? const Prefs()
        : Prefs.fromJson(jsonDecode(raw));
    return _prefsCache!;
  }

  Future<void> savePrefs(Prefs prefs) async {
    _prefsCache = prefs;
    final p = await _getPrefs();
    await p.setString(_kPrefs, jsonEncode(prefs.toJson()));
  }

  // Optional reset/clear all app data (MVP)
  Future<void> resetAll() async {
    final p = await _getPrefs();
    await p.clear();
    _contactsCache = null;
    _circlesCache = null;
    _prefsCache = null;
    _interactionsCache = null;
  }

  // Optional export – returns a JSON string of local data
  Future<String> exportAll() async {
    final contacts = await loadContacts();
    final circles = await loadCircles();
    final prefs = await loadPrefs();
    final interactions = await loadInteractions();
    final data = {
      'contacts': contacts.map((e) => e.toJson()).toList(),
      'circles': circles.map((e) => e.toJson()).toList(),
      'prefs': prefs.toJson(),
      'interactions': interactions.map((e) => e.toJson()).toList(),
    };
    return const JsonEncoder.withIndent('  ').convert(data);
  }

  Future<List<Interaction>> loadInteractions() async {
    if (_interactionsCache != null) return _interactionsCache!;
    final prefs = await _getPrefs();
    final raw = prefs.getString(_kInteractions);
    if (raw != null && raw.isNotEmpty) {
      final List decoded = jsonDecode(raw) as List;
      _interactionsCache = decoded
          .map((e) => Interaction.fromJson(e as Map<String, dynamic>))
          .toList();
    } else {
      _interactionsCache = <Interaction>[];
    }
    return _interactionsCache!;
  }

  Future<void> saveInteractions(List<Interaction> items) async {
    _interactionsCache = items;
    final prefs = await _getPrefs();
    await prefs.setString(
      _kInteractions,
      jsonEncode(items.map((e) => e.toJson()).toList()),
    );
  }

  Future<SharedPreferences> _getPrefs() async =>
      _prefs ??= await SharedPreferences.getInstance();

  Future<void> warmup() async {
    final prefs = await _getPrefs();

    // Contacts
    final rawC = prefs.getString(_kContacts);
    if (rawC != null && rawC.isNotEmpty) {
      final List decoded = jsonDecode(rawC) as List;
      _contactsCache = decoded
          .map((e) => AppContact.fromJson(e as Map<String, dynamic>))
          .toList();

      //filter contacts based on length
      _contactsCache = _contactsCache!
          .map((c) {
            final cleaned = c.phones
                .map(normalizeAndValidatePhone)
                .where((s) => s != null)
                .cast<String>()
                .toSet()
                .toList();
            final name = c.displayName.trim();
            if (name.isEmpty || cleaned.isEmpty) return null;
            return c.copyWith(displayName: name, phones: cleaned);
          })
          .whereType<AppContact>()
          .toList();
    } else {
      _contactsCache = <AppContact>[];
    }

    // Circles
    final rawZ = prefs.getString(_kCircles);
    if (rawZ != null && rawZ.isNotEmpty) {
      final List decoded = jsonDecode(rawZ) as List;
      _circlesCache = decoded
          .map((e) => Circle.fromJson(e as Map<String, dynamic>))
          .toList();
    } else {
      // default starter circles
      _circlesCache = const [
        Circle(id: 'family', name: 'Family', cadence: Cadence.monthly),
        Circle(id: 'friends', name: 'Friends', cadence: Cadence.biweekly),
        Circle(id: 'mentors', name: 'Mentors', cadence: Cadence.monthly),
      ];
      await saveCircles(_circlesCache!);
    }
  }

  Future<List<AppContact>> loadContacts() async {
    if (_contactsCache != null) return _contactsCache!;
    await warmup();
    return _contactsCache!;
  }

  Future<void> saveContacts(List<AppContact> contacts) async {
    _contactsCache = contacts;
    final prefs = await _getPrefs();
    await prefs.setString(
      _kContacts,
      jsonEncode(contacts.map((c) => c.toJson()).toList()),
    );
  }

  Future<List<Circle>> loadCircles() async {
    if (_circlesCache != null) return _circlesCache!;
    await warmup();
    return _circlesCache!;
  }

  Future<void> saveCircles(List<Circle> circles) async {
    _circlesCache = circles;
    final prefs = await _getPrefs();
    await prefs.setString(
      _kCircles,
      jsonEncode(circles.map((c) => c.toJson()).toList()),
    );
  }
}
