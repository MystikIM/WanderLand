import 'dart:io';
import 'dart:typed_data';

typedef Now = DateTime Function();

/// A mailbox id is 16 to 43 URL-safe characters. Nothing else is ever used as a folder name.
final RegExp mailboxPattern = RegExp(r'^[A-Za-z0-9_-]{16,43}$');
final RegExp _idPattern = RegExp(r'^\d{16}-\d{6}$');

enum PutResult { ok, tooBig, full }

class MailItem {
  const MailItem(this.mailbox, this.id, this.bytes);
  final String mailbox;
  final String id;
  final Uint8List bytes;
}

/// One folder per mailbox, one file per message. Opaque bytes in, the same bytes out.
class MailStore {
  MailStore(
    this.dir, {
    this.maxFrameBytes = 32 * 1024,
    this.maxPerMailbox = 200,
    this.maxMailboxes = 5000,
    this.ttl = const Duration(days: 7),
    Now? now,
  }) : _now = now ?? DateTime.now;

  final Directory dir;
  final int maxFrameBytes;
  final int maxPerMailbox;
  final int maxMailboxes;
  final Duration ttl;
  final Now _now;
  int _seq = 0;

  static final String _sep = Platform.pathSeparator;

  Directory _box(String mailbox) {
    if (!mailboxPattern.hasMatch(mailbox)) throw ArgumentError('bad mailbox');
    return Directory('${dir.path}$_sep$mailbox');
  }

  Future<List<File>> _files(Directory box, {String ext = '.msg'}) async {
    if (!await box.exists()) return [];
    final out = <File>[];
    await for (final e in box.list()) {
      if (e is File && e.path.endsWith(ext)) out.add(e);
    }
    out.sort((a, b) => a.path.compareTo(b.path));
    return out;
  }

  static String _idOf(File f) {
    final name = f.uri.pathSegments.last;
    return name.substring(0, name.lastIndexOf('.'));
  }

  Future<int> _mailboxCount() async {
    var n = 0;
    await for (final e in dir.list()) {
      if (e is Directory) n++;
    }
    return n;
  }

  Future<PutResult> put(String mailbox, List<int> bytes) async {
    final box = _box(mailbox);
    if (bytes.length > maxFrameBytes) return PutResult.tooBig;
    if (!await box.exists()) {
      if (await _mailboxCount() >= maxMailboxes) return PutResult.full;
      await box.create(recursive: true);
    }
    if ((await _files(box)).length >= maxPerMailbox) return PutResult.full;
    final stamp = _now().microsecondsSinceEpoch.toString().padLeft(16, '0');
    final id = '$stamp-${(_seq++ % 1000000).toString().padLeft(6, '0')}';
    final tmp = File('${box.path}$_sep$id.tmp');
    await tmp.writeAsBytes(bytes, flush: true);
    await tmp.rename('${box.path}$_sep$id.msg');
    return PutResult.ok;
  }

  /// Oldest first, without removing anything. Remove with [ack] once it is safely received.
  Future<List<MailItem>> peek(Iterable<String> mailboxes, {int perMailbox = 50}) async {
    final out = <MailItem>[];
    for (final m in mailboxes) {
      final files = await _files(_box(m));
      for (final f in files.take(perMailbox)) {
        try {
          out.add(MailItem(m, _idOf(f), await f.readAsBytes()));
        } on FileSystemException {
          // acknowledged by someone else a moment ago: nothing to deliver
        }
      }
    }
    return out;
  }

  Future<void> ack(String mailbox, String id) async {
    final box = _box(mailbox);
    if (!_idPattern.hasMatch(id)) return;
    final f = File('${box.path}$_sep$id.msg');
    try {
      await f.delete();
    } on FileSystemException {
      // already gone
    }
  }

  Future<void> deleteMailbox(String mailbox) async {
    final box = _box(mailbox);
    if (await box.exists()) await box.delete(recursive: true);
  }

  /// Deletes mail older than the time limit and empty mailboxes. Returns how many messages went.
  Future<int> sweep() async {
    var removed = 0;
    final cutoff = _now().microsecondsSinceEpoch - ttl.inMicroseconds;
    await for (final e in dir.list()) {
      if (e is! Directory) continue;
      final name = e.uri.pathSegments.where((s) => s.isNotEmpty).last;
      if (!mailboxPattern.hasMatch(name)) continue;
      for (final ext in ['.msg', '.tmp']) {
        for (final f in await _files(e, ext: ext)) {
          final stamp = int.tryParse(_idOf(f).split('-').first) ?? 0;
          if (stamp < cutoff) {
            await f.delete();
            if (ext == '.msg') removed++;
          }
        }
      }
      if ((await _files(e)).isEmpty && (await _files(e, ext: '.tmp')).isEmpty) {
        await e.delete(recursive: true);
      }
    }
    return removed;
  }
}
