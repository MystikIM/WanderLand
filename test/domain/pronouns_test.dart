import 'package:flutter_test/flutter_test.dart';
import 'package:plural_app/domain/pronouns.dart';

void main() {
  group('splitPronouns', () {
    test('splits on commas and trims', () {
      expect(splitPronouns('she/her, they/them'), ['she/her', 'they/them']);
      expect(splitPronouns('  he/him ,xe/xem  ,'), ['he/him', 'xe/xem']);
    });
    test('empty and blank give an empty list', () {
      expect(splitPronouns(''), isEmpty);
      expect(splitPronouns('  , , '), isEmpty);
    });
    test('a single custom set stays whole, slashes and all', () {
      expect(splitPronouns('moon/moons'), ['moon/moons']);
    });
  });

  group('hasPronoun', () {
    test('finds a pronoun in a list, ignoring case and spaces', () {
      expect(hasPronoun('she/her, They/Them', 'they/them'), isTrue);
      expect(hasPronoun('she/her', 'they/them'), isFalse);
      expect(hasPronoun('', 'she/her'), isFalse);
    });
    test('does not match part of another pronoun', () {
      expect(hasPronoun('she/her/hers', 'she/her'), isFalse);
    });
  });

  group('togglePronoun', () {
    test('adds one, then another, in the order they were picked', () {
      var s = togglePronoun('', 'she/her');
      expect(s, 'she/her');
      s = togglePronoun(s, 'they/them');
      expect(s, 'she/her, they/them');
    });
    test('taps it again to take it away, keeping the rest', () {
      expect(togglePronoun('she/her, they/them', 'she/her'), 'they/them');
      expect(togglePronoun('she/her', 'she/her'), '');
    });
    test('keeps pronouns the person typed themselves', () {
      expect(togglePronoun('moon/moons, she/her', 'she/her'), 'moon/moons');
      expect(togglePronoun('moon/moons', 'he/him'), 'moon/moons, he/him');
    });
    test('matches the existing pick whatever its case', () {
      expect(togglePronoun('She/Her', 'she/her'), '');
    });
    test('there is no limit: every preset can be picked at once, and any number of custom ones', () {
      var s = '';
      for (final p in kPronounPresets) {
        s = togglePronoun(s, p);
      }
      expect(splitPronouns(s), kPronounPresets);
      for (var i = 0; i < 40; i++) {
        s = togglePronoun(s, 'custom$i/customs$i');
      }
      expect(splitPronouns(s), hasLength(kPronounPresets.length + 40));
    });
  });
}
