import 'package:flutter_test/flutter_test.dart';
import 'package:plural_app/controllers/chat_controller.dart';
import 'package:plural_app/data/doc_store.dart';

void main() {
  late MemoryDocStore store;
  var now = DateTime(2026, 10, 14, 9);
  late ChatController c;
  setUp(() async {
    store = MemoryDocStore();
    now = DateTime(2026, 10, 14, 9);
    c = ChatController(store, clock: () => now);
    await c.load();
  });

  test('a fresh chat has a General channel, and loading again does not duplicate it', () async {
    expect(c.channels.map((x) => x.name), ['General']);
    expect(c.channels.single.id, 'general');
    final again = ChatController(store, clock: () => now);
    await again.load();
    expect(again.channels.length, 1);
  });

  test('messages are kept per channel, oldest first, and persist', () async {
    final side = await c.addChannel('Side chat');
    await c.send(channelId: 'general', authorAlterId: 'bob', text: 'hi');
    now = now.add(const Duration(minutes: 1));
    await c.send(channelId: 'general', authorAlterId: 'cat', text: '  hello 💜  ');
    await c.send(channelId: side.id, authorAlterId: 'bob', text: 'psst');
    expect(c.messagesIn('general').map((m) => m.text), ['hi', 'hello 💜']);
    expect(c.messagesIn(side.id).map((m) => m.text), ['psst']);
    final again = ChatController(store, clock: () => now);
    await again.load();
    expect(again.messagesIn('general').length, 2);
  });

  test('empty messages and unknown channels are rejected', () async {
    expect(() => c.send(channelId: 'general', authorAlterId: 'bob', text: '   '), throwsArgumentError);
    expect(() => c.send(channelId: 'nope', authorAlterId: 'bob', text: 'hi'), throwsArgumentError);
  });

  test('channel names: trimmed, not blank, not duplicated (ignoring case)', () async {
    expect(() => c.addChannel('  '), throwsArgumentError);
    expect(() => c.addChannel('general'), throwsArgumentError);
    final x = await c.addChannel('  Planning  ');
    expect(x.name, 'Planning');
    expect(() => c.addChannel('PLANNING'), throwsArgumentError);
  });

  test('deleting a channel removes its messages; the last channel cannot be deleted', () async {
    final side = await c.addChannel('Side');
    await c.send(channelId: side.id, authorAlterId: 'a', text: 'x');
    expect(await c.deleteChannel(side.id), isTrue);
    expect(c.messagesIn(side.id), isEmpty);
    expect(await c.deleteChannel('general'), isFalse);
    expect(c.channels.length, 1);
  });

  test('deleteMessage removes just that message', () async {
    final m1 = await c.send(channelId: 'general', authorAlterId: 'a', text: 'one');
    await c.send(channelId: 'general', authorAlterId: 'a', text: 'two');
    await c.deleteMessage(m1.id);
    expect(c.messagesIn('general').map((m) => m.text), ['two']);
  });
}
