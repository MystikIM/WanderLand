import 'package:flutter_test/flutter_test.dart';
import 'package:plural_app/controllers/journal_controller.dart';
import 'package:plural_app/data/doc_store.dart';

void main() {
  late MemoryDocStore store;
  var now = DateTime(2026, 10, 14, 9);
  late JournalController c;
  setUp(() async {
    store = MemoryDocStore();
    now = DateTime(2026, 10, 14, 9);
    c = JournalController(store, clock: () => now);
    await c.load();
  });

  test('create saves, persists, and lists newest edit first', () async {
    final a = await c.create(title: 'First', body: 'hello **world**');
    now = now.add(const Duration(hours: 1));
    final b = await c.create(title: 'Second', body: '', authorAlterId: 'bob');
    expect(c.entries.map((e) => e.id), [b.id, a.id]);
    final again = JournalController(store, clock: () => now);
    await again.load();
    expect(again.entries.length, 2);
    expect(again.entries.first.authorAlterId, 'bob');
  });

  test('a completely blank entry is rejected; title-only or body-only is fine', () async {
    expect(() => c.create(), throwsArgumentError);
    expect(() => c.create(title: '  ', body: '\n'), throwsArgumentError);
    await c.create(title: 'Only a title');
    await c.create(body: 'Only a body 🌲');
    expect(c.entries.length, 2);
  });

  test('update bumps updatedAt and moves the entry to the top; delete removes it', () async {
    final a = await c.create(title: 'A', body: 'x');
    now = now.add(const Duration(hours: 1));
    await c.create(title: 'B', body: 'y');
    now = now.add(const Duration(hours: 1));
    await c.update(a.copyWith(body: 'edited'));
    expect(c.entries.first.id, a.id);
    expect(c.entries.first.updatedAt, now);
    expect(c.entries.first.createdAt, a.createdAt);
    await c.delete(a.id);
    expect(c.entries.length, 1);
  });

  test('very long text is accepted', () async {
    final e = await c.create(title: 't', body: 'word ' * 20000);
    expect(c.entries.single.body.length, e.body.length);
  });
}
