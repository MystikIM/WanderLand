import 'package:flutter_test/flutter_test.dart';
import 'package:plural_app/domain/activity.dart';
import 'package:plural_app/domain/models.dart';

FrontEntry e(String alter, DateTime s, DateTime? end,
        {FrontTier tier = FrontTier.primary}) =>
    FrontEntry(id: '$alter$s', alterId: alter, tier: tier, start: s, end: end);

void main() {
  // 2026-10-12 is a Monday; 2026-10-14 is a Wednesday.
  final monday = DateTime(2026, 10, 12);

  test('weekStart is Monday 00:00', () {
    expect(Activity.weekStart(DateTime(2026, 10, 14, 15, 30)), monday);
    expect(Activity.weekStart(DateTime(2026, 10, 18, 23, 59)), monday); // Sunday
    expect(Activity.weekStart(monday), monday);
  });

  test('an entry crossing midnight is split between the two days', () {
    final days = Activity.weekDays(
      [e('bob', DateTime(2026, 10, 12, 22), DateTime(2026, 10, 13, 2))],
      monday,
      DateTime(2026, 10, 14),
    );
    expect(days[0]['bob'], const Duration(hours: 2));
    expect(days[1]['bob'], const Duration(hours: 2));
    expect(days[2]['bob'], isNull);
  });

  test('an entry from the previous week only counts its part inside this week', () {
    final days = Activity.weekDays(
      [e('bob', DateTime(2026, 10, 11, 23), DateTime(2026, 10, 12, 1))],
      monday,
      DateTime(2026, 10, 14),
    );
    expect(days[0]['bob'], const Duration(hours: 1));
  });

  test('an open entry runs up to now and not beyond', () {
    final days = Activity.weekDays(
      [e('cat', DateTime(2026, 10, 14, 9), null)],
      monday,
      DateTime(2026, 10, 14, 12),
    );
    expect(days[2]['cat'], const Duration(hours: 3));
    expect(days[3]['cat'], isNull);
  });

  test('empty history gives seven empty days and empty totals', () {
    final days = Activity.weekDays([], monday, DateTime(2026, 10, 14));
    expect(days.length, 7);
    expect(days.every((d) => d.isEmpty), isTrue);
    expect(Activity.weekTotals(days), isEmpty);
  });

  test('weekTotals adds days together', () {
    final days = Activity.weekDays([
      e('bob', DateTime(2026, 10, 12, 9), DateTime(2026, 10, 12, 10)),
      e('bob', DateTime(2026, 10, 13, 9), DateTime(2026, 10, 13, 11)),
    ], monday, DateTime(2026, 10, 14));
    expect(Activity.weekTotals(days)['bob'], const Duration(hours: 3));
  });

  // Bob fronts 18:00-20:00 every weekday from Oct 1 to Oct 13, 2026.
  List<FrontEntry> bobEvenings() => [
        for (var d = 1; d <= 13; d++)
          if (DateTime(2026, 10, d).weekday <= 5)
            e('bob', DateTime(2026, 10, d, 18), DateTime(2026, 10, d, 20)),
      ];
  final wedEvening = DateTime(2026, 10, 14, 18, 30);

  test('usualFronter finds the alter who usually fronts at this hour', () {
    expect(Activity.usualFronter(entries: bobEvenings(), now: wedEvening), 'bob');
  });

  test('headsUp shows Bob when Cat is picked, nothing when Bob is picked', () {
    expect(Activity.headsUp(entries: bobEvenings(), pickedAlterId: 'cat', now: wedEvening), 'bob');
    expect(Activity.headsUp(entries: bobEvenings(), pickedAlterId: 'bob', now: wedEvening), isNull);
  });

  test('weekend history does not count for a weekday', () {
    final onlyWeekend = [
      for (var d = 3; d <= 11; d++)
        if (DateTime(2026, 10, d).weekday >= 6)
          e('bob', DateTime(2026, 10, d, 18), DateTime(2026, 10, d, 20)),
    ];
    expect(Activity.usualFronter(entries: onlyWeekend, now: wedEvening), isNull);
  });

  test('not enough history says nothing', () {
    final few = [
      e('bob', DateTime(2026, 10, 12, 18), DateTime(2026, 10, 12, 20)),
      e('bob', DateTime(2026, 10, 13, 18), DateTime(2026, 10, 13, 20)),
    ];
    expect(Activity.usualFronter(entries: few, now: wedEvening), isNull);
    expect(Activity.usualFronter(entries: [], now: wedEvening), isNull);
  });

  test('a split pattern (no clear usual alter) says nothing', () {
    final split = [
      for (var d = 1; d <= 13; d++)
        if (DateTime(2026, 10, d).weekday <= 5)
          e(d.isEven ? 'bob' : 'cat', DateTime(2026, 10, d, 18), DateTime(2026, 10, d, 20)),
    ];
    // 9 weekdays: bob ~4, cat ~5 -> neither reaches 50% of days with a clear top
    final r = Activity.usualFronter(entries: split, now: wedEvening, minShare: 0.6);
    expect(r, isNull);
  });

  test('recentAlterIds: newest first, no repeats, primary only, capped', () {
    final h = [
      e('a', DateTime(2026, 10, 1), DateTime(2026, 10, 2)),
      e('b', DateTime(2026, 10, 2), DateTime(2026, 10, 3)),
      e('a', DateTime(2026, 10, 3), DateTime(2026, 10, 4)),
      e('z', DateTime(2026, 10, 4), null, tier: FrontTier.coFront),
      e('c', DateTime(2026, 10, 5), null),
    ];
    expect(Activity.recentAlterIds(h, limit: 3), ['c', 'a', 'b']);
    expect(Activity.recentAlterIds(h, limit: 2), ['c', 'a']);
  });
}
