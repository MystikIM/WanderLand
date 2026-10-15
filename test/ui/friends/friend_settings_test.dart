import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plural_app/friends/friend_models.dart';
import 'package:plural_app/ui/friends/friend_settings_screen.dart';
import '../../helpers/friends_harness.dart';
import '../../helpers/friends_ui_env.dart';
import '../../helpers/harness.dart';

/// Switching chat off waits on the real clock, which a widget test's fake clock never moves.
Future<void> letItFinish(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump();
  }
}

void main() {
  testWidgets('chat can be switched off and back to while-the-app-is-open; Always on is shown as coming soon', (tester) async {
    final env = await uiEnv();
    await pumpScreen(tester, const FriendSettingsScreen(), providers: env.providers);
    expect(find.textContaining('Coming soon'), findsOneWidget);
    await tester.tap(find.byKey(const Key('fset-mode-off')));
    await letItFinish(tester);
    await tester.pumpAndSettle();
    expect(env.friends.identity!.mode, ChatMode.off);
    await tester.tap(find.byKey(const Key('fset-mode-open')));
    await letItFinish(tester);
    await tester.pumpAndSettle();
    expect(env.friends.identity!.mode, ChatMode.whileOpen);
  });

  testWidgets('the username can be changed, with a plain message if it is not allowed', (tester) async {
    final env = await uiEnv();
    await pumpScreen(tester, const FriendSettingsScreen(), providers: env.providers);
    await tester.enterText(find.byKey(const Key('fset-username')), 'x');
    await tester.tap(find.byKey(const Key('fset-username-save')));
    await tester.pumpAndSettle();
    expect(find.textContaining('between 3 and 24'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('fset-username')), 'newname');
    await tester.tap(find.byKey(const Key('fset-username-save')));
    await tester.pumpAndSettle();
    expect(env.friends.identity!.username, 'newname');
  });

  testWidgets('reset asks first, and wipes friends, messages and the key', (tester) async {
    final env = await uiEnv();
    await befriend(env.me, env.peer);
    await pumpScreen(tester, const FriendSettingsScreen(), providers: env.providers);
    await tester.ensureVisible(find.byKey(const Key('fset-reset')));
    await tester.tap(find.byKey(const Key('fset-reset')));
    await tester.pumpAndSettle();
    expect(env.friends.friends, isNotEmpty);
    await tester.tap(find.byKey(const Key('fset-confirm')));
    await tester.pumpAndSettle();
    await letItFinish(tester);
    await tester.pumpAndSettle();
    expect(env.friends.friends, isEmpty);
    expect(env.friends.isOn, isFalse);
  });

  testWidgets('chat never turned on: the page says where to start', (tester) async {
    final env = await uiEnv(chatOn: false);
    await pumpScreen(tester, const FriendSettingsScreen(), providers: env.providers);
    expect(find.textContaining('Chat > Friends'), findsOneWidget);
    expect(find.byKey(const Key('fset-reset')), findsNothing);
  });

  testWidgets('REVIEW FOCUS: while a little is out, every control is disabled and the reason is written', (tester) async {
    final env = await uiEnv();
    env.me.little = true;
    await pumpScreen(tester, const FriendSettingsScreen(), providers: env.providers);
    expect(tester.widget<RadioListTile<ChatMode>>(find.byKey(const Key('fset-mode-off'))).enabled, isFalse);
    expect(tester.widget<FilledButton>(find.byKey(const Key('fset-username-save'))).onPressed, isNull);
    expect(tester.widget<OutlinedButton>(find.byKey(const Key('fset-reset'))).onPressed, isNull);
    expect(find.textContaining('grown-up'), findsWidgets);
  });
}
