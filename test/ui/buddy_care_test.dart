import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plural_app/controllers/alter_controller.dart';
import 'package:plural_app/controllers/buddy_controller.dart';
import 'package:plural_app/controllers/front_controller.dart';
import 'package:plural_app/controllers/settings_controller.dart';
import 'package:plural_app/data/doc_store.dart';
import 'package:plural_app/domain/buddy.dart';
import 'package:plural_app/ui/buddy_card.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import '../helpers/harness.dart';

void main() {
  final now = DateTime(2026, 10, 14, 9);

  Future<(BuddyController, List<SingleChildWidget>)> env() async {
    final store = MemoryDocStore();
    final s = SettingsController(store);
    await s.load();
    final a = AlterController(store);
    await a.load();
    final f = FrontController(store, clock: () => now);
    await f.load();
    final b = BuddyController(store, clock: () => now);
    await b.load();
    return (
      b,
      <SingleChildWidget>[
        ChangeNotifierProvider.value(value: s),
        ChangeNotifierProvider.value(value: a),
        ChangeNotifierProvider.value(value: f),
        ChangeNotifierProvider.value(value: b),
      ],
    );
  }

  testWidgets('the buddy card has all seven care buttons and each one works', (tester) async {
    final (b, p) = await env();
    await pumpScreen(tester, const Scaffold(body: SingleChildScrollView(child: BuddyCard())), providers: p);
    for (final a in BuddyAction.values) {
      expect(find.byKey(Key('buddy-${a.name}')), findsOneWidget, reason: a.name);
    }
    await tester.tap(find.byKey(const Key('buddy-wash')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('buddy-walk')));
    await tester.pumpAndSettle();
    expect(b.state.careCount, 2);
  });

}
