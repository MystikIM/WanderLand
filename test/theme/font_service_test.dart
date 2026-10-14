import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:plural_app/data/doc_store.dart';
import 'package:plural_app/theme/font_service.dart';

void main() {
  testWidgets('imports a user font, remembers it, and reloads it', (tester) async {
    await tester.runAsync(() async {
      final docs = await Directory.systemTemp.createTemp('fonts_test');
      final store = MemoryDocStore();
      final src = File('assets/fonts/Pacifico-Regular.ttf');
      expect(src.existsSync(), isTrue, reason: 'Task 5 Step 1 must download the fonts first');

      final svc = FontService(store, docs);
      final family = await svc.importFont(src);
      expect(family, 'custom:Pacifico-Regular');
      expect(await svc.savedFamilies(), [family]);

      final again = FontService(store, docs);
      expect(await again.loadSaved(), [family]);
      await docs.delete(recursive: true);
    });
  });

  testWidgets('rejects non-font files', (tester) async {
    await tester.runAsync(() async {
      final docs = await Directory.systemTemp.createTemp('fonts_test2');
      final bad = File('${docs.path}/notes.txt')..writeAsStringSync('hi');
      final svc = FontService(MemoryDocStore(), docs);
      expect(() => svc.importFont(bad), throwsArgumentError);
      await docs.delete(recursive: true);
    });
  });
}
