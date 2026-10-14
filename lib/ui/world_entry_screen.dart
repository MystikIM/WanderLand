import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/alter_controller.dart';
import '../controllers/world_controller.dart';
import '../domain/alter_links.dart';
import '../domain/world.dart';
import 'alter_link_nav.dart';
import 'alters_screen.dart' show AlterAvatar;
import 'linked_text.dart';

class WorldEntryScreen extends StatefulWidget {
  const WorldEntryScreen({super.key, this.existing});
  final WorldEntry? existing;
  @override
  State<WorldEntryScreen> createState() => _WorldEntryScreenState();
}

class _WorldEntryScreenState extends State<WorldEntryScreen> {
  late final _title = TextEditingController(text: widget.existing?.title ?? '');
  late final _text = TextEditingController(text: widget.existing?.text ?? '');
  String? _error;
  bool _read = false;

  @override
  void dispose() {
    _title.dispose();
    _text.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final world = context.read<WorldController>();
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final List<String> grown;
      if (widget.existing == null) {
        grown = await world.addEntry(title: _title.text, text: _text.text);
      } else {
        if (_title.text.trim().isEmpty && _text.text.trim().isEmpty) {
          throw ArgumentError('Write a title or something about your world first');
        }
        grown = await world.updateEntry(WorldEntry(
          id: widget.existing!.id,
          title: _title.text.trim(),
          text: _text.text,
          createdAt: widget.existing!.createdAt,
          updatedAt: DateTime.now(),
        ));
      }
      nav.pop();
      if (grown.isNotEmpty) {
        messenger.showSnackBar(SnackBar(content: Text('Your world grew: ${grown.join(', ')} ✨')));
      }
    } on ArgumentError catch (e) {
      setState(() => _error = '${e.message}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final alters = context.watch<AlterController>();
    final names = [for (final a in alters.all) NameRef(a.id, a.name)];
    final mentioned = <String>{};
    for (final s in AlterLinker.find(_text.text, names)) {
      mentioned.addAll(s.alterIds);
    }
    return Scaffold(
        appBar: AppBar(
          title: Text(widget.existing == null ? 'Write about your world' : 'Your words'),
          actions: [
            if (widget.existing != null)
              IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Delete this entry (the pieces stay)',
                onPressed: () async {
                  final world = context.read<WorldController>();
                  final nav = Navigator.of(context);
                  await world.deleteEntry(widget.existing!.id);
                  nav.pop();
                },
              ),
          ],
        ),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          const Text(
              'Describe your inner world however it feels true to you: what it is, how it looks, who and what is there. '
              'Things you mention may appear in the picture. You are always in charge of it.'),
          const SizedBox(height: 12),
          TextField(
            key: const Key('world-title'),
            controller: _title,
            decoration: const InputDecoration(labelText: 'Title (optional)'),
          ),
          const SizedBox(height: 12),
          SegmentedButton<bool>(
            key: const Key('world-mode'),
            segments: const [
              ButtonSegment(value: false, label: Text('Write')),
              ButtonSegment(value: true, label: Text('Read')),
            ],
            selected: {_read},
            onSelectionChanged: (v) => setState(() => _read = v.first),
          ),
          const SizedBox(height: 12),
          if (_read)
            LinkedText(
              text: _text.text,
              names: names,
              onTap: (ids) => openAlterLink(context, ids),
            )
          else
            TextField(
              key: const Key('world-text'),
              controller: _text,
              minLines: 8,
              maxLines: null,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(labelText: 'Your words'),
            ),
          if (mentioned.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text('Mentioned'),
            Wrap(spacing: 8, children: [
              for (final id in mentioned)
                if (alters.byId(id) != null)
                  ActionChip(
                    key: Key('mention-$id'),
                    avatar: AlterAvatar(alter: alters.byId(id)!, radius: 12),
                    label: Text(alters.byId(id)!.name),
                    onPressed: () => openAlterLink(context, [id]),
                  ),
            ]),
          ],
          if (_error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_error!)),
          const SizedBox(height: 16),
          FilledButton(key: const Key('world-save'), onPressed: _save, child: const Text('Save')),
        ]),
      );
  }
}
