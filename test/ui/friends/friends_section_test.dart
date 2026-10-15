import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plural_app/ui/friends/friends_section.dart';
import '../../helpers/friends_harness.dart';
import '../../helpers/friends_ui_env.dart';
import '../../helpers/harness.dart';

void main() {
  testWidgets('chat off: a plain explanation and a Turn on button, and nothing else', (tester) async {
    final env = await uiEnv(chatOn: false);
    await pumpScreen(tester, const Scaffold(body: FriendsSection()), providers: env.providers);
    expect(find.textContaining('scrambled'), findsOneWidget);
    expect(find.textContaining('internet'), findsOneWidget);
    expect(find.byKey(const Key('friends-add')), findsNothing);
    expect(find.byKey(const Key('friends-turn-on')), findsOneWidget);
  });

  testWidgets('turning on asks for a username, refuses a bad one in plain words, then switches chat on', (tester) async {
    final env = await uiEnv(chatOn: false);
    await pumpScreen(tester, const Scaffold(body: FriendsSection()), providers: env.providers);
    await tester.tap(find.byKey(const Key('friends-turn-on')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('friends-username')), 'a!');
    await tester.tap(find.byKey(const Key('friends-enable')));
    await tester.pumpAndSettle();
    expect(find.textContaining('between 3 and 24'), findsOneWidget);
    expect(env.friends.isOn, isFalse);
    await tester.enterText(find.byKey(const Key('friends-username')), 'moonlight');
    await tester.tap(find.byKey(const Key('friends-enable')));
    await tester.pumpAndSettle();
    expect(env.friends.isOn, isTrue);
    expect(env.friends.identity!.username, 'moonlight');
    expect(find.byKey(const Key('friends-add')), findsOneWidget);
  });

  testWidgets('REVIEW FOCUS: a little cannot turn chat on, and is told why', (tester) async {
    final env = await uiEnv(chatOn: false);
    env.me.little = true;
    await pumpScreen(tester, const Scaffold(body: FriendsSection()), providers: env.providers);
    final button = tester.widget<FilledButton>(find.byKey(const Key('friends-turn-on')));
    expect(button.onPressed, isNull);
    expect(find.textContaining('grown-up'), findsOneWidget);
  });

  testWidgets('friends are listed with their last message', (tester) async {
    final env = await uiEnv();
    await befriend(env.me, env.peer);
    final f = env.friends.friends.single;
    await env.peer.c.sendMessage(friendId: env.peer.c.friends.single.id, text: 'hello there');
    await settle([env.me, env.peer]);
    await pumpScreen(tester, const Scaffold(body: FriendsSection()), providers: env.providers);
    expect(find.byKey(Key('friend-${f.id}')), findsOneWidget);
    expect(find.text('bravo'), findsOneWidget);
    expect(find.textContaining('hello there'), findsOneWidget);
  });

  testWidgets('requests waiting show a banner; a friend I asked shows as waiting', (tester) async {
    final env = await uiEnv();
    await env.peer.c.addFromCode(await env.friends.myCode());
    await settle([env.me, env.peer]);
    await pumpScreen(tester, const Scaffold(body: FriendsSection()), providers: env.providers);
    expect(find.text('1 friend request waiting'), findsOneWidget);
    final other = await Phone.on(env.me.hub, username: 'charlie');
    await env.friends.addFromCode(await other.c.myCode());
    await tester.pumpAndSettle();
    expect(find.text('Waiting for them to accept'), findsOneWidget);
  });

  testWidgets('REVIEW FOCUS: while a little is out, Add is disabled, and a friend not marked okay does not open', (tester) async {
    final env = await uiEnv();
    await befriend(env.me, env.peer);
    env.me.little = true;
    await pumpScreen(tester, const Scaffold(body: FriendsSection()), providers: env.providers);
    expect(tester.widget<FilledButton>(find.byKey(const Key('friends-add'))).onPressed, isNull);
    await tester.tap(find.byKey(Key('friend-${env.friends.friends.single.id}')));
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.byKey(const Key('friend-input')), findsNothing);
  });

  testWidgets('REVIEW FOCUS: very long names and messages do not overflow', (tester) async {
    final env = await uiEnv();
    await befriend(env.me, env.peer);
    await env.friends.setNickname(env.friends.friends.single.id, 'N' * 200);
    await env.peer.c.sendMessage(friendId: env.peer.c.friends.single.id, text: 'm' * 3000);
    await settle([env.me, env.peer]);
    await pumpScreen(tester, const Scaffold(body: FriendsSection()), providers: env.providers);
    expect(tester.takeException(), isNull);
  });
}
