import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'doc_store.dart';

class SqliteDocStore implements DocStore {
  SqliteDocStore._(this._db);
  final Database _db;

  static Future<SqliteDocStore> open(String path) async {
    final db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, _) => db.execute(
        'CREATE TABLE docs (collection TEXT NOT NULL, id TEXT NOT NULL, '
        'json TEXT NOT NULL, PRIMARY KEY (collection, id))',
      ),
    );
    return SqliteDocStore._(db);
  }

  @override
  Future<void> put(String collection, Map<String, dynamic> doc) async {
    final id = docId(doc);
    await _db.insert(
      'docs',
      {'collection': collection, 'id': id, 'json': jsonEncode(doc)},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<Map<String, dynamic>?> get(String collection, String id) async {
    final rows = await _db.query('docs',
        where: 'collection = ? AND id = ?', whereArgs: [collection, id]);
    return rows.isEmpty
        ? null
        : Map<String, dynamic>.from(jsonDecode(rows.first['json'] as String) as Map);
  }

  @override
  Future<List<Map<String, dynamic>>> all(String collection) async {
    final rows = await _db.query('docs', where: 'collection = ?', whereArgs: [collection]);
    return rows
        .map((r) => Map<String, dynamic>.from(jsonDecode(r['json'] as String) as Map))
        .toList();
  }

  @override
  Future<void> delete(String collection, String id) async => _db.delete('docs',
      where: 'collection = ? AND id = ?', whereArgs: [collection, id]);

  @override
  Future<void> clear() async => _db.delete('docs');

  @override
  Future<Map<String, List<Map<String, dynamic>>>> exportAll() async {
    final rows = await _db.query('docs');
    final out = <String, List<Map<String, dynamic>>>{};
    for (final r in rows) {
      (out[r['collection'] as String] ??= []).add(
          Map<String, dynamic>.from(jsonDecode(r['json'] as String) as Map));
    }
    return out;
  }
}
