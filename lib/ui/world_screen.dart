import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../controllers/alter_controller.dart';
import '../controllers/world_controller.dart';
import '../data/image_store.dart';
import '../domain/world.dart';
import 'alter_link_nav.dart';
import 'alters_screen.dart' show AlterAvatar;
import 'appearance_screen.dart' show kSwatches;
import 'art.dart';
import 'piece_body.dart';
import 'scene_painters.dart';
import 'world_entry_screen.dart';

class WorldScreen extends StatefulWidget {
  const WorldScreen({super.key});
  @override
  State<WorldScreen> createState() => _WorldScreenState();
}

class _WorldScreenState extends State<WorldScreen> {
  final Map<String, Offset> _drag = {};

  Future<void> _pickBackground() async {
    final world = context.read<WorldController>();
    final images = context.read<ImageStore>();
    final x = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 2000);
    if (x == null) return;
    final rel = await images.save(File(x.path));
    await world.setBackground(rel);
  }

  void _pieceSheet(SceneItem item) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => Consumer<WorldController>(
        builder: (ctx, world, _) {
          final cur = world.items.where((i) => i.id == item.id).firstOrNull;
          if (cur == null) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(cur.kind, style: Theme.of(ctx).textTheme.titleMedium),
              const SizedBox(height: 8),
              const Text('Size'),
              Slider(
                key: const Key('piece-size'),
                min: 0.3,
                max: 2.0,
                value: cur.scale.clamp(0.3, 2.0).toDouble(),
                onChanged: (v) => world.scaleItem(cur.id, v),
              ),
              const Text('Color'),
              Wrap(spacing: 8, runSpacing: 8, children: [
                ActionChip(
                  key: const Key('piece-color-original'),
                  label: const Text('original'),
                  onPressed: () => world.setColor(cur.id, null),
                ),
                for (final c in kSwatches)
                  GestureDetector(
                    key: Key('piece-color-0x${c.toRadixString(16).toUpperCase()}'),
                    onTap: () => world.setColor(cur.id, c),
                    child: CircleAvatar(radius: 16, backgroundColor: Color(c)),
                  ),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                TextButton.icon(
                  key: const Key('piece-remove'),
                  onPressed: () async {
                    final nav = Navigator.of(ctx);
                    await world.removeItem(cur.id);
                    nav.pop();
                  },
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Remove from my world'),
                ),
                const Spacer(),
                FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Done')),
              ]),
            ]),
          );
        },
      ),
    );
  }

  Widget _piece(WorldController world, SceneItem it, Size box) {
    final size = 110.0 * it.scale;
    final pos = _drag[it.id] ?? Offset(it.x, it.y);
    return Positioned(
      key: ValueKey('piece-${it.id}'),
      left: pos.dx * box.width - size / 2,
      top: pos.dy * box.height - size / 2,
      width: size,
      height: size,
      child: PieceBody(
        kind: it.kind,
        tint: it.colorValue == null ? null : Color(it.colorValue!),
        onPanUpdate: (d) => setState(() {
          final cur = _drag[it.id] ?? Offset(it.x, it.y);
          _drag[it.id] = Offset(
            (cur.dx + d.delta.dx / box.width).clamp(0.0, 1.0).toDouble(),
            (cur.dy + d.delta.dy / box.height).clamp(0.0, 1.0).toDouble(),
          );
        }),
        onPanEnd: (_) {
          final o = _drag.remove(it.id);
          if (o != null) world.moveItem(it.id, o.dx, o.dy);
        },
        onLongPress: () => _pieceSheet(it),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final world = context.watch<WorldController>();
    final alters = context.watch<AlterController>();
    final images = context.read<ImageStore>();
    final bg = world.backgroundPath == null ? null : images.resolve(world.backgroundPath!);

    return Scaffold(body: ListView(padding: const EdgeInsets.all(12), children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: AspectRatio(
          aspectRatio: 4 / 3,
          child: LayoutBuilder(
            builder: (context, c) {
              final box = Size(c.maxWidth, c.maxHeight);
              return Stack(key: const Key('scene'), children: [
                Positioned.fill(
                  child: bg != null && bg.existsSync()
                      ? Image.file(File(bg.path), fit: BoxFit.cover)
                      : const ArtImage(
                          'world_backdrop',
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                          fallback: CustomPaint(painter: SceneBackdropPainter()),
                        ),
                ),
                for (final it in world.items) _piece(world, it, box),
              ]);
            },
          ),
        ),
      ),
      const SizedBox(height: 8),
      Wrap(spacing: 8, children: [
        FilledButton.icon(
          key: const Key('world-write'),
          onPressed: () => Navigator.of(context)
              .push(MaterialPageRoute(builder: (_) => const WorldEntryScreen())),
          icon: const Icon(Icons.edit),
          label: const Text('Write about it'),
        ),
        PopupMenuButton<String>(
          key: const Key('add-piece'),
          onSelected: world.addPiece,
          itemBuilder: (_) => [
            for (final k in kLexicon.keys)
              PopupMenuItem(key: Key('add-$k'), value: k, child: Text(k)),
          ],
          child: const Chip(avatar: Icon(Icons.add, size: 18), label: Text('Add a piece')),
        ),
        ActionChip(
          avatar: const Icon(Icons.image, size: 18),
          label: Text(world.backgroundPath == null ? 'Background' : 'Change background'),
          onPressed: _pickBackground,
        ),
        if (world.backgroundPath != null)
          ActionChip(
            label: const Text('Remove background'),
            onPressed: () => world.setBackground(null),
          ),
      ]),
      Builder(builder: (context) {
        final counts = world.alterMentionCounts();
        final live = counts.entries.where((e) => alters.byId(e.key) != null).toList()
          ..sort((a, b) {
            final byCount = b.value.compareTo(a.value);
            return byCount != 0
                ? byCount
                : alters.label(a.key).toLowerCase().compareTo(alters.label(b.key).toLowerCase());
          });
        if (live.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Who lives here', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Wrap(spacing: 8, children: [
              for (final e in live)
                ActionChip(
                  key: Key('lives-${e.key}'),
                  avatar: AlterAvatar(alter: alters.byId(e.key)!, radius: 12),
                  label: Text(e.value > 1
                      ? '${alters.label(e.key)} · ${e.value}'
                      : alters.label(e.key)),
                  onPressed: () => openAlterLink(context, [e.key]),
                ),
            ]),
          ]),
        );
      }),
      const Divider(height: 24),
      if (world.entries.isEmpty)
        const Padding(
          padding: EdgeInsets.all(16),
          child: Column(children: [
            ArtImage('world_empty', width: 140, height: 140),
            SizedBox(height: 8),
            Text(
              'Write about your inner world in your own words. What is it like? What is there? '
              'Things you mention can appear in the picture above, and you can move, resize, recolor or remove anything.',
            ),
          ]),
        )
      else
        for (final e in world.entries)
          ListTile(
            title: Text(e.title.isEmpty ? '(no title)' : e.title),
            subtitle: Text(e.text, maxLines: 2, overflow: TextOverflow.ellipsis),
            onTap: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => WorldEntryScreen(existing: e))),
          ),
    ]));
  }
}
