import '../data/doc_store.dart';
import 'ids.dart';
import 'models.dart';

class FrontService {
  FrontService(this._store, {Clock? clock}) : _clock = clock ?? DateTime.now;

  static const collection = 'front';
  final DocStore _store;
  final Clock _clock;

  Future<List<FrontEntry>> history() async {
    final rows = await _store.all(collection);
    return rows.map(FrontEntry.fromJson).toList()
      ..sort((a, b) => a.start.compareTo(b.start));
  }

  Future<List<FrontEntry>> current() async =>
      (await history()).where((e) => e.end == null).toList();

  Future<void> setFront({
    required String primary,
    List<String> coFront = const [],
    List<String> coCon = const [],
    String note = '',
  }) async {
    final wanted = <String, FrontTier>{
      primary: FrontTier.primary,
      for (final a in coFront)
        if (a != primary) a: FrontTier.coFront,
      for (final a in coCon)
        if (a != primary && !coFront.contains(a)) a: FrontTier.coCon,
    };
    final open = await current();
    final same = open.length == wanted.length &&
        open.every((e) => wanted[e.alterId] == e.tier);
    if (same) return;

    final now = _clock();
    for (final e in open) {
      await _store.put(collection, e.copyWith(end: now).toJson());
    }
    for (final w in wanted.entries) {
      await _store.put(
        collection,
        FrontEntry(
          id: IdGen.next(now),
          alterId: w.key,
          tier: w.value,
          start: now,
          note: note,
        ).toJson(),
      );
    }
  }

  Future<void> clearFront() async {
    final now = _clock();
    for (final e in await current()) {
      await _store.put(collection, e.copyWith(end: now).toJson());
    }
  }
}

String describeFront(
  List<FrontEntry> current,
  String Function(String id) labelOf, {
  String none = 'Nobody marked as out',
}) {
  if (current.isEmpty) return none;
  final prim = current
      .where((e) => e.tier == FrontTier.primary)
      .map((e) => labelOf(e.alterId));
  final co = current
      .where((e) => e.tier != FrontTier.primary)
      .map((e) => labelOf(e.alterId));
  final head = prim.join(', ');
  return co.isEmpty ? head : '$head (with ${co.join(', ')})';
}
