import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:plural_app/friends/friend_crypto.dart';
import 'package:plural_app/friends/wire.dart';

void main() {
  late IdentityKeys a;
  late IdentityKeys b;
  late PairKeys ab; // from A's side
  late PairKeys ba; // from B's side

  setUp(() async {
    a = await FriendCrypto.newIdentity();
    b = await FriendCrypto.newIdentity();
    ab = await FriendCrypto.derive(a, b.publicBytes);
    ba = await FriendCrypto.derive(b, a.publicBytes);
  });

  test('keys are 32 bytes and every identity is different', () async {
    expect(a.publicBytes.length, 32);
    expect(a.privateBytes.length, 32);
    expect(a.publicBytes, isNot(b.publicBytes));
  });

  test('both friends derive the same key, with the inboxes crossed over', () async {
    expect(await ab.key.extractBytes(), await ba.key.extractBytes());
    expect(ab.myInbox, ba.theirInbox);
    expect(ab.theirInbox, ba.myInbox);
    expect(ab.myInbox, isNot(ab.theirInbox));
    expect(ab.safetyNumber, ba.safetyNumber);
  });

  test('inboxes are short url-safe ids and the safety number is six groups of five digits', () {
    expect(ab.myInbox, matches(RegExp(r'^[A-Za-z0-9_-]{22}$')));
    expect(ab.safetyNumber, matches(RegExp(r'^\d{5}( \d{5}){5}$')));
  });

  test('a different friend gives a different key, inbox and safety number', () async {
    final c = await FriendCrypto.newIdentity();
    final ac = await FriendCrypto.derive(a, c.publicBytes);
    expect(await ac.key.extractBytes(), isNot(await ab.key.extractBytes()));
    expect(ac.myInbox, isNot(ab.myInbox));
    expect(ac.safetyNumber, isNot(ab.safetyNumber));
  });

  test('a key that is not 32 bytes is refused', () async {
    expect(() => FriendCrypto.derive(a, [1, 2, 3]), throwsArgumentError);
  });

  test('seal then open gives the words back, and the sealed bytes do not contain them', () async {
    final sealed = await FriendCrypto.seal(ab.key, utf8.encode('secret words'), mailbox: ab.theirInbox);
    expect(latin1.decode(sealed), isNot(contains('secret')));
    final opened = await FriendCrypto.open(ba.key, sealed, mailbox: ab.theirInbox);
    expect(utf8.decode(opened!), 'secret words');
  });

  test('open gives null for the wrong key, wrong mailbox, tampering and short input', () async {
    final sealed = await FriendCrypto.seal(ab.key, utf8.encode('x'), mailbox: 'mbx');
    final c = await FriendCrypto.newIdentity();
    final other = await FriendCrypto.derive(c, a.publicBytes);
    expect(await FriendCrypto.open(other.key, sealed, mailbox: 'mbx'), isNull);
    expect(await FriendCrypto.open(ab.key, sealed, mailbox: 'other'), isNull);
    final bad = Uint8List.fromList(sealed)..[sealed.length - 1] ^= 1;
    expect(await FriendCrypto.open(ab.key, bad, mailbox: 'mbx'), isNull);
    expect(await FriendCrypto.open(ab.key, [1, 2, 3], mailbox: 'mbx'), isNull);
  });

  test('random mailboxes are 22 url-safe characters and never repeat', () {
    final x = FriendCrypto.randomMailbox();
    expect(x, matches(RegExp(r'^[A-Za-z0-9_-]{22}$')));
    expect(FriendCrypto.randomMailbox(), isNot(x));
  });

  group('pairing code', () {
    test('round-trips username, key and mailbox, and starts with WL1-', () {
      final mailbox = FriendCrypto.randomMailbox();
      final code = encodePairingCode(username: 'zed_sys', publicKey: a.publicBytes, mailbox: mailbox);
      expect(code, startsWith('WL1-'));
      final back = decodePairingCode(code);
      expect(back.username, 'zed_sys');
      expect(back.publicKey, a.publicBytes);
      expect(back.mailbox, mailbox);
    });
    test('forgives spaces and line breaks around the code', () {
      final code = encodePairingCode(username: 'zed', publicKey: a.publicBytes, mailbox: FriendCrypto.randomMailbox());
      expect(decodePairingCode('  $code\n').username, 'zed');
    });
    test('garbage gives a plain message', () {
      for (final bad in ['', 'hello', 'WL1-', 'WL1-!!!', 'WL2-abcd', 'WL1-${base64Url.encode(utf8.encode('{}'))}']) {
        expect(() => decodePairingCode(bad), throwsA(isA<FormatException>()), reason: bad);
      }
      try {
        decodePairingCode('nope');
      } on FormatException catch (e) {
        expect(e.message, contains('does not look right'));
      }
    });
    test('a wrong-size key or a bad username or mailbox is refused', () {
      String code(Map<String, Object> m) => 'WL1-${base64Url.encode(utf8.encode(jsonEncode(m)))}';
      final goodKey = base64Url.encode(a.publicBytes);
      final goodBox = FriendCrypto.randomMailbox();
      expect(() => decodePairingCode(code({'u': 'zed', 'k': base64Url.encode([1, 2]), 'm': goodBox})), throwsFormatException);
      expect(() => decodePairingCode(code({'u': 'x', 'k': goodKey, 'm': goodBox})), throwsFormatException);
      expect(() => decodePairingCode(code({'u': 'zed', 'k': goodKey, 'm': 'short'})), throwsFormatException);
    });
  });

  group('wire frame', () {
    test('round-trips with and without a sender key', () {
      final sealed = Uint8List.fromList([1, 2, 3, 4]);
      final plain = decodeFrame(encodeFrame(sealed: sealed))!;
      expect(plain.from, isNull);
      expect(plain.sealed, sealed);
      final hello = decodeFrame(encodeFrame(from: 'abcd', sealed: sealed))!;
      expect(hello.from, 'abcd');
      expect(hello.sealed, sealed);
    });
    test('garbage and wrong versions give null', () {
      expect(decodeFrame([1, 2, 3]), isNull);
      expect(decodeFrame(utf8.encode('[]')), isNull);
      expect(decodeFrame(utf8.encode('{"v":2,"b":"AQID"}')), isNull);
      expect(decodeFrame(utf8.encode('{"v":1}')), isNull);
      expect(decodeFrame(utf8.encode('{"v":1,"b":"!!!"}')), isNull);
    });
  });
}
