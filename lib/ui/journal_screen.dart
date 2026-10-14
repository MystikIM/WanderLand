import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/alter_controller.dart';
import '../controllers/journal_controller.dart';
import '../domain/little.dart';
import '../domain/pin_lock.dart';
import 'journal_edit_screen.dart';
import 'little_scope.dart';

class JournalScreen extends StatefulWidget {
  const JournalScreen({super.key});
  @override
  State<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends State<JournalScreen> {
  bool _loading = true;
  bool _locked = false;
  String _hint = '';
  DateTime? _resetAt;
  bool _resetReady = false;
  String? _error;
  final _pin = TextEditingController();

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _pin.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final lock = context.read<PinLock>();
    final set = await lock.isSet;
    final hint = await lock.hint;
    final at = await lock.resetAt;
    final ready = await lock.resetReady;
    if (!mounted) return;
    setState(() {
      _loading = false;
      _locked = set && !(_unlockedThisVisit);
      _hint = hint;
      _resetAt = at;
      _resetReady = ready;
    });
  }

  bool _unlockedThisVisit = false;

  Future<void> _tryPin() async {
    final ok = await context.read<PinLock>().verify(_pin.text);
    if (!mounted) return;
    setState(() {
      _error = ok ? null : 'That is not the right PIN';
      if (ok) {
        _unlockedThisVisit = true;
        _locked = false;
        _resetAt = null;
      }
      _pin.clear();
    });
  }

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} '
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  Future<void> _setPinDialog() async {
    final pin = TextEditingController();
    final hint = TextEditingController();
    final lock = context.read<PinLock>();
    String? err;
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Text('Set a PIN'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text(
                'This is a screen lock, not encryption. It keeps casual snoopers out of your journal; '
                'it does not scramble the file on the phone.\n\n'
                'Other alters may not remember it, so write a hint that only you would understand.'),
            TextField(
              key: const Key('new-pin'),
              controller: pin,
              obscureText: true,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: 'PIN (4 to 8 digits)', errorText: err),
            ),
            TextField(
              key: const Key('new-pin-hint'),
              controller: hint,
              decoration: const InputDecoration(labelText: 'Hint (optional)'),
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              key: const Key('new-pin-save'),
              onPressed: () async {
                try {
                  await lock.setPin(pin.text, hint: hint.text);
                  if (ctx.mounted) Navigator.pop(ctx);
                } on ArgumentError catch (e) {
                  setD(() => err = '${e.message}');
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final level = currentLittleLevel(context);
    final title = LittleCopy(level)('journal');
    if (_loading) return Scaffold(appBar: AppBar(title: Text(title)), body: const SizedBox.shrink());
    if (_locked) return _lockScreen(title);

    final j = context.watch<JournalController>();
    final alters = context.watch<AlterController>();
    return Scaffold(
      appBar: AppBar(title: Text(title), actions: [
        PopupMenuButton<String>(
          key: const Key('journal-menu'),
          onSelected: (v) async {
            if (v == 'set') {
              await _setPinDialog();
            } else {
              await context.read<PinLock>().remove();
              await _refresh();
            }
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'set', child: Text('Set a PIN')),
            PopupMenuItem(value: 'remove', child: Text('Remove the PIN')),
          ],
        ),
      ]),
      floatingActionButton: FloatingActionButton(
        key: const Key('journal-add'),
        onPressed: () => Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const JournalEditScreen())),
        child: const Icon(Icons.edit),
      ),
      body: j.entries.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('Write your first entry with the button below.', textAlign: TextAlign.center),
              ),
            )
          : ListView(children: [
              for (final e in j.entries)
                ListTile(
                  title: Text(e.title.isEmpty ? '(no title)' : e.title),
                  subtitle: Text(
                    '${_fmt(e.updatedAt)}'
                    '${e.authorAlterId == null ? '' : '  ·  ${alters.label(e.authorAlterId!)}'}',
                  ),
                  onTap: () => Navigator.of(context)
                      .push(MaterialPageRoute(builder: (_) => JournalEditScreen(existing: e))),
                ),
            ]),
    );
  }

  Widget _lockScreen(String title) => Scaffold(
        appBar: AppBar(title: Text(title)),
        body: ListView(padding: const EdgeInsets.all(24), children: [
          const Icon(Icons.lock_outline, size: 48),
          const SizedBox(height: 12),
          const Text('This journal is locked.', textAlign: TextAlign.center),
          if (_hint.isNotEmpty) Text('Hint: $_hint', textAlign: TextAlign.center),
          const SizedBox(height: 16),
          TextField(
            key: const Key('pin-field'),
            controller: _pin,
            obscureText: true,
            keyboardType: TextInputType.number,
            onSubmitted: (_) => _tryPin(),
            decoration: InputDecoration(labelText: 'PIN', errorText: _error),
          ),
          const SizedBox(height: 12),
          FilledButton(key: const Key('pin-submit'), onPressed: _tryPin, child: const Text('Unlock')),
          const Divider(height: 32),
          if (_resetAt == null)
            TextButton(
              key: const Key('pin-forgot'),
              onPressed: () async {
                await context.read<PinLock>().requestReset();
                await _refresh();
              },
              child: const Text('I forgot my PIN'),
            )
          else ...[
            Text(
              _resetReady
                  ? 'The waiting time is over.'
                  : 'You can remove the PIN on ${_fmt(_resetAt!)}. Entering the right PIN before then cancels this.',
              textAlign: TextAlign.center,
            ),
            if (_resetReady)
              FilledButton(
                key: const Key('pin-reset-now'),
                onPressed: () async {
                  await context.read<PinLock>().completeReset();
                  _unlockedThisVisit = true;
                  await _refresh();
                },
                child: const Text('Remove the PIN now'),
              ),
          ],
        ]),
      );
}
