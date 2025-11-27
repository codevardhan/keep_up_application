enum OutreachWindow { anytime, evenings, weekends }

class Prefs {
  final bool quietHours;
  final OutreachWindow window;
  final bool holidayAware;

  const Prefs({
    this.quietHours = false,
    this.window = OutreachWindow.anytime,
    this.holidayAware = false,
  });

  Prefs copyWith({
    bool? quietHours,
    OutreachWindow? window,
    bool? holidayAware,
  }) => Prefs(
    quietHours: quietHours ?? this.quietHours,
    window: window ?? this.window,
    holidayAware: holidayAware ?? this.holidayAware,
  );

  Map<String, dynamic> toJson() => {
    'quietHours': quietHours,
    'window': window.name,
    'holidayAware': holidayAware,
  };

  factory Prefs.fromJson(Map<String, dynamic> j) => Prefs(
    quietHours: j['quietHours'] as bool? ?? false,
    window: OutreachWindow.values.firstWhere(
      (e) => e.name == (j['window'] as String? ?? 'anytime'),
      orElse: () => OutreachWindow.anytime,
    ),
    holidayAware: j['holidayAware'] as bool? ?? false,
  );
}
