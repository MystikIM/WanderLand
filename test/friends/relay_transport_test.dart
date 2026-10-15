import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:plural_app/friends/relay_transport.dart';
import 'package:plural_app/friends/transport.dart';
import 'package:wanderland_relay/mail_store.dart';
import 'package:wanderland_relay/relay_server.dart';
import '../helpers/friends_harness.dart';

String box(int i) => 'box${i.toString().padLeft(19, '0')}';

void main() {
  late Directory dir;
  late MailStore store;
  late RelayServer server;
  late Uri base;
  final made = <RelayTransport>[];

  Future<void> boot({int? port, int putsPerMinute = 60, int maxFrame = 32 * 1024}) async {
    store = MailStore(dir, maxFrameBytes: maxFrame);
    server = RelayServer(store, putsPerMinute: putsPerMinute, pollMaxWait: const Duration(seconds: 1));
    await server.start(port: port ?? 0);
    base = Uri.parse('http://127.0.0.1:${server.port}/');
  }

  RelayTransport make() {
    final t = RelayTransport(
      base,
      pollWait: const Duration(seconds: 1),
      backoffMin: const Duration(milliseconds: 50),
      backoffMax: const Duration(milliseconds: 200),
      requestTimeout: const Duration(seconds: 3),
    );
    made.add(t);
    return t;
  }

  Envelope env(String mailbox, List<int> bytes) => Envelope(mailbox, Uint8List.fromList(bytes));

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('relay_transport');
    await boot();
  });
  tearDown(() async {
    for (final t in made) {
      await t.close();
    }
    made.clear();
    await server.close();
    await deleteDirSoon(dir);
  });

  test('mail sent by one phone arrives at the phone listening, and is then removed from the relay', () async {
    final a = make();
    final b = make();
    final got = <Envelope>[];
    b.incoming.listen((e) { got.add(e); e.onHandled?.call(); });
    await b.listenOn(box(1));
    expect(await a.send(env(box(1), [1, 2, 3])), isTrue);
    await eventually(() async => got.length == 1);
    expect(got.single.mailbox, box(1));
    expect(got.single.bytes, [1, 2, 3]);
    await eventually(() async => (await store.peek([box(1)])).isEmpty);
  });

  test('mail waiting before anyone listens is delivered the moment they start, oldest first', () async {
    final a = make();
    final b = make();
    await a.send(env(box(1), [1]));
    await a.send(env(box(1), [2]));
    final got = <int>[];
    b.incoming.listen((e) { got.add(e.bytes.single); e.onHandled?.call(); });
    await b.listenOn(box(1));
    await eventually(() async => got.length == 2);
    expect(got, [1, 2]);
  });

  test('one phone can listen on many mailboxes at once, including the 100th', () async {
    final a = make();
    final b = make();
    final got = <String>[];
    b.incoming.listen((e) { got.add(e.mailbox); e.onHandled?.call(); });
    for (var i = 0; i < 100; i++) {
      await b.listenOn(box(i));
    }
    await a.send(env(box(99), [9]));
    await eventually(() async => got.contains(box(99)));
  });

  test('forget stops listening for that mailbox and leaves its mail on the relay', () async {
    final a = make();
    final b = make();
    final got = <Envelope>[];
    b.incoming.listen((e) { got.add(e); e.onHandled?.call(); });
    await b.listenOn(box(1));
    await b.forget(box(1));
    await a.send(env(box(1), [1]));
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    expect(got, isEmpty);
    expect(await store.peek([box(1)]), hasLength(1));
  });

  test('drop deletes the mailbox on the relay as well', () async {
    final a = make();
    await a.send(env(box(1), [1]));
    await a.listenOn(box(1)); // chat is on: the app is listening to this friend
    await a.drop(box(1));
    await eventually(() async => (await store.peek([box(1)])).isEmpty);
  });

  test('REVIEW FOCUS: mail that arrives for a mailbox just forgotten is acknowledged and dropped, never shown', () async {
    final a = make();
    final b = make();
    final got = <Envelope>[];
    b.incoming.listen((e) { got.add(e); e.onHandled?.call(); });
    await b.listenOn(box(1));
    await b.listenOn(box(2));
    await a.send(env(box(1), [1]));
    await eventually(() async => got.length == 1);
    await b.forget(box(2));
    await a.send(env(box(2), [2]));
    await a.send(env(box(1), [3]));
    await eventually(() async => got.length == 2);
    expect(got.map((e) => e.bytes.single), [1, 3]);
  });

  test('a busy relay says not sent, and a refused frame counts as handled so it cannot block the queue', () async {
    await server.close();
    await boot(putsPerMinute: 1, maxFrame: 10);
    final a = make();
    expect(await a.send(env(box(1), [1])), isTrue);
    expect(await a.send(env(box(1), [2])), isFalse); // 429: busy, try later
    expect(await a.send(env(box(2), List.filled(11, 0))), isTrue); // 413: can never succeed, so do not retry forever
    expect(await store.peek([box(2)]), isEmpty);
  });

  test('REVIEW FOCUS: relay down means not sent and offline; back up means it reconnects by itself and mail flows', () async {
    final a = make();
    final b = make();
    final got = <int>[];
    b.incoming.listen((e) { got.add(e.bytes.single); e.onHandled?.call(); });
    await b.listenOn(box(1));
    await eventually(() async => b.online);
    final port = server.port;
    await server.close();
    expect(await a.send(env(box(1), [1])), isFalse);
    await eventually(() async => !b.online);
    await boot(port: port); // same address, same mail folder
    expect(await a.send(env(box(1), [2])), isTrue);
    await eventually(() async => got.contains(2));
    await eventually(() async => b.online);
  });

  test('online changes are announced', () async {
    final b = make();
    final changes = <bool>[];
    b.onlineChanges.listen(changes.add);
    await b.listenOn(box(1));
    await eventually(() async => changes.contains(true));
    await server.close();
    await eventually(() async => changes.contains(false));
  });

  test('closing stops everything and later sends say not sent', () async {
    final a = make();
    await a.close();
    expect(await a.send(env(box(1), [1])), isFalse);
  });
}
