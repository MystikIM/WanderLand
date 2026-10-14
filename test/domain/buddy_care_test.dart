import 'package:flutter_test/flutter_test.dart';
import 'package:plural_app/domain/buddy.dart';

void main() {
  final t0 = DateTime(2026, 10, 14, 9);
  BuddyState start() => const BuddyState(joy: 50, tummy: 50).copyWith(updatedAt: t0);

  test('every care action does something kind and counts once', () {
    final snack = start().care(BuddyAction.snack, t0);
    expect((snack.tummy, snack.joy), (60.0, 58.0));
    final walk = start().care(BuddyAction.walk, t0);
    expect((walk.joy, walk.tummy), (65.0, 45.0));
    final pet = start().care(BuddyAction.pet, t0);
    expect((pet.joy, pet.tummy), (58.0, 50.0));
    final wash = start().care(BuddyAction.wash, t0);
    expect((wash.joy, wash.tummy), (60.0, 50.0));
    for (final s in [snack, walk, pet, wash]) {
      expect(s.careCount, 1);
    }
  });

  test('each action has its own cooldown', () {
    var s = start().care(BuddyAction.pet, t0);
    expect(s.canCare(BuddyAction.pet, t0.add(const Duration(minutes: 1))), isFalse);
    for (final a in BuddyAction.values.where((a) => a != BuddyAction.pet)) {
      expect(s.canCare(a, t0.add(const Duration(minutes: 1))), isTrue, reason: a.name);
    }
    s = s.care(BuddyAction.wash, t0.add(const Duration(minutes: 1)));
    expect(s.careCount, 2);
  });

  test('there are exactly seven actions and each has a label', () {
    expect(BuddyAction.values.length, 7);
    expect(kBuddyActionLabels.keys.toSet(), BuddyAction.values.toSet());
    expect(kBuddyActionLabels[BuddyAction.snack], contains('Snack'));
  });

  test('old saved buddies with only the first three actions still load', () {
    final s = BuddyState.fromJson({
      'id': 'buddy',
      'lastCare': {'feed': t0.toIso8601String(), 'play': t0.toIso8601String()},
    });
    expect(s.canCare(BuddyAction.feed, t0), isFalse);
    expect(s.canCare(BuddyAction.walk, t0), isTrue);
  });
}
