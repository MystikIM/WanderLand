class JournalEntry {
  const JournalEntry({
    required this.id,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.updatedAt,
    this.authorAlterId,
  });
  final String id;
  final String title;
  final String body;
  final String? authorAlterId;
  final DateTime createdAt;
  final DateTime updatedAt;

  JournalEntry copyWith({String? title, String? body, String? authorAlterId, bool clearAuthor = false, DateTime? updatedAt}) =>
      JournalEntry(
        id: id,
        createdAt: createdAt,
        title: title ?? this.title,
        body: body ?? this.body,
        authorAlterId: clearAuthor ? null : (authorAlterId ?? this.authorAlterId),
        updatedAt: updatedAt ?? this.updatedAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'body': body,
        'authorAlterId': authorAlterId,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory JournalEntry.fromJson(Map<String, dynamic> j) => JournalEntry(
        id: j['id'] as String,
        title: j['title'] as String? ?? '',
        body: j['body'] as String? ?? '',
        authorAlterId: j['authorAlterId'] as String?,
        createdAt: DateTime.parse(j['createdAt'] as String),
        updatedAt: DateTime.parse(j['updatedAt'] as String),
      );
}

class ChatChannel {
  const ChatChannel({required this.id, required this.name, required this.createdAt});
  final String id;
  final String name;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'createdAt': createdAt.toIso8601String()};

  factory ChatChannel.fromJson(Map<String, dynamic> j) => ChatChannel(
        id: j['id'] as String,
        name: j['name'] as String,
        createdAt: DateTime.parse(j['createdAt'] as String),
      );
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.channelId,
    required this.authorAlterId,
    required this.text,
    required this.createdAt,
  });
  final String id;
  final String channelId;
  final String authorAlterId;
  final String text;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'channelId': channelId,
        'authorAlterId': authorAlterId,
        'text': text,
        'createdAt': createdAt.toIso8601String(),
      };

  factory ChatMessage.fromJson(Map<String, dynamic> j) => ChatMessage(
        id: j['id'] as String,
        channelId: j['channelId'] as String,
        authorAlterId: j['authorAlterId'] as String,
        text: j['text'] as String,
        createdAt: DateTime.parse(j['createdAt'] as String),
      );
}
