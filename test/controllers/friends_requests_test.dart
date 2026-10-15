import 'package:flutter_test/flutter_test.dart';
import 'package:plural_app/friends/friend_models.dart';
import '../helpers/friends_harness.dart';

void main() {
  late MemoryHub hub;
  late Phone a;
  late Phone b;
  setUp(() async {
    hub = MemoryHub();
    a = await Phone.on(hub, username: 'alpha');
    b = await Phone.on(hub, username: 'bravo');
  });

  test('a request shows up for the other person, and accepting makes them friends on both sides', () async {
    final code = await b.c.myCode();
    final sent = await a.c.addFromCode(code);
    expect(sent.state, FriendState.pendingOut);
    expect(sent.theirUsername, 'bravo');
    await settle([a, b]);

    expect(b.c.pendingRequests, hasLength(1));
    expect(b.c.pendingRequests.single.theirUsername, 'alpha');
    expect(b.c.pendingRequests.single.state, FriendState.pendingIn);
    expect(a.c.friends.single.state, FriendState.pendingOut);

    await b.c.acceptRequest(b.c.pendingRequests.single.id);
    await settle([a, b]);
    expect(b.c.friends.single.state, FriendState.friends);
    expect(a.c.friends.single.state, FriendState.friends);
    expect(b.c.pendingRequests, isEmpty);
  });

  test('both sides see the same safety number', () async {
    await befriend(a, b);
    expect(await a.c.safetyNumberFor(a.c.friends.single.id), await b.c.safetyNumberFor(b.c.friends.single.id));
  });

  test('friends and requests survive closing and opening the app', () async {
    await befriend(a, b);
    await a.restart();
    await b.restart();
    expect(a.c.friends.single.state, FriendState.friends);
    expect(b.c.friends.single.state, FriendState.friends);
    expect(a.transport.listening, contains(a.c.friends.single.inbox));
  });

  test('declining forgets the request quietly, and the asker is left waiting', () async {
    await a.c.addFromCode(await b.c.myCode());
    await settle([a, b]);
    await b.c.declineRequest(b.c.pendingRequests.single.id);
    await settle([a, b]);
    expect(b.c.friends, isEmpty);
    expect(a.c.friends.single.state, FriendState.pendingOut);
  });

  test('a code only works once', () async {
    final c = await Phone.on(hub, username: 'charlie');
    final code = await b.c.myCode();
    await a.c.addFromCode(code);
    await settle([a, b]);
    await c.c.addFromCode(code);
    await settle([a, b, c]);
    expect(b.c.pendingRequests.map((f) => f.theirUsername), ['alpha']);
  });

  test('REVIEW FOCUS: scanning your own code is refused', () async {
    final code = await a.c.myCode();
    expect(() => a.c.addFromCode(code), throwsA(isA<ArgumentError>().having((e) => e.message, 'message', contains('your own'))));
  });

  test('REVIEW FOCUS: garbage is refused with a plain message, and nothing is added', () async {
    expect(() => a.c.addFromCode('hello'), throwsA(isA<FormatException>()));
    expect(a.c.friends, isEmpty);
  });

  test('REVIEW FOCUS: the same friend twice is refused', () async {
    await a.c.addFromCode(await b.c.myCode());
    expect(() async => a.c.addFromCode(await b.c.myCode()), throwsA(isA<ArgumentError>()));
  });

  test('REVIEW FOCUS: two people adding each other at the same moment become friends', () async {
    final codeA = await a.c.myCode();
    final codeB = await b.c.myCode();
    // Both phones are offline while they scan, so the two requests truly cross in the post.
    a.transport.reachable = false;
    b.transport.reachable = false;
    await a.c.addFromCode(codeB);
    await b.c.addFromCode(codeA);
    a.transport.reachable = true;
    b.transport.reachable = true;
    await a.c.flush();
    await b.c.flush();
    await settle([a, b]);
    expect(a.c.friends.single.state, FriendState.friends);
    expect(b.c.friends.single.state, FriendState.friends);
    expect(a.c.pendingRequests, isEmpty);
    expect(b.c.pendingRequests, isEmpty);
  });

  test('RACE: a request arriving while I scan their code never makes two records for one person', () async {
    final codeA = await a.c.myCode();
    final codeB = await b.c.myCode();
    await a.c.addFromCode(codeB); // arrives at b before b has finished anything
    await expectLater(b.c.addFromCode(codeA), throwsA(isA<ArgumentError>()));
    await settle([a, b]);
    expect(b.c.friends, hasLength(1));
    expect(b.c.friends.single.state, FriendState.pendingIn);
    expect(a.c.friends, hasLength(1));
  });

  test('no more than five new requests are kept per day; the rest are dropped silently', () async {
    final senders = [for (var i = 0; i < 6; i++) await Phone.on(hub, username: 'sender$i')];
    for (final s in senders) {
      await s.c.addFromCode(await b.c.myCode());
      await settle([b, s]); // handled one at a time, so the limit itself is what stops the sixth
    }
    expect(b.c.pendingRequests, hasLength(5));
    expect(b.c.pendingRequests.map((f) => f.theirUsername), isNot(contains('sender5')));
  });

  test('the request limit is per rolling day, so tomorrow works again', () async {
    final senders = [for (var i = 0; i < 6; i++) await Phone.on(hub, username: 'sender$i')];
    for (final s in senders.take(5)) {
      await s.c.addFromCode(await b.c.myCode());
    }
    await settle([b, ...senders]);
    expect(b.c.pendingRequests, hasLength(5));
    b.now = b.now.add(const Duration(days: 1, minutes: 1));
    await senders.last.c.addFromCode(await b.c.myCode());
    await settle([b, ...senders]);
    expect(b.c.pendingRequests, hasLength(6));
  });

  test('a request made while the other phone is off arrives when it is back, and an offline asker retries with flush', () async {
    b.transport.reachable = false;
    final code = await b.c.myCode();
    a.transport.reachable = false;
    await a.c.addFromCode(code);
    expect(a.c.friends.single.state, FriendState.pendingOut);
    a.transport.reachable = true;
    await a.c.flush();
    await settle([a, b]);
    expect(b.c.pendingRequests, isEmpty); // b is still off
    b.transport.reachable = true;
    await settle([a, b]);
    expect(b.c.pendingRequests, hasLength(1));
  });
}
