import 'package:flutter_test/flutter_test.dart';
import 'package:plural_app/controllers/front_controller.dart';
import 'package:plural_app/controllers/settings_controller.dart';
import 'package:plural_app/data/doc_store.dart';

void main() {
  test('set/clear update current, history, primaryId and notify', () async {
    final c = FrontController(MemoryDocStore(), clock: () => DateTime(2026, 10, 14, 9));
    await c.load();
    expect(c.primaryId, isNull);
    var n = 0;
    c.addListener(() => n++);
    await c.set(primary: 'bob', coFront: ['cat']);
    expect(c.primaryId, 'bob');
    expect(c.current.length, 2);
    await c.clear();
    expect(c.primaryId, isNull);
    expect(c.history.length, 2);
    expect(n, greaterThanOrEqualTo(2));
  });

  test('front survives a reload from the same store', () async {
    final store = MemoryDocStore();
    final a = FrontController(store);
    await a.load();
    await a.set(primary: 'bob');
    final b = FrontController(store);
    await b.load();
    expect(b.primaryId, 'bob');
  });

  test('heads-up prefs default on and persist, including muted alters', () async {
    final store = MemoryDocStore();
    final s = SettingsController(store);
    await s.load();
    expect(s.headsUp.enabled, isTrue);
    await s.setHeadsUp(s.headsUp.copyWith(muted: ['bob']));
    final s2 = SettingsController(store);
    await s2.load();
    expect(s2.headsUp.muted, ['bob']);
    await s2.setHeadsUp(s2.headsUp.copyWith(enabled: false));
    final s3 = SettingsController(store);
    await s3.load();
    expect(s3.headsUp.enabled, isFalse);
  });
}
