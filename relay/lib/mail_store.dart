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
  int _lastStamp = 0;

  /// Test hook: runs after a mailbox looks empty and just before it is tidied away.
  Future<void> Function(String mailbox)? onSweepBeforeRemove;

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
    final existing = await _files(box);
    if (existing.length >= maxPerMailbox) return PutResult.full;
    // Never let the clock (or a step backwards) reorder mail: each stamp is later than the last.
    var stamp = _now().microsecondsSinceEpoch;
    if (stamp <= _lastStamp) stamp = _lastStamp + 1;
    if (existing.isNotEmpty) {
      final newest = int.tryParse(_idOf(existing.last).split('-').first) ?? 0;
      if (stamp <= newest) stamp = newest + 1;
    }
    _lastStamp = stamp;
    final id = '${stamp.toString().padLeft(16, '0')}-${(_seq++ % 1000000).toString().padLeft(6, '0')}';
    for (var attempt = 0;; attempt++) {
      try {
        final tmp = File('${box.path}$_sep$id.tmp');
        await tmp.writeAsBytes(bytes, flush: true);
        await tmp.rename('${box.path}$_sep$id.msg');
        return PutResult.ok;
      } on FileSystemException {
        // the mailbox folder was tidied away a moment ago: make it again, once
        if (attempt >= 1) rethrow;
        await box.create(recursive: true);
      }
    }
  }

  /// Oldest first, without removing anything. Remove with [ack] once it is safely received.
  /// Stops reading once [maxBytes] have been collected (always at least one message if any wait).
  Future<List<MailItem>> peek(Iterable<String> mailboxes, {int perMailbox = 50, int? maxBytes}) async {
    final out = <MailItem>[];
    var total = 0;
    for (final m in mailboxes) {
      final files = await _files(_box(m));
      for (final f in files.take(perMailbox)) {
        if (maxBytes != null && total >= maxBytes) return out;
        try {
          final bytes = await f.readAsBytes();
          total += bytes.length;
          out.add(MailItem(m, _idOf(f), bytes));
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
      // One bad mailbox (for example one a friend just removed) never stops the rest.
      try {
        for (final ext in ['.msg', '.tmp']) {
          for (final f in await _files(e, ext: ext)) {
            final stamp = int.tryParse(_idOf(f).split('-').first) ?? 0;
            if (stamp < cutoff) {
              try {
                await f.delete();
                if (ext == '.msg') removed++;
              } on FileSystemException {
                // already gone
              }
            }
          }
        }
        if ((await _files(e)).isEmpty && (await _files(e, ext: '.tmp')).isEmpty) {
          await onSweepBeforeRemove?.call(name);
          // Not recursive on purpose: if mail landed a moment ago this refuses instead of deleting it.
          await e.delete();
        }
      } on FileSystemException {
        // gone, or no longer empty: leave it for the next sweep
      }
    }
    return removed;
  }
}
