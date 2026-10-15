import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:wanderland_relay/mail_store.dart';
import 'package:wanderland_relay/relay_server.dart';

const boxA = 'aaaaaaaaaaaaaaaaaaaaaa';
const boxB = 'bbbbbbbbbbbbbbbbbbbbbb';

void main() {
  late Directory dir;
  late MailStore store;
  late RelayServer server;
  late HttpClient http;

  Future<void> boot({int putsPerMinute = 60, int maxFrame = 1024, int maxPerMailbox = 200}) async {
    store = MailStore(dir, maxFrameBytes: maxFrame, maxPerMailbox: maxPerMailbox);
    server = RelayServer(store, putsPerMinute: putsPerMinute, pollMaxWait: const Duration(seconds: 1));
    await server.start(port: 0);
  }

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('relay_server');
    http = HttpClient();
    await boot();
  });
  tearDown(() async {
    http.close(force: true);
    await server.close();
    await dir.delete(recursive: true);
  });

  Uri url(String path) => Uri.parse('http://127.0.0.1:${server.port}$path');

  Future<(int, String)> call(String method, String path, {List<int>? body}) async {
    final req = await http.openUrl(method, url(path));
    if (body != null) req.add(body);
    final res = await req.close();
    final text = await utf8.decodeStream(res);
    return (res.statusCode, text);
  }

  Future<(int, Map<String, dynamic>?)> poll(List<String> boxes, {int wait = 0}) async {
    final (code, text) = await call('POST', '/v1/poll', body: utf8.encode(jsonEncode({'m': boxes, 'wait': wait})));
    return (code, code == 200 ? jsonDecode(text) as Map<String, dynamic> : null);
  }

  test('health answers ok', () async {
    expect(await call('GET', '/v1/health'), (200, 'ok'));
  });

  test('a message put in a mailbox comes back from a poll, as the same bytes', () async {
    expect((await call('PUT', '/v1/m/$boxA', body: [1, 2, 3])).$1, 204);
    final (code, json) = await poll([boxA]);
    expect(code, 200);
    final item = (json!['items'] as List).single as Map;
    expect(item['m'], boxA);
    expect(base64.decode(item['b'] as String), [1, 2, 3]);
  });

  test('mail stays until acknowledged, then goes', () async {
    await call('PUT', '/v1/m/$boxA', body: [7]);
    final (_, first) = await poll([boxA]);
    final item = (first!['items'] as List).single as Map;
    expect(((await poll([boxA])).$2!['items'] as List), hasLength(1)); // still there
    final ack = await call('POST', '/v1/ack', body: utf8.encode(jsonEncode({'items': [{'m': boxA, 'i': item['i']}]})));
    expect(ack.$1, 204);
    expect(((await poll([boxA])).$2!['items'] as List), isEmpty);
  });

  test('a poll with nothing waiting returns an empty list after the wait', () async {
    final started = DateTime.now();
    final (code, json) = await poll([boxA], wait: 1);
    expect(code, 200);
    expect(json!['items'], isEmpty);
    expect(DateTime.now().difference(started), greaterThan(const Duration(milliseconds: 800)));
  });

  test('a waiting poll is woken the moment mail arrives', () async {
    final started = DateTime.now();
    final waiting = poll([boxA, boxB], wait: 1);
    await Future<void>.delayed(const Duration(milliseconds: 150));
    await call('PUT', '/v1/m/$boxB', body: [5]);
    final (_, json) = await waiting;
    expect((json!['items'] as List).single['m'], boxB);
    expect(DateTime.now().difference(started), lessThan(const Duration(milliseconds: 800)));
  });

  test('DELETE drops a mailbox and everything in it', () async {
    await call('PUT', '/v1/m/$boxA', body: [1]);
    expect((await call('DELETE', '/v1/m/$boxA')).$1, 204);
    expect(((await poll([boxA])).$2!['items'] as List), isEmpty);
  });

  test('too big is 413, an empty body or a bad mailbox is 400, unknown paths are 404', () async {
    expect((await call('PUT', '/v1/m/$boxA', body: List.filled(1025, 0))).$1, 413);
    expect((await call('PUT', '/v1/m/$boxA', body: [])).$1, 400);
    expect((await call('PUT', '/v1/m/short', body: [1])).$1, 400);
    expect((await call('PUT', '/v1/m/..%2F..%2Fetc%2Fpasswd', body: [1])).$1, 400);
    expect((await call('GET', '/nope')).$1, 404);
    expect((await call('PATCH', '/v1/m/$boxA')).$1, 404);
  });

  test('REVIEW FOCUS: broken or silly poll and ack bodies are refused, never crash the server', () async {
    expect((await call('POST', '/v1/poll', body: utf8.encode('not json'))).$1, 400);
    expect((await call('POST', '/v1/poll', body: utf8.encode('{"m":"x"}'))).$1, 400);
    expect((await call('POST', '/v1/poll', body: utf8.encode('{"m":[]}'))).$1, 400);
    expect((await call('POST', '/v1/poll', body: utf8.encode('{"m":["../x"]}'))).$1, 400);
    final tooMany = [for (var i = 0; i < 257; i++) '${'m' * 21}${i.toString().padLeft(3, '0')}'];
    expect((await call('POST', '/v1/poll', body: utf8.encode(jsonEncode({'m': tooMany})))).$1, 400);
    expect((await call('POST', '/v1/ack', body: utf8.encode('{"items":"x"}'))).$1, 400);
    expect((await call('GET', '/v1/health')).$1, 200); // still alive
  });

  test('REVIEW FOCUS: acknowledging mail that is already gone, or with a silly id, is fine', () async {
    final body = utf8.encode(jsonEncode({'items': [{'m': boxA, 'i': '0000000000000000-000000'}, {'m': boxA, 'i': '../../x'}]}));
    expect((await call('POST', '/v1/ack', body: body)).$1, 204);
  });

  test('REVIEW FOCUS: two polls for the same mailbox at once both get the mail and nothing is lost', () async {
    await call('PUT', '/v1/m/$boxA', body: [4]);
    final both = await Future.wait([poll([boxA]), poll([boxA])]);
    for (final r in both) {
      expect((r.$2!['items'] as List), hasLength(1));
    }
    expect(((await poll([boxA])).$2!['items'] as List), hasLength(1)); // still there until acked
  });

  test('a busy mailbox is told to slow down, and a full one too', () async {
    await server.close();
    await boot(putsPerMinute: 2, maxPerMailbox: 3);
    expect((await call('PUT', '/v1/m/$boxA', body: [1])).$1, 204);
    expect((await call('PUT', '/v1/m/$boxA', body: [2])).$1, 204);
    expect((await call('PUT', '/v1/m/$boxA', body: [3])).$1, 429);
    await server.close();
    await boot(maxPerMailbox: 1);
    expect((await call('PUT', '/v1/m/$boxB', body: [1])).$1, 204);
    expect((await call('PUT', '/v1/m/$boxB', body: [2])).$1, 429);
  });

  test('REVIEW FOCUS: shutting the server down releases a poll that is waiting', () async {
    final waiting = poll([boxA], wait: 1);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    final closing = server.close();
    await closing.timeout(const Duration(seconds: 3));
    await waiting.then((_) {}, onError: (_) {}).timeout(const Duration(seconds: 3));
  });
}
