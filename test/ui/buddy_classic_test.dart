import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plural_app/controllers/alter_controller.dart';
import 'package:plural_app/controllers/buddy_controller.dart';
import 'package:plural_app/controllers/front_controller.dart';
import 'package:plural_app/controllers/settings_controller.dart';
import 'package:plural_app/data/doc_store.dart';
import 'package:plural_app/domain/buddy.dart';
import 'package:plural_app/ui/buddy_card.dart';
import 'package:plural_app/ui/buddy_screen.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import '../helpers/harness.dart';

final t0 = DateTime(2026, 10, 1, 9);

class Env {
  Env(this.store, this.alters, this.front, this.buddy, this.settings);
  final MemoryDocStore store;
  final AlterController alters;
  final FrontController front;
  final BuddyController buddy;
  final SettingsController settings;
  List<SingleChildWidget> get p => [
        ChangeNotifierProvider.value(value: alters),
        ChangeNotifierProvider.value(value: front),
        ChangeNotifierProvider.value(value: buddy),
        ChangeNotifierProvider.value(value: settings),
      ];
}

Future<Env> make({required DateTime now, bool classicSince = false}) async {
  final store = MemoryDocStore();
  if (classicSince) {
    await store.put('buddy', const BuddyState(classic: true, name: 'Mochi')
        .copyWith(updatedAt: t0, lastSeen: t0)
        .toJson());
  }
  final s = SettingsController(store);
  await s.load();
  final a = AlterController(store);
  await a.load();
  final f = FrontController(store, clock: () => now);
  await f.load();
  final b = BuddyController(store, clock: () => now);
  await b.load();
  return Env(store, a, f, b, s);
}

void main() {
  void bigScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 3200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  testWidgets('classic switch is off by default; the warning appears before it turns on', (tester) async {
    bigScreen(tester);
    final e = await make(now: t0);
    await pumpScreen(tester, const BuddyScreen(), providers: e.p);
    final sw = tester.widget<SwitchListTile>(find.byKey(const Key('buddy-classic')));
    expect(sw.value, isFalse);

    await tester.tap(find.byKey(const Key('buddy-classic')));
    await tester.pumpAndSettle();
    expect(find.textContaining('pass away'), findsOneWidget);
    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();
    expect(e.buddy.state.classic, isFalse);

    await tester.tap(find.byKey(const Key('buddy-classic')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('classic-confirm')));
    await tester.pumpAndSettle();
    expect(e.buddy.state.classic, isTrue);
  });

  testWidgets('a passed buddy shows a gentle memorial and a button to hatch a new egg', (tester) async {
    final e = await make(now: t0.add(const Duration(days: 9)), classicSince: true);
    await pumpScreen(tester, const Scaffold(body: BuddyCard()), providers: e.p);
    expect(find.textContaining('Mochi has passed away'), findsOneWidget);
    expect(find.textContaining('Thank you for taking care of them'), findsOneWidget);
    expect(find.byKey(const Key('buddy-feed')), findsNothing);

    await tester.tap(find.byKey(const Key('buddy-hatch')));
    await tester.pumpAndSettle();
    expect(e.buddy.state.isPassed, isFalse);
    expect(find.byKey(const Key('buddy-feed')), findsOneWidget);
  });

  testWidgets('with a little out, the memorial uses soft words', (tester) async {
    final e = await make(now: t0.add(const Duration(days: 9)), classicSince: true);
    final pip = await e.alters.create(name: 'Pip');
    await e.alters.save(pip.copyWith(ageYears: 6));
    await e.front.set(primary: pip.id);
    await pumpScreen(tester, const Scaffold(body: BuddyCard()), providers: e.p);
    expect(find.textContaining('long trip to the stars'), findsOneWidget);
    expect(find.textContaining('passed away'), findsNothing);
  });

  testWidgets('the Buddy screen remembers those who passed', (tester) async {
    bigScreen(tester);
    final e = await make(now: t0.add(const Duration(days: 9)), classicSince: true);
    await pumpScreen(tester, const BuddyScreen(), providers: e.p);
    expect(find.text('In loving memory'), findsOneWidget);
    expect(find.byKey(const Key('memorial-0')), findsOneWidget);
    expect(find.textContaining('Mochi'), findsWidgets);
  });

  testWidgets('little guard: while a little is out the classic switch cannot be changed', (tester) async {
    bigScreen(tester);
    final e = await make(now: t0);
    final pip = await e.alters.create(name: 'Pip');
    await e.alters.save(pip.copyWith(ageYears: 6));
    await e.front.set(primary: pip.id);
    await pumpScreen(tester, const BuddyScreen(), providers: e.p);
    final sw = tester.widget<SwitchListTile>(find.byKey(const Key('buddy-classic')));
    expect(sw.onChanged, isNull);
    expect(find.textContaining('grown-up'), findsWidgets);
  });
}
