import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plural_app/controllers/alter_controller.dart';
import 'package:plural_app/controllers/front_controller.dart';
import 'package:plural_app/controllers/settings_controller.dart';
import 'package:plural_app/data/doc_store.dart';
import 'package:plural_app/data/image_store.dart';
import 'package:plural_app/theme/terminology.dart';
import 'package:plural_app/ui/home_shell.dart';
import 'package:provider/provider.dart';
import '../helpers/harness.dart';

void main() {
  testWidgets('bottom bar has the six tabs in the right order and More opens Appearance', (tester) async {
    final store = MemoryDocStore();
    final s = SettingsController(store);
    await s.load();
    final a = AlterController(store);
    await a.load();
    final f = FrontController(store);
    await f.load();
    await pumpScreen(tester, const HomeShell(), providers: [
      ChangeNotifierProvider.value(value: s),
      ChangeNotifierProvider.value(value: a),
      ChangeNotifierProvider.value(value: f),
      Provider.value(value: ImageStore(Directory.systemTemp)),
      Provider<DocStore>.value(value: store),
      Provider<Directory>.value(value: Directory.systemTemp),
    ]);

    final labels = tester
        .widgetList<NavigationDestination>(find.byType(NavigationDestination))
        .map((d) => d.label)
        .toList();
    expect(labels, ['Front', 'Activity', 'Alters', 'Inner World', 'Chat', 'More']);

    await tester.tap(find.text('More'));
    await tester.pumpAndSettle();
    expect(find.text('Appearance'), findsOneWidget);
    expect(find.text('About'), findsOneWidget);
  });

  testWidgets('the Alters tab label follows the user\'s own word', (tester) async {
    final store = MemoryDocStore();
    final s = SettingsController(store);
    await s.load();
    final a = AlterController(store);
    await a.load();
    final f = FrontController(store);
    await f.load();
    await s.setTerminology(Terminology(const {'alters': 'headmates'}));
    await pumpScreen(tester, const HomeShell(), providers: [
      ChangeNotifierProvider.value(value: s),
      ChangeNotifierProvider.value(value: a),
      ChangeNotifierProvider.value(value: f),
      Provider.value(value: ImageStore(Directory.systemTemp)),
      Provider<DocStore>.value(value: store),
      Provider<Directory>.value(value: Directory.systemTemp),
    ]);
    expect(find.text('Headmates'), findsWidgets);
  });
}
