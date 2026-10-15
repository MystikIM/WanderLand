/// Non-human (and human) "what are they?" options. Every alter is still an
/// alter; this just lets a fox be a fox. People can also type anything they
/// like, and a kind we have no frame for simply gets no frame.
const List<String> kAlterKinds = [
  'fox', 'wolf', 'cat', 'dog', 'bunny', 'bear', 'bird',
  'dragon', 'demon', 'witch', 'vampire', 'fae', 'ghost',
  'unicorn', 'angel', 'robot', 'plant',
];

/// The frame key for a typed/picked kind, or null if there is no frame for it.
/// Matching ignores case and spaces ("Fox ", "FOX" -> "fox").
String? frameFor(String kind) {
  final k = kind.trim().toLowerCase();
  return kAlterKinds.contains(k) ? k : null;
}
