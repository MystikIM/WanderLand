import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:plural_app/friends/friend_models.dart';
import 'package:wanderland_relay/mail_store.dart';
import 'package:wanderland_relay/relay_server.dart';
import '../helpers/friends_harness.dart';

void main() {
  late Directory dir;
  late RelayServer server;
  late Uri base;
  final phones = <RelayPhone>[];

  Future<void> boot({int? port}) async {
    server = RelayServer(MailStore(dir), pollMaxWait: const Duration(seconds: 1));
    await server.start(port: port ?? 0);
    base = Uri.parse('http://127.0.0.1:${server.port}/');
  }

  Future<RelayPhone> phone(String name) async {
    final p = await RelayPhone.on(base, username: name);
    phones.add(p);
    return p;
  }

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('relay_e2e');
    await boot();
  });
  tearDown(() async {
    for (final p in phones) {
      await p.close();
    }
    phones.clear();
    await server.close();
    await deleteDirSoon(dir);
  });

  Future<void> becomeFriends(RelayPhone asker, RelayPhone shower) async {
    await asker.c.addFromCode(await shower.c.myCode());
    await eventually(() async => shower.c.pendingRequests.length == 1);
    await shower.c.acceptRequest(shower.c.pendingRequests.single.id);
    await eventually(() async => asker.c.friends.single.state == FriendState.friends);
  }

  test('two phones become friends and chat over a real relay, and the sender sees delivered', () async {
    final a = await phone('alpha');
    final b = await phone('bravo');
    await becomeFriends(a, b);
    await a.c.sendMessage(friendId: a.c.friends.single.id, text: 'hello over the internet 💜');
    await eventually(() async => b.c.messagesWith(b.c.friends.single.id).length == 1);
    expect(b.c.messagesWith(b.c.friends.single.id).single.text, 'hello over the internet 💜');
    await eventually(() async => a.c.messagesWith(a.c.friends.single.id).single.state == DeliveryState.delivered);
    await b.c.sendMessage(friendId: b.c.friends.single.id, text: 'and back');
    await eventually(() async => a.c.messagesWith(a.c.friends.single.id).length == 2);
  });

  test('a message sent while the friend\'s app is closed waits at the relay and arrives when it opens', () async {
    final a = await phone('alpha');
    final b = await phone('bravo');
    await becomeFriends(a, b);
    await b.transport.close(); // b's app is closed
    await a.c.sendMessage(friendId: a.c.friends.single.id, text: 'are you there?');
    await eventually(() async => a.c.messagesWith(a.c.friends.single.id).single.state == DeliveryState.sent);
    expect(b.c.messagesWith(b.c.friends.single.id), isEmpty);
    await b.restart();
    await eventually(() async => b.c.messagesWith(b.c.friends.single.id).length == 1);
    await eventually(() async => a.c.messagesWith(a.c.friends.single.id).single.state == DeliveryState.delivered);
  });

  test('REVIEW FOCUS: the relay restarting loses no mail and the phones reconnect by themselves', () async {
    final a = await phone('alpha');
    final b = await phone('bravo');
    await becomeFriends(a, b);
    final port = server.port;
    await server.close();
    await a.c.sendMessage(friendId: a.c.friends.single.id, text: 'sent while the relay is down');
    expect(a.c.messagesWith(a.c.friends.single.id).single.state, DeliveryState.queued);
    await boot(port: port);
    await eventually(() async => b.c.messagesWith(b.c.friends.single.id).length == 1);
    await eventually(() async => a.c.messagesWith(a.c.friends.single.id).single.state == DeliveryState.delivered);
  });

  test('a blocked friend\'s mailbox is dropped on the relay and their mail never shows', () async {
    final a = await phone('alpha');
    final b = await phone('bravo');
    await becomeFriends(a, b);
    await b.c.block(b.c.friends.single.id);
    await a.c.sendMessage(friendId: a.c.friends.single.id, text: 'hello?');
    await Future<void>.delayed(const Duration(milliseconds: 600));
    expect(b.c.messagesWith(b.c.friends.single.id), isEmpty);
    expect(a.c.messagesWith(a.c.friends.single.id).single.state, isNot(DeliveryState.delivered));
  });

  test('nothing readable is ever stored on the relay', () async {
    final a = await phone('alpha');
    final b = await phone('bravo');
    await becomeFriends(a, b);
    await a.c.sendMessage(friendId: a.c.friends.single.id, text: 'my private words');
    await Future<void>.delayed(const Duration(milliseconds: 300));
    var all = '';
    await for (final e in dir.list(recursive: true)) {
      if (e is File) all += String.fromCharCodes(await e.readAsBytes());
    }
    for (final secret in ['alpha', 'bravo', 'my private words']) {
      expect(all, isNot(contains(secret)), reason: secret);
    }
  });
}
