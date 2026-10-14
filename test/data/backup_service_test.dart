import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:plural_app/data/backup_service.dart';
import 'package:plural_app/data/doc_store.dart';

Uint8List zipOf(Map<String, List<int>> files) {
  final a = Archive();
  files.forEach((name, bytes) => a.addFile(ArchiveFile(name, bytes.length, bytes)));
  return Uint8List.fromList(ZipEncoder().encode(a));
}

List<int> dataJson({int format = 1, Object? collections, bool omitFormat = false}) => utf8.encode(jsonEncode({
      if (!omitFormat) 'format': format,
      'app': 'x',
      'collections': collections ??
          {
            'alters': [
              {'id': 'new1', 'name': 'New'}
            ],
          },
    }));

void main() {
  late Directory docs;
  late MemoryDocStore store;
  late BackupService svc;
  final now = DateTime(2026, 10, 14, 9, 5);

  setUp(() async {
    docs = await Directory.systemTemp.createTemp('backup_docs');
    store = MemoryDocStore();
    svc = BackupService(store, docs, clock: () => now);
  });
  tearDown(() async => docs.delete(recursive: true));

  Future<Directory> sandbox() => Directory.systemTemp.createTemp('backup_other');

  test('round trip: documents, pictures and fonts all come back', () async {
    await store.put('alters', {'id': 'a1', 'name': 'Bob 🌲'});
    await store.put('journal', {'id': 'j1', 'title': 'hi', 'body': 'x'});
    await Directory(p.join(docs.path, 'images')).create();
    await File(p.join(docs.path, 'images', 'bob.png')).writeAsBytes([1, 2, 3]);
    await Directory(p.join(docs.path, 'fonts')).create();
    await File(p.join(docs.path, 'fonts', 'My Font.ttf')).writeAsBytes([9, 9]);

    final bytes = await svc.createZip();

    final other = await sandbox();
    final store2 = MemoryDocStore();
    final result = await BackupService(store2, other).restoreZip(bytes);
    expect(result.docs, 2);
    expect(result.files, 2);
    expect((await store2.get('alters', 'a1'))!['name'], 'Bob 🌲');
    expect((await store2.get('journal', 'j1'))!['title'], 'hi');
    expect(await File(p.join(other.path, 'images', 'bob.png')).readAsBytes(), [1, 2, 3]);
    expect(await File(p.join(other.path, 'fonts', 'My Font.ttf')).readAsBytes(), [9, 9]);
    await other.delete(recursive: true);
  });

  test('the zip has data.json with format 1 and does not include old safety backups', () async {
    await store.put('alters', {'id': 'a1', 'name': 'A'});
    await Directory(p.join(docs.path, 'backups')).create();
    await File(p.join(docs.path, 'backups', 'old.zip')).writeAsBytes([5]);
    final archive = ZipDecoder().decodeBytes(await svc.createZip());
    final names = archive.files.map((f) => f.name).toList();
    expect(names, contains('data.json'));
    expect(names.any((n) => n.startsWith('backups')), isFalse);
    final data = jsonDecode(utf8.decode(archive.findFile('data.json')!.content as List<int>)) as Map;
    expect(data['format'], 1);
    expect(data['exportedAt'], now.toIso8601String());
  });

  test('an empty system backs up and restores fine', () async {
    final bytes = await svc.createZip();
    final r = await BackupService(MemoryDocStore(), await sandbox()).restoreZip(bytes);
    expect((r.docs, r.files), (0, 0));
  });

  test('restore replaces what was there, and saves a safety copy of it first', () async {
    await store.put('alters', {'id': 'old1', 'name': 'Old'});
    final result = await svc.restoreZip(zipOf({'data.json': dataJson()}));
    expect(result.docs, 1);
    expect(await store.get('alters', 'old1'), isNull);
    expect((await store.get('alters', 'new1'))!['name'], 'New');

    final safety = Directory(p.join(docs.path, 'backups'))
        .listSync()
        .whereType<File>()
        .where((f) => p.basename(f.path).startsWith('before-restore-'))
        .toList();
    expect(safety.length, 1);
    final saved = ZipDecoder().decodeBytes(await safety.single.readAsBytes());
    final data = jsonDecode(utf8.decode(saved.findFile('data.json')!.content as List<int>)) as Map;
    expect((data['collections'] as Map)['alters'][0]['name'], 'Old');
  });

  test('old pictures are cleared and replaced by the backup\'s pictures', () async {
    await Directory(p.join(docs.path, 'images')).create();
    await File(p.join(docs.path, 'images', 'stale.png')).writeAsBytes([1]);
    await svc.restoreZip(zipOf({'data.json': dataJson(), 'images/fresh.png': [7]}));
    expect(File(p.join(docs.path, 'images', 'stale.png')).existsSync(), isFalse);
    expect(await File(p.join(docs.path, 'images', 'fresh.png')).readAsBytes(), [7]);
  });

  Future<void> expectRefused(Uint8List bytes, {String? messageContains}) async {
    await store.put('alters', {'id': 'keep', 'name': 'Keep me'});
    await expectLater(
      svc.restoreZip(bytes),
      throwsA(isA<BackupException>().having((e) => e.message, 'message', contains(messageContains ?? ''))),
    );
    expect((await store.get('alters', 'keep'))!['name'], 'Keep me'); // nothing was touched
    expect(Directory(p.join(docs.path, 'backups')).existsSync(), isFalse); // not even a safety copy
  }

  test('random bytes are refused without touching anything', () async {
    await expectRefused(Uint8List.fromList([1, 2, 3, 4, 5]), messageContains: 'does not look like');
  });

  test('a zip with no data.json is refused', () async {
    await expectRefused(zipOf({'hello.txt': [104, 105]}), messageContains: 'does not look like');
  });

  test('broken or wrongly shaped data.json is refused', () async {
    await expectRefused(zipOf({'data.json': utf8.encode('not json')}));
    await expectRefused(zipOf({'data.json': dataJson(omitFormat: true)}));
    await expectRefused(zipOf({'data.json': dataJson(collections: 'oops')}));
    await expectRefused(zipOf({
      'data.json': dataJson(collections: {
        'alters': [
          {'name': 'no id here'}
        ]
      })
    }));
  });

  test('a backup from a newer version of the app is refused with a clear message', () async {
    await expectRefused(zipOf({'data.json': dataJson(format: 2)}), messageContains: 'newer version');
  });

  test('zip-slip: paths that climb out of the app folder refuse the whole file', () async {
    final outside = File(p.join(docs.parent.path, 'evil.txt'));
    for (final bad in ['../evil.txt', 'images/../../evil.txt', r'images\..\..\evil.txt', '/etc/evil', 'C:/evil.txt']) {
      await expectRefused(zipOf({'data.json': dataJson(), bad: [1]}), messageContains: 'unsafe');
    }
    expect(outside.existsSync(), isFalse);
  });

  test('files outside images/ and fonts/ are ignored, not written', () async {
    await svc.restoreZip(zipOf({'data.json': dataJson(), 'other/stuff.txt': [1], 'notes.txt': [2]}));
    expect(File(p.join(docs.path, 'other', 'stuff.txt')).existsSync(), isFalse);
    expect(File(p.join(docs.path, 'notes.txt')).existsSync(), isFalse);
  });

  test('exportToFile writes a dated zip that can be restored', () async {
    await store.put('alters', {'id': 'a1', 'name': 'A'});
    final dir = await sandbox();
    final f = await svc.exportToFile(dir);
    expect(p.basename(f.path), 'wanderland-backup-20261014-0905.zip');
    final r = await BackupService(MemoryDocStore(), await sandbox()).restoreZip(await f.readAsBytes());
    expect(r.docs, 1);
    await dir.delete(recursive: true);
  });
}
