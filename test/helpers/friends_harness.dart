import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:plural_app/controllers/friends_controller.dart';
import 'package:plural_app/data/doc_store.dart';
import 'package:plural_app/domain/models.dart';
import 'package:plural_app/friends/secret_store.dart';
import 'dart:async';
import 'package:plural_app/friends/relay_transport.dart';
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
  final List<String> drops = [];

  /// Hand this phone a piece of mail directly, as if it had just arrived.
  void inject(Envelope e) => _ctl.add(e);

  @override
  Future<void> drop(String mailbox) async {
    drops.add(mailbox);
    await forget(mailbox);
  }

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
/// One pretend phone: its own database, secret store, network port and controller.
class Phone {
  Phone(this.hub, {List<Alter>? withAlters, DateTime? start})
      : alters = withAlters ?? <Alter>[],
        now = start ?? DateTime(2026, 10, 15, 9) {
    store = MemoryDocStore();
    secrets = MemorySecretStore();
    transport = hub.port();
    c = _controller();
  }

  final MemoryHub hub;
  final List<Alter> alters;
  List<String> outIds = [];
  bool little = false;
  DateTime now;
  late final MemoryDocStore store;
  late final MemorySecretStore secrets;
  late final MemoryTransport transport;
  late FriendsController c;

  FriendsController _controller() => FriendsController(
        store: store,
        secrets: secrets,
        transport: transport,
        frontOut: () => [for (final id in outIds) ...alters.where((a) => a.id == id)],
        alterById: (id) => alters.where((a) => a.id == id).firstOrNull,
        littleLocked: () => little,
        // Every look at the clock moves it on a millisecond, so two things made
        // "now" never share a timestamp and sort order is never a coin flip.
        clock: () => now = now.add(const Duration(milliseconds: 1)),
      );

  /// A phone with chat switched on.
  static Future<Phone> on(MemoryHub hub, {String username = 'zed', List<Alter>? withAlters}) async {
    final p = Phone(hub, withAlters: withAlters);
    await p.c.load();
    await p.c.enable(username: username);
    return p;
  }

  /// Pretend the app was closed and opened again: same database and secrets.
  Future<void> restart() async {
    c.dispose();
    c = _controller();
    await c.load();
  }
}

/// Let every phone finish handling what it received, including replies.
Future<void> settle(Iterable<Phone> phones) async {
  for (var round = 0; round < 5; round++) {
    for (final p in phones) {
      await p.c.idle;
    }
  }
}

/// [asker] scans [shower]'s code and [shower] accepts. Both end up friends.
Future<void> befriend(Phone asker, Phone shower) async {
  final code = await shower.c.myCode();
  await asker.c.addFromCode(code);
  await settle([asker, shower]);
  await shower.c.acceptRequest(shower.c.pendingRequests.single.id);
  await settle([asker, shower]);
}

/// For real-network tests: wait (briefly) until something becomes true.
Future<void> eventually(Future<bool> Function() ok, {Duration timeout = const Duration(seconds: 8)}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    if (await ok()) return;
    await Future<void>.delayed(const Duration(milliseconds: 25));
  }
  fail('timed out waiting for something to happen');
}

RelayTransport _testRelay(Uri base) => RelayTransport(
      base,
      pollWait: const Duration(seconds: 1),
      backoffMin: const Duration(milliseconds: 50),
      backoffMax: const Duration(milliseconds: 200),
      requestTimeout: const Duration(seconds: 3),
    );

/// A pretend phone that really talks to a relay over HTTP.
class RelayPhone {
  RelayPhone(this.base) {
    store = MemoryDocStore();
    secrets = MemorySecretStore();
    transport = _testRelay(base);
    c = _controller();
    _watchOnline();
  }

  final Uri base;
  DateTime now = DateTime(2026, 10, 15, 9);
  late final MemoryDocStore store;
  late final MemorySecretStore secrets;
  late RelayTransport transport;
  late FriendsController c;
  StreamSubscription<bool>? _online;

  /// Same as the app: when the relay comes back, send whatever was waiting.
  void _watchOnline() {
    _online?.cancel();
    _online = transport.onlineChanges.listen((on) {
      if (on && c.isOn) c.flush().catchError((Object _) {});
    });
  }

  FriendsController _controller() => FriendsController(
        store: store,
        secrets: secrets,
        transport: transport,
        frontOut: () => const [],
        alterById: (_) => null,
        littleLocked: () => false,
        clock: () => now = now.add(const Duration(milliseconds: 1)),
      );

  static Future<RelayPhone> on(Uri base, {String username = 'zed'}) async {
    final p = RelayPhone(base);
    await p.c.load();
    await p.c.enable(username: username);
    return p;
  }

  /// The app closed and opened again: same database and keys, a fresh connection.
  Future<void> restart() async {
    await _online?.cancel();
    c.dispose();
    await transport.close();
    transport = _testRelay(base);
    c = _controller();
    _watchOnline();
    await c.load();
  }

  Future<void> close() async {
    await _online?.cancel();
    c.dispose();
    await transport.close();
  }
}

/// Windows can hold a file open for a moment after a server stops; try a few times.
Future<void> deleteDirSoon(Directory dir) async {
  for (var i = 0; i < 20; i++) {
    try {
      if (await dir.exists()) await dir.delete(recursive: true);
      return;
    } on FileSystemException {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
  }
}
