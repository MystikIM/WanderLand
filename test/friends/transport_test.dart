import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:plural_app/friends/transport.dart';
import '../helpers/friends_harness.dart';

Envelope env(String box, int b) => Envelope(box, Uint8List.fromList([b]));

void main() {
  test('OfflineTransport never delivers and says every send failed', () async {
    final t = OfflineTransport();
    await t.listenOn('x');
    expect(await t.send(env('x', 1)), isFalse);
    expect(await t.incoming.isEmpty, isTrue);
    await t.forget('x');
  });

  test('mail goes only to the phone listening on that mailbox', () async {
    final hub = MemoryHub();
    final a = hub.port();
    final b = hub.port();
    final got = <int>[];
    b.incoming.listen((e) => got.add(e.bytes.single));
    await b.listenOn('b-inbox');
    expect(await a.send(env('b-inbox', 7)), isTrue);
    expect(await a.send(env('nobody', 9)), isTrue); // waits at the relay
    expect(got, [7]);
  });

  test('mail waits at the relay until someone listens, then arrives in order', () async {
    final hub = MemoryHub();
    final a = hub.port();
    final b = hub.port();
    final got = <int>[];
    b.incoming.listen((e) => got.add(e.bytes.single));
    await a.send(env('later', 1));
    await a.send(env('later', 2));
    expect(got, isEmpty);
    await b.listenOn('later');
    expect(got, [1, 2]);
    expect(b.listening, {'later'});
  });

  test('an unreachable phone cannot send, and receives its waiting mail when it comes back', () async {
    final hub = MemoryHub();
    final a = hub.port();
    final b = hub.port();
    final got = <int>[];
    b.incoming.listen((e) => got.add(e.bytes.single));
    await b.listenOn('inbox');
    b.reachable = false;
    expect(await b.send(env('x', 1)), isFalse);
    await a.send(env('inbox', 5));
    expect(got, isEmpty);
    b.reachable = true;
    expect(got, [5]);
  });

  test('forget stops delivery to that phone, and the hub keeps a log of everything sent', () async {
    final hub = MemoryHub();
    final a = hub.port();
    final b = hub.port();
    final got = <int>[];
    b.incoming.listen((e) => got.add(e.bytes.single));
    await b.listenOn('inbox');
    await b.forget('inbox');
    await a.send(env('inbox', 3));
    expect(got, isEmpty);
    expect(hub.log.map((e) => e.bytes.single), [3]);
  });
}
