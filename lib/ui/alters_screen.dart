import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/alter_controller.dart';
import '../controllers/settings_controller.dart';
import '../data/image_store.dart';
import '../domain/models.dart';
import 'alter_detail_screen.dart';
import 'alter_edit_screen.dart';

class AlterAvatar extends StatelessWidget {
  const AlterAvatar({super.key, required this.alter, this.radius = 24});
  final Alter alter;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final rel = alter.imagePath;
    if (rel != null) {
      final f = context.read<ImageStore>().resolve(rel);
      if (f.existsSync()) {
        return CircleAvatar(radius: radius, backgroundImage: FileImage(File(f.path)));
      }
    }
    final initial = alter.name.isEmpty
        ? '?'
        : String.fromCharCode(alter.name.runes.first);
    return CircleAvatar(
      radius: radius,
      backgroundColor: Color(alter.colorValue),
      child: Text(initial, style: TextStyle(fontSize: radius * 0.9, color: Colors.white)),
    );
  }
}

class AltersScreen extends StatefulWidget {
  const AltersScreen({super.key});
  @override
  State<AltersScreen> createState() => _AltersScreenState();
}

class _AltersScreenState extends State<AltersScreen> {
  bool _showArchived = false;

  @override
  Widget build(BuildContext context) {
    final c = context.watch<AlterController>();
    final t = context.watch<SettingsController>().terminology;
    final list = _showArchived
        ? (c.all.toList()..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase())))
        : c.active;
    return Scaffold(
      appBar: AppBar(
        title: Text(t.cap('alters')),
        actions: [
          IconButton(
            key: const Key('show-archived'),
            tooltip: 'Show archived',
            icon: Icon(_showArchived ? Icons.visibility : Icons.visibility_off),
            onPressed: () => setState(() => _showArchived = !_showArchived),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const AlterEditScreen())),
        icon: const Icon(Icons.add),
        label: Text('Add ${t('alter')}'),
      ),
      body: list.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Add your first ${t('alter')} with the button below.',
                    textAlign: TextAlign.center),
              ),
            )
          : ListView(children: [
              for (final a in list)
                ListTile(
                  leading: AlterAvatar(alter: a),
                  title: Text(a.name),
                  subtitle: Text([a.pronouns, a.role].where((s) => s.isNotEmpty).join(' · ')),
                  trailing: a.archived ? const Icon(Icons.archive_outlined) : null,
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => AlterDetailScreen(alterId: a.id))),
                ),
            ]),
    );
  }
}
