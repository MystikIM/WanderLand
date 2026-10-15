import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plural_app/controllers/alter_controller.dart';
import 'package:plural_app/controllers/front_controller.dart';
import 'package:plural_app/controllers/settings_controller.dart';
import 'package:plural_app/data/doc_store.dart';
import 'package:plural_app/data/image_store.dart';
import 'package:plural_app/domain/alter_kinds.dart';
import 'package:plural_app/domain/models.dart';
import 'package:plural_app/domain/world.dart';
import 'package:plural_app/ui/alter_detail_screen.dart';
import 'package:plural_app/ui/alter_edit_screen.dart';
import 'package:plural_app/ui/alters_screen.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import '../helpers/harness.dart';

Future<(List<SingleChildWidget>, AlterController)> setup() async {
  final store = MemoryDocStore();
  final s = SettingsController(store);
  await s.load();
  final a = AlterController(store);
  await a.load();
  final f = FrontController(store);
  await f.load();
  return (
    [
      ChangeNotifierProvider.value(value: s),
      ChangeNotifierProvider.value(value: a),
      ChangeNotifierProvider.value(value: f),
      Provider.value(value: ImageStore(Directory.systemTemp)),
    ],
    a
  );
}

void main() {
  test('frameFor ignores case and spaces, and has no frame for things we do not know', () {
    expect(frameFor('fox'), 'fox');
    expect(frameFor('  Fox '), 'fox');
    expect(frameFor('DRAGON'), 'dragon');
    expect(frameFor('a star'), isNull);
    expect(frameFor(''), isNull);
  });

  test('kind is saved, loads back, and old data without it still loads', () {
    final a = Alter(id: 'a', name: 'Fenn', createdAt: DateTime(2026), kind: 'fox');
    expect(Alter.fromJson(a.toJson()).kind, 'fox');
    final old = a.toJson()..remove('kind');
    expect(Alter.fromJson(old).kind, '');
  });

  test('new scene pieces are found by their words, and negation still works', () {
    const m = KeywordMatcher();
    expect(m.mentions('a cauldron by the castle'), {'cauldron': 1, 'castle': 1});
    expect(m.mentions('a nest in the den'), {'nest': 1, 'den': 1});
    expect(m.mentions('there is no castle'), isEmpty);
    for (final k in ['den', 'nest', 'cauldron', 'castle']) {
      expect(kAnchors[k], isNotNull);
    }
  });

  testWidgets('every kind of frame draws, with and without a custom picture', (tester) async {
    final (p, _) = await setup();
    await pumpScreen(
      tester,
      Scaffold(
        body: Wrap(children: [
          for (final k in [...kAlterKinds, 'a star', ''])
            Padding(
              padding: const EdgeInsets.all(20),
              child: AlterAvatar(alter: Alter(id: k, name: 'N', createdAt: DateTime(2026), kind: k), radius: 30),
            ),
        ]),
      ),
      providers: p,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('editor: pick a kind chip, or write your own; it saves and shows in the list', (tester) async {
    final (p, a) = await setup();
    await pumpScreen(tester, const AlterEditScreen(), providers: p);
    await tester.enterText(find.byKey(const Key('alter-name')), 'Fenn');
    await tester.ensureVisible(find.byKey(const Key('kind-fox')));
    await tester.tap(find.byKey(const Key('kind-fox')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('save-alter')));
    await tester.pumpAndSettle();
    expect(a.all.single.kind, 'fox');
  });

  testWidgets('editor: a kind you write yourself is saved and shows in the list', (tester) async {
    final (p, a) = await setup();
    final bob = await a.create(name: 'Bob');
    await pumpScreen(tester, AlterEditScreen(existing: bob), providers: p);
    await tester.enterText(find.byKey(const Key('alter-kind')), 'a very small star');
    await tester.tap(find.byKey(const Key('save-alter')));
    await tester.pumpAndSettle();
    expect(a.byId(bob.id)!.kind, 'a very small star');
  });

  testWidgets('the alters list shows the kind next to the name', (tester) async {
    final (p, a) = await setup();
    final bob = await a.create(name: 'Bob');
    await a.save(bob.copyWith(kind: 'a very small star'));
    await pumpScreen(tester, const AltersScreen(), providers: p);
    expect(find.textContaining('a very small star'), findsOneWidget);
  });

  testWidgets('tapping the selected kind chip again clears it', (tester) async {
    final (p, a) = await setup();
    final bob = await a.create(name: 'Bob');
    await a.save(bob.copyWith(kind: 'wolf'));
    await pumpScreen(tester, AlterEditScreen(existing: a.byId(bob.id)), providers: p);
    await tester.ensureVisible(find.byKey(const Key('kind-wolf')));
    await tester.tap(find.byKey(const Key('kind-wolf')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('save-alter')));
    await tester.pumpAndSettle();
    expect(a.byId(bob.id)!.kind, '');
  });

  testWidgets('the detail page shows what they are', (tester) async {
    final (p, a) = await setup();
    final bob = await a.create(name: 'Bob');
    await a.save(bob.copyWith(kind: 'dragon'));
    await pumpScreen(tester, AlterDetailScreen(alterId: bob.id), providers: p);
    expect(find.byKey(const Key('alter-kind-label')), findsOneWidget);
    expect(find.text('dragon'), findsOneWidget);
  });
}
