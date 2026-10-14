import 'package:flutter_test/flutter_test.dart';
import 'package:plural_app/controllers/settings_controller.dart';
import 'package:plural_app/data/doc_store.dart';
import 'package:plural_app/theme/terminology.dart';
import 'package:plural_app/theme/theme_config.dart';

void main() {
  test('settings persist across a reload', () async {
    final store = MemoryDocStore();
    final a = SettingsController(store);
    await a.load();
    expect(a.profile.onboarded, isFalse);
    await a.setTheme(a.theme.copyWith(fontFamily: 'Pacifico'));
    await a.setTerminology(Terminology(const {'alter': 'headmate'}));
    await a.setProfile(const SystemProfile(systemName: 'The Wanderers', greeting: 'Hi all', onboarded: true));

    final b = SettingsController(store);
    await b.load();
    expect(b.theme.fontFamily, 'Pacifico');
    expect(b.terminology('alter'), 'headmate');
    expect(b.profile.systemName, 'The Wanderers');
    expect(b.profile.onboarded, isTrue);
  });

  test('notifies listeners on change', () async {
    final s = SettingsController(MemoryDocStore());
    var n = 0;
    s.addListener(() => n++);
    await s.setTheme(const ThemeConfig(mode: 'light'));
    expect(n, 1);
  });
}
