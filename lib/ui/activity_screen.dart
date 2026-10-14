import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/alter_controller.dart';
import '../controllers/front_controller.dart';
import '../domain/activity.dart';

String formatDuration(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes % 60;
  if (h == 0 && m == 0) return '<1m';
  if (h == 0) return '${m}m';
  return m == 0 ? '${h}h' : '${h}h ${m}m';
}

const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});
  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  DateTime? _weekStart;

  @override
  Widget build(BuildContext context) {
    final front = context.watch<FrontController>();
    final alters = context.watch<AlterController>();
    final now = front.clock();
    final thisWeek = Activity.weekStart(now);
    final start = _weekStart ?? thisWeek;
    final end = DateTime(start.year, start.month, start.day + 6);
    final days = Activity.weekDays(front.history, start, now);
    final totals = Activity.weekTotals(days);
    final sorted = totals.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    Color colorOf(String id) => Color(alters.byId(id)?.colorValue ?? 0xFF888888);

    return Scaffold(
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Row(children: [
          IconButton(
            key: const Key('prev-week'),
            icon: const Icon(Icons.chevron_left),
            onPressed: () => setState(
                () => _weekStart = DateTime(start.year, start.month, start.day - 7)),
          ),
          Expanded(
            child: Text(
              '${_months[start.month - 1]} ${start.day} – ${_months[end.month - 1]} ${end.day}',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          IconButton(
            key: const Key('next-week'),
            icon: const Icon(Icons.chevron_right),
            onPressed: start.isBefore(thisWeek)
                ? () => setState(
                    () => _weekStart = DateTime(start.year, start.month, start.day + 7))
                : null,
          ),
        ]),
        const SizedBox(height: 8),
        if (sorted.isEmpty)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              start == thisWeek ? 'Nothing logged this week yet.' : 'Nothing logged this week.',
              textAlign: TextAlign.center,
            ),
          )
        else ...[
          for (var i = 0; i < 7; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(children: [
                SizedBox(width: 40, child: Text(_days[i])),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      height: 18,
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      child: LayoutBuilder(builder: (_, box) {
                        final entries = days[i].entries.toList();
                        return Row(children: [
                          for (final e in entries)
                            Container(
                              width: box.maxWidth * (e.value.inMinutes / 1440).clamp(0.0, 1.0),
                              color: colorOf(e.key),
                            ),
                        ]);
                      }),
                    ),
                  ),
                ),
              ]),
            ),
          const Divider(height: 32),
          for (final e in sorted)
            ListTile(
              key: Key('total-${e.key}'),
              dense: true,
              leading: CircleAvatar(radius: 8, backgroundColor: colorOf(e.key)),
              title: Text(alters.label(e.key)),
              trailing: Text(formatDuration(e.value)),
            ),
        ],
      ]),
    );
  }
}
