import 'package:flutter/foundation.dart';
import '../data/doc_store.dart';
import '../domain/ids.dart';
import '../domain/journal.dart';

class ChatController extends ChangeNotifier {
  ChatController(this._store, {Clock? clock}) : _clock = clock ?? DateTime.now;
  static const channelsCollection = 'chat_channels';
  static const messagesCollection = 'chat_messages';
  final DocStore _store;
  final Clock _clock;
  List<ChatChannel> channels = const [];
  List<ChatMessage> _messages = const [];

  Future<void> load() async {
    channels = (await _store.all(channelsCollection)).map(ChatChannel.fromJson).toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    if (channels.isEmpty) {
      await _store.put(channelsCollection,
          ChatChannel(id: 'general', name: 'General', createdAt: _clock()).toJson());
      channels = (await _store.all(channelsCollection)).map(ChatChannel.fromJson).toList();
    }
    _messages = (await _store.all(messagesCollection)).map(ChatMessage.fromJson).toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    notifyListeners();
  }

  List<ChatMessage> messagesIn(String channelId) =>
      _messages.where((m) => m.channelId == channelId).toList();

  Future<ChatMessage> send({
    required String channelId,
    required String authorAlterId,
    required String text,
  }) async {
    final t = text.trim();
    if (t.isEmpty) throw ArgumentError('Write something first');
    if (!channels.any((c) => c.id == channelId)) throw ArgumentError('That channel is gone');
    final now = _clock();
    final m = ChatMessage(
      id: IdGen.next(now),
      channelId: channelId,
      authorAlterId: authorAlterId,
      text: t,
      createdAt: now,
    );
    await _store.put(messagesCollection, m.toJson());
    await load();
    return m;
  }

  Future<ChatChannel> addChannel(String name) async {
    final n = name.trim();
    if (n.isEmpty) throw ArgumentError('Give the channel a name');
    if (channels.any((c) => c.name.toLowerCase() == n.toLowerCase())) {
      throw ArgumentError('There is already a channel with that name');
    }
    final now = _clock();
    final c = ChatChannel(id: IdGen.next(now), name: n, createdAt: now);
    await _store.put(channelsCollection, c.toJson());
    await load();
    return c;
  }

  Future<bool> deleteChannel(String id) async {
    if (channels.length <= 1) return false;
    for (final m in _messages.where((m) => m.channelId == id)) {
      await _store.delete(messagesCollection, m.id);
    }
    await _store.delete(channelsCollection, id);
    await load();
    return true;
  }

  Future<void> deleteMessage(String id) async {
    await _store.delete(messagesCollection, id);
    await load();
  }
}
