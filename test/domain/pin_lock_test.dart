import 'package:flutter_test/flutter_test.dart';
import 'package:plural_app/data/doc_store.dart';
import 'package:plural_app/domain/pin_lock.dart';

void main() {
  late MemoryDocStore store;
  var now = DateTime(2026, 10, 14, 9);
  late PinLock lock;
  setUp(() {
    store = MemoryDocStore();
    now = DateTime(2026, 10, 14, 9);
    lock = PinLock(store, clock: () => now);
  });

  test('no PIN by default; setting one works and wrong/right PINs are told apart', () async {
    expect(await lock.isSet, isFalse);
    await lock.setPin('4821', hint: 'my first dog');
    expect(await lock.isSet, isTrue);
    expect(await lock.verify('4821'), isTrue);
    expect(await lock.verify('0000'), isFalse);
    expect(await lock.verify(''), isFalse);
    expect(await lock.hint, 'my first dog');
  });

  test('PINs must be 4 to 8 digits', () async {
    for (final bad in ['', '123', '123456789', 'abcd', '12 34', '12.4']) {
      expect(() => lock.setPin(bad), throwsArgumentError, reason: bad);
    }
    await lock.setPin('12345678');
    await lock.setPin('0000');
    expect(await lock.verify('0000'), isTrue);
  });

  test('the PIN is never stored in plain text', () async {
    await lock.setPin('7391');
    final doc = (await store.get('settings', 'pin'))!;
    expect(doc.values.map((v) => '$v').any((v) => v.contains('7391')), isFalse);
    expect(doc['hash'], isNot('7391'));
  });

  test('the same PIN gets a different stored hash each time (salted)', () async {
    await lock.setPin('7391');
    final first = (await store.get('settings', 'pin'))!['hash'];
    now = now.add(const Duration(seconds: 5));
    await lock.setPin('7391');
    final second = (await store.get('settings', 'pin'))!['hash'];
    expect(first, isNot(second));
  });

  test('forgot the PIN: a reset opens exactly 24 hours after the first request', () async {
    await lock.setPin('4821');
    final ready = await lock.requestReset();
    expect(ready, now.add(const Duration(hours: 24)));
    expect(await lock.resetReady, isFalse);
    expect(await lock.completeReset(), isFalse);
    expect(await lock.isSet, isTrue);

    now = now.add(const Duration(hours: 23, minutes: 59));
    expect(await lock.resetReady, isFalse);
    now = now.add(const Duration(minutes: 1));
    expect(await lock.resetReady, isTrue);
    expect(await lock.completeReset(), isTrue);
    expect(await lock.isSet, isFalse);
  });

  test('asking again does not push the date back; the right PIN cancels a pending reset', () async {
    await lock.setPin('4821');
    final first = await lock.requestReset();
    now = now.add(const Duration(hours: 5));
    expect(await lock.requestReset(), first);
    expect(await lock.verify('4821'), isTrue);
    expect(await lock.resetAt, isNull);
  });

  test('remove clears the PIN; requestReset with no PIN does nothing', () async {
    expect(await lock.requestReset(), isNull);
    await lock.setPin('4821');
    await lock.remove();
    expect(await lock.isSet, isFalse);
    expect(await lock.verify('4821'), isFalse);
  });
}
