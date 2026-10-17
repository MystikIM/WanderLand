import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'front_notification_sync.dart';

class LocalNotifierPort implements NotifierPort {
  final _plugin = FlutterLocalNotificationsPlugin();
  static const _frontId = 1;
  static const _testId = 2;
  static const _checkInBase = 100;

  @override
  Future<bool> init({required void Function() onTap}) async {
    tzdata.initializeTimeZones();
    final zone = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(zone.identifier));
    await _plugin.initialize(
      settings: const InitializationSettings(
          android: AndroidInitializationSettings('@drawable/ic_stat_wanderland')),
      onDidReceiveNotificationResponse: (_) => onTap(),
    );
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    final launch = await _plugin.getNotificationAppLaunchDetails();
    return launch?.didNotificationLaunchApp ?? false;
  }

  @override
  Future<void> showFront(String text, {required bool private}) => _plugin.show(
        id: _frontId,
        title: 'Currently out',
        body: text,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            'front',
            'Who is out',
            channelDescription: 'Shows who is out right now',
            importance: Importance.low,
            priority: Priority.low,
            ongoing: true,
            onlyAlertOnce: true,
            visibility: private ? NotificationVisibility.private : NotificationVisibility.public,
          ),
        ),
        payload: 'switch',
      );

  @override
  Future<void> clearFront() => _plugin.cancel(id: _frontId);

  static const _checkInDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      'checkin',
      'Check-in reminders',
      channelDescription: 'Gentle reminders to check in',
      visibility: NotificationVisibility.private,
    ),
  );

  tz.TZDateTime _next(int h, int m) {
    final now = tz.TZDateTime.now(tz.local);
    var t = tz.TZDateTime(tz.local, now.year, now.month, now.day, h, m);
    if (!t.isAfter(now)) t = t.add(const Duration(days: 1));
    return t;
  }

  @override
  Future<void> scheduleCheckIns(List<(int, int)> times) async {
    await cancelCheckIns();
    for (var i = 0; i < times.length && i < 8; i++) {
      final (h, m) = times[i];
      await _plugin.zonedSchedule(
        id: _checkInBase + i,
        title: "Who's out right now?",
        body: 'Tap to update',
        scheduledDate: _next(h, m),
        notificationDetails: _checkInDetails,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: 'switch',
      );
    }
  }

  @override
  Future<void> cancelCheckIns() async {
    for (var i = 0; i < 8; i++) {
      await _plugin.cancel(id: _checkInBase + i);
    }
  }

  @override
  Future<void> showTest() => _plugin.show(
        id: _testId,
        title: "Who's out right now?",
        body: 'This is how a check-in reminder looks.',
        notificationDetails: _checkInDetails,
        payload: 'switch',
      );
}
