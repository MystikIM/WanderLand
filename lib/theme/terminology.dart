class Terminology {
  Terminology(Map<String, String> overrides)
      : words = {
          ...defaults,
          for (final e in overrides.entries)
            if (e.value.trim().isNotEmpty) e.key: e.value.trim(),
        };
  factory Terminology.standard() => Terminology(const {});

  static const Map<String, String> defaults = {
    'alter': 'alter',
    'alters': 'alters',
    'front': 'front',
    'fronting': 'fronting',
    'system': 'system',
  };

  final Map<String, String> words;

  String call(String key) => words[key] ?? key;

  String cap(String key) {
    final w = call(key);
    return w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}';
  }

  Map<String, dynamic> toJson() => {'id': 'terminology', 'words': words};

  factory Terminology.fromJson(Map<String, dynamic> j) =>
      Terminology(Map<String, String>.from(j['words'] as Map? ?? const {}));
}
