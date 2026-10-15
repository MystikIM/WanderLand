import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plural_app/friends/friend_models.dart';
import 'package:plural_app/ui/friends/add_friend_screen.dart';
import '../../helpers/friends_harness.dart';
import '../../helpers/friends_ui_env.dart';
import '../../helpers/harness.dart';

void main() {
  testWidgets('Show my code makes a code once, shows it as text and as a QR, and it can be copied', (tester) async {
    final env = await uiEnv();
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') copied = (call.arguments as Map)['text'] as String;
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    await pumpScreen(tester, const AddFriendScreen(), providers: env.providers);
    expect(find.byKey(const Key('friends-my-code')), findsNothing); // not made until asked
    expect(env.friends.identity!.pairingMailboxes, isEmpty);
    await tester.tap(find.byKey(const Key('friends-show-code')));
    await tester.pumpAndSettle();
    final shown = tester.widget<SelectableText>(find.byKey(const Key('friends-my-code'))).data!;
    expect(shown, startsWith('WL1-'));
    expect(find.byKey(ValueKey('qr:$shown')), findsOneWidget); // the QR carries this exact code
    await tester.tap(find.byKey(const Key('friends-copy-code')));
    await tester.pump();
    expect(copied, shown);
  });

  testWidgets("pasting a friend's code sends the request and says so", (tester) async {
    final env = await uiEnv();
    final code = await env.peer.c.myCode();
    await pumpScreen(tester, const AddFriendScreen(), providers: env.providers);
    await tester.enterText(find.byKey(const Key('friends-code-input')), '  $code  ');
    await tester.tap(find.byKey(const Key('friends-add-go')));
    await tester.pumpAndSettle();
    expect(env.friends.friends.single.state, FriendState.pendingOut);
    expect(find.textContaining('bravo'), findsWidgets);
    await settle([env.me, env.peer]);
    expect(env.peer.c.pendingRequests, hasLength(1));
  });

  testWidgets('REVIEW FOCUS: a bad code, my own code, and the same friend twice each give a plain sentence', (tester) async {
    final env = await uiEnv();
    await pumpScreen(tester, const AddFriendScreen(), providers: env.providers);
    Future<String> tryCode(String text) async {
      await tester.enterText(find.byKey(const Key('friends-code-input')), text);
      await tester.tap(find.byKey(const Key('friends-add-go')));
      await tester.pumpAndSettle();
      return tester.widget<Text>(find.byKey(const Key('friends-add-problem'))).data!;
    }

    expect(await tryCode('hello'), isNot(contains('Exception')));
    final own = await env.friends.myCode();
    expect(await tryCode(own), contains('your own'));
    final theirs = await env.peer.c.myCode();
    await env.friends.addFromCode(theirs);
    final again = await env.peer.c.myCode();
    expect(await tryCode(again), isNotEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a waiting request can be accepted or declined', (tester) async {
    final env = await uiEnv();
    final c = await Phone.on(env.me.hub, username: 'charlie');
    await env.peer.c.addFromCode(await env.friends.myCode());
    await c.c.addFromCode(await env.friends.myCode());
    await settle([env.me, env.peer, c]);
    await pumpScreen(tester, const AddFriendScreen(), providers: env.providers);
    final reqs = env.friends.pendingRequests;
    expect(reqs, hasLength(2));
    await tester.tap(find.byKey(Key('friends-accept-${reqs.first.id}')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key('friends-decline-${reqs.last.id}')));
    await tester.pumpAndSettle();
    expect(env.friends.pendingRequests, isEmpty);
    expect(env.friends.friends.where((f) => f.state == FriendState.friends), hasLength(1));
  });

  testWidgets('REVIEW FOCUS: while a little is out nothing here can be used, and the reason is written', (tester) async {
    final env = await uiEnv();
    env.me.little = true;
    await pumpScreen(tester, const AddFriendScreen(), providers: env.providers);
    expect(find.byKey(const Key('friends-show-code')), findsNothing);
    expect(find.byKey(const Key('friends-add-go')), findsNothing);
    expect(find.textContaining('grown-up'), findsOneWidget);
  });
}
