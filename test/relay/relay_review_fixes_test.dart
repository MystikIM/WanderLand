import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:wanderland_relay/mail_store.dart';
import 'package:wanderland_relay/relay_server.dart';

const boxA = 'aaaaaaaaaaaaaaaaaaaaaa';
const boxB = 'bbbbbbbbbbbbbbbbbbbbbb';

void main() {
  late Directory dir;
  setUp(() async => dir = await Directory.systemTemp.createTemp('relay_fix'));
  tearDown(() async {
    for (var i = 0; i < 20; i++) {
      try {
        if (await dir.exists()) await dir.delete(recursive: true);
        return;
      } on FileSystemException {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
    }
  });

  group('store', () {
    test('C3: mail that arrives while an empty mailbox is being tidied up is not deleted', () async {
      final store = MailStore(dir);
      await store.put(boxA, [1]);
      final first = (await store.peek([boxA])).single;
      await store.ack(boxA, first.id); // box is now empty
      store.onSweepBeforeRemove = (box) async {
        await store.put(box, [2]); // a friend sends exactly now
      };
      await store.sweep();
      expect((await store.peek([boxA])).single.bytes, [2]);
    });

    test('C2: tidying up never throws, even if the folder vanishes under it', () async {
      final store = MailStore(dir);
      await store.put(boxA, [1]);
      final first = (await store.peek([boxA])).single;
      await store.ack(boxA, first.id);
      store.onSweepBeforeRemove = (box) async => store.deleteMailbox(box); // removed by a friend at that moment
      await store.sweep(); // must not throw
    });

    test('I1: if the clock steps backwards, mail still comes out in the order it went in', () async {
      var t = DateTime(2026, 10, 15, 9, 0, 10);
      final store = MailStore(dir, now: () => t);
      await store.put(boxA, [1]);
      t = DateTime(2026, 10, 15, 9, 0, 9); // clock stepped back one second
      await store.put(boxA, [2]);
      final again = MailStore(dir, now: () => t); // also after a restart
      await again.put(boxA, [3]);
      expect((await again.peek([boxA])).map((i) => i.bytes.single), [1, 2, 3]);
    });
  });

  group('server', () {
    late RelayServer server;
    late HttpClient http;
    setUp(() => http = HttpClient());
    tearDown(() async {
      http.close(force: true);
      await server.close();
    });

    Future<(int, String)> call(String method, String path, {List<int>? body, Map<String, String>? headers}) async {
      final req = await http.openUrl(method, Uri.parse('http://127.0.0.1:${server.port}$path'));
      headers?.forEach(req.headers.set);
      if (body != null) req.add(body);
      final res = await req.close();
      return (res.statusCode, await utf8.decodeStream(res));
    }

    test('C4: one poll never returns more than the byte cap, but always makes progress', () async {
      server = RelayServer(MailStore(dir), maxPollBytes: 30);
      await server.start(port: 0);
      for (var i = 0; i < 5; i++) {
        await call('PUT', '/v1/m/$boxA', body: List.filled(10, i + 1));
      }
      final (_, text) = await call('POST', '/v1/poll', body: utf8.encode(jsonEncode({'m': [boxA]})));
      final items = (jsonDecode(text) as Map)['items'] as List;
      expect(items.length, inInclusiveRange(1, 3));
    });

    test('I6: one address cannot flood many mailboxes (address from the proxy header when told to trust it)', () async {
      server = RelayServer(MailStore(dir), putsPerMinutePerIp: 3, trustForwardedIp: true);
      await server.start(port: 0);
      Future<int> put(int i, String ip) async =>
          (await call('PUT', '/v1/m/${'m' * 21}$i', body: [1], headers: {'CF-Connecting-IP': ip})).$1;
      expect(await put(1, '1.1.1.1'), 204);
      expect(await put(2, '1.1.1.1'), 204);
      expect(await put(3, '1.1.1.1'), 204);
      expect(await put(4, '1.1.1.1'), 429);
      expect(await put(5, '2.2.2.2'), 204); // a different address is not affected
    });

    test('I6: without trusting the header, a spoofed header does not help', () async {
      server = RelayServer(MailStore(dir), putsPerMinutePerIp: 2);
      await server.start(port: 0);
      Future<int> put(int i, String ip) async =>
          (await call('PUT', '/v1/m/${'m' * 21}$i', body: [1], headers: {'CF-Connecting-IP': ip})).$1;
      expect(await put(1, '1.1.1.1'), 204);
      expect(await put(2, '2.2.2.2'), 204);
      expect(await put(3, '3.3.3.3'), 429);
    });
  });
}
