import 'package:flutter_test/flutter_test.dart';
import 'package:plural_app/data/doc_store.dart';

void docStoreContract(String name, Future<DocStore> Function() make) {
  group('DocStore contract: $name', () {
    late DocStore s;
    setUp(() async => s = await make());

    test('put then get returns the same doc', () async {
      await s.put('alters', {'id': 'a1', 'name': 'Bob 🌲'});
      expect((await s.get('alters', 'a1'))!['name'], 'Bob 🌲');
    });

    test('put with same id replaces', () async {
      await s.put('alters', {'id': 'a1', 'name': 'Old'});
      await s.put('alters', {'id': 'a1', 'name': 'New'});
      expect((await s.all('alters')).length, 1);
      expect((await s.get('alters', 'a1'))!['name'], 'New');
    });

    test('get missing returns null; collections are separate', () async {
      await s.put('a', {'id': '1'});
      expect(await s.get('b', '1'), isNull);
      expect(await s.all('b'), isEmpty);
    });

    test('delete removes only that doc', () async {
      await s.put('a', {'id': '1'});
      await s.put('a', {'id': '2'});
      await s.delete('a', '1');
      expect((await s.all('a')).map((d) => d['id']), ['2']);
    });

    test('exportAll then restoreDocs round trips; clear empties', () async {
      await s.put('a', {'id': '1', 'x': 1});
      await s.put('b', {'id': '2', 'y': [1, 2]});
      final dump = await s.exportAll();
      await s.clear();
      expect(await s.all('a'), isEmpty);
      await restoreDocs(s, dump);
      expect((await s.get('b', '2'))!['y'], [1, 2]);
      expect((await s.get('a', '1'))!['x'], 1);
    });

    test('put without an id is rejected', () async {
      expect(() => s.put('a', {'name': 'x'}), throwsArgumentError);
    });
  });
}
