import 'package:flutter_test/flutter_test.dart';
import 'package:plural_app/theme/theme_config.dart';

void main() {
  const mine = ThemeConfig(seedColor: 0xFF111111, accentColor: 0xFF222222, fontFamily: 'Pacifico', cornerRadius: 4);
  const bobsColor = 0xFFE40303;

  test('default is "accent"', () {
    expect(const ThemeConfig().alterLook, 'accent');
  });

  test('accent: only the accent color follows the alter', () {
    final c = withAlterLook(mine, bobsColor);
    expect(c.accentColor, bobsColor);
    expect(c.seedColor, 0xFF111111);
    expect(c.fontFamily, 'Pacifico');
    expect(c.cornerRadius, 4);
  });

  test('full: the main color follows too, but never the font or shapes', () {
    final c = withAlterLook(mine.copyWith(alterLook: 'full'), bobsColor);
    expect(c.seedColor, bobsColor);
    expect(c.accentColor, bobsColor);
    expect(c.fontFamily, 'Pacifico');
    expect(c.cornerRadius, 4);
  });

  test('off, nobody out, or an unknown setting', () {
    expect(withAlterLook(mine.copyWith(alterLook: 'off'), bobsColor).accentColor, 0xFF222222);
    expect(withAlterLook(mine, null).accentColor, 0xFF222222);
    expect(withAlterLook(mine.copyWith(alterLook: 'weird'), bobsColor).accentColor, bobsColor);
  });

  test('saved and old settings: round trip, and older saves default to "accent"', () {
    final back = ThemeConfig.fromJson(mine.copyWith(alterLook: 'full').toJson());
    expect(back.alterLook, 'full');
    expect(ThemeConfig.fromJson({'id': 'theme'}).alterLook, 'accent');
  });
}
