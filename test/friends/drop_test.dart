import 'package:flutter_test/flutter_test.dart';
import 'package:plural_app/friends/friend_models.dart';
import '../helpers/friends_harness.dart';

void main() {
  late MemoryHub hub;
  late Phone a;
  late Phone b;
  setUp(() async {
    hub = MemoryHub();
    a = await Phone.on(hub, username: 'alpha');
    b = await Phone.on(hub, username: 'bravo');
    await befriend(a, b);
  });

  test('blocking a friend tells the relay to drop their mailbox, and stops listening to it', () async {
    final f = b.c.friends.single;
    await b.c.block(f.id);
    expect(b.transport.drops, [f.inbox]);
    expect(b.transport.listening, isNot(contains(f.inbox)));
  });

  test('removing a friend drops their mailbox too', () async {
    final f = a.c.friends.single;
    await a.c.removeFriend(f.id);
    expect(a.transport.drops, [f.inbox]);
  });

  test('declining a request drops the mailbox it opened', () async {
    final c = await Phone.on(hub, username: 'charlie');
    await c.c.addFromCode(await b.c.myCode());
    await settle([b, c]);
    final request = b.c.pendingRequests.single;
    await b.c.declineRequest(request.id);
    expect(b.transport.drops, contains(request.inbox));
  });

  test('turning chat off only stops listening: mail waiting for you is NOT thrown away', () async {
    await a.c.setMode(ChatMode.off);
    expect(a.transport.drops, isEmpty);
  });
}
