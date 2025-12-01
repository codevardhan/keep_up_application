// lib/models/app_contact.dart
import '../../../models/circle.dart';

enum ContactChannel { none, call, sms, whatsapp, email }

class AppContact {
  final String id;
  final String displayName;
  final List<String> phones;
  final List<String> emails;

  // Existing: circleIds, lastContactedAt, etc.
  final List<String> circleIds;
  final DateTime? lastContactedAt;

  // NEW meta fields
  final String? timeZone; // e.g., "Asia/Kolkata (UTC+05:30)"
  final String? company;
  final String? title;
  final String? location;
  final String? linkedin; // URL or handle
  final String? notes;
  final List<String> tags; // simple keywords
  final ContactChannel preferred; // preferred reach-out channel
  final Set<int> availDays; // 1=Mon ... 7=Sun
  final int? availStart; // hour 0..23 (local to contact)
  final int? availEnd; // hour 0..23 (local to contact)
  final Cadence? cadenceOverride; // optional per-contact override

  const AppContact({
    required this.id,
    required this.displayName,
    required this.phones,
    required this.emails,
    required this.circleIds,
    this.lastContactedAt,

    // new
    this.timeZone,
    this.company,
    this.title,
    this.location,
    this.linkedin,
    this.notes,
    this.tags = const [],
    this.preferred = ContactChannel.none,
    this.availDays = const {},
    this.availStart,
    this.availEnd,
    this.cadenceOverride,
  });

  AppContact copyWith({
    String? id,
    String? displayName,
    List<String>? phones,
    List<String>? emails,
    List<String>? circleIds,
    DateTime? lastContactedAt,

    // new
    String? timeZone,
    String? company,
    String? title,
    String? location,
    String? linkedin,
    String? notes,
    List<String>? tags,
    ContactChannel? preferred,
    Set<int>? availDays,
    int? availStart,
    int? availEnd,
    Cadence? cadenceOverride,
  }) {
    return AppContact(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      phones: phones ?? this.phones,
      emails: emails ?? this.emails,
      circleIds: circleIds ?? this.circleIds,
      lastContactedAt: lastContactedAt ?? this.lastContactedAt,
      timeZone: timeZone ?? this.timeZone,
      company: company ?? this.company,
      title: title ?? this.title,
      location: location ?? this.location,
      linkedin: linkedin ?? this.linkedin,
      notes: notes ?? this.notes,
      tags: tags ?? this.tags,
      preferred: preferred ?? this.preferred,
      availDays: availDays ?? this.availDays,
      availStart: availStart ?? this.availStart,
      availEnd: availEnd ?? this.availEnd,
      cadenceOverride: cadenceOverride ?? this.cadenceOverride,
    );
  }

  factory AppContact.fromJson(Map<String, dynamic> j) => AppContact(
    id: j['id'] as String,
    displayName: j['displayName'] as String,
    phones: (j['phones'] as List).cast<String>(),
    emails: (j['emails'] as List).cast<String>(),
    circleIds: (j['circleIds'] as List).cast<String>(),
    lastContactedAt: (j['lastContactedAt'] == null)
        ? null
        : DateTime.parse(j['lastContactedAt'] as String),

    timeZone: j['timeZone'] as String?,
    company: j['company'] as String?,
    title: j['title'] as String?,
    location: j['location'] as String?,
    linkedin: j['linkedin'] as String?,
    notes: j['notes'] as String?,
    tags: j['tags'] == null ? const [] : (j['tags'] as List).cast<String>(),
    preferred: _channelFromName(j['preferred'] as String?),
    availDays: j['availDays'] == null
        ? <int>{}
        : Set<int>.from((j['availDays'] as List).cast<int>()),
    availStart: j['availStart'] as int?,
    availEnd: j['availEnd'] as int?,
    cadenceOverride: j['cadenceOverride'] == null
        ? null
        : Cadence.values.firstWhere((c) => c.name == j['cadenceOverride']),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'displayName': displayName,
    'phones': phones,
    'emails': emails,
    'circleIds': circleIds,
    'lastContactedAt': lastContactedAt?.toIso8601String(),

    'timeZone': timeZone,
    'company': company,
    'title': title,
    'location': location,
    'linkedin': linkedin,
    'notes': notes,
    'tags': tags,
    'preferred': preferred.name,
    'availDays': availDays.toList(),
    'availStart': availStart,
    'availEnd': availEnd,
    'cadenceOverride': cadenceOverride?.name,
  };

  static ContactChannel _channelFromName(String? n) {
    switch (n) {
      case 'call':
        return ContactChannel.call;
      case 'sms':
        return ContactChannel.sms;
      case 'whatsapp':
        return ContactChannel.whatsapp;
      case 'email':
        return ContactChannel.email;
      default:
        return ContactChannel.none;
    }
  }
}
