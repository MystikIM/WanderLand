import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plural_app/controllers/settings_controller.dart';
import 'package:plural_app/data/doc_store.dart';
import 'package:plural_app/ui/appearance_screen.dart';
import 'package:provider/provider.dart';
import '../helpers/harness.dart';

void main() {
  testWidgets('Appearance lets the person pick how the app follows whoever is out', (tester) async {
    final s = SettingsController(MemoryDocStore());
    await s.load();
    await pumpScreen(tester, AppearanceScreen(onImportFont: () async {}),
        providers: [ChangeNotifierProvider.value(value: s)]);
    expect(s.theme.alterLook, 'accent');
    await tester.ensureVisible(find.byKey(const Key('alter-look')));
    await tester.tap(find.text('Whole app'));
    await tester.pumpAndSettle();
    expect(s.theme.alterLook, 'full');
    await tester.tap(find.text('Off'));
    await tester.pumpAndSettle();
    expect(s.theme.alterLook, 'off');
  });
}
