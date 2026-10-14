import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../controllers/alter_controller.dart';
import '../data/image_store.dart';
import '../domain/models.dart';
import '../domain/pronouns.dart';
import 'appearance_screen.dart' show kSwatches;

class AlterEditScreen extends StatefulWidget {
  const AlterEditScreen({super.key, this.existing});
  final Alter? existing;
  @override
  State<AlterEditScreen> createState() => _AlterEditScreenState();
}

class _AlterEditScreenState extends State<AlterEditScreen> {
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late final _pronouns = TextEditingController(text: widget.existing?.pronouns ?? '');
  late final _role = TextEditingController(text: widget.existing?.role ?? '');
  late final _bio = TextEditingController(text: widget.existing?.bio ?? '');
  late final _tags = TextEditingController(text: (widget.existing?.tags ?? []).join(', '));
  late final _groups = TextEditingController(text: (widget.existing?.groups ?? []).join(', '));
  late int _color = widget.existing?.colorValue ?? 0xFF9B5DE5;
  late String? _image = widget.existing?.imagePath;
  late String? _banner = widget.existing?.bannerPath;
  late final List<MapEntry<TextEditingController, TextEditingController>> _fields = [
    for (final e in (widget.existing?.customFields ?? {}).entries)
      MapEntry(TextEditingController(text: e.key), TextEditingController(text: e.value)),
  ];
  late final _age = TextEditingController(text: widget.existing?.ageYears?.toString() ?? '');
  late String _littleMode = widget.existing?.littleMode ?? 'auto';
  String? _nameError;
  String? _ageError;

  List<String> _split(String s) =>
      s.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

  Future<void> _pick(bool banner) async {
    final images = context.read<ImageStore>();
    final x = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1600);
    if (x == null) return;
    final rel = await images.save(File(x.path));
    if (!mounted) return;
    setState(() => banner ? _banner = rel : _image = rel);
  }

  Future<void> _save() async {
    final alters = context.read<AlterController>();
    final nav = Navigator.of(context);
    if (_name.text.trim().isEmpty) {
      setState(() => _nameError = 'Please give them a name');
      return;
    }
    int? age;
    if (_age.text.trim().isNotEmpty) {
      age = int.tryParse(_age.text.trim());
      if (age == null || age < 0 || age > 150) {
        setState(() => _ageError = 'Please use a number');
        return;
      }
    }
    setState(() => _ageError = null);
    final base = widget.existing ?? await alters.create(name: _name.text);
    await alters.save(base.copyWith(
      ageYears: age,
      clearAge: age == null,
      littleMode: _littleMode,
      name: _name.text.trim(),
      pronouns: _pronouns.text.trim(),
      role: _role.text.trim(),
      colorValue: _color,
      bio: _bio.text,
      imagePath: _image,
      bannerPath: _banner,
      tags: _split(_tags.text),
      groups: _split(_groups.text),
      customFields: {
        for (final f in _fields)
          if (f.key.text.trim().isNotEmpty) f.key.text.trim(): f.value.text.trim(),
      },
    ));
    nav.pop();
  }

  @override
  Widget build(BuildContext context) {
    final alters = context.read<AlterController>();
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing == null ? 'New' : 'Edit'),
        actions: [
          if (widget.existing != null)
            PopupMenuButton<String>(
              onSelected: (v) async {
                final nav = Navigator.of(context);
                if (v == 'archive') {
                  await alters.setArchived(widget.existing!.id, !widget.existing!.archived);
                } else {
                  await alters.delete(widget.existing!.id);
                }
                nav.popUntil((r) => r.isFirst);
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'archive',
                  child: Text(widget.existing!.archived ? 'Unarchive' : 'Archive'),
                ),
                const PopupMenuItem(value: 'delete', child: Text('Delete for good')),
              ],
            ),
        ],
      ),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        TextField(
          key: const Key('alter-name'),
          controller: _name,
          decoration: InputDecoration(labelText: 'Name', errorText: _nameError),
        ),
        const SizedBox(height: 12),
        Wrap(spacing: 8, children: [
          for (final p in kPronounPresets)
            ChoiceChip(
              label: Text(p),
              selected: _pronouns.text == p,
              onSelected: (_) => setState(() => _pronouns.text = p),
            ),
        ]),
        const SizedBox(height: 8),
        TextField(
          key: const Key('alter-pronouns'),
          controller: _pronouns,
          decoration: const InputDecoration(labelText: 'Pronouns (type your own if you like)'),
        ),
        const SizedBox(height: 12),
        TextField(controller: _role, decoration: const InputDecoration(labelText: 'Role')),
        const SizedBox(height: 12),
        TextField(
          key: const Key('alter-age'),
          controller: _age,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(labelText: 'Age (how old they feel; optional)', errorText: _ageError),
        ),
        const SizedBox(height: 8),
        SegmentedButton<String>(
          key: const Key('alter-little-mode'),
          segments: const [
            ButtonSegment(value: 'auto', label: Text('Little: auto')),
            ButtonSegment(value: 'on', label: Text('Always')),
            ButtonSegment(value: 'off', label: Text('Never')),
          ],
          selected: {_littleMode},
          onSelectionChanged: (v) => setState(() => _littleMode = v.first),
        ),
        const Padding(
          padding: EdgeInsets.only(top: 4),
          child: Text('Auto: a kid-friendly look appears when this person is out and under 13.'),
        ),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final c in kSwatches)
            GestureDetector(
              onTap: () => setState(() => _color = c),
              child: Container(
                width: 34, height: 34,
                decoration: BoxDecoration(
                  color: Color(c), shape: BoxShape.circle,
                  border: Border.all(width: c == _color ? 3 : 1, color: Colors.white70),
                ),
              ),
            ),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          OutlinedButton.icon(
            onPressed: () => _pick(false),
            icon: const Icon(Icons.image),
            label: Text(_image == null ? 'Add picture' : 'Change picture'),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: () => _pick(true),
            icon: const Icon(Icons.panorama),
            label: Text(_banner == null ? 'Add banner' : 'Change banner'),
          ),
        ]),
        const SizedBox(height: 12),
        TextField(
          controller: _bio,
          minLines: 3,
          maxLines: 10,
          decoration: const InputDecoration(labelText: 'About (Markdown works)'),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const Key('alter-tags'),
          controller: _tags,
          decoration: const InputDecoration(labelText: 'Tags (comma separated)'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _groups,
          decoration: const InputDecoration(labelText: 'Groups (comma separated)'),
        ),
        const SizedBox(height: 12),
        for (var i = 0; i < _fields.length; i++)
          Row(children: [
            Expanded(child: TextField(controller: _fields[i].key, decoration: const InputDecoration(labelText: 'Field'))),
            const SizedBox(width: 8),
            Expanded(child: TextField(controller: _fields[i].value, decoration: const InputDecoration(labelText: 'Value'))),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => setState(() => _fields.removeAt(i)),
            ),
          ]),
        TextButton.icon(
          onPressed: () => setState(() => _fields.add(
              MapEntry(TextEditingController(), TextEditingController()))),
          icon: const Icon(Icons.add),
          label: const Text('Add a custom field'),
        ),
        const SizedBox(height: 16),
        FilledButton(key: const Key('save-alter'), onPressed: _save, child: const Text('Save')),
      ]),
    );
  }
}
