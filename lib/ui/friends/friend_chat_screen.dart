import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../controllers/alter_controller.dart';
import '../../controllers/friends_controller.dart';
import '../../domain/little.dart';
import '../../friends/friend_models.dart';
import '../little_scope.dart';
import 'friend_sheet.dart';
import 'friend_text.dart';

class FriendChatScreen extends StatefulWidget {
  const FriendChatScreen({super.key, required this.friendId});
  final String friendId;
  @override
  State<FriendChatScreen> createState() => _FriendChatScreenState();
}

class _FriendChatScreenState extends State<FriendChatScreen> {
  final _input = TextEditingController();
  String? _as; // chosen speaker; null = whoever is out
  bool _closing = false;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _send(String? asAlterId) async {
    final text = _input.text;
    if (text.trim().isEmpty) return;
    final fc = context.read<FriendsController>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      await fc.sendMessage(friendId: widget.friendId, text: text, asAlterId: asAlterId);
      _input.clear();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(friendProblemText(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final fc = context.watch<FriendsController>();
    final alters = context.watch<AlterController>();
    final copy = LittleCopy(currentLittleLevel(context));
    final friend = fc.friends.where((f) => f.id == widget.friendId).firstOrNull;
    if (friend == null || friend.state != FriendState.friends) {
      // Removed or blocked while this screen was open: leave quietly.
      if (!_closing) {
        _closing = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && Navigator.of(context).canPop()) Navigator.of(context).pop();
        });
      }
      return const Scaffold();
    }
    final messages = fc.messagesWith(friend.id);
    final blockedForLittle = fc.locked && !friend.littleOk;
    final active = alters.active;
    final speaker = active.any((a) => a.id == _as) ? _as : null;
    final out = outNowLine(friend);

    return Scaffold(
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(friend.displayName, maxLines: 1, overflow: TextOverflow.ellipsis),
          if (out.isNotEmpty) Text(out, style: Theme.of(context).textTheme.bodySmall),
        ]),
        actions: [
          IconButton(
            key: const Key('friend-settings'),
            icon: const Icon(Icons.tune),
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              builder: (_) => ChangeNotifierProvider<FriendsController>.value(
                value: fc,
                child: FriendSheet(friendId: friend.id),
              ),
            ),
          ),
        ],
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Text(deliveryHeader(messages), style: Theme.of(context).textTheme.bodySmall),
        ),
        Expanded(
          child: messages.isEmpty
              ? const Center(child: Text('No messages yet. Say hi!'))
              : ListView(padding: const EdgeInsets.all(8), children: [
                  for (final m in messages) _Bubble(key: Key('friend-msg-${m.id}'), m: m),
                ]),
        ),
        if (blockedForLittle)
          Padding(padding: const EdgeInsets.all(12), child: Text(copy('guardMessage')))
        else
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(children: [
              if (active.isNotEmpty)
                DropdownButton<String?>(
                  key: const Key('friend-as'),
                  value: speaker,
                  items: [
                    const DropdownMenuItem<String?>(value: null, child: Text('Whoever is out')),
                    for (final a in active) DropdownMenuItem<String?>(value: a.id, child: Text(a.name)),
                  ],
                  onChanged: (v) => setState(() => _as = v),
                ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  key: const Key('friend-input'),
                  controller: _input,
                  minLines: 1,
                  maxLines: 4,
                  maxLength: FriendsController.maxText,
                  decoration: const InputDecoration(hintText: 'Say something kind...', counterText: ''),
                  onSubmitted: (_) => _send(speaker),
                ),
              ),
              IconButton(key: const Key('friend-send'), icon: const Icon(Icons.send), onPressed: () => _send(speaker)),
            ]),
          ),
      ]),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({super.key, required this.m});
  final FriendMessage m;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final mine = m.outgoing;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
        child: Card(
          color: mine ? scheme.primaryContainer : scheme.surfaceContainerHighest,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (m.speakerName != null)
                Text(m.speakerName!,
                    style: TextStyle(fontWeight: FontWeight.bold, color: m.speakerColor == null ? null : Color(m.speakerColor!))),
              Text(m.text),
              if (mine) Text(deliveryLabel(m.state), style: Theme.of(context).textTheme.bodySmall),
            ]),
          ),
        ),
      ),
    );
  }
}
