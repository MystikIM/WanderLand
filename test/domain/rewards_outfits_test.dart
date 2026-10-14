import 'package:flutter_test/flutter_test.dart';
import 'package:plural_app/domain/rewards.dart';

void main() {
  test('3 different check-in days unlocks the shirt (the example Mystik gave)', () {
    final earned = earnedBadges(alterCount: 0, checkInDays: 3, careCount: 0);
    expect(outfitsUnlockedBy(earned), {'shirt'});
    expect(outfitsUnlockedBy(earnedBadges(alterCount: 0, checkInDays: 2, careCount: 0)), isEmpty);
  });

  test('the full outfit ladder', () {
    Set<String> o(int days, int care) =>
        outfitsUnlockedBy(earnedBadges(alterCount: 0, checkInDays: days, careCount: care));
    expect(o(7, 0), {'shirt', 'hoodie'});
    expect(o(14, 0), {'shirt', 'hoodie', 'dress'});
    expect(o(30, 0), {'shirt', 'hoodie', 'dress', 'cape'});
    expect(o(0, 50), {'pajamas'});
    expect(o(0, 49), isEmpty);
  });

  test('the two-week badge exists and counts days, not streaks', () {
    expect(earnedBadges(alterCount: 0, checkInDays: 13, careCount: 0), isNot(contains('checkin-14')));
    expect(earnedBadges(alterCount: 0, checkInDays: 14, careCount: 0), contains('checkin-14'));
  });

  test('every outfit is unlocked by exactly one badge, and star moved to buddy care', () {
    for (final o in kOutfits) {
      expect(kBadges.where((b) => b.outfit == o).length, 1, reason: o);
    }
    expect(kBadges.where((b) => b.outfit.isNotEmpty).every((b) => kOutfits.contains(b.outfit)), isTrue);
    expect(accessoriesUnlockedBy(['care-10']), {'star'});
    expect(accessoriesUnlockedBy(['checkin-3']), isEmpty);
  });
}
