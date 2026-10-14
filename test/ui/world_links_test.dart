import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plural_app/controllers/alter_controller.dart';
import 'package:plural_app/controllers/world_controller.dart';
import 'package:plural_app/data/doc_store.dart';
import 'package:plural_app/data/image_store.dart';
import 'package:plural_app/domain/alter_links.dart';
import 'package:plural_app/ui/linked_text.dart';
import 'package:plural_app/ui/world_entry_screen.dart';
import 'package:plural_app/ui/world_screen.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import '../helpers/harness.dart';

void main() {
  late AlterController alters;
  late WorldController world;
  late List<SingleChildWidget> providers;

  Future<void> setUpEnv() async {
    final store = MemoryDocStore();
    alters = AlterController(store);
    await alters.load();
    world = WorldController(
      store,
      clock: () => DateTime(2026, 10, 14, 9),
      names: () => [for (final a in alters.all) NameRef(a.id, a.name)],
    );
    await world.load();
    providers = <SingleChildWidget>[
      ChangeNotifierProvider.value(value: alters),
      ChangeNotifierProvider.value(value: world),
      Provider.value(value: ImageStore(Directory.systemTemp)),
    ];
  }

  Finder inAppBar(String text) =>
      find.descendant(of: find.byType(AppBar), matching: find.text(text));

  testWidgets('LinkedText makes only known names tappable and reports who was tapped', (tester) async {
    await setUpEnv();
    final bob = await alters.create(name: 'Bob');
    List<String>? tapped;
    await pumpScreen(
      tester,
      Scaffold(
        body: LinkedText(
          text: 'Bob walks with Nobody.',
          names: [NameRef(bob.id, bob.name)],
          onTap: (ids) => tapped = ids,
        ),
      ),
      providers: providers,
    );
    expect(find.byKey(const ValueKey('alter-link-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('alter-link-1')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('alter-link-0')));
    expect(tapped, [bob.id]);
  });

  testWidgets('reading an entry: tap a name to open that alter', (tester) async {
    await setUpEnv();
    final cat = await alters.create(name: 'Cat');
    await world.addEntry(title: 'Evening', text: 'Cat sits by the lake.');
    await pumpScreen(tester, WorldEntryScreen(existing: world.entries.single), providers: providers);
    await tester.tap(find.text('Read'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('alter-link-0')));
    await tester.pumpAndSettle();
    expect(inAppBar('Cat'), findsOneWidget);
    expect(alters.byId(cat.id), isNotNull);
  });

  testWidgets('while writing, a live "Mentioned" strip offers the alters named so far', (tester) async {
    await setUpEnv();
    final cat = await alters.create(name: 'Cat');
    await pumpScreen(tester, const WorldEntryScreen(), providers: providers);
    expect(find.byKey(Key('mention-${cat.id}')), findsNothing);
    await tester.enterText(find.byKey(const Key('world-text')), 'cat is by the lake');
    await tester.pumpAndSettle();
    expect(find.byKey(Key('mention-${cat.id}')), findsOneWidget);
    await tester.tap(find.byKey(Key('mention-${cat.id}')));
    await tester.pumpAndSettle();
    expect(inAppBar('Cat'), findsOneWidget);
  });

  testWidgets('two alters with the same name: ask which one, then open that one', (tester) async {
    await setUpEnv();
    final sam1 = await alters.create(name: 'Sam', pronouns: 'he/him');
    await alters.create(name: 'Sam', pronouns: 'she/her');
    await world.addEntry(text: 'Sam waves.');
    await pumpScreen(tester, WorldEntryScreen(existing: world.entries.single), providers: providers);
    await tester.tap(find.text('Read'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('alter-link-0')));
    await tester.pumpAndSettle();
    expect(find.text('Which one do you mean?'), findsOneWidget);
    await tester.tap(find.byKey(Key('pick-link-${sam1.id}')));
    await tester.pumpAndSettle();
    expect(find.text('he/him'), findsWidgets);
  });

  testWidgets('"Who lives here" lists mentioned alters, most mentioned first, and opens them', (tester) async {
    await setUpEnv();
    final bob = await alters.create(name: 'Bob');
    final cat = await alters.create(name: 'Cat');
    await alters.create(name: 'Dan'); // never mentioned
    await world.addEntry(text: 'Cat and Bob. Later, Cat again.');
    await pumpScreen(tester, const WorldScreen(), providers: providers);
    expect(find.text('Who lives here'), findsOneWidget);
    expect(find.byKey(Key('lives-${cat.id}')), findsOneWidget);
    expect(find.byKey(Key('lives-${bob.id}')), findsOneWidget);
    expect(find.textContaining('Dan'), findsNothing);
    expect(find.text('Cat · 2'), findsOneWidget);
    final catX = tester.getTopLeft(find.byKey(Key('lives-${cat.id}'))).dx;
    final bobX = tester.getTopLeft(find.byKey(Key('lives-${bob.id}'))).dx;
    expect(catX, lessThan(bobX));
    await tester.tap(find.byKey(Key('lives-${bob.id}')));
    await tester.pumpAndSettle();
    expect(inAppBar('Bob'), findsOneWidget);
  });

  testWidgets('no one mentioned means no "Who lives here"; a removed alter is no longer linked and nothing crashes', (tester) async {
    await setUpEnv();
    await pumpScreen(tester, const WorldScreen(), providers: providers);
    expect(find.text('Who lives here'), findsNothing);

    final gone = await alters.create(name: 'Gone');
    await world.addEntry(text: 'Gone was here');
    await alters.delete(gone.id);
    await tester.pumpAndSettle();
    expect(find.text('Who lives here'), findsNothing);
    await pumpScreen(tester, WorldEntryScreen(existing: world.entries.single), providers: providers);
    await tester.tap(find.text('Read'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('alter-link-0')), findsNothing);
    expect(find.textContaining('Gone was here', findRichText: true), findsOneWidget);
  });
}
