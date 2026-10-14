import 'package:flutter_test/flutter_test.dart';
import 'package:plural_app/domain/world.dart';

void main() {
  const m = KeywordMatcher();

  test('finds things the person mentions, ignoring case and punctuation', () {
    expect(m.mentions('There is a big TREE, by the lake!'), {'tree': 1, 'lake': 1});
    expect(m.mentions('Trees... so many trees.'), {'tree': 2});
    expect(m.mentions('The moon (and stars) at night'), {'moon': 3});
    expect(m.mentions(''), isEmpty);
    expect(m.mentions('nothing special here'), isEmpty);
  });

  test('whole words only: "street" is not a tree', () {
    expect(m.mentions('a busy street'), isEmpty);
    expect(m.mentions('homework'), isEmpty);
  });

  test('"I don\'t have a tree" does not draw a tree (straight or curly apostrophe)', () {
    expect(m.mentions("I don't have a tree"), isEmpty);
    expect(m.mentions('I don’t have a tree'), isEmpty);
    expect(m.mentions('There isn’t a lake'), isEmpty);
    expect(m.mentions('no big old tree'), isEmpty);
    expect(m.mentions('without a door'), isEmpty);
  });

  test('negation only reaches the thing right after it', () {
    expect(m.mentions('There is no sun but a big tree'), {'tree': 1});
    expect(m.mentions('no sun here, but a tree stands tall'), {'tree': 1});
  });

  test('emoji and other languages do not break it', () {
    expect(m.mentions('🌲🌲 a tree 💜 y también un árbol'), {'tree': 1});
    expect(m.mentions('עץ ו-tree'), {'tree': 1});
  });

  test('a very long diary still works', () {
    final text = '${'word ' * 50000}tree';
    expect(m.mentions(text), {'tree': 1});
  });

  test('mentionsAll adds up across entries', () {
    expect(m.mentionsAll(['a tree', 'two trees and a lake']), {'tree': 2, 'lake': 1});
  });

  test('growScale: 0.6 first, then +0.1 each, capped at 1.0', () {
    expect(growScale(1), closeTo(0.6, 1e-9));
    expect(growScale(2), closeTo(0.7, 1e-9));
    expect(growScale(5), closeTo(1.0, 1e-9));
    expect(growScale(50), closeTo(1.0, 1e-9));
  });

  test('every lexicon kind has an anchor spot, and anchors stay inside the scene', () {
    for (final k in kLexicon.keys) {
      final a = kAnchors[k];
      expect(a, isNotNull, reason: k);
      expect(a!.$1, inInclusiveRange(0.0, 1.0));
      expect(a.$2, inInclusiveRange(0.0, 1.0));
    }
  });

  var n = 0;
  String newId() => 'id${n++}';
  List<SceneItem> sync(List<SceneItem> items, Map<String, int> mentions, [Set<String> dismissed = const {}]) =>
      SceneBuilder.sync(items: items, mentions: mentions, dismissed: dismissed, newId: newId);

  test('a first mention puts a small piece in its corner', () {
    final out = sync([], {'tree': 1});
    expect(out.length, 1);
    expect(out.single.kind, 'tree');
    expect(out.single.scale, closeTo(0.6, 1e-9));
    expect((out.single.x, out.single.y), kAnchors['tree']);
    expect(out.single.userEdited, isFalse);
  });

  test('more mentions grow a piece the person has not touched', () {
    var items = sync([], {'tree': 1});
    items = sync(items, {'tree': 3});
    expect(items.single.scale, closeTo(0.8, 1e-9));
  });

  test('a piece the person moved or resized is never changed by the diary', () {
    var items = sync([], {'tree': 1});
    items = [items.single.copyWith(x: 0.9, y: 0.2, scale: 0.5, userEdited: true)];
    items = sync(items, {'tree': 9});
    expect(items.single.x, 0.9);
    expect(items.single.scale, 0.5);
    expect(items.length, 1);
  });

  test('removed (dismissed) kinds never come back, other kinds still appear', () {
    final out = sync([], {'tree': 2, 'lake': 1}, {'tree'});
    expect(out.map((i) => i.kind), ['lake']);
  });

  test('pieces are never removed when the diary stops mentioning them', () {
    var items = sync([], {'tree': 1, 'lake': 1});
    items = sync(items, {'lake': 1});
    expect(items.map((i) => i.kind).toSet(), {'tree', 'lake'});
  });

  test('SceneItem and WorldEntry round trip', () {
    final i = SceneItem(id: 'a', kind: 'sun', x: .1, y: .2, scale: .7, userEdited: true, colorValue: 0xFFFF0000);
    final b = SceneItem.fromJson(i.toJson());
    expect((b.kind, b.x, b.y, b.scale, b.userEdited, b.colorValue), ('sun', .1, .2, .7, true, 0xFFFF0000));
    final e = WorldEntry(id: 'e', title: 't', text: 'tree', createdAt: DateTime(2026), updatedAt: DateTime(2026, 1, 2));
    expect(WorldEntry.fromJson(e.toJson()).updatedAt, DateTime(2026, 1, 2));
  });
}
