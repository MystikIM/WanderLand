import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:plural_app/controllers/friends_controller.dart';
import 'package:plural_app/friends/friend_crypto.dart';
import 'package:plural_app/friends/friend_models.dart';
import '../helpers/friends_harness.dart';

void main() {
  late MemoryHub hub;
  setUp(() => hub = MemoryHub());

  test('a fresh phone has chat off: no identity, nothing listened to', () async {
    final p = Phone(hub);
    await p.c.load();
    expect(p.c.identity, isNull);
    expect(p.c.isOn, isFalse);
    expect(p.transport.listening, isEmpty);
    expect(await p.secrets.read(FriendsController.secretKeyName), isNull);
  });

  test('enable checks the username, makes a key, and keeps it in the secret store only', () async {
    final p = Phone(hub);
    await p.c.load();
    expect(() => p.c.enable(username: 'ab'), throwsA(isA<ArgumentError>()));
    expect(() => p.c.enable(username: 'has space'), throwsA(isA<ArgumentError>()));
    await p.c.enable(username: '  Zed_1 ');
    expect(p.c.isOn, isTrue);
    expect(p.c.identity!.username, 'Zed_1');
    expect(base64.decode(p.c.identity!.publicKey).length, 32);
    final secret = await p.secrets.read(FriendsController.secretKeyName);
    expect(base64.decode(secret!).length, 32);
    final stored = jsonEncode(await p.store.exportAll());
    expect(stored, isNot(contains(secret)), reason: 'the secret key must never reach the database');
  });

  test('turning chat on again keeps the same key', () async {
    final p = await Phone.on(hub);
    final key = p.c.identity!.publicKey;
    await p.c.enable(username: 'newname', mode: ChatMode.always);
    expect(p.c.identity!.publicKey, key);
    expect(p.c.identity!.username, 'newname');
    expect(p.c.identity!.mode, ChatMode.always);
  });

  test('the identity survives closing and opening the app', () async {
    final p = await Phone.on(hub, username: 'zed');
    final key = p.c.identity!.publicKey;
    await p.restart();
    expect(p.c.identity!.username, 'zed');
    expect(p.c.identity!.publicKey, key);
    expect(p.c.isOn, isTrue);
  });

  test('setMode off stops listening, and turning it back on listens again', () async {
    final p = await Phone.on(hub);
    await p.c.myCode();
    expect(p.transport.listening, hasLength(1));
    await p.c.setMode(ChatMode.off);
    expect(p.c.isOn, isFalse);
    expect(p.transport.listening, isEmpty);
    await p.c.setMode(ChatMode.always);
    expect(p.c.isOn, isTrue);
    expect(p.transport.listening, hasLength(1));
  });

  test('setUsername validates and saves', () async {
    final p = await Phone.on(hub);
    expect(() => p.c.setUsername('x'), throwsA(isA<ArgumentError>()));
    await p.c.setUsername('wolfie');
    await p.restart();
    expect(p.c.identity!.username, 'wolfie');
  });

  test('myCode needs chat on, then gives a code with my name and key and a fresh mailbox each time', () async {
    final off = Phone(hub);
    await off.c.load();
    expect(off.c.myCode(), throwsA(isA<StateError>()));

    final p = await Phone.on(hub, username: 'zed');
    final one = decodePairingCode(await p.c.myCode());
    final two = decodePairingCode(await p.c.myCode());
    expect(one.username, 'zed');
    expect(base64.encode(one.publicKey), p.c.identity!.publicKey);
    expect(one.mailbox, isNot(two.mailbox));
    expect(p.transport.listening, containsAll([one.mailbox, two.mailbox]));
  });

  test('only the five newest pairing mailboxes are kept, older ones are let go', () async {
    final p = await Phone.on(hub);
    final boxes = <String>[];
    for (var i = 0; i < 7; i++) {
      boxes.add(decodePairingCode(await p.c.myCode()).mailbox);
    }
    expect(p.c.identity!.pairingMailboxes, boxes.sublist(2));
    expect(p.transport.listening, boxes.sublist(2).toSet());
  });

  test('reset wipes identity, friends, messages and the secret key', () async {
    final p = await Phone.on(hub);
    await p.c.myCode();
    await p.c.reset();
    expect(p.c.identity, isNull);
    expect(p.c.friends, isEmpty);
    expect(await p.secrets.read(FriendsController.secretKeyName), isNull);
    expect(await p.store.all(FriendsController.identityCollection), isEmpty);
    expect(p.transport.listening, isEmpty);
  });

  test('REVIEW FOCUS: identity present but the secret key gone gives a plain error, never a silent new key', () async {
    final p = await Phone.on(hub);
    final key = p.c.identity!.publicKey;
    await p.secrets.delete(FriendsController.secretKeyName);
    await p.restart();
    await expectLater(
      p.c.myCode(),
      throwsA(isA<StateError>().having((e) => e.message, 'message', FriendsController.keyMissing)),
    );
    await expectLater(p.c.enable(username: 'zed'), throwsA(isA<StateError>()));
    expect(p.c.identity!.publicKey, key);
    expect(await p.secrets.read(FriendsController.secretKeyName), isNull);
  });
}
