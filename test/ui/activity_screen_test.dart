import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plural_app/controllers/alter_controller.dart';
import 'package:plural_app/controllers/front_controller.dart';
import 'package:plural_app/controllers/settings_controller.dart';
import 'package:plural_app/data/doc_store.dart';
import 'package:plural_app/data/image_store.dart';
import 'package:plural_app/domain/models.dart';
import 'package:plural_app/ui/activity_screen.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import '../helpers/harness.dart';

void main() {
  test('formatDuration', () {
    expect(formatDuration(Duration.zero), '<1m');
    expect(formatDuration(const Duration(seconds: 30)), '<1m');
    expect(formatDuration(const Duration(minutes: 45)), '45m');
    expect(formatDuration(const Duration(hours: 2)), '2h');
    expect(formatDuration(const Duration(hours: 2, minutes: 5)), '2h 5m');
  });

  Future<(MemoryDocStore, AlterController, FrontController, List<SingleChildWidget>)> env() async {
    final store = MemoryDocStore();
    final s = SettingsController(store);
    await s.load();
    final a = AlterController(store);
    await a.load();
    final f = FrontController(store, clock: () => DateTime(2026, 10, 14, 12)); // Wednesday
    await f.load();
    return (
      store,
      a,
      f,
      <SingleChildWidget>[
        ChangeNotifierProvider.value(value: s),
        ChangeNotifierProvider.value(value: a),
        ChangeNotifierProvider.value(value: f),
        Provider.value(value: ImageStore(Directory.systemTemp)),
      ],
    );
  }

  Future<void> addEntry(DocStore store, String id, String alter, DateTime s, DateTime? e) =>
      store.put('front', FrontEntry(id: id, alterId: alter, tier: FrontTier.primary, start: s, end: e).toJson());

  testWidgets('empty history shows a friendly message and no crash (zero alters too)', (tester) async {
    final (_, _, _, p) = await env();
    await pumpScreen(tester, const ActivityScreen(), providers: p);
    expect(find.text('Nothing logged this week yet.'), findsOneWidget);
  });

  testWidgets('this week: totals per alter with readable durations', (tester) async {
    final (store, alters, front, p) = await env();
    final bob = await alters.create(name: 'Bob');
    final cat = await alters.create(name: 'Cat');
    await addEntry(store, '1', bob.id, DateTime(2026, 10, 12, 9), DateTime(2026, 10, 12, 11));
    await addEntry(store, '2', cat.id, DateTime(2026, 10, 13, 9), DateTime(2026, 10, 13, 10, 30));
    await front.load();
    await pumpScreen(tester, const ActivityScreen(), providers: p);
    expect(find.descendant(of: find.byKey(Key('total-${bob.id}')), matching: find.text('2h')), findsOneWidget);
    expect(find.descendant(of: find.byKey(Key('total-${cat.id}')), matching: find.text('1h 30m')), findsOneWidget);
  });

  testWidgets('a removed alter shows a safe label instead of crashing', (tester) async {
    final (store, _, front, p) = await env();
    await addEntry(store, '1', 'ghost', DateTime(2026, 10, 12, 9), DateTime(2026, 10, 12, 10));
    await front.load();
    await pumpScreen(tester, const ActivityScreen(), providers: p);
    expect(find.text('Removed alter'), findsOneWidget);
  });

  testWidgets('week navigation: previous works, next is disabled on the current week', (tester) async {
    final (store, alters, front, p) = await env();
    final bob = await alters.create(name: 'Bob');
    await addEntry(store, '1', bob.id, DateTime(2026, 10, 5, 9), DateTime(2026, 10, 5, 10));
    await front.load();
    await pumpScreen(tester, const ActivityScreen(), providers: p);
    expect(find.text('Nothing logged this week yet.'), findsOneWidget);
    final next = tester.widget<IconButton>(find.byKey(const Key('next-week')));
    expect(next.onPressed, isNull);
    await tester.tap(find.byKey(const Key('prev-week')));
    await tester.pumpAndSettle();
    expect(find.byKey(Key('total-${bob.id}')), findsOneWidget);
  });

  testWidgets('an entry crossing midnight is counted in total once, split over days', (tester) async {
    final (store, alters, front, p) = await env();
    final bob = await alters.create(name: 'Bob');
    await addEntry(store, '1', bob.id, DateTime(2026, 10, 12, 22), DateTime(2026, 10, 13, 2));
    await front.load();
    await pumpScreen(tester, const ActivityScreen(), providers: p);
    expect(find.descendant(of: find.byKey(Key('total-${bob.id}')), matching: find.text('4h')), findsOneWidget);
  });
}
