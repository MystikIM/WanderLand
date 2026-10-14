import 'package:flutter_test/flutter_test.dart';
import 'package:plural_app/controllers/buddy_controller.dart';
import 'package:plural_app/data/doc_store.dart';
import 'package:plural_app/domain/buddy.dart';

void main() {
  final t0 = DateTime(2026, 10, 1, 9);

  Future<BuddyController> open(MemoryDocStore store, DateTime now) async {
    final c = BuddyController(store, clock: () => now);
    await c.load();
    return c;
  }

  test('classic is off by default; turning it on persists', () async {
    final store = MemoryDocStore();
    final c = await open(store, t0);
    expect(c.state.classic, isFalse);
    await c.setClassic(true);
    expect((await open(store, t0)).state.classic, isTrue);
  });

  test('opening the app every 6 days keeps a classic buddy alive', () async {
    final store = MemoryDocStore();
    await (await open(store, t0)).setClassic(true);
    for (var d = 6; d <= 30; d += 6) {
      final c = await open(store, t0.add(Duration(days: d)));
      expect(c.state.isPassed, isFalse, reason: 'day $d');
    }
  });

  test('away 8 days: passes, remembered, badges kept; hatching starts fresh and persists', () async {
    final store = MemoryDocStore();
    final c0 = await open(store, t0);
    await c0.refresh(alterCount: 1, history: []);
    await c0.setClassic(true);

    final c1 = await open(store, t0.add(const Duration(days: 8)));
    expect(c1.state.isPassed, isTrue);
    expect(c1.state.memorial.length, 1);
    expect(c1.earned.keys, contains('first-alter'));
    expect(await c1.care(BuddyAction.feed), isFalse);

    await c1.hatchNew();
    final c2 = await open(store, t0.add(const Duration(days: 8, hours: 1)));
    expect(c2.state.isPassed, isFalse);
    expect(c2.state.generation, 2);
    expect(c2.state.memorial.length, 1);
  });

  test('the passing is remembered if the app is re-opened later (not repeated)', () async {
    final store = MemoryDocStore();
    await (await open(store, t0)).setClassic(true);
    await open(store, t0.add(const Duration(days: 10)));
    final again = await open(store, t0.add(const Duration(days: 40)));
    expect(again.state.memorial.length, 1);
  });

  test('turning classic off revives a passed buddy; non-classic never passes', () async {
    final store = MemoryDocStore();
    await (await open(store, t0)).setClassic(true);
    final c = await open(store, t0.add(const Duration(days: 9)));
    expect(c.state.isPassed, isTrue);
    await c.setClassic(false);
    expect(c.state.isPassed, isFalse);
    expect(c.state.memorial, isEmpty);
    final far = await open(store, t0.add(const Duration(days: 400)));
    expect(far.state.isPassed, isFalse);
  });

  test('visit() (app resumed) can notice a passing without a restart', () async {
    final store = MemoryDocStore();
    var now = t0;
    final c = BuddyController(store, clock: () => now);
    await c.load();
    await c.setClassic(true);
    now = t0.add(const Duration(days: 8));
    await c.visit();
    expect(c.state.isPassed, isTrue);
  });
}
