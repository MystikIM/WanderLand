import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plural_app/app_links.dart';
import 'package:plural_app/controllers/alter_controller.dart';
import 'package:plural_app/controllers/front_controller.dart';
import 'package:plural_app/controllers/settings_controller.dart';
import 'package:plural_app/data/doc_store.dart';
import 'package:plural_app/data/image_store.dart';
import 'package:plural_app/domain/models.dart';
import 'package:plural_app/ui/alter_edit_screen.dart';
import 'package:plural_app/ui/front_screen.dart';
import 'package:plural_app/ui/home_shell.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import '../helpers/harness.dart';

class Env {
  Env(this.store, this.settings, this.alters, this.front);
  final MemoryDocStore store;
  final SettingsController settings;
  final AlterController alters;
  final FrontController front;
  List<SingleChildWidget> get providers => [
        ChangeNotifierProvider.value(value: settings),
        ChangeNotifierProvider.value(value: alters),
        ChangeNotifierProvider.value(value: front),
        Provider.value(value: ImageStore(Directory.systemTemp)),
        Provider<DocStore>.value(value: store),
        Provider<Directory>.value(value: Directory.systemTemp),
      ];
}

Future<Env> makeEnv({DateTime? now}) async {
  final store = MemoryDocStore();
  final s = SettingsController(store);
  await s.load();
  final a = AlterController(store);
  await a.load();
  final f = FrontController(store, clock: () => now ?? DateTime(2026, 10, 14, 18, 30));
  await f.load();
  return Env(store, s, a, f);
}

void main() {
  testWidgets('fresh install: no alters shows an invitation, no crash', (tester) async {
    final e = await makeEnv();
    await pumpScreen(tester, const FrontScreen(), providers: e.providers);
    expect(find.textContaining('Add your first'), findsOneWidget);
    expect(find.text('Nobody marked as out'), findsOneWidget);
  });

  testWidgets('switch flow: pick Cat, confirm, Cat is shown as out', (tester) async {
    final e = await makeEnv();
    await e.alters.create(name: 'Bob');
    final cat = await e.alters.create(name: 'Cat');
    await pumpScreen(tester, const FrontScreen(), providers: e.providers);
    await tester.tap(find.byKey(const Key('open-switch')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key('pick-${cat.id}')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('switch-confirm')));
    await tester.pumpAndSettle();
    expect(e.front.primaryId, cat.id);
    expect(find.text('Cat'), findsWidgets);
  });

  testWidgets('"nobody / not sure" clears the front', (tester) async {
    final e = await makeEnv();
    final bob = await e.alters.create(name: 'Bob');
    await e.front.set(primary: bob.id);
    await pumpScreen(tester, const FrontScreen(), providers: e.providers);
    await tester.tap(find.byKey(const Key('open-switch')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('switch-nobody')));
    await tester.pumpAndSettle();
    expect(e.front.primaryId, isNull);
  });

  Future<(Env, Alter, Alter)> withBobEvenings() async {
    final e = await makeEnv(now: DateTime(2026, 10, 14, 18, 30)); // a Wednesday
    final bob = await e.alters.create(name: 'Bob');
    final cat = await e.alters.create(name: 'Cat');
    for (var d = 1; d <= 13; d++) {
      if (DateTime(2026, 10, d).weekday <= 5) {
        await e.store.put('front', FrontEntry(
          id: 'f$d', alterId: bob.id, tier: FrontTier.primary,
          start: DateTime(2026, 10, d, 18), end: DateTime(2026, 10, d, 20),
        ).toJson());
      }
    }
    await e.front.load();
    return (e, bob, cat);
  }

  testWidgets('heads-up: picking Cat when Bob usually fronts shows a gentle note; picking Bob does not', (tester) async {
    final (e, bob, cat) = await withBobEvenings();
    await pumpScreen(tester, const FrontScreen(), providers: e.providers);
    await tester.tap(find.byKey(const Key('open-switch')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key('pick-${cat.id}')));
    await tester.pumpAndSettle();
    expect(find.text('Bob is often out around now.'), findsOneWidget);
    await tester.tap(find.byKey(Key('pick-${bob.id}')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('heads-up')), findsNothing);
  });

  testWidgets('heads-up can be dismissed, muted per alter, and never blocks the switch', (tester) async {
    final (e, bob, cat) = await withBobEvenings();
    await pumpScreen(tester, const FrontScreen(), providers: e.providers);
    await tester.tap(find.byKey(const Key('open-switch')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key('pick-${cat.id}')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('mute-heads-up')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('heads-up')), findsNothing);
    expect(e.settings.headsUp.muted, [bob.id]);
    await tester.tap(find.byKey(const Key('switch-confirm')));
    await tester.pumpAndSettle();
    expect(e.front.primaryId, cat.id);
  });

  testWidgets('heads-ups can be turned off entirely', (tester) async {
    final (e, _, cat) = await withBobEvenings();
    await e.settings.setHeadsUp(e.settings.headsUp.copyWith(enabled: false));
    await pumpScreen(tester, const FrontScreen(), providers: e.providers);
    await tester.tap(find.byKey(const Key('open-switch')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key('pick-${cat.id}')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('heads-up')), findsNothing);
  });

  testWidgets('a removed alter is never named in a heads-up', (tester) async {
    final (e, bob, cat) = await withBobEvenings();
    await e.alters.delete(bob.id);
    await pumpScreen(tester, const FrontScreen(), providers: e.providers);
    await tester.tap(find.byKey(const Key('open-switch')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key('pick-${cat.id}')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('heads-up')), findsNothing);
  });

  testWidgets('little mode: when a 6-year-old is out the wording turns kid-friendly', (tester) async {
    final e = await makeEnv();
    final pip = await e.alters.create(name: 'Pip');
    await e.alters.save(pip.copyWith(ageYears: 6));
    await e.front.set(primary: pip.id);
    await pumpScreen(tester, const FrontScreen(), providers: e.providers);
    expect(find.text("Hi! 🌈 Who's out right now?"), findsOneWidget);
  });

  testWidgets('little guard hides delete/archive while a little is out; off switches it back', (tester) async {
    final e = await makeEnv();
    final pip = await e.alters.create(name: 'Pip');
    await e.alters.save(pip.copyWith(ageYears: 6));
    final bob = await e.alters.create(name: 'Bob');
    await e.front.set(primary: pip.id);
    await pumpScreen(tester, AlterEditScreen(existing: bob), providers: e.providers);
    expect(find.byType(PopupMenuButton<String>), findsNothing);
    expect(find.byKey(const Key('guard-lock')), findsOneWidget);

    await e.settings.setProfile(e.settings.profile.copyWith(littleGuard: false));
    await tester.pumpAndSettle();
    expect(find.byType(PopupMenuButton<String>), findsOneWidget);
  });

  testWidgets('a notification/widget tap (DeepLinks) opens the switch sheet from any tab', (tester) async {
    final e = await makeEnv();
    await e.alters.create(name: 'Bob');
    await pumpScreen(tester, const HomeShell(initialTab: 2), providers: e.providers);
    DeepLinks.switchRequests.value++;
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('switch-confirm')), findsOneWidget);
  });
}
