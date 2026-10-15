import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plural_app/controllers/alter_controller.dart';
import 'package:plural_app/controllers/buddy_controller.dart';
import 'package:plural_app/controllers/front_controller.dart';
import 'package:plural_app/controllers/settings_controller.dart';
import 'package:plural_app/data/doc_store.dart';
import 'package:plural_app/data/image_store.dart';
import 'package:plural_app/ui/home_shell.dart';
import 'package:provider/provider.dart';

const _fonts = {
  'Atkinson Hyperlegible': 'assets/fonts/AtkinsonHyperlegible-Regular.ttf',
  'Space Mono': 'assets/fonts/SpaceMono-Regular.ttf',
  'Pacifico': 'assets/fonts/Pacifico-Regular.ttf',
  'Indie Flower': 'assets/fonts/IndieFlower-Regular.ttf',
  'Special Elite': 'assets/fonts/SpecialElite-Regular.ttf',
};

void main() {
  for (final e in _fonts.entries) {
    testWidgets('every bottom tab label stays on one line at 360dp wide in ${e.key}', (tester) async {
      await (FontLoader(e.key)..addFont(Future.value(ByteData.sublistView(File(e.value).readAsBytesSync())))).load();

      final store = MemoryDocStore();
      final s = SettingsController(store);
      await s.load();
      final a = AlterController(store);
      await a.load();
      final f = FrontController(store);
      await f.load();
      final b = BuddyController(store);
      await b.load();

      // A real phone's width (the Revvl 7 Pro is 360 dp), not the tall test surface.
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: s),
          ChangeNotifierProvider.value(value: a),
          ChangeNotifierProvider.value(value: f),
          ChangeNotifierProvider.value(value: b),
          Provider.value(value: ImageStore(Directory.systemTemp)),
          Provider<DocStore>.value(value: store),
          Provider<Directory>.value(value: Directory.systemTemp),
        ],
        child: MaterialApp(
          theme: ThemeData(fontFamily: e.key),
          home: const HomeShell(),
        ),
      ));
      await tester.pumpAndSettle();

      double heightOf(String label) => tester
          .getSize(find.descendant(of: find.byType(NavigationBar), matching: find.text(label)))
          .height;
      final labels = ['Front', 'Activity', 'Alters', 'Inner World', 'Chat', 'More'];
      final oneLine = heightOf('Chat');
      for (final l in labels) {
        expect(heightOf(l), moreOrLessEquals(oneLine, epsilon: 1.0), reason: '"$l" wrapped in ${e.key}');
      }
    });
  }
}
