import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plural_app/data/doc_store.dart';
import 'package:plural_app/ui/friends/friend_settings_screen.dart';
import 'package:plural_app/ui/more_screen.dart';
import 'package:provider/provider.dart';
import '../../helpers/friends_ui_env.dart';
import '../../helpers/harness.dart';

void main() {
  testWidgets('More has a Friend chat tile that opens the chat settings', (tester) async {
    final env = await uiEnv();
    await pumpScreen(
      tester,
      const Scaffold(body: MoreScreen()),
      providers: [
        ...env.providers,
        Provider<DocStore>.value(value: env.store),
        Provider<Directory>.value(value: Directory.systemTemp),
      ],
    );
    await tester.scrollUntilVisible(find.byKey(const Key('more-friend-chat')), 200);
    await tester.tap(find.byKey(const Key('more-friend-chat')));
    await tester.pumpAndSettle();
    expect(find.byType(FriendSettingsScreen), findsOneWidget);
  });
}
