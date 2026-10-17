import 'package:flutter_test/flutter_test.dart';
import 'package:plural_app/domain/models.dart';
import 'package:plural_app/domain/rewards.dart';

FrontEntry e(DateTime s) =>
    FrontEntry(id: '$s', alterId: 'a', tier: FrontTier.primary, start: s);

void main() {
  test('check-in days count different calendar days, not entries', () {
    expect(checkInDays([]), 0);
    expect(checkInDays([e(DateTime(2026, 10, 1, 9)), e(DateTime(2026, 10, 1, 21))]), 1);
    expect(checkInDays([e(DateTime(2026, 10, 1, 23, 50)), e(DateTime(2026, 10, 2, 0, 10))]), 2);
  });

  test('gaps never matter: 3 days spread over a month is still 3 days', () {
    final h = [e(DateTime(2026, 9, 1)), e(DateTime(2026, 9, 15)), e(DateTime(2026, 10, 14))];
    expect(checkInDays(h), 3);
    expect(earnedBadges(alterCount: 0, checkInDays: 3, careCount: 0), containsAll(['first-checkin', 'checkin-3']));
  });

  test('badge thresholds are exact', () {
    Set<String> g(int a, int d, int c) => earnedBadges(alterCount: a, checkInDays: d, careCount: c);
    expect(g(0, 0, 0), isEmpty);
    expect(g(1, 0, 0), {'first-alter'});
    expect(g(4, 0, 0), {'first-alter'});
    expect(g(5, 0, 0), {'first-alter', 'alters-5'});
    expect(g(10, 0, 0), containsAll(['alters-5', 'alters-10']));
    expect(g(0, 1, 0), {'first-checkin'});
    expect(g(0, 2, 0), {'first-checkin'});
    expect(g(0, 3, 0), {'first-checkin', 'checkin-3'});
    expect(g(0, 7, 0), contains('checkin-7'));
    expect(g(0, 29, 0), isNot(contains('checkin-30')));
    expect(g(0, 30, 0), contains('checkin-30'));
    expect(g(0, 0, 9), isEmpty);
    expect(g(0, 0, 10), {'care-10'});
    expect(g(0, 0, 50), {'care-10', 'care-50'});
  });

  test('every badge has a unique id and a how-to text', () {
    expect(kBadges.map((b) => b.id).toSet().length, kBadges.length);
    expect(kBadges.every((b) => b.how.isNotEmpty && b.title.isNotEmpty), isTrue);
  });
}
