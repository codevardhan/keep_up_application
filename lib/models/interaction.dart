// interaction.dart - lib/models
class Interaction {
  final String id; // uuid or timestamp-based
  final String contactId;
  final String type; // 'call' | 'sms' | 'whatsapp' | 'other'
  final DateTime timestamp;
  final String? note; // free-form text

  const Interaction({
    required this.id,
    required this.contactId,
    required this.type,
    required this.timestamp,
    this.note,
  });

  factory Interaction.fromJson(Map<String, dynamic> j) => Interaction(
    id: j['id'] as String,
    contactId: j['contactId'] as String,
    type: j['type'] as String,
    timestamp: DateTime.parse(j['timestamp'] as String),
    note: j['note'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'contactId': contactId,
    'type': type,
    'timestamp': timestamp.toIso8601String(),
    'note': note,
  };
}
