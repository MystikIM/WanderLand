import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plural_app/controllers/alter_controller.dart';
import 'package:plural_app/controllers/front_controller.dart';
import 'package:plural_app/controllers/settings_controller.dart';
import 'package:plural_app/data/doc_store.dart';
import 'package:plural_app/data/image_store.dart';
import 'package:plural_app/domain/pronouns.dart';
import 'package:plural_app/ui/alter_edit_screen.dart';
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

Future<void> tapChip(WidgetTester tester, String p) async {
  final chip = find.byKey(Key('pronoun-$p'));
  await tester.ensureVisible(chip);
  await tester.tap(chip);
  await tester.pumpAndSettle();
}

ChoiceChip chipOf(WidgetTester tester, String p) =>
    tester.widget<ChoiceChip>(find.byKey(Key('pronoun-$p')));

void main() {
  testWidgets('pronoun chips are multi-select: several stay lit at once and fill the box', (tester) async {
    final (p, a) = await setup();
    final bob = await a.create(name: 'Bob');
    await pumpScreen(tester, AlterEditScreen(existing: bob), providers: p);
    await tapChip(tester, 'she/her');
    await tapChip(tester, 'they/them');
    expect(chipOf(tester, 'she/her').selected, isTrue);
    expect(chipOf(tester, 'they/them').selected, isTrue);
    expect(chipOf(tester, 'he/him').selected, isFalse);
    final box = tester.widget<TextField>(find.byKey(const Key('alter-pronouns')));
    expect(box.controller!.text, 'she/her, they/them');
  });

  testWidgets('tapping a lit chip again turns just that one off', (tester) async {
    final (p, a) = await setup();
    final bob = await a.create(name: 'Bob');
    await pumpScreen(tester, AlterEditScreen(existing: bob), providers: p);
    await tapChip(tester, 'she/her');
    await tapChip(tester, 'they/them');
    await tapChip(tester, 'she/her');
    expect(chipOf(tester, 'she/her').selected, isFalse);
    expect(chipOf(tester, 'they/them').selected, isTrue);
  });

  testWidgets('all of them can be picked, there is no limit, and it all saves', (tester) async {
    final (p, a) = await setup();
    final bob = await a.create(name: 'Bob');
    await pumpScreen(tester, AlterEditScreen(existing: bob), providers: p);
    for (final preset in kPronounPresets) {
      await tapChip(tester, preset);
    }
    await tester.ensureVisible(find.byKey(const Key('save-alter')));
    await tester.tap(find.byKey(const Key('save-alter')));
    await tester.pumpAndSettle();
    expect(splitPronouns(a.byId(bob.id)!.pronouns), kPronounPresets);
  });

  testWidgets('an alter who already has two pronouns opens with both lit, and typing your own still works', (tester) async {
    final (p, a) = await setup();
    final bob = await a.create(name: 'Bob', pronouns: 'he/him, they/them, moon/moons');
    await pumpScreen(tester, AlterEditScreen(existing: bob), providers: p);
    expect(chipOf(tester, 'he/him').selected, isTrue);
    expect(chipOf(tester, 'they/them').selected, isTrue);
    expect(chipOf(tester, 'she/her').selected, isFalse);
    await tester.enterText(find.byKey(const Key('alter-pronouns')), 'he/him, star/stars');
    await tester.pumpAndSettle();
    expect(chipOf(tester, 'he/him').selected, isTrue);
    expect(chipOf(tester, 'they/them').selected, isFalse);
    await tapChip(tester, 'she/her');
    final box = tester.widget<TextField>(find.byKey(const Key('alter-pronouns')));
    expect(box.controller!.text, 'he/him, star/stars, she/her');
  });
}
