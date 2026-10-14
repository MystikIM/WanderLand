import 'dart:io';
import 'package:path/path.dart' as p;
import '../domain/ids.dart';

class ImageStore {
  ImageStore(this._docsDir);
  final Directory _docsDir;

  Future<String> save(File picked) async {
    final dir = Directory(p.join(_docsDir.path, 'images'));
    await dir.create(recursive: true);
    final rel = 'images/${IdGen.next(DateTime.now())}${p.extension(picked.path).toLowerCase()}';
    await picked.copy(p.join(_docsDir.path, rel));
    return rel;
  }

  File resolve(String relative) => File(p.join(_docsDir.path, relative));

  Future<void> remove(String relative) async {
    final f = resolve(relative);
    if (await f.exists()) await f.delete();
  }
}
