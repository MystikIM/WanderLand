import 'package:flutter_test/flutter_test.dart';
import 'package:plural_app/controllers/buddy_controller.dart';
import 'package:plural_app/data/doc_store.dart';
import 'package:plural_app/domain/buddy.dart';
import 'package:plural_app/domain/models.dart';

FrontEntry fe(DateTime s) =>
    FrontEntry(id: '$s', alterId: 'a', tier: FrontTier.primary, start: s);

void main() {
  late MemoryDocStore store;
  late DateTime now;
  late BuddyController c;
  setUp(() async {
    store = MemoryDocStore();
    now = DateTime(2026, 10, 14, 9);
    c = BuddyController(store, clock: () => now);
    await c.load();
  });

  test('refresh awards badges once, celebrates them, and remembers them', () async {
    await c.refresh(alterCount: 1, history: [fe(DateTime(2026, 10, 14, 9))]);
    expect(c.earned.keys, containsAll(['first-alter', 'first-checkin']));
    expect(c.celebrations.map((b) => b.id), containsAll(['first-alter', 'first-checkin']));
    c.dismissCelebrations();
    expect(c.celebrations, isEmpty);
    await c.refresh(alterCount: 1, history: [fe(DateTime(2026, 10, 14, 9))]);
    expect(c.celebrations, isEmpty); // not celebrated twice

    final again = BuddyController(store, clock: () => now);
    await again.load();
    expect(again.earned.keys, containsAll(['first-alter', 'first-checkin']));
  });

  test('badges are never taken away, even if alters are deleted', () async {
    await c.refresh(alterCount: 5, history: []);
    expect(c.earned.keys, contains('alters-5'));
    await c.refresh(alterCount: 0, history: []);
    expect(c.earned.keys, containsAll(['first-alter', 'alters-5']));
  });

  test('care respects the cooldown and persists', () async {
    expect(await c.care(BuddyAction.feed), isTrue);
    expect(await c.care(BuddyAction.feed), isFalse);
    expect(c.state.careCount, 1);
    now = now.add(const Duration(minutes: 6));
    expect(await c.care(BuddyAction.feed), isTrue);
    final again = BuddyController(store, clock: () => now);
    await again.load();
    expect(again.state.careCount, 2);
  });

  test('caring ten times earns the buddy badge', () async {
    for (var i = 0; i < 10; i++) {
      await c.care(BuddyAction.cuddle);
      now = now.add(const Duration(minutes: 6));
    }
    expect(c.earned.keys, contains('care-10'));
  });

  test('accessories: locked ones are ignored, unlocked ones work', () async {
    await c.setAccessory('crown');
    expect(c.state.accessory, '');
    await c.refresh(alterCount: 10, history: []);
    expect(c.unlocked, containsAll(['bow', 'scarf', 'crown']));
    await c.setAccessory('crown');
    expect(c.state.accessory, 'crown');
    await c.setAccessory('');
    expect(c.state.accessory, '');
  });

  test('rename trims and refuses blank; species must be known', () async {
    await c.rename('  Mochi  ');
    expect(c.state.name, 'Mochi');
    await c.rename('   ');
    expect(c.state.name, 'Mochi');
    await c.setSpecies('cat');
    await c.setSpecies('dragon');
    expect(c.state.species, 'cat');
  });

  test('hiding the buddy keeps earning badges quietly (no pop-ups)', () async {
    await c.setEnabled(false);
    await c.refresh(alterCount: 1, history: []);
    expect(c.earned.keys, contains('first-alter'));
    expect(c.celebrations, isEmpty);
    await c.setEnabled(true);
    expect(c.state.enabled, isTrue);
  });
}
