import 'dart:async';
import 'package:plural_app/friends/transport.dart';

/// A pretend relay: holds mail for mailboxes nobody is listening on yet.
class MemoryHub {
  final List<Envelope> log = [];
  final Map<String, List<Envelope>> _waiting = {};
  final Map<String, MemoryTransport> _owners = {};

  MemoryTransport port() => MemoryTransport._(this);

  Future<void> deliver(Envelope e) async {
    log.add(e);
    final owner = _owners[e.mailbox];
    if (owner != null && owner._reachable) {
      owner._ctl.add(e);
    } else {
      (_waiting[e.mailbox] ??= []).add(e);
    }
  }

  void _claim(String mailbox, MemoryTransport t) {
    _owners[mailbox] = t;
    _flushTo(mailbox, t);
  }

  void _flushTo(String mailbox, MemoryTransport t) {
    if (!t._reachable) return;
    final waiting = _waiting.remove(mailbox);
    if (waiting == null) return;
    for (final e in waiting) {
      t._ctl.add(e);
    }
  }

  void _release(String mailbox, MemoryTransport t) {
    if (_owners[mailbox] == t) _owners.remove(mailbox);
  }
}

class MemoryTransport implements FriendTransport {
  MemoryTransport._(this._hub);
  final MemoryHub _hub;
  final StreamController<Envelope> _ctl = StreamController<Envelope>.broadcast(sync: true);
  bool _reachable = true;
  final Set<String> listening = {};

  bool get reachable => _reachable;
  set reachable(bool v) {
    _reachable = v;
    if (v) {
      for (final m in listening.toList()) {
        _hub._flushTo(m, this);
      }
    }
  }

  @override
  Stream<Envelope> get incoming => _ctl.stream;

  @override
  Future<bool> send(Envelope e) async {
    if (!_reachable) return false;
    await _hub.deliver(e);
    return true;
  }

  @override
  Future<void> listenOn(String mailbox) async {
    listening.add(mailbox);
    _hub._claim(mailbox, this);
  }

  @override
  Future<void> forget(String mailbox) async {
    listening.remove(mailbox);
    _hub._release(mailbox, this);
  }
}
