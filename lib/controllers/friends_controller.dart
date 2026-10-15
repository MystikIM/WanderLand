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
import '../friends/wire.dart';
import '../friends/sharing.dart';

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
  List<FriendMessage> _messages = const [];

  List<FriendMessage> messagesWith(String friendId) =>
      _messages.where((m) => m.friendId == friendId).toList();
  IdentityKeys? _keys;
  StreamSubscription<Envelope>? _sub;
  Future<void> _inboxQueue = Future.value();

  /// Everything that changes friends, messages or identity runs one at a time on this
  /// queue, so an incoming message can never slip in halfway through a local action
  /// (two records for one friend, or a counter update overwritten).
  Future<T> _exclusive<T>(Future<T> Function() body) {
    final done = Completer<T>();
    _inboxQueue = _inboxQueue.then((_) async {
      try {
        done.complete(await body());
      } catch (e, s) {
        done.completeError(e, s);
      }
    });
    return done.future;
  }

  /// Completes when everything received so far has been handled (tests wait on this).
  Future<void> get idle => _inboxQueue;

  List<Friend> get pendingRequests => friends.where((f) => f.state == FriendState.pendingIn).toList();

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
    _messages = (await _store.all(messagesCollection)).map(FriendMessage.fromJson).toList()
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
    await _sub?.cancel();
    _sub = _transport.incoming.listen((e) {
      _inboxQueue = _inboxQueue.then((_) => _handle(e)).catchError((Object _) {});
    });
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
  Future<String> myCode() => _exclusive(_myCode);

  Future<String> _myCode() async {
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

  // ---- sending ----------------------------------------------------------

  /// Seals a message for [f], stamps it with the next counter, optionally keeps it
  /// in the outbox until it is handed over, and tries to send it now.
  Future<bool> _sendSealed(
    Friend f, {
    required String type,
    required Map<String, dynamic> body,
    required String toMailbox,
    bool includeFrom = false,
    bool queue = false,
    String? msgId,
  }) async {
    final keys = await _myKeys();
    final pair = await FriendCrypto.derive(keys, base64.decode(f.publicKey));
    final current = _friend(f.id) ?? f;
    final n = current.nextOut;
    final plain = utf8.encode(jsonEncode({'t': type, 'n': n, ...body}));
    final sealed = await FriendCrypto.seal(pair.key, plain, mailbox: toMailbox);
    await _putFriend(current.copyWith(nextOut: n + 1));
    final bytes = encodeFrame(from: includeFrom ? identity!.publicKey : null, sealed: sealed);
    String? queuedId;
    if (queue) {
      queuedId = IdGen.next(_clock());
      await _store.put(outboxCollection, {
        'id': queuedId,
        'friendId': f.id,
        'kind': type,
        'n': n, // keeps retries in the order they were made
        'mailbox': toMailbox,
        'frame': base64.encode(bytes),
        'msgId': ?msgId,
      });
    }
    final ok = await _transport.send(Envelope(toMailbox, bytes));
    if (ok && queuedId != null) await _store.delete(outboxCollection, queuedId);
    return ok;
  }

  Future<void> _dropOutbox(String friendId, {String? kind}) async {
    for (final d in await _store.all(outboxCollection)) {
      if (d['friendId'] == friendId && (kind == null || d['kind'] == kind)) {
        await _store.delete(outboxCollection, d['id'] as String);
      }
    }
  }

  Future<void> _putMessage(FriendMessage m) async {
    await _store.put(messagesCollection, m.toJson());
    _messages = [for (final x in _messages) if (x.id != m.id) x, m]
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  /// Only ever moves a message forward: queued, then sent, then delivered.
  Future<void> _markMessage(String id, DeliveryState state) async {
    final m = _messages.where((x) => x.id == id && x.outgoing).firstOrNull;
    if (m == null || state.index <= m.state.index) return;
    await _putMessage(m.copyWith(state: state));
  }

  /// Try again to hand over everything that is waiting (call when the connection is back).
  Future<void> flush() => _exclusive(_flush);

  Future<void> _flush() async {
    if (!isOn) return;
    final docs = (await _store.all(outboxCollection))
      ..sort((a, b) => (a['n'] as int).compareTo(b['n'] as int));
    for (final d in docs) {
      final ok = await _transport.send(Envelope(d['mailbox'] as String, base64.decode(d['frame'] as String)));
      if (!ok) break; // still offline: keep the order
      await _store.delete(outboxCollection, d['id'] as String);
      final mid = d['msgId'] as String?;
      if (mid != null) await _markMessage(mid, DeliveryState.sent);
    }
    notifyListeners();
  }

  // ---- friend requests --------------------------------------------------

  String _safeName(Object? raw, String fallback) =>
      raw is String && usernameProblem(raw) == null ? raw.trim() : fallback;

  Future<Friend> addFromCode(String code) => _exclusive(() => _addFromCode(code));

  Future<Friend> _addFromCode(String code) async {
    final me = _requireOn();
    if (locked) throw StateError('A grown-up alter needs to add friends.');
    final c = decodePairingCode(code); // throws FormatException with a plain message
    final theirKey = base64.encode(c.publicKey);
    if (theirKey == me.publicKey) throw ArgumentError('That is your own code.');
    final existing = friends.where((f) => f.publicKey == theirKey).firstOrNull;
    if (existing != null) {
      throw ArgumentError(existing.state == FriendState.blocked
          ? 'This person is blocked. Remove them from your blocked list first.'
          : 'You already have this friend, or a request is waiting.');
    }
    final pair = await FriendCrypto.derive(await _myKeys(), c.publicKey);
    final now = _clock();
    final f = Friend(
      id: IdGen.next(now),
      theirUsername: c.username,
      publicKey: theirKey,
      state: FriendState.pendingOut,
      inbox: pair.myInbox,
      outbox: pair.theirInbox,
      createdAt: now,
    );
    await _putFriend(f);
    await _transport.listenOn(pair.myInbox);
    notifyListeners();
    await _sendSealed(f,
        type: 'hello',
        body: {'u': me.username},
        toMailbox: c.mailbox,
        includeFrom: true,
        queue: true);
    return _friend(f.id)!;
  }

  Future<void> _sendAccept(Friend f) => _sendSealed(f,
      type: 'accept', body: {'u': identity!.username}, toMailbox: f.outbox, queue: true);

  Future<void> acceptRequest(String friendId) => _exclusive(() => _acceptRequest(friendId));

  Future<void> _acceptRequest(String friendId) async {
    _requireOn();
    if (locked) throw StateError('A grown-up alter needs to accept friends.');
    final f = _friend(friendId);
    if (f == null || f.state != FriendState.pendingIn) throw StateError('That request is gone.');
    await _putFriend(f.copyWith(state: FriendState.friends));
    notifyListeners();
    await _sendAccept(_friend(friendId)!);
  }

  /// Quiet: the other person is not told, they just keep waiting.
  Future<void> declineRequest(String friendId) => _exclusive(() => _declineRequest(friendId));

  Future<void> _declineRequest(String friendId) async {
    final f = _friend(friendId);
    if (f == null || f.state != FriendState.pendingIn) return;
    await _removeFriendData(f);
    notifyListeners();
  }

  Future<void> _removeFriendData(Friend f) async {
    await _transport.forget(f.inbox);
    await _dropOutbox(f.id);
    await _store.delete(friendsCollection, f.id);
    friends = [for (final x in friends) if (x.id != f.id) x];
  }

  Future<String> safetyNumberFor(String friendId) async {
    final f = _friend(friendId);
    if (f == null) throw StateError('That friend is gone.');
    return (await FriendCrypto.derive(await _myKeys(), base64.decode(f.publicKey))).safetyNumber;
  }

  // ---- messages ---------------------------------------------------------

  Future<FriendMessage> sendMessage({
    required String friendId,
    required String text,
    String? asAlterId,
  }) =>
      _exclusive(() => _sendMessage(friendId: friendId, text: text, asAlterId: asAlterId));

  Future<FriendMessage> _sendMessage({
    required String friendId,
    required String text,
    String? asAlterId,
  }) async {
    _requireOn();
    final f = _friend(friendId);
    if (f == null || f.state != FriendState.friends) {
      throw StateError('You can only message people who are your friends.');
    }
    if (locked && !f.littleOk) {
      throw StateError('Ask a grown-up alter to turn chat on for this friend first.');
    }
    final t = text.trim();
    if (t.isEmpty) throw ArgumentError('Write something first.');
    if (t.length > maxText) throw ArgumentError('That is too long. The most is $maxText characters.');
    final who = asAlterId != null ? _alterById(asAlterId) : _frontOut().firstOrNull;
    final speaker = speakerFor(f, who);
    final now = _clock();
    final id = IdGen.next(now);
    var m = FriendMessage(
      id: id,
      friendId: f.id,
      outgoing: true,
      text: t,
      createdAt: now,
      state: DeliveryState.queued,
      speakerName: speaker?.name,
      speakerColor: speaker?.colorValue,
    );
    await _putMessage(m);
    notifyListeners();
    final sent = await _sendSealed(f,
        type: 'msg',
        body: {'id': id, 'x': t, if (speaker != null) 'sp': speaker.toJson()},
        toMailbox: f.outbox,
        queue: true,
        msgId: id);
    if (sent) {
      await _markMessage(id, DeliveryState.sent);
      notifyListeners();
    }
    return _messages.firstWhere((x) => x.id == id, orElse: () => m);
  }

  Future<void> _onMessage(Friend f, Map<String, dynamic> m) async {
    if (f.state != FriendState.friends) return; // not friends yet: nothing to show
    final remoteId = m['id'];
    final text = m['x'];
    if (remoteId is! String || remoteId.isEmpty || remoteId.length > 64) return;
    if (text is! String || text.trim().isEmpty || text.length > maxText) return;
    final docId = '${f.id}-in-$remoteId';
    if (_messages.any((x) => x.id == docId)) return;
    String? speakerName;
    int? speakerColor;
    final sp = m['sp'];
    if (sp is Map && sp['n'] is String && sp['c'] is int) {
      final name = (sp['n'] as String).trim();
      if (name.isNotEmpty) {
        speakerName = name.length > 60 ? name.substring(0, 60) : name;
        speakerColor = sp['c'] as int;
      }
    }
    await _putMessage(FriendMessage(
      id: docId,
      friendId: f.id,
      outgoing: false,
      text: text,
      createdAt: _clock(),
      state: DeliveryState.delivered,
      speakerName: speakerName,
      speakerColor: speakerColor,
    ));
    // Tell them it arrived. Best effort: if this is lost they just see "sent".
    await _sendSealed(f, type: 'ack', body: {'id': remoteId}, toMailbox: f.outbox);
  }

  Future<void> _onAck(Friend f, Map<String, dynamic> m) async {
    final id = m['id'];
    if (id is String) await _markMessage(id, DeliveryState.delivered);
  }

  // ---- receiving --------------------------------------------------------

  Future<void> _handle(Envelope e) async {
    if (!isOn) return;
    final frame = decodeFrame(e.bytes);
    if (frame == null) return;
    final keys = await _myKeys();
    final fromKey = frame.from;
    Friend? known;
    final PairKeys pair;
    if (fromKey != null) {
      // A first hello: only accepted on one of my open pairing mailboxes.
      if (!identity!.pairingMailboxes.contains(e.mailbox)) return;
      final Uint8List theirPub;
      try {
        theirPub = base64.decode(fromKey);
      } on FormatException {
        return;
      }
      if (theirPub.length != 32) return;
      pair = await FriendCrypto.derive(keys, theirPub);
      known = friends.where((x) => x.publicKey == fromKey).firstOrNull;
    } else {
      known = friends.where((x) => x.inbox == e.mailbox).firstOrNull;
      if (known == null || known.state == FriendState.blocked) return;
      pair = await FriendCrypto.derive(keys, base64.decode(known.publicKey));
    }
    final plain = await FriendCrypto.open(pair.key, frame.sealed, mailbox: e.mailbox);
    if (plain == null) return;
    final Map<String, dynamic> m;
    try {
      final d = jsonDecode(utf8.decode(plain));
      if (d is! Map<String, dynamic>) return;
      m = d;
    } on FormatException {
      return;
    }
    final type = m['t'];
    final n = m['n'];
    if (type is! String || n is! int) return;

    if (fromKey != null) {
      if (type == 'hello') await _onHello(fromKey, pair, m, n, e.mailbox, known);
      notifyListeners();
      return;
    }
    var f = known!;
    if (n <= f.lastIn) return; // a repeat of something already handled
    f = f.copyWith(lastIn: n, lastSeen: _clock());
    await _putFriend(f);
    switch (type) {
      case 'accept':
        await _onAccept(f, m);
      case 'msg':
        await _onMessage(f, m);
      case 'ack':
        await _onAck(f, m);
    }

    notifyListeners();
  }

  Future<void> _onHello(String theirKey, PairKeys pair, Map<String, dynamic> m, int n, String mailbox,
      Friend? existing) async {
    if (existing != null) {
      if (existing.state == FriendState.blocked || existing.state == FriendState.pendingIn) return;
      if (existing.state == FriendState.pendingOut) {
        // We both asked at the same moment: that is a yes from both sides.
        await _putFriend(existing.copyWith(
          state: FriendState.friends,
          theirUsername: _safeName(m['u'], existing.theirUsername),
          lastIn: n > existing.lastIn ? n : existing.lastIn,
          lastSeen: _clock(),
        ));
        await _dropOutbox(existing.id, kind: 'hello');
      }
      await _sendAccept(_friend(existing.id)!);
      return;
    }
    final since = _clock().subtract(const Duration(days: 1));
    final recent =
        friends.where((x) => x.state == FriendState.pendingIn && x.createdAt.isAfter(since)).length;
    if (recent >= maxRequestsPerDay) return;
    final now = _clock();
    await _putFriend(Friend(
      id: IdGen.next(now),
      theirUsername: _safeName(m['u'], 'friend'),
      publicKey: theirKey,
      state: FriendState.pendingIn,
      inbox: pair.myInbox,
      outbox: pair.theirInbox,
      createdAt: now,
      lastIn: n,
      lastSeen: now,
    ));
    await _transport.listenOn(pair.myInbox);
    // The one-time pairing mailbox has done its job.
    final me = identity!;
    await _saveIdentity(me.copyWith(pairingMailboxes: [for (final b in me.pairingMailboxes) if (b != mailbox) b]));
    await _transport.forget(mailbox);
  }

  Future<void> _onAccept(Friend f, Map<String, dynamic> m) async {
    if (f.state != FriendState.pendingOut) return;
    await _putFriend(f.copyWith(
      state: FriendState.friends,
      theirUsername: _safeName(m['u'], f.theirUsername),
    ));
    await _dropOutbox(f.id, kind: 'hello');
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
    _messages = const [];
    _keys = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
