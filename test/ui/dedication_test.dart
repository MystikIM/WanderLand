import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plural_app/app_info.dart';
import 'package:plural_app/controllers/alter_controller.dart';
import 'package:plural_app/controllers/buddy_controller.dart';
import 'package:plural_app/controllers/chat_controller.dart';
import 'package:plural_app/controllers/front_controller.dart';
import 'package:plural_app/controllers/settings_controller.dart';
import 'package:plural_app/data/doc_store.dart';
import 'package:plural_app/ui/dedication.dart';
import 'package:plural_app/ui/home_shell.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import '../helpers/harness.dart';

void main() {
  Future<(SettingsController, List<SingleChildWidget>)> env({bool onboarded = true}) async {
    final store = MemoryDocStore();
    final s = SettingsController(store);
    await s.load();
    if (onboarded) await s.setProfile(s.profile.copyWith(onboarded: true));
    final a = AlterController(store);
    await a.load();
    final f = FrontController(store);
    await f.load();
    final b = BuddyController(store);
    await b.load();
    final c = ChatController(store);
    await c.load();
    return (
      s,
      <SingleChildWidget>[
        ChangeNotifierProvider.value(value: s),
        ChangeNotifierProvider.value(value: a),
        ChangeNotifierProvider.value(value: f),
        ChangeNotifierProvider.value(value: b),
        ChangeNotifierProvider.value(value: c),
      ],
    );
  }

  testWidgets('the About page shows the dedication with the motto and the nicknames only', (tester) async {
    final (_, p) = await env();
    await pumpScreen(tester, const DedicationScreen(), providers: p);
    expect(find.text(dedicationMotto1), findsOneWidget);
    expect(find.text(dedicationMotto2), findsOneWidget);
    expect(find.textContaining('The Zoo and Joker_Wolf'), findsOneWidget);
    expect(find.textContaining('MystikIM'), findsOneWidget);
    expect(find.byKey(const Key('dedication-wolf')), findsOneWidget);
  });

  testWidgets('tapping a friend or the wolf plays a little reaction and nothing breaks', (tester) async {
    final (_, p) = await env();
    await pumpScreen(tester, const DedicationScreen(), providers: p);
    await tester.tap(find.byKey(const Key('dedication-friend-0')));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.tap(find.byKey(const Key('dedication-wolf')));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('first launch shows the dedication once; after "Let\'s go" it is remembered', (tester) async {
    final (s, p) = await env();
    await pumpScreen(tester, const HomeShell(showDedication: true), providers: p);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('dedication-card')), findsOneWidget);
    await tester.tap(find.byKey(const Key('dedication-continue')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('dedication-card')), findsNothing);
    expect(s.profile.dedicationSeen, isTrue);

    await pumpScreen(tester, HomeShell(key: UniqueKey(), showDedication: true), providers: p);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('dedication-card')), findsNothing);
  });

  testWidgets('it does not pop up before setup is finished, or when switched off', (tester) async {
    final (_, p) = await env(onboarded: false);
    await pumpScreen(tester, const HomeShell(showDedication: true), providers: p);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('dedication-card')), findsNothing);

    final (_, p2) = await env();
    await pumpScreen(tester, HomeShell(key: UniqueKey()), providers: p2);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('dedication-card')), findsNothing);
  });
}
