import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'friend_models.dart';

class IdentityKeys {
  const IdentityKeys(this.privateBytes, this.publicBytes);
  final List<int> privateBytes;
  final List<int> publicBytes;
}

class PairKeys {
  const PairKeys({
    required this.key,
    required this.myInbox,
    required this.theirInbox,
    required this.safetyNumber,
  });
  final SecretKey key;
  final String myInbox; // where mail for me from this friend arrives
  final String theirInbox; // where I drop mail for this friend
  final String safetyNumber; // both friends see the same one
}

class PairingCode {
  const PairingCode({required this.username, required this.publicKey, required this.mailbox});
  final String username;
  final Uint8List publicKey;
  final String mailbox; // one-time mailbox for the first hello
}

class FriendCrypto {
  FriendCrypto._();
  static final _x25519 = X25519();
  static final _aead = Chacha20.poly1305Aead();
  static final _hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);

  static Future<IdentityKeys> newIdentity() async {
    final kp = await _x25519.newKeyPair();
    return IdentityKeys(await kp.extractPrivateKeyBytes(), (await kp.extractPublicKey()).bytes);
  }

  static int _compare(List<int> a, List<int> b) {
    for (var i = 0; i < a.length && i < b.length; i++) {
      if (a[i] != b[i]) return a[i].compareTo(b[i]);
    }
    return a.length.compareTo(b.length);
  }

  static String _b64(List<int> bytes) => base64Url.encode(bytes).replaceAll('=', '');

  static Future<PairKeys> derive(IdentityKeys mine, List<int> theirPublic) async {
    if (theirPublic.length != 32) throw ArgumentError('That friend key is not valid.');
    final keyPair = SimpleKeyPairData(
      mine.privateBytes,
      publicKey: SimplePublicKey(mine.publicBytes, type: KeyPairType.x25519),
      type: KeyPairType.x25519,
    );
    final shared = await _x25519.sharedSecretKey(
      keyPair: keyPair,
      remotePublicKey: SimplePublicKey(theirPublic, type: KeyPairType.x25519),
    );
    final first = _compare(mine.publicBytes, theirPublic) <= 0;
    final sorted = first ? [...mine.publicBytes, ...theirPublic] : [...theirPublic, ...mine.publicBytes];

    Future<List<int>> expand(String info, [List<int> extra = const []]) async {
      final k = await _hkdf.deriveKey(secretKey: shared, nonce: sorted, info: [...utf8.encode(info), ...extra]);
      return k.extractBytes();
    }

    final key = SecretKey(await expand('wanderland/key/v1'));
    final myInbox = _b64((await expand('wanderland/inbox/v1', mine.publicBytes)).sublist(0, 16));
    final theirInbox = _b64((await expand('wanderland/inbox/v1', theirPublic)).sublist(0, 16));

    final digest = (await Sha256().hash(sorted)).bytes;
    final groups = <String>[];
    for (var i = 0; i < 6; i++) {
      final n = (digest[3 * i] << 16 | digest[3 * i + 1] << 8 | digest[3 * i + 2]) % 100000;
      groups.add(n.toString().padLeft(5, '0'));
    }
    return PairKeys(key: key, myInbox: myInbox, theirInbox: theirInbox, safetyNumber: groups.join(' '));
  }

  static List<int> _aad(String mailbox) => utf8.encode('wl1|$mailbox');

  static Future<Uint8List> seal(SecretKey key, List<int> plain, {required String mailbox}) async {
    final box = await _aead.encrypt(plain, secretKey: key, aad: _aad(mailbox));
    return Uint8List.fromList(box.concatenation());
  }

  /// Null when it was not made for this key and mailbox, or was changed on the way.
  static Future<Uint8List?> open(SecretKey key, List<int> sealed, {required String mailbox}) async {
    if (sealed.length < 28) return null; // 12 nonce + 16 tag
    try {
      final box = SecretBox.fromConcatenation(sealed, nonceLength: 12, macLength: 16);
      return Uint8List.fromList(await _aead.decrypt(box, secretKey: key, aad: _aad(mailbox)));
    } on SecretBoxAuthenticationError {
      return null;
    }
  }

  static String randomMailbox() {
    final r = Random.secure();
    return _b64([for (var i = 0; i < 16; i++) r.nextInt(256)]);
  }
}

const _badCode = 'That code does not look right. Ask your friend to show it again.';

String encodePairingCode({required String username, required List<int> publicKey, required String mailbox}) =>
    'WL1-${base64Url.encode(utf8.encode(jsonEncode({'u': username, 'k': base64Url.encode(publicKey), 'm': mailbox})))}';

PairingCode decodePairingCode(String raw) {
  final text = raw.trim();
  if (!text.startsWith('WL1-')) throw const FormatException(_badCode);
  try {
    final j = jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(text.substring(4)))));
    if (j is! Map) throw const FormatException(_badCode);
    final u = j['u'];
    final k = j['k'];
    final m = j['m'];
    if (u is! String || k is! String || m is! String) throw const FormatException(_badCode);
    final key = base64Url.decode(base64Url.normalize(k));
    if (key.length != 32) throw const FormatException(_badCode);
    if (usernameProblem(u) != null) throw const FormatException(_badCode);
    if (!RegExp(r'^[A-Za-z0-9_-]{16,43}$').hasMatch(m)) throw const FormatException(_badCode);
    return PairingCode(username: u.trim(), publicKey: Uint8List.fromList(key), mailbox: m);
  } on FormatException {
    throw const FormatException(_badCode);
  }
}
