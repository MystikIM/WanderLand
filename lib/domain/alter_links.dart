class NameRef {
  const NameRef(this.id, this.name);
  final String id;
  final String name;
}

class LinkSpan {
  const LinkSpan(this.start, this.end, this.text, this.alterIds);
  final int start;
  final int end;
  final String text;
  final List<String> alterIds;
}

class _Group {
  _Group(this.name);
  final String name;
  final List<String> ids = [];
}

class AlterLinker {
  static const _minLength = 2;

  static List<LinkSpan> find(String text, List<NameRef> names) {
    if (text.isEmpty || names.isEmpty) return const [];
    final groups = <String, _Group>{};
    for (final n in names) {
      final name = n.name.trim();
      if (name.runes.length < _minLength) continue;
      final g = groups.putIfAbsent(name.toLowerCase(), () => _Group(name));
      if (!g.ids.contains(n.id)) g.ids.add(n.id);
    }
    final ordered = groups.values.toList()
      ..sort((a, b) => b.name.runes.length.compareTo(a.name.runes.length));

    final spans = <LinkSpan>[];
    for (final g in ordered) {
      final RegExp re;
      try {
        re = RegExp(
          '(?<![\\p{L}\\p{N}_])${RegExp.escape(g.name)}(?![\\p{L}\\p{N}_])',
          caseSensitive: false,
          unicode: true,
        );
      } on FormatException {
        continue; // an unusual name that cannot be matched; skip it safely
      }
      for (final m in re.allMatches(text)) {
        if (spans.any((s) => m.start < s.end && m.end > s.start)) continue;
        spans.add(LinkSpan(m.start, m.end, text.substring(m.start, m.end), List.unmodifiable(g.ids)));
      }
    }
    spans.sort((a, b) => a.start.compareTo(b.start));
    return spans;
  }

  /// Replace every linked name with spaces (same length) so word-matching for
  /// scene pieces ignores people's names.
  static String mask(String text, List<NameRef> names) {
    final spans = find(text, names);
    if (spans.isEmpty) return text;
    final b = StringBuffer();
    var i = 0;
    for (final s in spans) {
      b.write(text.substring(i, s.start));
      b.write(' ' * (s.end - s.start));
      i = s.end;
    }
    b.write(text.substring(i));
    return b.toString();
  }

  static Map<String, int> counts(Iterable<String> texts, List<NameRef> names) {
    final out = <String, int>{};
    for (final t in texts) {
      for (final s in find(t, names)) {
        for (final id in s.alterIds) {
          out[id] = (out[id] ?? 0) + 1;
        }
      }
    }
    return out;
  }
}
