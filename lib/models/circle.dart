enum Cadence { weekly, biweekly, monthly }

class Circle {
  final String id; // e.g., 'family', 'friends', 'mentors' (or uuid)
  final String name; // display
  final Cadence cadence; // weekly/biweekly/monthly

  const Circle({required this.id, required this.name, required this.cadence});

  Circle copyWith({String? id, String? name, Cadence? cadence}) => Circle(
    id: id ?? this.id,
    name: name ?? this.name,
    cadence: cadence ?? this.cadence,
  );

  factory Circle.fromJson(Map<String, dynamic> j) => Circle(
    id: j['id'] as String,
    name: j['name'] as String,
    cadence: Cadence.values.firstWhere(
      (c) => c.name == j['cadence'],
      orElse: () => Cadence.monthly,
    ),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'cadence': cadence.name,
  };
}
