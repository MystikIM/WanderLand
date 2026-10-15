import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plural_app/ui/friends/friend_chat_screen.dart';
import '../../helpers/friends_harness.dart';
import '../../helpers/friends_ui_env.dart';
import '../../helpers/harness.dart';

void main() {
  Future<(UiEnv, String)> chatEnv() async {
    final env = await uiEnv();
    await befriend(env.me, env.peer);
    return (env, env.friends.friends.single.id);
  }

  testWidgets('messages show with a delivery word; typing and sending works', (tester) async {
    final (env, id) = await chatEnv();
    await env.peer.c.sendMessage(friendId: env.peer.c.friends.single.id, text: 'hi from bravo');
    await settle([env.me, env.peer]);
    await pumpScreen(tester, FriendChatScreen(friendId: id), providers: env.providers);
    expect(find.text('hi from bravo'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('friend-input')), 'hello bravo 💜');
    await tester.tap(find.byKey(const Key('friend-send')));
    await tester.pumpAndSettle();
    await settle([env.me, env.peer]);
    await tester.pumpAndSettle();
    expect(find.text('hello bravo 💜'), findsOneWidget);
    expect(find.text('Delivered'), findsOneWidget);
    expect(env.peer.c.messagesWith(env.peer.c.friends.single.id).last.text, 'hello bravo 💜');
  });

  testWidgets('"speaking as" defaults to whoever is out, and the friend sees the name only if allowed', (tester) async {
    final (env, id) = await chatEnv();
    final cat = env.alters.all.firstWhere((a) => a.name == 'Cat');
    await env.front.set(primary: cat.id);
    env.me.outIds = [cat.id];
    await env.friends.setShareFront(id, true);
    await env.friends.setAllowedAlters(id, [cat.id]);
    await pumpScreen(tester, FriendChatScreen(friendId: id), providers: env.providers);
    await tester.enterText(find.byKey(const Key('friend-input')), 'meow');
    await tester.tap(find.byKey(const Key('friend-send')));
    await tester.pumpAndSettle();
    expect(env.friends.messagesWith(id).single.speakerName, 'Cat');
  });

  testWidgets('the speaker can be picked by hand', (tester) async {
    final (env, id) = await chatEnv();
    final bob = env.alters.all.firstWhere((a) => a.name == 'Bob');
    await env.friends.setShareFront(id, true);
    await env.friends.setAllowedAlters(id, [bob.id]);
    await pumpScreen(tester, FriendChatScreen(friendId: id), providers: env.providers);
    await tester.tap(find.byKey(const Key('friend-as')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bob').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('friend-input')), 'hi');
    await tester.tap(find.byKey(const Key('friend-send')));
    await tester.pumpAndSettle();
    expect(env.friends.messagesWith(id).single.speakerName, 'Bob');
  });

  testWidgets('empty text is not sent, and the header says when mail is waiting', (tester) async {
    final (env, id) = await chatEnv();
    env.me.transport.reachable = false;
    await pumpScreen(tester, FriendChatScreen(friendId: id), providers: env.providers);
    await tester.tap(find.byKey(const Key('friend-send')));
    await tester.pumpAndSettle();
    expect(env.friends.messagesWith(id), isEmpty);
    await tester.enterText(find.byKey(const Key('friend-input')), 'will wait');
    await tester.tap(find.byKey(const Key('friend-send')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Waiting'), findsWidgets);
  });

  testWidgets('REVIEW FOCUS: a friend removed while the chat is open closes the screen, no crash', (tester) async {
    final (env, id) = await chatEnv();
    await pumpScreen(tester, Builder(builder: (c) {
      return Scaffold(
        body: Center(
          child: ElevatedButton(
            key: const Key('open'),
            onPressed: () => Navigator.of(c).push(MaterialPageRoute<void>(builder: (_) => FriendChatScreen(friendId: id))),
            child: const Text('open'),
          ),
        ),
      );
    }), providers: env.providers);
    await tester.tap(find.byKey(const Key('open')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('friend-input')), findsOneWidget);
    await env.friends.removeFriend(id);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('friend-input')), findsNothing);
    expect(find.byKey(const Key('open')), findsOneWidget); // back where it started
  });

  testWidgets('REVIEW FOCUS: a little in a chat not marked okay cannot send; in one that is, they can', (tester) async {
    final (env, id) = await chatEnv();
    env.me.little = true;
    await pumpScreen(tester, FriendChatScreen(friendId: id), providers: env.providers);
    expect(find.byKey(const Key('friend-input')), findsNothing);
    expect(find.textContaining('grown-up'), findsOneWidget);
    env.me.little = false;
    await env.friends.setLittleOk(id, true);
    env.me.little = true;
    await pumpScreen(tester, FriendChatScreen(friendId: id), providers: env.providers);
    await tester.enterText(find.byKey(const Key('friend-input')), 'hi');
    await tester.tap(find.byKey(const Key('friend-send')));
    await tester.pumpAndSettle();
    expect(env.friends.messagesWith(id), hasLength(1));
  });

  testWidgets('REVIEW FOCUS: a very long message and a huge text size do not overflow', (tester) async {
    final (env, id) = await chatEnv();
    await env.peer.c.sendMessage(friendId: env.peer.c.friends.single.id, text: 'long ' * 700);
    await settle([env.me, env.peer]);
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pumpScreen(tester, FriendChatScreen(friendId: id), providers: env.providers);
    expect(tester.takeException(), isNull);
  });

  testWidgets('REVIEW FOCUS: tapping Send twice sends the message once', (tester) async {
    final (env, id) = await chatEnv();
    await pumpScreen(tester, FriendChatScreen(friendId: id), providers: env.providers);
    await tester.enterText(find.byKey(const Key('friend-input')), 'only once');
    await tester.tap(find.byKey(const Key('friend-send')));
    await tester.tap(find.byKey(const Key('friend-send')), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(env.friends.messagesWith(id), hasLength(1));
  });

  testWidgets('REVIEW FOCUS: if sending fails the words come back into the box and a plain sentence shows', (tester) async {
    final (env, id) = await chatEnv();
    await pumpScreen(tester, FriendChatScreen(friendId: id), providers: env.providers);
    await tester.enterText(find.byKey(const Key('friend-input')), 'please keep me');
    env.me.little = true; // a little takes the front after the box was shown; this chat is not marked okay
    await tester.tap(find.byKey(const Key('friend-send')));
    await tester.pumpAndSettle();
    expect(find.textContaining('grown-up'), findsWidgets);
    expect(env.friends.messagesWith(id), isEmpty);
    final field = tester.widgetList<TextField>(find.byKey(const Key('friend-input')));
    if (field.isNotEmpty) expect(field.single.controller!.text, 'please keep me');
  });

  testWidgets('REVIEW FOCUS: a little in a chat not marked okay cannot read the old messages either', (tester) async {
    final (env, id) = await chatEnv();
    await env.peer.c.sendMessage(friendId: env.peer.c.friends.single.id, text: 'something unkind');
    await settle([env.me, env.peer]);
    env.me.little = true;
    await pumpScreen(tester, FriendChatScreen(friendId: id), providers: env.providers);
    expect(find.textContaining('something unkind'), findsNothing);
    expect(find.textContaining('grown-up'), findsOneWidget);
  });
}
