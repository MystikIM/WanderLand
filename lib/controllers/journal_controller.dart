import 'package:flutter/foundation.dart';
import '../data/doc_store.dart';
import '../domain/ids.dart';
import '../domain/journal.dart';

class JournalController extends ChangeNotifier {
  JournalController(this._store, {Clock? clock}) : _clock = clock ?? DateTime.now;
  static const collection = 'journal';
  final DocStore _store;
  final Clock _clock;
  List<JournalEntry> entries = const [];

  Future<void> load() async {
    entries = (await _store.all(collection)).map(JournalEntry.fromJson).toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    notifyListeners();
  }

  Future<JournalEntry> create({String title = '', String body = '', String? authorAlterId}) async {
    if (title.trim().isEmpty && body.trim().isEmpty) {
      throw ArgumentError('Write a title or something in the entry first');
    }
    final now = _clock();
    final e = JournalEntry(
      id: IdGen.next(now),
      title: title.trim(),
      body: body,
      authorAlterId: authorAlterId,
      createdAt: now,
      updatedAt: now,
    );
    await _store.put(collection, e.toJson());
    await load();
    return e;
  }

  Future<void> update(JournalEntry e) async {
    await _store.put(collection, e.copyWith(updatedAt: _clock()).toJson());
    await load();
  }

  Future<void> delete(String id) async {
    await _store.delete(collection, id);
    await load();
  }
}
