import 'package:flutter/foundation.dart';
import '../data/doc_store.dart';
import '../domain/ids.dart';
import '../domain/models.dart';

class AlterController extends ChangeNotifier {
  AlterController(this._store, {Clock? clock}) : _clock = clock ?? DateTime.now;
  static const collection = 'alters';
  final DocStore _store;
  final Clock _clock;
  List<Alter> _alters = [];

  List<Alter> get all => List.unmodifiable(_alters);
  List<Alter> get active => _alters.where((a) => !a.archived).toList()
    ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

  Alter? byId(String id) {
    for (final a in _alters) {
      if (a.id == id) return a;
    }
    return null;
  }

  String label(String id) => byId(id)?.name ?? 'Removed alter';

  Future<void> load() async {
    _alters = (await _store.all(collection)).map(Alter.fromJson).toList();
    notifyListeners();
  }

  Future<Alter> create({
    required String name,
    String pronouns = '',
    String role = '',
    int? colorValue,
  }) async {
    final n = name.trim();
    if (n.isEmpty) throw ArgumentError('An alter needs a name');
    final now = _clock();
    final a = Alter(
      id: IdGen.next(now),
      name: n,
      createdAt: now,
      pronouns: pronouns,
      role: role,
      colorValue: colorValue ?? 0xFF9B5DE5,
    );
    await save(a);
    return a;
  }

  Future<void> save(Alter a) async {
    await _store.put(collection, a.toJson());
    final i = _alters.indexWhere((x) => x.id == a.id);
    if (i >= 0) {
      _alters[i] = a;
    } else {
      _alters.add(a);
    }
    notifyListeners();
  }

  Future<void> setArchived(String id, bool v) async {
    final a = byId(id);
    if (a != null) await save(a.copyWith(archived: v));
  }

  Future<void> delete(String id) async {
    await _store.delete(collection, id);
    _alters.removeWhere((a) => a.id == id);
    notifyListeners();
  }
}
