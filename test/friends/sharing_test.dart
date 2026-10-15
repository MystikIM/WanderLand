import 'package:flutter_test/flutter_test.dart';
import 'package:plural_app/domain/models.dart';
import 'package:plural_app/friends/friend_models.dart';
import 'package:plural_app/friends/sharing.dart';

Alter alter(String id, String name, int color) =>
    Alter(id: id, name: name, createdAt: DateTime(2026), colorValue: color);

Friend friend({bool share = false, List<String> allowed = const []}) => Friend(
      id: 'f', theirUsername: 'w', publicKey: 'pk', state: FriendState.friends,
      inbox: 'i', outbox: 'o', createdAt: DateTime(2026),
      shareFront: share, allowedAlterIds: allowed,
    );

void main() {
  final star = alter('a1', 'Star', 0xFF111111);
  final shade = alter('a2', 'Shade', 0xFF222222);

  group('frontShareFor', () {
    test('sharing off sends nothing at all, even if alters are ticked', () {
      expect(frontShareFor(friend(share: false, allowed: ['a1']), [star]), isNull);
    });
    test('sharing on but nobody ticked: someone is out, no names', () {
      final s = frontShareFor(friend(share: true), [star])!;
      expect(s.alters, isEmpty);
      expect(s.someoneOut, isTrue);
    });
    test('only ticked alters are named, the rest become someone', () {
      final s = frontShareFor(friend(share: true, allowed: ['a1']), [star, shade])!;
      expect(s.alters.map((a) => a.name), ['Star']);
      expect(s.alters.single.colorValue, 0xFF111111);
      expect(s.someoneOut, isTrue);
    });
    test('everyone out is ticked: names only, no someone', () {
      final s = frontShareFor(friend(share: true, allowed: ['a1', 'a2']), [star, shade])!;
      expect(s.alters.map((a) => a.name), ['Star', 'Shade']);
      expect(s.someoneOut, isFalse);
    });
    test('nobody out is an empty front, not someone', () {
      final s = frontShareFor(friend(share: true, allowed: ['a1']), const [])!;
      expect(s.alters, isEmpty);
      expect(s.someoneOut, isFalse);
    });
  });

  group('speakerFor', () {
    test('a ticked alter speaks under their name and color', () {
      final s = speakerFor(friend(allowed: ['a1']), star)!;
      expect(s.name, 'Star');
      expect(s.colorValue, 0xFF111111);
    });
    test('an unticked alter, or no alter, is just the username', () {
      expect(speakerFor(friend(allowed: ['a1']), shade), isNull);
      expect(speakerFor(friend(allowed: ['a1']), null), isNull);
      expect(speakerFor(friend(), star), isNull);
    });
    test('the master front switch does not hide a ticked speaker', () {
      expect(speakerFor(friend(share: false, allowed: ['a1']), star), isNotNull);
    });
  });
}
