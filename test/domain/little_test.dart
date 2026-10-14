import 'package:flutter_test/flutter_test.dart';
import 'package:plural_app/controllers/settings_controller.dart';
import 'package:plural_app/domain/little.dart';
import 'package:plural_app/domain/models.dart';
import 'package:plural_app/theme/theme_config.dart';

Alter a({int? age, String mode = 'auto'}) =>
    Alter(id: 'x', name: 'X', createdAt: DateTime(2026), ageYears: age, littleMode: mode);

void main() {
  test('auto mode follows age bands with exact boundaries', () {
    expect(littleLevelOf(a(age: 3)), LittleLevel.young);
    expect(littleLevelOf(a(age: 5)), LittleLevel.young);
    expect(littleLevelOf(a(age: 6)), LittleLevel.child);
    expect(littleLevelOf(a(age: 12)), LittleLevel.child);
    expect(littleLevelOf(a(age: 13)), LittleLevel.none);
    expect(littleLevelOf(a(age: 40)), LittleLevel.none);
  });

  test('no age or no alter means normal', () {
    expect(littleLevelOf(a()), LittleLevel.none);
    expect(littleLevelOf(null), LittleLevel.none);
  });

  test('"on" forces little mode; "off" forces normal', () {
    expect(littleLevelOf(a(mode: 'on')), LittleLevel.child); // no age -> child
    expect(littleLevelOf(a(age: 4, mode: 'on')), LittleLevel.young);
    expect(littleLevelOf(a(age: 30, mode: 'on')), LittleLevel.child);
    expect(littleLevelOf(a(age: 5, mode: 'off')), LittleLevel.none);
  });

  test('unknown mode text behaves like auto', () {
    expect(littleLevelOf(a(age: 5, mode: 'weird')), LittleLevel.young);
  });

  test('kid copy is different per level and falls back safely', () {
    const none = LittleCopy(LittleLevel.none);
    const child = LittleCopy(LittleLevel.child);
    const young = LittleCopy(LittleLevel.young);
    expect(none('whosOut'), "Who's out?");
    expect(child('whosOut'), isNot(none('whosOut')));
    expect(young('whosOut'), isNot(child('whosOut')));
    expect(none('not-a-key'), 'not-a-key');
    for (final k in ['whosOut', 'done', 'journal', 'addFirst', 'guardMessage']) {
      expect(child(k).isNotEmpty && young(k).isNotEmpty, isTrue, reason: k);
    }
  });

  test('littleAdjust makes things bigger/rounder but keeps the person\'s own choices', () {
    const mine = ThemeConfig(seedColor: 0xFF123456, fontFamily: 'Pacifico', fontScale: 1.0, cornerRadius: 4);
    final c = littleAdjust(mine, LittleLevel.child);
    expect(c.fontScale, greaterThan(1.0));
    expect(c.cornerRadius, greaterThan(4));
    expect(c.seedColor, 0xFF123456);
    expect(c.fontFamily, 'Pacifico');
    final y = littleAdjust(mine, LittleLevel.young);
    expect(y.fontScale, greaterThanOrEqualTo(c.fontScale));
    // never shrinks a larger setting:
    const big = ThemeConfig(fontScale: 1.7, cornerRadius: 30);
    expect(littleAdjust(big, LittleLevel.child).fontScale, 1.7);
    expect(littleAdjust(big, LittleLevel.child).cornerRadius, 30);
    // normal level changes nothing:
    expect(littleAdjust(mine, LittleLevel.none).fontScale, 1.0);
  });

  test('guard blocks risky actions only while a little is out and the guard is on', () {
    expect(riskyActionsAllowed(LittleLevel.none, guardOn: true), isTrue);
    expect(riskyActionsAllowed(LittleLevel.child, guardOn: true), isFalse);
    expect(riskyActionsAllowed(LittleLevel.young, guardOn: true), isFalse);
    expect(riskyActionsAllowed(LittleLevel.young, guardOn: false), isTrue);
  });

  test('Alter age/mode round trip; old saved alters without them still load', () {
    final x = Alter.fromJson(a(age: 7, mode: 'on').toJson());
    expect(x.ageYears, 7);
    expect(x.littleMode, 'on');
    final old = Alter.fromJson({'id': 'o', 'name': 'Old', 'createdAt': '2026-01-01T00:00:00.000'});
    expect(old.ageYears, isNull);
    expect(old.littleMode, 'auto');
    expect(a(age: 7).copyWith(clearAge: true).ageYears, isNull);
  });

  test('SystemProfile: guard defaults on, survives round trip, copyWith keeps the rest', () {
    expect(const SystemProfile().littleGuard, isTrue);
    final p = const SystemProfile(systemName: 'S', onboarded: true).copyWith(littleGuard: false);
    final back = SystemProfile.fromJson(p.toJson());
    expect(back.littleGuard, isFalse);
    expect(back.systemName, 'S');
    expect(back.onboarded, isTrue);
    expect(SystemProfile.fromJson({'id': 'profile'}).littleGuard, isTrue); // older save
  });
}
