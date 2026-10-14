import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plural_app/controllers/alter_controller.dart';
import 'package:plural_app/controllers/world_controller.dart';
import 'package:plural_app/data/doc_store.dart';
import 'package:plural_app/data/image_store.dart';
import 'package:plural_app/domain/world.dart';
import 'package:plural_app/ui/scene_painters.dart';
import 'package:plural_app/ui/world_screen.dart';
import 'package:provider/provider.dart';
import '../helpers/harness.dart';

void main() {
  Future<WorldController> make() async {
    final w = WorldController(MemoryDocStore(), clock: () => DateTime(2026, 10, 14, 9));
    await w.load();
    return w;
  }

  Future<void> open(WidgetTester tester, WorldController w) async {
    final alters = AlterController(MemoryDocStore());
    await alters.load();
    await pumpScreen(
      tester,
      const WorldScreen(),
      providers: [
        ChangeNotifierProvider.value(value: w),
        ChangeNotifierProvider.value(value: alters),
        Provider.value(value: ImageStore(Directory.systemTemp)),
      ],
    );
  }

  testWidgets('a fresh inner world shows an empty scene and a gentle invitation', (tester) async {
    final w = await make();
    await open(tester, w);
    expect(find.byKey(const Key('scene')), findsOneWidget);
    expect(find.textContaining('Write about your inner world'), findsOneWidget);
  });

  testWidgets('writing about a tree and a lake grows both, and says so; "I don\'t have a house" adds none', (tester) async {
    final w = await make();
    await open(tester, w);
    await tester.tap(find.byKey(const Key('world-write')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('world-title')), 'Home');
    await tester.enterText(find.byKey(const Key('world-text')),
        'There is a big tree by a lake. I don’t have a house.');
    await tester.tap(find.byKey(const Key('world-save')));
    await tester.pumpAndSettle();

    expect(w.items.map((i) => i.kind).toSet(), {'tree', 'lake'});
    expect(find.byKey(ValueKey('piece-${w.items.firstWhere((i) => i.kind == 'tree').id}')), findsOneWidget);
    expect(find.textContaining('Your world grew'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
  });

  testWidgets('an entry that adds nothing still saves and shows no "grew" message', (tester) async {
    final w = await make();
    await open(tester, w);
    await tester.tap(find.byKey(const Key('world-write')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('world-text')), 'It is quiet and soft.');
    await tester.tap(find.byKey(const Key('world-save')));
    await tester.pumpAndSettle();
    expect(w.entries.length, 1);
    expect(w.items, isEmpty);
    expect(find.textContaining('Your world grew'), findsNothing);
  });

  testWidgets('a blank entry is refused kindly', (tester) async {
    final w = await make();
    await open(tester, w);
    await tester.tap(find.byKey(const Key('world-write')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('world-save')));
    await tester.pumpAndSettle();
    expect(find.text('Write a title or something about your world first'), findsOneWidget);
    expect(w.entries, isEmpty);
  });

  testWidgets('long-press a piece: remove it, and it stays gone', (tester) async {
    final w = await make();
    await w.addEntry(text: 'a tree');
    await open(tester, w);
    final id = w.items.single.id;
    await tester.longPress(find.byKey(ValueKey('piece-$id')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('piece-remove')));
    await tester.pumpAndSettle();
    expect(w.items, isEmpty);
    await w.addEntry(text: 'more trees');
    await tester.pumpAndSettle();
    expect(w.items, isEmpty);
  });

  testWidgets('add a piece by hand from the menu', (tester) async {
    final w = await make();
    await open(tester, w);
    await tester.tap(find.byKey(const Key('add-piece')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('add-moon')));
    await tester.pumpAndSettle();
    expect(w.items.single.kind, 'moon');
    expect(w.items.single.userEdited, isTrue);
  });

  testWidgets('dragging a piece moves it and keeps it where the person put it', (tester) async {
    final w = await make();
    await w.addEntry(text: 'a tree');
    await open(tester, w);
    final before = w.items.single.x;
    final g = await tester.startGesture(tester.getCenter(find.byKey(ValueKey('piece-${w.items.single.id}'))));
    for (var k = 0; k < 6; k++) {
      await g.moveBy(const Offset(25, 0));
      await tester.pump();
    }
    await g.up();
    await tester.pumpAndSettle();
    expect(w.items.single.x, greaterThan(before + 0.05));
    expect(w.items.single.userEdited, isTrue);
  });

  testWidgets('resizing and recoloring from the piece sheet', (tester) async {
    final w = await make();
    await w.addEntry(text: 'a tree');
    await open(tester, w);
    await tester.longPress(find.byKey(ValueKey('piece-${w.items.single.id}')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('piece-color-0xFFE40303')));
    await tester.pumpAndSettle();
    expect(w.items.single.colorValue, 0xFFE40303);
    await tester.tap(find.byKey(const Key('piece-color-original')));
    await tester.pumpAndSettle();
    expect(w.items.single.colorValue, isNull);
  });

  testWidgets('every kind of piece draws, with and without a custom color', (tester) async {
    for (final kind in kLexicon.keys) {
      for (final tint in <Color?>[null, Colors.purple]) {
        await tester.pumpWidget(MaterialApp(
          home: Scaffold(body: CustomPaint(size: const Size(100, 100), painter: PiecePainter(kind, tint))),
        ));
      }
    }
    expect(tester.takeException(), isNull);
  });
}
