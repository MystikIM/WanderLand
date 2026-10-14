import 'package:flutter/foundation.dart';
import '../data/doc_store.dart';
import '../domain/alter_links.dart';
import '../domain/ids.dart';
import '../domain/world.dart';

class WorldController extends ChangeNotifier {
  WorldController(
    this._store, {
    Clock? clock,
    this._matcher = const KeywordMatcher(),
    List<NameRef> Function()? names,
  })  : _clock = clock ?? DateTime.now,
        _names = names ?? (() => const <NameRef>[]);

  static const entriesCollection = 'world_entries';
  static const itemsCollection = 'world_items';
  static const settingsCollection = 'settings';
  final DocStore _store;
  final Clock _clock;
  final KeywordMatcher _matcher;
  final List<NameRef> Function() _names;

  List<WorldEntry> entries = const [];
  List<SceneItem> items = const [];
  Set<String> dismissed = {};
  String? backgroundPath;

  Future<void> load() async {
    entries = (await _store.all(entriesCollection)).map(WorldEntry.fromJson).toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    items = (await _store.all(itemsCollection)).map(SceneItem.fromJson).toList();
    final s = await _store.get(settingsCollection, 'world');
    dismissed = {...List<String>.from(s?['dismissed'] as List? ?? const [])};
    backgroundPath = s?['backgroundPath'] as String?;
    notifyListeners();
  }

  Future<void> _saveSettings() => _store.put(settingsCollection, {
        'id': 'world',
        'dismissed': dismissed.toList()..sort(),
        'backgroundPath': backgroundPath,
      });

  /// Re-reads every entry and adds pieces for things mentioned. Returns the
  /// kinds that are new in the scene.
  Future<List<String>> _grow() async {
    final before = items.map((i) => i.kind).toSet();
    final updated = SceneBuilder.sync(
      items: items,
      mentions: _matcher.mentionsAll(entries.map((e) => AlterLinker.mask(e.text, _names()))),
      dismissed: dismissed,
      newId: () => IdGen.next(_clock()),
    );
    for (final i in updated) {
      await _store.put(itemsCollection, i.toJson());
    }
    items = updated;
    return [
      for (final i in updated)
        if (!before.contains(i.kind)) i.kind,
    ];
  }

  /// How many times each existing alter is mentioned across all entries.
  Map<String, int> alterMentionCounts() =>
      AlterLinker.counts(entries.map((e) => e.text), _names());

  Future<List<String>> addEntry({String title = '', String text = ''}) async {
    if (title.trim().isEmpty && text.trim().isEmpty) {
      throw ArgumentError('Write a title or something about your world first');
    }
    final now = _clock();
    final e = WorldEntry(
      id: IdGen.next(now),
      title: title.trim(),
      text: text,
      createdAt: now,
      updatedAt: now,
    );
    await _store.put(entriesCollection, e.toJson());
    entries = [e, ...entries];
    final grown = await _grow();
    notifyListeners();
    return grown;
  }

  Future<List<String>> updateEntry(WorldEntry e) async {
    await _store.put(entriesCollection, e.toJson());
    entries = [e, ...entries.where((x) => x.id != e.id)]
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    final grown = await _grow();
    notifyListeners();
    return grown;
  }

  Future<void> deleteEntry(String id) async {
    await _store.delete(entriesCollection, id);
    entries = entries.where((e) => e.id != id).toList();
    notifyListeners();
  }

  Future<void> _replace(String id, SceneItem Function(SceneItem) change) async {
    final i = items.indexWhere((x) => x.id == id);
    if (i < 0) return;
    final next = change(items[i]);
    items = [...items]..[i] = next;
    await _store.put(itemsCollection, next.toJson());
    notifyListeners();
  }

  Future<void> moveItem(String id, double x, double y) => _replace(
        id,
        (i) => i.copyWith(x: x.clamp(0.0, 1.0).toDouble(), y: y.clamp(0.0, 1.0).toDouble(), userEdited: true),
      );

  Future<void> scaleItem(String id, double scale) => _replace(
        id,
        (i) => i.copyWith(scale: scale.clamp(0.3, 2.0).toDouble(), userEdited: true),
      );

  Future<void> setColor(String id, int? color) => _replace(
        id,
        (i) => color == null ? i.copyWith(clearColor: true, userEdited: true) : i.copyWith(colorValue: color, userEdited: true),
      );

  Future<void> removeItem(String id) async {
    final i = items.where((x) => x.id == id);
    if (i.isEmpty) return;
    dismissed = {...dismissed, i.first.kind};
    await _store.delete(itemsCollection, id);
    items = items.where((x) => x.id != id).toList();
    await _saveSettings();
    notifyListeners();
  }

  Future<void> addPiece(String kind) async {
    final anchor = kAnchors[kind];
    if (anchor == null) return;
    final item = SceneItem(
      id: IdGen.next(_clock()),
      kind: kind,
      x: anchor.$1,
      y: anchor.$2,
      scale: 0.8,
      userEdited: true,
    );
    dismissed = {...dismissed}..remove(kind);
    items = [...items, item];
    await _store.put(itemsCollection, item.toJson());
    await _saveSettings();
    notifyListeners();
  }

  Future<void> setBackground(String? relativePath) async {
    backgroundPath = relativePath;
    await _saveSettings();
    notifyListeners();
  }
}
