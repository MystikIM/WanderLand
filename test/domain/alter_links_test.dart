import 'package:flutter_test/flutter_test.dart';
import 'package:plural_app/domain/alter_links.dart';
import 'package:plural_app/domain/world.dart';

void main() {
  const bob = NameRef('bob', 'Bob');
  const cat = NameRef('cat', 'Cat');

  List<String> texts(String text, List<NameRef> names) =>
      AlterLinker.find(text, names).map((s) => s.text).toList();

  test('finds names, ignoring case, in order', () {
    expect(texts('cat met BOB by the lake', [bob, cat]), ['cat', 'BOB']);
    final s = AlterLinker.find('hi Bob', [bob]).single;
    expect((s.start, s.end), (3, 6));
    expect(s.alterIds, ['bob']);
  });

  test('whole words only: Bobby is not Bob, but Bob\'s and Bob, and Bob. are', () {
    expect(texts('Bobby is here', [bob]), isEmpty);
    expect(texts('Bob’s garden', [bob]), ['Bob']);
    expect(texts("Bob's garden", [bob]), ['Bob']);
    expect(texts('Bob, Bob. (Bob) "Bob"', [bob]).length, 4);
    expect(texts('rebob', [bob]), isEmpty);
  });

  test('longest name wins and names do not overlap', () {
    const mary = NameRef('mary', 'Mary');
    const maryJane = NameRef('mj', 'Mary Jane');
    final spans = AlterLinker.find('Mary Jane and Mary', [mary, maryJane]);
    expect(spans.map((s) => (s.text, s.alterIds.single)).toList(), [('Mary Jane', 'mj'), ('Mary', 'mary')]);
  });

  test('names with emoji, accents, punctuation and regex symbols are safe', () {
    const tree = NameRef('t', 'Bob 🌲');
    const emile = NameRef('e', 'Émile');
    const cpp = NameRef('c', 'C++');
    const aj = NameRef('a', 'A.J.');
    const odd = NameRef('o', '(Mr) [X]');
    expect(texts('here is bob 🌲 now', [tree]), ['bob 🌲']);
    expect(texts('ÉMILE said hi', [emile]), ['ÉMILE']);
    expect(texts('C++ and A.J. spoke, (Mr) [X] too', [cpp, aj, odd]).length, 3);
  });

  test('the same name on two alters gives one span listing both', () {
    const sam1 = NameRef('s1', 'Sam');
    const sam2 = NameRef('s2', 'sam');
    final s = AlterLinker.find('Sam waves', [sam1, sam2]).single;
    expect(s.alterIds, ['s1', 's2']);
  });

  test('too-short, blank and missing names are ignored; empty input is fine', () {
    expect(AlterLinker.find('A b c', [const NameRef('a', 'A'), const NameRef('b', '  ')]), isEmpty);
    expect(AlterLinker.find('', [bob]), isEmpty);
    expect(AlterLinker.find('Bob', []), isEmpty);
  });

  test('a name from a removed alter simply is not in the list, so it is not linked', () {
    expect(texts('Bob and Cat', [cat]), ['Cat']);
  });

  test('mask blanks linked names but keeps the length and everything else', () {
    expect(AlterLinker.mask('Bob and Cat', [bob, cat]), '    and    ');
    expect(AlterLinker.mask('nothing here', [bob]), 'nothing here');
  });

  test('an alter named like a scene word does not grow that piece', () {
    const willow = NameRef('w', 'Willow');
    const m = KeywordMatcher();
    const text = 'Willow sits by a tree';
    expect(m.mentions(text), {'tree': 2});
    expect(m.mentions(AlterLinker.mask(text, [willow])), {'tree': 1});
  });

  test('counts how often each alter is mentioned across entries (same name counts for each candidate)', () {
    const sam1 = NameRef('s1', 'Sam');
    const sam2 = NameRef('s2', 'Sam');
    final c = AlterLinker.counts(['Bob, Bob and Cat', 'Sam too'], [bob, cat, sam1, sam2]);
    expect(c, {'bob': 2, 'cat': 1, 's1': 1, 's2': 1});
  });

  test('a very long diary with many names still completes', () {
    final names = [for (var i = 0; i < 60; i++) NameRef('n$i', 'Name$i')];
    final text = '${'word ' * 30000}Name7 and Name59';
    expect(AlterLinker.find(text, names).map((s) => s.text).toList(), ['Name7', 'Name59']);
  });
}
