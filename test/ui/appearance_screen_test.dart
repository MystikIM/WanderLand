import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plural_app/controllers/settings_controller.dart';
import 'package:plural_app/data/doc_store.dart';
import 'package:plural_app/ui/appearance_screen.dart';
import 'package:provider/provider.dart';
import '../helpers/harness.dart';

void main() {
  testWidgets('choosing a font and a word updates and saves settings', (tester) async {
    final store = MemoryDocStore();
    final s = SettingsController(store);
    await s.load();
    await pumpScreen(
      tester,
      AppearanceScreen(onImportFont: () async {}),
      providers: [ChangeNotifierProvider.value(value: s)],
    );

    await tester.ensureVisible(find.text('Pacifico'));
    await tester.tap(find.text('Pacifico'));
    await tester.pumpAndSettle();
    expect(s.theme.fontFamily, 'Pacifico');

    final alterField = find.byKey(const Key('word-alter'));
    await tester.ensureVisible(alterField);
    await tester.enterText(alterField, 'headmate');
    await tester.tap(find.byKey(const Key('save-words')));
    await tester.pumpAndSettle();
    expect(s.terminology('alter'), 'headmate');

    final reloaded = SettingsController(store);
    await reloaded.load();
    expect(reloaded.theme.fontFamily, 'Pacifico');
    expect(reloaded.terminology('alter'), 'headmate');
  });
}
