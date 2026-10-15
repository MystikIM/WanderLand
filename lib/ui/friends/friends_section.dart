import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../controllers/friends_controller.dart';
import '../../domain/little.dart';
import '../../friends/friend_models.dart';
import '../little_scope.dart';
import 'add_friend_screen.dart';
import 'friend_chat_screen.dart';
import 'friend_text.dart';

class FriendsSection extends StatelessWidget {
  const FriendsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final fc = context.watch<FriendsController>();
    final copy = LittleCopy(currentLittleLevel(context));
    if (!fc.isOn) return _TurnOn(guard: fc.locked ? copy('guardMessage') : null);

    final shown = [
      for (final f in fc.friends)
        if (f.state == FriendState.friends || f.state == FriendState.pendingOut) f,
    ];
    DateTime lastOf(Friend f) {
      final m = fc.messagesWith(f.id);
      return m.isEmpty ? f.createdAt : m.last.createdAt;
    }

    shown.sort((a, b) => lastOf(b).compareTo(lastOf(a)));
    final waiting = fc.pendingRequests.length;
    void openAdd() => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const AddFriendScreen()));

    return ListView(key: const Key('friends-list'), padding: const EdgeInsets.all(8), children: [
      if (waiting > 0)
        Card(
          child: ListTile(
            key: const Key('friends-requests'),
            leading: const Icon(Icons.mark_email_unread),
            title: Text(waiting == 1 ? '1 friend request waiting' : '$waiting friend requests waiting'),
            trailing: const Icon(Icons.chevron_right),
            onTap: openAdd,
          ),
        ),
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: FilledButton.icon(
          key: const Key('friends-add'),
          onPressed: fc.locked ? null : openAdd,
          icon: const Icon(Icons.person_add),
          label: const Text('Add a friend'),
        ),
      ),
      if (fc.locked) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(copy('guardMessage'))),
      if (shown.isEmpty)
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text('No friends yet. Add one with the button above, using the code they send you.'),
        ),
      for (final f in shown) _FriendTile(friend: f, fc: fc, copy: copy),
    ]);
  }
}

class _FriendTile extends StatelessWidget {
  const _FriendTile({required this.friend, required this.fc, required this.copy});
  final Friend friend;
  final FriendsController fc;
  final LittleCopy copy;

  @override
  Widget build(BuildContext context) {
    final f = friend;
    final waiting = f.state == FriendState.pendingOut;
    final notForLittles = fc.locked && !f.littleOk;
    final out = outNowLine(f);
    final preview = waiting ? 'Waiting for them to accept' : previewOf(fc.messagesWith(f.id));
    return ListTile(
      key: Key('friend-${f.id}'),
      leading: CircleAvatar(child: Text(f.displayName.characters.first.toUpperCase())),
      title: Text(f.displayName, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(out.isEmpty || waiting ? preview : '$preview\n$out', maxLines: 2, overflow: TextOverflow.ellipsis),
      trailing: notForLittles ? const Icon(Icons.lock) : (f.muted ? const Icon(Icons.notifications_off) : null),
      onTap: waiting
          ? null
          : notForLittles
              ? () => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(copy('guardMessage'))))
              : () => Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => FriendChatScreen(friendId: f.id)),
                  ),
    );
  }
}

class _TurnOn extends StatelessWidget {
  const _TurnOn({this.guard});
  final String? guard;

  Future<void> _ask(BuildContext context) =>
      showDialog<void>(context: context, builder: (_) => _UsernameDialog(fc: context.read<FriendsController>()));

  @override
  Widget build(BuildContext context) {
    return ListView(padding: const EdgeInsets.all(16), children: [
      const Icon(Icons.people, size: 48),
      const SizedBox(height: 12),
      Text('Chat with friends', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 8),
      const Text('Talk with other people who use WanderLand. Here is how it works:'),
      const SizedBox(height: 8),
      const Text('• Only people you add can message you.'),
      const Text('• Messages are scrambled before they leave your phone, so nobody in the middle can read them.'),
      const Text('• It uses the internet, and only while chat is turned on. Until you turn it on, nothing is sent.'),
      const Text('• You choose, friend by friend, whether they can see who is out.'),
      const SizedBox(height: 16),
      FilledButton(
        key: const Key('friends-turn-on'),
        onPressed: guard == null ? () => _ask(context) : null,
        child: const Text('Turn on friend chat'),
      ),
      if (guard != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(guard!)),
    ]);
  }
}

class _UsernameDialog extends StatefulWidget {
  const _UsernameDialog({required this.fc});
  final FriendsController fc;
  @override
  State<_UsernameDialog> createState() => _UsernameDialogState();
}

class _UsernameDialogState extends State<_UsernameDialog> {
  final _name = TextEditingController();
  String? _err;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _go() async {
    final problem = usernameProblem(_name.text);
    if (problem != null) {
      setState(() => _err = problem);
      return;
    }
    try {
      await widget.fc.enable(username: _name.text.trim());
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() => _err = friendProblemText(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Pick a username'),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('This is the name your friends see. It is not your real name.'),
          TextField(
            key: const Key('friends-username'),
            controller: _name,
            decoration: InputDecoration(labelText: 'Username', errorText: _err),
          ),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Not now')),
        FilledButton(key: const Key('friends-enable'), onPressed: _go, child: const Text('Turn on')),
      ],
    );
  }
}
