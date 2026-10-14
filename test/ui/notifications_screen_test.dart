import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plural_app/controllers/settings_controller.dart';
import 'package:plural_app/data/doc_store.dart';
import 'package:plural_app/platform/front_notification_sync.dart';
import 'package:plural_app/ui/notifications_screen.dart';
import 'package:provider/provider.dart';
import '../helpers/harness.dart';

class _Port implements NotifierPort {
  int tests = 0;
  @override
  Future<bool> init({required void Function() onTap}) async => false;
  @override
  Future<void> showFront(String text, {required bool private}) async {}
  @override
  Future<void> clearFront() async {}
  @override
  Future<void> scheduleCheckIns(List<(int, int)> times) async {}
  @override
  Future<void> cancelCheckIns() async {}
  @override
  Future<void> showTest() async => tests++;
}

void main() {
  Future<(SettingsController, _Port)> open(WidgetTester tester, {TimeOfDay? picked}) async {
    final s = SettingsController(MemoryDocStore());
    await s.load();
    final port = _Port();
    await pumpScreen(
      tester,
      NotificationsScreen(pickTime: (_) async => picked),
      providers: [
        ChangeNotifierProvider.value(value: s),
        Provider<NotifierPort>.value(value: port),
      ],
    );
    return (s, port);
  }

  testWidgets('defaults: notification on, lock screen private, reminders off', (tester) async {
    final (s, _) = await open(tester);
    expect(tester.widget<SwitchListTile>(find.byKey(const Key('notify-front'))).value, isTrue);
    expect(tester.widget<SwitchListTile>(find.byKey(const Key('notify-private'))).value, isTrue);
    expect(tester.widget<SwitchListTile>(find.byKey(const Key('notify-reminders'))).value, isFalse);
    expect(s.notify.reminders, isFalse);
  });

  testWidgets('switches save', (tester) async {
    final (s, _) = await open(tester);
    await tester.tap(find.byKey(const Key('notify-reminders')));
    await tester.pumpAndSettle();
    expect(s.notify.reminders, isTrue);
    await tester.tap(find.byKey(const Key('notify-private')));
    await tester.pumpAndSettle();
    expect(s.notify.privateOnLockScreen, isFalse);
  });

  testWidgets('reminder times: add (sorted, no duplicates), remove', (tester) async {
    final (s, _) = await open(tester, picked: const TimeOfDay(hour: 7, minute: 30));
    await tester.tap(find.byKey(const Key('add-time')));
    await tester.pumpAndSettle();
    expect(s.notify.times, ['07:30', '09:00', '20:00']);
    await tester.tap(find.byKey(const Key('add-time'))); // same time again
    await tester.pumpAndSettle();
    expect(s.notify.times.length, 3);
    await tester.tap(find.byKey(const Key('remove-09:00')));
    await tester.pumpAndSettle();
    expect(s.notify.times, ['07:30', '20:00']);
  });

  testWidgets('cancelling the time picker changes nothing; the 8-time cap is enforced', (tester) async {
    final (s, _) = await open(tester);
    await tester.tap(find.byKey(const Key('add-time')));
    await tester.pumpAndSettle();
    expect(s.notify.times.length, 2);

    await s.setNotify(s.notify.copyWith(times: [for (var h = 1; h <= 8; h++) '0$h:00']));
    await tester.pumpAndSettle();
    final add = tester.widget<TextButton>(find.byKey(const Key('add-time')));
    expect(add.onPressed, isNull);
  });

  testWidgets('"Send a test" asks the port to show a sample', (tester) async {
    final (_, port) = await open(tester);
    await tester.tap(find.byKey(const Key('notify-test')));
    await tester.pumpAndSettle();
    expect(port.tests, 1);
  });
}
