import 'dart:math';
import 'package:flutter/material.dart';
import '../domain/buddy.dart';
import 'art.dart';

/// Species that have real pictures. "rabbit" (the old floppy-ear one) is shown
/// with the bunny pictures, since the two looked too alike.
const Set<String> kBuddyArtSpecies = {
  'blob', 'cat', 'dog', 'bunny', 'rabbit', 'frog', 'turtle', 'butterfly', 'fairy', 'unicorn',
};

bool buddyHasArt(String species) => kBuddyArtSpecies.contains(species);

String _artSpecies(String s) => s == 'rabbit' ? 'bunny' : s;

double _seg(double t, double a, double b) => ((t - a) / (b - a)).clamp(0.0, 1.0).toDouble();

/// The buddy drawn from the real pictures. [t] runs 0..1 over a care action
/// (1 = resting, nothing playing). Everything is a one-shot, never a loop.
class ArtBuddy extends StatelessWidget {
  const ArtBuddy({
    super.key,
    required this.species,
    required this.color,
    required this.mood,
    required this.size,
    this.reaction,
    this.t = 1,
  });
  final String species;
  final Color color;
  final BuddyMood mood;
  final double size;
  final BuddyAction? reaction;
  final double t;

  bool get _playing => reaction != null && t < 1;

  String get _pose {
    if (!_playing) return 'idle_${mood.name}';
    switch (reaction!) {
      case BuddyAction.feed:
      case BuddyAction.snack:
        return (t * 10).floor().isEven ? 'eating_open' : 'eating_closed';
      case BuddyAction.wash:
        return 'wash';
      case BuddyAction.cuddle:
        return 'cuddle';
      case BuddyAction.play:
        return 'jump';
      case BuddyAction.walk:
      case BuddyAction.pet:
        return 'idle_happy';
    }
  }

  Offset get _bodyShift {
    if (!_playing) return Offset.zero;
    switch (reaction!) {
      case BuddyAction.play:
        return Offset(0, -sin(t * pi * 5).abs() * size * .12);
      case BuddyAction.walk:
        return Offset(sin(t * pi * 2) * size * .16, -sin(t * pi * 8).abs() * size * .025);
      case BuddyAction.cuddle:
        return Offset(0, sin(t * pi * 6) * size * .01);
      default:
        return Offset.zero;
    }
  }

  Widget _prop(String name, {required double cx, required double cy, required double w, double opacity = 1}) {
    final px = size * w;
    return Positioned(
      left: size * cx - px / 2,
      top: size * cy - px / 2,
      width: px,
      height: px,
      child: IgnorePointer(child: ArtImage('buddy_prop_$name', opacity: opacity.clamp(0.0, 1.0).toDouble())),
    );
  }

  /// A prop that floats up and fades, started at [t0].
  Widget _rise(String name, {required double cx, required double from, required double t0, double w = .22, double rise = .45, double wobble = .03}) {
    final u = _seg(t, t0, min(1, t0 + .45));
    if (u <= 0 || u >= 1) return const SizedBox.shrink();
    return _prop(
      name,
      cx: cx + sin(u * pi * 3) * wobble,
      cy: from - rise * u,
      w: w,
      opacity: sin(u * pi).clamp(0.0, 1.0).toDouble() * 1.4,
    );
  }

  List<Widget> _props() {
    if (!_playing) return const [];
    switch (reaction!) {
      case BuddyAction.feed:
      case BuddyAction.snack:
        final food = reaction == BuddyAction.feed ? 'apple' : 'cookie';
        final eaten = _seg(t, .05, .55);
        return [
          if (eaten < 1)
            _prop(food, cx: .74 - .16 * _seg(t, 0, .12), cy: .62, w: .3 * (1 - eaten * .8)),
          if (t > .3) _rise('crumbs', cx: .5, from: .72, t0: .3, w: .3, rise: -.1, wobble: .02),
        ];
      case BuddyAction.wash:
        return [
          _prop('foam_puff', cx: .5, cy: .12 + sin(t * pi * 6) * .01, w: .34 * (.6 + .4 * _seg(t, 0, .2))),
          _rise('bubble_small', cx: .2, from: .7, t0: 0, w: .12),
          _rise('bubble_medium', cx: .8, from: .75, t0: .12, w: .17),
          _rise('bubble_large', cx: .35, from: .8, t0: .26, w: .22),
          _rise('bubble_small', cx: .68, from: .6, t0: .4, w: .12),
          _rise('bubble_medium', cx: .15, from: .55, t0: .5, w: .16),
        ];
      case BuddyAction.cuddle:
        return [
          _rise('heart_float', cx: .3, from: .5, t0: 0, w: .2),
          _rise('heart_float', cx: .7, from: .55, t0: .18, w: .24),
          _rise('heart_float', cx: .5, from: .45, t0: .36, w: .2),
          _rise('heart_float', cx: .22, from: .6, t0: .54, w: .16),
        ];
      case BuddyAction.play:
        return [
          _prop('balloon', cx: .82, cy: .2 + sin(t * pi * 4) * .03, w: .3),
          _rise('sparkle_star', cx: .2, from: .3, t0: .1, w: .16, rise: .12),
        ];
      case BuddyAction.walk:
        return [
          _prop('dust_puff',
              cx: .5 + sin(t * pi * 2) * .16 - cos(t * pi * 2) * .12,
              cy: .9,
              w: .2,
              opacity: (sin(t * pi * 8).abs()) * .8),
        ];
      case BuddyAction.pet:
        return [
          _prop('petting_hand', cx: .5 + sin(t * pi * 8) * .09, cy: .05 + sin(t * pi * 8).abs() * .02, w: .34),
          _rise('sparkle_star', cx: .8, from: .3, t0: .15, w: .16, rise: .1),
          _rise('sparkle_star', cx: .2, from: .35, t0: .4, w: .14, rise: .1),
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final shift = _bodyShift;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(clipBehavior: Clip.none, children: [
        Positioned.fill(
          child: Transform.translate(
            offset: shift,
            child: ArtImage(
              'buddy_${_artSpecies(species)}_$_pose',
              tint: softTint(color, .72),
              fit: BoxFit.contain,
            ),
          ),
        ),
        ..._props(),
      ]),
    );
  }
}
