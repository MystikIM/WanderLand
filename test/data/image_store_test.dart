import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:plural_app/data/image_store.dart';

void main() {
  test('copies a picked image into the app folder and can remove it', () async {
    final docs = await Directory.systemTemp.createTemp('img_docs');
    final src = File('${docs.path}/picked.PNG')..writeAsBytesSync([1, 2, 3]);
    final store = ImageStore(docs);
    final rel = await store.save(src);
    expect(rel.startsWith('images/'), isTrue);
    expect(rel.toLowerCase().endsWith('.png'), isTrue);
    expect(store.resolve(rel).readAsBytesSync(), [1, 2, 3]);
    await store.remove(rel);
    expect(store.resolve(rel).existsSync(), isFalse);
    await store.remove(rel); // removing twice is fine
    await docs.delete(recursive: true);
  });
}
