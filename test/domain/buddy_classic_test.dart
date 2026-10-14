import 'package:flutter_test/flutter_test.dart';
import 'package:plural_app/domain/buddy.dart';

void main() {
  final t0 = DateTime(2026, 10, 1, 9);

  test('classic mode is off by default and an off buddy never passes, however long away', () {
    final s = const BuddyState().copyWith(updatedAt: t0, lastSeen: t0);
    expect(s.classic, isFalse);
    final v = s.visit(t0.add(const Duration(days: 400)));
    expect(v.isPassed, isFalse);
    expect(v.memorial, isEmpty);
  });

  test('classic: visiting within 7 days keeps the buddy and refreshes lastSeen', () {
    var s = const BuddyState(classic: true).copyWith(updatedAt: t0, lastSeen: t0);
    s = s.visit(t0.add(const Duration(days: 6, hours: 23)));
    expect(s.isPassed, isFalse);
    expect(s.lastSeen, t0.add(const Duration(days: 6, hours: 23)));
  });

  test('classic: exactly 7 days away passes, with a memorial dated when it happened', () {
    final s = const BuddyState(classic: true, name: 'Mochi', species: 'cat')
        .copyWith(updatedAt: t0, lastSeen: t0);
    final v = s.visit(t0.add(const Duration(days: 9)));
    expect(v.isPassed, isTrue);
    expect(v.passedAt, t0.add(kClassicAway));
    expect(v.memorial.single.name, 'Mochi');
    expect(v.memorial.single.species, 'cat');
  });

  test('a passed buddy cannot be cared for and visiting does not change anything', () {
    final s = const BuddyState(classic: true).copyWith(updatedAt: t0, lastSeen: t0)
        .visit(t0.add(const Duration(days: 8)));
    expect(s.canCare(BuddyAction.feed, t0.add(const Duration(days: 8))), isFalse);
    expect(s.care(BuddyAction.feed, t0.add(const Duration(days: 8))).careCount, 0);
    expect(identical(s.visit(t0.add(const Duration(days: 20))), s), isTrue);
    expect(s.memorial.length, 1);
  });

  test('classic removes the gentle floor so numbers can reach zero', () {
    final s = const BuddyState(classic: true).copyWith(updatedAt: t0, lastSeen: t0);
    final later = s.settle(t0.add(const Duration(days: 365)));
    expect(later.joy, 0);
    expect(later.tummy, 0);
  });

  test('hatching a new egg starts fresh but remembers everyone and keeps care counts', () {
    final passed = const BuddyState(classic: true, name: 'Mochi', careCount: 12)
        .copyWith(updatedAt: t0, lastSeen: t0)
        .visit(t0.add(const Duration(days: 8)));
    final egg = passed.hatchNew(t0.add(const Duration(days: 8)));
    expect(egg.isPassed, isFalse);
    expect(egg.name, 'Buddy');
    expect(egg.generation, 2);
    expect(egg.memorial.length, 1);
    expect(egg.careCount, 12);
    expect(egg.classic, isTrue);
    expect(egg.lastSeen, t0.add(const Duration(days: 8)));
    expect(egg.joy, 70);
  });

  test('turning classic off brings back a passed buddy and lifts them to a gentle level', () {
    final passed = const BuddyState(classic: true, name: 'Mochi')
        .copyWith(updatedAt: t0, lastSeen: t0)
        .visit(t0.add(const Duration(days: 8)));
    final back = passed.withClassic(false, t0.add(const Duration(days: 9)));
    expect(back.isPassed, isFalse);
    expect(back.classic, isFalse);
    expect(back.name, 'Mochi');
    expect(back.memorial, isEmpty);
    expect(back.joy, greaterThanOrEqualTo(kBuddyFloor));
    expect(back.tummy, greaterThanOrEqualTo(kBuddyFloor));
  });

  test('turning classic on starts the 7-day clock from now', () {
    final now = t0.add(const Duration(days: 30));
    final on = const BuddyState().copyWith(updatedAt: t0).withClassic(true, now);
    expect(on.classic, isTrue);
    expect(on.lastSeen, now);
    expect(on.visit(now.add(const Duration(days: 1))).isPassed, isFalse);
  });

  test('JSON round trip keeps classic data; old saved buddies load as not classic', () {
    final passed = const BuddyState(classic: true, name: 'Mochi')
        .copyWith(updatedAt: t0, lastSeen: t0)
        .visit(t0.add(const Duration(days: 8)));
    final back = BuddyState.fromJson(passed.toJson());
    expect(back.classic, isTrue);
    expect(back.isPassed, isTrue);
    expect(back.memorial.single.name, 'Mochi');
    expect(back.generation, 1);
    final old = BuddyState.fromJson({'id': 'buddy', 'name': 'Old'});
    expect(old.classic, isFalse);
    expect(old.isPassed, isFalse);
    expect(old.memorial, isEmpty);
    expect(old.generation, 1);
  });
}
