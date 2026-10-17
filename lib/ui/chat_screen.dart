import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/alter_controller.dart';
import '../controllers/chat_controller.dart';
import '../controllers/front_controller.dart';
import 'alters_screen.dart' show AlterAvatar;
import 'art.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  String _channel = 'general';
  String? _as; // chosen sender; null = whoever is out
  final _input = TextEditingController();

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _addChannel() async {
    final chat = context.read<ChatController>();
    final name = TextEditingController();
    String? err;
    final created = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Text('New channel'),
          content: TextField(
            key: const Key('channel-name'),
            controller: name,
            decoration: InputDecoration(labelText: 'Name', errorText: err),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              key: const Key('channel-save'),
              onPressed: () async {
                try {
                  final c = await chat.addChannel(name.text);
                  if (ctx.mounted) Navigator.pop(ctx, c.id);
                } on ArgumentError catch (e) {
                  setD(() => err = '${e.message}');
                }
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
    if (created != null && mounted) setState(() => _channel = created);
  }

  Future<void> _send(String senderId) async {
    final chat = context.read<ChatController>();
    if (_input.text.trim().isEmpty) return;
    await chat.send(channelId: _channel, authorAlterId: senderId, text: _input.text);
    _input.clear();
  }

  @override
  Widget build(BuildContext context) {
    final chat = context.watch<ChatController>();
    final alters = context.watch<AlterController>();
    final front = context.watch<FrontController>();

    if (alters.active.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('Add an alter first, then you can chat here.', textAlign: TextAlign.center),
        ),
      );
    }
    if (!chat.channels.any((c) => c.id == _channel)) _channel = chat.channels.first.id;
    bool isActive(String? id) => id != null && alters.active.any((a) => a.id == id);
    final defaultSender = isActive(front.primaryId) ? front.primaryId! : alters.active.first.id;
    final sender = isActive(_as) ? _as! : defaultSender;
    final messages = chat.messagesIn(_channel);

    return Scaffold(body: Column(children: [
      SizedBox(
        height: 52,
        child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.all(8), children: [
          for (final c in chat.channels)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                key: Key('channel-${c.id}'),
                label: Text(c.name),
                selected: c.id == _channel,
                onSelected: (_) => setState(() => _channel = c.id),
              ),
            ),
          ActionChip(
            key: const Key('chat-add-channel'),
            avatar: const Icon(Icons.add, size: 18),
            label: const Text('Channel'),
            onPressed: _addChannel,
          ),
        ]),
      ),
      Expanded(
        child: messages.isEmpty
            ? const Center(
                child: EmptyArt('empty_chat', Text('No messages yet. Say hi!'), size: 130))
            : ListView(padding: const EdgeInsets.all(8), children: [
                for (final m in messages)
                  Builder(builder: (context) {
                    final a = alters.byId(m.authorAlterId);
                    return ListTile(
                      leading: a == null
                          ? const CircleAvatar(child: Icon(Icons.person_off))
                          : AlterAvatar(alter: a),
                      title: Text(alters.label(m.authorAlterId)),
                      subtitle: Text(m.text),
                      onLongPress: () => chat.deleteMessage(m.id),
                    );
                  }),
              ]),
      ),
      Padding(
        padding: const EdgeInsets.all(8),
        child: Row(children: [
          DropdownButton<String>(
            value: sender,
            items: [
              for (final a in alters.active) DropdownMenuItem(value: a.id, child: Text(a.name)),
            ],
            onChanged: (v) => setState(() => _as = v),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              key: const Key('chat-input'),
              controller: _input,
              decoration: const InputDecoration(hintText: 'Say something kind...'),
              onSubmitted: (_) => _send(sender),
            ),
          ),
          IconButton(key: const Key('chat-send'), icon: const Icon(Icons.send), onPressed: () => _send(sender)),
        ]),
      ),
    ]));
  }
}
