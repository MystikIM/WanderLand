import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plural_app/data/backup_service.dart';
import 'package:plural_app/data/doc_store.dart';

/// A store that must never be emptied in one go, and can be made to fail halfway.
class _CarefulStore extends MemoryDocStore {
  bool failOnAltersPut = false;
  bool allowClear = false;
  @override
  Future<void> clear() async {
    if (!allowClear) throw StateError('restore must not wipe the whole store');
    return super.clear();
  }
  @override
  Future<void> put(String collection, Map<String, dynamic> doc) async {
    if (failOnAltersPut && collection == 'alters') throw StateError('disk full');
    return super.put(collection, doc);
  }
}

Uint8List zipOfAlters(List<Map<String, Object>> alters) {
  final data = utf8.encode(jsonEncode({
    'format': 1,
    'app': 'x',
    'collections': {'alters': alters},
  }));
  final a = Archive()..addFile(ArchiveFile('data.json', data.length, data));
  return Uint8List.fromList(ZipEncoder().encode(a));
}

void main() {
  late Directory docs;
  late _CarefulStore store;
  late BackupService svc;

  setUp(() async {
    docs = await Directory.systemTemp.createTemp('backup_safety');
    store = _CarefulStore();
    svc = BackupService(store, docs, clock: () => DateTime(2026, 10, 15, 9));
    await store.put('alters', {'id': 'old', 'name': 'Old'});
    await store.put('friends', {'id': 'f1', 'theirUsername': 'real'});
    await store.put('friend_messages', {'id': 'm1', 'text': 'kept'});
    await store.put('friend_outbox', {'id': 'o1', 'n': 1});
    await store.put('chat_identity', {'id': 'me', 'username': 'me'});
  });
  tearDown(() async => docs.delete(recursive: true));

  test('I3: a restore replaces everything except chat without ever emptying the whole store', () async {
    await svc.restoreZip(zipOfAlters([
      {'id': 'new1', 'name': 'New'}
    ]));
    expect((await store.all('alters')).map((d) => d['id']), ['new1']);
    expect((await store.all('friends')).single['id'], 'f1');
    expect((await store.all('friend_messages')).single['id'], 'm1');
    expect((await store.all('friend_outbox')).single['id'], 'o1');
    expect((await store.get('chat_identity', 'me'))!['username'], 'me');
  });

  test('I3: if the restore fails halfway, chat data is still there', () async {
    store.failOnAltersPut = true;
    store.allowClear = true; // an old-style restore would wipe first, then fail: chat must still survive
    await expectLater(
      svc.restoreZip(zipOfAlters([
        {'id': 'new1', 'name': 'New'}
      ])),
      throwsA(isA<StateError>()),
    );
    expect((await store.all('friends')).single['id'], 'f1');
    expect((await store.all('friend_messages')).single['id'], 'm1');
    expect((await store.get('chat_identity', 'me'))!['username'], 'me');
  });
}
