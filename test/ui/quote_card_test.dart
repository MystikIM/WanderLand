import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plural_app/controllers/alter_controller.dart';
import 'package:plural_app/controllers/front_controller.dart';
import 'package:plural_app/controllers/settings_controller.dart';
import 'package:plural_app/data/doc_store.dart';
import 'package:plural_app/domain/quotes.dart';
import 'package:plural_app/ui/appearance_screen.dart';
import 'package:plural_app/ui/quote_card.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import '../helpers/harness.dart';

void main() {
  var now = DateTime(2026, 10, 14, 9);

  Future<(SettingsController, AlterController, FrontController, List<SingleChildWidget>)> env() async {
    now = DateTime(2026, 10, 14, 9);
    final store = MemoryDocStore();
    final s = SettingsController(store);
    await s.load();
    final a = AlterController(store);
    await a.load();
    final f = FrontController(store, clock: () => now);
    await f.load();
    return (
      s,
      a,
      f,
      <SingleChildWidget>[
        ChangeNotifierProvider.value(value: s),
        ChangeNotifierProvider.value(value: a),
        ChangeNotifierProvider.value(value: f),
      ],
    );
  }

  String shown(WidgetTester tester) =>
      tester.widget<Text>(find.byKey(const Key('quote-text'))).data!;

  testWidgets('a kind note shows, stays the same all day, and is remembered', (tester) async {
    final (s, _, _, p) = await env();
    await pumpScreen(tester, const Scaffold(body: QuoteCard()), providers: p);
    final first = shown(tester);
    expect(kQuotes, contains(first));
    expect(s.quotes.lastDay, '2026-10-14');
    await pumpScreen(tester, const Scaffold(body: QuoteCard()), providers: p);
    expect(shown(tester), first);
  });

  testWidgets('"Another one" shows a different note; closing hides the card for now', (tester) async {
    final (_, _, _, p) = await env();
    await pumpScreen(tester, const Scaffold(body: QuoteCard()), providers: p);
    final first = shown(tester);
    await tester.tap(find.byKey(const Key('quote-next')));
    await tester.pumpAndSettle();
    expect(shown(tester), isNot(first));
    await tester.tap(find.byKey(const Key('quote-dismiss')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('quote-text')), findsNothing);
  });

  testWidgets('turned off: nothing is shown', (tester) async {
    final (s, _, _, p) = await env();
    await s.setQuotes(s.quotes.copyWith(enabled: false));
    await pumpScreen(tester, const Scaffold(body: QuoteCard()), providers: p);
    expect(find.byKey(const Key('quote-text')), findsNothing);
  });

  testWidgets('a new day brings a new note', (tester) async {
    final (_, _, f, p) = await env();
    await pumpScreen(tester, const Scaffold(body: QuoteCard()), providers: p);
    final today = shown(tester);
    now = DateTime(2026, 10, 15, 9);
    await f.load();
    await tester.pumpAndSettle();
    expect(shown(tester), isNot(today));
  });

  testWidgets('when a little is out the note comes from the gentle little set', (tester) async {
    final (_, a, f, p) = await env();
    final pip = await a.create(name: 'Pip');
    await a.save(pip.copyWith(ageYears: 6));
    await f.set(primary: pip.id);
    await pumpScreen(tester, const Scaffold(body: QuoteCard()), providers: p);
    expect(kLittleQuotes, contains(shown(tester)));
  });

  testWidgets('Appearance has a switch for kind notes that is saved', (tester) async {
    final (s, _, _, p) = await env();
    await pumpScreen(tester, AppearanceScreen(onImportFont: () async {}), providers: p);
    await tester.ensureVisible(find.byKey(const Key('quotes-switch')));
    await tester.tap(find.byKey(const Key('quotes-switch')));
    await tester.pumpAndSettle();
    expect(s.quotes.enabled, isFalse);
  });
}
