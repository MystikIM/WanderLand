import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:plural_app/friends/friend_models.dart';
import 'package:plural_app/friends/transport.dart';
import '../helpers/friends_harness.dart';

void main() {
  test('C1: the controller confirms mail only after it has handled it', () async {
    final hub = MemoryHub();
    final a = await Phone.on(hub, username: 'alpha');
    var confirmed = 0;
    a.transport.inject(Envelope('somebox0000000000000000', Uint8List.fromList([1, 2, 3]), onHandled: () => confirmed++));
    expect(confirmed, 0); // not before it has been looked at
    await a.c.idle;
    expect(confirmed, 1);
  });

  test('C1: mail that turns up once chat is off is never confirmed, so it stays on the relay', () async {
    final hub = MemoryHub();
    final a = await Phone.on(hub, username: 'alpha');
    await a.c.setMode(ChatMode.off);
    var confirmed = 0;
    a.transport.inject(Envelope('somebox0000000000000000', Uint8List.fromList([1]), onHandled: () => confirmed++));
    await a.c.idle;
    expect(confirmed, 0);
  });
}
