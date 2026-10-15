import 'dart:io';
import 'package:plural_app/controllers/alter_controller.dart';
import 'package:plural_app/controllers/chat_controller.dart';
import 'package:plural_app/controllers/front_controller.dart';
import 'package:plural_app/controllers/friends_controller.dart';
import 'package:plural_app/controllers/settings_controller.dart';
import 'package:plural_app/data/doc_store.dart';
import 'package:plural_app/data/image_store.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'friends_harness.dart';

/// Everything a friends screen test needs: the app's controllers, one pretend phone that is
/// "me" (its FriendsController is the one under test) and a second pretend phone, "bravo".
class UiEnv {
  UiEnv({
    required this.store,
    required this.settings,
    required this.alters,
    required this.front,
    required this.chat,
    required this.me,
    required this.peer,
  });
  final MemoryDocStore store;
  final SettingsController settings;
  final AlterController alters;
  final FrontController front;
  final ChatController chat;
  final Phone me;
  final Phone peer;

  FriendsController get friends => me.c;

  List<SingleChildWidget> get providers => [
        ChangeNotifierProvider.value(value: settings),
        ChangeNotifierProvider.value(value: alters),
        ChangeNotifierProvider.value(value: front),
        ChangeNotifierProvider.value(value: chat),
        ChangeNotifierProvider<FriendsController>.value(value: me.c),
        Provider.value(value: ImageStore(Directory.systemTemp)),
      ];
}

Future<UiEnv> uiEnv({bool chatOn = true, List<String> alterNames = const ['Bob', 'Cat']}) async {
  final store = MemoryDocStore();
  final settings = SettingsController(store);
  await settings.load();
  final alters = AlterController(store);
  await alters.load();
  for (final n in alterNames) {
    await alters.create(name: n);
  }
  final front = FrontController(store, clock: () => DateTime(2026, 10, 15, 9));
  await front.load();
  final chat = ChatController(store, clock: () => DateTime(2026, 10, 15, 9));
  await chat.load();
  final hub = MemoryHub();
  final me = Phone(hub, withAlters: alters.all.toList());
  await me.c.load();
  if (chatOn) await me.c.enable(username: 'alpha');
  final peer = await Phone.on(hub, username: 'bravo');
  return UiEnv(store: store, settings: settings, alters: alters, front: front, chat: chat, me: me, peer: peer);
}
