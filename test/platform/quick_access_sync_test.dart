import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:plural_app/controllers/alter_controller.dart';
import 'package:plural_app/controllers/front_controller.dart';
import 'package:plural_app/data/doc_store.dart';
import 'package:plural_app/platform/quick_access_sync.dart';

class FakeShortcuts implements ShortcutsPort {
  List<ShortcutEntry> last = [];
  int sets = 0;
  Future<void> Function(String type)? select;
  @override
  Future<void> init(Future<void> Function(String type) onSelected) async => select = onSelected;
  @override
  Future<void> setShortcuts(List<ShortcutEntry> entries) async {
    last = entries;
    sets++;
  }
}

class FakeWidget implements WidgetPort {
  String text = '';
  int updates = 0;
  bool launched = false;
  final ctrl = StreamController<void>.broadcast();
  @override
  Future<void> updateText(String t) async {
    text = t;
    updates++;
  }
  @override
  Stream<void> get clicks => ctrl.stream;
  @override
  Future<bool> launchedFromWidget() async => launched;
}

void main() {
  late AlterController alters;
  late FrontController front;
  late FakeShortcuts sc;
  late FakeWidget wd;
  late QuickAccessSync sync;
  var opened = 0;
  var now = DateTime(2026, 10, 14, 9);

  setUp(() async {
    final store = MemoryDocStore();
    alters = AlterController(store);
    await alters.load();
    now = DateTime(2026, 10, 14, 9);
    front = FrontController(store, clock: () => now);
    await front.load();
    sc = FakeShortcuts();
    wd = FakeWidget();
    opened = 0;
    sync = QuickAccessSync(
      shortcuts: sc, widget: wd, alters: alters, front: front,
      onOpenSwitch: () => opened++,
    );
  });
  tearDown(() => sync.dispose());

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  test('with no alters nothing crashes: no shortcuts, a friendly widget text', () async {
    await sync.start();
    expect(sc.last, isEmpty);
    expect(wd.text, 'Nobody marked as out');
  });

  test('shortcuts are the 4 most recent distinct alters, newest first, as front:<id>', () async {
    final ids = <String>[];
    for (final n in ['A', 'B', 'C', 'D', 'E']) {
      ids.add((await alters.create(name: n)).id);
    }
    await sync.start();
    for (final id in ids) {
      now = now.add(const Duration(hours: 1));
      await front.set(primary: id);
    }
    await settle();
    expect(sc.last.map((e) => e.title), ['E', 'D', 'C', 'B']);
    expect(sc.last.first.type, 'front:${ids.last}');
  });

  test('archived or removed alters are not offered', () async {
    final a = await alters.create(name: 'A');
    final b = await alters.create(name: 'B');
    await sync.start();
    await front.set(primary: a.id);
    now = now.add(const Duration(hours: 1));
    await front.set(primary: b.id);
    await alters.setArchived(a.id, true);
    await settle();
    expect(sc.last.map((e) => e.title), ['B']);
    await alters.delete(b.id);
    await settle();
    expect(sc.last, isEmpty);
  });

  test('the widget text follows who is out and is not resent when unchanged', () async {
    final a = await alters.create(name: 'Bob');
    final c = await alters.create(name: 'Cat');
    await sync.start();
    await front.set(primary: a.id, coFront: [c.id]);
    await settle();
    expect(wd.text, 'Bob (with Cat)');
    final updates = wd.updates;
    await front.load();
    await settle();
    expect(wd.updates, updates);
    await front.clear();
    await settle();
    expect(wd.text, 'Nobody marked as out');
  });

  test('choosing a shortcut switches to that alter; bad or stale ones are ignored', () async {
    final a = await alters.create(name: 'A');
    final b = await alters.create(name: 'B');
    await sync.start();
    await sc.select!('front:${b.id}');
    expect(front.primaryId, b.id);
    await sc.select!('front:nobody');
    await sc.select!('something-else');
    await sc.select!('front:');
    expect(front.primaryId, b.id);
    await alters.setArchived(a.id, true);
    await sc.select!('front:${a.id}');
    expect(front.primaryId, b.id);
  });

  test('widget taps and launching from the widget open the switch sheet', () async {
    wd.launched = true;
    await sync.start();
    expect(opened, 1);
    wd.ctrl.add(null);
    await settle();
    expect(opened, 2);
  });
}
