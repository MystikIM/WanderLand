import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/settings_controller.dart';
import '../domain/reminders.dart';
import '../platform/front_notification_sync.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key, this.pickTime});
  final Future<TimeOfDay?> Function(BuildContext)? pickTime;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<SettingsController>();
    final n = s.notify;
    final sorted = validTimes(n.times).map((t) => formatTime(t.$1, t.$2)).toList();

    Future<void> add() async {
      final t = await (pickTime ??
          (c) => showTimePicker(context: c, initialTime: const TimeOfDay(hour: 12, minute: 0)))(context);
      if (t == null) return;
      await s.setNotify(n.copyWith(times: validTimes([...n.times, formatTime(t.hour, t.minute)])
          .map((x) => formatTime(x.$1, x.$2))
          .toList()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: ListView(children: [
        SwitchListTile(
          key: const Key('notify-front'),
          title: const Text('Show who is out'),
          subtitle: const Text('A quiet notification while someone is out. Tap it to switch.'),
          value: n.frontNotification,
          onChanged: (v) => s.setNotify(n.copyWith(frontNotification: v)),
        ),
        SwitchListTile(
          key: const Key('notify-private'),
          title: const Text('Hide names on the lock screen'),
          subtitle: const Text('Others who glance at your phone will not see who is out.'),
          value: n.privateOnLockScreen,
          onChanged: (v) => s.setNotify(n.copyWith(privateOnLockScreen: v)),
        ),
        const Divider(),
        SwitchListTile(
          key: const Key('notify-reminders'),
          title: const Text('Gentle check-in reminders'),
          subtitle: const Text('A soft "Who\'s out right now?" at times you choose. Off until you turn it on.'),
          value: n.reminders,
          onChanged: (v) => s.setNotify(n.copyWith(reminders: v)),
        ),
        for (final t in sorted)
          ListTile(
            dense: true,
            leading: const Icon(Icons.alarm),
            title: Text(t),
            trailing: IconButton(
              key: Key('remove-$t'),
              icon: const Icon(Icons.close),
              onPressed: () => s.setNotify(n.copyWith(times: sorted.where((x) => x != t).toList())),
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              key: const Key('add-time'),
              onPressed: sorted.length >= 8 ? null : add,
              icon: const Icon(Icons.add),
              label: Text(sorted.length >= 8 ? 'That is the most (8)' : 'Add a time'),
            ),
          ),
        ),
        const Divider(),
        ListTile(
          key: const Key('notify-test'),
          leading: const Icon(Icons.notifications_active_outlined),
          title: const Text('Send a test'),
          onTap: () => context.read<NotifierPort>().showTest(),
        ),
      ]),
    );
  }
}
