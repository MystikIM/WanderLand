import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../controllers/friends_controller.dart';
import '../../domain/little.dart';
import '../../friends/friend_models.dart';
import '../little_scope.dart';
import 'friend_text.dart';

/// More > Friend chat: on or off, username, start over.
class FriendSettingsScreen extends StatefulWidget {
  const FriendSettingsScreen({super.key});
  @override
  State<FriendSettingsScreen> createState() => _FriendSettingsScreenState();
}

class _FriendSettingsScreenState extends State<FriendSettingsScreen> {
  final _name = TextEditingController();
  bool _loaded = false;
  String? _problem;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _saveName(FriendsController fc) async {
    final p = usernameProblem(_name.text);
    if (p != null) {
      setState(() => _problem = p);
      return;
    }
    try {
      await fc.setUsername(_name.text.trim());
      if (mounted) setState(() => _problem = null);
    } catch (e) {
      if (mounted) setState(() => _problem = friendProblemText(e));
    }
  }

  Future<void> _setMode(FriendsController fc, ChatMode m) async {
    try {
      await fc.setMode(m);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendProblemText(e))));
    }
  }

  Future<void> _reset(FriendsController fc) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Start chat over?'),
        content: const Text(
            'This deletes all your friends and messages from this phone, and your chat key. Your friends are not told. You can never get them back; you would add friends again.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(key: const Key('fset-confirm'), onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete it all')),
        ],
      ),
    );
    if (yes == true) {
      try {
        await fc.reset();
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendProblemText(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final fc = context.watch<FriendsController>();
    final copy = LittleCopy(currentLittleLevel(context));
    final me = fc.identity;
    if (me != null && !_loaded) {
      _name.text = me.username;
      _loaded = true;
    }
    final locked = fc.locked;
    return Scaffold(
      appBar: AppBar(title: const Text('Friend chat')),
      body: me == null
          ? const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Friend chat is off and not set up. To start, open Chat > Friends and press "Turn on friend chat".'),
            )
          : ListView(padding: const EdgeInsets.all(16), children: [
              if (locked) Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(copy('guardMessage'))),
              Text('When is chat connected?', style: Theme.of(context).textTheme.titleMedium),
              RadioGroup<ChatMode>(
                groupValue: me.mode,
                onChanged: (v) {
                  if (!locked && v != null) _setMode(fc, v);
                },
                child: Column(children: [
                  RadioListTile<ChatMode>(
                    key: const Key('fset-mode-off'),
                    value: ChatMode.off,
                    enabled: !locked,
                    title: const Text('Off'),
                    subtitle: const Text('Nothing is sent or received.'),
                  ),
                  RadioListTile<ChatMode>(
                    key: const Key('fset-mode-open'),
                    value: ChatMode.whileOpen,
                    enabled: !locked,
                    title: const Text('While the app is open'),
                    subtitle: const Text('Messages arrive while WanderLand is open.'),
                  ),
                  const RadioListTile<ChatMode>(
                    value: ChatMode.always,
                    enabled: false,
                    title: Text('Always on'),
                    subtitle: Text('Messages arrive even when the app is closed. Coming soon.'),
                  ),
                ]),
              ),
              const Divider(height: 32),
              TextField(
                key: const Key('fset-username'),
                controller: _name,
                enabled: !locked,
                decoration: InputDecoration(labelText: 'My username (friends see this)', errorText: _problem),
              ),
              const SizedBox(height: 8),
              FilledButton(
                key: const Key('fset-username-save'),
                onPressed: locked ? null : () => _saveName(fc),
                child: const Text('Save username'),
              ),
              const Divider(height: 32),
              OutlinedButton(
                key: const Key('fset-reset'),
                onPressed: locked ? null : () => _reset(fc),
                child: const Text('Start chat over'),
              ),
            ]),
    );
  }
}
