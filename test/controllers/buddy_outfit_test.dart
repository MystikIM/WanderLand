import 'package:flutter_test/flutter_test.dart';
import 'package:plural_app/controllers/buddy_controller.dart';
import 'package:plural_app/data/doc_store.dart';
import 'package:plural_app/domain/models.dart';

FrontEntry fe(DateTime s) =>
    FrontEntry(id: '$s', alterId: 'a', tier: FrontTier.primary, start: s);

void main() {
  test('outfits: locked ones are ignored, unlocked ones can be worn and taken off, and it persists', () async {
    final store = MemoryDocStore();
    final now = DateTime(2026, 10, 14, 9);
    final c = BuddyController(store, clock: () => now);
    await c.load();
    await c.setOutfit('shirt');
    expect(c.state.outfit, '');

    await c.refresh(alterCount: 0, history: [
      fe(DateTime(2026, 10, 1)), fe(DateTime(2026, 10, 2)), fe(DateTime(2026, 10, 3)),
    ]);
    expect(c.unlockedOutfits, {'shirt'});
    await c.setOutfit('shirt');
    expect(c.state.outfit, 'shirt');
    await c.setOutfit('cape'); // still locked
    expect(c.state.outfit, 'shirt');

    final again = BuddyController(store, clock: () => now);
    await again.load();
    expect(again.state.outfit, 'shirt');
    await again.setOutfit('');
    expect(again.state.outfit, '');
  });
}
