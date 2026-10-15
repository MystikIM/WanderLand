import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:plural_app/controllers/friends_controller.dart';
import 'package:plural_app/friends/friend_models.dart';
import 'package:plural_app/friends/transport.dart';
import 'package:plural_app/friends/wire.dart';
import '../helpers/friends_harness.dart';

void main() {
  late MemoryHub hub;
  late Phone a;
  late Phone b;
  late String aFriend; // A's friend id for B
  late String bFriend;
  setUp(() async {
    hub = MemoryHub();
    a = await Phone.on(hub, username: 'alpha');
    b = await Phone.on(hub, username: 'bravo');
    await befriend(a, b);
    aFriend = a.c.friends.single.id;
    bFriend = b.c.friends.single.id;
  });

  test('a message arrives in order, is stored on both phones, and comes back as delivered', () async {
    await a.c.sendMessage(friendId: aFriend, text: '  hello there 💜  ');
    a.now = a.now.add(const Duration(minutes: 1));
    await a.c.sendMessage(friendId: aFriend, text: 'second');
    await settle([a, b]);

    final got = b.c.messagesWith(bFriend);
    expect(got.map((m) => m.text), ['hello there 💜', 'second']);
    expect(got.every((m) => !m.outgoing), isTrue);
    final sent = a.c.messagesWith(aFriend);
    expect(sent.every((m) => m.outgoing), isTrue);
    expect(sent.map((m) => m.state), [DeliveryState.delivered, DeliveryState.delivered]);
  });

  test('a message with no ticked alter goes out as just the username', () async {
    await a.c.sendMessage(friendId: aFriend, text: 'hi');
    await settle([a, b]);
    expect(b.c.messagesWith(bFriend).single.speakerName, isNull);
  });

  test('messages are kept after closing and opening the app', () async {
    await a.c.sendMessage(friendId: aFriend, text: 'keep me');
    await settle([a, b]);
    await a.restart();
    await b.restart();
    expect(a.c.messagesWith(a.c.friends.single.id).single.text, 'keep me');
    expect(b.c.messagesWith(b.c.friends.single.id).single.text, 'keep me');
  });

  test('empty, too long, to a non-friend, and while chat is off are all refused plainly', () async {
    expect(() => a.c.sendMessage(friendId: aFriend, text: '   '), throwsA(isA<ArgumentError>()));
    expect(() => a.c.sendMessage(friendId: aFriend, text: 'x' * 4001), throwsA(isA<ArgumentError>()));
    await a.c.sendMessage(friendId: aFriend, text: 'x' * 4000); // exactly the limit is fine
    expect(() => a.c.sendMessage(friendId: 'nope', text: 'hi'), throwsA(isA<StateError>()));
    await a.c.setMode(ChatMode.off);
    expect(() => a.c.sendMessage(friendId: aFriend, text: 'hi'), throwsA(isA<StateError>()));
  });

  test('while offline a message waits as queued, and flush hands it over when the connection is back', () async {
    a.transport.reachable = false;
    final m = await a.c.sendMessage(friendId: aFriend, text: 'later');
    expect(m.state, DeliveryState.queued);
    await a.c.flush(); // still offline: nothing changes
    expect(a.c.messagesWith(aFriend).single.state, DeliveryState.queued);
    expect(b.c.messagesWith(bFriend), isEmpty);

    a.transport.reachable = true;
    await a.c.flush();
    await settle([a, b]);
    expect(b.c.messagesWith(bFriend).single.text, 'later');
    expect(a.c.messagesWith(aFriend).single.state, DeliveryState.delivered);
  });

  test('queued mail keeps its order and the counters stay unbroken', () async {
    a.transport.reachable = false;
    for (final t in ['one', 'two', 'three']) {
      await a.c.sendMessage(friendId: aFriend, text: t);
    }
    a.transport.reachable = true;
    await a.c.flush();
    await settle([a, b]);
    expect(b.c.messagesWith(bFriend).map((m) => m.text), ['one', 'two', 'three']);
  });

  test('REVIEW FOCUS: the same frame delivered twice shows once', () async {
    await a.c.sendMessage(friendId: aFriend, text: 'only once');
    await settle([a, b]);
    final frame = hub.log.last; // the message, as it travelled
    await hub.deliver(Envelope(frame.mailbox, Uint8List.fromList(frame.bytes)));
    await settle([a, b]);
    expect(b.c.messagesWith(bFriend), hasLength(1));
  });

  test('REVIEW FOCUS: garbage, a tampered message and mail for an unknown mailbox are ignored without a crash', () async {
    await a.c.sendMessage(friendId: aFriend, text: 'real');
    await settle([a, b]);
    final inbox = b.c.friends.single.inbox;

    await hub.deliver(Envelope(inbox, Uint8List.fromList([1, 2, 3])));
    await hub.deliver(Envelope(inbox, encodeFrame(sealed: Uint8List.fromList(List.filled(60, 7)))));
    final real = decodeFrame(hub.log.firstWhere((e) => e.mailbox == inbox).bytes)!;
    final flipped = Uint8List.fromList(real.sealed)..[20] ^= 1;
    await hub.deliver(Envelope(inbox, encodeFrame(sealed: flipped)));
    await hub.deliver(Envelope('some-other-mailbox', encodeFrame(sealed: real.sealed)));
    await settle([a, b]);

    expect(b.c.messagesWith(bFriend).map((m) => m.text), ['real']);
    expect(b.c.friends.single.lastIn, greaterThan(0));
  });

  test('a long message round-trips whole, with emoji and line breaks', () async {
    final text = 'line one\nline two 💜🐺 ${'x' * 3000}';
    await a.c.sendMessage(friendId: aFriend, text: text);
    await settle([a, b]);
    expect(b.c.messagesWith(bFriend).single.text, text);
  });

  test('a sealed message never contains its words', () async {
    await a.c.sendMessage(friendId: aFriend, text: 'banana secret');
    final all = hub.log.map((e) => latin1.decode(e.bytes)).join();
    expect(all, isNot(contains('banana')));
    expect(all, isNot(contains('alpha')));
    expect(FriendsController.maxText, 4000);
  });
}
