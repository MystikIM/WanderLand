import 'package:flutter_test/flutter_test.dart';
import 'package:plural_app/friends/friend_models.dart';
import 'package:plural_app/friends/secret_store.dart';

void main() {
  group('usernameProblem', () {
    test('accepts 3 to 24 letters, numbers, underscore and dash', () {
      expect(usernameProblem('zed'), isNull);
      expect(usernameProblem('Joker_Wolf-9'), isNull);
      expect(usernameProblem('a' * 24), isNull);
      expect(usernameProblem('  trimmed  '), isNull);
    });
    test('rejects too short, too long, and other characters', () {
      expect(usernameProblem('ab'), contains('between 3 and 24'));
      expect(usernameProblem('a' * 25), contains('between 3 and 24'));
      expect(usernameProblem('has space'), contains('letters, numbers'));
      expect(usernameProblem('emoji💜x'), contains('letters, numbers'));
      expect(usernameProblem(''), isNotNull);
    });
  });

  test('ChatIdentity round-trips and an unknown mode falls back to whileOpen', () {
    final i = ChatIdentity(
      username: 'zed',
      publicKey: 'abc=',
      createdAt: DateTime(2026, 10, 15, 9),
      mode: ChatMode.always,
      pairingMailboxes: const ['m1', 'm2'],
    );
    final back = ChatIdentity.fromJson(i.toJson());
    expect(back.username, 'zed');
    expect(back.publicKey, 'abc=');
    expect(back.mode, ChatMode.always);
    expect(back.pairingMailboxes, ['m1', 'm2']);
    expect(back.createdAt, DateTime(2026, 10, 15, 9));
    expect(i.toJson()['id'], 'me');
    final odd = ChatIdentity.fromJson({...i.toJson(), 'mode': 'banana'});
    expect(odd.mode, ChatMode.whileOpen);
  });

  test('Friend round-trips every field', () {
    final f = Friend(
      id: 'f1',
      theirUsername: 'wolf',
      publicKey: 'pk',
      state: FriendState.friends,
      inbox: 'in',
      outbox: 'out',
      createdAt: DateTime(2026, 10, 15),
      nickname: 'Wolfie',
      muted: true,
      shareFront: true,
      allowedAlterIds: const ['a1'],
      littleOk: true,
      nextOut: 4,
      lastIn: 7,
      lastSeen: DateTime(2026, 10, 15, 10),
      theirFront: const TheirFront(alters: [TheirAlter('Star', 0xFF112233)], someoneOut: true),
    );
    final back = Friend.fromJson(f.toJson());
    expect(back.id, 'f1');
    expect(back.displayName, 'Wolfie');
    expect(back.state, FriendState.friends);
    expect(back.muted, isTrue);
    expect(back.shareFront, isTrue);
    expect(back.allowedAlterIds, ['a1']);
    expect(back.littleOk, isTrue);
    expect(back.nextOut, 4);
    expect(back.lastIn, 7);
    expect(back.lastSeen, DateTime(2026, 10, 15, 10));
    expect(back.theirFront!.alters.single.name, 'Star');
    expect(back.theirFront!.alters.single.colorValue, 0xFF112233);
    expect(back.theirFront!.someoneOut, isTrue);
  });

  test('Friend defaults are the private ones, and displayName falls back to their username', () {
    final f = Friend(
      id: 'f2', theirUsername: 'wolf', publicKey: 'pk', state: FriendState.pendingIn,
      inbox: 'i', outbox: 'o', createdAt: DateTime(2026),
    );
    expect(f.shareFront, isFalse);
    expect(f.allowedAlterIds, isEmpty);
    expect(f.littleOk, isFalse);
    expect(f.muted, isFalse);
    expect(f.nextOut, 1);
    expect(f.lastIn, 0);
    expect(f.theirFront, isNull);
    expect(f.displayName, 'wolf');
  });

  test('an unknown friend state becomes blocked, the safest reading', () {
    final f = Friend.fromJson({
      'id': 'f3', 'theirUsername': 'x', 'publicKey': 'pk', 'state': 'weird',
      'inbox': 'i', 'outbox': 'o', 'createdAt': DateTime(2026).toIso8601String(),
    });
    expect(f.state, FriendState.blocked);
  });

  test('copyWith can clear their front', () {
    final f = Friend(
      id: 'f4', theirUsername: 'x', publicKey: 'pk', state: FriendState.friends,
      inbox: 'i', outbox: 'o', createdAt: DateTime(2026),
      theirFront: const TheirFront(alters: [], someoneOut: true),
    );
    expect(f.copyWith(clearFront: true).theirFront, isNull);
    expect(f.copyWith(nickname: 'N').theirFront, isNotNull);
  });

  test('FriendMessage round-trips and keeps the speaker', () {
    final m = FriendMessage(
      id: 'm1', friendId: 'f1', outgoing: true, text: 'hi 💜',
      createdAt: DateTime(2026, 10, 15, 9), state: DeliveryState.sent,
      speakerName: 'Star', speakerColor: 0xFF445566,
    );
    final back = FriendMessage.fromJson(m.toJson());
    expect(back.text, 'hi 💜');
    expect(back.outgoing, isTrue);
    expect(back.state, DeliveryState.sent);
    expect(back.speakerName, 'Star');
    expect(back.speakerColor, 0xFF445566);
    expect(m.copyWith(state: DeliveryState.delivered).state, DeliveryState.delivered);
  });

  test('the four chat collections are the private ones', () {
    expect(kPrivateCollections, {'chat_identity', 'friends', 'friend_messages', 'friend_outbox'});
  });

  test('MemorySecretStore reads, writes and deletes', () async {
    final s = MemorySecretStore();
    expect(await s.read('k'), isNull);
    await s.write('k', 'v');
    expect(await s.read('k'), 'v');
    await s.delete('k');
    expect(await s.read('k'), isNull);
  });
}
