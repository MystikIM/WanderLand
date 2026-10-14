import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plural_app/controllers/alter_controller.dart';
import 'package:plural_app/controllers/settings_controller.dart';
import 'package:plural_app/data/doc_store.dart';
import 'package:plural_app/data/image_store.dart';
import 'package:plural_app/ui/alter_detail_screen.dart';
import 'package:plural_app/ui/alter_edit_screen.dart';
import 'package:provider/provider.dart';
import '../helpers/harness.dart';

void main() {
  late AlterController a;

  testWidgets('age and little mode save from the editor', (tester) async {
    final store = MemoryDocStore();
    final s = SettingsController(store);
    await s.load();
    a = AlterController(store);
    await a.load();
    await pumpScreen(tester, const AlterEditScreen(), providers: [
      ChangeNotifierProvider.value(value: s),
      ChangeNotifierProvider.value(value: a),
      Provider.value(value: ImageStore(Directory.systemTemp)),
    ]);
    await tester.enterText(find.byKey(const Key('alter-name')), 'Pip');
    await tester.enterText(find.byKey(const Key('alter-age')), '7');
    await tester.ensureVisible(find.byKey(const Key('save-alter')));
    await tester.tap(find.byKey(const Key('save-alter')));
    await tester.pumpAndSettle();
    expect(a.all.single.ageYears, 7);
    expect(a.all.single.littleMode, 'auto');
  });

  testWidgets('a non-number age is refused with a kind message', (tester) async {
    final store = MemoryDocStore();
    final s = SettingsController(store);
    await s.load();
    a = AlterController(store);
    await a.load();
    await pumpScreen(tester, const AlterEditScreen(), providers: [
      ChangeNotifierProvider.value(value: s),
      ChangeNotifierProvider.value(value: a),
      Provider.value(value: ImageStore(Directory.systemTemp)),
    ]);
    await tester.enterText(find.byKey(const Key('alter-name')), 'Pip');
    await tester.enterText(find.byKey(const Key('alter-age')), 'abc');
    await tester.ensureVisible(find.byKey(const Key('save-alter')));
    await tester.tap(find.byKey(const Key('save-alter')));
    await tester.pumpAndSettle();
    expect(find.text('Please use a number'), findsOneWidget);
    expect(a.all, isEmpty);
  });

  testWidgets('profile shows a gentle little label', (tester) async {
    final store = MemoryDocStore();
    final s = SettingsController(store);
    await s.load();
    a = AlterController(store);
    await a.load();
    final x = await a.create(name: 'Pip');
    await a.save(x.copyWith(ageYears: 6));
    await pumpScreen(tester, AlterDetailScreen(alterId: x.id), providers: [
      ChangeNotifierProvider.value(value: s),
      ChangeNotifierProvider.value(value: a),
      Provider.value(value: ImageStore(Directory.systemTemp)),
    ]);
    expect(find.text('little · age 6'), findsOneWidget);
  });
}
