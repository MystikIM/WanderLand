class NotifyPrefs {
  const NotifyPrefs({
    this.frontNotification = true,
    this.privateOnLockScreen = true,
    this.reminders = false,
    this.times = const ['09:00', '20:00'],
  });
  final bool frontNotification;
  final bool privateOnLockScreen;
  final bool reminders;
  final List<String> times;

  NotifyPrefs copyWith({
    bool? frontNotification,
    bool? privateOnLockScreen,
    bool? reminders,
    List<String>? times,
  }) =>
      NotifyPrefs(
        frontNotification: frontNotification ?? this.frontNotification,
        privateOnLockScreen: privateOnLockScreen ?? this.privateOnLockScreen,
        reminders: reminders ?? this.reminders,
        times: times ?? this.times,
      );

  Map<String, dynamic> toJson() => {
        'id': 'notify',
        'frontNotification': frontNotification,
        'privateOnLockScreen': privateOnLockScreen,
        'reminders': reminders,
        'times': times,
      };

  factory NotifyPrefs.fromJson(Map<String, dynamic> j) => NotifyPrefs(
        frontNotification: j['frontNotification'] as bool? ?? true,
        privateOnLockScreen: j['privateOnLockScreen'] as bool? ?? true,
        reminders: j['reminders'] as bool? ?? false,
        times: List<String>.from(j['times'] as List? ?? const ['09:00', '20:00']),
      );
}

(int, int)? parseTime(String s) {
  final m = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(s.trim());
  if (m == null) return null;
  final h = int.parse(m.group(1)!);
  final mi = int.parse(m.group(2)!);
  if (h > 23 || mi > 59) return null;
  return (h, mi);
}

String formatTime(int h, int m) =>
    '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';

List<(int, int)> validTimes(List<String> raw, {int max = 8}) {
  final set = <(int, int)>{
    for (final r in raw)
      if (parseTime(r) != null) parseTime(r)!,
  };
  final list = set.toList()
    ..sort((a, b) => a.$1 != b.$1 ? a.$1.compareTo(b.$1) : a.$2.compareTo(b.$2));
  return list.take(max).toList();
}
