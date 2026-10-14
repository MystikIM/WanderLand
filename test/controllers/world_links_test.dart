import 'package:flutter_test/flutter_test.dart';
import 'package:plural_app/controllers/world_controller.dart';
import 'package:plural_app/data/doc_store.dart';
import 'package:plural_app/domain/alter_links.dart';

void main() {
  late List<NameRef> names;
  late WorldController w;
  setUp(() async {
    names = [const NameRef('bob', 'Bob'), const NameRef('willow', 'Willow')];
    w = WorldController(MemoryDocStore(), clock: () => DateTime(2026, 10, 14, 9), names: () => names);
    await w.load();
  });

  test('an alter\'s name never grows a piece, but real scene words in the same entry still do', () async {
    final grown = await w.addEntry(text: 'Willow sits by a tree with Bob.');
    expect(grown, ['tree']);
    expect(w.items.single.scale, closeTo(0.6, 1e-9)); // one tree mention, not two
  });

  test('counts mentions per alter across all entries', () async {
    await w.addEntry(text: 'Bob is here.');
    await w.addEntry(text: 'Bob and Willow talk.');
    expect(w.alterMentionCounts(), {'bob': 2, 'willow': 1});
  });

  test('renamed and removed alters are followed the next time it is asked', () async {
    await w.addEntry(text: 'Bob and Willow');
    names = [const NameRef('bob', 'Robert'), const NameRef('willow', 'Willow')];
    expect(w.alterMentionCounts(), {'willow': 1});
    names = [const NameRef('bob', 'Robert')];
    expect(w.alterMentionCounts(), isEmpty);
  });

  test('without any names given it behaves exactly as before', () async {
    final plain = WorldController(MemoryDocStore(), clock: () => DateTime(2026, 10, 14, 9));
    await plain.load();
    expect(await plain.addEntry(text: 'Willow by a tree'), ['tree']);
    expect(plain.items.single.scale, closeTo(0.7, 1e-9)); // "Willow" and "tree" both count
    expect(plain.alterMentionCounts(), isEmpty);
  });
}
