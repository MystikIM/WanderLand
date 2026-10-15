import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'transport.dart';

/// Talks to a mailbox relay over HTTP. It only ever sends and receives sealed bytes.
/// One long-poll covers every mailbox this phone listens on.
class RelayTransport implements FriendTransport {
  RelayTransport(
    Uri base, {
    HttpClient? client,
    this.pollWait = const Duration(seconds: 25),
    this.backoffMin = const Duration(seconds: 2),
    this.backoffMax = const Duration(seconds: 60),
    this.requestTimeout = const Duration(seconds: 15),
  })  : base = base.path.endsWith('/') ? base : base.replace(path: '${base.path}/'),
        _client = client ?? HttpClient();

  final Uri base;
  final Duration pollWait;
  final Duration backoffMin;
  final Duration backoffMax;
  final Duration requestTimeout;
  final HttpClient _client;

  /// The relay accepts at most this many mailboxes in one poll.
  static const maxMailboxes = 256;

  final StreamController<Envelope> _incoming = StreamController<Envelope>.broadcast();
  final StreamController<bool> _onlineChanges = StreamController<bool>.broadcast();
  final Set<String> _listening = {};
  bool _running = false;
  bool _closed = false;
  bool _online = false;

  bool get online => _online;
  Stream<bool> get onlineChanges => _onlineChanges.stream;

  @override
  Stream<Envelope> get incoming => _incoming.stream;

  void _setOnline(bool v) {
    if (_online == v || _closed) return;
    _online = v;
    _onlineChanges.add(v);
  }

  @override
  Future<bool> send(Envelope e) async {
    if (_closed) return false;
    try {
      final req = await _client.putUrl(base.resolve('v1/m/${e.mailbox}')).timeout(requestTimeout);
      req.headers.contentType = ContentType.binary;
      req.add(e.bytes);
      final res = await req.close().timeout(requestTimeout);
      await res.drain<void>().timeout(requestTimeout);
      if (res.statusCode == 204) return true;
      // 400 and 413 will never succeed, so count them as handled instead of blocking the queue.
      return res.statusCode == 400 || res.statusCode == 413;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> listenOn(String mailbox) async {
    _listening.add(mailbox);
    if (!_running && !_closed) unawaited(_loop());
  }

  @override
  Future<void> forget(String mailbox) async {
    _listening.remove(mailbox);
  }

  @override
  Future<void> drop(String mailbox) async {
    _listening.remove(mailbox);
    if (_closed) return;
    try {
      final req = await _client.deleteUrl(base.resolve('v1/m/$mailbox')).timeout(requestTimeout);
      final res = await req.close().timeout(requestTimeout);
      await res.drain<void>().timeout(requestTimeout);
    } catch (_) {
      // best effort: the relay deletes old mail by itself after 7 days
    }
  }

  Future<void> close() async {
    _closed = true;
    _listening.clear();
    _client.close(force: true);
    await _incoming.close();
    await _onlineChanges.close();
  }

  Future<void> _loop() async {
    if (_running) return;
    _running = true;
    var delay = backoffMin;
    while (_listening.isNotEmpty && !_closed) {
      try {
        final boxes = _listening.take(maxMailboxes).toList();
        final items = await _poll(boxes);
        _setOnline(true);
        delay = backoffMin;
        final acks = <Map<String, String>>[];
        for (final it in items) {
          // Mail for a mailbox we stopped listening to is left alone (not shown, not acknowledged),
          // so it is still waiting if chat is switched back on. A blocked friend uses drop().
          if (!_listening.contains(it.mailbox) || _closed) continue;
          _incoming.add(Envelope(it.mailbox, it.bytes));
          acks.add({'m': it.mailbox, 'i': it.id});
        }
        if (acks.isNotEmpty) await _ack(acks);
      } catch (_) {
        if (_closed) break;
        _setOnline(false);
        await Future<void>.delayed(delay);
        delay = delay * 2 > backoffMax ? backoffMax : delay * 2;
      }
    }
    _running = false;
    if (_listening.isNotEmpty && !_closed) unawaited(_loop());
  }

  Future<List<_Item>> _poll(List<String> boxes) async {
    final req = await _client.postUrl(base.resolve('v1/poll')).timeout(requestTimeout);
    req.headers.contentType = ContentType.json;
    req.add(utf8.encode(jsonEncode({'m': boxes, 'wait': pollWait.inSeconds})));
    final res = await req.close().timeout(pollWait + requestTimeout);
    final text = await utf8.decodeStream(res).timeout(requestTimeout);
    if (res.statusCode != 200) throw HttpException('poll ${res.statusCode}');
    final j = jsonDecode(text) as Map;
    return [
      for (final x in (j['items'] as List))
        _Item(
          (x as Map)['m'] as String,
          x['i'] as String,
          Uint8List.fromList(base64.decode(x['b'] as String)),
        ),
    ];
  }

  Future<void> _ack(List<Map<String, String>> items) async {
    final req = await _client.postUrl(base.resolve('v1/ack')).timeout(requestTimeout);
    req.headers.contentType = ContentType.json;
    req.add(utf8.encode(jsonEncode({'items': items})));
    final res = await req.close().timeout(requestTimeout);
    await res.drain<void>().timeout(requestTimeout);
  }
}

class _Item {
  const _Item(this.mailbox, this.id, this.bytes);
  final String mailbox;
  final String id;
  final Uint8List bytes;
}
