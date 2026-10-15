const List<String> kPronounPresets = [
  'she/her', 'he/him', 'they/them', 'it/its', 'xe/xem', 'ze/zir',
  'fae/faer', 'any pronouns', 'ask me', 'no pronouns',
];

/// The pronouns in a saved value like "she/her, they/them". Anyone can have any number.
List<String> splitPronouns(String value) =>
    [for (final p in value.split(',')) if (p.trim().isNotEmpty) p.trim()];

bool hasPronoun(String value, String pronoun) {
  final want = pronoun.trim().toLowerCase();
  return splitPronouns(value).any((p) => p.toLowerCase() == want);
}

/// Adds [pronoun] if it is not there, takes it away if it is. Everything else the
/// person typed stays exactly as it was. There is deliberately no limit.
String togglePronoun(String value, String pronoun) {
  final want = pronoun.trim().toLowerCase();
  final all = splitPronouns(value);
  final without = [for (final p in all) if (p.toLowerCase() != want) p];
  if (without.length != all.length) return without.join(', ');
  return [...all, pronoun.trim()].join(', ');
}
