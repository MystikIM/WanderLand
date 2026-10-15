import 'package:flutter_test/flutter_test.dart';
import 'package:plural_app/friends/friend_models.dart';
import 'package:plural_app/ui/friends/friend_text.dart';

Friend friend({TheirFront? front}) => Friend(
      id: 'f1',
      theirUsername: 'bravo',
      publicKey: 'k',
      state: FriendState.friends,
      inbox: 'i',
      outbox: 'o',
      createdAt: DateTime(2026, 10, 15),
      theirFront: front,
    );

FriendMessage msg(String text, {bool out = false, DeliveryState state = DeliveryState.sent}) => FriendMessage(
      id: text,
      friendId: 'f1',
      outgoing: out,
      text: text,
      createdAt: DateTime(2026, 10, 15),
      state: state,
    );

void main() {
  test('delivery words are plain', () {
    expect(deliveryLabel(DeliveryState.queued), 'Waiting to send');
    expect(deliveryLabel(DeliveryState.sent), 'Sent');
    expect(deliveryLabel(DeliveryState.delivered), 'Delivered');
  });

  test('the out-now line says only what the friend allowed', () {
    expect(outNowLine(friend()), '');
    expect(outNowLine(friend(front: const TheirFront(alters: [TheirAlter('Cat', 1), TheirAlter('Bob', 2)], someoneOut: false))), 'Out now: Cat, Bob');
    expect(outNowLine(friend(front: const TheirFront(alters: [], someoneOut: true))), 'Someone is out');
    expect(outNowLine(friend(front: const TheirFront(alters: [], someoneOut: false))), '');
  });

  test('preview is the last message, short, on one line', () {
    expect(previewOf([]), 'No messages yet');
    expect(previewOf([msg('hi'), msg('how are you\ntoday', out: true)]), 'You: how are you today');
    expect(previewOf([msg('x' * 100)]), '${'x' * 60}…');
  });

  test('the header warns when something is waiting to send', () {
    expect(deliveryHeader([msg('a', out: true, state: DeliveryState.queued)]), contains('Waiting'));
    expect(deliveryHeader([msg('a', out: true)]), contains('scrambled'));
    expect(deliveryHeader([msg('a', state: DeliveryState.queued)]), contains('scrambled'));
  });

  test('every kind of failure becomes a plain sentence', () {
    expect(friendProblemText(ArgumentError('That is your own code.')), 'That is your own code.');
    expect(friendProblemText(const FormatException('That does not look like a friend code.')), 'That does not look like a friend code.');
    expect(friendProblemText(StateError('Turn chat on first.')), 'Turn chat on first.');
    expect(friendProblemText(Exception('SocketException: boom')), 'Something went wrong. Try again.');
  });
}
