import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/alter_controller.dart';
import '../controllers/front_controller.dart';
import '../controllers/settings_controller.dart';
import '../domain/activity.dart';
import '../domain/little.dart';
import '../domain/models.dart';
import 'alters_screen.dart' show AlterAvatar;
import 'little_scope.dart';

Future<void> showSwitchSheet(BuildContext context) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _SwitchSheet(),
    );

class _SwitchSheet extends StatefulWidget {
  const _SwitchSheet();
  @override
  State<_SwitchSheet> createState() => _SwitchSheetState();
}

class _SwitchSheetState extends State<_SwitchSheet> {
  String? _primary;
  final Set<String> _co = {};
  final _note = TextEditingController();
  bool _dismissed = false;

  @override
  void initState() {
    super.initState();
    final front = context.read<FrontController>();
    _primary = front.primaryId;
    for (final e in front.current) {
      if (e.tier == FrontTier.coFront) _co.add(e.alterId);
    }
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final alters = context.watch<AlterController>();
    final front = context.watch<FrontController>();
    final settings = context.watch<SettingsController>();
    final copy = LittleCopy(currentLittleLevel(context));
    final prefs = settings.headsUp;

    final usual = (_primary == null || !prefs.enabled)
        ? null
        : Activity.headsUp(entries: front.history, pickedAlterId: _primary!, now: front.clock());
    final showHeadsUp = usual != null &&
        !_dismissed &&
        !prefs.muted.contains(usual) &&
        alters.byId(usual) != null;

    return Padding(
      padding: EdgeInsets.only(
        left: 16, right: 16, top: 4,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(copy('whosOut'), style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final a in alters.active)
              ChoiceChip(
                key: Key('pick-${a.id}'),
                avatar: AlterAvatar(alter: a, radius: 12),
                label: Text(a.name),
                selected: _primary == a.id,
                onSelected: (_) => setState(() {
                  _primary = a.id;
                  _co.remove(a.id);
                  _dismissed = false;
                }),
              ),
          ]),
          if (showHeadsUp)
            Card(
              key: const Key('heads-up'),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${alters.label(usual)} is often out around now.'),
                  Wrap(children: [
                    TextButton(
                      onPressed: () => setState(() => _dismissed = true),
                      child: const Text('Got it'),
                    ),
                    TextButton(
                      key: const Key('mute-heads-up'),
                      onPressed: () => settings.setHeadsUp(
                          prefs.copyWith(muted: [...prefs.muted, usual])),
                      child: Text("Don't remind me about ${alters.label(usual)}"),
                    ),
                  ]),
                ]),
              ),
            ),
          if (_primary != null && alters.active.length > 1) ...[
            const SizedBox(height: 12),
            const Text('Also out (co-front)'),
            Wrap(spacing: 8, children: [
              for (final a in alters.active.where((a) => a.id != _primary))
                FilterChip(
                  label: Text(a.name),
                  selected: _co.contains(a.id),
                  onSelected: (v) => setState(() => v ? _co.add(a.id) : _co.remove(a.id)),
                ),
            ]),
          ],
          const SizedBox(height: 12),
          TextField(
            controller: _note,
            decoration: const InputDecoration(labelText: 'A note (optional)'),
          ),
          const SizedBox(height: 16),
          Row(children: [
            TextButton(
              key: const Key('switch-nobody'),
              onPressed: () async {
                final nav = Navigator.of(context);
                await front.clear();
                nav.pop();
              },
              child: const Text('Nobody / not sure'),
            ),
            const Spacer(),
            FilledButton(
              key: const Key('switch-confirm'),
              onPressed: _primary == null
                  ? null
                  : () async {
                      final nav = Navigator.of(context);
                      await front.set(
                        primary: _primary!,
                        coFront: _co.where((x) => x != _primary).toList(),
                        note: _note.text.trim(),
                      );
                      nav.pop();
                    },
              child: Text(copy('done')),
            ),
          ]),
        ]),
      ),
    );
  }
}
