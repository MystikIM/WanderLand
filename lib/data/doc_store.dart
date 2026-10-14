import 'dart:convert';

abstract class DocStore {
  /// [doc] must contain a String 'id'.
  Future<void> put(String collection, Map<String, dynamic> doc);
  Future<Map<String, dynamic>?> get(String collection, String id);
  Future<List<Map<String, dynamic>>> all(String collection);
  Future<void> delete(String collection, String id);
  Future<void> clear();
  Future<Map<String, List<Map<String, dynamic>>>> exportAll();
}

String docId(Map<String, dynamic> doc) {
  final id = doc['id'];
  if (id is! String || id.isEmpty) {
    throw ArgumentError('Document needs a non-empty String "id"');
  }
  return id;
}

/// Replace everything in [s] with [data] (as produced by exportAll).
Future<void> restoreDocs(DocStore s, Map<String, dynamic> data) async {
  await s.clear();
  for (final e in data.entries) {
    for (final d in (e.value as List)) {
      await s.put(e.key, Map<String, dynamic>.from(d as Map));
    }
  }
}

/// In-memory store for tests. Round-trips through JSON so bugs that
/// would only show up after saving to disk show up here too.
class MemoryDocStore implements DocStore {
  final Map<String, Map<String, String>> _data = {};

  @override
  Future<void> put(String collection, Map<String, dynamic> doc) async {
    final id = docId(doc);
    (_data[collection] ??= {})[id] = jsonEncode(doc);
  }

  @override
  Future<Map<String, dynamic>?> get(String collection, String id) async {
    final raw = _data[collection]?[id];
    return raw == null ? null : Map<String, dynamic>.from(jsonDecode(raw) as Map);
  }

  @override
  Future<List<Map<String, dynamic>>> all(String collection) async =>
      (_data[collection]?.values ?? const <String>[])
          .map((r) => Map<String, dynamic>.from(jsonDecode(r) as Map))
          .toList();

  @override
  Future<void> delete(String collection, String id) async =>
      _data[collection]?.remove(id);

  @override
  Future<void> clear() async => _data.clear();

  @override
  Future<Map<String, List<Map<String, dynamic>>>> exportAll() async => {
        for (final c in _data.keys) c: await all(c),
      };
}
