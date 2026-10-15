import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/settings_controller.dart';
import '../data/doc_store.dart';
import '../theme/font_service.dart';
import 'appearance_screen.dart';
import '../domain/little.dart';
import 'backup_screen.dart';
import 'buddy_screen.dart';
import 'dedication.dart';
import 'friends/friend_settings_screen.dart';
import 'journal_screen.dart';
import 'little_scope.dart';
import 'notifications_screen.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  Future<void> _importFont(BuildContext context) async {
    final settings = context.read<SettingsController>();
    final svc = FontService(context.read<DocStore>(), context.read<Directory>());
    final messenger = ScaffoldMessenger.of(context);
    // file_picker 13: static API (the old FilePicker.platform.pickFiles is gone).
    final picked = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['ttf', 'otf'],
    );
    final path = picked?.path;
    if (path == null) return;
    try {
      final family = await svc.importFont(File(path));
      await settings.setTheme(settings.theme.copyWith(fontFamily: family));
    } on ArgumentError catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('${e.message}')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(children: [
      ListTile(
        leading: const Icon(Icons.palette),
        title: const Text('Appearance'),
        subtitle: const Text('Colors, fonts, and the words you use'),
        onTap: () async {
          final extra = await FontService(
                  context.read<DocStore>(), context.read<Directory>())
              .savedFamilies();
          if (!context.mounted) return;
          Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => AppearanceScreen(
              extraFonts: extra,
              onImportFont: () => _importFont(context),
            ),
          ));
        },
      ),
      ListTile(
        leading: const Icon(Icons.pets),
        title: const Text('Buddy & badges'),
        subtitle: const Text('Your little companion and what you have earned'),
        onTap: () => Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const BuddyScreen())),
      ),
      ListTile(
        leading: const Icon(Icons.notifications_outlined),
        title: const Text('Notifications'),
        subtitle: const Text('Who is out, lock screen privacy, check-in reminders'),
        onTap: () => Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const NotificationsScreen())),
      ),
      ListTile(
        key: const Key('more-friend-chat'),
        leading: const Icon(Icons.people_outline),
        title: const Text('Friend chat'),
        subtitle: const Text('Turn it on or off, your username, start over'),
        onTap: () => Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const FriendSettingsScreen())),
      ),
      ListTile(
        leading: const Icon(Icons.menu_book_outlined),
        title: Text(LittleCopy(currentLittleLevel(context))('journal')),
        subtitle: const Text('Private writing, with an optional PIN'),
        onTap: () => Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const JournalScreen())),
      ),
      ListTile(
        leading: const Icon(Icons.backup_outlined),
        title: const Text('Backup & restore'),
        subtitle: const Text('Keep a copy of your whole system'),
        onTap: () => Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const BackupScreen())),
      ),
      ListTile(
        leading: const Icon(Icons.info_outline),
        title: const Text('About'),
        subtitle: const Text('The dedication, and who made this'),
        onTap: () => Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const DedicationScreen())),
      ),
    ]);
  }
}
