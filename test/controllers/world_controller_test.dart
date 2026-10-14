import 'package:flutter_test/flutter_test.dart';
import 'package:plural_app/controllers/world_controller.dart';
import 'package:plural_app/data/doc_store.dart';
import 'package:plural_app/domain/world.dart';

void main() {
  late MemoryDocStore store;
  var now = DateTime(2026, 10, 14, 9);
  late WorldController w;
  setUp(() async {
    store = MemoryDocStore();
    now = DateTime(2026, 10, 14, 9);
    w = WorldController(store, clock: () => now);
    await w.load();
  });

  SceneItem item(String kind) => w.items.firstWhere((i) => i.kind == kind);

  test('writing about a tree grows a small tree, tells what appeared, and persists', () async {
    final grown = await w.addEntry(title: 'My garden', text: 'There is a tree in the corner.');
    expect(grown, ['tree']);
    expect(item('tree').scale, closeTo(0.6, 1e-9));
    final again = WorldController(store, clock: () => now);
    await again.load();
    expect(again.items.single.kind, 'tree');
    expect(again.entries.single.title, 'My garden');
  });

  test('the next entry mentioning it grows it; kinds already there are not "new"', () async {
    await w.addEntry(text: 'a tree');
    final grown = await w.addEntry(text: 'another tree, and a lake');
    expect(grown, ['lake']);
    expect(item('tree').scale, closeTo(0.7, 1e-9));
  });

  test('blank entries are refused', () async {
    expect(() => w.addEntry(), throwsArgumentError);
    expect(() => w.addEntry(title: '  ', text: ' \n'), throwsArgumentError);
  });

  test('negated words add nothing, and the entry is still saved', () async {
    final grown = await w.addEntry(text: "I don't have a tree here");
    expect(grown, isEmpty);
    expect(w.items, isEmpty);
    expect(w.entries.length, 1);
  });

  test('moving, resizing and recoloring a piece marks it as the person\'s own', () async {
    await w.addEntry(text: 'a tree');
    final id = item('tree').id;
    await w.moveItem(id, 1.7, -0.3);
    expect((item('tree').x, item('tree').y), (1.0, 0.0)); // clamped inside the scene
    expect(item('tree').userEdited, isTrue);
    await w.scaleItem(id, 9);
    expect(item('tree').scale, 2.0);
    await w.scaleItem(id, 0.01);
    expect(item('tree').scale, 0.3);
    await w.setColor(id, 0xFF112233);
    expect(item('tree').colorValue, 0xFF112233);
    await w.setColor(id, null);
    expect(item('tree').colorValue, isNull);

    await w.addEntry(text: 'tree tree tree tree tree');
    expect(item('tree').scale, 0.3); // the diary does not override their choice
    expect(item('tree').x, 1.0);
  });

  test('removing a piece sticks: it does not return when the diary mentions it again', () async {
    await w.addEntry(text: 'a tree');
    await w.removeItem(item('tree').id);
    expect(w.items, isEmpty);
    expect(w.dismissed, {'tree'});
    await w.addEntry(text: 'more trees');
    expect(w.items, isEmpty);
    final again = WorldController(store, clock: () => now);
    await again.load();
    expect(again.dismissed, {'tree'});
  });

  test('adding a piece by hand always works and lifts the removal', () async {
    await w.addEntry(text: 'a tree');
    await w.removeItem(item('tree').id);
    await w.addPiece('tree');
    expect(item('tree').userEdited, isTrue);
    expect(w.dismissed, isEmpty);
    await w.addPiece('not-a-kind'); // ignored safely
    expect(w.items.length, 1);
  });

  test('editing an entry so it no longer mentions something keeps the piece; deleting an entry too', () async {
    await w.addEntry(text: 'a tree');
    final e = w.entries.single;
    now = now.add(const Duration(hours: 1));
    await w.updateEntry(WorldEntry(id: e.id, title: e.title, text: 'just feelings', createdAt: e.createdAt, updatedAt: now));
    expect(item('tree').kind, 'tree');
    await w.deleteEntry(e.id);
    expect(w.entries, isEmpty);
    expect(item('tree').kind, 'tree');
  });

  test('background path is saved and can be cleared', () async {
    await w.setBackground('images/sky.jpg');
    final again = WorldController(store, clock: () => now);
    await again.load();
    expect(again.backgroundPath, 'images/sky.jpg');
    await again.setBackground(null);
    expect(again.backgroundPath, isNull);
  });
}
