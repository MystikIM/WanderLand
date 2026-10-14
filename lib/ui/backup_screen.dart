import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/settings_controller.dart';
import '../data/backup_service.dart';
import '../domain/little.dart';
import '../platform/device_backup_io.dart';
import 'little_scope.dart';

class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});
  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  String? _message;
  bool _busy = false;

  Future<void> _export() async {
    final api = context.read<BackupApi>();
    final io = context.read<BackupIo>();
    setState(() => _busy = true);
    try {
      final file = await api.exportToFile(await io.exportDirectory());
      await io.shareFile(file);
      if (mounted) setState(() => _message = 'Backup ready. Keep it somewhere private and safe.');
    } catch (e) {
      if (mounted) setState(() => _message = 'The backup could not be made: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restore() async {
    final api = context.read<BackupApi>();
    final io = context.read<BackupIo>();
    final reload = context.read<ReloadAll>();
    final bytes = await io.pickBackup();
    if (bytes == null || !mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restore this backup?'),
        content: const Text(
            'This will replace everything in the app with what is in the backup file. '
            'A safety copy of what is here now is saved first.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Not now')),
          FilledButton(
            key: const Key('restore-confirm'),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Replace everything'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    try {
      final r = await api.restoreZip(bytes);
      await reload();
      if (mounted) setState(() => _message = 'Restored ${r.docs} things and ${r.files} pictures and fonts. Welcome back. 💜');
    } on BackupException catch (e) {
      if (mounted) setState(() => _message = e.message);
    } catch (e) {
      if (mounted) setState(() => _message = 'The restore did not work: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final level = currentLittleLevel(context);
    final guard = context.watch<SettingsController>().profile.littleGuard;
    final canRestore = riskyActionsAllowed(level, guardOn: guard);
    return Scaffold(
      appBar: AppBar(title: const Text('Backup & restore')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        const Text(
            'A backup is one file with your whole system in it: alters, front history, journal, chat, inner world, '
            'pictures, fonts and settings. It is not encrypted, so keep it somewhere private.'),
        const SizedBox(height: 16),
        FilledButton.icon(
          key: const Key('backup-export'),
          onPressed: _busy ? null : _export,
          icon: const Icon(Icons.upload_file),
          label: const Text('Make a backup'),
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          key: const Key('backup-restore'),
          onPressed: (_busy || !canRestore) ? null : _restore,
          icon: const Icon(Icons.restore),
          label: const Text('Restore from a backup'),
        ),
        if (!canRestore) Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(LittleCopy(level)('guardMessage')),
        ),
        if (_busy) const Padding(padding: EdgeInsets.only(top: 16), child: LinearProgressIndicator()),
        if (_message != null) Padding(padding: const EdgeInsets.only(top: 16), child: Text(_message!)),
      ]),
    );
  }
}
