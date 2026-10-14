import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'app.dart';
import 'controllers/settings_controller.dart';
import 'data/sqlite_doc_store.dart';
import 'theme/font_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final dir = await getApplicationDocumentsDirectory();
  final store = await SqliteDocStore.open(p.join(dir.path, 'system.db'));
  final settings = SettingsController(store);
  await settings.load();
  await FontService(store, dir).loadSaved();
  runApp(PluralApp(store: store, docsDir: dir, settings: settings));
}
