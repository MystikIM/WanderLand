import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plural_app/controllers/alter_controller.dart';
import 'package:plural_app/controllers/front_controller.dart';
import 'package:plural_app/controllers/journal_controller.dart';
import 'package:plural_app/controllers/settings_controller.dart';
import 'package:plural_app/data/doc_store.dart';
import 'package:plural_app/data/image_store.dart';
import 'package:plural_app/domain/pin_lock.dart';
import 'package:plural_app/ui/journal_screen.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import '../helpers/harness.dart';

void main() {
  var now = DateTime(2026, 10, 14, 9);

  Future<(JournalController, PinLock, AlterController, FrontController, List<SingleChildWidget>)> env() async {
    now = DateTime(2026, 10, 14, 9);
    final store = MemoryDocStore();
    final s = SettingsController(store);
    await s.load();
    final a = AlterController(store);
    await a.load();
    final f = FrontController(store, clock: () => now);
    await f.load();
    final j = JournalController(store, clock: () => now);
    await j.load();
    final lock = PinLock(store, clock: () => now);
    return (
      j,
      lock,
      a,
      f,
      <SingleChildWidget>[
        ChangeNotifierProvider.value(value: s),
        ChangeNotifierProvider.value(value: a),
        ChangeNotifierProvider.value(value: f),
        ChangeNotifierProvider.value(value: j),
        Provider.value(value: lock),
        Provider.value(value: ImageStore(Directory.systemTemp)),
      ],
    );
  }

  testWidgets('empty journal invites a first entry; adding one shows it in the list', (tester) async {
    final (j, _, _, _, p) = await env();
    await pumpScreen(tester, const JournalScreen(), providers: p);
    expect(find.textContaining('Write your first'), findsOneWidget);
    await tester.tap(find.byKey(const Key('journal-add')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('journal-title')), 'A good day');
    await tester.enterText(find.byKey(const Key('journal-body')), 'We **did it**');
    await tester.tap(find.byKey(const Key('journal-save')));
    await tester.pumpAndSettle();
    expect(j.entries.single.title, 'A good day');
    expect(find.text('A good day'), findsOneWidget);
  });

  testWidgets('saving a blank entry shows a kind message and saves nothing', (tester) async {
    final (j, _, _, _, p) = await env();
    await pumpScreen(tester, const JournalScreen(), providers: p);
    await tester.tap(find.byKey(const Key('journal-add')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('journal-save')));
    await tester.pumpAndSettle();
    expect(find.text('Write a title or something in the entry first'), findsOneWidget);
    expect(j.entries, isEmpty);
  });

  testWidgets('with a PIN: locked until the right PIN; wrong PIN is gentle; hint is shown', (tester) async {
    final (j, lock, _, _, p) = await env();
    await j.create(title: 'Secret thoughts', body: 'x');
    await lock.setPin('4821', hint: 'my first dog');
    await pumpScreen(tester, const JournalScreen(), providers: p);
    expect(find.text('Secret thoughts'), findsNothing);
    expect(find.textContaining('my first dog'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('pin-field')), '0000');
    await tester.tap(find.byKey(const Key('pin-submit')));
    await tester.pumpAndSettle();
    expect(find.text('That is not the right PIN'), findsOneWidget);
    expect(find.text('Secret thoughts'), findsNothing);

    await tester.enterText(find.byKey(const Key('pin-field')), '4821');
    await tester.tap(find.byKey(const Key('pin-submit')));
    await tester.pumpAndSettle();
    expect(find.text('Secret thoughts'), findsOneWidget);
  });

  testWidgets('forgot the PIN: starts the 24-hour wait, says when, and offers removal only after', (tester) async {
    final (_, lock, _, _, p) = await env();
    await lock.setPin('4821');
    await pumpScreen(tester, const JournalScreen(), providers: p);
    await tester.tap(find.byKey(const Key('pin-forgot')));
    await tester.pumpAndSettle();
    expect(find.textContaining('2026-10-15 09:00'), findsOneWidget);
    expect(find.byKey(const Key('pin-reset-now')), findsNothing);

    now = now.add(const Duration(hours: 25));
    // A fresh screen (as when the person reopens the Journal), not a reused one.
    await pumpScreen(tester, JournalScreen(key: UniqueKey()), providers: p);
    expect(find.byKey(const Key('pin-reset-now')), findsOneWidget);
    await tester.tap(find.byKey(const Key('pin-reset-now')));
    await tester.pumpAndSettle();
    expect(await lock.isSet, isFalse);
    expect(find.byKey(const Key('journal-add')), findsOneWidget);
  });

  testWidgets('the screen is honest that the PIN is a screen lock, not encryption', (tester) async {
    final (_, _, _, _, p) = await env();
    await pumpScreen(tester, const JournalScreen(), providers: p);
    await tester.tap(find.byKey(const Key('journal-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Set a PIN'));
    await tester.pumpAndSettle();
    expect(find.textContaining('not encryption'), findsOneWidget);
  });

  testWidgets('setting a PIN from the menu locks the journal next time', (tester) async {
    final (_, lock, _, _, p) = await env();
    await pumpScreen(tester, const JournalScreen(), providers: p);
    await tester.tap(find.byKey(const Key('journal-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Set a PIN'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('new-pin')), '1234');
    await tester.enterText(find.byKey(const Key('new-pin-hint')), 'the usual');
    await tester.tap(find.byKey(const Key('new-pin-save')));
    await tester.pumpAndSettle();
    expect(await lock.isSet, isTrue);
    expect(await lock.hint, 'the usual');
  });
}
