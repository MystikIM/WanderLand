import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plural_app/data/backup_service.dart';
import 'package:plural_app/data/doc_store.dart';

Uint8List zipOf(Map<String, List<int>> files) {
  final a = Archive();
  files.forEach((name, bytes) => a.addFile(ArchiveFile(name, bytes.length, bytes)));
  return Uint8List.fromList(ZipEncoder().encode(a));
}

void main() {
  late Directory docs;
  late MemoryDocStore store;
  late BackupService svc;

  setUp(() async {
    docs = await Directory.systemTemp.createTemp('backup_chat');
    store = MemoryDocStore();
    svc = BackupService(store, docs, clock: () => DateTime(2026, 10, 15, 9));
  });
  tearDown(() async => docs.delete(recursive: true));

  Future<Map<String, dynamic>> zipCollections(Uint8List zip) async {
    final f = ZipDecoder().decodeBytes(zip).files.firstWhere((x) => x.name == 'data.json');
    return (jsonDecode(utf8.decode(f.content as List<int>)) as Map<String, dynamic>)['collections']
        as Map<String, dynamic>;
  }

  test('a backup zip leaves all four chat collections out', () async {
    await store.put('alters', {'id': 'a1', 'name': 'A'});
    for (final c in ['chat_identity', 'friends', 'friend_messages', 'friend_outbox']) {
      await store.put(c, {'id': 'x', 'secretish': 'data'});
    }
    final cols = await zipCollections(await svc.createZip());
    expect(cols.keys, ['alters']);
  });

  test('restoring keeps this phone\'s friends, and ignores chat data carried inside the zip', () async {
    await store.put('alters', {'id': 'old', 'name': 'Old'});
    await store.put('friends', {'id': 'mine', 'theirUsername': 'real'});
    await store.put('chat_identity', {'id': 'me', 'username': 'me'});
    final incoming = zipOf({
      'data.json': utf8.encode(jsonEncode({
        'format': 1,
        'app': 'x',
        'collections': {
          'alters': [
            {'id': 'new1', 'name': 'New'}
          ],
          'friends': [
            {'id': 'planted', 'theirUsername': 'evil'}
          ],
          'chat_identity': [
            {'id': 'me', 'username': 'planted'}
          ],
        },
      })),
    });
    await svc.restoreZip(incoming);
    expect((await store.all('alters')).single['id'], 'new1');
    expect((await store.all('friends')).single['id'], 'mine');
    expect((await store.get('chat_identity', 'me'))!['username'], 'me');
  });
}
