import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plural_app/ui/chat_home.dart';
import '../../helpers/friends_harness.dart';
import '../../helpers/friends_ui_env.dart';
import '../../helpers/harness.dart';

void main() {
  testWidgets('the Chat tab opens on Inside, and Friends is one tap away', (tester) async {
    final env = await uiEnv();
    await pumpScreen(tester, const ChatHome(), providers: env.providers);
    expect(find.byKey(const Key('chat-add-channel')), findsOneWidget); // today's chat, unchanged
    await tester.tap(find.descendant(of: find.byKey(const Key('chat-seg')), matching: find.textContaining('Friends')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('chat-add-channel')), findsNothing);
    await tester.tap(find.descendant(of: find.byKey(const Key('chat-seg')), matching: find.text('Inside')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('chat-add-channel')), findsOneWidget);
  });

  testWidgets('the Friends label shows how many requests are waiting', (tester) async {
    final env = await uiEnv();
    await env.peer.c.addFromCode(await env.friends.myCode());
    await settle([env.me, env.peer]);
    await pumpScreen(tester, const ChatHome(), providers: env.providers);
    expect(find.text('Friends (1)'), findsOneWidget);
  });
}
