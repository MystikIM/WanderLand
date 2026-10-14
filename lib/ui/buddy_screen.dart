import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/alter_controller.dart';
import '../controllers/buddy_controller.dart';
import '../controllers/front_controller.dart';
import '../domain/buddy.dart';
import '../domain/rewards.dart';
import 'buddy_view.dart';

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
    final unlocked = b.unlocked;

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
            accessory: b.state.accessory,
            size: 140,
          ),
        ),
        SwitchListTile(
          key: const Key('buddy-enabled'),
          title: const Text('Show my buddy'),
          value: b.state.enabled,
          onChanged: b.setEnabled,
        ),
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
          for (final sp in kBuddySpecies)
            ChoiceChip(
              key: Key('species-$sp'),
              label: Text(sp),
              selected: b.state.species == sp,
              onSelected: (_) => b.setSpecies(sp),
            ),
        ]),
        const SizedBox(height: 16),
        const Text('Accessory'),
        Wrap(spacing: 8, children: [
          ChoiceChip(
            key: const Key('acc-none'),
            label: const Text('none'),
            selected: b.state.accessory.isEmpty,
            onSelected: (_) => b.setAccessory(''),
          ),
          for (final a in kAccessories)
            ChoiceChip(
              key: Key('acc-$a'),
              label: Text(unlocked.contains(a) ? a : '🔒 $a'),
              selected: b.state.accessory == a,
              onSelected: unlocked.contains(a) ? (_) => b.setAccessory(a) : null,
            ),
        ]),
        const Divider(height: 32),
        Text('Badges', style: Theme.of(context).textTheme.titleMedium),
        for (final badge in kBadges)
          ListTile(
            key: Key('badge-${badge.id}'),
            leading: Text(b.earned.containsKey(badge.id) ? badge.emoji : '🔒',
                style: const TextStyle(fontSize: 26)),
            title: Text(badge.title),
            subtitle: Text(b.earned.containsKey(badge.id) ? 'Earned' : 'Locked: ${badge.how}'),
          ),
      ]),
    );
  }
}
