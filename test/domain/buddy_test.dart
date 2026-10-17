import 'package:flutter_test/flutter_test.dart';
import 'package:plural_app/domain/buddy.dart';
import 'package:plural_app/domain/little.dart';

void main() {
  final t0 = DateTime(2026, 10, 14, 9);

  test('time away never makes the buddy worse than sleepy (floor), and never negative', () {
    final s = const BuddyState().copyWith(updatedAt: t0);
    final later = s.settle(t0.add(const Duration(days: 365)));
    expect(later.joy, 30);
    expect(later.tummy, 30);
    expect(later.moodAt(t0.add(const Duration(days: 365))), BuddyMood.sleepy);
    expect(later.name, 'Buddy'); // still here, nothing lost
  });

  test('a normal day of absence only dips a little', () {
    final s = const BuddyState().copyWith(updatedAt: t0);
    final d = s.settle(t0.add(const Duration(hours: 10)));
    expect(d.joy, 60);
    expect(d.tummy, 50);
    expect(d.moodAt(t0.add(const Duration(hours: 10))), BuddyMood.content);
  });

  test('a fresh buddy is happy', () {
    final s = const BuddyState().copyWith(updatedAt: t0);
    expect(s.moodAt(t0), BuddyMood.happy);
  });

  test('care works, raises numbers, caps at 100, and counts', () {
    var s = const BuddyState().copyWith(updatedAt: t0);
    s = s.care(BuddyAction.feed, t0);
    expect(s.tummy, 95);
    expect(s.joy, 75);
    expect(s.careCount, 1);
    s = s.care(BuddyAction.feed, t0.add(const Duration(minutes: 6)));
    expect(s.tummy, 100);
    expect(s.careCount, 2);
  });

  test('cooldown: the same action twice within 5 minutes does nothing', () {
    var s = const BuddyState().copyWith(updatedAt: t0);
    s = s.care(BuddyAction.play, t0);
    expect(s.canCare(BuddyAction.play, t0.add(const Duration(minutes: 4))), isFalse);
    final same = s.care(BuddyAction.play, t0.add(const Duration(minutes: 4)));
    expect(same.careCount, 1);
    expect(s.canCare(BuddyAction.cuddle, t0.add(const Duration(minutes: 1))), isTrue); // other actions are separate
    expect(s.canCare(BuddyAction.play, t0.add(const Duration(minutes: 5))), isTrue);
  });

  test('if the phone clock goes backwards, care is still allowed', () {
    var s = const BuddyState().copyWith(updatedAt: t0);
    s = s.care(BuddyAction.feed, t0);
    expect(s.canCare(BuddyAction.feed, t0.subtract(const Duration(hours: 3))), isTrue);
  });

  test('play makes a little hungry but never below the floor', () {
    var s = const BuddyState(tummy: 31, joy: 50).copyWith(updatedAt: t0);
    s = s.care(BuddyAction.play, t0);
    expect(s.tummy, 30);
    expect(s.joy, 70);
  });

  test('JSON round trip and old/missing data loads safely', () {
    final s = const BuddyState(name: 'Mochi', species: 'cat', careCount: 4)
        .copyWith(updatedAt: t0, lastCare: {'feed': t0});
    final b = BuddyState.fromJson(s.toJson());
    expect(b.name, 'Mochi');
    expect(b.species, 'cat');
    expect(b.lastCare['feed'], t0);
    final empty = BuddyState.fromJson({'id': 'buddy'});
    expect(empty.name, 'Buddy');
    expect(empty.enabled, isTrue);
    expect(empty.species, 'blob');
  });

  test('greetings use the alter name, adapt to littles, and have a no-name version', () {
    expect(buddyGreeting(alterName: 'Bob', mood: BuddyMood.happy), 'Hi, Bob! 💜');
    expect(buddyGreeting(alterName: '  ', mood: BuddyMood.happy), 'Hi there!');
    expect(buddyGreeting(alterName: null, mood: BuddyMood.sleepy), 'Yawn... hi there! 😴');
    expect(buddyGreeting(alterName: 'Pip', mood: BuddyMood.happy, level: LittleLevel.child), 'Hi Pip! 🌈');
    expect(buddyGreeting(alterName: 'Pip', mood: BuddyMood.happy, level: LittleLevel.young), 'Hiii Pip!! 🧸');
    expect(buddyGreeting(alterName: 'Bob 🌲', mood: BuddyMood.sleepy), contains('Bob 🌲'));
  });
}
