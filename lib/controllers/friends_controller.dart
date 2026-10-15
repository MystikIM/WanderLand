import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../data/doc_store.dart';
import '../domain/ids.dart';
import '../domain/models.dart';
import '../friends/friend_crypto.dart';
import '../friends/friend_models.dart';
import '../friends/secret_store.dart';
import '../friends/transport.dart';

/// Alters who are out right now, primary first.
typedef FrontOut = List<Alter> Function();

class FriendsController extends ChangeNotifier {
  FriendsController({
    required this._store,
    required this._secrets,
    required this._transport,
    required this._frontOut,
    required this._alterById,
    required this._littleLocked,
    Clock? clock,
  }) : _clock = clock ?? DateTime.now;

  static const identityCollection = 'chat_identity';
  static const friendsCollection = 'friends';
  static const messagesCollection = 'friend_messages';
  static const outboxCollection = 'friend_outbox';
  static const secretKeyName = 'chat.identity.private';
  static const maxText = 4000;
  static const maxRequestsPerDay = 5;
  static const keyMissing =
      'This phone lost its chat key, so old friends cannot be read. Reset chat to start fresh.';

  final DocStore _store;
  final SecretStore _secrets;
  final FriendTransport _transport;
  // ignore: unused_field
  final FrontOut _frontOut;
  // ignore: unused_field
  final Alter? Function(String id) _alterById;
  final bool Function() _littleLocked;
  final Clock _clock;

  ChatIdentity? identity;
  List<Friend> friends = const [];
  IdentityKeys? _keys;
  StreamSubscription<Envelope>? _sub;

  bool get isOn => identity != null && identity!.mode != ChatMode.off;

  /// True while the little guard is on and a little is out. Then only a grown-up may
  /// add, accept or remove friends or change sharing; a little may chat only with
  /// friends marked [Friend.littleOk]. Reading, muting and blocking are always allowed.
  bool get locked => _littleLocked();

  Future<void> load() async {
    final raw = await _store.get(identityCollection, ChatIdentity.docId);
    identity = raw == null ? null : ChatIdentity.fromJson(raw);
    friends = (await _store.all(friendsCollection)).map(Friend.fromJson).toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    _keys = null;
    notifyListeners();
    if (isOn) {
      try {
        await _startListening();
      } on StateError {
        // The chat key is missing. Opening the app must still work; the plain
        // message is shown the moment chat is used (see keyMissing).
      }
    }
  }

  // ---- helpers ----------------------------------------------------------

  Friend? _friend(String id) => friends.where((f) => f.id == id).firstOrNull;

  Future<void> _saveIdentity(ChatIdentity i) async {
    identity = i;
    await _store.put(identityCollection, i.toJson());
  }

  Future<void> _putFriend(Friend f) async {
    await _store.put(friendsCollection, f.toJson());
    friends = [for (final x in friends) if (x.id != f.id) x, f]
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  Future<IdentityKeys> _myKeys() async {
    final cached = _keys;
    if (cached != null) return cached;
    final me = identity;
    if (me == null) throw StateError('Turn chat on first.');
    final secret = await _secrets.read(secretKeyName);
    if (secret == null) throw StateError(keyMissing);
    return _keys = IdentityKeys(base64.decode(secret), base64.decode(me.publicKey));
  }

  ChatIdentity _requireOn() {
    final me = identity;
    if (me == null || me.mode == ChatMode.off) throw StateError('Turn chat on first.');
    return me;
  }

  Future<void> _startListening() async {
    await _myKeys(); // fail loudly now if the key is gone
    final me = identity!;
    for (final f in friends.where((f) => f.state != FriendState.blocked)) {
      await _transport.listenOn(f.inbox);
    }
    for (final m in me.pairingMailboxes) {
      await _transport.listenOn(m);
    }
  }

  Future<void> _stopListening() async {
    await _sub?.cancel();
    _sub = null;
    for (final f in friends) {
      await _transport.forget(f.inbox);
    }
    for (final m in identity?.pairingMailboxes ?? const <String>[]) {
      await _transport.forget(m);
    }
  }

  // ---- turning chat on and off ------------------------------------------

  Future<void> enable({required String username, ChatMode mode = ChatMode.whileOpen}) async {
    final problem = usernameProblem(username);
    if (problem != null) throw ArgumentError(problem);
    if (mode == ChatMode.off) throw ArgumentError('Pick "while the app is open" or "always on".');
    final existing = identity;
    final IdentityKeys keys;
    if (existing != null) {
      keys = await _myKeys(); // throws keyMissing if the secret is gone
    } else {
      keys = await FriendCrypto.newIdentity();
      await _secrets.write(secretKeyName, base64.encode(keys.privateBytes));
    }
    _keys = keys;
    await _saveIdentity(ChatIdentity(
      username: username.trim(),
      publicKey: base64.encode(keys.publicBytes),
      createdAt: existing?.createdAt ?? _clock(),
      mode: mode,
      pairingMailboxes: existing?.pairingMailboxes ?? const [],
    ));
    notifyListeners();
    await _startListening();
  }

  Future<void> setMode(ChatMode mode) async {
    final me = identity;
    if (me == null) throw StateError('Turn chat on first.');
    if (mode == ChatMode.off) await _stopListening();
    await _saveIdentity(me.copyWith(mode: mode));
    notifyListeners();
    if (mode != ChatMode.off) await _startListening();
  }

  Future<void> setUsername(String username) async {
    final me = identity;
    if (me == null) throw StateError('Turn chat on first.');
    final problem = usernameProblem(username);
    if (problem != null) throw ArgumentError(problem);
    await _saveIdentity(me.copyWith(username: username.trim()));
    notifyListeners();
  }

  /// A code to show a friend. Each press makes a fresh one-time mailbox; only the
  /// five newest stay open.
  Future<String> myCode() async {
    final me = _requireOn();
    final keys = await _myKeys();
    final mailbox = FriendCrypto.randomMailbox();
    var boxes = [...me.pairingMailboxes, mailbox];
    if (boxes.length > 5) {
      for (final old in boxes.sublist(0, boxes.length - 5)) {
        await _transport.forget(old);
      }
      boxes = boxes.sublist(boxes.length - 5);
    }
    await _saveIdentity(me.copyWith(pairingMailboxes: boxes));
    await _transport.listenOn(mailbox);
    notifyListeners();
    return encodePairingCode(username: me.username, publicKey: keys.publicBytes, mailbox: mailbox);
  }

  /// Wipes chat on this phone: identity, friends, messages, waiting mail and the key.
  Future<void> reset() async {
    await _stopListening();
    for (final f in friends) {
      await _store.delete(friendsCollection, f.id);
    }
    for (final c in [messagesCollection, outboxCollection]) {
      for (final d in await _store.all(c)) {
        await _store.delete(c, d['id'] as String);
      }
    }
    await _store.delete(identityCollection, ChatIdentity.docId);
    await _secrets.delete(secretKeyName);
    identity = null;
    friends = const [];
    _keys = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
