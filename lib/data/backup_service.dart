import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import '../app_info.dart';
import '../domain/ids.dart';
import 'doc_store.dart';
import '../friends/friend_models.dart';

typedef ReloadAll = Future<void> Function();

class BackupException implements Exception {
  BackupException(this.message);
  final String message;
  @override
  String toString() => message;
}

class RestoreResult {
  const RestoreResult({required this.docs, required this.files});
  final int docs;
  final int files;
}

abstract class BackupApi {
  Future<File> exportToFile(Directory dir);
  Future<RestoreResult> restoreZip(Uint8List bytes);
}

class BackupService implements BackupApi {
  BackupService(this._store, this._docs, {Clock? clock}) : _clock = clock ?? DateTime.now;

  static const format = 1;
  static const _folders = ['images', 'fonts'];
  static const _notABackup = 'That does not look like a $appName backup file.';

  final DocStore _store;
  final Directory _docs;
  final Clock _clock;

  Future<Uint8List> createZip() async {
    final archive = Archive();
    final json = utf8.encode(jsonEncode({
      'format': format,
      'app': appName,
      'exportedAt': _clock().toIso8601String(),
      'collections': (await _store.exportAll())
        ..removeWhere((name, _) => kPrivateCollections.contains(name)),
    }));
    archive.addFile(ArchiveFile('data.json', json.length, json));
    for (final folder in _folders) {
      final dir = Directory(p.join(_docs.path, folder));
      if (!await dir.exists()) continue;
      await for (final e in dir.list(recursive: true, followLinks: false)) {
        if (e is! File) continue;
        final rel = p.relative(e.path, from: _docs.path).replaceAll(r'\', '/');
        final bytes = await e.readAsBytes();
        archive.addFile(ArchiveFile(rel, bytes.length, bytes));
      }
    }
    return Uint8List.fromList(ZipEncoder().encode(archive));
  }

  @override
  Future<File> exportToFile(Directory dir) async {
    final t = _clock();
    String two(int n) => n.toString().padLeft(2, '0');
    final name = 'wanderland-backup-${t.year}${two(t.month)}${two(t.day)}-${two(t.hour)}${two(t.minute)}.zip';
    final f = File(p.join(dir.path, name));
    await f.writeAsBytes(await createZip());
    return f;
  }

  static bool _safePath(String name) {
    if (name.isEmpty) return false;
    final n = name.replaceAll(r'\', '/');
    if (n.startsWith('/') || RegExp(r'^[A-Za-z]:').hasMatch(n)) return false;
    return !n.split('/').contains('..');
  }

  @override
  Future<RestoreResult> restoreZip(Uint8List bytes) async {
    // 1. Check everything BEFORE touching anything.
    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes);
    } catch (_) {
      throw BackupException(_notABackup);
    }
    for (final f in archive.files) {
      if (!_safePath(f.name)) {
        throw BackupException('This file contains an unsafe path, so nothing was restored.');
      }
    }
    final dataFile = archive.files.where((f) => f.isFile && f.name == 'data.json').firstOrNull;
    if (dataFile == null) throw BackupException(_notABackup);

    final Map<String, dynamic> collections;
    try {
      final data = jsonDecode(utf8.decode(dataFile.content as List<int>)) as Map<String, dynamic>;
      final fmt = data['format'];
      if (fmt is! int || fmt < 1) throw const FormatException();
      if (fmt > format) {
        throw BackupException(
            'This backup was made by a newer version of $appName. Please update the app first.');
      }
      collections = Map<String, dynamic>.from(data['collections'] as Map);
      for (final list in collections.values) {
        for (final d in (list as List)) {
          final id = (d as Map)['id'];
          if (id is! String || id.isEmpty) throw const FormatException();
        }
      }
    } on BackupException {
      rethrow;
    } catch (_) {
      throw BackupException(_notABackup);
    }

    // Chat data is private to one phone: never taken from a zip, never wiped by one.
    collections.removeWhere((name, _) => kPrivateCollections.contains(name));
    final keepChat = {
      for (final c in kPrivateCollections) c: await _store.all(c),
    };

    // 2. Save a safety copy of what is there now.
    final backups = Directory(p.join(_docs.path, 'backups'));
    await backups.create(recursive: true);
    final t = _clock();
    await File(p.join(backups.path, 'before-restore-${t.microsecondsSinceEpoch}.zip'))
        .writeAsBytes(await createZip());

    // 3. Replace.
    await restoreDocs(_store, collections);
    for (final e in keepChat.entries) {
      for (final d in e.value) {
        await _store.put(e.key, d);
      }
    }
    for (final folder in _folders) {
      final dir = Directory(p.join(_docs.path, folder));
      if (await dir.exists()) await dir.delete(recursive: true);
    }
    var files = 0;
    for (final f in archive.files) {
      if (!f.isFile) continue;
      final n = f.name.replaceAll(r'\', '/');
      if (!(n.startsWith('images/') || n.startsWith('fonts/'))) continue;
      final out = File(p.join(_docs.path, n));
      await out.parent.create(recursive: true);
      await out.writeAsBytes(f.content as List<int>);
      files++;
    }
    final docs = collections.values.fold<int>(0, (sum, l) => sum + (l as List).length);
    return RestoreResult(docs: docs, files: files);
  }
}
