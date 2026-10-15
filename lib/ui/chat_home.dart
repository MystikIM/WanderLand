import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/friends_controller.dart';
import 'chat_screen.dart';
import 'friends/friends_section.dart';

/// The Chat tab: "Inside" is the chat between alters on this phone (unchanged),
/// "Friends" is chat with other people who use the app.
class ChatHome extends StatefulWidget {
  const ChatHome({super.key});
  @override
  State<ChatHome> createState() => _ChatHomeState();
}

class _ChatHomeState extends State<ChatHome> {
  bool _friends = false;

  @override
  Widget build(BuildContext context) {
    final waiting = context.watch<FriendsController>().pendingRequests.length;
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        child: SegmentedButton<bool>(
          key: const Key('chat-seg'),
          showSelectedIcon: false,
          segments: [
            const ButtonSegment(value: false, icon: Icon(Icons.home), label: Text('Inside')),
            ButtonSegment(
              value: true,
              icon: const Icon(Icons.people),
              label: Text(waiting > 0 ? 'Friends ($waiting)' : 'Friends'),
            ),
          ],
          selected: {_friends},
          onSelectionChanged: (s) => setState(() => _friends = s.first),
        ),
      ),
      Expanded(child: _friends ? const FriendsSection() : const ChatScreen()),
    ]);
  }
}
