enum ChatMode { off, whileOpen, always }

enum FriendState { pendingOut, pendingIn, friends, blocked }

enum DeliveryState { queued, sent, delivered }

/// The chat collections that are private to one phone: never in a backup zip,
/// and a restore never wipes this phone's copies.
const Set<String> kPrivateCollections = {
  'chat_identity',
  'friends',
  'friend_messages',
  'friend_outbox',
};

T _byName<T extends Enum>(List<T> values, Object? name, T fallback) {
  for (final v in values) {
    if (v.name == name) return v;
  }
  return fallback;
}

/// Null when fine, otherwise a plain sentence saying what to fix.
String? usernameProblem(String raw) {
  final u = raw.trim();
  if (u.length < 3 || u.length > 24) return 'Pick a username between 3 and 24 characters.';
  if (!RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(u)) {
    return 'Use only letters, numbers, _ and - in a username.';
  }
  return null;
}

class ChatIdentity {
  const ChatIdentity({
    required this.username,
    required this.publicKey,
    required this.createdAt,
    this.mode = ChatMode.whileOpen,
    this.pairingMailboxes = const [],
  });
  static const docId = 'me';
  final String username;
  final String publicKey; // base64
  final DateTime createdAt;
  final ChatMode mode;
  final List<String> pairingMailboxes;

  ChatIdentity copyWith({String? username, ChatMode? mode, List<String>? pairingMailboxes}) => ChatIdentity(
        username: username ?? this.username,
        publicKey: publicKey,
        createdAt: createdAt,
        mode: mode ?? this.mode,
        pairingMailboxes: pairingMailboxes ?? this.pairingMailboxes,
      );

  Map<String, dynamic> toJson() => {
        'id': docId,
        'username': username,
        'publicKey': publicKey,
        'createdAt': createdAt.toIso8601String(),
        'mode': mode.name,
        'pairingMailboxes': pairingMailboxes,
      };

  factory ChatIdentity.fromJson(Map<String, dynamic> j) => ChatIdentity(
        username: j['username'] as String,
        publicKey: j['publicKey'] as String,
        createdAt: DateTime.parse(j['createdAt'] as String),
        mode: _byName(ChatMode.values, j['mode'], ChatMode.whileOpen),
        pairingMailboxes: [for (final m in (j['pairingMailboxes'] as List? ?? const [])) m as String],
      );
}

class TheirAlter {
  const TheirAlter(this.name, this.colorValue);
  final String name;
  final int colorValue;
  Map<String, dynamic> toJson() => {'n': name, 'c': colorValue};
  factory TheirAlter.fromJson(Map<String, dynamic> j) => TheirAlter(j['n'] as String, j['c'] as int);
}

/// What a friend is allowed to know about who is out right now.
class TheirFront {
  const TheirFront({required this.alters, required this.someoneOut});
  final List<TheirAlter> alters;
  final bool someoneOut; // true when someone out is NOT in [alters]
  Map<String, dynamic> toJson() => {
        'out': [for (final a in alters) a.toJson()],
        'some': someoneOut,
      };
  factory TheirFront.fromJson(Map<String, dynamic> j) => TheirFront(
        alters: [for (final a in (j['out'] as List? ?? const [])) TheirAlter.fromJson(Map<String, dynamic>.from(a as Map))],
        someoneOut: j['some'] as bool? ?? false,
      );
}

class Friend {
  const Friend({
    required this.id,
    required this.theirUsername,
    required this.publicKey,
    required this.state,
    required this.inbox,
    required this.outbox,
    required this.createdAt,
    this.nickname = '',
    this.muted = false,
    this.shareFront = false,
    this.allowedAlterIds = const [],
    this.littleOk = false,
    this.nextOut = 1,
    this.lastIn = 0,
    this.lastSeen,
    this.theirFront,
  });
  final String id;
  final String theirUsername;
  final String publicKey; // base64, theirs
  final FriendState state;
  final String inbox; // mailbox I listen on for this friend
  final String outbox; // mailbox I send to for this friend
  final DateTime createdAt;
  final String nickname;
  final bool muted;
  final bool shareFront;
  final List<String> allowedAlterIds;
  final bool littleOk; // a grown-up allowed littles to chat with this friend
  final int nextOut; // counter for the next thing I send
  final int lastIn; // highest counter I accepted from them
  final DateTime? lastSeen;
  final TheirFront? theirFront;

  String get displayName => nickname.isNotEmpty ? nickname : theirUsername;

  Friend copyWith({
    String? theirUsername,
    FriendState? state,
    String? nickname,
    bool? muted,
    bool? shareFront,
    List<String>? allowedAlterIds,
    bool? littleOk,
    int? nextOut,
    int? lastIn,
    DateTime? lastSeen,
    TheirFront? theirFront,
    bool clearFront = false,
  }) =>
      Friend(
        id: id,
        theirUsername: theirUsername ?? this.theirUsername,
        publicKey: publicKey,
        state: state ?? this.state,
        inbox: inbox,
        outbox: outbox,
        createdAt: createdAt,
        nickname: nickname ?? this.nickname,
        muted: muted ?? this.muted,
        shareFront: shareFront ?? this.shareFront,
        allowedAlterIds: allowedAlterIds ?? this.allowedAlterIds,
        littleOk: littleOk ?? this.littleOk,
        nextOut: nextOut ?? this.nextOut,
        lastIn: lastIn ?? this.lastIn,
        lastSeen: lastSeen ?? this.lastSeen,
        theirFront: clearFront ? null : (theirFront ?? this.theirFront),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'theirUsername': theirUsername,
        'publicKey': publicKey,
        'state': state.name,
        'inbox': inbox,
        'outbox': outbox,
        'createdAt': createdAt.toIso8601String(),
        'nickname': nickname,
        'muted': muted,
        'shareFront': shareFront,
        'allowedAlterIds': allowedAlterIds,
        'littleOk': littleOk,
        'nextOut': nextOut,
        'lastIn': lastIn,
        if (lastSeen != null) 'lastSeen': lastSeen!.toIso8601String(),
        if (theirFront != null) 'theirFront': theirFront!.toJson(),
      };

  factory Friend.fromJson(Map<String, dynamic> j) => Friend(
        id: j['id'] as String,
        theirUsername: j['theirUsername'] as String,
        publicKey: j['publicKey'] as String,
        state: _byName(FriendState.values, j['state'], FriendState.blocked),
        inbox: j['inbox'] as String,
        outbox: j['outbox'] as String,
        createdAt: DateTime.parse(j['createdAt'] as String),
        nickname: j['nickname'] as String? ?? '',
        muted: j['muted'] as bool? ?? false,
        shareFront: j['shareFront'] as bool? ?? false,
        allowedAlterIds: [for (final a in (j['allowedAlterIds'] as List? ?? const [])) a as String],
        littleOk: j['littleOk'] as bool? ?? false,
        nextOut: j['nextOut'] as int? ?? 1,
        lastIn: j['lastIn'] as int? ?? 0,
        lastSeen: j['lastSeen'] == null ? null : DateTime.parse(j['lastSeen'] as String),
        theirFront: j['theirFront'] == null
            ? null
            : TheirFront.fromJson(Map<String, dynamic>.from(j['theirFront'] as Map)),
      );
}

class FriendMessage {
  const FriendMessage({
    required this.id,
    required this.friendId,
    required this.outgoing,
    required this.text,
    required this.createdAt,
    required this.state,
    this.speakerName,
    this.speakerColor,
  });
  final String id;
  final String friendId;
  final bool outgoing;
  final String text;
  final DateTime createdAt;
  final DeliveryState state;
  final String? speakerName; // null = just the system username
  final int? speakerColor;

  FriendMessage copyWith({DeliveryState? state}) => FriendMessage(
        id: id,
        friendId: friendId,
        outgoing: outgoing,
        text: text,
        createdAt: createdAt,
        state: state ?? this.state,
        speakerName: speakerName,
        speakerColor: speakerColor,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'friendId': friendId,
        'outgoing': outgoing,
        'text': text,
        'createdAt': createdAt.toIso8601String(),
        'state': state.name,
        if (speakerName != null) 'speakerName': speakerName,
        if (speakerColor != null) 'speakerColor': speakerColor,
      };

  factory FriendMessage.fromJson(Map<String, dynamic> j) => FriendMessage(
        id: j['id'] as String,
        friendId: j['friendId'] as String,
        outgoing: j['outgoing'] as bool,
        text: j['text'] as String,
        createdAt: DateTime.parse(j['createdAt'] as String),
        state: _byName(DeliveryState.values, j['state'], DeliveryState.sent),
        speakerName: j['speakerName'] as String?,
        speakerColor: j['speakerColor'] as int?,
      );
}
