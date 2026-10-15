import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plural_app/friends/friend_models.dart';
import 'package:plural_app/friends/qr_photo_source.dart';
import 'package:plural_app/friends/qr_reader.dart';
import 'package:plural_app/ui/friends/add_friend_screen.dart';
import '../../helpers/friends_harness.dart';
import '../../helpers/friends_ui_env.dart';
import '../../helpers/harness.dart';

class FakePhotos implements QrPhotoSource {
  FakePhotos({this.camera, this.gallery});
  final Uint8List? camera;
  final Uint8List? gallery;
  @override
  Future<Uint8List?> takePhoto() async => camera;
  @override
  Future<Uint8List?> pickPicture() async => gallery;
}

class FakeReader implements QrReader {
  FakeReader(this.answer);
  final String? answer;
  Uint8List? saw;
  @override
  Future<String?> decode(Uint8List b) async {
    saw = b;
    return answer;
  }
}

final pic = Uint8List.fromList([1, 2, 3]);

void main() {
  testWidgets('Show my code makes a code once, shows it as text and as a QR, and it can be copied', (tester) async {
    final env = await uiEnv();
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') copied = (call.arguments as Map)['text'] as String;
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    await pumpScreen(tester, const AddFriendScreen(), providers: env.providers);
    expect(find.byKey(const Key('friends-my-code')), findsNothing); // not made until asked
    expect(env.friends.identity!.pairingMailboxes, isEmpty);
    await tester.tap(find.byKey(const Key('friends-show-code')));
    await tester.pumpAndSettle();
    final shown = tester.widget<SelectableText>(find.byKey(const Key('friends-my-code'))).data!;
    expect(shown, startsWith('WL1-'));
    expect(find.byKey(ValueKey('qr:$shown')), findsOneWidget); // the QR carries this exact code
    await tester.tap(find.byKey(const Key('friends-copy-code')));
    await tester.pump();
    expect(copied, shown);
  });

  testWidgets("pasting a friend's code sends the request and says so", (tester) async {
    final env = await uiEnv();
    final code = await env.peer.c.myCode();
    await pumpScreen(tester, const AddFriendScreen(), providers: env.providers);
    await tester.enterText(find.byKey(const Key('friends-code-input')), '  $code  ');
    await tester.tap(find.byKey(const Key('friends-add-go')));
    await tester.pumpAndSettle();
    expect(env.friends.friends.single.state, FriendState.pendingOut);
    expect(find.textContaining('bravo'), findsWidgets);
    await settle([env.me, env.peer]);
    expect(env.peer.c.pendingRequests, hasLength(1));
  });

  testWidgets('REVIEW FOCUS: a bad code, my own code, and the same friend twice each give a plain sentence', (tester) async {
    final env = await uiEnv();
    await pumpScreen(tester, const AddFriendScreen(), providers: env.providers);
    Future<String> tryCode(String text) async {
      await tester.enterText(find.byKey(const Key('friends-code-input')), text);
      await tester.tap(find.byKey(const Key('friends-add-go')));
      await tester.pumpAndSettle();
      return tester.widget<Text>(find.byKey(const Key('friends-add-problem'))).data!;
    }

    final bad = await tryCode('hello');
    expect(bad, isNot(anyOf(contains('Exception'), contains('Bad state'), contains('null'))));
    expect(bad, isNotEmpty);
    final own = await env.friends.myCode();
    expect(await tryCode(own), contains('your own'));
    final theirs = await env.peer.c.myCode();
    await env.friends.addFromCode(theirs);
    final again = await env.peer.c.myCode();
    expect(await tryCode(again), isNotEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a waiting request can be accepted or declined', (tester) async {
    final env = await uiEnv();
    final c = await Phone.on(env.me.hub, username: 'charlie');
    await env.peer.c.addFromCode(await env.friends.myCode());
    await c.c.addFromCode(await env.friends.myCode());
    await settle([env.me, env.peer, c]);
    await pumpScreen(tester, const AddFriendScreen(), providers: env.providers);
    final reqs = env.friends.pendingRequests;
    expect(reqs, hasLength(2));
    await tester.tap(find.byKey(Key('friends-accept-${reqs.first.id}')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key('friends-decline-${reqs.last.id}')));
    await tester.pumpAndSettle();
    expect(env.friends.pendingRequests, isEmpty);
    expect(env.friends.friends.where((f) => f.state == FriendState.friends), hasLength(1));
  });

  testWidgets('REVIEW FOCUS: while a little is out nothing here can be used, and the reason is written', (tester) async {
    final env = await uiEnv();
    env.me.little = true;
    await pumpScreen(tester, const AddFriendScreen(), providers: env.providers);
    expect(find.byKey(const Key('friends-show-code')), findsNothing);
    expect(find.byKey(const Key('friends-add-go')), findsNothing);
    expect(find.textContaining('grown-up'), findsOneWidget);
  });

  testWidgets('taking a photo of their QR sends the request', (tester) async {
    final env = await uiEnv();
    final code = await env.peer.c.myCode();
    final reader = FakeReader(code);
    await pumpScreen(tester, AddFriendScreen(photos: FakePhotos(camera: pic), reader: reader), providers: env.providers);
    await tester.tap(find.byKey(const Key('friends-scan-camera')));
    await tester.pumpAndSettle();
    expect(reader.saw, pic);
    expect(env.friends.friends.single.state, FriendState.pendingOut);
    expect(find.textContaining('Request sent to bravo'), findsOneWidget);
  });

  testWidgets('a picture from the gallery works the same way', (tester) async {
    final env = await uiEnv();
    final code = await env.peer.c.myCode();
    await pumpScreen(tester, AddFriendScreen(photos: FakePhotos(gallery: pic), reader: FakeReader(code)), providers: env.providers);
    await tester.tap(find.byKey(const Key('friends-scan-gallery')));
    await tester.pumpAndSettle();
    expect(env.friends.friends.single.theirUsername, 'bravo');
  });

  testWidgets('a picture with no readable QR says so in plain words and adds nobody', (tester) async {
    final env = await uiEnv();
    await pumpScreen(tester, AddFriendScreen(photos: FakePhotos(camera: pic), reader: FakeReader(null)), providers: env.providers);
    await tester.tap(find.byKey(const Key('friends-scan-camera')));
    await tester.pumpAndSettle();
    expect(find.textContaining('could not find a QR code'), findsOneWidget);
    expect(env.friends.friends, isEmpty);
  });

  testWidgets('backing out of the camera does nothing and says nothing', (tester) async {
    final env = await uiEnv();
    await pumpScreen(tester, AddFriendScreen(photos: FakePhotos(), reader: FakeReader('x')), providers: env.providers);
    await tester.tap(find.byKey(const Key('friends-scan-camera')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('friends-add-problem')), findsNothing);
    expect(env.friends.friends, isEmpty);
  });

  testWidgets('REVIEW FOCUS: a QR that is not a friend code gives a plain sentence', (tester) async {
    final env = await uiEnv();
    await pumpScreen(tester, AddFriendScreen(photos: FakePhotos(camera: pic), reader: FakeReader('https://example.com')), providers: env.providers);
    await tester.tap(find.byKey(const Key('friends-scan-camera')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('friends-add-problem')), findsOneWidget);
    expect(find.textContaining('Exception'), findsNothing);
    expect(env.friends.friends, isEmpty);
  });

  testWidgets('REVIEW FOCUS: scanning my own QR gives a plain sentence', (tester) async {
    final env = await uiEnv();
    final own = await env.friends.myCode();
    await pumpScreen(tester, AddFriendScreen(photos: FakePhotos(camera: pic), reader: FakeReader(own)), providers: env.providers);
    await tester.tap(find.byKey(const Key('friends-scan-camera')));
    await tester.pumpAndSettle();
    expect(find.textContaining('your own'), findsOneWidget);
  });

  testWidgets('REVIEW FOCUS: tapping Accept twice never leaves an uncaught error', (tester) async {
    final env = await uiEnv();
    await env.peer.c.addFromCode(await env.friends.myCode());
    await settle([env.me, env.peer]);
    await pumpScreen(tester, const AddFriendScreen(), providers: env.providers);
    final id = env.friends.pendingRequests.single.id;
    await tester.tap(find.byKey(Key('friends-accept-$id')));
    await tester.tap(find.byKey(Key('friends-accept-$id')), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(env.friends.friends.where((f) => f.state == FriendState.friends), hasLength(1));
  });

  testWidgets('REVIEW FOCUS: tapping Send friend request twice still ends with the request sent', (tester) async {
    final env = await uiEnv();
    final code = await env.peer.c.myCode();
    await pumpScreen(tester, const AddFriendScreen(), providers: env.providers);
    await tester.enterText(find.byKey(const Key('friends-code-input')), code);
    await tester.tap(find.byKey(const Key('friends-add-go')));
    await tester.tap(find.byKey(const Key('friends-add-go')), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(env.friends.friends, hasLength(1));
    expect(find.byKey(const Key('friends-add-problem')), findsNothing);
    expect(find.textContaining('Request sent to bravo'), findsOneWidget);
  });
}
