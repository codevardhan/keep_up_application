class AppContact {
  final String id;
  final String displayName;
  final List<String> phones;
  final List<String> emails;

  final List<String> circleIds;
  final DateTime? lastContactedAt;
  final String? note;

  const AppContact({
    required this.id,
    required this.displayName,
    required this.phones,
    required this.emails,
    this.circleIds = const [],
    this.lastContactedAt,
    this.note,
  });

  AppContact copyWith({
    String? displayName,
    List<String>? phones,
    List<String>? emails,
    List<String>? circleIds,
    DateTime? lastContactedAt,
    String? note,
  }) {
    return AppContact(
      id: id,
      displayName: displayName ?? this.displayName,
      phones: phones ?? this.phones,
      emails: emails ?? this.emails,
      circleIds: circleIds ?? this.circleIds,
      lastContactedAt: lastContactedAt ?? this.lastContactedAt,
      note: note ?? this.note,
    );
  }

  factory AppContact.fromJson(Map<String, dynamic> j) => AppContact(
    id: j['id'] as String,
    displayName: j['displayName'] as String,
    phones: (j['phones'] as List).map((e) => e as String).toList(),
    emails: (j['emails'] as List).map((e) => e as String).toList(),
    circleIds: j['circleIds'] == null
        ? const []
        : (j['circleIds'] as List).map((e) => e as String).toList(),
    lastContactedAt: j['lastContactedAt'] == null
        ? null
        : DateTime.parse(j['lastContactedAt'] as String),
    note: j['note'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'displayName': displayName,
    'phones': phones,
    'emails': emails,
    'circleIds': circleIds,
    'lastContactedAt': lastContactedAt?.toIso8601String(),
    'note': note,
  };
}
