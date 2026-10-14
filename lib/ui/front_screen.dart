import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_info.dart';
import '../controllers/alter_controller.dart';
import '../controllers/front_controller.dart';
import '../controllers/settings_controller.dart';
import '../domain/activity.dart';
import '../domain/front_service.dart';
import '../domain/little.dart';
import '../domain/models.dart';
import 'alters_screen.dart' show AlterAvatar;
import 'buddy_card.dart';
import 'little_scope.dart';
import 'switch_sheet.dart';

class FrontScreen extends StatelessWidget {
  const FrontScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<SettingsController>();
    final alters = context.watch<AlterController>();
    final front = context.watch<FrontController>();
    final level = currentLittleLevel(context);
    final copy = LittleCopy(level);
    final t = s.terminology;

    final hello = s.profile.greeting.isNotEmpty
        ? s.profile.greeting
        : (s.profile.systemName.isNotEmpty ? s.profile.systemName : appName);
    final outNow = describeFront(front.current, alters.label);
    final avatars = front.current.map((e) => alters.byId(e.alterId)).whereType<Alter>();
    final recent = Activity.recentAlterIds(front.history, limit: 4)
        .map(alters.byId)
        .whereType<Alter>()
        .where((a) => !a.archived)
        .toList();
    final hasAlters = alters.active.isNotEmpty;

    return Scaffold(body: ListView(padding: const EdgeInsets.all(16), children: [
      Text(hello, style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 16),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Out now', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            Row(children: [
              for (final a in avatars) Padding(
                padding: const EdgeInsets.only(right: 8),
                child: AlterAvatar(alter: a, radius: 28),
              ),
              Expanded(child: Text(outNow, style: Theme.of(context).textTheme.titleLarge)),
            ]),
          ]),
        ),
      ),
      const SizedBox(height: 16),
      const BuddyCard(),
      const SizedBox(height: 16),
      if (!hasAlters)
        Text(
          level == LittleLevel.none
              ? 'Add your first ${t('alter')} on the ${t.cap('alters')} tab to get started.'
              : copy('addFirst'),
        )
      else ...[
        FilledButton.icon(
          key: const Key('open-switch'),
          onPressed: () => showSwitchSheet(context),
          icon: const Icon(Icons.swap_horiz),
          label: Text(copy('whosOut')),
        ),
        if (recent.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Text('Quick switch'),
          Wrap(spacing: 8, children: [
            for (final a in recent)
              ActionChip(
                avatar: AlterAvatar(alter: a, radius: 12),
                label: Text(a.name),
                onPressed: () => front.set(primary: a.id),
              ),
          ]),
        ],
      ],
    ]));
  }
}
