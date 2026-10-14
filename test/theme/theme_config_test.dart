import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plural_app/theme/terminology.dart';
import 'package:plural_app/theme/theme_config.dart';

void main() {
  test('ThemeConfig round trips and has a MystikIM default', () {
    const c = ThemeConfig();
    expect(c.seedColor, kMystikViolet);
    final c2 = ThemeConfig.fromJson(c.copyWith(fontFamily: 'Pacifico', fontScale: 1.3).toJson());
    expect(c2.fontFamily, 'Pacifico');
    expect(c2.fontScale, 1.3);
  });

  test('buildTheme uses the chosen font, radius, and brightness', () {
    final t = buildTheme(const ThemeConfig(fontFamily: 'Space Mono'), Brightness.dark);
    expect(t.brightness, Brightness.dark);
    expect(t.textTheme.bodyMedium!.fontFamily, 'Space Mono');
  });

  test('themeModeOf maps strings', () {
    expect(themeModeOf(const ThemeConfig(mode: 'light')), ThemeMode.light);
    expect(themeModeOf(const ThemeConfig(mode: 'system')), ThemeMode.system);
    expect(themeModeOf(const ThemeConfig(mode: 'nonsense')), ThemeMode.dark);
  });

  test('Terminology defaults, overrides, and capitalizing', () {
    final t = Terminology.standard();
    expect(t('alter'), 'alter');
    expect(t.cap('front'), 'Front');
    final custom = Terminology(const {'alter': 'headmate', 'alters': 'headmates'});
    expect(custom('alters'), 'headmates');
    expect(custom('front'), 'front'); // untouched keys keep defaults
    expect(Terminology.fromJson(custom.toJson())('alter'), 'headmate');
  });

  test('empty override falls back to the default word', () {
    expect(Terminology(const {'alter': '  '})('alter'), 'alter');
  });
}
