import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import '../data/doc_store.dart';
import 'ids.dart';

class PinLock {
  PinLock(this._store, {Clock? clock}) : _clock = clock ?? DateTime.now;
  static const collection = 'settings';
  static const resetWait = Duration(hours: 24);
  final DocStore _store;
  final Clock _clock;

  Future<Map<String, dynamic>?> _doc() => _store.get(collection, 'pin');

  static String _hash(String salt, String pin) =>
      sha256.convert(utf8.encode('$salt:$pin')).toString();

  Future<bool> get isSet async => (await _doc())?['hash'] != null;

  Future<String> get hint async => (await _doc())?['hint'] as String? ?? '';

  Future<void> setPin(String pin, {String hint = ''}) async {
    if (!RegExp(r'^\d{4,8}$').hasMatch(pin)) {
      throw ArgumentError('A PIN is 4 to 8 digits');
    }
    final salt = '${IdGen.next(_clock())}-${Random.secure().nextInt(1 << 32)}';
    await _store.put(collection, {
      'id': 'pin',
      'salt': salt,
      'hash': _hash(salt, pin),
      'hint': hint.trim(),
      'resetAt': null,
    });
  }

  Future<bool> verify(String pin) async {
    final d = await _doc();
    if (d == null || d['hash'] == null) return false;
    final ok = _hash(d['salt'] as String, pin) == d['hash'];
    if (ok && d['resetAt'] != null) {
      await _store.put(collection, {...d, 'resetAt': null});
    }
    return ok;
  }

  Future<DateTime?> get resetAt async {
    final raw = (await _doc())?['resetAt'] as String?;
    return raw == null ? null : DateTime.parse(raw);
  }

  /// Start (or keep) the 24-hour wait. Returns when the reset becomes ready.
  Future<DateTime?> requestReset() async {
    final d = await _doc();
    if (d == null || d['hash'] == null) return null;
    final existing = d['resetAt'] as String?;
    if (existing != null) return DateTime.parse(existing);
    final ready = _clock().add(resetWait);
    await _store.put(collection, {...d, 'resetAt': ready.toIso8601String()});
    return ready;
  }

  Future<bool> get resetReady async {
    final at = await resetAt;
    return at != null && !_clock().isBefore(at);
  }

  Future<bool> completeReset() async {
    if (!await resetReady) return false;
    await _store.delete(collection, 'pin');
    return true;
  }

  Future<void> remove() => _store.delete(collection, 'pin');
}
