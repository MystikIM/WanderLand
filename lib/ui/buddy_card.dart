import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/alter_controller.dart';
import '../controllers/buddy_controller.dart';
import '../controllers/front_controller.dart';
import '../domain/buddy.dart';
import '../domain/little.dart';
import 'buddy_screen.dart';
import 'buddy_view.dart';

class BuddyCard extends StatelessWidget {
  const BuddyCard({super.key});

  @override
  Widget build(BuildContext context) {
    final b = context.watch<BuddyController>();
    if (!b.state.enabled) return const SizedBox.shrink();
    final alters = context.watch<AlterController>();
    final front = context.watch<FrontController>();
    final id = front.primaryId;
    final alter = id == null ? null : alters.byId(id);
    if (b.state.isPassed) {
      final soft = littleLevelOf(alter) != LittleLevel.none;
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            Text(soft ? '⭐' : '💫', style: const TextStyle(fontSize: 40)),
            const SizedBox(height: 8),
            Text(
              soft
                  ? '${b.state.name} went on a long trip to the stars. ⭐'
                  : '${b.state.name} has passed away.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (!soft) const Text('Thank you for taking care of them. 💜', textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(
              key: const Key('buddy-hatch'),
              onPressed: b.hatchNew,
              child: const Text('Hatch a new egg 🥚'),
            ),
          ]),
        ),
      );
    }
    final now = b.clock();
    final mood = b.state.moodAt(now);
    final color = alter != null ? Color(alter.colorValue) : Theme.of(context).colorScheme.primary;
    final greeting = buddyGreeting(alterName: alter?.name, mood: mood, level: littleLevelOf(alter));

    Widget act(BuddyAction a, String key, String label) => FilledButton.tonal(
          key: Key(key),
          onPressed: b.state.canCare(a, now) ? () => b.care(a) : null,
          child: Text(label),
        );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(children: [
          for (final c in b.celebrations)
            ListTile(
              key: Key('celebrate-${c.id}'),
              leading: Text(c.emoji, style: const TextStyle(fontSize: 28)),
              title: Text('New badge: ${c.title}!'),
              subtitle: Text(c.how),
            ),
          if (b.celebrations.isNotEmpty)
            TextButton(
              key: const Key('celebrate-ok'),
              onPressed: b.dismissCelebrations,
              child: const Text('Yay! 🎉'),
            ),
          Row(children: [
            BuddyView(
              species: b.state.species,
              color: color,
              mood: mood,
              accessory: b.state.accessory,
              outfit: b.state.outfit,
              size: 112,
              reaction: b.lastAction,
              reactionTick: b.actionTick,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(greeting, style: Theme.of(context).textTheme.titleMedium),
                Text(b.state.name, style: Theme.of(context).textTheme.bodySmall),
              ]),
            ),
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'hide') {
                  b.setEnabled(false);
                } else {
                  Navigator.of(context)
                      .push(MaterialPageRoute(builder: (_) => const BuddyScreen()));
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'open', child: Text('Buddy & badges')),
                PopupMenuItem(value: 'hide', child: Text('Hide my buddy')),
              ],
            ),
          ]),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 4, children: [
            for (final a in BuddyAction.values)
              act(a, 'buddy-${a.name}', kBuddyActionLabels[a]!),
          ]),
        ]),
      ),
    );
  }
}
