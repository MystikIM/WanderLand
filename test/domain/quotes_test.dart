import 'package:flutter_test/flutter_test.dart';
import 'package:plural_app/domain/little.dart';
import 'package:plural_app/domain/quotes.dart';

void main() {
  test('both note banks are healthy: unique, short, and sized to cycle fully', () {
    for (final bank in [kQuotes, kLittleQuotes]) {
      expect(bank.toSet().length, bank.length);
      expect(bank.every((q) => q.trim().isNotEmpty && q.length <= 120), isTrue);
      expect(bank.length % 7, isNot(0)); // the day step is 7, so every note gets its turn
    }
    expect(kQuotes.length, greaterThanOrEqualTo(40));
    expect(kLittleQuotes.length, greaterThanOrEqualTo(24));
  });

  test('notes never tell a plural system they are one person or to merge', () {
    final all = [...kQuotes, ...kLittleQuotes].join(' ').toLowerCase();
    for (final bad in ['just one person', 'integrate', 'fuse', 'only one', 'fake', 'attention']) {
      expect(all.contains(bad), isFalse, reason: bad);
    }
  });

  test('a day keeps the same note all day, and the next day gets a different one', () {
    final morning = DateTime(2026, 10, 14, 8);
    final p1 = chooseTodaysQuote(const QuotePrefs(), morning);
    expect(p1.lastDay, '2026-10-14');
    final p2 = chooseTodaysQuote(p1, DateTime(2026, 10, 14, 23, 59));
    expect(identical(p2, p1), isTrue);
    final p3 = chooseTodaysQuote(p2, DateTime(2026, 10, 15, 0, 1));
    expect(quoteText(LittleLevel.none, p3.lastIndex), isNot(quoteText(LittleLevel.none, p1.lastIndex)));
  });

  test('over 200 days: never the same note two days running, and every note appears', () {
    var p = const QuotePrefs();
    String? prev;
    final seen = <String>{};
    for (var d = 0; d < 200; d++) {
      p = chooseTodaysQuote(p, DateTime(2026, 10, 1 + d, 9));
      final text = quoteText(LittleLevel.none, p.lastIndex);
      expect(text, isNot(prev));
      prev = text;
      seen.add(text);
    }
    expect(seen.length, kQuotes.length);
  });

  test('"another one" moves to the next note; the index math is safe for any number', () {
    final p = chooseTodaysQuote(const QuotePrefs(), DateTime(2026, 10, 14));
    final n = nextQuote(p);
    expect(n.lastIndex, p.lastIndex + 1);
    expect(n.lastDay, p.lastDay);
    expect(() => quoteText(LittleLevel.none, -5), returnsNormally);
    expect(() => quoteText(LittleLevel.young, 1000003), returnsNormally);
    expect(quoteText(LittleLevel.child, 3), quoteText(LittleLevel.young, 3));
    expect(kLittleQuotes, contains(quoteText(LittleLevel.young, 3)));
  });

  test('QuotePrefs defaults on and round trips', () {
    expect(const QuotePrefs().enabled, isTrue);
    final back = QuotePrefs.fromJson(
        const QuotePrefs(enabled: false, lastDay: '2026-10-14', lastIndex: 9).toJson());
    expect(back.enabled, isFalse);
    expect(back.lastDay, '2026-10-14');
    expect(back.lastIndex, 9);
    expect(QuotePrefs.fromJson({'id': 'quotes'}).lastIndex, -1);
  });
}
