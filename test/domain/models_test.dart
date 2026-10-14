import 'package:flutter_test/flutter_test.dart';
import 'package:plural_app/domain/models.dart';
import 'package:plural_app/domain/pronouns.dart';

void main() {
  test('Alter survives a JSON round trip, including odd names', () {
    final a = Alter(
      id: 'a1',
      name: 'Bob 🌲 ‮עברית',
      createdAt: DateTime(2026, 10, 14),
      pronouns: 'xe/xem',
      tags: const ['protector'],
      groups: const ['guardians'],
      customFields: const {'Age': 'looks 30'},
    );
    final b = Alter.fromJson(a.toJson());
    expect(b.name, a.name);
    expect(b.pronouns, 'xe/xem');
    expect(b.customFields['Age'], 'looks 30');
    expect(b.tags, ['protector']);
    expect(b.archived, false);
  });

  test('copyWith can clear the image', () {
    final a = Alter(id: 'a', name: 'A', createdAt: DateTime(2026), imagePath: 'images/a.jpg');
    expect(a.copyWith(clearImage: true).imagePath, isNull);
    expect(a.copyWith(name: 'B').imagePath, 'images/a.jpg');
  });

  test('FrontEntry round trips and open entry has null end', () {
    final e = FrontEntry(id: 'f1', alterId: 'a1', tier: FrontTier.coFront, start: DateTime(2026, 10, 14, 9));
    final back = FrontEntry.fromJson(e.toJson());
    expect(back.tier, FrontTier.coFront);
    expect(back.end, isNull);
    expect(back.copyWith(end: DateTime(2026, 10, 14, 10)).end, DateTime(2026, 10, 14, 10));
  });

  test('pronoun presets are inclusive and free text is still allowed', () {
    expect(kPronounPresets, containsAll(['they/them', 'xe/xem', 'ze/zir', 'it/its', 'any pronouns']));
    final a = Alter(id: 'a', name: 'A', createdAt: DateTime(2026), pronouns: 'moon/moons');
    expect(Alter.fromJson(a.toJson()).pronouns, 'moon/moons');
  });
}
