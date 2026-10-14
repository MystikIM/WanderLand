import 'package:flutter_test/flutter_test.dart';
import 'package:plural_app/controllers/alter_controller.dart';
import 'package:plural_app/controllers/front_controller.dart';
import 'package:plural_app/controllers/settings_controller.dart';
import 'package:plural_app/data/doc_store.dart';
import 'package:plural_app/domain/reminders.dart';
import 'package:plural_app/platform/front_notification_sync.dart';

class FakePort implements NotifierPort {
  final calls = <String>[];
  bool launchedByTap = false;
  void Function()? tap;

  @override
  Future<bool> init({required void Function() onTap}) async {
    tap = onTap;
    return launchedByTap;
  }

  @override
  Future<void> showFront(String text, {required bool private}) async =>
      calls.add('show:$text:${private ? 'private' : 'public'}');
  @override
  Future<void> clearFront() async => calls.add('clear');
  @override
  Future<void> scheduleCheckIns(List<(int, int)> times) async =>
      calls.add('schedule:${times.map((t) => formatTime(t.$1, t.$2)).join(',')}');
  @override
  Future<void> cancelCheckIns() async => calls.add('cancel');
  @override
  Future<void> showTest() async => calls.add('test');
}

void main() {
  late MemoryDocStore store;
  late SettingsController settings;
  late AlterController alters;
  late FrontController front;
  late FakePort port;
  late FrontNotificationSync sync;
  var opened = 0;

  setUp(() async {
    store = MemoryDocStore();
    settings = SettingsController(store);
    await settings.load();
    alters = AlterController(store);
    await alters.load();
    front = FrontController(store, clock: () => DateTime(2026, 10, 14, 9));
    await front.load();
    port = FakePort();
    opened = 0;
    sync = FrontNotificationSync(
      port: port, settings: settings, alters: alters, front: front,
      onOpenSwitch: () => opened++,
    );
  });

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  test('shows who is out (private on the lock screen by default) and clears when nobody is', () async {
    final bob = await alters.create(name: 'Bob');
    final cat = await alters.create(name: 'Cat');
    await sync.start();
    await front.set(primary: bob.id, coFront: [cat.id]);
    await settle();
    expect(port.calls, contains('show:Bob (with Cat):private'));
    await front.clear();
    await settle();
    expect(port.calls.last, 'clear');
  });

  test('turning the notification off clears it; public lock screen is honored', () async {
    final bob = await alters.create(name: 'Bob');
    await sync.start();
    await front.set(primary: bob.id);
    await settle();
    await settings.setNotify(settings.notify.copyWith(privateOnLockScreen: false));
    await settle();
    expect(port.calls, contains('show:Bob:public'));
    await settings.setNotify(settings.notify.copyWith(frontNotification: false));
    await settle();
    expect(port.calls.last, 'clear');
  });

  test('the same notification is not sent twice in a row', () async {
    final bob = await alters.create(name: 'Bob');
    await sync.start();
    await front.set(primary: bob.id);
    await settle();
    await front.load(); // unrelated change notification
    await alters.load();
    await settle();
    expect(port.calls.where((c) => c.startsWith('show:')).length, 1);
  });

  test('reminders are off by default, scheduled when turned on, cancelled when off', () async {
    await sync.start();
    await settle();
    expect(port.calls.where((c) => c.startsWith('schedule')), isEmpty);
    await settings.setNotify(settings.notify.copyWith(reminders: true));
    await settle();
    expect(port.calls, contains('schedule:09:00,20:00'));
    await settings.setNotify(settings.notify.copyWith(times: ['bad', '07:30']));
    await settle();
    expect(port.calls, contains('schedule:07:30'));
    await settings.setNotify(settings.notify.copyWith(reminders: false));
    await settle();
    expect(port.calls.last, 'cancel');
  });

  test('a removed alter in the front is shown safely', () async {
    final bob = await alters.create(name: 'Bob');
    await front.set(primary: bob.id);
    await alters.delete(bob.id);
    await sync.start();
    await settle();
    expect(port.calls, contains('show:Removed alter:private'));
  });

  test('tapping the notification, or launching from it, opens the switch sheet', () async {
    port.launchedByTap = true;
    await sync.start();
    expect(opened, 1); // cold start from a tap
    port.tap!();
    expect(opened, 2);
  });
}
