import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:plural_app/friends/friend_models.dart';
import '../../helpers/friends_harness.dart';

/// Talks to the REAL relay on the internet. Skipped unless you ask for it:
///   RELAY_SMOKE=1 flutter test test/ui/friends/live_relay_smoke_test.dart
/// Two pretend phones become friends, trade one message each way, then remove each other
/// (which also clears their mailboxes on the relay). Nothing of yours is touched.
void main() {
  final on = Platform.environment['RELAY_SMOKE'] == '1';
  final base = Uri.parse(Platform.environment['RELAY_URL'] ?? 'https://chat.mystikim.com/');

  test('two phones can become friends and chat through the real relay', () async {
    final a = await RelayPhone.on(base, username: 'smoke-a');
    final b = await RelayPhone.on(base, username: 'smoke-b');
    try {
      await a.c.addFromCode(await b.c.myCode());
      await eventually(() async => b.c.pendingRequests.length == 1, timeout: const Duration(seconds: 30));
      await b.c.acceptRequest(b.c.pendingRequests.single.id);
      await eventually(() async => a.c.friends.single.state == FriendState.friends, timeout: const Duration(seconds: 30));
      await a.c.sendMessage(friendId: a.c.friends.single.id, text: 'hello through the internet');
      await eventually(() async => b.c.messagesWith(b.c.friends.single.id).isNotEmpty, timeout: const Duration(seconds: 30));
      expect(b.c.messagesWith(b.c.friends.single.id).single.text, 'hello through the internet');
      await b.c.sendMessage(friendId: b.c.friends.single.id, text: 'and back again');
      await eventually(() async => a.c.messagesWith(a.c.friends.single.id).length == 2, timeout: const Duration(seconds: 30));
      await eventually(
        () async => a.c.messagesWith(a.c.friends.single.id).first.state == DeliveryState.delivered,
        timeout: const Duration(seconds: 30),
      );
    } finally {
      for (final p in [a, b]) {
        if (p.c.friends.isNotEmpty) await p.c.removeFriend(p.c.friends.first.id);
        await p.close();
      }
    }
  }, skip: on ? false : 'set RELAY_SMOKE=1 to run against the real relay', timeout: const Timeout(Duration(minutes: 2)));
}
