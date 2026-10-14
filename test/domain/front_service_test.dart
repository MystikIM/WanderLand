import 'package:flutter_test/flutter_test.dart';
import 'package:plural_app/data/doc_store.dart';
import 'package:plural_app/domain/front_service.dart';
import 'package:plural_app/domain/models.dart';

void main() {
  late MemoryDocStore store;
  late DateTime t;
  late FrontService svc;

  setUp(() {
    store = MemoryDocStore();
    t = DateTime(2026, 10, 14, 9);
    svc = FrontService(store, clock: () => t);
  });

  test('setFront opens one primary entry', () async {
    await svc.setFront(primary: 'bob');
    final cur = await svc.current();
    expect(cur.length, 1);
    expect(cur.single.alterId, 'bob');
    expect(cur.single.tier, FrontTier.primary);
    expect(cur.single.end, isNull);
  });

  test('switching closes the old entry at the same instant the new one starts', () async {
    await svc.setFront(primary: 'bob');
    t = DateTime(2026, 10, 14, 11);
    await svc.setFront(primary: 'cat');
    final h = await svc.history();
    expect(h.length, 2);
    final bob = h.firstWhere((e) => e.alterId == 'bob');
    final cat = h.firstWhere((e) => e.alterId == 'cat');
    expect(bob.end, t);
    expect(cat.start, t);
    expect((await svc.current()).single.alterId, 'cat');
  });

  test('setting the same set again does nothing (no duplicate entries)', () async {
    await svc.setFront(primary: 'bob', coFront: ['cat']);
    t = DateTime(2026, 10, 14, 10);
    await svc.setFront(primary: 'bob', coFront: ['cat']);
    expect((await svc.history()).length, 2);
    expect((await svc.current()).length, 2);
  });

  test('co-front and co-con get their own tiers; primary is never repeated', () async {
    await svc.setFront(primary: 'bob', coFront: ['cat', 'bob'], coCon: ['dan', 'cat']);
    final cur = await svc.current();
    final tiers = {for (final e in cur) e.alterId: e.tier};
    expect(tiers, {'bob': FrontTier.primary, 'cat': FrontTier.coFront, 'dan': FrontTier.coCon});
  });

  test('clearFront closes everything and leaves nobody out', () async {
    await svc.setFront(primary: 'bob');
    t = DateTime(2026, 10, 14, 12);
    await svc.clearFront();
    expect(await svc.current(), isEmpty);
    expect((await svc.history()).single.end, t);
  });

  test('describeFront words', () {
    String label(String id) => id.toUpperCase();
    expect(describeFront([], label), 'Nobody marked as out');
    final e1 = FrontEntry(id: '1', alterId: 'bob', tier: FrontTier.primary, start: DateTime(2026));
    final e2 = FrontEntry(id: '2', alterId: 'cat', tier: FrontTier.coFront, start: DateTime(2026));
    expect(describeFront([e1], label), 'BOB');
    expect(describeFront([e1, e2], label), 'BOB (with CAT)');
  });
}
