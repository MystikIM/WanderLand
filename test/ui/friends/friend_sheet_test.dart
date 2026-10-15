import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plural_app/friends/friend_models.dart';
import 'package:plural_app/ui/friends/friend_sheet.dart';
import '../../helpers/friends_harness.dart';
import '../../helpers/friends_ui_env.dart';
import '../../helpers/harness.dart';

void main() {
  Future<(UiEnv, String)> sheetEnv() async {
    final env = await uiEnv();
    await befriend(env.me, env.peer);
    return (env, env.friends.friends.single.id);
  }

  testWidgets('the sharing switch starts off, turning it on reveals the alters checklist, and ticks are saved', (tester) async {
    final (env, id) = await sheetEnv();
    await pumpScreen(tester, Scaffold(body: FriendSheet(friendId: id)), providers: env.providers);
    expect(env.friends.friends.single.shareFront, isFalse);
    final cat = env.alters.all.firstWhere((a) => a.name == 'Cat');
    expect(find.byKey(Key('friend-allow-${cat.id}')), findsNothing);
    await tester.tap(find.byKey(const Key('friend-share')));
    await tester.pumpAndSettle();
    expect(env.friends.friends.single.shareFront, isTrue);
    await tester.tap(find.byKey(Key('friend-allow-${cat.id}')));
    await tester.pumpAndSettle();
    expect(env.friends.friends.single.allowedAlterIds, [cat.id]);
  });

  testWidgets('nickname, mute and the safety number work', (tester) async {
    final (env, id) = await sheetEnv();
    await pumpScreen(tester, Scaffold(body: FriendSheet(friendId: id)), providers: env.providers);
    await tester.enterText(find.byKey(const Key('friend-nickname')), 'Bravo bear');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(env.friends.friends.single.nickname, 'Bravo bear');
    await tester.tap(find.byKey(const Key('friend-mute')));
    await tester.pumpAndSettle();
    expect(env.friends.friends.single.muted, isTrue);
    await tester.tap(find.byKey(const Key('friend-safety')));
    await tester.pumpAndSettle();
    expect(find.textContaining(await env.friends.safetyNumberFor(id)), findsOneWidget);
  });

  testWidgets('block and remove ask first, then do it', (tester) async {
    final (env, id) = await sheetEnv();
    await pumpScreen(tester, Scaffold(body: FriendSheet(friendId: id)), providers: env.providers);
    await tester.tap(find.byKey(const Key('friend-block')));
    await tester.pumpAndSettle();
    expect(env.friends.friends.single.state, FriendState.friends); // not yet: asked first
    await tester.tap(find.byKey(const Key('friend-confirm')));
    await tester.pumpAndSettle();
    expect(env.friends.friends.single.state, FriendState.blocked);
  });

  testWidgets('removing a friend asks first, then deletes them', (tester) async {
    final (env, id) = await sheetEnv();
    await pumpScreen(tester, Scaffold(body: FriendSheet(friendId: id)), providers: env.providers);
    await tester.ensureVisible(find.byKey(const Key('friend-remove')));
    await tester.tap(find.byKey(const Key('friend-remove')));
    await tester.pumpAndSettle();
    expect(env.friends.friends, hasLength(1));
    await tester.tap(find.byKey(const Key('friend-confirm')));
    await tester.pumpAndSettle();
    expect(env.friends.friends, isEmpty);
  });

  testWidgets('REVIEW FOCUS: while a little is out, sharing, okay-for-littles and remove are disabled; mute and block still work', (tester) async {
    final (env, id) = await sheetEnv();
    env.me.little = true;
    await pumpScreen(tester, Scaffold(body: FriendSheet(friendId: id)), providers: env.providers);
    expect(tester.widget<SwitchListTile>(find.byKey(const Key('friend-share'))).onChanged, isNull);
    expect(tester.widget<SwitchListTile>(find.byKey(const Key('friend-little-ok'))).onChanged, isNull);
    expect(tester.widget<OutlinedButton>(find.byKey(const Key('friend-remove'))).onPressed, isNull);
    expect(tester.widget<SwitchListTile>(find.byKey(const Key('friend-mute'))).onChanged, isNotNull);
    expect(tester.widget<OutlinedButton>(find.byKey(const Key('friend-block'))).onPressed, isNotNull);
    expect(find.textContaining('grown-up'), findsWidgets);
  });

  testWidgets('REVIEW FOCUS: a friend removed while the sheet is open does not crash it', (tester) async {
    final (env, id) = await sheetEnv();
    await pumpScreen(tester, Scaffold(body: FriendSheet(friendId: id)), providers: env.providers);
    await env.friends.removeFriend(id);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
