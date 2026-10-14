import 'package:flutter_test/flutter_test.dart';
import 'package:plural_app/controllers/alter_controller.dart';
import 'package:plural_app/data/doc_store.dart';

void main() {
  late MemoryDocStore store;
  late AlterController c;
  setUp(() async {
    store = MemoryDocStore();
    c = AlterController(store, clock: () => DateTime(2026, 10, 14));
    await c.load();
  });

  test('create trims, saves, and persists across reload', () async {
    final a = await c.create(name: '  Bob 🌲  ', pronouns: 'they/them');
    expect(a.name, 'Bob 🌲');
    final c2 = AlterController(store);
    await c2.load();
    expect(c2.byId(a.id)!.pronouns, 'they/them');
  });

  test('empty or blank names are rejected', () async {
    expect(() => c.create(name: '   '), throwsArgumentError);
  });

  test('very long names are accepted', () async {
    final a = await c.create(name: 'x' * 300);
    expect(c.byId(a.id)!.name.length, 300);
  });

  test('active hides archived and sorts by name ignoring case', () async {
    final b = await c.create(name: 'bob');
    await c.create(name: 'Alice');
    final z = await c.create(name: 'Zed');
    await c.setArchived(z.id, true);
    expect(c.active.map((a) => a.name), ['Alice', 'bob']);
    expect(c.all.length, 3);
    await c.setArchived(z.id, false);
    expect(c.active.length, 3);
    expect(b.id, isNot(z.id));
  });

  test('label falls back safely for a removed alter', () async {
    final a = await c.create(name: 'Cat');
    expect(c.label(a.id), 'Cat');
    await c.delete(a.id);
    expect(c.label(a.id), 'Removed alter');
    expect(c.byId(a.id), isNull);
  });

  test('save updates fields and notifies', () async {
    final a = await c.create(name: 'Dan');
    var n = 0;
    c.addListener(() => n++);
    await c.save(a.copyWith(bio: 'Loves **tea**', tags: ['host']));
    expect(c.byId(a.id)!.bio, 'Loves **tea**');
    expect(n, 1);
  });
}
