import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../controllers/alter_controller.dart';
import '../../controllers/friends_controller.dart';
import '../../domain/little.dart';
import '../little_scope.dart';
import 'friend_text.dart';

/// Everything about one friend: what they may see, mute, block, remove, safety number.
class FriendSheet extends StatefulWidget {
  const FriendSheet({super.key, required this.friendId});
  final String friendId;
  @override
  State<FriendSheet> createState() => _FriendSheetState();
}

class _FriendSheetState extends State<FriendSheet> {
  final _nick = TextEditingController();
  bool _nickLoaded = false;

  @override
  void dispose() {
    _nick.dispose();
    super.dispose();
  }

  Future<bool> _confirm(String title, String body, String yes) async =>
      await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(title),
          content: Text(body),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(key: const Key('friend-confirm'), onPressed: () => Navigator.pop(ctx, true), child: Text(yes)),
          ],
        ),
      ) ??
      false;

  Future<void> _run(Future<void> Function() action) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await action();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(friendProblemText(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final fc = context.watch<FriendsController>();
    final alters = context.watch<AlterController>();
    final copy = LittleCopy(currentLittleLevel(context));
    final f = fc.friends.where((x) => x.id == widget.friendId).firstOrNull;
    if (f == null) return const SizedBox.shrink();
    if (!_nickLoaded) {
      _nick.text = f.nickname;
      _nickLoaded = true;
    }
    final locked = fc.locked;
    return SafeArea(
      child: ListView(shrinkWrap: true, padding: const EdgeInsets.all(16), children: [
        Text(f.theirUsername, style: Theme.of(context).textTheme.titleLarge, maxLines: 1, overflow: TextOverflow.ellipsis),
        TextField(
          key: const Key('friend-nickname'),
          controller: _nick,
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(labelText: 'Nickname (only you see it)'),
          onSubmitted: (v) => _run(() => fc.setNickname(f.id, v)),
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          key: const Key('friend-share'),
          title: Text('Let ${f.displayName} see who is out'),
          subtitle: const Text('Off by default. You choose which alters they can see.'),
          value: f.shareFront,
          onChanged: locked ? null : (v) => _run(() => fc.setShareFront(f.id, v)),
        ),
        if (f.shareFront)
          for (final a in alters.active)
            CheckboxListTile(
              key: Key('friend-allow-${a.id}'),
              title: Text(a.name),
              value: f.allowedAlterIds.contains(a.id),
              onChanged: locked
                  ? null
                  : (v) {
                      final next = {...f.allowedAlterIds};
                      v == true ? next.add(a.id) : next.remove(a.id);
                      _run(() => fc.setAllowedAlters(f.id, next));
                    },
            ),
        SwitchListTile(
          key: const Key('friend-mute'),
          title: const Text('Mute'),
          value: f.muted,
          onChanged: (v) => _run(() => fc.setMuted(f.id, v)),
        ),
        SwitchListTile(
          key: const Key('friend-little-ok'),
          title: const Text('Okay for littles to chat with'),
          value: f.littleOk,
          onChanged: locked ? null : (v) => _run(() => fc.setLittleOk(f.id, v)),
        ),
        if (locked) Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Text(copy('guardMessage'))),
        ListTile(
          key: const Key('friend-safety'),
          leading: const Icon(Icons.verified_user),
          title: const Text('Safety number'),
          subtitle: const Text('Read it out with your friend. If it matches on both phones, nobody is in the middle.'),
          onTap: () => _run(() async {
            final n = await fc.safetyNumberFor(f.id);
            if (!context.mounted) return;
            await showDialog<void>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Safety number'),
                content: SelectableText(n),
                actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
              ),
            );
          }),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          key: const Key('friend-block'),
          onPressed: () async {
            final nav = Navigator.of(context);
            if (await _confirm('Block ${f.displayName}?', 'They will not be told. Their messages stop arriving.', 'Block')) {
              await _run(() => fc.block(f.id));
              if (mounted && nav.canPop()) nav.pop();
            }
          },
          child: const Text('Block'),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          key: const Key('friend-remove'),
          onPressed: locked
              ? null
              : () async {
                  final nav = Navigator.of(context);
                  if (await _confirm('Remove ${f.displayName}?', 'Your chat with them is deleted from this phone.', 'Remove')) {
                    await _run(() => fc.removeFriend(f.id));
                    if (mounted && nav.canPop()) nav.pop();
                  }
                },
          child: const Text('Remove friend'),
        ),
      ]),
    );
  }
}
