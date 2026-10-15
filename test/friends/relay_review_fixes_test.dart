import 'dart:convert';
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
  RelayServer? server;
  HttpServer? fake;
  final made = <RelayTransport>[];

  RelayTransport make(Uri base, {Duration pollWait = const Duration(seconds: 1)}) {
    final t = RelayTransport(
      base,
      pollWait: pollWait,
      backoffMin: const Duration(milliseconds: 100),
      backoffMax: const Duration(milliseconds: 200),
      requestTimeout: const Duration(seconds: 3),
    );
    made.add(t);
    return t;
  }

  Future<Uri> bootReal({Duration pollMax = const Duration(seconds: 1)}) async {
    store = MailStore(dir);
    server = RelayServer(store, pollMaxWait: pollMax);
    await server!.start(port: 0);
    return Uri.parse('http://127.0.0.1:${server!.port}/');
  }

  /// A pretend relay that answers exactly as told, so failures can be forced.
  Future<Uri> bootFake(Future<void> Function(HttpRequest) handler) async {
    fake = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    fake!.listen(handler);
    return Uri.parse('http://127.0.0.1:${fake!.port}/');
  }

  Future<void> oneItemPollAndAck(HttpRequest req, int ackStatus, void Function() onPoll) async {
    await utf8.decodeStream(req);
    if (req.uri.path == '/v1/poll') {
      onPoll();
      req.response.headers.contentType = ContentType.json;
      req.response.write(jsonEncode({
        'items': [
          {'m': box(1), 'i': '0000000000000001-000000', 'b': base64.encode([1])},
        ],
      }));
    } else {
      req.response.statusCode = ackStatus;
    }
    await req.response.close();
  }

  setUp(() async => dir = await Directory.systemTemp.createTemp('relay_tfix'));
  tearDown(() async {
    for (final t in made) {
      await t.close();
    }
    made.clear();
    await server?.close();
    await fake?.close(force: true);
    server = null;
    fake = null;
    await deleteDirSoon(dir);
  });

  Envelope env(String mailbox, List<int> bytes) => Envelope(mailbox, Uint8List.fromList(bytes));

  test('C1: mail stays on the relay until the app says it has handled it, and is shown only once meanwhile', () async {
    final base = await bootReal();
    final a = make(base);
    final b = make(base);
    final got = <Envelope>[];
    b.incoming.listen(got.add);
    await b.listenOn(box(1));
    await a.send(env(box(1), [1]));
    await eventually(() async => got.length == 1);
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    expect(got, hasLength(1)); // not delivered a second time while unconfirmed
    expect(await store.peek([box(1)]), hasLength(1)); // still safe on the relay
    got.single.onHandled!(); // the app finished with it
    await eventually(() async => (await store.peek([box(1)])).isEmpty);
  });

  test('C1: waiting for the app to confirm does not make the phone poll in a tight loop', () async {
    var polls = 0;
    final base = await bootFake((req) => oneItemPollAndAck(req, 204, () => polls++));
    final b = make(base);
    b.incoming.listen((_) {}); // never confirms
    await b.listenOn(box(1));
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    expect(polls, lessThan(20));
  });

  test('I4: a failed acknowledge backs off instead of asking again at once', () async {
    var polls = 0;
    final base = await bootFake((req) => oneItemPollAndAck(req, 502, () => polls++));
    final b = make(base);
    b.incoming.listen((e) => e.onHandled?.call());
    await b.listenOn(box(1));
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    expect(polls, lessThan(20));
  });

  test('I8: only a "too big" answer counts as handled; any other 4xx means not sent', () async {
    final base = await bootFake((req) async {
      await req.drain<void>();
      req.response.statusCode = req.uri.path.endsWith(box(2)) ? 413 : 400;
      await req.response.close();
    });
    final a = make(base);
    expect(await a.send(env(box(1), [1])), isFalse);
    expect(await a.send(env(box(2), [1])), isTrue);
  });

  test('I3: dropping a mailbox this phone is not listening to does not touch the network', () async {
    final base = await bootReal();
    final a = make(base);
    await a.send(env(box(1), [1]));
    await a.drop(box(1)); // chat is off for this phone: nothing is listening
    expect(await store.peek([box(1)]), hasLength(1));
  });

  test('I7: a mailbox added during a long wait is picked up straight away', () async {
    final base = await bootReal(pollMax: const Duration(seconds: 5));
    final a = make(base, pollWait: const Duration(seconds: 5));
    final b = make(base, pollWait: const Duration(seconds: 5));
    final got = <int>[];
    b.incoming.listen((e) {
      got.add(e.bytes.single);
      e.onHandled?.call();
    });
    await b.listenOn(box(1));
    await Future<void>.delayed(const Duration(milliseconds: 300)); // a long wait is now in progress
    await a.send(env(box(2), [7]));
    final started = DateTime.now();
    await b.listenOn(box(2));
    await eventually(() async => got.contains(7));
    expect(DateTime.now().difference(started), lessThan(const Duration(milliseconds: 1500)));
  });
}
