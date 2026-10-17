import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/alter_controller.dart';
import '../controllers/buddy_controller.dart';
import '../controllers/front_controller.dart';
import '../controllers/settings_controller.dart';
import '../domain/buddy.dart';
import '../domain/little.dart';
import '../domain/rewards.dart';
import 'art.dart';
import 'buddy_view.dart';
import 'little_scope.dart';

class BuddyScreen extends StatefulWidget {
  const BuddyScreen({super.key});
  @override
  State<BuddyScreen> createState() => _BuddyScreenState();
}

class _BuddyScreenState extends State<BuddyScreen> {
  late final TextEditingController _name =
      TextEditingController(text: context.read<BuddyController>().state.name);

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final b = context.watch<BuddyController>();
    final alters = context.watch<AlterController>();
    final front = context.watch<FrontController>();
    final id = front.primaryId;
    final alter = id == null ? null : alters.byId(id);
    final color = alter != null ? Color(alter.colorValue) : Theme.of(context).colorScheme.primary;
    final settings = context.watch<SettingsController>();
    final allowed = riskyActionsAllowed(currentLittleLevel(context),
        guardOn: settings.profile.littleGuard);

    return Scaffold(
      appBar: AppBar(title: const Text('Buddy & badges')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        const Text(
            'Missing a day never takes anything away. Your buddy and your badges are always here for you. 💜'),
        const SizedBox(height: 12),
        Center(
          child: BuddyView(
            species: b.state.species,
            color: color,
            mood: b.state.moodAt(b.clock()),
            size: 140,
            reaction: b.lastAction,
            reactionTick: b.actionTick,
          ),
        ),
        SwitchListTile(
          key: const Key('buddy-enabled'),
          title: const Text('Show my buddy'),
          value: b.state.enabled,
          onChanged: b.setEnabled,
        ),
        SwitchListTile(
          key: const Key('buddy-classic'),
          title: const Text('Classic mode (nostalgia)'),
          subtitle: Text(allowed
              ? 'Like an old virtual pet: if nobody visits for 7 days, your buddy passes away. Off by default.'
              : 'A grown-up alter needs to change this one.'),
          value: b.state.classic,
          onChanged: !allowed
              ? null
              : (v) async {
                  if (!v) {
                    await b.setClassic(false);
                    return;
                  }
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Turn on Classic mode?'),
                      content: const Text(
                          'If you do not open the app or care for your buddy for 7 days, they will pass away. '
                          'You can always hatch a new egg, and your badges are never lost. '
                          'Turning this off again brings your last buddy back.'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Not now')),
                        FilledButton(
                          key: const Key('classic-confirm'),
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Turn on'),
                        ),
                      ],
                    ),
                  );
                  if (ok == true) await b.setClassic(true);
                },
        ),
        if (b.state.memorial.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text('In loving memory', style: Theme.of(context).textTheme.titleMedium),
          for (var i = 0; i < b.state.memorial.length; i++)
            ListTile(
              key: Key('memorial-$i'),
              leading: const ArtImage('buddy_memorial_star',
                  width: 36, height: 36, fallback: Text('💫', style: TextStyle(fontSize: 24))),
              title: Text('${b.state.memorial[i].name} (${b.state.memorial[i].species})'),
              subtitle: Text(
                  'Passed ${b.state.memorial[i].passedAt.toIso8601String().substring(0, 10)}'),
            ),
        ],
        Row(children: [
          Expanded(
            child: TextField(
              key: const Key('buddy-name'),
              controller: _name,
              decoration: const InputDecoration(labelText: "Buddy's name"),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            key: const Key('buddy-rename'),
            onPressed: () => b.rename(_name.text),
            child: const Text('Save'),
          ),
        ]),
        const SizedBox(height: 16),
        const Text('Kind of buddy'),
        Wrap(spacing: 8, children: [
          // 'rabbit' looked too much like 'bunny', so it is not offered any more
          // (anyone who already has one keeps it).
          for (final sp in kBuddySpecies.where((s) => s != 'rabbit' || b.state.species == 'rabbit'))
            ChoiceChip(
              key: Key('species-$sp'),
              label: Text(sp),
              selected: b.state.species == sp,
              onSelected: (_) => b.setSpecies(sp),
            ),
        ]),
        const Divider(height: 32),
        Text('Badges', style: Theme.of(context).textTheme.titleMedium),
        for (final badge in kBadges)
          ListTile(
            key: Key('badge-${badge.id}'),
            leading: b.earned.containsKey(badge.id)
                ? ArtImage(badgeArtName(badge.id),
                    width: 48,
                    height: 48,
                    fallback: Text(badge.emoji, style: const TextStyle(fontSize: 26)))
                : LockedArt(badgeArtName(badge.id),
                    size: 48, fallback: const Text('🔒', style: TextStyle(fontSize: 26))),
            title: Text(badge.title),
            subtitle: Text(b.earned.containsKey(badge.id) ? 'Earned' : 'Locked: ${badge.how}'),
          ),
      ]),
    );
  }
}
