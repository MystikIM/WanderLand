import 'package:flutter_test/flutter_test.dart';
import 'package:plural_app/domain/models.dart';
import '../helpers/friends_harness.dart';

Alter alter(String id, String name, int color) =>
    Alter(id: id, name: name, createdAt: DateTime(2026), colorValue: color);

void main() {
  late MemoryHub hub;
  late Phone a;
  late Phone b;
  late String aFriend;
  late String bFriend;
  setUp(() async {
    hub = MemoryHub();
    a = await Phone.on(hub, username: 'alpha', withAlters: [
      alter('a1', 'Star', 0xFF111111),
      alter('a2', 'Shade', 0xFF222222),
    ]);
    b = await Phone.on(hub, username: 'bravo');
    await befriend(a, b);
    aFriend = a.c.friends.single.id;
    bFriend = b.c.friends.single.id;
    a.outIds = ['a1', 'a2'];
  });

  test('by default nothing about front is shared, even when it changes', () async {
    await a.c.publishFront();
    await settle([a, b]);
    expect(b.c.friends.single.theirFront, isNull);
  });

  test('turning sharing on with nobody ticked tells the friend only that someone is out', () async {
    await a.c.setShareFront(aFriend, true);
    await settle([a, b]);
    final seen = b.c.friends.single.theirFront!;
    expect(seen.alters, isEmpty);
    expect(seen.someoneOut, isTrue);
  });

  test('ticking an alter names only that alter, and the other stays someone', () async {
    await a.c.setShareFront(aFriend, true);
    await a.c.setAllowedAlters(aFriend, ['a1']);
    await settle([a, b]);
    final seen = b.c.friends.single.theirFront!;
    expect(seen.alters.map((x) => x.name), ['Star']);
    expect(seen.alters.single.colorValue, 0xFF111111);
    expect(seen.someoneOut, isTrue);
  });

  test('when the front changes, publishFront tells the friend', () async {
    await a.c.setShareFront(aFriend, true);
    await a.c.setAllowedAlters(aFriend, ['a1', 'a2']);
    await settle([a, b]);
    expect(b.c.friends.single.theirFront!.alters.map((x) => x.name), ['Star', 'Shade']);
    a.outIds = ['a2'];
    await a.c.publishFront();
    await settle([a, b]);
    expect(b.c.friends.single.theirFront!.alters.map((x) => x.name), ['Shade']);
    expect(b.c.friends.single.theirFront!.someoneOut, isFalse);
    a.outIds = [];
    await a.c.publishFront();
    await settle([a, b]);
    expect(b.c.friends.single.theirFront!.alters, isEmpty);
    expect(b.c.friends.single.theirFront!.someoneOut, isFalse);
  });

  test('turning sharing off clears what the friend sees', () async {
    await a.c.setShareFront(aFriend, true);
    await a.c.setAllowedAlters(aFriend, ['a1']);
    await settle([a, b]);
    expect(b.c.friends.single.theirFront, isNotNull);
    await a.c.setShareFront(aFriend, false);
    await settle([a, b]);
    expect(b.c.friends.single.theirFront, isNull);
  });

  test('sharing is per friend: a second friend who was not allowed sees nothing', () async {
    final c = await Phone.on(hub, username: 'charlie');
    await befriend(a, c);
    final cFriend = a.c.friends.firstWhere((f) => f.theirUsername == 'charlie').id;
    await a.c.setShareFront(aFriend, true);
    await a.c.setAllowedAlters(aFriend, ['a1', 'a2']);
    await settle([a, b, c]);
    expect(b.c.friends.single.theirFront!.alters, isNotEmpty);
    expect(c.c.friends.single.theirFront, isNull);
    expect(a.c.friends.firstWhere((f) => f.id == cFriend).shareFront, isFalse);
  });

  test('a ticked alter speaks under their name, an unticked one is just the username', () async {
    await a.c.setAllowedAlters(aFriend, ['a1']);
    await a.c.sendMessage(friendId: aFriend, text: 'as star', asAlterId: 'a1');
    await a.c.sendMessage(friendId: aFriend, text: 'as shade', asAlterId: 'a2');
    await a.c.sendMessage(friendId: aFriend, text: 'default speaker'); // first out is Star
    await settle([a, b]);
    final got = b.c.messagesWith(bFriend);
    expect(got.map((m) => m.speakerName), ['Star', null, 'Star']);
    expect(got.first.speakerColor, 0xFF111111);
  });

  test('settings are remembered, and a friend can get a nickname and be muted', () async {
    await a.c.setShareFront(aFriend, true);
    await a.c.setAllowedAlters(aFriend, ['a2']);
    await a.c.setNickname(aFriend, '  Bravo-bear  ');
    await a.c.setMuted(aFriend, true);
    await a.c.setLittleOk(aFriend, true);
    await a.restart();
    final f = a.c.friends.single;
    expect(f.shareFront, isTrue);
    expect(f.allowedAlterIds, ['a2']);
    expect(f.displayName, 'Bravo-bear');
    expect(f.muted, isTrue);
    expect(f.littleOk, isTrue);
  });

  test('while a little is out, only a grown-up can change sharing or the littles tick; muting stays open', () async {
    a.little = true;
    await expectLater(() => a.c.setShareFront(aFriend, true), throwsA(isA<StateError>()));
    await expectLater(() => a.c.setAllowedAlters(aFriend, ['a1']), throwsA(isA<StateError>()));
    await expectLater(() => a.c.setLittleOk(aFriend, true), throwsA(isA<StateError>()));
    await a.c.setMuted(aFriend, true);
    expect(a.c.friends.single.muted, isTrue);
    expect(a.c.friends.single.shareFront, isFalse);
    expect(a.c.friends.single.littleOk, isFalse);
    a.little = false;
    await a.c.setLittleOk(aFriend, true);
    expect(a.c.friends.single.littleOk, isTrue);
  });

  test('a friend never shows more than 12 named alters, and the rest count as someone', () async {
    final many = [for (var i = 0; i < 14; i++) alter('x$i', 'Alter$i', 0xFF000000 + i)];
    final crowd = await Phone.on(hub, username: 'crowd', withAlters: many);
    final quiet = await Phone.on(hub, username: 'quiet');
    await befriend(crowd, quiet);
    crowd.outIds = [for (final x in many) x.id];
    final id = crowd.c.friends.single.id;
    await crowd.c.setShareFront(id, true);
    await crowd.c.setAllowedAlters(id, crowd.outIds);
    await settle([crowd, quiet]);
    final seen = quiet.c.friends.single.theirFront!;
    expect(seen.alters, hasLength(12));
    expect(seen.someoneOut, isTrue);
  });
}
