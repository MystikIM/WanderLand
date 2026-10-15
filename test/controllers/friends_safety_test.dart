import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:plural_app/domain/models.dart';
import 'package:plural_app/friends/friend_models.dart';
import '../helpers/friends_harness.dart';

Alter alter(String id, String name) => Alter(id: id, name: name, createdAt: DateTime(2026), colorValue: 0xFF123456);

void main() {
  late MemoryHub hub;
  late Phone a;
  late Phone b;
  late String aFriend;
  late String bFriend;
  setUp(() async {
    hub = MemoryHub();
    a = await Phone.on(hub, username: 'alpha', withAlters: [alter('a1', 'StarlightSecret')]);
    b = await Phone.on(hub, username: 'bravo');
    await befriend(a, b);
    aFriend = a.c.friends.single.id;
    bFriend = b.c.friends.single.id;
  });

  test('blocking stops their messages from showing, and they are not told', () async {
    await b.c.block(bFriend);
    expect(b.c.friends.single.state, FriendState.blocked);
    await a.c.sendMessage(friendId: aFriend, text: 'hello?');
    await settle([a, b]);
    expect(b.c.messagesWith(bFriend), isEmpty);
    expect(a.c.messagesWith(aFriend).single.state, DeliveryState.sent); // never delivered
  });

  test('blocking also stops me from sending to them, and clears what I knew of their front', () async {
    await a.c.setShareFront(aFriend, true);
    await b.c.setShareFront(bFriend, true);
    await settle([a, b]);
    expect(a.c.friends.single.theirFront, isNotNull);
    await a.c.block(aFriend);
    expect(a.c.friends.single.theirFront, isNull);
    expect(() => a.c.sendMessage(friendId: aFriend, text: 'hi'), throwsA(isA<StateError>()));
  });

  test('removing a friend on both sides allows a clean fresh start', () async {
    await a.c.sendMessage(friendId: aFriend, text: 'old chat');
    await settle([a, b]);
    await b.c.removeFriend(bFriend);
    await a.c.removeFriend(aFriend);
    expect(b.c.friends, isEmpty);
    expect(b.c.messagesWith(bFriend), isEmpty);
    expect(a.c.friends, isEmpty);
    await befriend(a, b);
    expect(a.c.friends.single.state, FriendState.friends);
    expect(b.c.friends.single.state, FriendState.friends);
    expect(b.c.messagesWith(b.c.friends.single.id), isEmpty);
    await a.c.sendMessage(friendId: a.c.friends.single.id, text: 'new chat');
    await settle([a, b]);
    expect(b.c.messagesWith(b.c.friends.single.id).single.text, 'new chat');
  });

  test('a blocked person shown as a new code is refused with a plain message', () async {
    await b.c.block(bFriend);
    final aCode = await a.c.myCode();
    expect(() => b.c.addFromCode(aCode),
        throwsA(isA<ArgumentError>().having((e) => e.message, 'message', contains('blocked'))));
  });

  test('removing a friend wipes the chat, the waiting mail and the mailbox', () async {
    a.transport.reachable = false;
    await a.c.sendMessage(friendId: aFriend, text: 'waiting');
    final inbox = a.c.friends.single.inbox;
    await a.c.removeFriend(aFriend);
    expect(a.c.messagesWith(aFriend), isEmpty);
    expect(await a.store.all('friend_messages'), isEmpty);
    expect(await a.store.all('friend_outbox'), isEmpty);
    expect(a.transport.listening, isNot(contains(inbox)));
  });

  test('littles: can chat with a friend a grown-up marked okay, but not with the others', () async {
    a.little = true;
    await expectLater(
        () => a.c.sendMessage(friendId: aFriend, text: 'hi'),
        throwsA(isA<StateError>().having((e) => e.message, 'message', contains('grown-up'))));
    a.little = false;
    await a.c.setLittleOk(aFriend, true);
    a.little = true;
    await a.c.sendMessage(friendId: aFriend, text: 'hi from a little');
    await settle([a, b]);
    expect(b.c.messagesWith(bFriend).single.text, 'hi from a little');
    expect(a.c.messagesWith(aFriend).single.state, DeliveryState.delivered);
  });

  test('littles: cannot add friends, accept requests or remove friends; mail still arrives; reading and blocking stay open', () async {
    final c = await Phone.on(hub, username: 'charlie');
    await c.c.addFromCode(await a.c.myCode());
    await settle([a, c]);
    a.little = true;
    await expectLater(() => a.c.addFromCode('WL1-whatever'), throwsA(isA<StateError>()));
    await expectLater(() => a.c.acceptRequest(a.c.pendingRequests.single.id), throwsA(isA<StateError>()));
    await expectLater(() => a.c.removeFriend(aFriend), throwsA(isA<StateError>()));
    expect(a.c.friends.any((f) => f.id == aFriend), isTrue);

    await b.c.sendMessage(friendId: bFriend, text: 'still arrives');
    await settle([a, b]);
    expect(a.c.messagesWith(aFriend).single.text, 'still arrives'); // a little can read it

    await a.c.block(aFriend); // a little can always block someone who bothers them
    expect(a.c.friends.firstWhere((f) => f.id == aFriend).state, FriendState.blocked);

    a.little = false;
    await a.c.acceptRequest(a.c.pendingRequests.single.id);
    expect(a.c.pendingRequests, isEmpty);
  });

  test('littles: with the little guard switched off in settings, nothing is held back', () async {
    a.little = false; // the app reports "not locked" when the guard setting is off
    await a.c.sendMessage(friendId: aFriend, text: 'no limits');
    await a.c.removeFriend(aFriend);
    expect(a.c.friends, isEmpty);
  });

  test('PRIVACY: nothing readable ever reaches the network', () async {
    await a.c.setShareFront(aFriend, true);
    await a.c.setAllowedAlters(aFriend, ['a1']);
    a.outIds = ['a1'];
    await a.c.publishFront();
    await a.c.sendMessage(friendId: aFriend, text: 'my private hello', asAlterId: 'a1');
    await b.c.sendMessage(friendId: bFriend, text: 'private reply');
    await settle([a, b]);
    final everything = hub.log.map((e) => '${e.mailbox}|${latin1.decode(e.bytes)}').join('\n');
    for (final secret in ['alpha', 'bravo', 'StarlightSecret', 'my private hello', 'private reply']) {
      expect(everything, isNot(contains(secret)), reason: '"$secret" leaked');
    }
    expect(hub.log, isNotEmpty);
  });
}
