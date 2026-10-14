import 'dart:async';
import '../controllers/alter_controller.dart';
import '../controllers/front_controller.dart';
import '../domain/activity.dart';
import '../domain/front_service.dart';
import '../domain/models.dart';

class ShortcutEntry {
  const ShortcutEntry({required this.type, required this.title});
  final String type;
  final String title;
}

abstract class ShortcutsPort {
  Future<void> init(Future<void> Function(String type) onSelected);
  Future<void> setShortcuts(List<ShortcutEntry> entries);
}

abstract class WidgetPort {
  Future<void> updateText(String text);
  Stream<void> get clicks;
  Future<bool> launchedFromWidget();
}

class QuickAccessSync {
  QuickAccessSync({
    required this.shortcuts,
    required this.widget,
    required this.alters,
    required this.front,
    required this.onOpenSwitch,
  });

  final ShortcutsPort shortcuts;
  final WidgetPort widget;
  final AlterController alters;
  final FrontController front;
  final void Function() onOpenSwitch;

  StreamSubscription<void>? _clicks;
  String? _lastShortcuts;
  String? _lastText;
  Future<void> _queue = Future.value();
  bool _started = false;

  Future<void> start() async {
    await shortcuts.init(_onSelected);
    _clicks = widget.clicks.listen((_) => onOpenSwitch());
    alters.addListener(_enqueue);
    front.addListener(_enqueue);
    _started = true;
    await _run();
    if (await widget.launchedFromWidget()) onOpenSwitch();
  }

  void dispose() {
    alters.removeListener(_enqueue);
    front.removeListener(_enqueue);
    _clicks?.cancel();
  }

  Future<void> _onSelected(String type) async {
    if (!type.startsWith('front:')) return;
    final a = alters.byId(type.substring('front:'.length));
    if (a == null || a.archived) return;
    await front.set(primary: a.id);
  }

  void _enqueue() {
    if (!_started) return;
    _queue = _queue.then((_) => _run());
  }

  Future<void> _run() async {
    final entries = Activity.recentAlterIds(front.history, limit: 8)
        .map(alters.byId)
        .whereType<Alter>()
        .where((a) => !a.archived)
        .take(4)
        .map((a) => ShortcutEntry(type: 'front:${a.id}', title: a.name))
        .toList();
    final key = entries.map((e) => '${e.type}|${e.title}').join(';');
    if (key != _lastShortcuts) {
      _lastShortcuts = key;
      await shortcuts.setShortcuts(entries);
    }
    final text = describeFront(front.current, alters.label);
    if (text != _lastText) {
      _lastText = text;
      await widget.updateText(text);
    }
  }
}
