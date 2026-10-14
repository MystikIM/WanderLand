import 'package:flutter_test/flutter_test.dart';
import 'package:plural_app/controllers/settings_controller.dart';
import 'package:plural_app/data/doc_store.dart';
import 'package:plural_app/domain/reminders.dart';

void main() {
  test('parseTime accepts H:mm and HH:mm and rejects nonsense', () {
    expect(parseTime('09:30'), (9, 30));
    expect(parseTime('9:05'), (9, 5));
    expect(parseTime(' 23:59 '), (23, 59));
    expect(parseTime('24:00'), isNull);
    expect(parseTime('12:60'), isNull);
    expect(parseTime('noon'), isNull);
    expect(parseTime(''), isNull);
    expect(parseTime('9:5'), isNull);
  });

  test('formatTime pads', () {
    expect(formatTime(7, 5), '07:05');
    expect(formatTime(20, 0), '20:00');
  });

  test('validTimes drops bad ones, removes duplicates, sorts, and caps at 8', () {
    expect(validTimes(['20:00', 'bad', '09:00', '9:00', '25:00']), [(9, 0), (20, 0)]);
    expect(validTimes([]), isEmpty);
    final many = [for (var h = 0; h < 12; h++) formatTime(h, 0)];
    expect(validTimes(many).length, 8);
  });

  test('defaults are calm and private: reminders OFF, lock screen hides names', () {
    const p = NotifyPrefs();
    expect(p.frontNotification, isTrue);
    expect(p.privateOnLockScreen, isTrue);
    expect(p.reminders, isFalse);
    expect(p.times, ['09:00', '20:00']);
  });

  test('prefs round trip, old data loads, and settings persist them', () async {
    final p = const NotifyPrefs().copyWith(reminders: true, times: ['07:30']);
    final back = NotifyPrefs.fromJson(p.toJson());
    expect(back.reminders, isTrue);
    expect(back.times, ['07:30']);
    expect(NotifyPrefs.fromJson({'id': 'notify'}).reminders, isFalse);

    final store = MemoryDocStore();
    final s = SettingsController(store);
    await s.load();
    await s.setNotify(p);
    final s2 = SettingsController(store);
    await s2.load();
    expect(s2.notify.times, ['07:30']);
  });
}
