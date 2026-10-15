import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:wanderland_relay/mail_store.dart';

const boxA = 'aaaaaaaaaaaaaaaaaaaaaa';
const boxB = 'bbbbbbbbbbbbbbbbbbbbbb';

void main() {
  late Directory dir;
  var now = DateTime(2026, 10, 15, 9);
  late MailStore store;

  MailStore make({int maxFrameBytes = 1024, int maxPerMailbox = 3, int maxMailboxes = 5}) => MailStore(
        dir,
        maxFrameBytes: maxFrameBytes,
        maxPerMailbox: maxPerMailbox,
        maxMailboxes: maxMailboxes,
        ttl: const Duration(days: 7),
        now: () => now = now.add(const Duration(milliseconds: 1)),
      );

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('relay_store');
    now = DateTime(2026, 10, 15, 9);
    store = make();
  });
  tearDown(() async => dir.delete(recursive: true));

  test('mail comes back oldest first, exactly as it went in', () async {
    expect(await store.put(boxA, [1]), PutResult.ok);
    expect(await store.put(boxA, [2, 2]), PutResult.ok);
    expect(await store.put(boxA, [3, 3, 3]), PutResult.ok);
    final items = await store.peek([boxA]);
    expect(items.map((i) => i.bytes), [
      Uint8List.fromList([1]),
      Uint8List.fromList([2, 2]),
      Uint8List.fromList([3, 3, 3]),
    ]);
    expect(items.every((i) => i.mailbox == boxA), isTrue);
  });

  test('peeking does not remove mail, acknowledging does', () async {
    await store.put(boxA, [1]);
    await store.put(boxA, [2]);
    final first = (await store.peek([boxA])).first;
    expect(await store.peek([boxA]), hasLength(2));
    await store.ack(boxA, first.id);
    expect((await store.peek([boxA])).single.bytes, [2]);
    await store.ack(boxA, first.id); // acknowledging twice is fine
    expect(await store.peek([boxA]), hasLength(1));
  });

  test('mailboxes are separate, and peek can ask for several at once', () async {
    await store.put(boxA, [1]);
    await store.put(boxB, [2]);
    expect((await store.peek([boxA])).single.bytes, [1]);
    expect(await store.peek([boxA, boxB]), hasLength(2));
    expect(await store.peek(['cccccccccccccccccccccc']), isEmpty);
  });

  test('too big, full mailbox and too many mailboxes are refused', () async {
    expect(await store.put(boxA, List.filled(1025, 0)), PutResult.tooBig);
    expect(await store.put(boxA, List.filled(1024, 0)), PutResult.ok);
    await store.put(boxA, [1]);
    await store.put(boxA, [2]);
    expect(await store.put(boxA, [3]), PutResult.full);
    for (var i = 0; i < 4; i++) {
      expect(await store.put('${'x' * 21}$i', [1]), PutResult.ok);
    }
    expect(await store.put('${'y' * 21}z', [1]), PutResult.full);
  });

  test('REVIEW FOCUS: bad mailbox ids and bad message ids never touch the disk outside the data folder', () async {
    for (final bad in ['', 'short', '../etc/passwd', 'a/b/c/d/e/f/g/h/i/j/k/l', 'x' * 44, 'ünïcödé-ünïcödé-ünïcödé']) {
      expect(() => store.put(bad, [1]), throwsArgumentError, reason: bad);
      expect(() => store.peek([bad]), throwsArgumentError, reason: bad);
      expect(() => store.deleteMailbox(bad), throwsArgumentError, reason: bad);
    }
    await store.put(boxA, [1]);
    final outside = File('${dir.parent.path}${Platform.pathSeparator}relay_outside_probe.msg');
    await outside.writeAsBytes([9]);
    await store.ack(boxA, '../../relay_outside_probe');
    await store.ack(boxA, '0000000000000000-000000/../../x');
    expect(await outside.exists(), isTrue);
    await outside.delete();
    expect(await store.peek([boxA]), hasLength(1));
  });

  test('mail survives the relay being stopped and started again, in the same order', () async {
    await store.put(boxA, [1]);
    await store.put(boxA, [2]);
    final again = make();
    expect((await again.peek([boxA])).map((i) => i.bytes.single), [1, 2]);
    await again.put(boxA, [3]);
    expect((await again.peek([boxA])).map((i) => i.bytes.single), [1, 2, 3]);
  });

  test('deleteMailbox removes everything waiting in it', () async {
    await store.put(boxA, [1]);
    await store.deleteMailbox(boxA);
    expect(await store.peek([boxA]), isEmpty);
    await store.deleteMailbox(boxA); // deleting a missing mailbox is fine
  });

  test('sweep removes mail older than the time limit, keeps newer mail, and tidies empty mailboxes', () async {
    await store.put(boxA, [1]);
    now = now.add(const Duration(days: 6));
    await store.put(boxA, [2]);
    now = now.add(const Duration(days: 2)); // first is 8 days old, second is 2 days old
    expect(await store.sweep(), 1);
    expect((await store.peek([boxA])).single.bytes, [2]);
    now = now.add(const Duration(days: 8));
    expect(await store.sweep(), 1);
    expect(await Directory('${dir.path}${Platform.pathSeparator}$boxA').exists(), isFalse);
  });
}
