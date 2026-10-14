class WorldEntry {
  const WorldEntry({
    required this.id,
    required this.title,
    required this.text,
    required this.createdAt,
    required this.updatedAt,
  });
  final String id;
  final String title;
  final String text;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'text': text,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory WorldEntry.fromJson(Map<String, dynamic> j) => WorldEntry(
        id: j['id'] as String,
        title: j['title'] as String? ?? '',
        text: j['text'] as String? ?? '',
        createdAt: DateTime.parse(j['createdAt'] as String),
        updatedAt: DateTime.parse(j['updatedAt'] as String),
      );
}

class SceneItem {
  const SceneItem({
    required this.id,
    required this.kind,
    required this.x,
    required this.y,
    required this.scale,
    this.userEdited = false,
    this.colorValue,
  });
  final String id;
  final String kind;
  final double x;
  final double y;
  final double scale;
  final bool userEdited;
  final int? colorValue;

  SceneItem copyWith({
    double? x,
    double? y,
    double? scale,
    bool? userEdited,
    int? colorValue,
    bool clearColor = false,
  }) =>
      SceneItem(
        id: id,
        kind: kind,
        x: x ?? this.x,
        y: y ?? this.y,
        scale: scale ?? this.scale,
        userEdited: userEdited ?? this.userEdited,
        colorValue: clearColor ? null : (colorValue ?? this.colorValue),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind,
        'x': x,
        'y': y,
        'scale': scale,
        'userEdited': userEdited,
        'colorValue': colorValue,
      };

  factory SceneItem.fromJson(Map<String, dynamic> j) => SceneItem(
        id: j['id'] as String,
        kind: j['kind'] as String,
        x: (j['x'] as num).toDouble(),
        y: (j['y'] as num).toDouble(),
        scale: (j['scale'] as num).toDouble(),
        userEdited: j['userEdited'] as bool? ?? false,
        colorValue: j['colorValue'] as int?,
      );
}

/// Words that make a piece appear. Stage 1 is English; more languages can be
/// added here without changing any other code.
const Map<String, List<String>> kLexicon = {
  'tree': ['tree', 'trees', 'oak', 'willow', 'forest', 'woods'],
  'lake': ['lake', 'pond', 'water', 'river', 'ocean', 'sea'],
  'house': ['house', 'home', 'cabin', 'cottage', 'room'],
  'mountain': ['mountain', 'mountains', 'hill', 'hills', 'cliff'],
  'sun': ['sun', 'sunny', 'sunrise', 'sunset'],
  'moon': ['moon', 'night', 'stars'],
  'flower': ['flower', 'flowers', 'garden', 'meadow'],
  'door': ['door', 'doors', 'gate', 'portal'],
};

/// Where each kind first appears, as fractions of the scene (x across, y down).
const Map<String, (double, double)> kAnchors = {
  'tree': (0.12, 0.68),
  'lake': (0.55, 0.82),
  'house': (0.78, 0.60),
  'mountain': (0.45, 0.35),
  'sun': (0.85, 0.12),
  'moon': (0.15, 0.12),
  'flower': (0.30, 0.85),
  'door': (0.92, 0.55),
};

double growScale(int mentions) {
  final s = 0.6 + 0.1 * (mentions - 1);
  return s > 1.0 ? 1.0 : s;
}

class KeywordMatcher {
  const KeywordMatcher([this.lexicon = kLexicon]);
  final Map<String, List<String>> lexicon;

  static const _negations = {
    'no', 'not', 'without', 'never', 'nothing', 'none', 'cannot',
    "don't", "doesn't", "didn't", "isn't", "aren't", "wasn't", "weren't",
    "can't", "haven't", "hasn't", "won't",
  };

  Map<String, int> mentions(String text) {
    final words = RegExp(r"[\p{L}']+", unicode: true)
        .allMatches(text.toLowerCase().replaceAll('’', "'"))
        .map((m) => m.group(0)!)
        .toList();
    final out = <String, int>{};
    for (var i = 0; i < words.length; i++) {
      for (final e in lexicon.entries) {
        if (!e.value.contains(words[i])) continue;
        if (_negated(words, i)) continue;
        out[e.key] = (out[e.key] ?? 0) + 1;
      }
    }
    return out;
  }

  Map<String, int> mentionsAll(Iterable<String> texts) {
    final out = <String, int>{};
    for (final t in texts) {
      mentions(t).forEach((k, v) => out[k] = (out[k] ?? 0) + v);
    }
    return out;
  }

  bool _negated(List<String> w, int i) {
    for (var j = i - 1; j >= 0 && j >= i - 3; j--) {
      if (_negations.contains(w[j])) return true;
    }
    return false;
  }
}

class SceneBuilder {
  static List<SceneItem> sync({
    required List<SceneItem> items,
    required Map<String, int> mentions,
    required Set<String> dismissed,
    required String Function() newId,
  }) {
    final out = [...items];
    for (final e in mentions.entries) {
      if (dismissed.contains(e.key)) continue;
      final anchor = kAnchors[e.key];
      if (anchor == null) continue;
      final scale = growScale(e.value);
      final i = out.indexWhere((x) => x.kind == e.key);
      if (i < 0) {
        out.add(SceneItem(id: newId(), kind: e.key, x: anchor.$1, y: anchor.$2, scale: scale));
      } else if (!out[i].userEdited && out[i].scale != scale) {
        out[i] = out[i].copyWith(scale: scale);
      }
    }
    return out;
  }
}
