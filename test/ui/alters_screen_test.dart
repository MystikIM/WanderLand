import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plural_app/controllers/alter_controller.dart';
import 'package:plural_app/controllers/settings_controller.dart';
import 'package:plural_app/data/doc_store.dart';
import 'package:plural_app/data/image_store.dart';
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
  return (
    [
      ChangeNotifierProvider.value(value: s),
      ChangeNotifierProvider.value(value: a),
      Provider.value(value: ImageStore(Directory.systemTemp)),
    ],
    a
  );
}

void main() {
  testWidgets('empty list invites the user to add the first one', (tester) async {
    final (p, _) = await setup();
    await pumpScreen(tester, const AltersScreen(), providers: p);
    expect(find.textContaining('Add your first'), findsOneWidget);
  });

  testWidgets('list shows alters; archived ones hide until toggled', (tester) async {
    final (p, a) = await setup();
    await a.create(name: 'Bob');
    final z = await a.create(name: 'Zed 🌙');
    await a.setArchived(z.id, true);
    await pumpScreen(tester, const AltersScreen(), providers: p);
    expect(find.text('Bob'), findsOneWidget);
    expect(find.text('Zed 🌙'), findsNothing);
    await tester.tap(find.byKey(const Key('show-archived')));
    await tester.pumpAndSettle();
    expect(find.text('Zed 🌙'), findsOneWidget);
  });

  testWidgets('edit form: a name is required, then it saves with a pronoun preset', (tester) async {
    final (p, a) = await setup();
    await pumpScreen(tester, const AlterEditScreen(), providers: p);
    await tester.tap(find.byKey(const Key('save-alter')));
    await tester.pumpAndSettle();
    expect(find.text('Please give them a name'), findsOneWidget);
    expect(a.all, isEmpty);

    await tester.enterText(find.byKey(const Key('alter-name')), 'Cat');
    await tester.tap(find.text('they/them'));
    await tester.enterText(find.byKey(const Key('alter-tags')), 'protector, kind');
    await tester.tap(find.byKey(const Key('save-alter')));
    await tester.pumpAndSettle();
    expect(a.all.single.name, 'Cat');
    expect(a.all.single.pronouns, 'they/them');
    expect(a.all.single.tags, ['protector', 'kind']);
  });

  testWidgets('free-text pronouns are kept', (tester) async {
    final (p, a) = await setup();
    await pumpScreen(tester, const AlterEditScreen(), providers: p);
    await tester.enterText(find.byKey(const Key('alter-name')), 'Moon');
    await tester.enterText(find.byKey(const Key('alter-pronouns')), 'moon/moons');
    await tester.tap(find.byKey(const Key('save-alter')));
    await tester.pumpAndSettle();
    expect(a.all.single.pronouns, 'moon/moons');
  });

  testWidgets('profile view shows name, pronouns and markdown bio', (tester) async {
    final (p, a) = await setup();
    final x = await a.create(name: 'Bob', pronouns: 'he/him');
    await a.save(x.copyWith(bio: 'Loves **tea**'));
    await pumpScreen(tester, AlterDetailScreen(alterId: x.id), providers: p);
    expect(find.text('Bob'), findsWidgets);
    expect(find.text('he/him'), findsOneWidget);
    expect(find.textContaining('tea'), findsOneWidget);
  });

  testWidgets('profile view of a removed alter does not crash', (tester) async {
    final (p, _) = await setup();
    await pumpScreen(tester, const AlterDetailScreen(alterId: 'gone'), providers: p);
    expect(find.text('Removed alter'), findsWidgets);
  });
}
