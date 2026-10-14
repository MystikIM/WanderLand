import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plural_app/controllers/alter_controller.dart';
import 'package:plural_app/controllers/chat_controller.dart';
import 'package:plural_app/controllers/front_controller.dart';
import 'package:plural_app/controllers/settings_controller.dart';
import 'package:plural_app/data/doc_store.dart';
import 'package:plural_app/data/image_store.dart';
import 'package:plural_app/ui/chat_screen.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import '../helpers/harness.dart';

void main() {
  Future<(ChatController, AlterController, FrontController, List<SingleChildWidget>)> env() async {
    final store = MemoryDocStore();
    final s = SettingsController(store);
    await s.load();
    final a = AlterController(store);
    await a.load();
    final f = FrontController(store, clock: () => DateTime(2026, 10, 14, 9));
    await f.load();
    final c = ChatController(store, clock: () => DateTime(2026, 10, 14, 9));
    await c.load();
    return (
      c,
      a,
      f,
      <SingleChildWidget>[
        ChangeNotifierProvider.value(value: s),
        ChangeNotifierProvider.value(value: a),
        ChangeNotifierProvider.value(value: f),
        ChangeNotifierProvider.value(value: c),
        Provider.value(value: ImageStore(Directory.systemTemp)),
      ],
    );
  }

  testWidgets('with no alters the chat explains what to do instead of crashing', (tester) async {
    final (_, _, _, p) = await env();
    await pumpScreen(tester, const ChatScreen(), providers: p);
    expect(find.textContaining('Add an'), findsOneWidget);
  });

  testWidgets('the sender defaults to whoever is out, and a message is sent as them', (tester) async {
    final (c, a, f, p) = await env();
    await a.create(name: 'Bob');
    final cat = await a.create(name: 'Cat');
    await f.set(primary: cat.id);
    await pumpScreen(tester, const ChatScreen(), providers: p);
    await tester.enterText(find.byKey(const Key('chat-input')), 'hello everyone 💜');
    await tester.tap(find.byKey(const Key('chat-send')));
    await tester.pumpAndSettle();
    expect(c.messagesIn('general').single.authorAlterId, cat.id);
    expect(find.text('hello everyone 💜'), findsOneWidget);
    expect(find.text('Cat'), findsWidgets);
  });

  testWidgets('an archived alter who is out does not break the sender picker', (tester) async {
    final (_, a, f, p) = await env();
    final bob = await a.create(name: 'Bob');
    await a.create(name: 'Cat');
    await f.set(primary: bob.id);
    await a.setArchived(bob.id, true);
    await pumpScreen(tester, const ChatScreen(), providers: p);
    expect(find.byKey(const Key('chat-input')), findsOneWidget);
  });

  testWidgets('empty messages are not sent', (tester) async {
    final (c, a, _, p) = await env();
    await a.create(name: 'Bob');
    await pumpScreen(tester, const ChatScreen(), providers: p);
    await tester.tap(find.byKey(const Key('chat-send')));
    await tester.pumpAndSettle();
    expect(c.messagesIn('general'), isEmpty);
  });

  testWidgets('a message from a removed alter shows a safe name', (tester) async {
    final (c, a, _, p) = await env();
    final gone = await a.create(name: 'Gone');
    await a.create(name: 'Bob');
    await c.send(channelId: 'general', authorAlterId: gone.id, text: 'bye');
    await a.delete(gone.id);
    await pumpScreen(tester, const ChatScreen(), providers: p);
    expect(find.text('Removed alter'), findsOneWidget);
    expect(find.text('bye'), findsOneWidget);
  });

  testWidgets('new channel, switching channels, and a duplicate name is refused kindly', (tester) async {
    final (c, a, _, p) = await env();
    await a.create(name: 'Bob');
    await pumpScreen(tester, const ChatScreen(), providers: p);
    await tester.tap(find.byKey(const Key('chat-add-channel')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('channel-name')), 'Planning');
    await tester.tap(find.byKey(const Key('channel-save')));
    await tester.pumpAndSettle();
    expect(c.channels.length, 2);
    expect(find.byKey(Key('channel-${c.channels.last.id}')), findsOneWidget);

    await tester.tap(find.byKey(const Key('chat-add-channel')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('channel-name')), 'planning');
    await tester.tap(find.byKey(const Key('channel-save')));
    await tester.pumpAndSettle();
    expect(find.text('There is already a channel with that name'), findsOneWidget);
    expect(c.channels.length, 2);
  });
}
