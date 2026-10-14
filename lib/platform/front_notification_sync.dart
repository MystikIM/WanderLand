import 'dart:async';
import '../controllers/alter_controller.dart';
import '../controllers/front_controller.dart';
import '../controllers/settings_controller.dart';
import '../domain/front_service.dart';
import '../domain/reminders.dart';

abstract class NotifierPort {
  /// Returns true if the app was opened by tapping one of our notifications.
  Future<bool> init({required void Function() onTap});
  Future<void> showFront(String text, {required bool private});
  Future<void> clearFront();
  Future<void> scheduleCheckIns(List<(int, int)> times);
  Future<void> cancelCheckIns();
  Future<void> showTest();
}

class FrontNotificationSync {
  FrontNotificationSync({
    required this.port,
    required this.settings,
    required this.alters,
    required this.front,
    required this.onOpenSwitch,
  });

  final NotifierPort port;
  final SettingsController settings;
  final AlterController alters;
  final FrontController front;
  final void Function() onOpenSwitch;

  String? _lastFront;
  String? _lastSchedule;
  bool _started = false;
  Future<void> _queue = Future.value();

  Future<void> start() async {
    final launchedByTap = await port.init(onTap: onOpenSwitch);
    settings.addListener(_enqueue);
    alters.addListener(_enqueue);
    front.addListener(_enqueue);
    _started = true;
    await _run();
    if (launchedByTap) onOpenSwitch();
  }

  void dispose() {
    settings.removeListener(_enqueue);
    alters.removeListener(_enqueue);
    front.removeListener(_enqueue);
  }

  void _enqueue() {
    if (!_started) return;
    _queue = _queue.then((_) => _run());
  }

  Future<void> _run() async {
    final p = settings.notify;
    final wantText = (p.frontNotification && front.current.isNotEmpty)
        ? describeFront(front.current, alters.label)
        : null;
    final frontKey = wantText == null ? 'none' : '$wantText|${p.privateOnLockScreen}';
    if (frontKey != _lastFront) {
      _lastFront = frontKey;
      if (wantText == null) {
        await port.clearFront();
      } else {
        await port.showFront(wantText, private: p.privateOnLockScreen);
      }
    }

    final times = p.reminders ? validTimes(p.times) : <(int, int)>[];
    final scheduleKey = times.map((t) => formatTime(t.$1, t.$2)).join(',');
    if (scheduleKey != _lastSchedule) {
      final first = _lastSchedule == null;
      _lastSchedule = scheduleKey;
      if (times.isEmpty) {
        if (!first) await port.cancelCheckIns();
      } else {
        await port.scheduleCheckIns(times);
      }
    }
  }
}
