import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:provider/provider.dart';
import '../controllers/alter_controller.dart';
import '../data/image_store.dart';
import 'alter_edit_screen.dart';
import 'alters_screen.dart';

class AlterDetailScreen extends StatelessWidget {
  const AlterDetailScreen({super.key, required this.alterId});
  final String alterId;

  @override
  Widget build(BuildContext context) {
    final c = context.watch<AlterController>();
    final a = c.byId(alterId);
    if (a == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Removed alter')),
        body: const Center(child: Text('Removed alter')),
      );
    }
    final banner = a.bannerPath == null ? null : context.read<ImageStore>().resolve(a.bannerPath!);
    return Scaffold(
      appBar: AppBar(
        title: Text(a.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => AlterEditScreen(existing: a))),
          ),
        ],
      ),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        if (banner != null && banner.existsSync())
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(File(banner.path), height: 140, fit: BoxFit.cover),
          ),
        const SizedBox(height: 12),
        Row(children: [
          AlterAvatar(alter: a, radius: 36),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(a.name, style: Theme.of(context).textTheme.headlineSmall),
              if (a.pronouns.isNotEmpty) Text(a.pronouns),
              if (a.role.isNotEmpty) Text(a.role),
            ]),
          ),
        ]),
        const SizedBox(height: 16),
        if (a.bio.isNotEmpty) MarkdownBody(data: a.bio),
        const SizedBox(height: 12),
        Wrap(spacing: 8, children: [
          for (final t in [...a.groups, ...a.tags]) Chip(label: Text(t)),
        ]),
        for (final e in a.customFields.entries)
          ListTile(dense: true, title: Text(e.key), subtitle: Text(e.value)),
      ]),
    );
  }
}
