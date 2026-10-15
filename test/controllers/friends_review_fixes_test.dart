import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plural_app/controllers/friends_controller.dart';
import 'package:plural_app/friends/friend_models.dart';
import 'package:plural_app/friends/secret_store.dart';
import 'package:plural_app/friends/transport.dart';
import '../helpers/friends_harness.dart';

class _BrokenSecrets implements SecretStore {
  @override
  Future<String?> read(String key) async => throw PlatformException(code: 'keystore', message: 'Keystore failed');
  @override
  Future<void> write(String key, String value) async {}
  @override
  Future<void> delete(String key) async {}
}

void main() {
  late MemoryHub hub;
  late Phone a;
  late Phone b;
  late String aFriend;
  late String bFriend;
  setUp(() async {
    hub = MemoryHub();
    a = await Phone.on(hub, username: 'alpha');
    b = await Phone.on(hub, username: 'bravo');
    await befriend(a, b);
    aFriend = a.c.friends.single.id;
    bFriend = b.c.friends.single.id;
  });

  group('C1: older waiting mail is never dropped because newer mail went first', () {
    test('a message that waited, then a newer one, arrive in order', () async {
      a.transport.reachable = false;
      await a.c.sendMessage(friendId: aFriend, text: 'one');
      a.transport.reachable = true;
      await a.c.sendMessage(friendId: aFriend, text: 'two');
      await a.c.flush();
      await settle([a, b]);
      expect(b.c.messagesWith(bFriend).map((m) => m.text), ['one', 'two']);
      expect(a.c.messagesWith(aFriend).map((m) => m.state), [DeliveryState.delivered, DeliveryState.delivered]);
    });

    test('an accept that waited does not get overtaken by a newer message', () async {
      final c = await Phone.on(hub, username: 'charlie');
      await c.c.addFromCode(await b.c.myCode());
      await settle([b, c]);
      b.transport.reachable = false;
      await b.c.acceptRequest(b.c.pendingRequests.single.id);
      b.transport.reachable = true;
      final cFriend = b.c.friends.firstWhere((f) => f.theirUsername == 'charlie').id;
      await b.c.sendMessage(friendId: cFriend, text: 'hi');
      await b.c.flush();
      await settle([b, c]);
      expect(c.c.friends.single.state, FriendState.friends);
      expect(c.c.messagesWith(c.c.friends.single.id).map((m) => m.text), ['hi']);
    });

    test('presence is not sent past mail that is still waiting', () async {
      a.transport.reachable = false;
      await a.c.sendMessage(friendId: aFriend, text: 'first');
      a.transport.reachable = true;
      await a.c.setShareFront(aFriend, true); // sends presence while 'first' still waits
      await a.c.flush();
      await settle([a, b]);
      expect(b.c.messagesWith(bFriend).map((m) => m.text), ['first']);
    });
  });

  group('I1: turning chat on or off, resetting and changing the name wait their turn on the queue', () {
    test('a code asked for right after turning chat off is refused, not half-made', () async {
      final off = a.c.setMode(ChatMode.off);
      final code = a.c.myCode();
      await off;
      await expectLater(code, throwsA(isA<StateError>()));
      expect(a.transport.listening, isEmpty);
    });

    test('a code asked for right after a reset is refused', () async {
      final r = a.c.reset();
      final code = a.c.myCode();
      await r;
      await expectLater(code, throwsA(isA<StateError>()));
      expect(a.c.friends, isEmpty);
      expect(await a.store.all('friends'), isEmpty);
    });

    test('a code made while chat is being switched on again keeps its mailbox', () async {
      final on = a.c.enable(username: 'newname', mode: ChatMode.always);
      final code = a.c.myCode();
      await on;
      final text = await code;
      expect(a.c.identity!.pairingMailboxes, hasLength(1));
      expect(text, startsWith('WL1-'));
      await a.restart();
      expect(a.c.identity!.pairingMailboxes, hasLength(1));
    });
  });

  group('I2: a little cannot switch chat on or off, rename it, or wipe it', () {
    test('reset, setMode, enable and setUsername all need a grown-up', () async {
      a.little = true;
      await expectLater(a.c.reset(), throwsA(isA<StateError>()));
      await expectLater(a.c.setMode(ChatMode.off), throwsA(isA<StateError>()));
      await expectLater(a.c.enable(username: 'other'), throwsA(isA<StateError>()));
      await expectLater(a.c.setUsername('other'), throwsA(isA<StateError>()));
      expect(a.c.friends, hasLength(1));
      expect(a.c.isOn, isTrue);
      expect(a.c.identity!.username, 'alpha');
      a.little = false;
      await a.c.setUsername('other');
      expect(a.c.identity!.username, 'other');
    });
  });

  group('I4: a secure-storage failure never stops the app from opening', () {
    test('load finishes, and using chat gives a plain message', () async {
      final c = FriendsController(
        store: a.store,
        secrets: _BrokenSecrets(),
        transport: OfflineTransport(),
        frontOut: () => const [],
        alterById: (_) => null,
        littleLocked: () => false,
      );
      await c.load(); // must not throw
      expect(c.identity!.username, 'alpha');
      await expectLater(
        c.myCode(),
        throwsA(isA<StateError>().having((e) => e.message, 'message', contains('chat key'))),
      );
    });
  });
}
