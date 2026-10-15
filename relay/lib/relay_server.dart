import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'mail_store.dart';

class _Waiter {
  _Waiter(this.boxes) : done = Completer<void>();
  final Set<String> boxes;
  final Completer<void> done;
}

/// The whole relay: a few HTTP calls on top of [MailStore]. It never looks inside a message.
class RelayServer {
  RelayServer(
    this.store, {
    this.putsPerMinute = 60,
    this.pollMaxWait = const Duration(seconds: 25),
    this.maxPollMailboxes = 256,
    Now? now,
  }) : _now = now ?? DateTime.now;

  final MailStore store;
  final int putsPerMinute;
  final Duration pollMaxWait;
  final int maxPollMailboxes;
  final Now _now;

  HttpServer? _http;
  final Map<String, List<DateTime>> _recentPuts = {};
  final Set<_Waiter> _waiters = {};

  int get port => _http!.port;

  Future<void> start({InternetAddress? address, int port = 8787}) async {
    final http = await HttpServer.bind(address ?? InternetAddress.loopbackIPv4, port);
    _http = http;
    http.listen(_handle);
  }

  Future<void> close() async {
    for (final w in _waiters.toList()) {
      if (!w.done.isCompleted) w.done.complete();
    }
    final http = _http;
    _http = null;
    await http?.close(force: true);
  }

  Future<void> _reply(HttpRequest req, int status, {String? text, Object? json, int? retryAfter}) async {
    final res = req.response..statusCode = status;
    if (retryAfter != null) res.headers.set('Retry-After', '$retryAfter');
    if (json != null) {
      res.headers.contentType = ContentType.json;
      res.write(jsonEncode(json));
    } else if (text != null) {
      res.headers.contentType = ContentType.text;
      res.write(text);
    }
    await res.close();
  }

  /// Null when the body is bigger than [max].
  Future<List<int>?> _readBody(HttpRequest req, int max) async {
    // Keep reading (and throw the excess away) so the "too big" reply can get out; only a
    // body over 1 MB is cut off hard.
    final out = <int>[];
    var seen = 0;
    await for (final chunk in req) {
      seen += chunk.length;
      if (seen > 1024 * 1024) return null;
      if (seen <= max) out.addAll(chunk);
    }
    return seen > max ? null : out;
  }

  static final RegExp _mailboxPath = RegExp(r'^/v1/m/([^/]+)$');

  Future<void> _handle(HttpRequest req) async {
    try {
      final path = req.uri.path;
      if (req.method == 'GET' && path == '/v1/health') return await _reply(req, 200, text: 'ok');
      final m = _mailboxPath.firstMatch(path);
      if (m != null && (req.method == 'PUT' || req.method == 'DELETE')) {
        final box = m.group(1)!;
        if (!mailboxPattern.hasMatch(box)) return await _reply(req, 400, text: 'bad mailbox');
        if (req.method == 'PUT') return await _put(req, box);
        await store.deleteMailbox(box);
        return await _reply(req, 204);
      }
      if (req.method == 'POST' && path == '/v1/poll') return await _poll(req);
      if (req.method == 'POST' && path == '/v1/ack') return await _ack(req);
      await _reply(req, 404, text: 'not found');
    } catch (_) {
      try {
        await _reply(req, 500, text: 'error');
      } catch (_) {
        // the other side hung up
      }
    }
  }

  Future<void> _put(HttpRequest req, String box) async {
    final body = await _readBody(req, store.maxFrameBytes);
    if (body == null) return _reply(req, 413, text: 'too big');
    if (body.isEmpty) return _reply(req, 400, text: 'empty');
    final now = _now();
    if (_recentPuts.length > 20000) _recentPuts.clear();
    final recent = (_recentPuts[box] ??= [])..removeWhere((t) => now.difference(t) > const Duration(minutes: 1));
    if (recent.length >= putsPerMinute) return _reply(req, 429, text: 'slow down', retryAfter: 30);
    switch (await store.put(box, body)) {
      case PutResult.tooBig:
        return _reply(req, 413, text: 'too big');
      case PutResult.full:
        return _reply(req, 429, text: 'full', retryAfter: 60);
      case PutResult.ok:
        recent.add(now);
        _wake(box);
        return _reply(req, 204);
    }
  }

  void _wake(String box) {
    for (final w in _waiters.toList()) {
      if (w.boxes.contains(box) && !w.done.isCompleted) w.done.complete();
    }
  }

  Future<void> _poll(HttpRequest req) async {
    final body = await _readBody(req, 64 * 1024);
    if (body == null) return _reply(req, 413, text: 'too big');
    final List<String> boxes;
    final int wait;
    try {
      final j = jsonDecode(utf8.decode(body)) as Map;
      boxes = [for (final x in (j['m'] as List)) x as String];
      wait = ((j['wait'] as num?) ?? 0).toInt();
    } catch (_) {
      return _reply(req, 400, text: 'bad request');
    }
    if (boxes.isEmpty || boxes.length > maxPollMailboxes || boxes.any((b) => !mailboxPattern.hasMatch(b))) {
      return _reply(req, 400, text: 'bad mailboxes');
    }
    final waitFor = Duration(milliseconds: (wait * 1000).clamp(0, pollMaxWait.inMilliseconds));
    var items = await store.peek(boxes);
    if (items.isEmpty && waitFor > Duration.zero) {
      final w = _Waiter(boxes.toSet());
      _waiters.add(w);
      final timer = Timer(waitFor, () {
        if (!w.done.isCompleted) w.done.complete();
      });
      await w.done.future;
      timer.cancel();
      _waiters.remove(w);
      items = await store.peek(boxes);
    }
    await _reply(req, 200, json: {
      'items': [
        for (final i in items) {'m': i.mailbox, 'i': i.id, 'b': base64.encode(i.bytes)},
      ],
    });
  }

  Future<void> _ack(HttpRequest req) async {
    final body = await _readBody(req, 128 * 1024);
    if (body == null) return _reply(req, 413, text: 'too big');
    try {
      final j = jsonDecode(utf8.decode(body)) as Map;
      for (final x in (j['items'] as List)) {
        final item = x as Map;
        final box = item['m'] as String;
        final id = item['i'] as String;
        if (mailboxPattern.hasMatch(box)) await store.ack(box, id);
      }
    } catch (_) {
      return _reply(req, 400, text: 'bad request');
    }
    return _reply(req, 204);
  }
}
