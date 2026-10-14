import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plural_app/controllers/alter_controller.dart';
import 'package:plural_app/controllers/buddy_controller.dart';
import 'package:plural_app/controllers/front_controller.dart';
import 'package:plural_app/controllers/settings_controller.dart';
import 'package:plural_app/data/doc_store.dart';
import 'package:plural_app/domain/buddy.dart';
import 'package:plural_app/domain/rewards.dart';
import 'package:plural_app/ui/buddy_card.dart';
import 'package:plural_app/ui/buddy_screen.dart';
import 'package:plural_app/ui/buddy_view.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import '../helpers/harness.dart';

class E {
  E(this.alters, this.front, this.buddy, this.settings);
  final SettingsController settings;
  final AlterController alters;
  final FrontController front;
  final BuddyController buddy;
  List<SingleChildWidget> get p => [
        ChangeNotifierProvider.value(value: alters),
        ChangeNotifierProvider.value(value: front),
        ChangeNotifierProvider.value(value: buddy),
        ChangeNotifierProvider.value(value: settings),
      ];
}

Future<E> make() async {
  final store = MemoryDocStore();
  final now = DateTime(2026, 10, 14, 9);
  final a = AlterController(store);
  await a.load();
  final f = FrontController(store, clock: () => now);
  await f.load();
  final b = BuddyController(store, clock: () => now);
  await b.load();
  final s = SettingsController(store);
  await s.load();
  return E(a, f, b, s);
}

void main() {
  testWidgets('buddy greets whoever is out by name', (tester) async {
    final e = await make();
    final bob = await e.alters.create(name: 'Bob');
    await e.front.set(primary: bob.id);
    await pumpScreen(tester, const Scaffold(body: BuddyCard()), providers: e.p);
    expect(find.text('Hi, Bob! 💜'), findsOneWidget);
    expect(find.text('Buddy'), findsOneWidget);
  });

  testWidgets('nobody out, or the out alter was removed: a friendly generic hello', (tester) async {
    final e = await make();
    await pumpScreen(tester, const Scaffold(body: BuddyCard()), providers: e.p);
    expect(find.text('Hi there!'), findsOneWidget);
    final gone = await e.alters.create(name: 'Gone');
    await e.front.set(primary: gone.id);
    await e.alters.delete(gone.id);
    await tester.pumpAndSettle();
    expect(find.text('Hi there!'), findsOneWidget);
  });

  testWidgets('feeding works once, then the button rests during the cooldown', (tester) async {
    final e = await make();
    await pumpScreen(tester, const Scaffold(body: BuddyCard()), providers: e.p);
    await tester.tap(find.byKey(const Key('buddy-feed')));
    await tester.pumpAndSettle();
    expect(e.buddy.state.careCount, 1);
    final btn = tester.widget<FilledButton>(find.byKey(const Key('buddy-feed')));
    expect(btn.onPressed, isNull);
    final play = tester.widget<FilledButton>(find.byKey(const Key('buddy-play')));
    expect(play.onPressed, isNotNull);
  });

  testWidgets('a new badge shows a celebration that can be dismissed', (tester) async {
    final e = await make();
    await pumpScreen(tester, const Scaffold(body: BuddyCard()), providers: e.p);
    await e.buddy.refresh(alterCount: 1, history: []);
    await tester.pumpAndSettle();
    expect(find.text('New badge: First friend!'), findsOneWidget);
    await tester.tap(find.byKey(const Key('celebrate-ok')));
    await tester.pumpAndSettle();
    expect(find.text('New badge: First friend!'), findsNothing);
  });

  testWidgets('buddy can be hidden from its menu', (tester) async {
    final e = await make();
    await pumpScreen(tester, const Scaffold(body: BuddyCard()), providers: e.p);
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hide my buddy'));
    await tester.pumpAndSettle();
    expect(e.buddy.state.enabled, isFalse);
    expect(find.byKey(const Key('buddy-feed')), findsNothing);
  });

  testWidgets('Buddy & badges screen: locked vs earned badges, locked accessories cannot be chosen', (tester) async {
    tester.view.physicalSize = const Size(800, 3200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final e = await make();
    await pumpScreen(tester, const BuddyScreen(), providers: e.p);
    expect(find.textContaining('Locked: Add your first alter'), findsOneWidget);
    expect(find.textContaining('never takes anything away'), findsOneWidget);

    await e.buddy.refresh(alterCount: 1, history: []);
    await tester.pumpAndSettle();
    expect(find.descendant(of: find.byKey(const Key('badge-first-alter')), matching: find.textContaining('Earned')), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('acc-bow')));
    await tester.tap(find.byKey(const Key('acc-bow')));
    await tester.pumpAndSettle();
    expect(e.buddy.state.accessory, 'bow');
    await tester.ensureVisible(find.byKey(const Key('acc-crown')));
    await tester.tap(find.byKey(const Key('acc-crown')), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(e.buddy.state.accessory, 'bow'); // crown is still locked
  });

  testWidgets('rename and species from the Buddy screen', (tester) async {
    tester.view.physicalSize = const Size(800, 3200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final e = await make();
    await pumpScreen(tester, const BuddyScreen(), providers: e.p);
    await tester.enterText(find.byKey(const Key('buddy-name')), 'Mochi');
    await tester.tap(find.byKey(const Key('buddy-rename')));
    await tester.pumpAndSettle();
    expect(e.buddy.state.name, 'Mochi');
    await tester.ensureVisible(find.byKey(const Key('species-cat')));
    await tester.tap(find.byKey(const Key('species-cat')));
    await tester.pumpAndSettle();
    expect(e.buddy.state.species, 'cat');
  });

  testWidgets('every kind of buddy, in every mood and accessory, draws without errors', (tester) async {
    expect(
      kBuddySpecies,
      containsAll(['bunny', 'dog', 'cat', 'rabbit', 'frog', 'turtle', 'butterfly', 'fairy', 'unicorn']),
    );
    for (final sp in kBuddySpecies) {
      for (final mood in BuddyMood.values) {
        for (final acc in ['', ...kAccessories]) {
          for (final outfit in ['', ...kOutfits]) {
            await tester.pumpWidget(MaterialApp(
              home: Scaffold(
                body: BuddyView(
                    species: sp, color: Colors.purple, mood: mood, accessory: acc, outfit: outfit),
              ),
            ));
          }
        }
      }
    }
    expect(tester.takeException(), isNull);
  });
}
