import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plural_app/domain/alter_kinds.dart';
import 'package:plural_app/domain/rewards.dart';
import 'package:plural_app/ui/art.dart';
import 'package:plural_app/ui/buddy_art.dart';

bool has(String name) => File(artPath(name)).existsSync();

// The real pictures are not in the public repo, so these checks only run on a
// machine that has them.
final bool _haveArt = has('world_backdrop');
final Object _skip = _haveArt ? false : 'the real art is not in this checkout';

void main() {
  test('every Inner World piece has a calm and a giggle picture', skip: _skip, () {
    for (final k in kPieceArt) {
      expect(has('piece_$k'), isTrue, reason: 'piece_$k');
      expect(has('piece_${k}_giggle'), isTrue, reason: 'piece_${k}_giggle');
    }
    expect(has('world_backdrop'), isTrue);
    expect(has('world_empty'), isTrue);
  });

  test('every buddy species with art has all 8 poses, and the care props exist', skip: _skip, () {
    const poses = [
      'idle_happy', 'idle_content', 'idle_sleepy', 'eating_open', 'eating_closed',
      'cuddle', 'jump', 'wash',
    ];
    for (final s in kBuddyArtSpecies.where((s) => s != 'rabbit')) {
      for (final p in poses) {
        expect(has('buddy_${s}_$p'), isTrue, reason: 'buddy_${s}_$p');
      }
    }
    for (final p in [
      'apple', 'cookie', 'crumbs', 'foam_puff', 'bubble_small', 'bubble_medium',
      'bubble_large', 'heart_float', 'balloon', 'sparkle_star', 'dust_puff', 'petting_hand',
    ]) {
      expect(has('buddy_prop_$p'), isTrue, reason: 'buddy_prop_$p');
    }
    expect(has('buddy_memorial_star'), isTrue);
  });

  test('every badge, accessory, outfit and alter frame has a picture', skip: _skip, () {
    for (final b in kBadges) {
      expect(has(badgeArtName(b.id)), isTrue, reason: badgeArtName(b.id));
    }
    for (final a in kAccessories) {
      expect(has('buddy_acc_$a'), isTrue, reason: 'buddy_acc_$a');
    }
    for (final o in kOutfits) {
      expect(has('buddy_outfit_$o'), isTrue, reason: 'buddy_outfit_$o');
    }
    for (final k in kAlterKinds) {
      expect(has('frame_$k'), isTrue, reason: 'frame_$k');
    }
  });

  test('dedication, empty-screen and onboarding pictures exist', skip: _skip, () {
    for (final n in ['cat', 'bunny', 'dog', 'frog', 'joker_wolf']) {
      expect(has('dedication_${n}_calm'), isTrue, reason: n);
      expect(has('dedication_${n}_happy'), isTrue, reason: n);
    }
    expect(has('dedication_backdrop'), isTrue);
    for (final n in ['front', 'alters', 'activity', 'journal', 'chat', 'world']) {
      expect(has('empty_$n'), isTrue, reason: 'empty_$n');
    }
    expect(has('onboarding_welcome'), isTrue);
    expect(has('onboarding_make_it_yours'), isTrue);
  });

  testWidgets('a missing picture shows the fallback instead of a hole', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: ArtImage('no_such_picture', fallback: Text('fallback here')),
    ));
    await tester.pumpAndSettle();
    expect(find.text('fallback here'), findsOneWidget);
  });
}
