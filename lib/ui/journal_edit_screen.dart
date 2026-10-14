import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:provider/provider.dart';
import '../controllers/alter_controller.dart';
import '../controllers/front_controller.dart';
import '../controllers/journal_controller.dart';
import '../domain/journal.dart';

class JournalEditScreen extends StatefulWidget {
  const JournalEditScreen({super.key, this.existing});
  final JournalEntry? existing;
  @override
  State<JournalEditScreen> createState() => _JournalEditScreenState();
}

class _JournalEditScreenState extends State<JournalEditScreen> {
  late final _title = TextEditingController(text: widget.existing?.title ?? '');
  late final _body = TextEditingController(text: widget.existing?.body ?? '');
  late String? _author = widget.existing?.authorAlterId ?? context.read<FrontController>().primaryId;
  bool _preview = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final j = context.read<JournalController>();
    final nav = Navigator.of(context);
    try {
      if (widget.existing == null) {
        await j.create(title: _title.text, body: _body.text, authorAlterId: _author);
      } else {
        if (_title.text.trim().isEmpty && _body.text.trim().isEmpty) {
          throw ArgumentError('Write a title or something in the entry first');
        }
        await j.update(widget.existing!.copyWith(
          title: _title.text.trim(),
          body: _body.text,
          authorAlterId: _author,
          clearAuthor: _author == null,
        ));
      }
      nav.pop();
    } on ArgumentError catch (e) {
      setState(() => _error = '${e.message}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final alters = context.watch<AlterController>();
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing == null ? 'New entry' : 'Entry'),
        actions: [
          if (widget.existing != null)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Delete',
              onPressed: () async {
                final j = context.read<JournalController>();
                final nav = Navigator.of(context);
                await j.delete(widget.existing!.id);
                nav.pop();
              },
            ),
        ],
      ),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        TextField(
          key: const Key('journal-title'),
          controller: _title,
          decoration: const InputDecoration(labelText: 'Title'),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String?>(
          initialValue: alters.byId(_author ?? '') == null ? null : _author,
          decoration: const InputDecoration(labelText: 'Written by'),
          items: [
            const DropdownMenuItem(value: null, child: Text('Nobody in particular')),
            for (final a in alters.active) DropdownMenuItem(value: a.id, child: Text(a.name)),
          ],
          onChanged: (v) => setState(() => _author = v),
        ),
        const SizedBox(height: 12),
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: false, label: Text('Write')),
            ButtonSegment(value: true, label: Text('Preview')),
          ],
          selected: {_preview},
          onSelectionChanged: (v) => setState(() => _preview = v.first),
        ),
        const SizedBox(height: 12),
        if (_preview)
          MarkdownBody(data: _body.text)
        else
          TextField(
            key: const Key('journal-body'),
            controller: _body,
            minLines: 8,
            maxLines: null,
            decoration: const InputDecoration(labelText: 'What is on your mind? (Markdown works)'),
          ),
        if (_error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_error!)),
        const SizedBox(height: 16),
        FilledButton(key: const Key('journal-save'), onPressed: _save, child: const Text('Save')),
      ]),
    );
  }
}
