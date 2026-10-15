import '../../friends/friend_models.dart';

String deliveryLabel(DeliveryState s) => switch (s) {
      DeliveryState.queued => 'Waiting to send',
      DeliveryState.sent => 'Sent',
      DeliveryState.delivered => 'Delivered',
    };

/// What this friend lets me see about who is out. Empty when they share nothing.
String outNowLine(Friend f) {
  final t = f.theirFront;
  if (t == null) return '';
  if (t.alters.isNotEmpty) return 'Out now: ${t.alters.map((a) => a.name).join(', ')}';
  if (t.someoneOut) return 'Someone is out';
  return '';
}

String previewOf(List<FriendMessage> messages) {
  if (messages.isEmpty) return 'No messages yet';
  final m = messages.last;
  final flat = m.text.replaceAll(RegExp(r'\s+'), ' ').trim();
  final cut = flat.length > 60 ? '${flat.substring(0, 60)}…' : flat;
  return m.outgoing ? 'You: $cut' : cut;
}

String deliveryHeader(Iterable<FriendMessage> messages) =>
    messages.any((m) => m.outgoing && m.state == DeliveryState.queued)
        ? 'Waiting for a connection. It will send as soon as you are online.'
        : 'Messages are scrambled before they leave your phone.';

/// Turns whatever the controller threw into one plain sentence for a person.
String friendProblemText(Object e) {
  const fallback = 'Something went wrong. Try again.';
  String clean(Object? m) {
    final t = m == null ? '' : '$m'.trim();
    return (t.isEmpty || t == 'null') ? fallback : t;
  }

  if (e is ArgumentError) return clean(e.message);
  if (e is FormatException) return clean(e.message);
  if (e is StateError) return clean(e.message);
  return fallback;
}
