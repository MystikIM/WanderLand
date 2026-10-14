import 'package:home_widget/home_widget.dart';
import 'package:quick_actions/quick_actions.dart';
import 'quick_access_sync.dart';

class QuickActionsPort implements ShortcutsPort {
  final _qa = const QuickActions();

  @override
  Future<void> init(Future<void> Function(String type) onSelected) async {
    _qa.initialize((type) => onSelected(type));
  }

  @override
  Future<void> setShortcuts(List<ShortcutEntry> entries) => _qa.setShortcutItems([
        for (final e in entries) ShortcutItem(type: e.type, localizedTitle: e.title),
      ]);
}

class HomeWidgetPort implements WidgetPort {
  @override
  Future<void> updateText(String text) async {
    await HomeWidget.saveWidgetData<String>('front_text', text);
    await HomeWidget.updateWidget(androidName: 'FrontWidgetProvider');
  }

  @override
  Stream<void> get clicks => HomeWidget.widgetClicked.map((_) {});

  @override
  Future<bool> launchedFromWidget() async =>
      (await HomeWidget.initiallyLaunchedFromHomeWidget()) != null;
}
