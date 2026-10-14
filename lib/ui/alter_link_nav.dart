import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/alter_controller.dart';
import 'alter_detail_screen.dart';
import 'alters_screen.dart' show AlterAvatar;

/// Open the profile for a tapped name. If several alters share the name, ask which.
Future<void> openAlterLink(BuildContext context, List<String> alterIds) async {
  final alters = context.read<AlterController>();
  final nav = Navigator.of(context);
  final existing = alterIds.where((id) => alters.byId(id) != null).toList();
  if (existing.isEmpty) return;

  String? chosen = existing.length == 1 ? existing.first : null;
  chosen ??= await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Padding(
          padding: EdgeInsets.all(8),
          child: Text('Which one do you mean?'),
        ),
        for (final id in existing)
          ListTile(
            key: Key('pick-link-$id'),
            leading: AlterAvatar(alter: alters.byId(id)!),
            title: Text(alters.byId(id)!.name),
            subtitle: Text(alters.byId(id)!.pronouns),
            onTap: () => Navigator.pop(ctx, id),
          ),
      ]),
    ),
  );
  if (chosen == null) return;
  final id = chosen;
  await nav.push(MaterialPageRoute(builder: (_) => AlterDetailScreen(alterId: id)));
}
