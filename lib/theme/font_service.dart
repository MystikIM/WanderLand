import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import '../data/doc_store.dart';

class FontService {
  FontService(this._store, this._docsDir);
  static const collection = 'settings';
  final DocStore _store;
  final Directory _docsDir;

  Future<List<String>> savedFamilies() async {
    final d = await _store.get(collection, 'fonts');
    return List<String>.from(d?['files'] as List? ?? const [])
        .map((f) => 'custom:${p.basenameWithoutExtension(f)}')
        .toList();
  }

  Future<String> importFont(File src) async {
    final ext = p.extension(src.path).toLowerCase();
    if (ext != '.ttf' && ext != '.otf') {
      throw ArgumentError('Please choose a .ttf or .otf font file');
    }
    final fontsDir = Directory(p.join(_docsDir.path, 'fonts'));
    await fontsDir.create(recursive: true);
    final dest = File(p.join(fontsDir.path, p.basename(src.path)));
    await src.copy(dest.path);
    final family = await _register(dest);

    final d = await _store.get(collection, 'fonts');
    final files = List<String>.from(d?['files'] as List? ?? const []);
    if (!files.contains(p.basename(dest.path))) files.add(p.basename(dest.path));
    await _store.put(collection, {'id': 'fonts', 'files': files});
    return family;
  }

  Future<List<String>> loadSaved() async {
    final d = await _store.get(collection, 'fonts');
    final out = <String>[];
    for (final f in List<String>.from(d?['files'] as List? ?? const [])) {
      final file = File(p.join(_docsDir.path, 'fonts', f));
      if (await file.exists()) out.add(await _register(file));
    }
    return out;
  }

  Future<String> _register(File f) async {
    final family = 'custom:${p.basenameWithoutExtension(f.path)}';
    final bytes = await f.readAsBytes();
    final loader = FontLoader(family)
      ..addFont(Future.value(ByteData.sublistView(Uint8List.fromList(bytes))));
    await loader.load();
    return family;
  }
}
